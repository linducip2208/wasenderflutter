/// Abstraksi protokol WhatsApp. Seluruh UI HANYA bergantung pada
/// [WhatsAppAdapter], tidak pada library konkret, sehingga adapter dapat
/// diganti tanpa menulis ulang UI.
///
/// STATUS KOMPATIBILITAS (jujur, terverifikasi 2026-10-14):
/// - TIDAK ADA library Dart/Flutter production-ready yang mengimplementasikan
///   protokol WhatsApp E2E (Signal + Noise handshake + QR pairing) secara
///   lokal di APK. Lihat docs/WHATSAPP_COMPATIBILITY.md.
/// - Library Node.js (Baileys, whatsapp-web.js) dan Rust tidak dapat
///   dijalankan langsung dalam APK Flutter tanpa server/embedding khusus.
/// - Maka koneksi protokol langsung berstatus BLOCKED.
/// - Adapter yang AKTIF: [DeviceShareAdapter] — mengirim via aplikasi
///   WhatsApp resmi terinstal (share intent / wa.me deep-link). Ini memakai
///   autentikasi & enkripsi resmi WhatsApp, tanpa bypass.
/// - Penerimaan otomatis membutuhkan adapter protokol yang belum tersedia;
///   inbox Wabadak menyimpan riwayat lokal + pencatatan manual + siap
///   menerima event dari adapter masa depan via [WhatsAppEvent].
library;

enum WhatsAppConnectionState {
  disconnected,
  connecting,
  qrRequired,
  pairing,
  connected,
  syncing,
  connectionError,
  blocked,
}

enum WhatsAppMsgDirection { inbound, outbound }

enum WhatsAppMsgStatus { pending, sending, sent, failed, unknown }

enum QueuedMsgStatus { pending, sending, sent, failed, cancelled }

class WhatsAppContact {
  final String jid;
  final String msisdn;
  final String displayName;
  const WhatsAppContact({
    required this.jid,
    required this.msisdn,
    required this.displayName,
  });
}

class WhatsAppMedia {
  final String path;
  final String mime;
  final int sizeBytes;
  final String? caption;
  const WhatsAppMedia({
    required this.path,
    required this.mime,
    required this.sizeBytes,
    this.caption,
  });
}

class WhatsAppMessage {
  final String id;
  final String chatJid;
  final WhatsAppMsgDirection direction;
  final String? body;
  final WhatsAppMedia? media;
  final DateTime at;
  final WhatsAppMsgStatus status;
  final String? errorCode;
  const WhatsAppMessage({
    required this.id,
    required this.chatJid,
    required this.direction,
    this.body,
    this.media,
    required this.at,
    required this.status,
    this.errorCode,
  });
}

class WhatsAppEvent {
  final String type;
  final WhatsAppMessage? message;
  final WhatsAppConnectionState? state;
  final String? detail;
  const WhatsAppEvent({
    required this.type,
    this.message,
    this.state,
    this.detail,
  });
}

/// Kemampuan yang dideklarasikan jujur oleh setiap adapter.
class AdapterCapabilities {
  final bool supportsQrLogin;
  final bool supportsDirectConnection;
  final bool supportsAutoReceive;
  final bool supportsMedia;
  final bool supportsShareIntent;
  final bool supportsReceipts;
  const AdapterCapabilities({
    required this.supportsQrLogin,
    required this.supportsDirectConnection,
    required this.supportsAutoReceive,
    required this.supportsMedia,
    required this.supportsShareIntent,
    required this.supportsReceipts,
  });
}

abstract class WhatsAppSessionStore {
  Future<void> saveSession(String key, String value);
  Future<String?> readSession(String key);
  Future<void> deleteSession();
}

abstract class WhatsAppAdapter {
  String get adapterId;
  String get displayName;
  AdapterCapabilities get capabilities;
  WhatsAppConnectionState get state;
  Stream<WhatsAppEvent> get events;

  Future<void> connect();
  Future<void> disconnect();
  Future<void> logout();
  Future<WhatsAppMessage> sendText({
    required String toMsisdn,
    required String body,
  });
  Future<WhatsAppMessage> sendMedia({
    required String toMsisdn,
    required WhatsAppMedia media,
  });
  Future<void> markRead(String chatJid);
  Future<void> dispose();
}

/// Adapter AKTIF: pengiriman via aplikasi WhatsApp resmi (share intent).
/// Tidak melakukan QR pairing / socket protokol sendiri.
class DeviceShareAdapter implements WhatsAppAdapter {
  final Stream<WhatsAppEvent> _empty = const Stream.empty();
  WhatsAppConnectionState _state = WhatsAppConnectionState.disconnected;

  @override
  String get adapterId => 'device_share';

  @override
  String get displayName => 'WhatsApp Resmi (Share)';

  @override
  AdapterCapabilities get capabilities => const AdapterCapabilities(
    supportsQrLogin: false,
    supportsDirectConnection: false,
    supportsAutoReceive: false,
    supportsMedia: true,
    supportsShareIntent: true,
    supportsReceipts: false,
  );

  @override
  WhatsAppConnectionState get state => _state;

  @override
  Stream<WhatsAppEvent> get events => _empty;

  @override
  Future<void> connect() async {
    _state = WhatsAppConnectionState.connected;
  }

  @override
  Future<void> disconnect() async {
    _state = WhatsAppConnectionState.disconnected;
  }

  @override
  Future<void> logout() async {
    _state = WhatsAppConnectionState.disconnected;
  }

  @override
  Future<WhatsAppMessage> sendText({
    required String toMsisdn,
    required String body,
  }) async {
    // Pengiriman aktual dilakukan caller via url_launcher/share_plus ke
    // aplikasi WhatsApp resmi; adapter mencatat status unknown (receipt
    // nyata tidak tersedia dari share intent).
    return WhatsAppMessage(
      id: 'share-${DateTime.now().microsecondsSinceEpoch}',
      chatJid: '$toMsisdn@s.whatsapp.net',
      direction: WhatsAppMsgDirection.outbound,
      body: body,
      at: DateTime.now().toUtc(),
      status: WhatsAppMsgStatus.unknown,
    );
  }

  @override
  Future<WhatsAppMessage> sendMedia({
    required String toMsisdn,
    required WhatsAppMedia media,
  }) async {
    return WhatsAppMessage(
      id: 'share-${DateTime.now().microsecondsSinceEpoch}',
      chatJid: '$toMsisdn@s.whatsapp.net',
      direction: WhatsAppMsgDirection.outbound,
      media: media,
      at: DateTime.now().toUtc(),
      status: WhatsAppMsgStatus.unknown,
    );
  }

  @override
  Future<void> markRead(String chatJid) async {}

  @override
  Future<void> dispose() async {}
}

/// Adapter protokol langsung (QR/socket/E2E): BLOCKED.
/// Disediakan sebagai interface siap-integrasi; setiap pemanggilan
/// mengembalikan status blocked dengan penjelasan jujur.
class BlockedProtocolAdapter implements WhatsAppAdapter {
  final Stream<WhatsAppEvent> _empty = const Stream.empty();

  @override
  String get adapterId => 'direct_protocol';

  @override
  String get displayName => 'Koneksi Langsung (BLOCKED)';

  @override
  AdapterCapabilities get capabilities => const AdapterCapabilities(
    supportsQrLogin: false,
    supportsDirectConnection: false,
    supportsAutoReceive: false,
    supportsMedia: false,
    supportsShareIntent: false,
    supportsReceipts: false,
  );

  @override
  WhatsAppConnectionState get state => WhatsAppConnectionState.blocked;

  @override
  Stream<WhatsAppEvent> get events => _empty;

  static const String blockedReason =
      'Koneksi protokol WhatsApp langsung (QR/socket/E2E) BELUM tersedia di '
      'APK ini. Tidak ada library Dart/Flutter yang terbukti menjalankan '
      'protokol tersebut lokal di Android (lihat '
      'docs/WHATSAPP_COMPATIBILITY.md). Gunakan pengiriman via aplikasi '
      'WhatsApp resmi. Jangan gunakan server VPS/Node tanpa persetujuan.';

  @override
  Future<void> connect() async {
    throw UnsupportedError(blockedReason);
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> logout() async {}

  @override
  Future<WhatsAppMessage> sendText({
    required String toMsisdn,
    required String body,
  }) {
    throw UnsupportedError(blockedReason);
  }

  @override
  Future<WhatsAppMessage> sendMedia({
    required String toMsisdn,
    required WhatsAppMedia media,
  }) {
    throw UnsupportedError(blockedReason);
  }

  @override
  Future<void> markRead(String chatJid) async {}

  @override
  Future<void> dispose() async {}
}

/// Registry: UI memilih adapter aktif tanpa import konkret.
class AdapterRegistry {
  final WhatsAppAdapter active;
  final List<WhatsAppAdapter> all;
  AdapterRegistry._(this.active, this.all);

  factory AdapterRegistry.defaultRegistry() {
    final share = DeviceShareAdapter();
    final blocked = BlockedProtocolAdapter();
    return AdapterRegistry._(share, [share, blocked]);
  }
}
