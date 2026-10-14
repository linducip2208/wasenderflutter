/// Sistem lisensi web keygen. Web keygen milik pemilik adalah sumber
/// kebenaran; aplikasi tidak mengasumsikan URL/skema sebelum dikonfigurasi.
library;

import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

enum LicenseState {
  notActivated,
  active,
  expired,
  revoked,
  invalid,
  networkError,
  revalidationRequired,
}

class LicenseData {
  final String licenseId;
  final String productId;
  final String status;
  final DateTime? activatedAt;
  final DateTime? expiresAt;
  final int deviceLimit;
  final List<String> devices;
  final DateTime? revokedAt;
  final String? planLabel;

  const LicenseData({
    required this.licenseId,
    required this.productId,
    required this.status,
    this.activatedAt,
    this.expiresAt,
    required this.deviceLimit,
    required this.devices,
    this.revokedAt,
    this.planLabel,
  });

  factory LicenseData.fromJson(Map<String, dynamic> j) => LicenseData(
    licenseId: '${j['license_id'] ?? j['id'] ?? ''}',
    productId: '${j['product_id'] ?? AppConfig.productId}',
    status: '${j['status'] ?? 'unknown'}',
    activatedAt: _dt(j['activated_at']),
    expiresAt: _dt(j['expires_at']),
    deviceLimit: (j['device_limit'] is num)
        ? (j['device_limit'] as num).toInt()
        : int.tryParse('${j['device_limit'] ?? 1}') ?? 1,
    devices: ((j['devices'] ?? j['bound_devices'] ?? []) as List)
        .map((e) => '$e')
        .toList(),
    revokedAt: _dt(j['revoked_at']),
    planLabel: j['plan']?.toString() ?? j['plan_label']?.toString(),
  );

  static DateTime? _dt(dynamic v) {
    if (v == null) return null;
    try {
      return DateTime.parse('$v').toUtc();
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toJson() => {
    'license_id': licenseId,
    'product_id': productId,
    'status': status,
    'activated_at': activatedAt?.toIso8601String(),
    'expires_at': expiresAt?.toIso8601String(),
    'device_limit': deviceLimit,
    'devices': devices,
    'revoked_at': revokedAt?.toIso8601String(),
    'plan': planLabel,
  };
}

class LicenseCheckResult {
  final LicenseState state;
  final LicenseData? data;
  final String message;
  final DateTime? serverTime;
  const LicenseCheckResult({
    required this.state,
    this.data,
    required this.message,
    this.serverTime,
  });
}

/// Client HTTP ke web keygen. Base URL dari build config / pengaturan aman.
/// Tidak menyimpan secret di source; TLS normal; timeout eksplisit.
class LicenseApiClient {
  final http.Client _http;
  LicenseApiClient([http.Client? c]) : _http = c ?? http.Client();

  Future<String> effectiveBaseUrl() async {
    if (AppConfig.licenseBaseUrl.isNotEmpty) return AppConfig.licenseBaseUrl;
    final p = await SharedPreferences.getInstance();
    return p.getString('license_base_url') ?? '';
  }

  Future<void> saveBaseUrl(String url) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('license_base_url', url.trim());
  }

  Future<LicenseCheckResult> activate({
    required String baseUrl,
    required String activationKey,
    required String deviceId,
    required String deviceName,
  }) async {
    final uri = Uri.parse('$baseUrl${_join('/api/v1/licenses/activate')}');
    try {
      final resp = await _http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'activation_key': activationKey.trim(),
              'product_id': AppConfig.productId,
              'device_id': deviceId,
              'device_name': deviceName,
            }),
          )
          .timeout(const Duration(seconds: 20));
      return _parse(resp.statusCode, resp.body, resp.headers['date']);
    } catch (e) {
      return LicenseCheckResult(
        state: LicenseState.networkError,
        message: 'Tidak dapat menghubungi keygen: $e',
      );
    }
  }

  Future<LicenseCheckResult> validate({
    required String baseUrl,
    required String licenseId,
    required String deviceId,
  }) async {
    final uri = Uri.parse(
      '$baseUrl${_join('/api/v1/licenses/validate')}?license_id=${Uri.encodeComponent(licenseId)}&device_id=${Uri.encodeComponent(deviceId)}&product_id=${Uri.encodeComponent(AppConfig.productId)}',
    );
    try {
      final resp = await _http.get(uri).timeout(const Duration(seconds: 20));
      return _parse(resp.statusCode, resp.body, resp.headers['date']);
    } catch (e) {
      return LicenseCheckResult(
        state: LicenseState.networkError,
        message: 'Tidak dapat menghubungi keygen: $e',
      );
    }
  }

  String _join(String p) => p;

  LicenseCheckResult _parse(int code, String body, String? dateHeader) {
    DateTime? serverTime;
    if (dateHeader != null) {
      try {
        serverTime = HttpDate.parse(dateHeader).toUtc();
      } catch (_) {}
    }
    if (code < 200 || code >= 300) {
      if (code == 404 || code == 422) {
        return LicenseCheckResult(
          state: LicenseState.invalid,
          message: 'Key tidak valid (HTTP $code).',
          serverTime: serverTime,
        );
      }
      if (code == 410 || code == 403) {
        return LicenseCheckResult(
          state: LicenseState.revoked,
          message: 'Lisensi dicabut / ditolak (HTTP $code).',
          serverTime: serverTime,
        );
      }
      return LicenseCheckResult(
        state: LicenseState.networkError,
        message: 'Server keygen error (HTTP $code).',
        serverTime: serverTime,
      );
    }
    try {
      final j = jsonDecode(body) as Map<String, dynamic>;
      final data = j.containsKey('data') && j['data'] is Map<String, dynamic>
          ? LicenseData.fromJson(j['data'] as Map<String, dynamic>)
          : LicenseData.fromJson(j);
      final s = data.status.toLowerCase();
      if (s == 'revoked' || s == 'cancelled') {
        return LicenseCheckResult(
          state: LicenseState.revoked,
          data: data,
          message: 'Lisensi telah dicabut via keygen.',
          serverTime: serverTime,
        );
      }
      if (s == 'expired') {
        return LicenseCheckResult(
          state: LicenseState.expired,
          data: data,
          message: 'Lisensi kedaluwarsa.',
          serverTime: serverTime,
        );
      }
      if (s == 'active' || s == 'valid') {
        return LicenseCheckResult(
          state: LicenseState.active,
          data: data,
          message: 'Lisensi aktif.',
          serverTime: serverTime,
        );
      }
      return LicenseCheckResult(
        state: LicenseState.invalid,
        data: data,
        message: 'Status lisensi tidak dikenali: ${data.status}.',
        serverTime: serverTime,
      );
    } catch (e) {
      return LicenseCheckResult(
        state: LicenseState.invalid,
        message: 'Respons keygen tidak valid: $e',
        serverTime: serverTime,
      );
    }
  }
}

/// Device binding: ID perangkat stabil (hash ANDROID_ID / info).
class DeviceBindingService {
  final FlutterSecureStorage _s = const FlutterSecureStorage();
  static const _k = 'device_uuid_v1';

  Future<String> deviceId() async {
    var id = await _s.read(key: _k);
    if (id == null || id.isEmpty) {
      final raw =
          '${DateTime.now().microsecondsSinceEpoch}-wasender-${await _salt()}';
      id = sha256.convert(utf8.encode(raw)).toString().substring(0, 32);
      await _s.write(key: _k, value: id);
    }
    return id;
  }

  Future<String> _salt() async {
    try {
      final p = await SharedPreferences.getInstance();
      var s = p.getString('install_salt');
      if (s == null) {
        s = '${DateTime.now().millisecondsSinceEpoch}';
        await p.setString('install_salt', s);
      }
      return s;
    } catch (_) {
      return 'salt';
    }
  }

  Future<String> deviceName() async =>
      'Android-${(await deviceId()).substring(0, 8)}';
}

/// Cache aman: payload di secure storage, bukan SharedPreferences biasa.
class SecureLicenseCache {
  final FlutterSecureStorage _s = const FlutterSecureStorage();
  static const _dataKey = 'license_payload';
  static const _checkKey = 'license_last_server_check';

  Future<void> save(LicenseData data, {DateTime? serverTime}) async {
    await _s.write(key: _dataKey, value: jsonEncode(data.toJson()));
    await _s.write(
      key: _checkKey,
      value: (serverTime ?? DateTime.now().toUtc()).toIso8601String(),
    );
  }

  Future<LicenseData?> load() async {
    final raw = await _s.read(key: _dataKey);
    if (raw == null) return null;
    try {
      return LicenseData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<DateTime?> lastServerCheck() async {
    final raw = await _s.read(key: _checkKey);
    if (raw == null) return null;
    try {
      return DateTime.parse(raw).toUtc();
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    await _s.delete(key: _dataKey);
    await _s.delete(key: _checkKey);
  }
}

/// Kebijakan validasi: expiry memakai waktu server; jam perangkat tidak
/// pernah menjadi satu-satunya sumber.
class LicenseValidationPolicy {
  final Duration maxOfflineCache;
  const LicenseValidationPolicy({
    this.maxOfflineCache = const Duration(hours: 24),
  });

  LicenseState evaluate({
    required LicenseData? cached,
    required DateTime? lastServerCheck,
    required DateTime nowUtc,
    required DateTime? serverTime,
  }) {
    if (cached == null) return LicenseState.notActivated;
    final ref = (serverTime ?? nowUtc).toUtc();
    if (cached.revokedAt != null ||
        cached.status.toLowerCase() == 'revoked' ||
        cached.status.toLowerCase() == 'cancelled') {
      return LicenseState.revoked;
    }
    if (cached.expiresAt != null && ref.isAfter(cached.expiresAt!)) {
      return LicenseState.expired;
    }
    if (lastServerCheck == null) return LicenseState.revalidationRequired;
    if (nowUtc.difference(lastServerCheck.toUtc()) > maxOfflineCache) {
      return LicenseState.revalidationRequired;
    }
    return LicenseState.active;
  }
}

class LicenseRepository extends ChangeNotifier {
  final LicenseApiClient api;
  final SecureLicenseCache cache;
  final DeviceBindingService devices;
  final LicenseValidationPolicy policy;

  LicenseState state = LicenseState.notActivated;
  LicenseData? data;
  String statusMessage = 'Belum diaktivasi.';
  DateTime? lastServerCheck;

  LicenseRepository({
    LicenseApiClient? api,
    SecureLicenseCache? cache,
    DeviceBindingService? devices,
    LicenseValidationPolicy? policy,
  }) : api = api ?? LicenseApiClient(),
       cache = cache ?? SecureLicenseCache(),
       devices = devices ?? DeviceBindingService(),
       policy = policy ?? const LicenseValidationPolicy();

  Future<void> boot() async {
    data = await cache.load();
    lastServerCheck = await cache.lastServerCheck();
    final p = await SharedPreferences.getInstance();
    final hours =
        p.getInt('offline_cache_hours') ?? AppConfig.maxOfflineCacheHours;
    final pol = LicenseValidationPolicy(
      maxOfflineCache: Duration(hours: hours),
    );
    state = pol.evaluate(
      cached: data,
      lastServerCheck: lastServerCheck,
      nowUtc: DateTime.now().toUtc(),
      serverTime: null,
    );
    statusMessage = _msg(state);
    notifyListeners();
  }

  String _msg(LicenseState s) => switch (s) {
    LicenseState.notActivated => 'Belum diaktivasi.',
    LicenseState.active => 'Lisensi aktif.',
    LicenseState.expired => 'Lisensi kedaluwarsa.',
    LicenseState.revoked => 'Lisensi dicabut via keygen.',
    LicenseState.invalid => 'Lisensi tidak valid.',
    LicenseState.networkError => 'Keygen tidak dapat dihubungi.',
    LicenseState.revalidationRequired =>
      'Perlu validasi ulang online (cache offline habis).',
  };

  bool get hasAccess => state == LicenseState.active;

  Future<LicenseCheckResult> activateWithKey(String key) async {
    final base = await api.effectiveBaseUrl();
    if (base.isEmpty) {
      state = LicenseState.networkError;
      statusMessage =
          'API keygen belum dikonfigurasi. Isi Base URL di Pengaturan > Lisensi atau build dengan --dart-define=LICENSE_BASE_URL=....';
      notifyListeners();
      return LicenseCheckResult(state: state, message: statusMessage);
    }
    final did = await devices.deviceId();
    final dname = await devices.deviceName();
    final r = await api.activate(
      baseUrl: base,
      activationKey: key,
      deviceId: did,
      deviceName: dname,
    );
    if (r.state == LicenseState.active && r.data != null) {
      await cache.save(r.data!, serverTime: r.serverTime);
      data = r.data;
      lastServerCheck = r.serverTime ?? DateTime.now().toUtc();
    }
    state = r.state;
    statusMessage = r.message;
    notifyListeners();
    return r;
  }

  Future<LicenseCheckResult> revalidate() async {
    final base = await api.effectiveBaseUrl();
    if (base.isEmpty || data == null) {
      state = data == null
          ? LicenseState.notActivated
          : LicenseState.revalidationRequired;
      statusMessage = base.isEmpty
          ? 'API keygen belum dikonfigurasi.'
          : statusMessage;
      notifyListeners();
      return LicenseCheckResult(state: state, message: statusMessage);
    }
    final did = await devices.deviceId();
    final r = await api.validate(
      baseUrl: base,
      licenseId: data!.licenseId,
      deviceId: did,
    );
    if (r.state == LicenseState.active && r.data != null) {
      await cache.save(r.data!, serverTime: r.serverTime);
      data = r.data;
      lastServerCheck = r.serverTime ?? DateTime.now().toUtc();
    } else if (r.state == LicenseState.networkError) {
      // Tetap pakai evaluasi offline terhadap cache.
      final p = await SharedPreferences.getInstance();
      final hours =
          p.getInt('offline_cache_hours') ?? AppConfig.maxOfflineCacheHours;
      state = LicenseValidationPolicy(maxOfflineCache: Duration(hours: hours))
          .evaluate(
            cached: data,
            lastServerCheck: lastServerCheck,
            nowUtc: DateTime.now().toUtc(),
            serverTime: null,
          );
      statusMessage = '${r.message} Status cache: ${_msg(state)}';
      notifyListeners();
      return LicenseCheckResult(
        state: state,
        data: data,
        message: statusMessage,
      );
    } else {
      state = r.state;
      if (r.data != null) {
        data = r.data;
        await cache.save(r.data!, serverTime: r.serverTime);
      }
    }
    statusMessage = r.message;
    notifyListeners();
    return r;
  }

  Future<void> clear() async {
    await cache.clear();
    data = null;
    state = LicenseState.notActivated;
    statusMessage = 'Belum diaktivasi.';
    notifyListeners();
  }
}
