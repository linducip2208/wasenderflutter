import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app.dart';
import '../../core/jakarta_time.dart';
import '../../data/database.dart';
import '../../widgets/states.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  const ChatScreen({super.key, required this.conversationId});
  @override
  State<ChatScreen> createState() => _Ch();
}

class _Ch extends State<ChatScreen> {
  final _text = TextEditingController();
  final _search = TextEditingController();
  List<Map<String, dynamic>> _msgs = [];
  Map<String, dynamic>? _conv;
  bool _loading = true;
  List<Map<String, dynamic>> _quick = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final adb = AppScope.of(context).adb;
    final c = await adb.db.query(
      'conversations',
      where: 'id = ?',
      whereArgs: [widget.conversationId],
      limit: 1,
    );
    _conv = c.isEmpty ? null : c.first;
    _msgs = await InboxRepo(adb).thread(widget.conversationId);
    _quick = await TemplateRepo(adb).list();
    await InboxRepo(adb).markRead(widget.conversationId);
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> get _filtered {
    if (_search.text.trim().isEmpty) return _msgs;
    final q = _search.text.toLowerCase();
    return _msgs
        .where((m) => '${m['body']}'.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _reply() async {
    final t = _text.text.trim();
    if (t.isEmpty) return;
    final adb = AppScope.of(context).adb;
    final jid = '${_conv?['chat_jid'] ?? ''}';
    final msisdn = jid.replaceAll('@s.whatsapp.net', '');
    final uri = Uri.parse(
      'https://wa.me/$msisdn?text=${Uri.encodeComponent(t)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await Share.share(t);
    }
    await InboxRepo(adb).addMessage(
      conversationId: widget.conversationId,
      direction: 'outbound',
      body: t,
      status: 'sent',
    );
    _text.clear();
    _reload();
  }

  Future<void> _editNoteLabel() async {
    final adb = AppScope.of(context).adb;
    final messenger = ScaffoldMessenger.of(context);
    final contactId = _conv?['contact_id'];
    if (contactId == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Percakapan ini belum terikat kontak lokal.'),
        ),
      );
      return;
    }
    final c = await adb.db.query(
      'contacts',
      where: 'id = ?',
      whereArgs: [contactId],
      limit: 1,
    );
    if (c.isEmpty) return;
    if (!mounted) return;
    final note = TextEditingController(text: '${c.first['note'] ?? ''}');
    final labels = TextEditingController(text: '${c.first['labels'] ?? '[]'}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Label & catatan kontak'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labels,
              decoration: const InputDecoration(
                labelText: 'Label (JSON, mis. ["vip"])',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: note,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Catatan',
                border: OutlineInputBorder(),
              ),
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
    if (ok != true) return;
    if (!mounted) return;
    final row = Map<String, dynamic>.from(c.first);
    row['note'] = note.text.trim();
    row['labels'] = labels.text.trim().isEmpty ? '[]' : labels.text.trim();
    row['updated_at'] = DateTime.now().toUtc().toIso8601String();
    await ContactRepo(adb).upsert(row);
    messenger.showSnackBar(const SnackBar(content: Text('Catatan tersimpan.')));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('${_conv?['title'] ?? 'Chat'}'),
      actions: [
        IconButton(
          icon: const Icon(Icons.note_alt_outlined),
          tooltip: 'Label & catatan',
          onPressed: _editNoteLabel,
        ),
        IconButton(
          icon: const Icon(Icons.archive_outlined),
          tooltip: 'Arsipkan',
          onPressed: () async {
            final nav = Navigator.of(context);
            final adb = AppScope.of(context).adb;
            await InboxRepo(adb).setArchived(widget.conversationId, true);
            nav.pop();
          },
        ),
      ],
    ),
    body: _loading
        ? const LoadingView()
        : _conv == null
        ? ErrorView(message: 'Percakapan tidak ditemukan.', onRetry: _reload)
        : Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Cari isi pesan tersimpan lokal...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              if (_quick.isNotEmpty)
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    children: [
                      for (final q in _quick)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            label: Text('${q['name']}'),
                            onPressed: () {
                              _text.text = '${q['body']}';
                              setState(() {});
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              Expanded(
                child: _filtered.isEmpty
                    ? const EmptyView(
                        icon: Icons.chat_bubble_outline,
                        title: 'Belum ada pesan',
                        subtitle: 'Kirim balasan pertama di bawah.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _filtered.length,
                        itemBuilder: (c, i) {
                          final m = _filtered[i];
                          final out = m['direction'] == 'outbound';
                          return Align(
                            alignment: out
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.all(10),
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(c).size.width * 0.78,
                              ),
                              decoration: BoxDecoration(
                                color: out
                                    ? Theme.of(c).colorScheme.primaryContainer
                                    : Theme.of(
                                        c,
                                      ).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${m['body']}'),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${formatJakarta(DateTime.parse('${m['at']}').toLocal(), pattern: 'dd MMM HH:mm')} • ${m['status']}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _text,
                          minLines: 1,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            hintText:
                                'Tulis balasan... (dikirim via aplikasi WA resmi)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _reply,
                        child: const Icon(Icons.send),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
  );
}
