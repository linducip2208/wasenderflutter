import 'package:flutter/material.dart';
import '../../app.dart';
import '../../core/notify.dart';
import '../../data/database.dart';
import '../../widgets/states.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});
  @override
  State<InboxScreen> createState() => _I();
}

class _I extends State<InboxScreen> {
  final _q = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _archived = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final adb = AppScope.of(context).adb;
    final repo = InboxRepo(adb);
    _items = await repo.conversations(
      archived: _archived,
      query: _q.text.trim(),
    );
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _logInbound() async {
    // Pencatatan manual pesan masuk (blm ada adapter auto-receive).
    final jid = TextEditingController();
    final body = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Catat pesan masuk'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: jid,
              decoration: const InputDecoration(
                labelText: 'Nomor (08xx/62xx)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: body,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Isi pesan',
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
    if (ok != true || !mounted) return;
    if (jid.text.trim().isEmpty || body.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nomor & isi wajib diisi.')));
      return;
    }
    final adb = AppScope.of(context).adb;
    final repo = InboxRepo(adb);
    final msisdn = jid.text.trim().replaceAll(RegExp(r'\D'), '');
    final id = await repo.ensureConversation(
      chatJid: '$msisdn@s.whatsapp.net',
      title: msisdn,
    );
    await repo.addMessage(
      conversationId: id,
      direction: 'inbound',
      body: body.text.trim(),
      status: 'sent',
    );
    await NotifyService.inbound('Pesan masuk: $msisdn', body.text.trim());
    _reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Wabadak Inbox'),
      actions: [
        IconButton(
          icon: Icon(_archived ? Icons.unarchive : Icons.archive_outlined),
          tooltip: _archived ? 'Lihat aktif' : 'Lihat arsip',
          onPressed: () {
            setState(() {
              _archived = !_archived;
              _loading = true;
            });
            _reload();
          },
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton(
      onPressed: _logInbound,
      tooltip: 'Catat pesan masuk',
      child: const Icon(Icons.add_comment),
    ),
    body: Column(
      children: [
        const BlockedBanner(
          'Penerimaan otomatis (sinkronisasi event saat koneksi aktif) BELUM tersedia — '
          'adapter protokol langsung berstatus BLOCKED. Gunakan pencatatan manual + balasan '
          'via aplikasi WA resmi. Tidak ada pesan palsu/receipt buatan.',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TextField(
            controller: _q,
            decoration: InputDecoration(
              hintText: 'Cari kontak / percakapan...',
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
        const SizedBox(height: 8),
        Expanded(
          child: _loading
              ? const LoadingView()
              : _items.isEmpty
              ? EmptyView(
                  icon: Icons.inbox_outlined,
                  title: _archived ? 'Arsip kosong' : 'Belum ada percakapan',
                  subtitle:
                      'Catat pesan masuk manual atau kirim dari Wasender.',
                  action: FilledButton(
                    onPressed: _logInbound,
                    child: const Text('Catat pesan masuk'),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (c, i) {
                      final it = _items[i];
                      final unread = (it['unread'] as int? ?? 0) == 1;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: unread
                              ? Theme.of(c).colorScheme.primary
                              : null,
                          child: Text(
                            '${it['title']}'.characters.first.toUpperCase(),
                          ),
                        ),
                        title: Text(
                          '${it['contact_name'] ?? it['title']}',
                          style: TextStyle(
                            fontWeight: unread
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text('${it['chat_jid'] ?? ''}'),
                        trailing: unread
                            ? const Icon(Icons.mark_chat_unread)
                            : const Icon(Icons.chevron_right),
                        onTap: () async {
                          await Navigator.pushNamed(
                            context,
                            '/chat',
                            arguments: {'conversationId': '${it['id']}'},
                          );
                          _reload();
                        },
                      );
                    },
                  ),
                ),
        ),
      ],
    ),
  );
}
