import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _S();
}

class _S extends State<SettingsScreen> {
  final _url = TextEditingController();
  int _cacheHours = 24;
  bool _dark = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    _url.text = p.getString('license_base_url') ?? '';
    _cacheHours = p.getInt('offline_cache_hours') ?? 24;
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('license_base_url', _url.text.trim());
    await p.setInt('offline_cache_hours', _cacheHours);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Pengaturan tersimpan.')));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pengaturan')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Lisensi (web keygen)',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _url,
          decoration: const InputDecoration(
            labelText: 'Base URL keygen',
            hintText: 'https://keygen.milik.anda',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('Toleransi cache offline (jam): '),
            DropdownButton<int>(
              value: _cacheHours,
              items: const [6, 12, 24, 48, 72]
                  .map((e) => DropdownMenuItem(value: e, child: Text('$e')))
                  .toList(),
              onChanged: (v) => setState(() => _cacheHours = v ?? 24),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          value: _dark,
          onChanged: (v) {
            setState(() => _dark = v);
            context.setThemeMode(v ? ThemeMode.dark : ThemeMode.light);
          },
          title: const Text('Tema gelap (opsional)'),
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 8),
        FilledButton(onPressed: _save, child: const Text('Simpan pengaturan')),
        const Divider(height: 32),
        ListTile(
          leading: const Icon(Icons.verified),
          title: const Text('Status lisensi'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.pushNamed(context, '/license/status'),
        ),
        ListTile(
          leading: const Icon(Icons.storage),
          title: const Text('Penyimpanan & backup'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.pushNamed(context, '/storage'),
        ),
        ListTile(
          leading: const Icon(Icons.info),
          title: const Text('Tentang & lisensi app'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.pushNamed(context, '/about'),
        ),
      ],
    ),
  );
}
