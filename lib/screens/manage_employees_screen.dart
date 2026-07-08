import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:task_tracker/providers/task_provider.dart';
import 'package:task_tracker/services/session_service.dart';
import 'package:task_tracker/services/settings_service.dart';
import 'package:task_tracker/services/user_service.dart';
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
  String? _managerPass;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  String? get _managerEmail => FirebaseAuth.instance.currentUser?.email;

  Future<String?> _ensureManagerPass() async {
    if (_managerPass != null) return _managerPass;
    final saved = SessionService().managerPassword;
    if (saved != null) {
      _managerPass = saved;
      return saved;
    }
    // One-time prompt per session
    final passCtrl = TextEditingController();
    final completer = Completer<String?>();
    bool showPass = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: const Text('Enter Your Password'),
          content: TextField(
            controller: passCtrl,
            decoration: InputDecoration(
              labelText: 'Password',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(showPass ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setDState(() => showPass = !showPass),
              ),
            ),
            obscureText: !showPass,
          ),
          actions: [
            TextButton(
              onPressed: () {
                passCtrl.dispose();
                Navigator.pop(ctx);
                completer.complete(null);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final p = passCtrl.text;
                if (p.isEmpty) return;
                // Verify password by trying to re-auth
                try {
                  await FirebaseAuth.instance.signInWithEmailAndPassword(
                    email: _managerEmail ?? '',
                    password: p,
                  );
                  _managerPass = p;
                  passCtrl.dispose();
                  if (ctx.mounted) Navigator.pop(ctx);
                  completer.complete(p);
                } catch (e) {
                  if (mounted) toast(context, 'Wrong password', error: true);
                }
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
    return completer.future;
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

                          final managerEmail = _managerEmail;
                          if (managerEmail == null) {
                            if (mounted) toast(context, 'Not signed in', error: true);
                            return;
                          }

                          final managerPass = await _ensureManagerPass();
                          if (managerPass == null) {
                            if (mounted) toast(context, 'Password required', error: true);
                            return;
                          }

                          setDState(() => creating = true);

                          final email = _emailCtrl.text.trim();
                          final name = _nameCtrl.text.trim();
                          final password = _passCtrl.text;
                          final auth = FirebaseAuth.instance;

                          try {
                            final result = await auth.createUserWithEmailAndPassword(
                              email: email,
                              password: password,
                            );

                            await UserService().setRole(result.user!.uid, 'employee');

                            await auth.signInWithEmailAndPassword(
                              email: managerEmail,
                              password: managerPass,
                            );

                            await context.read<TaskProvider>().addEmployee(
                                  email,
                                  name,
                                  managerEmail,
                                  password: password,
                                );

                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) toast(context, 'Employee created');
                          } on FirebaseAuthException catch (e) {
                            if (e.code == 'email-already-in-use') {
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (mounted) {
                                _resolveExistingAccount(email, name, password);
                              }
                            } else {
                              setDState(() => creating = false);
                              if (mounted) toast(context, friendlyError(e), error: true);
                            }
                          } catch (e) {
                            setDState(() => creating = false);
                            if (mounted) toast(context, friendlyError(e), error: true);
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
    final passCtrl = TextEditingController(text: password);
    final managerEmail = _managerEmail;
    final managerPass = await _ensureManagerPass();

    await showDialog(
      context: context,
      builder: (ctx) {
        bool showPass = false;
        bool loading = false;
        String? errorText;

        return StatefulBuilder(
          builder: (ctx, setDState) {
            return AlertDialog(
              title: const Text('Email Already Registered'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('"$email" is already in use.'),
                  const SizedBox(height: 12),
                  const Text('Enter the existing password then choose:'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: passCtrl,
                    decoration: InputDecoration(
                      labelText: 'Existing Password',
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
                  onPressed: loading ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: loading
                      ? null
                      : () async {
                          if (passCtrl.text.isEmpty) return;
                          setDState(() { loading = true; errorText = null; });

                          try {
                            final auth = FirebaseAuth.instance;
                            await auth.signInWithEmailAndPassword(
                              email: email,
                              password: passCtrl.text,
                            );
                            await auth.currentUser!.delete();

                            final newUser = await auth.createUserWithEmailAndPassword(
                              email: email,
                              password: password,
                            );
                            await UserService().setRole(newUser.user!.uid, 'employee');

                            if (managerEmail != null && managerPass != null) {
                              await auth.signInWithEmailAndPassword(
                                email: managerEmail,
                                password: managerPass,
                              );
                            }

                            await context.read<TaskProvider>().addEmployee(
                                  email,
                                  name,
                                  managerEmail ?? '',
                                  password: password,
                                );

                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) toast(context, 'Employee replaced & created');
                          } on FirebaseAuthException catch (e) {
                            if (e.code == 'wrong-password' ||
                                e.code == 'invalid-credential') {
                              setDState(() { loading = false; errorText = 'Wrong password'; });
                            } else {
                              setDState(() => loading = false);
                              if (mounted) toast(context, friendlyError(e), error: true);
                            }
                          } catch (e) {
                            setDState(() => loading = false);
                            if (mounted) toast(context, friendlyError(e), error: true);
                          }
                        },
                  child: const Text('Replace'),
                ),
                TextButton(
                  onPressed: loading
                      ? null
                      : () async {
                          if (passCtrl.text.isEmpty) return;
                          setDState(() { loading = true; errorText = null; });

                          try {
                            final auth = FirebaseAuth.instance;
                            await auth.signInWithEmailAndPassword(
                              email: email,
                              password: passCtrl.text,
                            );

                            await UserService().setRole(auth.currentUser!.uid, 'employee');

                            if (managerEmail != null && managerPass != null) {
                              await auth.signInWithEmailAndPassword(
                                email: managerEmail,
                                password: managerPass,
                              );
                            }

                            await context.read<TaskProvider>().addEmployee(
                                  email,
                                  name,
                                  managerEmail ?? '',
                                  password: passCtrl.text,
                                );

                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) toast(context, 'Employee linked successfully');
                          } on FirebaseAuthException catch (e) {
                            if (e.code == 'wrong-password' ||
                                e.code == 'invalid-credential') {
                              setDState(() { loading = false; errorText = 'Wrong password'; });
                            } else {
                              setDState(() => loading = false);
                              if (mounted) toast(context, friendlyError(e), error: true);
                            }
                          } catch (e) {
                            setDState(() => loading = false);
                            if (mounted) toast(context, friendlyError(e), error: true);
                          }
                        },
                  child: const Text('Use Existing'),
                ),
              ],
            );
          },
        );
      },
    );

    passCtrl.dispose();
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
                            final managerEmail = _managerEmail;
                            final managerPass = await _ensureManagerPass();
                            if (managerEmail == null || managerPass == null) {
                              setDState(() { loading = false; errorText = 'Not signed in'; });
                              return;
                            }

                            final auth = FirebaseAuth.instance;
                            final emp = await context.read<TaskProvider>().getEmployee(email);
                            final storedPass = emp?['storedPassword'] as String?;
                            if (storedPass == null) {
                              await auth.sendPasswordResetEmail(email: email);
                              newPassCtrl.dispose();
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (mounted) toast(context, 'Reset email sent (no stored password)');
                              return;
                            }

                            await auth.signInWithEmailAndPassword(
                              email: email,
                              password: storedPass,
                            );
                            await auth.currentUser!.updatePassword(newPassCtrl.text);
                            await auth.signInWithEmailAndPassword(
                              email: managerEmail,
                              password: managerPass,
                            );

                            await context.read<TaskProvider>().updateEmployeeField(email, {
                              'storedPassword': newPassCtrl.text,
                            });

                            newPassCtrl.dispose();
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) toast(context, 'Password changed');
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
