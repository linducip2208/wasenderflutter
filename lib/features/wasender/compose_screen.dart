import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app.dart';
import '../../core/jakarta_time.dart';
import '../../core/result.dart';
import '../../data/database.dart';

class ComposeScreen extends StatefulWidget {
  const ComposeScreen({super.key});
  @override
  State<ComposeScreen> createState() => _C();
}

class _C extends State<ComposeScreen> {
  final _name = TextEditingController();
  final _body = TextEditingController();
  List<Map<String, dynamic>> _contacts = [];
  List<Map<String, dynamic>> _templates = [];
  List<Map<String, dynamic>> _groups = [];
  String? _groupFilter;
  final _selected = <String>{};
  bool _onlyConsented = true;
  bool _busy = false;
  DateTime? _scheduledAt;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final adb = AppScope.of(context).adb;
    _contacts = await ContactRepo(adb).list(limit: 500);
    _templates = await TemplateRepo(adb).list();
    _groups = await GroupRepo(adb).list();
    if (mounted) setState(() {});
  }

  Future<void> _applyGroupFilter(String? groupId) async {
    setState(() => _groupFilter = groupId);
    final adb = AppScope.of(context).adb;
    _contacts = await ContactRepo(adb).list(limit: 500, groupId: groupId);
    if (mounted) setState(() {});
  }

  List<Map<String, dynamic>> get _targets {
    var list = _contacts.where((c) => _selected.contains('${c['id']}'));
    if (_onlyConsented) {
      list = list.where((c) => (c['consented'] as int? ?? 0) == 1);
    }
    list = list.where((c) => (c['suppressed'] as int? ?? 0) == 0);
    return list.toList();
  }

  String _preview() {
    if (_targets.isEmpty) return _body.text;
    final first = _targets.first;
    return renderTemplate(_body.text, {
      'nama': '${first['name']}',
      'nomor': '${first['msisdn']}',
    });
  }

  Future<void> _pickSchedule() async {
    final now = nowJakarta();
    final d = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (t == null) return;
    setState(() {
      _scheduledAt = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    });
  }

  Future<void> _enqueue() async {
    if (_name.text.trim().isEmpty) {
      _snack('Nama kampanye wajib diisi.');
      return;
    }
    if (_body.text.trim().isEmpty) {
      _snack('Isi pesan wajib diisi.');
      return;
    }
    if (_targets.isEmpty) {
      _snack('Pilih minimal 1 penerima (lolos opt-in & suppression).');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Konfirmasi kirim'),
        content: Text(
          'Kirim ke ${_targets.length} penerima? Hormati persetujuan & batas pengiriman. '
          'Jadwal (WIB): ${_scheduledAt == null ? 'sekarang' : formatJakartaFull(_scheduledAt!)}.\n\n'
          'Pratinjau penerima pertama:\n${_preview()}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Masuk antrean'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final adb = AppScope.of(context).adb;
    final now = DateTime.now().toUtc().toIso8601String();
    final campId = newId();
    await adb.db.insert('campaigns', {
      'id': campId,
      'name': _name.text.trim(),
      'body': _body.text,
      'status': 'queued',
      'scheduled_at': _scheduledAt?.toUtc().toIso8601String(),
      'created_at': now,
    });
    for (final c in _targets) {
      final rendered = renderTemplate(_body.text, {
        'nama': '${c['name']}',
        'nomor': '${c['msisdn']}',
      });
      final rid = newId();
      await adb.db.insert('campaign_recipients', {
        'id': rid,
        'campaign_id': campId,
        'contact_id': '${c['id']}',
        'msisdn': '${c['msisdn']}',
        'rendered_body': rendered,
        'status': 'pending',
        'updated_at': now,
      });
      await adb.db.insert('message_queue', {
        'id': newId(),
        'campaign_id': campId,
        'contact_id': '${c['id']}',
        'msisdn': '${c['msisdn']}',
        'body': rendered,
        'status': 'pending',
        'next_at': (_scheduledAt ?? DateTime.now()).toUtc().toIso8601String(),
        'created_at': now,
      });
    }
    await adb.audit('campaign_enqueue', '$campId:${_targets.length}');
    if (!mounted) return;
    setState(() => _busy = false);
    Navigator.pushReplacementNamed(context, '/queue');
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _sendNowSingle(Map<String, dynamic> c) async {
    final text = renderTemplate(_body.text.isEmpty ? 'Halo!' : _body.text, {
      'nama': '${c['name']}',
      'nomor': '${c['msisdn']}',
    });
    final uri = Uri.parse(
      'https://wa.me/${c['msisdn']}?text=${Uri.encodeComponent(text)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await Share.share(text);
    }
    if (!mounted) return;
    final adb = AppScope.of(context).adb;
    final conv = InboxRepo(adb);
    final id = await conv.ensureConversation(
      contactId: '${c['id']}',
      chatJid: '${c['msisdn']}@s.whatsapp.net',
      title: '${c['name']}',
    );
    await conv.addMessage(
      conversationId: id,
      direction: 'outbound',
      body: text,
      status: 'sent',
    );
    _snack('Dibuka via aplikasi WA resmi (status: sent, bukan delivered).');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tulis kampanye')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _name,
          decoration: const InputDecoration(
            labelText: 'Nama kampanye',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        if (_templates.isNotEmpty)
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: 'Pakai template',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(
                value: '',
                child: Text('— tulis manual —'),
              ),
              for (final t in _templates)
                DropdownMenuItem(
                  value: '${t['body']}',
                  child: Text('${t['name']}'),
                ),
            ],
            onChanged: (v) {
              if (v != null && v.isNotEmpty) {
                _body.text = v;
                setState(() {});
              }
            },
          ),
        const SizedBox(height: 12),
        TextField(
          controller: _body,
          maxLines: 5,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Isi pesan ({{nama}})',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text('Pratinjau:\n${_preview()}'),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          value: _onlyConsented,
          onChanged: (v) => setState(() => _onlyConsented = v),
          title: const Text('Hanya penerima opt-in & non-suppression'),
          contentPadding: EdgeInsets.zero,
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.schedule),
          title: Text(
            _scheduledAt == null
                ? 'Kirim sekarang'
                : 'Jadwal (WIB): ${formatJakartaFull(_scheduledAt!)}',
          ),
          trailing: TextButton(
            onPressed: _pickSchedule,
            child: const Text('Atur jadwal'),
          ),
        ),
        const Text(
          'Jadwal berjalan saat Android mengizinkan eksekusi. Jika aplikasi '
          'dihentikan paksa / perangkat mati / dibatasi baterai, pengiriman '
          'tertunda — bukan tepat waktu yang dijamin.',
          style: TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 12),
        Text(
          'Penerima (${_targets.length} lolos filter)',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        if (_groups.isNotEmpty)
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Semua'),
                selected: _groupFilter == null,
                onSelected: (_) => _applyGroupFilter(null),
              ),
              for (final g in _groups)
                ChoiceChip(
                  label: Text('${g['name']} (${g['member_count']})'),
                  selected: _groupFilter == '${g['id']}',
                  onSelected: (_) => _applyGroupFilter('${g['id']}'),
                ),
            ],
          ),
        Row(
          children: [
            TextButton(
              onPressed: () => setState(() {
                for (final c in _contacts) {
                  _selected.add('${c['id']}');
                }
              }),
              child: const Text('Pilih semua tampil'),
            ),
            TextButton(
              onPressed: () => setState(() => _selected.clear()),
              child: const Text('Bersihkan'),
            ),
          ],
        ),
        ..._contacts.map(
          (c) => CheckboxListTile(
            value: _selected.contains('${c['id']}'),
            onChanged: (v) => setState(() {
              if (v == true) {
                _selected.add('${c['id']}');
              } else {
                _selected.remove('${c['id']}');
              }
            }),
            title: Text('${c['name']}'),
            subtitle: Text('${c['msisdn']}'),
            secondary: IconButton(
              icon: const Icon(Icons.send),
              tooltip: 'Kirim langsung via WA resmi',
              onPressed: () => _sendNowSingle(c),
            ),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _enqueue,
          child: Text(
            _busy ? 'Menyimpan...' : 'Masukkan ${_targets.length} ke antrean',
          ),
        ),
      ],
    ),
  );
}
