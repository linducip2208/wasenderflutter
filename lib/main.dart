import 'package:flutter/material.dart';
import 'app.dart';
import 'core/notify.dart';
import 'data/database.dart';
import 'license/license.dart';
import 'whatsapp/protocol.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotifyService.init();
  final adb = AppDatabase();
  await adb.recoverIfCorrupt(() => adb.open());
  final license = LicenseRepository();
  await license.boot();
  final adapters = AdapterRegistry.defaultRegistry();
  runApp(WasenderApp(adb: adb, license: license, adapters: adapters));
}
