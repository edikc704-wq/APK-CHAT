import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/woun_service.dart';

class WounScreen extends StatefulWidget {
  const WounScreen({super.key});
  @override
  State<WounScreen> createState() => _WounScreenState();
}

class _WounScreenState extends State<WounScreen> {
  final _woun = WounService.instance;
  String _myUser = '';
  bool _isOwner = false;

  @override
  void initState() {
    super.initState();
    AuthService.instance.getSession().then((u) {
      setState(() {
        _myUser = u ?? '';
        _isOwner = _myUser == 'edxzvip';
      });
    });
  }

  Future<void> _showResultDialog(KirimWounResult r, {bool selfSend = false}) {
    return showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF202C33),
        title: const Text('✅ Berhasil', style: TextStyle(color: Colors.white)),
        content: Text(
          '${selfSend ? '📝 Pengisian saldo sendiri\n' : ''}'
          'Jumlah terkirim: ${r.jumlah} woun\n'
          '${!selfSend ? 'Diterima: ${r.diterima} woun\n' : ''}'
          'Biaya admin: ${r.admin} woun\nTanggal: ${r.tanggal}',
          style: const TextStyle(color: Color(0xFF8696A0)),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup'))],
      ),
    );
  }

  void _showError(Object e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.red),
    );
  }

  Future<void> _dialogKirim({required bool ownerMode}) async {
    final targetCtrl = TextEditingController();
    final jumlahCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF202C33),
        title: Text(ownerMode ? '📤 Kirim Woun (Owner)' : '📤 Kirim Woun', style: const TextStyle(color: Colors.white)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: targetCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: 'Username tujuan')),
          TextField(controller: jumlahCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: 'Jumlah woun')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Kirim')),
        ],
      ),
    );
    if (ok != true) return;
    final jumlah = int.tryParse(jumlahCtrl.text.trim()) ?? 0;
    try {
      final r = ownerMode
          ? await _woun.kirimWounOwner(_myUser, targetCtrl.text, jumlah)
          : await _woun.kirimWoun(_myUser, targetCtrl.text, jumlah);
      await _showResultDialog(r, selfSend: targetCtrl.text.trim().toLowerCase() == _myUser);
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _dialogIsiSendiri() async {
    final jumlahCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF202C33),
        title: const Text('💛 Isi Woun Sendiri', style: TextStyle(color: Colors.white)),
        content: TextField(controller: jumlahCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: 'Jumlah woun')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Tambah')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _woun.isiSendiri(_myUser, int.tryParse(jumlahCtrl.text.trim()) ?? 0);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saldo berhasil ditambah')));
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _dialogTambahKurang({required bool tambah}) async {
    final targetCtrl = TextEditingController();
    final jumlahCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF202C33),
        title: Text(tambah ? '➕ Tambah Woun' : '➖ Kurangi Woun', style: const TextStyle(color: Colors.white)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: targetCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: 'Username (tanpa @)')),
          TextField(controller: jumlahCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: 'Jumlah woun')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text(tambah ? 'Tambah' : 'Kurangi')),
        ],
      ),
    );
    if (ok != true) return;
    final jumlah = int.tryParse(jumlahCtrl.text.trim()) ?? 0;
    try {
      if (tambah) {
        await _woun.tambahWounUser(_myUser, targetCtrl.text, jumlah);
      } else {
        await _woun.kurangiWounUser(_myUser, targetCtrl.text, jumlah);
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Berhasil diproses')));
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _bukaRiwayat() async {
    final items = await _woun.muatRiwayat(_myUser);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF202C33),
      builder: (_) => ListView(
        padding: const EdgeInsets.all(16),
        children: items.isEmpty
            ? [const Padding(padding: EdgeInsets.all(20), child: Text('Belum ada riwayat transaksi.', style: TextStyle(color: Color(0xFF8696A0))))]
            : items.map((e) {
                final type = e['type'] ?? '';
                final target = e['targetUsername'] ?? '-';
                final jumlah = e['jumlah'] ?? 0;
                final tanggal = e['tanggal'] ?? '';
                return ListTile(
                  leading: Icon(type == 'KIRIM' ? Icons.send : type == 'KURANG' ? Icons.remove_circle_outline : Icons.add_circle_outline, color: const Color(0xFF3BA4F9)),
                  title: Text('$type → @$target', style: const TextStyle(color: Colors.white)),
                  subtitle: Text('$jumlah woun • $tanggal', style: const TextStyle(color: Color(0xFF8696A0))),
                );
              }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111B21),
      appBar: AppBar(
        backgroundColor: const Color(0xFF202C33),
        title: const Text('Dompet Woun'),
        actions: [IconButton(icon: const Icon(Icons.history), onPressed: _bukaRiwayat)],
      ),
      body: _myUser.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        const Text('Saldo Woun Kamu', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        StreamBuilder<int>(
                          stream: _woun.watchSaldo(_myUser),
                          builder: (context, snap) => Text(
                            '${snap.data ?? 0} 💰',
                            style: const TextStyle(color: Colors.black, fontSize: 36, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_isOwner) ...[
                    _ownerButton('➕ Tambah Woun User', const Color(0xFF3BA4F9), () => _dialogTambahKurang(tambah: true)),
                    _ownerButton('➖ Kurangi Woun User', const Color(0xFFEF4444), () => _dialogTambahKurang(tambah: false)),
                    _ownerButton('📤 Kirim Woun (Owner)', const Color(0xFF3BA4F9), () => _dialogKirim(ownerMode: true)),
                    _ownerButton('💛 Isi Woun Sendiri', const Color(0xFFFBBF24), _dialogIsiSendiri, dark: true),
                  ] else
                    _ownerButton('📤 Kirim Woun', const Color(0xFF3BA4F9), () => _dialogKirim(ownerMode: false)),
                ],
              ),
            ),
    );
  }

  Widget _ownerButton(String label, Color color, VoidCallback onTap, {bool dark = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: dark ? Colors.black : Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
