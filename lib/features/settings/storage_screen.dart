import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../app.dart';
import '../../widgets/states.dart';

class StorageScreen extends StatefulWidget {
  const StorageScreen({super.key});
  @override
  State<StorageScreen> createState() => _S();
}

class _S extends State<StorageScreen> {
  String? _info;
  bool _busy = false;

  Future<void> _backup() async {
    setState(() => _busy = true);
    try {
      final adb = AppScope.of(context).adb;
      final json = await adb.exportBackupJson();
      final dir = await getApplicationDocumentsDirectory();
      final f = File(
        '${dir.path}/backup-wasender-${DateTime.now().millisecondsSinceEpoch}.json',
      );
      await f.writeAsString(json);
      // Catatan jujur: backup JSON berisi data lokal (termasuk isi pesan).
      // Simpan di lokasi aman; file tidak dienkripsi.
      setState(
        () => _info =
            'Backup tersimpan (TIDAK terenkripsi, lindungi file ini):\n${f.path}',
      );
    } catch (e) {
      setState(() => _info = 'Gagal backup: $e');
    }
    setState(() => _busy = false);
  }

  Future<void> _restore() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (r == null || r.files.first.bytes == null) return;
    if (!mounted) return;
    final ok = await confirmDestructive(
      context,
      title: 'Restore backup?',
      message: 'Data lokal saat ini akan DIGANTI seluruhnya oleh file backup.',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await AppScope.of(
        context,
      ).adb.importBackupJson(String.fromCharCodes(r.files.first.bytes!));
      setState(() => _info = 'Restore berhasil.');
    } catch (e) {
      setState(() => _info = 'Gagal restore: $e');
    }
    setState(() => _busy = false);
  }

  Future<void> _wipe() async {
    final ok = await confirmDestructive(
      context,
      title: 'Hapus seluruh data lokal?',
      message:
          'Kontak, kampanye, antrean, percakapan, dan pesan di perangkat ini akan dihapus permanen.',
    );
    if (!ok || !mounted) return;
    final adb = AppScope.of(context).adb;
    for (final t in [
      'delivery_attempts',
      'message_queue',
      'campaign_recipients',
      'messages',
      'conversations',
      'campaigns',
      'message_templates',
      'contact_group_members',
      'contact_groups',
      'contacts',
    ]) {
      await adb.db.delete(t);
    }
    await adb.audit('wipe', 'penghapusan data oleh pengguna');
    if (mounted) {
      setState(() => _info = 'Seluruh data lokal dihapus.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Penyimpanan & backup')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Backup berisi data lokal termasuk isi pesan — file TIDAK terenkripsi. '
          'Jangan bagikan sembarangan. Sesi sensitif tetap di secure storage dan '
          'tidak ikut dalam file backup JSON.',
          style: TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _busy ? null : _backup,
          child: Text(_busy ? 'Memproses...' : 'Buat backup (JSON)'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _busy ? null : _restore,
          child: const Text('Restore dari file'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: _busy ? null : _wipe,
          child: const Text('Hapus seluruh data lokal'),
        ),
        if (_info != null) ...[
          const SizedBox(height: 16),
          SelectableText(_info!),
        ],
      ],
    ),
  );
}
