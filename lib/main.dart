import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:task_tracker/config/brand.dart';
import 'package:task_tracker/firebase_options.dart';
import 'package:task_tracker/providers/task_provider.dart';
import 'package:task_tracker/services/auth_gate.dart';
import 'package:task_tracker/services/push_notification_service.dart';
import 'package:task_tracker/services/session_service.dart';
import 'package:task_tracker/services/settings_service.dart';
import 'package:task_tracker/services/update_service.dart';
import 'package:task_tracker/utils/connectivity.dart';
import 'package:task_tracker/widgets/offline_banner.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> scaffoldKey =
    GlobalKey<ScaffoldMessengerState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _SplashScreen());
  _initApp();
}

Future<void> _initApp() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (!kIsWeb) {
    await SessionService().init();
    runApp(TaskTrackerApp());
    // Init push notifications after app is running (non-blocking)
    PushNotificationService().initialize();
    try { Permission.requestInstallPackages.request(); } catch (_) {}
  } else {
    await SessionService().init();
    runApp(TaskTrackerApp());
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Brand.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.assignment, size: 40, color: Colors.white),
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}

class TaskTrackerApp extends StatelessWidget {
  TaskTrackerApp({super.key});

  final _updateService = UpdateService();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TaskProvider()),
        ChangeNotifierProvider(create: (_) {
          final s = SettingsService();
          s.load();
          return s;
        }),
        ChangeNotifierProvider(create: (_) {
          final c = ConnectivityProvider();
          c.start();
          return c;
        }),
      ],
      child: Builder(
        builder: (context) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Future.delayed(const Duration(seconds: 2), () {
              if (context.mounted) {
                _updateService.checkForUpdate(context);
              }
            });
            final settings = context.read<SettingsService>();
            context.read<TaskProvider>().attachSettings(settings);
          });
          return const _AppWithSettings();
        },
      ),
    );
  }
}

class _AppWithSettings extends StatelessWidget {
  const _AppWithSettings();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    return MaterialApp(
      title: 'Task Tracker',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldKey,
      theme: ThemeData(
        colorSchemeSeed: settings.accentColor,
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: Brand.surface,
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Brand.radiusMd),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        ),
        appBarTheme: AppBarTheme(
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 1,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Brand.radiusSm),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Brand.radiusSm),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Brand.radiusMd),
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: settings.accentColor,
          brightness: Brightness.dark,
        ).copyWith(
          surface: const Color(0xFF1C1B1F),
          surfaceContainerLowest: const Color(0xFF0F0D11),
          surfaceContainerLow: const Color(0xFF1A181C),
          surfaceContainer: const Color(0xFF1E1C20),
          surfaceContainerHigh: const Color(0xFF28262B),
          surfaceContainerHighest: const Color(0xFF333036),
          onSurface: const Color(0xFFE6E1E5),
          onSurfaceVariant: const Color(0xFFCAC4D0),
          background: const Color(0xFF1C1B1F),
          onBackground: const Color(0xFFE6E1E5),
          surfaceTint: const Color(0xFF1C1B1F),
          outline: const Color(0xFF938F99),
          outlineVariant: const Color(0xFF49454F),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Brand.radiusMd),
            side: BorderSide(color: Colors.grey.shade800),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 1,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Brand.radiusSm),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Brand.radiusSm),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Brand.radiusMd),
          ),
        ),
      ),
      themeMode: settings.themeMode,
      locale: Locale(settings.language),
      supportedLocales: const [
        Locale('en'),
        Locale('fr'),
        Locale('ar'),
      ],
      localeResolutionCallback: (locale, supported) {
        if (locale != null && supported.contains(locale)) return locale;
        return const Locale('en');
      },
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      home: OfflineBanner(
        child: Builder(
          builder: (context) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              PushNotificationService().bindContext(
                navigatorKey.currentState!,
                scaffoldKey.currentState!,
              );
            });
            return const AuthGate();
          },
        ),
      ),
    );
  }
}
