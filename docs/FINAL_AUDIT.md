# FINAL AUDIT — Wasender + Wabadak v1.0.0 (2026-10-14, Asia/Jakarta)

Repo: https://github.com/linducip2208/wasenderflutter (branch `main`).

## Ringkasan fitur selesai
- 16 layar Android: splash, aktivasi, dashboard (kartu due), koneksi, kontak
  (CRUD, label, filter label, impor/ekspor CSV), grup kontak (CRUD + anggota +
  filter kampanye), suppression list, template, compose (pratinjau, konfirmasi,
  pilih-semua, jadwal WIB), antrean (share intent, pause/cancel/resume, riwayat
  percobaan, banner due), riwayat, laporan CSV, inbox (arsip, pencarian, catat
  manual + notifikasi lazy-permission), chat (balasan share, quick reply,
  label+catatan), pengaturan, storage (backup/restore/wipe), log audit, tentang.
- Label aplikasi: "Wasender + Wabadak". CI GitHub Actions (format+analyze+test).
- Lisensi penuh: 7 state, device binding, cache aman, policy expiry waktu
  server, revalidasi, pesan konfigurasi jujur saat base URL kosong.
- SQLite v4 + 12 tabel + FTS + migrasi v1→v4 + recovery DB korup + backup/restore
  JSON + audit log + impor CSV tervalidasi + dedup per-msisdn di kode.
- Keamanan: secure storage sesi+lisensi, tanpa secret di source/repo, permission
  minimal (INTERNET, NETWORK_STATE, POST_NOTIFICATIONS), sanitasi CSV, batas
  media 10 MB. Keystore upload + key.properties di-.gitignore, TIDAK di-push.

## Fitur gagal / diblokir (jujur)
- **BLOCKED — koneksi protokol WA langsung** (QR login, socket, auto-receive,
  receipt delivered/read): tidak ada library Dart/Flutter yang terbukti lokal di
  APK (bukti: docs/WHATSAPP_COMPATIBILITY.md). `BlockedProtocolAdapter` + banner
  UI menyatakan ini; bukan "selesai".
- **Menunggu eksternal — 2 endpoint keygen** (kontrak: docs/LICENSE_API.md) dan
  eksekusi `integration_test` di HP fisik (tidak ada perangkat Android di
  lingkungan build ini).

## Verifikasi (terakhir, sesi ini)
- `flutter analyze`: **No issues found** (0 error/warning/info).
- `flutter test`: **30/30 lulus**.
- Integration test emulator (API 37): **2/2 skenario lulus**; menemukan &
  memperbaiki bug `AppScope.of` di `initState`. Rincian: docs/TESTING.md.
- Release APK upload-signed, terverifikasi apksigner:
  `Signer DN: CN=Wasender Wabadak, OU=Mobile, O=Wasender, L=Jakarta, C=ID`
  (bukan Android Debug). Desugaring diaktifkan untuk flutter_local_notifications.
- Grep lib: tanpa TODO/dummy/secret. Semua tanggal via Asia/Jakarta.
- Tanpa web admin / backend WA tersembunyi (hanya client HTTP keygen).
- Git: `git status` sebelum push diverifikasi bebas key.properties/*.jks/build.

## Lokasi APK (terverifikasi ada)
- `build/app/outputs/flutter-apk/app-debug.apk` (150,2 MB)
- `build/app/outputs/flutter-apk/app-release.apk` (56,8 MB, upload-signed)

## Cara uji di HP
Pasang release APK → isi base URL + key → tambah kontak/grup → tulis kampanye →
kirim via WA resmi → cek antrean/riwayat/laporan → inbox catat manual + balas →
backup/restore. `flutter test integration_test` saat HP tersambung.

## Risiko & batasan
Protokol WA dapat berubah sepihak; hormati opt-in + kirim bertahap. Jadwal tidak
tepat-waktu bila app di-force-stop/baterai dibatasi (banner due + disclaimer di
UI). Lisensi otoritatif di keygen; client tidak anti-crack total.

## File (repo, 60+ file)
`lib/` 25 file (main, app, config, core×3, whatsapp×2, license, data,
features×14, widgets), `test/` 5, `integration_test/` 1, `docs/` 8, README,
pubspec, AndroidManifest, build.gradle.kts (upload signing + desugar).
Env: Flutter 3.41.6 / Dart 3.11.4 / SDK 36.1.0 / JDK 21.
