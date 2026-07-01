"""Tambah izin Kamera/Galeri/Internet ke AndroidManifest.xml hasil `flutter create .`
Dipanggil dari workflow build-apk.yml. Aman dijalankan berkali-kali (idempotent).
"""
import sys

path = sys.argv[1]

with open(path, "r") as f:
    content = f.read()

if "android.permission.CAMERA" in content:
    print(">> Izin sudah ada, skip.")
    sys.exit(0)

perms = (
    '    <uses-permission android:name="android.permission.INTERNET"/>\n'
    '    <uses-permission android:name="android.permission.CAMERA"/>\n'
    '    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>\n'
    '    <uses-permission android:name="android.permission.READ_MEDIA_VIDEO"/>\n'
    '    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32"/>\n'
)

idx = content.index("<manifest")
end = content.index(">", idx) + 1
content = content[:end] + "\n" + perms + content[end:]

with open(path, "w") as f:
    f.write(content)

print(">> Izin berhasil ditambahkan ke AndroidManifest.xml")
