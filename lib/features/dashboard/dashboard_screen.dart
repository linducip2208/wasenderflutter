import 'package:flutter/material.dart';
import '../../app.dart';
import '../../data/database.dart';
import '../../whatsapp/protocol.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _D();
}

class _D extends State<DashboardScreen> {
  int _contacts = 0, _queued = 0, _convs = 0, _campaigns = 0, _due = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final adb = AppScope.of(context).adb;
    try {
      _contacts = await ContactRepo(adb).count();
      final q = await adb.db.rawQuery(
        "SELECT COUNT(*) n FROM message_queue WHERE status IN ('pending','sending')",
      );
      _queued = (q.first['n'] as int?) ?? 0;
      final c = await adb.db.rawQuery(
        'SELECT COUNT(*) n FROM conversations WHERE archived = 0',
      );
      _convs = (c.first['n'] as int?) ?? 0;
      final k = await adb.db.rawQuery('SELECT COUNT(*) n FROM campaigns');
      _campaigns = (k.first['n'] as int?) ?? 0;
      _due = await QueueRepo(adb).dueCount();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final lic = AppScope.of(context).license;
    final adapters = AppScope.of(context).adapters;
    final blocked = adapters.active is DeviceShareAdapter;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wasender + Wabadak'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (!lic.hasAccess)
                    Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: ListTile(
                        leading: const Icon(Icons.lock),
                        title: const Text('Lisensi tidak aktif'),
                        subtitle: Text(lic.statusMessage),
                        trailing: TextButton(
                          onPressed: () =>
                              Navigator.pushNamed(context, '/license'),
                          child: const Text('Aktivasi'),
                        ),
                      ),
                    ),
                  if (blocked)
                    Card(
                      color: Theme.of(context).colorScheme.tertiaryContainer,
                      child: const ListTile(
                        leading: Icon(Icons.info_outline),
                        title: Text('Mode pengiriman: aplikasi WA resmi'),
                        subtitle: Text(
                          'Koneksi protokol langsung BLOCKED (lihat Koneksi). '
                          'Pesan dikirim via aplikasi WhatsApp resmi, tanpa bypass enkripsi.',
                        ),
                      ),
                    ),
                  if (_due > 0)
                    Card(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: ListTile(
                        leading: const Icon(Icons.alarm),
                        title: Text('$_due pesan jadwalnya tiba'),
                        trailing: TextButton(
                          onPressed: () =>
                              Navigator.pushNamed(context, '/queue'),
                          child: const Text('Buka antrean'),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.4,
                    children: [
                      _stat(
                        context,
                        'Kontak',
                        '$_contacts',
                        Icons.people,
                        '/contacts',
                      ),
                      _stat(
                        context,
                        'Antrean',
                        '$_queued',
                        Icons.queue,
                        '/queue',
                      ),
                      _stat(
                        context,
                        'Percakapan',
                        '$_convs',
                        Icons.chat_bubble,
                        '/inbox',
                      ),
                      _stat(
                        context,
                        'Kampanye',
                        '$_campaigns',
                        Icons.campaign,
                        '/history',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Wasender',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  _tile(
                    context,
                    'Tulis & kirim kampanye',
                    Icons.send,
                    '/compose',
                  ),
                  _tile(
                    context,
                    'Antrean pengiriman',
                    Icons.hourglass_bottom,
                    '/queue',
                  ),
                  _tile(
                    context,
                    'Riwayat pengiriman',
                    Icons.history,
                    '/history',
                  ),
                  _tile(context, 'Laporan', Icons.bar_chart, '/reports'),
                  _tile(context, 'Kontak', Icons.contacts, '/contacts'),
                  _tile(context, 'Grup kontak', Icons.group, '/groups'),
                  _tile(
                    context,
                    'Suppression list',
                    Icons.block,
                    '/suppression',
                  ),
                  _tile(context, 'Template pesan', Icons.abc, '/templates'),
                  const SizedBox(height: 8),
                  Text(
                    'Wabadak',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  _tile(context, 'Inbox percakapan', Icons.inbox, '/inbox'),
                  _tile(context, 'Koneksi WhatsApp', Icons.link, '/connection'),
                  const SizedBox(height: 8),
                  Text(
                    'Lainnya',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  _tile(
                    context,
                    'Penyimpanan & backup',
                    Icons.storage,
                    '/storage',
                  ),
                  _tile(context, 'Pengaturan', Icons.settings, '/settings'),
                  _tile(context, 'Tentang & lisensi', Icons.info, '/about'),
                ],
              ),
            ),
    );
  }

  Widget _stat(
    BuildContext c,
    String label,
    String value,
    IconData icon,
    String route,
  ) {
    return Card(
      child: InkWell(
        onTap: () => Navigator.pushNamed(c, route),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Theme.of(c).colorScheme.primary),
              const SizedBox(height: 4),
              Text(value, style: Theme.of(c).textTheme.headlineSmall),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(BuildContext c, String label, IconData icon, String route) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.pushNamed(c, route),
      ),
    );
  }
}
