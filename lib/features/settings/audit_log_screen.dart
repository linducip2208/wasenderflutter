import 'package:flutter/material.dart';
import '../../app.dart';
import '../../core/jakarta_time.dart';
import '../../widgets/states.dart';

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});
  @override
  State<AuditLogScreen> createState() => _A();
}

class _A extends State<AuditLogScreen> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    _rows = await AppScope.of(
      context,
    ).adb.db.query('local_audit_logs', orderBy: 'at DESC', limit: 300);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _clear() async {
    final ok = await confirmDestructive(
      context,
      title: 'Hapus log audit?',
      message: 'Seluruh catatan audit lokal akan dihapus.',
    );
    if (!ok || !mounted) return;
    await AppScope.of(context).adb.db.delete('local_audit_logs');
    _reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Log audit'),
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_sweep_outlined),
          tooltip: 'Hapus log',
          onPressed: _clear,
        ),
      ],
    ),
    body: _loading
        ? const LoadingView()
        : _rows.isEmpty
        ? const EmptyView(
            icon: Icons.receipt_long_outlined,
            title: 'Log kosong',
            subtitle:
                'Aktivitas (impor, kampanye, hapus data) dicatat di sini tanpa isi pesan/token.',
          )
        : RefreshIndicator(
            onRefresh: _reload,
            child: ListView.builder(
              itemCount: _rows.length,
              itemBuilder: (c, i) {
                final r = _rows[i];
                DateTime? at;
                try {
                  at = DateTime.parse('${r['at']}').toLocal();
                } catch (_) {}
                return ListTile(
                  leading: const Icon(Icons.history),
                  title: Text('${r['action']}'),
                  subtitle: Text(
                    '${at == null ? '-' : formatJakarta(at)}'
                    '${('${r['detail'] ?? ''}').isEmpty ? '' : ' • ${r['detail']}'}',
                  ),
                );
              },
            ),
          ),
  );
}
