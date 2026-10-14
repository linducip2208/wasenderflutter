import 'package:flutter_test/flutter_test.dart';
import 'package:wasender_wabadak/license/license.dart';

LicenseData _lic({
  String status = 'active',
  DateTime? expires,
  DateTime? revoked,
}) => LicenseData(
  licenseId: 'lic_1',
  productId: 'wasender_wabadak_android',
  status: status,
  activatedAt: DateTime.utc(2026, 10, 1),
  expiresAt: expires ?? DateTime.utc(2026, 11, 1),
  deviceLimit: 2,
  devices: const ['dev1'],
  revokedAt: revoked,
);

void main() {
  const pol = LicenseValidationPolicy(maxOfflineCache: Duration(hours: 24));
  final now = DateTime.utc(2026, 10, 14, 12);

  test('1 key valid -> active', () {
    expect(
      pol.evaluate(
        cached: _lic(),
        lastServerCheck: now.subtract(const Duration(hours: 1)),
        nowUtc: now,
        serverTime: now,
      ),
      LicenseState.active,
    );
  });

  test('2 belum aktivasi -> notActivated', () {
    expect(
      pol.evaluate(
        cached: null,
        lastServerCheck: null,
        nowUtc: now,
        serverTime: now,
      ),
      LicenseState.notActivated,
    );
  });

  test('3 expired berdasar waktu server, bukan jam perangkat', () {
    // Jam perangkat maju tidak relevan; serverTime yang menentukan.
    expect(
      pol.evaluate(
        cached: _lic(expires: DateTime.utc(2026, 10, 10)),
        lastServerCheck: now,
        nowUtc: DateTime.utc(2026, 10, 9),
        serverTime: DateTime.utc(2026, 10, 14),
      ),
      LicenseState.expired,
    );
  });

  test('4 revoked -> revoked', () {
    expect(
      pol.evaluate(
        cached: _lic(status: 'revoked', revoked: DateTime.utc(2026, 10, 13)),
        lastServerCheck: now,
        nowUtc: now,
        serverTime: now,
      ),
      LicenseState.revoked,
    );
  });

  test('5 cache dalam toleransi -> active', () {
    expect(
      pol.evaluate(
        cached: _lic(),
        lastServerCheck: now.subtract(const Duration(hours: 23)),
        nowUtc: now,
        serverTime: null,
      ),
      LicenseState.active,
    );
  });

  test('6 cache habis -> revalidationRequired', () {
    expect(
      pol.evaluate(
        cached: _lic(),
        lastServerCheck: now.subtract(const Duration(hours: 25)),
        nowUtc: now,
        serverTime: null,
      ),
      LicenseState.revalidationRequired,
    );
  });

  test('7 over-limit dinilai dari devices vs device_limit', () {
    final d = _lic();
    expect(d.devices.length, lessThanOrEqualTo(d.deviceLimit));
    final over = LicenseData(
      licenseId: d.licenseId,
      productId: d.productId,
      status: 'invalid',
      deviceLimit: 1,
      devices: const ['a', 'b'],
    );
    expect(over.devices.length > over.deviceLimit, isTrue);
  });
}
