import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../app.dart';
import '../../data/database.dart';
import '../../widgets/states.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _R();
}

class _R extends State<ReportsScreen> {
  Map<String, int> _totals = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final adb = AppScope.of(context).adb;
    final rows = await adb.db.rawQuery(
      'SELECT status, COUNT(*) n FROM campaign_recipients GROUP BY status',
    );
    final m = <String, int>{};
    for (final r in rows) {
      m['${r['status']}'] = (r['n'] as int?) ?? 0;
    }
    _totals = m;
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _export() async {
    final adb = AppScope.of(context).adb;
    final rows = await adb.db.query('campaign_recipients', limit: 5000);
    final csv = toCsv(
      ['campaign_id', 'msisdn', 'status', 'attempts', 'last_error'],
      rows
          .map(
            (r) => [
              r['campaign_id'],
              r['msisdn'],
              r['status'],
              r['attempts'],
              r['last_error'],
            ],
          )
          .toList(),
    );
    final dir = await getApplicationDocumentsDirectory();
    final f = File(
      '${dir.path}/laporan-${DateTime.now().millisecondsSinceEpoch}.csv',
    );
    await f.writeAsString(csv);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('CSV tersimpan: ${f.path}')));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Laporan')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _export,
      icon: const Icon(Icons.download),
      label: const Text('Ekspor CSV'),
    ),
    body: _loading
        ? const LoadingView()
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Statistik dihitung dari data nyata database lokal.'),
              const SizedBox(height: 12),
              for (final e in _totals.entries)
                Card(
                  child: ListTile(
                    title: Text(e.key),
                    trailing: Text(
                      '${e.value}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              if (_totals.isEmpty)
                const EmptyView(
                  icon: Icons.bar_chart,
                  title: 'Belum ada data',
                  subtitle: 'Kirim kampanye dulu untuk melihat statistik.',
                ),
            ],
          ),
  );
}
