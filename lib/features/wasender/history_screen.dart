import 'package:flutter/material.dart';
import '../../app.dart';
import '../../core/jakarta_time.dart';
import '../../data/database.dart';
import '../../widgets/states.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _H();
}

class _H extends State<HistoryScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    _items = await CampaignRepo(AppScope.of(context).adb).list();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Riwayat pengiriman')),
    body: _loading
        ? const LoadingView()
        : _items.isEmpty
        ? const EmptyView(
            icon: Icons.history,
            title: 'Belum ada kampanye',
            subtitle: 'Riwayat kampanye akan muncul di sini.',
          )
        : RefreshIndicator(
            onRefresh: _reload,
            child: ListView.builder(
              itemCount: _items.length,
              itemBuilder: (c, i) {
                final it = _items[i];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: ListTile(
                    title: Text('${it['name']}'),
                    subtitle: Text(
                      'Status: ${it['status']} • dibuat ${formatJakarta(DateTime.parse('${it['created_at']}').toLocal())}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _detail(it),
                  ),
                );
              },
            ),
          ),
  );

  Future<void> _detail(Map<String, dynamic> camp) async {
    final adb = AppScope.of(context).adb;
    final sum = await CampaignRepo(adb).summary('${camp['id']}');
    final recs = await adb.db.query(
      'campaign_recipients',
      where: 'campaign_id = ?',
      whereArgs: [camp['id']],
      limit: 200,
    );
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('${camp['name']}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Terkirim: ${sum['sent']} • Gagal: ${sum['failed']} • Menunggu: ${(sum['pending'] ?? 0) + (sum['sending'] ?? 0)}',
              ),
              const SizedBox(height: 8),
              const Text(
                'Catatan: "Terkirim" = berhasil dibuka via aplikasi WA resmi. '
                'Bukan delivered/read tanpa receipt nyata.',
                style: TextStyle(fontSize: 12),
              ),
              const Divider(),
              for (final r in recs)
                Text(
                  '• ${r['msisdn']} — ${r['status']}${('${r['last_error'] ?? ''}').isEmpty ? '' : ' (${r['last_error']})'}',
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }
}
