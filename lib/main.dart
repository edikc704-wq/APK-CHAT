import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const InfernalApp());
}

class InfernalApp extends StatelessWidget {
  const InfernalApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'INFERNAL',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B0F14),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00A884), brightness: Brightness.dark),
      ),
      home: const _SessionGate(),
    );
  }
}

// Pengganti script auto-login di login.html:
// kalau sesi tersimpan, langsung ke Dashboard tanpa lewat form login lagi.
class _SessionGate extends StatelessWidget {
  const _SessionGate();
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: AuthService.instance.getSession(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: Color(0xFF0B0F14),
            body: Center(child: CircularProgressIndicator(color: Color(0xFF00A884))),
          );
        }
        if (snapshot.data != null) {
          return const DashboardScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
