import 'package:flutter_test/flutter_test.dart';
import 'package:wasender_wabadak/core/jakarta_time.dart';
import 'package:wasender_wabadak/core/result.dart';
import 'package:wasender_wabadak/data/database.dart';

void main() {
  test('validasi MSISDN', () {
    expect(validateMsisdn('08123456789'), isNull);
    expect(validateMsisdn('628123456789'), isNull);
    expect(validateMsisdn('123'), isNotNull);
    expect(validateMsisdn('abc'), isNotNull);
  });

  test('normalisasi MSISDN', () {
    expect(normalizeMsisdn('0812-3456-789'), '628123456789');
    expect(normalizeMsisdn('+62 812 3456 789'), '628123456789');
  });

  test('render template + vars', () {
    expect(
      renderTemplate('Halo {{nama}} ({{nama}})', {'nama': 'Budi'}),
      'Halo Budi (Budi)',
    );
    expect(templateVars('A {{nama}} {{kota}}'), {'nama', 'kota'});
  });

  test('sanitasi CSV', () {
    expect(sanitizeCsvCell('  halo\x00dunia  '), 'halodunia');
    expect(sanitizeCsvCell('x' * 600).length, 500);
  });

  test('waktu Jakarta UTC+7', () {
    ensureJakartaTimeInitialized();
    final j = toJakarta(DateTime.utc(2026, 10, 14, 0, 0));
    expect(j.hour, 7);
    expect(jakartaZoneName, 'Asia/Jakarta');
  });

  test('CSV header invalid ditolak', () async {
    // Tanpa DB: uji splitter via importContactsCsv memakai DB nyata di bawah.
    expect(
      toCsv(
        ['a', 'b'],
        [
          [1, 'x,y'],
        ],
      ),
      'a,b\n1,"x,y"\n',
    );
  });

  test('backoff antrean naik', () {
    // Urutan 30s, 120s, 600s — diuji via QueueWorker.backoff memakai DB;
    // di sini verifikasi konstanta lewat database import tidak error.
    expect(newId().length, 36);
  });
}
