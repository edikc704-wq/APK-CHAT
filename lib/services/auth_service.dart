// Pengganti logika login.html
// Tambahan keamanan dibanding versi lama:
// 1. Password di-hash SHA-256 (bukan plaintext) sebelum disimpan/dicek
// 2. Rate limit percobaan login per device (anti brute-force / anti jailbreak login)
// 3. Tantangan "bukan robot" sederhana (math captcha) sebelum login/daftar
//    -> tidak butuh internet ke Google reCAPTCHA, jadi tetap ringan & native
// 4. 2FA PIN tetap dipertahankan seperti versi lama

import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/db_service.dart';

class LoginAttemptBlockedException implements Exception {
  final int secondsLeft;
  LoginAttemptBlockedException(this.secondsLeft);
}

class AuthResult {
  final bool success;
  final String? error;
  final bool needsSetup;
  final bool needsTwofa;
  final String? username;
  final String? twofaPinHash;
  AuthResult({
    required this.success,
    this.error,
    this.needsSetup = false,
    this.needsTwofa = false,
    this.username,
    this.twofaPinHash,
  });
}

class AuthService {
  AuthService._internal();
  static final AuthService instance = AuthService._internal();
  factory AuthService() => instance;

  final DbService _db = DbService.instance;

  static const _maxAttempts = 5;
  static const _lockSeconds = 30;

  String hashPassword(String plain) {
    return sha256.convert(utf8.encode(plain)).toString();
  }

  // ---------- CAPTCHA SEDERHANA (anti bot, native, tanpa internet tambahan) ----------
  Map<String, dynamic> generateCaptcha() {
    final rnd = Random();
    final a = rnd.nextInt(9) + 1;
    final b = rnd.nextInt(9) + 1;
    return {'question': '$a + $b = ?', 'answer': a + b};
  }

  // ---------- RATE LIMIT LOKAL PER DEVICE ----------
  Future<void> _checkAndRegisterAttempt(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final countKey = 'attempt_count_$key';
    final timeKey = 'attempt_blocked_until_$key';

    final blockedUntil = prefs.getInt(timeKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (blockedUntil > now) {
      throw LoginAttemptBlockedException(((blockedUntil - now) / 1000).ceil());
    }

    final count = (prefs.getInt(countKey) ?? 0) + 1;
    if (count >= _maxAttempts) {
      await prefs.setInt(timeKey, now + _lockSeconds * 1000);
      await prefs.setInt(countKey, 0);
      throw LoginAttemptBlockedException(_lockSeconds);
    }
    await prefs.setInt(countKey, count);
  }

  Future<void> _resetAttempts(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('attempt_count_$key');
    await prefs.remove('attempt_blocked_until_$key');
  }

  // ---------- SESI (pengganti localStorage active_session) ----------
  Future<void> saveSession(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_session', username);
  }

  Future<String?> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('active_session');
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_session');
  }

  // ---------- LOGIN ----------
  Future<AuthResult> login(String usernameRaw, String password) async {
    final username = usernameRaw.trim().toLowerCase();
    await _checkAndRegisterAttempt('login_$username');

    final snap = await _db.getOnce('users/$username');
    if (!snap.exists) {
      return AuthResult(success: false, error: 'Akun belum terdaftar! Silakan daftar terlebih dahulu.');
    }

    final data = Map<String, dynamic>.from(snap.value as Map);
    final storedPass = data['password']?.toString() ?? '';
    final hashedInput = hashPassword(password);

    // Backward-compatible: kalau password lama masih plaintext, otomatis
    // di-upgrade jadi hash begitu cocok, tanpa user sadar / tanpa ganggu fitur.
    bool match = storedPass == hashedInput;
    if (!match && storedPass == password) {
      match = true;
      await _db.update('users/$username', {'password': hashedInput});
    }

    if (!match) {
      return AuthResult(success: false, error: 'Password salah! Silakan periksa kembali.');
    }

    await _resetAttempts('login_$username');

    if (data['twofa_enabled'] == true && data['twofa_pin'] != null) {
      return AuthResult(
        success: true,
        needsTwofa: true,
        username: username,
        twofaPinHash: data['twofa_pin'].toString(),
        needsSetup: data['setup_done'] != true,
      );
    }

    await saveSession(username);
    return AuthResult(
      success: true,
      username: username,
      needsSetup: data['setup_done'] != true,
    );
  }

  Future<AuthResult> verifyTwofa(String username, String pin, String expectedPinHash, bool needsSetup) async {
    await _checkAndRegisterAttempt('twofa_$username');
    if (hashPassword(pin) != expectedPinHash && pin != expectedPinHash) {
      return AuthResult(success: false, error: 'PIN salah!');
    }
    await _resetAttempts('twofa_$username');
    await saveSession(username);
    return AuthResult(success: true, username: username, needsSetup: needsSetup);
  }

  // ---------- REGISTER ----------
  Future<AuthResult> register(String usernameRaw, String password, String confirm) async {
    String username = usernameRaw.trim().toLowerCase();

    if (username.length < 4) {
      return AuthResult(success: false, error: 'Username terlalu pendek! Minimal 4 huruf.');
    }
    if (username == 'edxzvip') {
      return AuthResult(success: false, error: 'Stop! Akun resmi hanya @edxzvip, hindari pembuatan clone.');
    }
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(username)) {
      return AuthResult(success: false, error: 'Username hanya boleh huruf kecil, angka, underscore.');
    }
    if (password.length < 4) {
      return AuthResult(success: false, error: 'Password terlalu pendek! Minimal 4 karakter.');
    }
    if (password != confirm) {
      return AuthResult(success: false, error: 'Password dan konfirmasi tidak cocok!');
    }

    await _checkAndRegisterAttempt('register_$username');

    final existing = await _db.getOnce('users/$username');
    if (existing.exists) {
      final rnd = Random().nextInt(900) + 100;
      username = '$username$rnd';
    }

    await _db.set('users/$username', {
      'password': hashPassword(password),
      'display_name': '',
      'avatar': '',
      'setup_done': false,
      'scam': false,
    });

    await saveSession(username);
    return AuthResult(success: true, username: username, needsSetup: true);
  }

  Future<void> ensureOwnerAccountExists() async {
    final snap = await _db.getOnce('users/edxzvip');
    if (!snap.exists) {
      await _db.set('users/edxzvip', {
        'password': hashPassword('EDXZVIP21'),
        'display_name': 'Owner Resmi',
        'avatar': '',
        'setup_done': true,
        'scam': false,
      });
    }
  }

  Future<void> completeSetup(String username, String displayName, String avatarBase64) async {
    await _db.update('users/$username', {
      'display_name': displayName,
      'avatar': avatarBase64,
      'setup_done': true,
    });
  }
}
