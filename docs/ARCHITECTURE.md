# Arsitektur Wasender + Wabadak

Aplikasi Android-native (Flutter/Dart). Seluruh UI & operasional di HP.
Tanpa web admin operasional, tanpa VPS backend WhatsApp.

```
lib/
  main.dart                 bootstrap (DB open + recovery, license boot)
  app.dart                  MaterialApp M3, routes, AppScope (DI sederhana)
  config/app_config.dart    APP_ID / LICENSE_BASE_URL via --dart-define
  core/
    jakarta_time.dart       satu-satunya sumber waktu tampilan (Asia/Jakarta)
    result.dart             OpResult, validasi MSISDN, renderTemplate, sanitasi CSV
  whatsapp/
    protocol.dart           WhatsAppAdapter + types + DeviceShareAdapter (AKTIF)
                            + BlockedProtocolAdapter (BLOCKED) + AdapterRegistry
    session_store.dart      SecureSessionStore (flutter_secure_storage/Keystore)
  license/
    license.dart            LicenseApiClient, DeviceBindingService,
                            SecureLicenseCache, LicenseValidationPolicy,
                            LicenseRepository (ChangeNotifier)
  data/
    database.dart           AppDatabase (sqflite, migrasi v1→v3), ContactRepo,
                            TemplateRepo, CampaignRepo, QueueRepo, InboxRepo,
                            SettingsRepo, QueueWorker (retry+backoff),
                            importContactsCsv, toCsv, backup/restore JSON
  features/
    splash/                 SplashScreen (routing berdasar status lisensi)
    license/                ActivationScreen, LicenseStatusScreen
    dashboard/              DashboardScreen (statistik nyata dari DB)
    connection/             ConnectionScreen (status adapter jujur)
    wasender/               contacts, templates, compose (kampanye+jadwal),
                            queue (share intent, pause/cancel), history, reports
    wabadak/                inbox (arsip, pencarian, catat manual), chat
                            (balasan share, quick reply, label+catatan)
    settings/               settings (base URL, cache), storage (backup/
                            restore/wipe), about (privasi ringkas)
  widgets/states.dart       Loading/Empty/Error, confirmDestructive, BlockedBanner
```

Prinsip:
- UI hanya bergantung pada abstraksi (`WhatsAppAdapter`, repo), bukan library konkret.
- Status pengiriman jujur: `sent` = dibuka via aplikasi WA resmi; tidak ada
  klaim `delivered/read` tanpa receipt nyata.
- Waktu tampil selalu Asia/Jakarta; waktu validitas lisensi memakai waktu server.
