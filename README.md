# INFERNAL — Full Native Flutter

## Sudah jadi
- Login, Daftar, Setup Profil, Verifikasi 2 Langkah — native, hash password SHA-256, anti brute-force, captcha anti-bot
- Auto-login pakai sesi tersimpan
- Dashboard + bottom navigation (Obrolan, Kontak, Pengaturan, Profil)
- **Obrolan**: daftar chat real-time, chat room dengan bubble pesan, kirim foto/video/file LANGSUNG dari galeri/kamera Android asli (bukan lewat browser lagi), hapus pesan (tahan lama → hapus), bot RomainBot (`/info @user`) & InfernalBot (`/gif @user jumlah`)
- **Woun**: dompet saldo real-time, kirim woun (potongan admin otomatis sesuai tier), menu khusus Owner (tambah/kurangi/kirim bebas/isi sendiri), riwayat transaksi — transfer saldo sekarang pakai Firebase **transaction** (aman dari race condition, beda dari versi lama yang pakai `.set()` biasa)
- **Verifikasi**: ambil selfie 3 langkah (lurus/kiri/kanan) pakai kamera depan ASLI Android lewat package `camera` (izinnya izin sistem Android, bukan izin browser lagi), dan layar review untuk Owner (terima/tolak)
- GitHub Actions auto-build APK

## Belum jadi (menyusul)
- Pengaturan (dari `seting.js`, 52K — bio, ganti avatar, 2FA toggle, dll)
- Profil & Kontak (lihat profil orang, search `@username`, post foto/video di profil)
- Emoji picker (`emoji.js`)

## Cara build APK (full otomatis, tinggal upload)
1. Upload/push folder ini apa adanya ke GitHub (branch `main`)
2. GitHub Actions otomatis akan:
   - Generate folder `android/` (karena repo ini sengaja tidak menyertakannya — biar ringan & bisa dikerjakan dari Termux)
   - Tambahkan izin Kamera/Galeri/Internet ke `AndroidManifest.xml`
   - Pastikan folder `assets/images/` ada
   - `flutter pub get` lalu `flutter build apk --release`
3. Buka tab **Actions** di repo → tunggu selesai (hijau) → unduh artifact `infernal-apk`

Tidak perlu install Flutter SDK manual lagi, tidak perlu jalankan `flutter create .` manual, dan tidak perlu edit AndroidManifest.xml manual — semua sudah dihandle workflow `.github/workflows/build-apk.yml`.

## Catatan Firebase
`firebase_options.dart` masih pakai API key lama dari `database.js` supaya tetap konek ke database yang sama, data lama aman. Disarankan nanti jalankan `flutterfire configure` untuk key Android resmi.

