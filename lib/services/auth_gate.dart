import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task_tracker/screens/employee_tasks_screen.dart';
import 'package:task_tracker/screens/login_screen.dart';
import 'package:task_tracker/screens/manager_dashboard.dart';
import 'package:task_tracker/services/settings_service.dart';
import 'package:task_tracker/services/user_service.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _userService = UserService();

  String? _lastUserId;
  String? _resolvedRole;
  bool _loading = true;

  @override
  Widget build(BuildContext context) {
    final settings = context.read<SettingsService>();
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: settings.accentColor),
            ),
          );
        }

        final user = snapshot.data;

        if (user == null) {
          if (_lastUserId != null) {
            _lastUserId = null;
            _resolvedRole = null;
            _loading = true;
          }
          return const LoginScreen();
        }

        if (user.uid != _lastUserId) {
          _lastUserId = user.uid;
          _resolvedRole = null;
          _loading = true;
          _resolveRole(settings, user.uid);
        }

        if (_loading) {
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: settings.accentColor),
            ),
          );
        }

        if (_resolvedRole == null || _resolvedRole!.isEmpty) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline,
                        size: 64, color: Theme.of(context).colorScheme.error),
                    const SizedBox(height: 16),
                    Text(
                      settings.t('account_not_configured'),
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      settings.t('contact_administrator'),
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        FirebaseAuth.instance.signOut();
                      },
                      child: Text(settings.t('sign_out')),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (_resolvedRole == 'manager') {
          return const ManagerDashboard();
        }
        return const EmployeeTasksScreen();
      },
    );
  }

  Future<void> _resolveRole(SettingsService settings, String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('role_$uid');

    if (cached != null && cached.isNotEmpty) {
      settings.currentRole = cached;
      if (mounted) {
        setState(() {
          _resolvedRole = cached;
          _loading = false;
        });
      }
    } else {
      try {
        final role = await _userService
            .getRole(uid)
            .timeout(const Duration(seconds: 10));
        if (role != null && role.isNotEmpty && mounted) {
          await prefs.setString('role_$uid', role);
          settings.currentRole = role;
          setState(() {
            _resolvedRole = role;
            _loading = false;
          });
        } else if (mounted) {
          setState(() {
            _resolvedRole = '';
            _loading = false;
          });
        }
      } catch (_) {
        if (!mounted) return;
        if (cached != null && cached.isNotEmpty) {
          settings.currentRole = cached;
          setState(() {
            _resolvedRole = cached;
            _loading = false;
          });
        } else {
          setState(() {
            _resolvedRole = '';
            _loading = false;
          });
        }
      }
    }
  }
}
