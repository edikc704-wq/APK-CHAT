// Pengganti logika di woun.html
// Perbedaan penting dibanding versi lama: transfer saldo sekarang pakai
// Firebase runTransaction() supaya aman dari race condition (dua transaksi
// barengan tidak akan saling timpa saldo lagi).

import 'package:firebase_database/firebase_database.dart';
import 'db_service.dart';

class KirimWounResult {
  final int jumlah;
  final int admin;
  final int diterima;
  final String tanggal;
  KirimWounResult({required this.jumlah, required this.admin, required this.diterima, required this.tanggal});
}

class WounService {
  WounService._internal();
  static final WounService instance = WounService._internal();
  factory WounService() => instance;

  final DbService _db = DbService.instance;

  int hitungAdmin(int jumlah) {
    if (jumlah < 20) return 3;
    if (jumlah < 45) return 5;
    return 25;
  }

  Stream<int> watchSaldo(String username) {
    return _db.onValue('users/$username/woun').map((e) {
      final v = e.snapshot.value;
      if (v == null) return 0;
      if (v is int) return v;
      return int.tryParse(v.toString()) ?? 0;
    });
  }

  String _tanggalSekarang() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  // FIX BUG #3 (lanjutan): callback harus return Transaction.success(nilai)
  // bukan langsung return nilai mentah — supaya sesuai tipe Transaction Function(Object?).
  Future<void> _ubahSaldo(String username, int Function(int current) updater) async {
    await _db.runTransaction('users/$username/woun', (current) {
      final saldo = (current is int) ? current : int.tryParse('${current ?? 0}') ?? 0;
      return Transaction.success(updater(saldo));
    });
  }

  Future<void> _simpanRiwayat(String myUser, Map<String, dynamic> entry) async {
    await _db.push('woun_history/$myUser', entry);
  }

  // ---------- USER BIASA: kirim woun (tidak boleh ke diri sendiri, tidak boleh saldo minus) ----------
  Future<KirimWounResult> kirimWoun(String myUser, String targetRaw, int jumlah) async {
    final target = targetRaw.trim().replaceAll('@', '').toLowerCase();
    if (target == myUser) throw Exception('Tidak bisa kirim ke diri sendiri!');
    if (jumlah <= 0) throw Exception('Jumlah tidak valid!');

    final targetSnap = await _db.getOnce('users/$target');
    if (!targetSnap.exists) throw Exception('User tidak ditemukan!');

    final admin = hitungAdmin(jumlah);
    final diterima = jumlah - admin;

    bool gagalSaldoKurang = false;
    await _ubahSaldo(myUser, (current) {
      if (current < jumlah) { gagalSaldoKurang = true; return current; }
      return current - jumlah;
    });
    if (gagalSaldoKurang) throw Exception('Woun Anda kurang! Transaksi gagal.');

    await _ubahSaldo(target, (current) => current + diterima);

    final tanggal = _tanggalSekarang();
    await _simpanRiwayat(myUser, {
      'type': 'KIRIM', 'targetUsername': target, 'jumlah': jumlah, 'diterima': diterima,
      'admin': admin, 'ownerMode': false, 'selfSend': false, 'tanggal': tanggal,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    await _kirimNotifChat(myUser, target, diterima);
    return KirimWounResult(jumlah: jumlah, admin: admin, diterima: diterima, tanggal: tanggal);
  }

  // ---------- OWNER: kirim bebas (boleh saldo minus, boleh ke diri sendiri) ----------
  Future<KirimWounResult> kirimWounOwner(String myUser, String targetRaw, int jumlah) async {
    final target = targetRaw.trim().replaceAll('@', '').toLowerCase();
    if (jumlah <= 0) throw Exception('Jumlah tidak valid!');

    final targetSnap = await _db.getOnce('users/$target');
    if (!targetSnap.exists) throw Exception('User tidak ditemukan!');

    final admin = hitungAdmin(jumlah);
    final diterima = jumlah - admin;
    final selfSend = target == myUser;

    if (selfSend) {
      await _ubahSaldo(myUser, (current) => current - admin + diterima);
    } else {
      await _ubahSaldo(myUser, (current) => current - jumlah);
      await _ubahSaldo(target, (current) => current + diterima);
    }

    final tanggal = _tanggalSekarang();
    await _simpanRiwayat(myUser, {
      'type': 'KIRIM', 'targetUsername': target, 'jumlah': jumlah, 'diterima': diterima,
      'admin': admin, 'ownerMode': true, 'selfSend': selfSend, 'tanggal': tanggal,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    if (!selfSend) await _kirimNotifChat(myUser, target, diterima);
    return KirimWounResult(jumlah: jumlah, admin: admin, diterima: diterima, tanggal: tanggal);
  }

  // ---------- OWNER: isi saldo sendiri langsung ----------
  Future<void> isiSendiri(String myUser, int jumlah) async {
    if (jumlah <= 0) throw Exception('Masukkan jumlah woun!');
    await _ubahSaldo(myUser, (current) => current + jumlah);
    await _simpanRiwayat(myUser, {
      'type': 'TAMBAH', 'targetUsername': myUser, 'jumlah': jumlah, 'tanggal': _tanggalSekarang(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // ---------- OWNER: tambah/kurangi woun user lain ----------
  Future<void> tambahWounUser(String myUser, String targetRaw, int jumlah) async {
    final target = targetRaw.trim().replaceAll('@', '').toLowerCase();
    if (jumlah <= 0) throw Exception('Isi semua field!');
    final snap = await _db.getOnce('users/$target');
    if (!snap.exists) throw Exception('User tidak ditemukan!');
    await _ubahSaldo(target, (current) => current + jumlah);
    await _simpanRiwayat(myUser, {'type': 'TAMBAH', 'targetUsername': target, 'jumlah': jumlah, 'tanggal': _tanggalSekarang(), 'timestamp': DateTime.now().millisecondsSinceEpoch});
  }

  Future<void> kurangiWounUser(String myUser, String targetRaw, int jumlah) async {
    final target = targetRaw.trim().replaceAll('@', '').toLowerCase();
    if (jumlah <= 0) throw Exception('Isi semua field!');
    final snap = await _db.getOnce('users/$target');
    if (!snap.exists) throw Exception('User tidak ditemukan!');
    await _ubahSaldo(target, (current) => (current - jumlah) < 0 ? 0 : current - jumlah);
    await _simpanRiwayat(myUser, {'type': 'KURANG', 'targetUsername': target, 'jumlah': jumlah, 'tanggal': _tanggalSekarang(), 'timestamp': DateTime.now().millisecondsSinceEpoch});
  }

  // ---------- Dipanggil dari InfernalBot (/gif) ----------
  Future<KirimWounResult> kirimViaBot(String myUser, String target, int jumlah) async {
    return kirimWoun(myUser, target, jumlah);
  }

  Future<void> _kirimNotifChat(String myUser, String target, int diterima) async {
    final notifText = '✅ Pengiriman Woun sejumlah $diterima woun berhasil dikirim ke @$target';
    final pairKey = ([myUser, target]..sort()).join('_');
    await _db.push('chats/$pairKey', {
      'sender': myUser, 'text': notifText, 'time': _jamSekarang(), 'timestamp': DateTime.now().millisecondsSinceEpoch, 'isWounNotif': true,
    });
    final ts = DateTime.now().millisecondsSinceEpoch;
    await _db.update('chats_index/$myUser/$target', {'lastMsg': notifText, 'lastTime': ts});
    await _db.update('chats_index/$target/$myUser', {'lastMsg': notifText, 'lastTime': ts});
  }

  String _jamSekarang() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  Future<List<Map<String, dynamic>>> muatRiwayat(String myUser) async {
    final snap = await _db.getOnce('woun_history/$myUser');
    if (!snap.exists) return [];
    final map = Map<String, dynamic>.from(snap.value as Map);
    final items = map.values.map((v) => Map<String, dynamic>.from(v as Map)).toList();
    items.sort((a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));
    return items;
  }
}
