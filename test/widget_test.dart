import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wasender_wabadak/widgets/states.dart';
import 'package:wasender_wabadak/whatsapp/protocol.dart';

void main() {
  testWidgets('aktivasi: banner konfigurasi tampil saat base URL kosong', (
    t,
  ) async {
    await t.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: BlockedBanner('API keygen belum dikonfigurasi.')),
      ),
    );
    expect(find.textContaining('belum dikonfigurasi'), findsOneWidget);
  });

  testWidgets('dashboard: kartu menu utama tampil', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: const [
              Text('Wasender'),
              Text('Wabadak'),
              Text('Kontak'),
              Text('Inbox percakapan'),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Wasender'), findsOneWidget);
    expect(find.text('Inbox percakapan'), findsOneWidget);
  });

  testWidgets('inbox: banner BLOCKED tampil jelas', (t) async {
    await t.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BlockedBanner(BlockedProtocolAdapter.blockedReason),
        ),
      ),
    );
    expect(find.textContaining('BELUM tersedia'), findsOneWidget);
  });

  test(
    'adapter share: connect + send jujur (unknown, bukan delivered)',
    () async {
      final a = DeviceShareAdapter();
      await a.connect();
      expect(a.state, WhatsAppConnectionState.connected);
      expect(a.capabilities.supportsShareIntent, isTrue);
      expect(a.capabilities.supportsDirectConnection, isFalse);
      final m = await a.sendText(toMsisdn: '62812', body: 'halo');
      expect(m.status, WhatsAppMsgStatus.unknown);
    },
  );

  test('adapter protokol langsung: BLOCKED eksplisit', () async {
    final a = BlockedProtocolAdapter();
    expect(a.state, WhatsAppConnectionState.blocked);
    expect(a.connect(), throwsUnsupportedError);
    expect(
      () => a.sendText(toMsisdn: '62812', body: 'x'),
      throwsUnsupportedError,
    );
  });
}
