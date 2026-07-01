// Pengganti simpan.js + logika chat di dashboard.html
// Termasuk logika bot romainbot & infernalbot (port 1:1 dari versi lama)

import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import 'db_service.dart';
import '../models/chat_message.dart';
import 'woun_service.dart';

class ChatService {
  ChatService._internal();
  static final ChatService instance = ChatService._internal();
  factory ChatService() => instance;

  final DbService _db = DbService.instance;

  String getPairKey(String userA, String userB) {
    if (userB == 'pesan tersimpan' || userA == userB) {
      return '${userA}_self';
    }
    final list = [userA, userB]..sort();
    return list.join('_');
  }

  String nowTime() {
    final now = DateTime.now();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Stream<List<ChatMessage>> watchMessages(String myUser, String targetRaw) {
    final target = targetRaw.replaceAll('@', '').toLowerCase();
    final pairKey = getPairKey(myUser, target);
    return _db.onValue('chats/$pairKey').map((event) {
      final raw = event.snapshot.value;
      if (raw == null) return <ChatMessage>[];
      final map = Map<String, dynamic>.from(raw as Map);
      final list = map.entries.map((e) => ChatMessage.fromMap(e.key, Map.from(e.value as Map))).toList();
      list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return list;
    });
  }

  Future<void> _updateIndex(String myUser, String target, String lastMsg, int ts) async {
    await _db.update('chats_index/$myUser/$target', {'lastMsg': lastMsg, 'lastTime': ts});
    if (target != 'pesan tersimpan' && target != myUser) {
      await _db.update('chats_index/$target/$myUser', {'lastMsg': lastMsg, 'lastTime': ts});
    }
  }

  Future<void> sendText(String myUser, String targetRaw, String text) async {
    final target = targetRaw.replaceAll('@', '').toLowerCase();

    if (target == 'romainbot') return _romainBot(myUser, text);
    if (target == 'infernalbot') return _infernalBot(myUser, text);

    // Cegah orang ngaku-ngaku transfer woun palsu
    if (RegExp(r'^pengiriman woun sejumlah', caseSensitive: false).hasMatch(text)) {
      await _pushRaw(myUser, target, {
        'sender': myUser,
        'type': 'text',
        'text': '⚠️ Stop! Ini tindakan palsu. Harap jujur.',
        'time': nowTime(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      return;
    }

    final ts = DateTime.now().millisecondsSinceEpoch;
    await _pushRaw(myUser, target, {
      'sender': myUser,
      'type': 'text',
      'text': text,
      'time': nowTime(),
      'timestamp': ts,
    });
    await _updateIndex(myUser, target, text, ts);
  }

  Future<void> _pushRaw(String myUser, String target, Map<String, dynamic> data) async {
    final pairKey = getPairKey(myUser, target);
    await _db.push('chats/$pairKey', data);
  }

  // ---------- KIRIM MEDIA (foto/video/file) - native picker, tanpa browser ----------
  Future<void> sendMedia({
    required String myUser,
    required String targetRaw,
    required String tipe, // image, video, file
    required List<int> bytes,
    required String mimeType,
    String? fileName,
  }) async {
    final target = targetRaw.replaceAll('@', '').toLowerCase();
    final maxSize = tipe == 'file' ? 2 * 1024 * 1024 : 5 * 1024 * 1024;
    if (bytes.length > maxSize) {
      throw Exception('Ukuran file terlalu besar! Maksimal ${tipe == 'file' ? '2MB' : '5MB'}.');
    }

    final base64Data = 'data:$mimeType;base64,${base64Encode(bytes)}';
    final ts = DateTime.now().millisecondsSinceEpoch;
    final time = nowTime();

    final msgData = <String, dynamic>{'sender': myUser, 'type': tipe, 'time': time, 'timestamp': ts};
    String lastMsgText;
    if (tipe == 'image') {
      msgData['imageData'] = base64Data;
      lastMsgText = '📷 Foto';
    } else if (tipe == 'video') {
      msgData['videoData'] = base64Data;
      lastMsgText = '🎥 Video';
    } else {
      msgData['fileData'] = base64Data;
      msgData['fileName'] = fileName ?? 'file';
      msgData['fileSize'] = '${(bytes.length / 1024).toStringAsFixed(1)} KB';
      lastMsgText = '📎 ${fileName ?? 'File'}';
    }
    msgData['text'] = lastMsgText;

    await _pushRaw(myUser, target, msgData);
    await _updateIndex(myUser, target, lastMsgText, ts);
  }

  Future<void> deleteMessage(String myUser, String targetRaw, String msgKey) async {
    final target = targetRaw.replaceAll('@', '').toLowerCase();
    final pairKey = getPairKey(myUser, target);
    await _db.update('chats/$pairKey/$msgKey', {'deleted': true, 'text': '🚫 Pesan ini telah dihapus'});
  }

  // ---------- DAFTAR OBROLAN ----------
  Stream<Map<String, ChatSummary>> watchChatList(String myUser) {
    return _db.onValue('chats_index/$myUser').map((event) {
      final raw = event.snapshot.value;
      final result = <String, ChatSummary>{};
      if (raw == null) return result;
      final map = Map<String, dynamic>.from(raw as Map);
      map.forEach((target, v) {
        final entry = Map<String, dynamic>.from(v as Map);
        result[target] = ChatSummary(
          target: target,
          lastMsg: entry['lastMsg']?.toString() ?? '',
          lastTime: (entry['lastTime'] is int) ? entry['lastTime'] : int.tryParse('${entry['lastTime']}') ?? 0,
        );
      });
      return result;
    });
  }

  // ---------- BOT: RomainBot (info user) ----------
  Future<void> _romainBot(String myUser, String text) async {
    final t = text.trim();
    await _kirimPesanBotUserSide('romainbot', myUser, t);

    String reply;
    if (t == '/start') {
      reply = 'Halo @$myUser! 👋\nKirim: <b>/info @username</b> untuk melihat info seseorang.';
    } else if (t.startsWith('/info')) {
      final target = t.replaceFirst('/info', '').trim().replaceAll('@', '').toLowerCase();
      if (target.isEmpty) {
        reply = 'Format: <b>/info @username</b>';
      } else {
        final snap = await _db.getOnce('users/$target');
        if (!snap.exists) {
          reply = '❌ User <b>@$target</b> tidak ditemukan.';
        } else {
          final d = Map<String, dynamic>.from(snap.value as Map);
          final status = d['status']?.toString() ?? 'Pengguna';
          final id = d['uid']?.toString() ?? target;
          final wounVisible = d['woun_visible'] == true;
          final woun = wounVisible ? '${d['woun'] ?? 0}' : '🔒 Disembunyikan';
          final verified = d['verified'];
          final badge = verified == 'biru' ? '✅ Bersertifikat Resmi' : verified == 'hijau' ? '🟢 Terverifikasi Aman' : '—';
          final scam = (d['scam'] == true) ? '⚠️ SCAM' : 'Aman';
          reply = 'ℹ️ <b>Informasi tentang @$target</b>\n\nStatus: $status\nLencana: $badge\nId: $id\nWoun: $woun\nKeamanan: $scam';
        }
      }
    } else {
      reply = 'Perintah tidak dikenal.\nGunakan: <b>/start</b> atau <b>/info @username</b>';
    }
    await Future.delayed(const Duration(milliseconds: 500));
    await _kirimBalasanBot('romainbot', myUser, reply);
  }

  // ---------- BOT: InfernalBot (kirim woun) ----------
  Future<void> _infernalBot(String myUser, String text) async {
    final t = text.trim();
    await _kirimPesanBotUserSide('infernalbot', myUser, t);

    String reply;
    if (t == '/start') {
      reply = 'Halo @$myUser! 🔥\nKirim woun: <b>/gif @username jumlah</b>\nContoh: <b>/gif @edxzvip 10</b>';
    } else if (t.startsWith('/gif')) {
      final parts = t.split(RegExp(r'\s+'));
      final targetRaw = parts.length > 1 ? parts[1] : '';
      final jumlah = parts.length > 2 ? int.tryParse(parts[2]) : null;
      final target = targetRaw.replaceAll('@', '').toLowerCase();

      if (target.isEmpty || jumlah == null || jumlah <= 0) {
        reply = 'Format: <b>/gif @username jumlah</b>';
      } else {
        try {
          final hasil = await WounService.instance.kirimViaBot(myUser, target, jumlah);
          reply = '✅ Pengiriman Woun Berhasil!\n\nKirim ke: @$target\nJumlah: $jumlah woun\nDiterima: ${hasil.diterima} woun\nAdmin: -${hasil.admin} woun\nTanggal: ${hasil.tanggal}';
        } catch (e) {
          reply = '❌ ${e.toString().replaceFirst('Exception: ', '')}';
        }
      }
    } else {
      reply = 'Perintah tidak dikenal.\nGunakan: <b>/start</b> atau <b>/gif @username jumlah</b>';
    }
    await Future.delayed(const Duration(milliseconds: 500));
    await _kirimBalasanBot('infernalbot', myUser, reply);
  }

  Future<void> _kirimPesanBotUserSide(String botId, String myUser, String userText) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    await _pushRaw(myUser, botId, {'sender': myUser, 'type': 'text', 'text': userText, 'time': nowTime(), 'timestamp': ts});
    await _updateIndex(myUser, botId, userText, ts);
  }

  Future<void> _kirimBalasanBot(String botId, String myUser, String reply) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    await _pushRaw(myUser, botId, {'sender': botId, 'type': 'text', 'text': reply, 'time': nowTime(), 'timestamp': ts, 'isBot': true});
    final preview = reply.length > 30 ? reply.substring(0, 30) : reply;
    await _updateIndex(myUser, botId, '🤖 $preview', ts);
  }

  /// Bisa dipanggil untuk memulai bot pertama kali (seperti startBot() lama)
  Future<void> startBot(String myUser, String botId) async {
    final greeting = botId == 'romainbot'
        ? 'Halo @$myUser! 👋\n\nKirim username orang untuk melihat identitasnya.\nContoh: /info @edxzvip'
        : 'Halo @$myUser! 🔥\n\nKirim woun ke orang lain!\nContoh: /gif @username 10';
    await _kirimPesanBotUserSide(botId, myUser, '/start');
    await Future.delayed(const Duration(milliseconds: 500));
    await _kirimBalasanBot(botId, myUser, greeting);
  }
}
