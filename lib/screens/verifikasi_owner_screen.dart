import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/db_service.dart';

class VerifikasiOwnerScreen extends StatelessWidget {
  const VerifikasiOwnerScreen({super.key});

  String _waktuLalu(int? ts) {
    if (ts == null) return '';
    final detik = (DateTime.now().millisecondsSinceEpoch - ts) ~/ 1000;
    if (detik < 60) return 'Baru saja';
    if (detik < 3600) return '${detik ~/ 60} menit lalu';
    if (detik < 86400) return '${detik ~/ 3600} jam lalu';
    return '${detik ~/ 86400} hari lalu';
  }

  Future<void> _terima(BuildContext context, String username) async {
    await DbService.instance.update('users/$username', {'verified': 'biru', 'verif_status': null, 'verif_photos': null});
    await DbService.instance.remove('verif_requests/$username');
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('@$username berhasil diverifikasi!')));
  }

  Future<void> _tolak(BuildContext context, String username) async {
    await DbService.instance.update('users/$username', {'verif_status': 'rejected', 'verif_reject_time': DateTime.now().millisecondsSinceEpoch, 'verif_photos': null});
    await DbService.instance.remove('verif_requests/$username');
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Permohonan @$username ditolak.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111B21),
      appBar: AppBar(backgroundColor: const Color(0xFF202C33), title: const Text('Permohonan Verifikasi')),
      body: StreamBuilder(
        stream: DbService.instance.onValue('verif_requests'),
        builder: (context, snap) {
          final raw = snap.data?.snapshot.value;
          if (raw == null) return const Center(child: Text('Tidak ada permohonan verifikasi saat ini.', style: TextStyle(color: Color(0xFF8696A0))));
          final data = Map<String, dynamic>.from(raw as Map);
          final usernames = data.keys.toList();
          if (usernames.isEmpty) return const Center(child: Text('Tidak ada permohonan verifikasi saat ini.', style: TextStyle(color: Color(0xFF8696A0))));

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: usernames.length,
            itemBuilder: (context, i) {
              final username = usernames[i];
              final req = Map<String, dynamic>.from(data[username] as Map);
              final photos = (req['photos'] as List?)?.cast<String>() ?? [];
              final time = req['time'] is int ? req['time'] as int : null;

              return Card(
                color: const Color(0xFF202C33),
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ExpansionTile(
                  leading: const CircleAvatar(backgroundColor: Color(0xFF2A3942), child: Icon(Icons.person, color: Color(0xFF8696A0))),
                  title: Text('@$username', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: Text(_waktuLalu(time), style: const TextStyle(color: Color(0xFF8696A0), fontSize: 12)),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 120,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: photos.map((p) {
                                final b64 = p.split(',').last;
                                return GestureDetector(
                                  onTap: () => _zoom(context, b64),
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 10),
                                    child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(Uint8List.fromList(base64Decode(b64)), width: 90, fit: BoxFit.cover)),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(children: [
                            Expanded(child: ElevatedButton(onPressed: () => _terima(context, username), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A884)), child: const Text('Terima'))),
                            const SizedBox(width: 10),
                            Expanded(child: ElevatedButton(onPressed: () => _tolak(context, username), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)), child: const Text('Tolak'))),
                          ]),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _zoom(BuildContext context, String b64) {
    showDialog(context: context, builder: (_) => Dialog(child: Image.memory(Uint8List.fromList(base64Decode(b64)))));
  }
}
