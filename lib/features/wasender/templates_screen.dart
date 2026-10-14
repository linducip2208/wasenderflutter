import 'package:flutter/material.dart';
import '../../app.dart';
import '../../core/result.dart';
import '../../data/database.dart';
import '../../widgets/states.dart';

class TemplatesScreen extends StatefulWidget {
  const TemplatesScreen({super.key});
  @override
  State<TemplatesScreen> createState() => _T();
}

class _T extends State<TemplatesScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    _items = await TemplateRepo(AppScope.of(context).adb).list();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _edit({Map<String, dynamic>? t}) async {
    final name = TextEditingController(text: '${t?['name'] ?? ''}');
    final body = TextEditingController(text: '${t?['body'] ?? ''}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(t == null ? 'Template baru' : 'Edit template'),
        content: SingleChildScrollView(
          child: Column(
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
                controller: body,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Isi (gunakan {{nama}})',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
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
    if (name.text.trim().isEmpty || body.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama dan isi wajib diisi.')),
      );
      return;
    }
    final now = DateTime.now().toUtc().toIso8601String();
    await TemplateRepo(AppScope.of(context).adb).upsert({
      'id': t?['id'] ?? newId(),
      'name': name.text.trim(),
      'body': body.text,
      'category': t?['category'] ?? 'general',
      'created_at': t?['created_at'] ?? now,
      'updated_at': now,
    });
    _reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Template')),
    floatingActionButton: FloatingActionButton(
      onPressed: () => _edit(),
      child: const Icon(Icons.add),
    ),
    body: _loading
        ? const LoadingView()
        : _items.isEmpty
        ? EmptyView(
            icon: Icons.abc,
            title: 'Belum ada template',
            subtitle: 'Contoh: Halo {{nama}}, promo hari ini ...',
            action: FilledButton(
              onPressed: () => _edit(),
              child: const Text('Buat template'),
            ),
          )
        : ListView.builder(
            itemCount: _items.length,
            itemBuilder: (c, i) {
              final t = _items[i];
              final vars = templateVars('${t['body']}').join(', ');
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text('${t['name']}'),
                  subtitle: Text(
                    '${t['body']}${vars.isEmpty ? '' : '\nVariabel: $vars'}',
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) async {
                      final adb = AppScope.of(context).adb;
                      if (v == 'edit') {
                        _edit(t: t);
                      } else {
                        final ok = await confirmDestructive(
                          context,
                          title: 'Hapus template?',
                          message: 'Template ${t['name']} dihapus permanen.',
                        );
                        if (ok) {
                          await TemplateRepo(adb).remove('${t['id']}');
                          _reload();
                        }
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'del', child: Text('Hapus')),
                    ],
                  ),
                ),
              );
            },
          ),
  );
}
