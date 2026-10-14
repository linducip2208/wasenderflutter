/// Konfigurasi aplikasi. applicationId dapat dioverride via
/// --dart-define=APP_ID=... atau --dart-define=LICENSE_BASE_URL=...
/// TIDAK ada secret yang di-hardcode di sini.
library;

class AppConfig {
  /// applicationId default; override build: --dart-define=APP_ID=com.contoh.app
  static const String applicationId = String.fromEnvironment(
    'APP_ID',
    defaultValue: 'com.wasender.wasender_wabadak',
  );

  /// Base URL web keygen milik pemilik aplikasi.
  /// Diset via --dart-define=LICENSE_BASE_URL=https://keygen.milik.anda
  /// atau via layar Pengaturan > Lisensi (tersimpan aman, bukan di source).
  static const String licenseBaseUrl = String.fromEnvironment(
    'LICENSE_BASE_URL',
    defaultValue: '',
  );

  static const String productId = String.fromEnvironment(
    'PRODUCT_ID',
    defaultValue: 'wasender_wabadak_android',
  );

  /// Batas cache offline lisensi (default 24 jam, dapat diubah di Pengaturan).
  static const int maxOfflineCacheHours = 24;

  /// Batas ukuran lampiran (10 MB).
  static const int maxMediaBytes = 10 * 1024 * 1024;

  static const List<String> allowedMediaExt = [
    'jpg',
    'jpeg',
    'png',
    'webp',
    'gif',
    'mp4',
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'txt',
    'mp3',
    'ogg',
  ];
}
