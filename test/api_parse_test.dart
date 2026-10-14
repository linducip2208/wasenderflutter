import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:wasender_wabadak/license/license.dart';

void main() {
  test('parse envelope data active', () {
    final d = LicenseData.fromJson(
      (jsonDecode(
                '{"data":{"license_id":"lic_9","product_id":"p","status":"active",'
                '"activated_at":"2026-10-01T00:00:00Z","expires_at":"2026-11-01T00:00:00Z",'
                '"device_limit":2,"devices":["d1"],"plan":"Bulanan 1"}}',
              )
              as Map<String, dynamic>)['data']
          as Map<String, dynamic>,
    );
    expect(d.licenseId, 'lic_9');
    expect(d.planLabel, 'Bulanan 1');
    expect(d.deviceLimit, 2);
  });

  test('parse flat revoked', () {
    final d = LicenseData.fromJson(
      jsonDecode(
            '{"license_id":"l","status":"revoked","revoked_at":"2026-10-13T00:00:00Z"}',
          )
          as Map<String, dynamic>,
    );
    expect(d.status, 'revoked');
    expect(d.revokedAt, isNotNull);
  });

  test('round-trip toJson', () {
    final d = LicenseData(
      licenseId: 'a',
      productId: 'p',
      status: 'active',
      deviceLimit: 1,
      devices: const ['x'],
    );
    final back = LicenseData.fromJson(d.toJson());
    expect(back.licenseId, 'a');
    expect(back.devices, ['x']);
  });
}
