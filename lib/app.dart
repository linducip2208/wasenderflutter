import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../core/jakarta_time.dart';
import '../data/database.dart';
import '../license/license.dart';
import '../whatsapp/protocol.dart';
import 'features/splash/splash_screen.dart';
import 'features/license/activation_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/connection/connection_screen.dart';
import 'features/wasender/contacts_screen.dart';
import 'features/wasender/groups_screen.dart';
import 'features/wasender/templates_screen.dart';
import 'features/wasender/compose_screen.dart';
import 'features/wasender/queue_screen.dart';
import 'features/wasender/history_screen.dart';
import 'features/wasender/reports_screen.dart';
import 'features/wabadak/inbox_screen.dart';
import 'features/wabadak/chat_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/settings/storage_screen.dart';
import 'features/settings/about_screen.dart';
import 'features/license/status_screen.dart';

class AppScope extends InheritedWidget {
  final AppDatabase adb;
  final LicenseRepository license;
  final AdapterRegistry adapters;
  const AppScope({
    super.key,
    required this.adb,
    required this.license,
    required this.adapters,
    required super.child,
  });

  static AppScope of(BuildContext c) =>
      c.dependOnInheritedWidgetOfExactType<AppScope>()!;

  @override
  bool updateShouldNotify(AppScope old) => false;
}

class WasenderApp extends StatefulWidget {
  final AppDatabase adb;
  final LicenseRepository license;
  final AdapterRegistry adapters;
  const WasenderApp({
    super.key,
    required this.adb,
    required this.license,
    required this.adapters,
  });

  @override
  State<WasenderApp> createState() => _WasenderAppState();
}

class _WasenderAppState extends State<WasenderApp> {
  ThemeMode _mode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    ensureJakartaTimeInitialized();
  }

  void setMode(ThemeMode m) => setState(() => _mode = m);

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF0B6B3A);
    final light = ColorScheme.fromSeed(seedColor: seed);
    final dark = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    );
    return AppScope(
      adb: widget.adb,
      license: widget.license,
      adapters: widget.adapters,
      child: _ModeSetter(
        setMode: setMode,
        mode: _mode,
        child: MaterialApp(
          title: 'Wasender + Wabadak',
          debugShowCheckedModeBanner: false,
          locale: const Locale('id', 'ID'),
          supportedLocales: const [Locale('id', 'ID'), Locale('en', 'US')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          themeMode: _mode,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: light,
            appBarTheme: const AppBarTheme(centerTitle: false),
          ),
          darkTheme: ThemeData(useMaterial3: true, colorScheme: dark),
          initialRoute: '/',
          routes: {
            '/': (_) => const SplashScreen(),
            '/license': (_) => const ActivationScreen(),
            '/license/status': (_) => const LicenseStatusScreen(),
            '/dashboard': (_) => const DashboardScreen(),
            '/connection': (_) => const ConnectionScreen(),
            '/contacts': (_) => const ContactsScreen(),
            '/groups': (_) => const GroupsScreen(),
            '/templates': (_) => const TemplatesScreen(),
            '/compose': (_) => const ComposeScreen(),
            '/queue': (_) => const QueueScreen(),
            '/history': (_) => const HistoryScreen(),
            '/reports': (_) => const ReportsScreen(),
            '/inbox': (_) => const InboxScreen(),
            '/settings': (_) => const SettingsScreen(),
            '/storage': (_) => const StorageScreen(),
            '/about': (_) => const AboutScreen(),
          },
          onGenerateRoute: (s) {
            if (s.name == '/chat') {
              final convId =
                  (s.arguments as Map?)?['conversationId'] as String?;
              if (convId == null) {
                return MaterialPageRoute(builder: (_) => const InboxScreen());
              }
              return MaterialPageRoute(
                builder: (_) => ChatScreen(conversationId: convId),
              );
            }
            return null;
          },
        ),
      ),
    );
  }
}

class _ModeSetter extends InheritedWidget {
  final void Function(ThemeMode) setMode;
  final ThemeMode mode;
  const _ModeSetter({
    required this.setMode,
    required this.mode,
    required super.child,
  });
  static _ModeSetter of(BuildContext c) =>
      c.dependOnInheritedWidgetOfExactType<_ModeSetter>()!;
  @override
  bool updateShouldNotify(_ModeSetter old) => old.mode != mode;
}

extension ThemeCtl on BuildContext {
  void setThemeMode(ThemeMode m) => _ModeSetter.of(this).setMode(m);
  ThemeMode get themeMode => _ModeSetter.of(this).mode;
}
