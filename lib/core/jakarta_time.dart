/// Zona waktu tunggal aplikasi: Asia/Jakarta (WIB, UTC+7, tanpa DST).
/// Seluruh tampilan tanggal/waktu HARUS memakai helper ini.
library;

import 'package:intl/intl.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

const String jakartaZoneName = 'Asia/Jakarta';
bool _tzInit = false;

void ensureJakartaTimeInitialized() {
  if (!_tzInit) {
    tzdata.initializeTimeZones();
    _tzInit = true;
  }
}

tz.Location jakartaLocation() {
  ensureJakartaTimeInitialized();
  return tz.getLocation(jakartaZoneName);
}

/// Waktu server/perangkat yang dinormalisasi ke Asia/Jakarta.
tz.TZDateTime nowJakarta() {
  return tz.TZDateTime.now(jakartaLocation());
}

tz.TZDateTime toJakarta(DateTime dt) {
  return tz.TZDateTime.from(dt.toUtc(), jakartaLocation());
}

String formatJakarta(DateTime dt, {String pattern = 'dd MMM yyyy HH:mm'}) {
  final jkt = dt.isUtc
      ? toJakarta(dt)
      : tz.TZDateTime.from(dt, jakartaLocation());
  return DateFormat(pattern, 'id_ID').format(jkt);
}

String formatJakartaFull(DateTime dt) =>
    formatJakarta(dt, pattern: 'EEEE, dd MMMM yyyy HH:mm');

/// Batas cache offline lisensi: timestamp server terakhir + toleransi.
bool isOfflineGraceExpired({
  required DateTime lastServerCheck,
  required Duration maxOfflineCache,
  required DateTime now,
}) {
  return now.difference(lastServerCheck.toUtc()) > maxOfflineCache;
}
