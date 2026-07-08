import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:task_tracker/config/brand.dart';
import 'package:task_tracker/firebase_options.dart';
import 'package:task_tracker/providers/task_provider.dart';
import 'package:task_tracker/services/auth_gate.dart';
import 'package:task_tracker/services/settings_service.dart';
import 'package:task_tracker/utils/connectivity.dart';
import 'package:task_tracker/widgets/offline_banner.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const TaskTrackerApp());
}

class TaskTrackerApp extends StatelessWidget {
  const TaskTrackerApp({super.key});

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
      child: const _AppWithSettings(),
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
          backgroundColor: Brand.cardBackground,
          foregroundColor: Brand.primary,
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Brand.radiusMd),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: settings.accentColor,
        useMaterial3: true,
        brightness: Brightness.dark,
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
      home: const OfflineBanner(child: AuthGate()),
    );
  }
}


