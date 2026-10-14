# Wasender + Wabadak (Android-native, Flutter)

Aplikasi Android untuk **Wasender** (kontak, kampanye, template, antrean,
jadwal, riwayat, laporan) dan **Wabadak** (inbox, balasan, label, catatan,
arsip). Seluruh operasional di HP — tanpa web admin, tanpa VPS WhatsApp.

## Status jujur
- Pengiriman AKTIF via aplikasi WhatsApp resmi (share intent / `wa.me`).
- Koneksi protokol langsung (QR/socket/E2E): **BLOCKED** — tidak ada library
  Dart/Flutter yang terbukti menjalankannya lokal di APK. Detail:
  `docs/WHATSAPP_COMPATIBILITY.md`. Tidak ada pesan/receipt palsu.
- Integrasi lisensi: kontrak + client siap; perlu 2 endpoint di web keygen
  milik Anda (`docs/LICENSE_API.md`). Tanpa base URL, aplikasi menampilkan
  pesan konfigurasi — bukan klaim integrasi selesai.

## Mulai
```powershell
flutter pub get
flutter run
flutter test
flutter analyze
flutter build apk --debug
flutter build apk --release --dart-define=LICENSE_BASE_URL=https://keygen.milik.anda
```

## Dokumen
`docs/ARCHITECTURE.md` · `INSTALLATION.md` · `WHATSAPP_COMPATIBILITY.md` ·
`LICENSE_API.md` · `SECURITY.md` · `TESTING.md` · `RELEASE.md` · `FINAL_AUDIT.md`

## Pasang di HP
1. Salin `build/app/outputs/flutter-apk/app-release.apk` ke HP.
2. Izinkan "install dari sumber tak dikenal", pasang.
3. Isi Base URL keygen + activation key → dashboard.
4. Pastikan WhatsApp resmi terinstal untuk pengiriman.
