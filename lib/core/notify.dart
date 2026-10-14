/// Notifikasi lokal untuk pesan masuk yang dicatat (Wabadak).
/// Hanya notifikasi instan; tanpa penjadwalan background yang menjanjikan
/// pengiriman tepat waktu.
library;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotifyService {
  static final FlutterLocalNotificationsPlugin _pl =
      FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static Future<void> init() async {
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _pl.initialize(const InitializationSettings(android: android));
      final a = _pl
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await a?.requestNotificationsPermission();
      await a?.createNotificationChannel(
        const AndroidNotificationChannel(
          'wabadak_inbox',
          'Wabadak Inbox',
          description: 'Pemberitahuan pesan masuk yang dicatat.',
          importance: Importance.defaultImportance,
        ),
      );
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  static Future<void> inbound(String title, String body) async {
    if (!_ready) return;
    try {
      final short = body.length > 120 ? '${body.substring(0, 120)}…' : body;
      await _pl.show(
        title.hashCode & 0x7fffffff,
        title,
        short,
        const NotificationDetails(
          android: AndroidNotificationDetails('wabadak_inbox', 'Wabadak Inbox'),
        ),
      );
    } catch (_) {}
  }
}
