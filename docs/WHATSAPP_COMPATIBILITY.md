# Kompatibilitas WhatsApp — Hasil Audit (2026-10-14, jujur)

## Kesimpulan: koneksi protokol langsung = BLOCKED
Tidak ada library Dart/Flutter production-ready yang menjalankan protokol
WhatsApp E2E (Noise handshake + Signal + QR pairing + socket) lokal di APK.

## Yang diperiksa
| Library | Runtime | Andal di APK? | Alasan |
|---|---|---|---|
| Baileys (WhiskeySockets) | Node.js | TIDAK | Butuh Node; tidak bisa import ke Dart. Menjalankannya berarti server — dilarang brief. |
| whatsapp-web.js | Node + Chromium/puppeteer | TIDAK | Butuh browser/Node server. |
| whatsmeow | Go | TIDAK langsung | Perlu gomobile binding + maintenance protokol sendiri; belum ada binding teruji untuk repo ini. Jalur masa depan yang paling realistis. |
| wppconnect / venom | Node | TIDAK | Sama: server-side. |
| Paket pub `whatsapp_*` / share-wrapper | Dart | Sebagian | Hanya share intent / deep-link, BUKAN protokol. Itulah yang dipakai adapter aktif. |

## Yang dipakai sekarang (AKTIF, jujur)
`DeviceShareAdapter` (`lib/whatsapp/protocol.dart`):
- Mengirim via aplikasi WhatsApp resmi (share intent / `wa.me` deep-link).
- Memakai autentikasi & enkripsi resmi WhatsApp — tanpa bypass, tanpa socket sendiri.
- Status yang dilaporkan: `sent`/`unknown`, TIDAK PERNAH `delivered/read` palsu.
- Media: file diteruskan ke aplikasi resmi (batas 10 MB, ekstensi dibatasi).

## Yang belum tersedia (BLOCKED, bukan selesai)
- QR login & pairing langsung, socket koneksi, penerimaan otomatis (event sync),
  receipt delivered/read, pemulihan koneksi protokol.
- `BlockedProtocolAdapter` melempar `UnsupportedError` berisi penjelasan +
  rujukan dokumen ini. Layar Koneksi & Inbox menampilkan banner BLOCKED.
- Inbox tetap fungsional: riwayat lokal, pencatatan manual, balasan via share,
  label, catatan, arsip, quick reply, pencarian lokal.

## Jalur integrasi masa depan (tanpa mengubah UI)
Implementasikan `WhatsAppAdapter` baru (mis. binding gomobile whatsmeow via
platform channel), daftarkan di `AdapterRegistry`. UI tidak perlu ditulis ulang.
Jangan membuat kriptografi sendiri; ikuti protokol resmi & kebijakan WhatsApp.
Risiko: perubahan protokol sepihak, pemblokiran nomor spam — hormati opt-in,
rate-limit, dan suppression list (sudah ada di Wasender).
