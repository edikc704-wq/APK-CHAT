import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import 'chat_room_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});
  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  String? _myUser;

  @override
  void initState() {
    super.initState();
    AuthService.instance.getSession().then((u) => setState(() => _myUser = u));
  }

  @override
  Widget build(BuildContext context) {
    if (_myUser == null) return const Center(child: CircularProgressIndicator());

    return StreamBuilder<Map<String, ChatSummary>>(
      stream: ChatService.instance.watchChatList(_myUser!),
      builder: (context, AsyncSnapshot<Map<String, ChatSummary>> snap) {
        final data = snap.data;
        if (data == null || data.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Belum ada obrolan.\nMulai chat dengan mencari username.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF8696A0))),
            ),
          );
        }
        final entries = data.entries.toList()
          ..sort((a, b) => b.value.lastTime.compareTo(a.value.lastTime));

        return ListView.builder(
          itemCount: entries.length,
          itemBuilder: (context, i) {
            final target = entries[i].key;
            final summary = entries[i].value;
            return _ChatTile(myUser: _myUser!, target: target, lastMsg: summary.lastMsg, lastTime: summary.lastTime);
          },
        );
      },
    );
  }
}

class _ChatTile extends StatelessWidget {
  final String myUser;
  final String target;
  final String lastMsg;
  final int lastTime;
  const _ChatTile({required this.myUser, required this.target, required this.lastMsg, required this.lastTime});

  String _label() {
    if (target == 'pesan tersimpan') return 'Pesan Tersimpan';
    if (target == 'romainbot') return '🤖 RomainBot';
    if (target == 'infernalbot') return '🔥 InfernalBot';
    return '@$target';
  }

  @override
  Widget build(BuildContext context) {
    final time = lastTime > 0 ? TimeOfDay.fromDateTime(DateTime.fromMillisecondsSinceEpoch(lastTime)).format(context) : '';
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: const Color(0xFF2A3942),
        child: Text(target.isNotEmpty ? target[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white)),
      ),
      title: Text(_label(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      subtitle: Text(lastMsg, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF8696A0))),
      trailing: Text(time, style: const TextStyle(color: Color(0xFF8696A0), fontSize: 12)),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatRoomScreen(myUser: myUser, target: target, title: _label()))),
    );
  }
}
