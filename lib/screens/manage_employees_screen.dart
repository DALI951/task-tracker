import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:task_tracker/providers/task_provider.dart';
import 'package:task_tracker/services/callables.dart';
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
      builder: (ctx) {
        bool showPass = false;
        bool creating = false;
        return StatefulBuilder(
          builder: (ctx, setDState) {
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
                  onPressed: creating ? null : () => Navigator.pop(ctx),
                  child: Text(context.read<SettingsService>().t('cancel')),
                ),
                ElevatedButton(
                  onPressed: creating
                      ? null
                      : () async {
                          if (_emailCtrl.text.isEmpty ||
                              _nameCtrl.text.isEmpty ||
                              _passCtrl.text.length < 6) return;

                          setDState(() => creating = true);

                          final email = _emailCtrl.text.trim();
                          final name = _nameCtrl.text.trim();
                          final password = _passCtrl.text;

                          try {
                            await Callables.createEmployee(
                              email: email,
                              name: name,
                              password: password,
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) toast(context, 'Employee created');
                          } on FirebaseFunctionsException catch (e) {
                            if (e.code == 'already-exists') {
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (mounted) {
                                _resolveExistingAccount(email, name, password);
                              }
                            } else if (e.code == 'permission-denied') {
                              setDState(() => creating = false);
                              if (mounted) {
                                toast(context,
                                    'This employee was created by another manager',
                                    error: true);
                              }
                            } else {
                              setDState(() => creating = false);
                              if (mounted) {
                                toast(context, friendlyError(e), error: true);
                              }
                            }
                          } catch (e) {
                            setDState(() => creating = false);
                            if (mounted) {
                              toast(context, friendlyError(e), error: true);
                            }
                          }
                        },
                  child: creating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(context.read<SettingsService>().t('create')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _resolveExistingAccount(
      String email, String name, String password) async {
    await showDialog(
      context: context,
      builder: (ctx) {
        bool loading = false;
        String? errorText;

        return StatefulBuilder(
          builder: (ctx, setDState) {
            Future<void> run(
                Future<void> Function() op, String actionName) async {
              setDState(() { loading = true; errorText = null; });
              try {
                await op();
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  toast(
                    context,
                    actionName == 'replace'
                        ? 'Employee replaced & created'
                        : actionName == 'link'
                            ? 'Employee linked successfully'
                            : 'Password changed',
                  );
                }
              } on FirebaseFunctionsException catch (e) {
                setDState(() {
                  loading = false;
                  errorText = e.code == 'permission-denied'
                      ? 'This employee was created by another manager'
                      : friendlyError(e);
                });
              } catch (e) {
                setDState(() { loading = false; errorText = friendlyError(e); });
              }
            }

            return AlertDialog(
              title: const Text('Email Already Registered'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('"$email" is already in use.'),
                  const SizedBox(height: 12),
                  const Text('Choose how to handle this account:'),
                  const SizedBox(height: 8),
                  if (errorText != null) ...[
                    Text(
                      errorText!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (loading) ...[
                    const SizedBox(height: 12),
                    const Center(child: CircularProgressIndicator()),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: loading ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: loading
                      ? null
                      : () => run(
                            () => Callables.setEmployeePassword(
                              email: email,
                              newPassword: password,
                            ),
                            'password',
                          ),
                  child: const Text('Change Password'),
                ),
                TextButton(
                  onPressed: loading
                      ? null
                      : () => run(
                            () => Callables.createEmployee(
                              email: email,
                              name: name,
                              password: password,
                              mode: 'link',
                            ),
                            'link',
                          ),
                  child: const Text('Use Existing'),
                ),
                TextButton(
                  onPressed: loading
                      ? null
                      : () => run(
                            () => Callables.createEmployee(
                              email: email,
                              name: name,
                              password: password,
                              mode: 'replace',
                            ),
                            'replace',
                          ),
                  child: const Text('Replace'),
                ),
              ],
            );
          },
        );
      },
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
            onPressed: () {
              Navigator.pop(ctx);
              ctrl.dispose();
            },
            child: Text(context.read<SettingsService>().t('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              final ok = await context.read<TaskProvider>().updateEmployeeName(email, ctrl.text.trim());
              if (ctx.mounted) Navigator.pop(ctx);
              ctrl.dispose();
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

  void _resetPassword(String email, String name) {
    final newPassCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        bool showPass = false;
        bool loading = false;
        String? errorText;
        return StatefulBuilder(
          builder: (ctx, setDState) {
            return AlertDialog(
              title: const Text('Change Password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Set new password for $name ($email)'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newPassCtrl,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      border: const OutlineInputBorder(),
                      errorText: errorText,
                      suffixIcon: IconButton(
                        icon: Icon(showPass ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setDState(() => showPass = !showPass),
                      ),
                    ),
                    obscureText: !showPass,
                  ),
                  if (loading) ...[
                    const SizedBox(height: 12),
                    const Center(child: CircularProgressIndicator()),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: loading ? null : () {
                    newPassCtrl.dispose();
                    Navigator.pop(ctx);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: loading
                      ? null
                      : () async {
                          if (newPassCtrl.text.length < 6) {
                            setDState(() => errorText = 'Min 6 characters');
                            return;
                          }
                          setDState(() { loading = true; errorText = null; });

                          try {
                            await Callables.setEmployeePassword(
                              email: email,
                              newPassword: newPassCtrl.text,
                            );
                            newPassCtrl.dispose();
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) toast(context, 'Password changed');
                          } on FirebaseFunctionsException catch (e) {
                            setDState(() {
                              loading = false;
                              errorText = e.code == 'not-found'
                                  ? 'No account found with this email'
                                  : e.code == 'permission-denied'
                                      ? 'This employee was created by another manager'
                                      : friendlyError(e);
                            });
                          } catch (e) {
                            setDState(() {
                              loading = false;
                              errorText = friendlyError(e);
                            });
                          }
                        },
                  child: loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Change'),
                ),
              ],
            );
          },
        );
      },
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
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _addEmployee,
                    icon: const Icon(Icons.person_add, size: 18),
                    label: Text(t('create_employee')),
                  ),
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
                        icon: const Icon(Icons.lock_reset, size: 20),
                        onPressed: () => _resetPassword(
                          emp['email'] as String? ?? '',
                          emp['name'] as String? ?? '',
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () => _renameEmployee(
                          emp['email'] as String? ?? '',
                          emp['name'] as String? ?? '',
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                        onPressed: () async {
                          try {
                            await Callables.deleteEmployee(
                              email: emp['email'] as String? ?? '',
                            );
                          } on FirebaseFunctionsException catch (e) {
                            if (mounted) {
                              toast(
                                context,
                                e.code == 'permission-denied'
                                    ? 'This employee was created by another manager'
                                    : friendlyError(e),
                                error: true,
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              toast(context, friendlyError(e), error: true);
                            }
                          }
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
