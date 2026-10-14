import 'package:flutter/material.dart';
import '../../app.dart';
import '../../core/jakarta_time.dart';

class LicenseStatusScreen extends StatefulWidget {
  const LicenseStatusScreen({super.key});
  @override
  State<LicenseStatusScreen> createState() => _L();
}

class _L extends State<LicenseStatusScreen> {
  bool _busy = false;

  Future<void> _revalidate() async {
    setState(() => _busy = true);
    await AppScope.of(context).license.revalidate();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final lic = AppScope.of(context).license;
    return Scaffold(
      appBar: AppBar(title: const Text('Status Lisensi')),
      body: ListenableBuilder(
        listenable: lic,
        builder: (c, _) {
          final d = lic.data;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              ListTile(
                leading: Icon(
                  lic.hasAccess ? Icons.verified : Icons.gpp_bad,
                  color: lic.hasAccess
                      ? Colors.green
                      : Theme.of(c).colorScheme.error,
                  size: 40,
                ),
                title: Text(lic.state.name),
                subtitle: Text(lic.statusMessage),
              ),
              const Divider(),
              if (d == null)
                const Text('Belum ada data lisensi tersimpan.')
              else ...[
                _row('License ID', d.licenseId),
                _row('Product', d.productId),
                if (d.planLabel != null) _row('Paket', d.planLabel!),
                _row('Status keygen', d.status),
                _row(
                  'Aktif sejak',
                  d.activatedAt == null
                      ? '-'
                      : formatJakartaFull(d.activatedAt!.toLocal()),
                ),
                _row(
                  'Berakhir',
                  d.expiresAt == null
                      ? '-'
                      : formatJakartaFull(d.expiresAt!.toLocal()),
                ),
                _row('Batas perangkat', '${d.deviceLimit}'),
                _row(
                  'Perangkat terikat',
                  d.devices.join(', ').isEmpty ? '-' : d.devices.join(', '),
                ),
                if (d.revokedAt != null)
                  _row('Dicabut', formatJakartaFull(d.revokedAt!.toLocal())),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _revalidate,
                child: Text(_busy ? 'Memvalidasi...' : 'Validasi ulang online'),
              ),
              TextButton(
                onPressed: () => Navigator.pushReplacementNamed(
                  context,
                  lic.hasAccess ? '/dashboard' : '/license',
                ),
                child: const Text('Kembali'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        Expanded(child: Text(v)),
      ],
    ),
  );
}
