import 'package:flutter/material.dart';
import '../../app.dart';
import '../../core/result.dart';
import '../../data/database.dart';
import '../../widgets/states.dart';

/// Daftar berhenti (suppression): nomor yang meminta berhenti / menolak pesan.
/// Nomor di daftar ini TIDAK PERNAH menjadi target kampanye (difilter di compose).
class SuppressionScreen extends StatefulWidget {
  const SuppressionScreen({super.key});
  @override
  State<SuppressionScreen> createState() => _S();
}

class _S extends State<SuppressionScreen> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    _rows = await AppScope.of(context).adb.db.query(
      'contacts',
      where: 'suppressed = 1',
      orderBy: 'name',
      limit: 500,
    );
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _add() async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Tambah ke suppression'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(
                labelText: 'Nama',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: phone,
              decoration: const InputDecoration(
                labelText: 'Nomor (08xx / 62xx)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final v = validateMsisdn(phone.text.trim());
    if (name.text.trim().isEmpty || v != null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(v ?? 'Nama wajib diisi.')));
      }
      return;
    }
    final adb = AppScope.of(context).adb;
    final now = DateTime.now().toUtc().toIso8601String();
    await ContactRepo(adb).upsert({
      'id': newId(),
      'name': sanitizeCsvCell(name.text.trim(), maxLen: 200),
      'msisdn': normalizeMsisdn(phone.text.trim()),
      'suppressed': 1,
      'created_at': now,
      'updated_at': now,
    });
    await adb.audit('suppression_add', normalizeMsisdn(phone.text.trim()));
    _reload();
  }

  Future<void> _remove(Map<String, dynamic> row) async {
    final ok = await confirmDestructive(
      context,
      title: 'Keluarkan dari suppression?',
      message:
          '${row['name']} dapat menjadi target kampanye lagi (tetap butuh opt-in).',
    );
    if (!ok || !mounted) return;
    final adb = AppScope.of(context).adb;
    final m = Map<String, dynamic>.from(row)
      ..['suppressed'] = 0
      ..['updated_at'] = DateTime.now().toUtc().toIso8601String();
    await ContactRepo(adb).upsert(m);
    await adb.audit('suppression_remove', '${row['msisdn']}');
    _reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Suppression list')),
    floatingActionButton: FloatingActionButton(
      onPressed: _add,
      child: const Icon(Icons.add),
    ),
    body: _loading
        ? const LoadingView()
        : _rows.isEmpty
        ? EmptyView(
            icon: Icons.block_outlined,
            title: 'Suppression kosong',
            subtitle:
                'Nomor yang meminta berhenti ditambahkan di sini dan dikecualikan dari kampanye.',
            action: FilledButton(
              onPressed: _add,
              child: const Text('Tambah nomor'),
            ),
          )
        : RefreshIndicator(
            onRefresh: _reload,
            child: ListView.builder(
              itemCount: _rows.length,
              itemBuilder: (c, i) {
                final r = _rows[i];
                return ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.block, size: 18),
                  ),
                  title: Text('${r['name']}'),
                  subtitle: Text('${r['msisdn']}'),
                  trailing: TextButton(
                    onPressed: () => _remove(r),
                    child: const Text('Keluarkan'),
                  ),
                );
              },
            ),
          ),
  );
}
