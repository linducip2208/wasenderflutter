# Kontrak API Web Keygen (dibutuhkan dari web milik pemilik)

Aplikasi TIDAK mengasumsikan URL/skema. Konfigurasi base URL via
`--dart-define=LICENSE_BASE_URL=...` atau Pengaturan > Lisensi.
TLS normal, timeout 20 dtk. Tanpa API secret di APK.

## Endpoint yang harus disediakan web keygen

### 1. Aktivasi — `POST {base}/api/v1/licenses/activate`
Request:
```json
{
  "activation_key": "XXXX-XXXX",
  "product_id": "wasender_wabadak_android",
  "device_id": "<32 hex stabil>",
  "device_name": "Android-xxxxxxxx"
}
```
Response sukses (2xx), salah satu bentuk diterima:
```json
{ "data": {
  "license_id": "lic_123", "product_id": "wasender_wabadak_android",
  "status": "active", "activated_at": "2026-10-01T00:00:00Z",
  "expires_at": "2026-11-01T00:00:00Z", "device_limit": 2,
  "devices": ["<device_id>..."], "plan": "Bulanan 1" } }
```
atau flat tanpa envelope `data`. Field minimal: `license_id`, `product_id`,
`status`, `activated_at`, `expires_at`, `device_limit`, device binding
(`devices`), `revoked_at` bila dicabut.

### 2. Validasi — `GET {base}/api/v1/licenses/validate?license_id=..&device_id=..&product_id=..`
Response sama seperti aktivasi.

## Pemetaan status HTTP → LicenseState
- 2xx + `status: active/valid` → ACTIVE
- 2xx + `status: expired` → EXPIRED
- 2xx + `status: revoked/cancelled`, atau 403/410 → REVOKED
- 404/422 → INVALID
- timeout / socket / 5xx / JSON rusak → NETWORK_ERROR (pakai cache offline
  dalam batas toleransi) atau INVALID bila respons 2xx tapi tak terp-parse.

## Kebijakan yang sudah diimplementasikan di aplikasi
- Harian (1/3/7/14 hari), bulanan (1/3/6/12 bln), durasi khusus: didukung
  generik via `expires_at` dari keygen (keygen yang menetapkan).
- Berlaku sejak aktivasi pertama: didukung bila keygen mengisi `activated_at`
  saat aktivasi (bukan saat key dibuat).
- Aktivasi ulang sesuai `device_limit`; aktivasi melebihi batas harus ditolak
  keygen (HTTP 403 + status revoked/invalid + pesan jelas).
- Expiry memakai waktu server (header HTTP `Date` saat aktivasi/validasi);
  jam perangkat bukan satu-satunya sumber.
- Cache offline di secure storage; toleransi default 24 jam, dapat diubah
  (6/12/24/48/72). Setelah dicabut atau toleransi habis → akses ditolak.
- Tanpa base URL → layar menampilkan pesan konfigurasi, bukan "integrasi selesai".

## Checklist untuk pemilik keygen
- [ ] Sediakan 2 endpoint di atas dengan kontrak JSON ini.
- [ ] Kirim header `Date` (waktu server) di setiap respons.
- [ ] Tetapkan `expires_at` sesuai paket harian/bulanan/khusus.
- [ ] Tolak device melebihi `device_limit` dengan pesan eksplisit.
- [ ] Sediakan uji: key valid / invalid / expired / revoked / over-limit.
