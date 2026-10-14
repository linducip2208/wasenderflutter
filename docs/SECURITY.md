# Keamanan & Privasi

## Yang diterapkan
- Tanpa hardcoded secret: base URL via `--dart-define` / pengaturan; tanpa
  API secret, private key, atau kredensial lisensi di source/APK.
- Sesi WA & payload lisensi di `flutter_secure_storage` (Keystore-backed),
  bukan teks biasa / SharedPreferences.
- TLS default platform untuk keygen; timeout 20 dtk; respons invalid
  ditangani eksplisit.
- Sanitasi CSV (buang karakter kontrol, batasi panjang), validasi nomor
  08/62, batas lampiran 10 MB + whitelist ekstensi.
- Konfirmasi destruktif: hapus kontak/template, cancel antrean, restore, wipe.
- Log audit lokal tanpa token/QR/isi pesan/kredensial (detail dipotong 2000 char).
- Permission Android minimal: INTERNET + ACCESS_NETWORK_STATE saja
  (lihat AndroidManifest). Tanpa SMS/CALL/LOCATION/CONTACTS sistem.
- Backup JSON memuat data lokal (termasuk isi pesan) dan TIDAK terenkripsi —
  dinyatakan jujur di UI; sesi sensitif tidak ikut ter-backup.
- Penghapusan data: menu Penyimpanan > Hapus seluruh data lokal.

## Keterbatasan yang dinyatakan jujur
- DB SQLite lokal BUKAN SQLCipher — jangan diklaim terenkripsi.
- Proteksi client-side tidak anti-crack total; status otoritatif tetap di
  web keygen (revalidasi online + batas cache offline).
- Pengiriman memakai aplikasi WA resmi; hormati opt-in, suppression list,
  dan jangan spam. Rate-limit manual: kirim bertahap via antrean + jeda
  antar share.
