import 'package:flutter/material.dart';
import '../../app.dart';
import '../../whatsapp/protocol.dart';
import '../../widgets/states.dart';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});
  @override
  State<ConnectionScreen> createState() => _C();
}

class _C extends State<ConnectionScreen> {
  @override
  Widget build(BuildContext context) {
    final adapters = AppScope.of(context).adapters;
    return Scaffold(
      appBar: AppBar(title: const Text('Koneksi WhatsApp')),
      body: ListView(
        children: [
          const BlockedBanner(BlockedProtocolAdapter.blockedReason),
          for (final a in adapters.all)
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                leading: Icon(
                  a.adapterId == 'device_share'
                      ? Icons.check_circle
                      : Icons.block,
                  color: a.adapterId == 'device_share'
                      ? Colors.green
                      : Theme.of(context).colorScheme.error,
                ),
                title: Text(a.displayName),
                subtitle: Text(_caps(a.capabilities)),
                trailing: Text(
                  a.adapterId == adapters.active.adapterId
                      ? 'AKTIF'
                      : (a.adapterId == 'device_share'
                            ? 'TERSEDIA'
                            : 'BLOCKED'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Pengiriman berjalan melalui aplikasi WhatsApp resmi yang terinstal '
              '(share intent / deep-link wa.me). Penerimaan otomatis dan QR login '
              'langsung membutuhkan adapter protokol yang terbukti berjalan lokal di '
              'Android — saat ini belum ada yang memenuhi syarat (lihat dokumen '
              'docs/WHATSAPP_COMPATIBILITY.md). Inbox Wabadak tetap mencatat riwayat '
              'lokal, balasan via share, label, catatan, dan arsip.',
              textAlign: TextAlign.justify,
            ),
          ),
        ],
      ),
    );
  }

  String _caps(AdapterCapabilities c) =>
      'QR:${c.supportsQrLogin ? "ya" : "tidak"} • '
      'langsung:${c.supportsDirectConnection ? "ya" : "tidak"} • '
      'terima-otomatis:${c.supportsAutoReceive ? "ya" : "tidak"} • '
      'media:${c.supportsMedia ? "ya" : "tidak"} • '
      'receipt:${c.supportsReceipts ? "ya" : "tidak"}';
}
