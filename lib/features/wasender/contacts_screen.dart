import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../app.dart';
import '../../core/result.dart';
import '../../data/database.dart';
import '../../widgets/states.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});
  @override
  State<ContactsScreen> createState() => _C();
}

class _C extends State<ContactsScreen> {
  final _q = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  String? _labelFilter;
  bool _loading = true;
  String? _err;

  static List<String> labelsOf(Map<String, dynamic> row) {
    try {
      final v = jsonDecode('${row['labels'] ?? '[]'}');
      if (v is List) return v.map((e) => '$e').toList();
    } catch (_) {}
    return [];
  }

  List<String> get _allLabels {
    final s = <String>{};
    for (final it in _items) {
      s.addAll(labelsOf(it));
    }
    final l = s.toList()..sort();
    return l;
  }

  List<Map<String, dynamic>> get _visible {
    if (_labelFilter == null) return _items;
    return _items.where((it) => labelsOf(it).contains(_labelFilter)).toList();
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      _items = await ContactRepo(
        AppScope.of(context).adb,
      ).list(query: _q.text.trim());
    } catch (e) {
      _err = '$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _edit({Map<String, dynamic>? c}) async {
    final name = TextEditingController(text: '${c?['name'] ?? ''}');
    final phone = TextEditingController(text: '${c?['msisdn'] ?? ''}');
    final note = TextEditingController(text: '${c?['note'] ?? ''}');
    final labels = TextEditingController(
      text: c == null ? '' : _C.labelsOf(c).join(', '),
    );
    bool consented = ((c?['consented'] as int?) ?? 0) == 1;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setS) => AlertDialog(
          title: Text(c == null ? 'Tambah kontak' : 'Edit kontak'),
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
                  controller: phone,
                  decoration: const InputDecoration(
                    labelText: 'Nomor (08xx / 62xx)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: note,
                  decoration: const InputDecoration(
                    labelText: 'Catatan',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: labels,
                  decoration: const InputDecoration(
                    labelText: 'Label (pisah koma, mis. vip, reseller)',
                    border: OutlineInputBorder(),
                  ),
                ),
                CheckboxListTile(
                  value: consented,
                  onChanged: (v) => setS(() => consented = v ?? false),
                  title: const Text('Ada persetujuan penerima (opt-in)'),
                  contentPadding: EdgeInsets.zero,
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
    final labelList = labels.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(10)
        .map((e) => e.length > 30 ? e.substring(0, 30) : e)
        .toList();
    await ContactRepo(adb).upsert({
      'id': c?['id'] ?? newId(),
      'name': sanitizeCsvCell(name.text.trim(), maxLen: 200),
      'msisdn': normalizeMsisdn(phone.text.trim()),
      'note': sanitizeCsvCell(note.text.trim()),
      'labels': jsonEncode(labelList),
      'consented': consented ? 1 : 0,
      'suppressed': c?['suppressed'] ?? 0,
      'archived': c?['archived'] ?? 0,
      'created_at': c?['created_at'] ?? now,
      'updated_at': now,
    });
    await adb.audit('contact_upsert', normalizeMsisdn(phone.text.trim()));
    _reload();
  }

  Future<void> _exportCsv() async {
    final messenger = ScaffoldMessenger.of(context);
    final adb = AppScope.of(context).adb;
    final rows = await ContactRepo(adb).list(limit: 10000);
    final csv = toCsv([
      'name',
      'phone',
      'note',
    ], rows.map((r) => [r['name'], r['msisdn'], r['note']]).toList());
    final dir = await getApplicationDocumentsDirectory();
    final f = File(
      '${dir.path}/kontak-${DateTime.now().millisecondsSinceEpoch}.csv',
    );
    await f.writeAsString(csv);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text('CSV tersimpan (${rows.length}): ${f.path}')),
    );
  }

  Future<void> _importCsv() async {
    final adb = AppScope.of(context).adb;
    final messenger = ScaffoldMessenger.of(context);
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (r == null || r.files.first.bytes == null) return;
    final text = String.fromCharCodes(r.files.first.bytes!);
    final res = await importContactsCsv(adb, text);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text('Impor: ${res.imported} masuk, ${res.skipped} dilewati.'),
      ),
    );
    if (res.errors.isEmpty) {
      _reload();
      return;
    }
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Catatan impor'),
        content: SingleChildScrollView(child: Text(res.errors.join('\n'))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kontak'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Ekspor CSV',
            onPressed: _exportCsv,
          ),
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Impor CSV',
            onPressed: _importCsv,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _q,
              decoration: InputDecoration(
                hintText: 'Cari nama / nomor...',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _q.clear();
                    _reload();
                  },
                ),
              ),
              onSubmitted: (_) => _reload(),
            ),
          ),
          if (_allLabels.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('Semua'),
                    selected: _labelFilter == null,
                    onSelected: (_) => setState(() => _labelFilter = null),
                  ),
                  const SizedBox(width: 8),
                  for (final lb in _allLabels) ...[
                    ChoiceChip(
                      label: Text(lb),
                      selected: _labelFilter == lb,
                      onSelected: (_) => setState(
                        () => _labelFilter = _labelFilter == lb ? null : lb,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? const LoadingView()
                : _err != null
                ? ErrorView(message: _err!, onRetry: _reload)
                : _items.isEmpty
                ? EmptyView(
                    icon: Icons.people_outline,
                    title: 'Belum ada kontak',
                    subtitle:
                        'Tambah manual atau impor CSV (header: name,phone).',
                    action: FilledButton(
                      onPressed: () => _edit(),
                      child: const Text('Tambah kontak'),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _reload,
                    child: ListView.builder(
                      itemCount: _visible.length,
                      itemBuilder: (c, i) {
                        final it = _visible[i];
                        final consented = (it['consented'] as int? ?? 0) == 1;
                        final lbs = _C.labelsOf(it);
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              '${it['name']}'.characters.first.toUpperCase(),
                            ),
                          ),
                          title: Text('${it['name']}'),
                          subtitle: Text(
                            '${it['msisdn']}${consented ? ' • opt-in' : ' • tanpa opt-in'}'
                            '${lbs.isEmpty ? '' : '\n[${lbs.join(', ')}]'}',
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) async {
                              final adb = AppScope.of(context).adb;
                              if (v == 'edit') {
                                _edit(c: it);
                              } else if (v == 'del') {
                                final ok = await confirmDestructive(
                                  context,
                                  title: 'Hapus kontak?',
                                  message:
                                      'Kontak ${it['name']} akan dihapus permanen.',
                                );
                                if (ok) {
                                  await ContactRepo(adb).remove('${it['id']}');
                                  _reload();
                                }
                              } else if (v == 'supp') {
                                it['suppressed'] = 1;
                                await ContactRepo(adb).upsert(it);
                                _reload();
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(
                                value: 'supp',
                                child: Text('Masukkan suppression'),
                              ),
                              PopupMenuItem(value: 'del', child: Text('Hapus')),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
