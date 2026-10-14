import 'package:flutter/material.dart';
import '../../app.dart';
import '../../core/jakarta_time.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final lic = AppScope.of(context).license;
    return Scaffold(
      appBar: AppBar(title: const Text('Tentang & lisensi')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Wasender + Wabadak v1.0.0',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Aplikasi Android-native: seluruh UI & operasional di HP. Tanpa web admin, '
            'tanpa VPS backend WhatsApp. Pengiriman via aplikasi WhatsApp resmi; '
            'koneksi protokol langsung berstatus BLOCKED (lihat Koneksi & dokumen).',
            textAlign: TextAlign.justify,
          ),
          const Divider(height: 24),
          ListenableBuilder(
            listenable: lic,
            builder: (c, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Lisensi: ${lic.state.name}'),
                Text(lic.statusMessage),
                if (lic.data?.expiresAt != null)
                  Text(
                    'Berakhir: ${formatJakartaFull(lic.data!.expiresAt!.toLocal())} (WIB)',
                  ),
              ],
            ),
          ),
          const Divider(height: 24),
          const Text(
            'Kebijakan privasi (ringkas)',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            '• Data kontak, pesan, dan kampanye tersimpan lokal di perangkat.\n'
            '• Sesi & token lisensi di secure storage (Keystore-backed).\n'
            '• Tidak ada kredensial di source code APK.\n'
            '• Backup JSON tidak terenkripsi — jaga kerahasiaannya.\n'
            '• Hormati persetujuan penerima & permintaan berhenti (suppression).\n'
            '• Status lisensi otoritatif ada di web keygen Anda.',
            textAlign: TextAlign.left,
          ),
        ],
      ),
    );
  }
}
