# Rilis

## Versioning
`pubspec.yaml` → `1.0.0+1` (versionName/versionCode Android).

## Signing produksi (jangan commit keystore/password)
Keystore upload sudah dibuat lokal: `android/wasender-upload.jks` + konfigurasi
`android/key.properties` (keduanya di-.gitignore, TIDAK masuk repo).
`android/app/build.gradle.kts` memakai signing `upload` bila file ada, fallback
`debug` bila tidak ada. Verifikasi:
```powershell
D:\sdk\build-tools\36.1.0\apksigner.bat verify --print-certs build\app\outputs\flutter-apk\app-release.apk
# Signer #1 certificate DN: CN=Wasender Wabadak, ... (bukan Android Debug)
```
Untuk keystore lain/baru, timpa file di atas (JANGAN commit) atau sesuaikan
`android/key.properties`:
```properties
storePassword=***
keyPassword=***
keyAlias=upload
storeFile=wasender-upload.jks
```
Jangan mencetak password/token ke log CI. Backup keystore + password di tempat
aman di luar repo — kehilangan = tidak bisa update rilis Play Store dengan
sertifikat sama.

## App bundle Play Store
```powershell
flutter build appbundle --release
# -> build/app/outputs/bundle/release/app-release.aab (upload-signed)
```
Unggah AAB ke Play Console (format yang diminta Google Play). APK tetap untuk
distribusi langsung (sideload).

## Checklist rilis
- [ ] `flutter analyze` bersih, `flutter test` hijau.
- [ ] `docs/FINAL_AUDIT.md` menyatakan status BLOCKED apa adanya.
- [ ] Uji di HP fisik: aktivasi, kirim share, inbox manual, backup/restore.
- [ ] `flutter build apk --release` / `--split-per-abi` bila perlu.
- [ ] Simpan APK + SHA256 di tempat aman; catat lokasi di laporan.
