import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task_tracker/screens/employee_tasks_screen.dart';
import 'package:task_tracker/screens/manager_dashboard.dart';
import 'package:task_tracker/services/settings_service.dart';
import 'package:task_tracker/services/user_service.dart';

class RoleSelectionScreen extends StatelessWidget {
  final String uid;
  const RoleSelectionScreen({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<SettingsService>().t;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.assignment, size: 64, color: Theme.of(context).primaryColor),
              const SizedBox(height: 8),
              Text(
                t('select_role'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await UserService().setRole(uid, 'manager');
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('role_$uid', 'manager');
                    context.read<SettingsService>().currentRole = 'manager';
                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const ManagerDashboard()),
                        (_) => false,
                      );
                    }
                  },
                  icon: const Icon(Icons.admin_panel_settings),
                  label: Text(t('i_am_manager')),
                  style: ElevatedButton.styleFrom(
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await UserService().setRole(uid, 'employee');
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('role_$uid', 'employee');
                    context.read<SettingsService>().currentRole = 'employee';
                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const EmployeeTasksScreen()),
                        (_) => false,
                      );
                    }
                  },
                  icon: const Icon(Icons.person),
                  label: Text(t('i_am_employee')),
                  style: ElevatedButton.styleFrom(
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
