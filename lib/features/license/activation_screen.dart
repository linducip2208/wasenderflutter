import 'package:flutter/material.dart';
import '../../app.dart';
import '../../license/license.dart';

class ActivationScreen extends StatefulWidget {
  const ActivationScreen({super.key});
  @override
  State<ActivationScreen> createState() => _A();
}

class _A extends State<ActivationScreen> {
  final _key = TextEditingController();
  final _url = TextEditingController();
  bool _busy = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    AppScope.of(context).license.api.effectiveBaseUrl().then((u) {
      if (mounted && u.isNotEmpty) _url.text = u;
    });
  }

  Future<void> _go() async {
    final lic = AppScope.of(context).license;
    if (_url.text.trim().isNotEmpty) {
      await lic.api.saveBaseUrl(_url.text.trim());
    }
    if (_key.text.trim().isEmpty) {
      setState(() => _err = 'Masukkan activation key dari web keygen.');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    final r = await lic.activateWithKey(_key.text.trim());
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.state == LicenseState.active) {
      Navigator.pushReplacementNamed(context, '/dashboard');
    } else {
      setState(() => _err = r.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lic = AppScope.of(context).license;
    return Scaffold(
      appBar: AppBar(title: const Text('Aktivasi Lisensi')),
      body: ListenableBuilder(
        listenable: lic,
        builder: (c, _) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Icon(
              Icons.key_rounded,
              size: 64,
              color: Theme.of(c).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            const Text(
              'Masukkan activation key yang dibuat di web keygen milik Anda. '
              'Masa berlaku (harian/bulanan/khusus) ditetapkan di keygen.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _url,
              decoration: const InputDecoration(
                labelText: 'Base URL keygen (https://...)',
                hintText: 'https://keygen.milik.anda',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _key,
              decoration: const InputDecoration(
                labelText: 'Activation key',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.vpn_key),
              ),
            ),
            if (_err != null) ...[
              const SizedBox(height: 12),
              Text(
                _err!,
                style: TextStyle(color: Theme.of(c).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _go,
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Aktivasikan'),
            ),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/license/status'),
              child: const Text('Lihat status lisensi'),
            ),
            const SizedBox(height: 24),
            Text(
              'Status: ${lic.statusMessage}',
              style: Theme.of(c).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
