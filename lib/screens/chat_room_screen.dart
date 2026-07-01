import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../models/chat_message.dart';
import '../services/chat_service.dart';

class ChatRoomScreen extends StatefulWidget {
  final String myUser;
  final String target;
  final String title;
  const ChatRoomScreen({super.key, required this.myUser, required this.target, required this.title});

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final _chat = ChatService.instance;
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _kirimTeks() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _inputCtrl.clear();
    try {
      await _chat.sendText(widget.myUser, widget.target, text);
      _scrollToBottom();
    } catch (e) {
      _showError(e);
    }
  }

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.red));
  }

  // ---------- LAMPIRAN NATIVE: foto, video, file (tanpa browser) ----------
  Future<void> _ambilDariGaleri({required bool video}) async {
    final picker = ImagePicker();
    final picked = video ? await picker.pickVideo(source: ImageSource.gallery) : await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    await _uploadDanKirim(File(picked.path), video ? 'video' : 'image');
  }

  Future<void> _ambilDariKamera({required bool video}) async {
    final picker = ImagePicker();
    final picked = video ? await picker.pickVideo(source: ImageSource.camera) : await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (picked == null) return;
    await _uploadDanKirim(File(picked.path), video ? 'video' : 'image');
  }

  Future<void> _ambilFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.single.path == null) return;
    await _uploadDanKirim(File(result.files.single.path!), 'file');
  }

  Future<void> _uploadDanKirim(File file, String tipe) async {
    setState(() => _sending = true);
    try {
      final bytes = await file.readAsBytes();
      final mime = tipe == 'image' ? 'image/jpeg' : tipe == 'video' ? 'video/mp4' : 'application/octet-stream';
      await _chat.sendMedia(
        myUser: widget.myUser,
        targetRaw: widget.target,
        tipe: tipe,
        bytes: bytes,
        mimeType: mime,
        fileName: file.path.split('/').last,
      );
      _scrollToBottom();
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showLampiranPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF202C33),
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(leading: const Icon(Icons.photo, color: Color(0xFF3BA4F9)), title: const Text('Foto dari Galeri', style: TextStyle(color: Colors.white)), onTap: () { Navigator.pop(context); _ambilDariGaleri(video: false); }),
            ListTile(leading: const Icon(Icons.camera_alt, color: Color(0xFF3BA4F9)), title: const Text('Foto dari Kamera', style: TextStyle(color: Colors.white)), onTap: () { Navigator.pop(context); _ambilDariKamera(video: false); }),
            ListTile(leading: const Icon(Icons.videocam, color: Color(0xFFEF4444)), title: const Text('Video', style: TextStyle(color: Colors.white)), onTap: () { Navigator.pop(context); _ambilDariGaleri(video: true); }),
            ListTile(leading: const Icon(Icons.insert_drive_file, color: Color(0xFF8696A0)), title: const Text('File', style: TextStyle(color: Colors.white)), onTap: () { Navigator.pop(context); _ambilFile(); }),
          ],
        ),
      ),
    );
  }

  Future<void> _hapusPesan(ChatMessage msg) async {
    if (msg.sender != widget.myUser) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF202C33),
        title: const Text('Hapus pesan?', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      await _chat.deleteMessage(widget.myUser, widget.target, msg.key);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F14),
      appBar: AppBar(backgroundColor: const Color(0xFF202C33), title: Text(widget.title)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _chat.watchMessages(widget.myUser, widget.target),
              builder: (context, snap) {
                final messages = snap.data ?? [];
                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, i) => _Bubble(msg: messages[i], isMe: messages[i].sender == widget.myUser, onLongPress: () => _hapusPesan(messages[i])),
                );
              },
            ),
          ),
          if (_sending) const LinearProgressIndicator(minHeight: 2),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              color: const Color(0xFF202C33),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.attach_file, color: Color(0xFF8696A0)), onPressed: _showLampiranPicker),
                  Expanded(
                    child: TextField(
                      controller: _inputCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Tulis pesan...',
                        hintStyle: const TextStyle(color: Color(0xFF8696A0)),
                        filled: true,
                        fillColor: const Color(0xFF2A3942),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      ),
                      onSubmitted: (_) => _kirimTeks(),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.send, color: Color(0xFF00A884)), onPressed: _kirimTeks),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage msg;
  final bool isMe;
  final VoidCallback onLongPress;
  const _Bubble({required this.msg, required this.isMe, required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final align = isMe ? Alignment.centerRight : Alignment.centerLeft;
    final color = msg.deleted ? const Color(0xFF2A3942) : isMe ? const Color(0xFF005C4B) : const Color(0xFF202C33);

    Widget content;
    if (msg.deleted) {
      content = Text('🚫 Pesan ini telah dihapus', style: const TextStyle(color: Color(0xFF8696A0), fontStyle: FontStyle.italic));
    } else if (msg.type == 'image' && msg.imageData != null) {
      content = ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(_decodeBase64(msg.imageData!), width: 200, fit: BoxFit.cover));
    } else if (msg.type == 'video' && msg.videoData != null) {
      content = Row(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.videocam, color: Colors.white), SizedBox(width: 6), Text('Video', style: TextStyle(color: Colors.white))]);
    } else if (msg.type == 'file' && msg.fileData != null) {
      content = Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.insert_drive_file, color: Color(0xFF3BA4F9)),
        const SizedBox(width: 8),
        Flexible(child: Text(msg.fileName ?? 'File', style: const TextStyle(color: Colors.white))),
      ]);
    } else {
      content = Text(msg.text, style: const TextStyle(color: Colors.white));
    }

    return Align(
      alignment: align,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(10),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            content,
            const SizedBox(height: 4),
            Text(msg.time, style: const TextStyle(color: Color(0xFF8696A0), fontSize: 10)),
          ]),
        ),
      ),
    );
  }

  static Uint8List _decodeBase64(String dataUrl) {
    final parts = dataUrl.split(',');
    final b64 = parts.length > 1 ? parts[1] : parts[0];
    return base64Decode(b64);
  }
}
