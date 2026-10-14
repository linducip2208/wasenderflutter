# Pengujian

```powershell
dart format .
flutter analyze
flutter test
flutter build apk --debug
flutter build apk --release   # bila signing aman tersedia
```

## Cakupan `flutter test`
- `test/license_policy_test.dart` — 7 skenario: valid, invalid, expired,
  revoked, network-error→cache, cache-habis→revalidasi, over-limit.
- `test/core_utils_test.dart` — validasi/normalisasi MSISDN, renderTemplate,
  sanitasi CSV, waktu Jakarta, backoff antrean.
- `test/api_parse_test.dart` — parsing respons keygen (envelope/flat, mapping
  status, HTTP error, JSON rusak).
- `test/widget_test.dart` — aktivasi (pesan konfigurasi saat base URL kosong),
  dashboard (4 kartu menu), inbox (banner BLOCKED tampil).

## Matriks manual (17 skenario brief)
1. Key valid → ACTIVE, masuk dashboard. 2. Key invalid → pesan jelas.
3. Key expired → EXPIRED. 4. Key revoked → akses ditolak. 5. API down →
   NETWORK_ERROR + cache. 6. Offline → cache dalam toleransi. 7. Cache habis →
   REVALIDATION_REQUIRED. 8. Over-limit → ditolak keygen. 9. QR langsung →
   BLOCKED + penjelasan. 10. Putus koneksi → banner + share tetap jalan.
11. DB kosong → empty states. 12. DB berisi → list+paginasi. 13. CSV invalid →
   error per baris. 14. Cancel antrean → status cancelled. 15. Restart app →
   boot license+DB recovery. 16. Backup/restore → round-trip JSON.
17. Grep: tanpa secret di source (`licenseBaseUrl` hanya via dart-define).

Integration test bernomor WA sungguhan & akses keygen produksi TIDAK
dipalsukan — dilakukan manual di HP oleh pemilik.
