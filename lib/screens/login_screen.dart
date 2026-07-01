import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum _Step { login, register, setup, twofa }

class _LoginScreenState extends State<LoginScreen> {
  final _auth = AuthService.instance;
  _Step _step = _Step.login;
  bool _loading = false;
  String? _error;

  // login
  final _loginUserCtrl = TextEditingController();
  final _loginPassCtrl = TextEditingController();

  // register
  final _regUserCtrl = TextEditingController();
  final _regPassCtrl = TextEditingController();
  final _regConfirmCtrl = TextEditingController();

  // captcha
  late Map<String, dynamic> _captcha;
  final _captchaCtrl = TextEditingController();

  // setup
  final _setupNameCtrl = TextEditingController();
  File? _avatarFile;
  String _avatarBase64 = '';

  // twofa
  final _twofaCtrl = TextEditingController();
  String? _pendingUser;
  String? _pendingPinHash;
  bool _pendingNeedsSetup = false;

  @override
  void initState() {
    super.initState();
    _captcha = _auth.generateCaptcha();
    _auth.ensureOwnerAccountExists();
  }

  void _refreshCaptcha() {
    setState(() {
      _captcha = _auth.generateCaptcha();
      _captchaCtrl.clear();
    });
  }

  bool _captchaOk() => int.tryParse(_captchaCtrl.text.trim()) == _captcha['answer'];

  Future<void> _doLogin() async {
    if (!_captchaOk()) {
      setState(() => _error = 'Jawaban verifikasi salah. Coba lagi.');
      _refreshCaptcha();
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _auth.login(_loginUserCtrl.text, _loginPassCtrl.text);
      if (!res.success) {
        setState(() => _error = res.error);
        _refreshCaptcha();
      } else if (res.needsTwofa) {
        _pendingUser = res.username;
        _pendingPinHash = res.twofaPinHash;
        _pendingNeedsSetup = res.needsSetup;
        setState(() => _step = _Step.twofa);
      } else if (res.needsSetup) {
        setState(() => _step = _Step.setup);
      } else {
        _goToDashboard();
      }
    } catch (e) {
      setState(() => _error = _friendlyError(e));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _doRegister() async {
    if (!_captchaOk()) {
      setState(() => _error = 'Jawaban verifikasi salah. Coba lagi.');
      _refreshCaptcha();
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _auth.register(_regUserCtrl.text, _regPassCtrl.text, _regConfirmCtrl.text);
      if (!res.success) {
        setState(() => _error = res.error);
      } else {
        setState(() => _step = _Step.setup);
      }
    } catch (e) {
      setState(() => _error = _friendlyError(e));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _doTwofa() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _auth.verifyTwofa(_pendingUser!, _twofaCtrl.text.trim(), _pendingPinHash!, _pendingNeedsSetup);
      if (!res.success) {
        setState(() => _error = res.error);
      } else if (res.needsSetup) {
        setState(() => _step = _Step.setup);
      } else {
        _goToDashboard();
      }
    } catch (e) {
      setState(() => _error = _friendlyError(e));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 250, maxHeight: 250, imageQuality: 80);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _avatarFile = File(picked.path);
      _avatarBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
    });
  }

  Future<void> _doSetup() async {
    final user = _pendingUser ?? await _auth.getSession();
    if (user == null) return;
    setState(() { _loading = true; _error = null; });
    try {
      await _auth.completeSetup(user, _setupNameCtrl.text.trim(), _avatarBase64);
      _goToDashboard();
    } catch (e) {
      setState(() => _error = _friendlyError(e));
    } finally {
      setState(() => _loading = false);
    }
  }

  String _friendlyError(Object e) {
    if (e is LoginAttemptBlockedException) {
      return 'Terlalu banyak percobaan. Coba lagi dalam ${e.secondsLeft} detik.';
    }
    return 'Gagal terhubung ke server. Pastikan internet menyala.';
  }

  void _goToDashboard() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F14),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: 420,
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.fromLTRB(32, 40, 32, 32),
            decoration: BoxDecoration(
              color: const Color(0xFF111B21).withOpacity(0.85),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 60, offset: const Offset(0, 30))],
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: _buildStep(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case _Step.login:
        return _loginForm();
      case _Step.register:
        return _registerForm();
      case _Step.setup:
        return _setupForm();
      case _Step.twofa:
        return _twofaForm();
    }
  }

  Widget _header(String title, String subtitle) {
    return Column(
      key: ValueKey(title),
      children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(subtitle, style: const TextStyle(color: Color(0xFF8696A0), fontSize: 14)),
        const SizedBox(height: 30),
      ],
    );
  }

  InputDecoration _inputDeco(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF8696A0)),
      prefixIcon: Icon(icon, color: const Color(0xFF8696A0)),
      filled: true,
      fillColor: const Color(0xFF202C33),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF3BA4F9))),
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
    );
  }

  Widget _errorText() {
    if (_error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(_error!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13), textAlign: TextAlign.center),
    );
  }

  Widget _captchaField() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _captchaCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDeco('Verifikasi: ${_captcha['question']}', Icons.shield_outlined),
          ),
        ),
        IconButton(onPressed: _refreshCaptcha, icon: const Icon(Icons.refresh, color: Color(0xFF8696A0))),
      ],
    );
  }

  Widget _submitButton(String label, IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _loading ? null : onTap,
        icon: _loading
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Icon(icon),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00A884),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _loginForm() {
    return Column(
      key: const ValueKey('login'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _header('Selamat Datang', 'Masuk untuk melanjutkan ke Obrolan'),
        TextField(controller: _loginUserCtrl, style: const TextStyle(color: Colors.white), decoration: _inputDeco('Username', Icons.person_outline)),
        const SizedBox(height: 16),
        TextField(controller: _loginPassCtrl, obscureText: true, style: const TextStyle(color: Colors.white), decoration: _inputDeco('Password', Icons.lock_outline)),
        const SizedBox(height: 16),
        _captchaField(),
        const SizedBox(height: 8),
        _submitButton('Masuk', Icons.login, _doLogin),
        _errorText(),
        const SizedBox(height: 20),
        TextButton(
          onPressed: () => setState(() { _step = _Step.register; _error = null; _refreshCaptcha(); }),
          child: const Text.rich(TextSpan(
            text: 'Belum punya akun? ',
            style: TextStyle(color: Color(0xFF8696A0)),
            children: [TextSpan(text: 'Buat sekarang', style: TextStyle(color: Color(0xFF3BA4F9), fontWeight: FontWeight.w600))],
          )),
        ),
      ],
    );
  }

  Widget _registerForm() {
    return Column(
      key: const ValueKey('register'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _header('Buat Akun', 'Bergabunglah dengan komunitas kami'),
        TextField(controller: _regUserCtrl, style: const TextStyle(color: Colors.white), decoration: _inputDeco('Username Baru (Wajib)', Icons.person_add_alt)),
        const SizedBox(height: 16),
        TextField(controller: _regPassCtrl, obscureText: true, style: const TextStyle(color: Colors.white), decoration: _inputDeco('Password', Icons.lock_outline)),
        const SizedBox(height: 16),
        TextField(controller: _regConfirmCtrl, obscureText: true, style: const TextStyle(color: Colors.white), decoration: _inputDeco('Konfirmasi Password', Icons.verified_user_outlined)),
        const SizedBox(height: 16),
        _captchaField(),
        const SizedBox(height: 8),
        _submitButton('Daftar Akun', Icons.person_add, _doRegister),
        _errorText(),
        const SizedBox(height: 20),
        TextButton(
          onPressed: () => setState(() { _step = _Step.login; _error = null; _refreshCaptcha(); }),
          child: const Text.rich(TextSpan(
            text: 'Sudah punya akun? ',
            style: TextStyle(color: Color(0xFF8696A0)),
            children: [TextSpan(text: 'Masuk di sini', style: TextStyle(color: Color(0xFF3BA4F9), fontWeight: FontWeight.w600))],
          )),
        ),
      ],
    );
  }

  Widget _setupForm() {
    return Column(
      key: const ValueKey('setup'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _header('Lengkapi Profil', 'Pasang foto dan nama tampilan Anda'),
        GestureDetector(
          onTap: _pickAvatar,
          child: Container(
            width: 110, height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF202C33),
              border: Border.all(color: const Color(0xFF3BA4F9), width: 2, style: BorderStyle.solid),
              image: _avatarFile != null ? DecorationImage(image: FileImage(_avatarFile!), fit: BoxFit.cover) : null,
            ),
            child: _avatarFile == null ? const Icon(Icons.camera_alt_outlined, color: Color(0xFF8696A0), size: 36) : null,
          ),
        ),
        const SizedBox(height: 10),
        const Text('Foto Profil (Opsional)', style: TextStyle(color: Color(0xFF8696A0), fontSize: 12)),
        const SizedBox(height: 24),
        TextField(controller: _setupNameCtrl, style: const TextStyle(color: Colors.white), decoration: _inputDeco('Nama Tampilan (Opsional)', Icons.badge_outlined)),
        const SizedBox(height: 8),
        _submitButton('Selesai & Masuk', Icons.check_circle_outline, _doSetup),
        _errorText(),
      ],
    );
  }

  Widget _twofaForm() {
    return Column(
      key: const ValueKey('twofa'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _header('Verifikasi 2 Langkah', 'Masukkan PIN 4 digit untuk masuk'),
        TextField(
          controller: _twofaCtrl,
          obscureText: true,
          maxLength: 4,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDeco('PIN 4 Digit', Icons.shield_moon_outlined).copyWith(counterText: ''),
        ),
        _submitButton('Verifikasi & Masuk', Icons.login, _doTwofa),
        _errorText(),
      ],
    );
  }
}
