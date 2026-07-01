import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'chat_list_screen.dart';
import 'woun_screen.dart';
import 'verifikasi_owner_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _tabIndex = 0;
  String? _username;

  final _titles = ['Obrolan', 'Kontak', 'Pengaturan', 'Profil'];

  @override
  void initState() {
    super.initState();
    AuthService.instance.getSession().then((u) => setState(() => _username = u));
  }

  bool get _isOwner => _username == 'edxzvip';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF202C33),
        title: Text(_titles[_tabIndex]),
        actions: _isOwner
            ? [
                IconButton(
                  icon: const Icon(Icons.badge_outlined, color: Color(0xFF3BA4F9)),
                  tooltip: 'Permohonan Verifikasi',
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VerifikasiOwnerScreen())),
                ),
                IconButton(
                  icon: const Icon(Icons.monetization_on_outlined, color: Color(0xFFFBBF24)),
                  tooltip: 'Kelola Woun',
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WounScreen())),
                ),
              ]
            : null,
      ),
      body: IndexedStack(
        index: _tabIndex,
        children: const [
          ChatListScreen(),
          _PlaceholderTab(label: 'Daftar Kontak'),
          _PlaceholderTab(label: 'Pengaturan'),
          _PlaceholderTab(label: 'Profil Kamu'),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF202C33),
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Obrolan'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Kontak'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Pengaturan'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  final String label;
  const _PlaceholderTab({required this.label});
  @override
  Widget build(BuildContext context) {
    return Center(child: Text('$label\n(segera dilengkapi)', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF8696A0))));
  }
}
