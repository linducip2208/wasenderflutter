import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app.dart';
import '../../data/database.dart';
import '../../widgets/states.dart';

class QueueScreen extends StatefulWidget {
  const QueueScreen({super.key});
  @override
  State<QueueScreen> createState() => _Q();
}

class _Q extends State<QueueScreen> {
  List<Map<String, dynamic>> _items = [];
  int _due = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final repo = QueueRepo(AppScope.of(context).adb);
    _items = await repo.list();
    _due = await repo.dueCount();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _shareItem(Map<String, dynamic> it) async {
    final adb = AppScope.of(context).adb;
    final uri = Uri.parse(
      'https://wa.me/${it['msisdn']}?text=${Uri.encodeComponent('${it['body']}')}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await Share.share('${it['body']}');
    }
    if (!mounted) return;
    await QueueWorker(adb).markShared('${it['id']}');
    // Sinkronkan status campaign_recipients + inbox.
    if (it['campaign_id'] != null) {
      await adb.db.update(
        'campaign_recipients',
        {'status': 'sent'},
        where: 'campaign_id = ? AND contact_id = ?',
        whereArgs: [it['campaign_id'], it['contact_id']],
      );
    }
    final conv = InboxRepo(adb);
    final cid = await conv.ensureConversation(
      contactId: it['contact_id'] == null ? null : '${it['contact_id']}',
      chatJid: '${it['msisdn']}@s.whatsapp.net',
      title: '${it['msisdn']}',
    );
    await conv.addMessage(
      conversationId: cid,
      direction: 'outbound',
      body: '${it['body']}',
      status: 'sent',
    );
    _reload();
  }

  Future<void> _failItem(Map<String, dynamic> it) async {
    await QueueWorker(
      AppScope.of(context).adb,
    ).markFailed('${it['id']}', 'Gagal dibuka / dibatalkan pengguna');
    _reload();
  }

  Future<void> _showAttempts(Map<String, dynamic> it) async {
    final rows = await QueueRepo(
      AppScope.of(context).adb,
    ).attempts('${it['id']}');
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Percobaan: ${it['msisdn']}'),
        content: SingleChildScrollView(
          child: rows.isEmpty
              ? const Text('Belum ada catatan percobaan.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final a in rows)
                      Text(
                        '• ${a['at']} — ${a['result']}${('${a['detail'] ?? ''}').isEmpty ? '' : ': ${a['detail']}'}',
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

  @override
  Widget build(BuildContext context) {
    final adb = AppScope.of(context).adb;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Antrean'),
        actions: [
          IconButton(
            icon: const Icon(Icons.pause),
            tooltip: 'Pause (tahan sending)',
            onPressed: () async {
              await QueueRepo(adb).pauseAll();
              _reload();
            },
          ),
          IconButton(
            icon: const Icon(Icons.cancel_outlined),
            tooltip: 'Cancel antrean pending',
            onPressed: () async {
              final ok = await confirmDestructive(
                context,
                title: 'Batalkan antrean?',
                message: 'Semua item pending/sending dibatalkan.',
              );
              if (ok) {
                await QueueRepo(adb).cancelPending();
                _reload();
              }
            },
          ),
        ],
      ),
      body: _loading
          ? const LoadingView()
          : _items.isEmpty
          ? const EmptyView(
              icon: Icons.hourglass_empty,
              title: 'Antrean kosong',
              subtitle: 'Buat kampanye dari menu Tulis kampanye.',
            )
          : RefreshIndicator(
              onRefresh: _reload,
              child: ListView.builder(
                itemCount: _items.length + (_due > 0 ? 1 : 0),
                itemBuilder: (c, i) {
                  if (_due > 0 && i == 0) {
                    return Card(
                      margin: const EdgeInsets.all(12),
                      color: Theme.of(c).colorScheme.primaryContainer,
                      child: ListTile(
                        leading: const Icon(Icons.alarm),
                        title: Text('$_due pesan jadwalnya tiba'),
                        subtitle: const Text(
                          'Ketuk ikon kirim per pesan untuk mengirim via aplikasi WA resmi.',
                        ),
                      ),
                    );
                  }
                  final it = _items[_due > 0 ? i - 1 : i];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: ListTile(
                      title: Text('${it['msisdn']}'),
                      subtitle: Text(
                        '${it['body']}\nStatus: ${it['status']} • percobaan ${it['attempts']}/${it['max_attempts']}'
                        '${('${it['last_error'] ?? ''}').isEmpty ? '' : '\nErr: ${it['last_error']}'}',
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if ('${it['status']}' == 'pending' ||
                              '${it['status']}' == 'sending')
                            IconButton(
                              icon: const Icon(Icons.send),
                              tooltip: 'Kirim via WA resmi',
                              onPressed: () => _shareItem(it),
                            ),
                          if ('${it['status']}' == 'pending')
                            IconButton(
                              icon: const Icon(Icons.close),
                              tooltip: 'Tandai gagal (retry backoff)',
                              onPressed: () => _failItem(it),
                            ),
                          if ('${it['status']}' == 'failed')
                            IconButton(
                              icon: const Icon(Icons.replay),
                              tooltip: 'Resume: ulangi dari percobaan 0',
                              onPressed: () async {
                                await QueueRepo(
                                  AppScope.of(context).adb,
                                ).resume('${it['id']}');
                                _reload();
                              },
                            ),
                          IconButton(
                            icon: const Icon(Icons.info_outline),
                            tooltip: 'Riwayat percobaan',
                            onPressed: () => _showAttempts(it),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
