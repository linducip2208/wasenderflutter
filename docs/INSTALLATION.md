# Instalasi & Build

## Syarat
- Flutter 3.41+ (teruji 3.41.6), Dart 3.11+, Android SDK 34+, JDK 17+
- HP Android 8+ (minSdk bawaan Flutter) + aplikasi WhatsApp resmi terinstal

## Jalankan debug
```powershell
flutter pub get
flutter run
```

## Build APK
```powershell
flutter build apk --debug
# release dengan debug signing (bawaan template; ganti untuk produksi):
flutter build apk --release
```

## Konfigurasi build (tanpa hardcode secret)
```powershell
flutter build apk --release `
  --dart-define=APP_ID=com.perusahaan.wasender `
  --dart-define=LICENSE_BASE_URL=https://keygen.milik.anda `
  --dart-define=PRODUCT_ID=wasender_wabadak_android
```
`applicationId` default `com.wasender.wasender_wabadak` (lihat
`android/app/build.gradle.kts`); cocokkan dengan `APP_ID` bila diganti.

## Signing release produksi
1. Buat keystore sendiri, JANGAN commit ke repo.
2. Isi `android/key.properties` (contoh di `docs/RELEASE.md`).
3. Referensikan dari `build.gradle.kts`. Jangan mencetak password ke log.

## Troubleshooting
- `flutter doctor --android-licenses` bila toolchain mengeluh.
- `flutter clean; flutter pub get` bila Gradle cache korup.
- Jadwal kampanye tertunda bila HP mode hemat baterai / aplikasi di-force-stop
  (keterbatasan Android, didokumentasikan di UI).
