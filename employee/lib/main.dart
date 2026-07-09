import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:task_tracker_employee/firebase_options.dart';
import 'package:task_tracker_employee/services/firestore_service.dart';
import 'package:task_tracker_employee/services/settings_service.dart';
import 'package:task_tracker_employee/screens/login_screen.dart';
import 'package:task_tracker_employee/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const EmployeeApp());
}

class EmployeeApp extends StatelessWidget {
  const EmployeeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) {
          final s = SettingsService();
          s.load();
          return s;
        }),
        ChangeNotifierProvider(create: (_) => EmployeeState()),
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
      title: 'Task Tracker - Employee',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
      ),
      themeMode: settings.themeMode,
      locale: Locale(settings.language),
      supportedLocales: const [
        Locale('en'),
        Locale('fr'),
        Locale('ar'),
      ],
      home: const AuthGate(),
    );
  }
}

class EmployeeState extends ChangeNotifier {
  final FirestoreService _firestore = FirestoreService();
  List<Map<String, dynamic>> _tasks = [];
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> get tasks => _tasks;
  bool get loading => _loading;
  String? get error => _error;

  void listenToTasks(String email) {
    _loading = true;
    _tasks = [];
    _error = null;
    notifyListeners();

    _firestore.tasksForEmployee(email).listen(
      (snapshot) {
        _tasks = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return data;
        }).toList();
        _tasks.sort((a, b) {
          final aCreated = a['createdAt'] as Timestamp?;
          final bCreated = b['createdAt'] as Timestamp?;
          if (aCreated != null && bCreated != null) {
            return bCreated.compareTo(aCreated);
          }
          return 0;
        });
        _loading = false;
        notifyListeners();
      },
      onError: (e) {
        _loading = false;
        _error = e.toString();
        notifyListeners();
      },
    );
  }

  Future<bool> startTask(String taskId) async {
    try {
      await _firestore.updateTask(taskId, {
        'status': 'doing',
      });
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> completeTask(String taskId, String photoBase64) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      await _firestore.updateTask(taskId, {
        'status': 'pending_review',
        'photoUrl': photoBase64,
        'completedAt': DateTime.now(),
      });
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> reportProblem({
    required String reportedBy,
    required String reporterName,
    required String description,
    String? photoUrl,
    String? carOrThing,
  }) async {
    await _firestore.addProblem({
      'reportedBy': reportedBy,
      'reporterName': reporterName,
      'description': description,
      'photoUrl': photoUrl,
      'carOrThing': carOrThing,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  void dispose() {
    super.dispose();
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          final user = snapshot.data;
          if (user == null) {
            return const LoginScreen();
          }
          return const HomeScreen();
        }
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}
