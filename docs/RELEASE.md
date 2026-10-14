# Rilis

## Versioning
`pubspec.yaml` → `1.0.0+1` (versionName/versionCode Android).

## Signing produksi (jangan commit keystore/password)
Buat `android/key.properties` (sudah di-.gitignore template? pastikan):
```properties
storePassword=***
keyPassword=***
keyAlias=upload
storeFile=C:/aman/wasender-upload.jks
```
Lalu di `android/app/build.gradle.kts` ganti blok `release` dengan
`signingConfigs` dari key.properties (lihat komentar TODO bawaan).
Jangan mencetak password/token ke log CI.

## Checklist rilis
- [ ] `flutter analyze` bersih, `flutter test` hijau.
- [ ] `docs/FINAL_AUDIT.md` menyatakan status BLOCKED apa adanya.
- [ ] Uji di HP fisik: aktivasi, kirim share, inbox manual, backup/restore.
- [ ] `flutter build apk --release` / `--split-per-abi` bila perlu.
- [ ] Simpan APK + SHA256 di tempat aman; catat lokasi di laporan.
