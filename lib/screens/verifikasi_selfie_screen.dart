// Pengganti fungsi mulaiSelfieVerifikasi()/ambilFotoSelfie() di seting.js
// yang dulu pakai navigator.mediaDevices.getUserMedia (browser).
// Sekarang pakai package `camera` asli Android, jadi izin kamera
// beneran izin sistem Android, bukan izin browser lagi.

import 'dart:convert';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../services/db_service.dart';

class VerifikasiSelfieScreen extends StatefulWidget {
  final String myUsername;
  const VerifikasiSelfieScreen({super.key, required this.myUsername});

  @override
  State<VerifikasiSelfieScreen> createState() => _VerifikasiSelfieScreenState();
}

class _VerifikasiSelfieScreenState extends State<VerifikasiSelfieScreen> {
  static const _langkah = ['Hadapkan wajah lurus ke kamera', 'Hadapkan wajah ke arah KIRI', 'Hadapkan wajah ke arah KANAN'];

  CameraController? _controller;
  bool _ready = false;
  bool _busy = false;
  int _step = 0;
  final List<String> _fotoBase64 = [];

  @override
  void initState() {
    super.initState();
    _initKamera();
  }

  Future<void> _initKamera() async {
    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front, orElse: () => cameras.first);
      _controller = CameraController(front, ResolutionPreset.medium, enableAudio: false);
      await _controller!.initialize();
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal mengakses kamera depan. Pastikan izin kamera diaktifkan.'), backgroundColor: Colors.red));
        Navigator.pop(context);
      }
    }
  }

  Future<void> _ambilFoto() async {
    if (_controller == null || !_controller!.value.isInitialized || _busy) return;
    setState(() => _busy = true);
    try {
      final file = await _controller!.takePicture();
      final bytes = await file.readAsBytes();
      _fotoBase64.add('data:image/jpeg;base64,${base64Encode(bytes)}');
      setState(() {
        _step++;
        _busy = false;
      });
    } catch (e) {
      setState(() => _busy = false);
    }
  }

  Future<void> _kirim() async {
    setState(() => _busy = true);
    try {
      await DbService.instance.update('users/${widget.myUsername}', {
        'verif_status': 'pending',
        'verif_photos': _fotoBase64,
      });
      await DbService.instance.set('verif_requests/${widget.myUsername}', {
        'time': DateTime.now().millisecondsSinceEpoch,
        'photos': _fotoBase64,
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permintaan verifikasi terkirim! Mohon tunggu peninjauan dari Owner.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selesai = _step >= 3;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, title: const Text('Verifikasi Selfie')),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(child: ClipRect(child: CameraPreview(_controller!))),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  color: const Color(0xFF111B21),
                  child: Column(
                    children: [
                      Text(selesai ? 'Semua foto terambil. Siap dikirim?' : _langkah[_step], textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 15)),
                      const SizedBox(height: 12),
                      if (_fotoBase64.isNotEmpty)
                        SizedBox(
                          height: 60,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: _fotoBase64.map((f) {
                              final b64 = f.split(',').last;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(Uint8List.fromList(base64Decode(b64)), width: 50, height: 60, fit: BoxFit.cover)),
                              );
                            }).toList(),
                          ),
                        ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _busy ? null : (selesai ? _kirim : _ambilFoto),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A884), padding: const EdgeInsets.symmetric(vertical: 14)),
                          child: Text(_busy ? 'Memproses...' : (selesai ? 'Kirim' : 'Ambil Foto'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
