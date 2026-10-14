/// Penyimpanan sesi WhatsApp di secure storage (Android Keystore-backed).
/// Tidak menyimpan kredensial sebagai teks biasa.
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'protocol.dart';

class SecureSessionStore implements WhatsAppSessionStore {
  final FlutterSecureStorage _s;
  static const _prefix = 'wa_session_';
  SecureSessionStore([FlutterSecureStorage? s])
    : _s = s ?? const FlutterSecureStorage();

  @override
  Future<void> saveSession(String key, String value) =>
      _s.write(key: '$_prefix$key', value: value);

  @override
  Future<String?> readSession(String key) => _s.read(key: '$_prefix$key');

  @override
  Future<void> deleteSession() => _s.deleteAll();
}
