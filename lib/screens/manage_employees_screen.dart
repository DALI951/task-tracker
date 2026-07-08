import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:task_tracker/config/brand.dart';
import 'package:task_tracker/providers/task_provider.dart';
import 'package:task_tracker/services/settings_service.dart';
import 'package:task_tracker/utils/error_handler.dart';

class ManageEmployeesScreen extends StatefulWidget {
  const ManageEmployeesScreen({super.key});

  @override
  State<ManageEmployeesScreen> createState() => _ManageEmployeesScreenState();
}

class _ManageEmployeesScreenState extends State<ManageEmployeesScreen> {
  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _addEmployee() {
    _emailCtrl.clear();
    _nameCtrl.clear();
    _passCtrl.clear();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) {
          bool showPass = false;
          return AlertDialog(
            title: Text(context.read<SettingsService>().t('new_employee')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText: context.read<SettingsService>().t('employee_name'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _passCtrl,
                  decoration: InputDecoration(
                    labelText: context.read<SettingsService>().t('password'),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(showPass ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setDState(() => showPass = !showPass),
                    ),
                  ),
                  obscureText: !showPass,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(context.read<SettingsService>().t('cancel')),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (_emailCtrl.text.isEmpty ||
                      _nameCtrl.text.isEmpty ||
                      _passCtrl.text.length < 6) return;

                  try {
                    final auth = FirebaseAuth.instance;
                    final manager = auth.currentUser;
                    if (manager == null) return;

                    final managerEmail = manager.email ?? '';
                    final managerPass = _passCtrl.text;

                    await auth.createUserWithEmailAndPassword(
                      email: _emailCtrl.text.trim(),
                      password: _passCtrl.text,
                    );

                    await context.read<TaskProvider>().addEmployee(
                          _emailCtrl.text.trim(),
                          _nameCtrl.text.trim(),
                          managerEmail,
                        );

                    await auth.signInWithEmailAndPassword(
                      email: managerEmail,
                      password: managerPass,
                    );

                    _emailCtrl.clear();
                    _nameCtrl.clear();
                    _passCtrl.clear();
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) toast(context, 'Employee created');
                  } catch (e) {
                    if (mounted) toast(context, friendlyError(e), error: true);
                  }
                },
                child: Text(context.read<SettingsService>().t('create')),
              ),
            ],
          );
        },
      ),
    );
  }

  void _renameEmployee(String email, String currentName) {
    final ctrl = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.read<SettingsService>().t('rename_employee')),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            labelText: context.read<SettingsService>().t('employee_name'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () { ctrl.dispose(); Navigator.pop(ctx); },
            child: Text(context.read<SettingsService>().t('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              final ok = await context.read<TaskProvider>().updateEmployeeName(email, ctrl.text.trim());
              ctrl.dispose();
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                toast(context, ok ? context.read<SettingsService>().t('saved') : context.read<TaskProvider>().error ?? 'Failed',
                    error: !ok);
              }
            },
            child: Text(context.read<SettingsService>().t('save')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<SettingsService>().t;
    final employees = context.watch<TaskProvider>().employees;

    return Scaffold(
      appBar: AppBar(title: Text(t('manage_employees'))),
      body: employees.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(100),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(Icons.people_outline,
                        size: 32, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  Text(t('no_employees'),
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            )
          : ListView.builder(
              itemCount: employees.length,
              itemBuilder: (_, i) {
                final emp = employees[i];
                return ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(emp['name'] as String? ?? ''),
                  subtitle: Text(emp['email'] as String? ?? ''),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _renameEmployee(
                          emp['email'] as String? ?? '',
                          emp['name'] as String? ?? '',
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () async {
                          final ok = await context.read<TaskProvider>().deleteEmployee(emp['email'] as String? ?? '');
                          if (mounted && !ok) toast(context, context.read<TaskProvider>().error ?? 'Failed', error: true);
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addEmployee,
        child: const Icon(Icons.person_add),
      ),
    );
  }
}
