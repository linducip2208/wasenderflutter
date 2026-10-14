/// Integration test Android (dijalankan di HP/emulator, BUKAN di host).
///
/// Jalankan dari root project saat HP Android tersambung:
///   flutter test integration_test
///
/// Tanpa activation key yang valid, aplikasi berhenti di gerbang lisensi —
/// itu yang diverifikasi di sini (jalur jujur, tanpa mock keygen).
/// Alur berlisensi penuh (dashboard, kirim share, inbox) diuji manual
/// mengikuti docs/TESTING.md skenario 1–17.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wasender_wabadak/app.dart';
import 'package:wasender_wabadak/data/database.dart';
import 'package:wasender_wabadak/license/license.dart';
import 'package:wasender_wabadak/whatsapp/protocol.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('boot -> gerbang lisensi tampil tanpa key', (t) async {
    final adb = AppDatabase();
    await adb.recoverIfCorrupt(() => adb.open());
    final license = LicenseRepository();
    await license.boot();
    // Di perangkat uji yang belum diaktivasi: harus NOT_ACTIVATED.
    // Jika perangkat sudah diaktivasi manual, lewati dengan aman.
    if (license.hasAccess) {
      markTestSkipped('Perangkat sudah berlisensi; uji gerbang dilewati.');
      return;
    }
    expect(license.state, LicenseState.notActivated);
    await t.pumpWidget(
      WasenderApp(
        adb: adb,
        license: license,
        adapters: AdapterRegistry.defaultRegistry(),
      ),
    );
    await t.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('Aktivasi Lisensi'), findsOneWidget);
    expect(find.text('Activation key'), findsOneWidget);
    expect(find.text('Aktivasikan'), findsOneWidget);
    await adb.close();
  });

  testWidgets('layar status lisensi dapat dibuka', (t) async {
    final adb = AppDatabase();
    await adb.recoverIfCorrupt(() => adb.open());
    final license = LicenseRepository();
    await license.boot();
    await t.pumpWidget(
      WasenderApp(
        adb: adb,
        license: license,
        adapters: AdapterRegistry.defaultRegistry(),
      ),
    );
    await t.pumpAndSettle(const Duration(seconds: 2));
    await t.tap(find.text('Lihat status lisensi'));
    await t.pumpAndSettle();
    expect(find.text('Status Lisensi'), findsOneWidget);
    await adb.close();
  });
}
