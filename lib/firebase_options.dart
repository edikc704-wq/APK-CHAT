// File ini dibuat otomatis berdasarkan konfigurasi Firebase lama (database.js).
// CATATAN PENTING UNTUK NANTI DI-UPLOAD KE GITHUB:
// Sebaiknya jalankan `flutterfire configure` sekali di project ini supaya
// Android apiKey resmi terbentuk otomatis (lebih aman & stabil untuk APK asli).
// Tapi untuk sementara, config web lama tetap dipakai supaya tetap konek ke
// Realtime Database yang sama (data lama TIDAK hilang/berubah).

import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => android;

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDuF70h00Vf6Vbqk4YFrqrWyTWOovmn7ms',
    appId: '1:963004829027:android:dd1d4e791a9868d616d756',
    messagingSenderId: '963004829027',
    projectId: 'edxzvip',
    databaseURL: 'https://edxzvip-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'edxzvip.firebasestorage.app',
  );
}
