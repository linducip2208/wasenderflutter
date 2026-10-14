import 'package:flutter/material.dart';
import '../../app.dart';
import '../../data/database.dart';
import '../../widgets/states.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});
  @override
  State<GroupsScreen> createState() => _G();
}

class _G extends State<GroupsScreen> {
  List<Map<String, dynamic>> _groups = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    _groups = await GroupRepo(AppScope.of(context).adb).list();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _upsert({Map<String, dynamic>? g}) async {
    final name = TextEditingController(text: '${g?['name'] ?? ''}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(g == null ? 'Grup baru' : 'Ubah nama grup'),
        content: TextField(
          controller: name,
          decoration: const InputDecoration(
            labelText: 'Nama grup',
            border: OutlineInputBorder(),
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
    if (name.text.trim().isEmpty) return;
    final repo = GroupRepo(AppScope.of(context).adb);
    try {
      if (g == null) {
        await repo.create(name.text);
      } else {
        await repo.rename('${g['id']}', name.text);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal menyimpan grup: $e')));
      }
      return;
    }
    _reload();
  }

  Future<void> _members(Map<String, dynamic> g) async {
    final adb = AppScope.of(context).adb;
    final all = await ContactRepo(adb).list(limit: 1000);
    final sel = await GroupRepo(adb).memberIds('${g['id']}');
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setS) => AlertDialog(
          title: Text('Anggota: ${g['name']}'),
          content: SizedBox(
            width: double.maxFinite,
            height: 360,
            child: all.isEmpty
                ? const Text('Belum ada kontak.')
                : ListView.builder(
                    itemCount: all.length,
                    itemBuilder: (c, i) {
                      final ct = all[i];
                      final id = '${ct['id']}';
                      return CheckboxListTile(
                        value: sel.contains(id),
                        onChanged: (v) => setS(() {
                          if (v == true) {
                            sel.add(id);
                          } else {
                            sel.remove(id);
                          }
                        }),
                        title: Text('${ct['name']}'),
                        subtitle: Text('${ct['msisdn']}'),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      );
                    },
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
      ),
    );
    if (ok == true) {
      await GroupRepo(adb).setMembers('${g['id']}', sel);
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Grup kontak')),
    floatingActionButton: FloatingActionButton(
      onPressed: () => _upsert(),
      child: const Icon(Icons.add),
    ),
    body: _loading
        ? const LoadingView()
        : _groups.isEmpty
        ? EmptyView(
            icon: Icons.group_outlined,
            title: 'Belum ada grup',
            subtitle:
                'Contoh: Pelanggan, Reseller, VIP. Grup dipakai memfilter penerima kampanye.',
            action: FilledButton(
              onPressed: () => _upsert(),
              child: const Text('Buat grup'),
            ),
          )
        : RefreshIndicator(
            onRefresh: _reload,
            child: ListView.builder(
              itemCount: _groups.length,
              itemBuilder: (c, i) {
                final g = _groups[i];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.group),
                    title: Text('${g['name']}'),
                    subtitle: Text('${g['member_count']} anggota'),
                    onTap: () => _members(g),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) async {
                        final repo = GroupRepo(AppScope.of(context).adb);
                        if (v == 'members') {
                          _members(g);
                        } else if (v == 'rename') {
                          _upsert(g: g);
                        } else {
                          final ok = await confirmDestructive(
                            context,
                            title: 'Hapus grup?',
                            message:
                                'Grup ${g['name']} dihapus (kontak tidak ikut terhapus).',
                          );
                          if (ok) {
                            await repo.remove('${g['id']}');
                            _reload();
                          }
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'members',
                          child: Text('Kelola anggota'),
                        ),
                        PopupMenuItem(
                          value: 'rename',
                          child: Text('Ubah nama'),
                        ),
                        PopupMenuItem(value: 'del', child: Text('Hapus')),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
  );
}
