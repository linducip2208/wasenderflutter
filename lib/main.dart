import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app.dart';
import 'core/notify.dart';
import 'data/database.dart';
import 'license/license.dart';
import 'whatsapp/protocol.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Data locale Indonesia untuk DateFormat('...', 'id_ID') — tanpa ini
  // format tanggal Indonesia crash (LocaleDataException) di perangkat.
  await initializeDateFormatting('id_ID', null);
  await NotifyService.init();
  final adb = AppDatabase();
  await adb.recoverIfCorrupt(() => adb.open());
  final license = LicenseRepository();
  await license.boot();
  final adapters = AdapterRegistry.defaultRegistry();
  runApp(WasenderApp(adb: adb, license: license, adapters: adapters));
}
