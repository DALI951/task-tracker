import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:task_tracker/providers/task_provider.dart';
import 'package:task_tracker/services/manager_session.dart';
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
  bool _emailConflict = false;
  String? _createError;

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
    _emailConflict = false;
    _createError = null;
    showDialog(
      context: context,
      builder: (ctx) {
        bool showPass = false;
        bool creating = false;
        String? emailError;
        return StatefulBuilder(
          builder: (ctx, setDState) {
            return AlertDialog(
              title: Text(context.read<SettingsService>().t('new_employee')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
               children: [
                  if (emailError != null)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(emailError!, style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w600,
                        )),
                      ),
                    ),
                  TextField(
                    controller: _emailCtrl,
                    decoration: InputDecoration(
                      labelText: context.read<SettingsService>().t('email'),
                      border: const OutlineInputBorder(),
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
                            final created =
                                await _createEmployeeAccount(email, name, password);
                            if (created) {
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (mounted) {
                                toast(context, context.read<SettingsService>().t('employee_created'));
                              }
                            } else {
                              setDState(() {
                                creating = false;
                                emailError = _emailConflict
                                    ? context.read<SettingsService>().t('email_already_used')
                                    : _createError;
                                if (_emailConflict) {
                                  _emailCtrl.clear();
                                }
                              });
                            }
                          } on FirebaseAuthException catch (e) {
                            setDState(() {
                              creating = false;
                              emailError = e.code == 'invalid-email'
                                  ? 'Invalid email address'
                                  : friendlyError(e);
                            });
                          } catch (e) {
                            setDState(() {
                              creating = false;
                              emailError = friendlyError(e);
                            });
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

  /// Creates the employee's Auth account client-side. The auth session briefly
  /// switches to the new account (Firebase limitation), so the manager's
  /// password is cached in memory for this session and used to sign back in.
  /// Returns true when the account was created and the directory doc written.
  Future<bool> _createEmployeeAccount(
      String email, String name, String password) async {
    _createError = null;
    final auth = FirebaseAuth.instance;
    final managerEmail = auth.currentUser?.email ?? '';

    if (!ManagerSession.hasCredentials || ManagerSession.email != managerEmail) {
      final managerPass = await _promptManagerPassword();
      if (managerPass == null || managerPass.isEmpty) return false;
      if (!await _validateManagerPassword(managerEmail, managerPass)) {
        _createError = 'Wrong password';
        return false;
      }
      ManagerSession.cache(managerEmail, managerPass);
    }

    final UserCredential cred;
    try {
      cred = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        _emailConflict = true;
        return false;
      }
      rethrow;
    }

    final uid = cred.user!.uid;

    try {
      await cred.user!.updateDisplayName(name);
    } catch (_) {}

    String? setupError;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'email': email,
        'displayName': name,
        'role': 'employee',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Restore the manager first, then show this error in the still-open form.
      setupError = 'Employee account created but setup failed: ${friendlyError(e)}';
    }

    await auth.signInWithEmailAndPassword(
      email: managerEmail,
      password: ManagerSession.password!,
    );

    await FirebaseFirestore.instance
        .collection('employees')
        .doc(email)
        .set({
          'createdBy': managerEmail,
          'email': email,
          'name': name,
          'authUid': uid,
        }, SetOptions(merge: true));

    if (setupError != null) {
      _createError = setupError;
      return false;
    }

    return true;
  }

  /// Validates the manager's password via the Auth REST endpoint without
  /// switching the current session (client-side creation must swap briefly,
  /// so a bad password must be caught before that happens).
  Future<bool> _validateManagerPassword(String email, String password) async {
    try {
      final apiKey = FirebaseAuth.instance.app.options.apiKey;
      final resp = await Dio().post(
        'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$apiKey',
        data: {
          'email': email,
          'password': password,
          'returnSecureToken': true,
        },
      );
      return resp.statusCode == 200;
    } catch (_) {
      // Couldn't validate (offline etc.) — let the actual re-auth handle it.
      return true;
    }
  }

  Future<String?> _promptManagerPassword() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        bool show = false;
        return StatefulBuilder(
          builder: (ctx, setDState) => AlertDialog(
            title: Text(context.read<SettingsService>().t('confirm_password')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    context.read<SettingsService>().t('manager_password_prompt')),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  decoration: InputDecoration(
                    labelText: context.read<SettingsService>().t('your_password'),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon:
                          Icon(show ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setDState(() => show = !show),
                    ),
                  ),
                  obscureText: !show,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(context.read<SettingsService>().t('cancel')),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, ctrl.text),
                child: Text(context.read<SettingsService>().t('continue')),
              ),
            ],
          ),
        );
      },
    );
    ctrl.dispose();
    return (result == null || result.isEmpty) ? null : result;
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.read<SettingsService>().t('reset_password')),
        content: Text(
            '${context.read<SettingsService>().t('reset_email_confirm')} $name ($email)? ${context.read<SettingsService>().t('reset_they_set')}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.read<SettingsService>().t('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseAuth.instance
                    .sendPasswordResetEmail(email: email);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) toast(context, context.read<SettingsService>().t('reset_email_sent'));
              } catch (e) {
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) toast(context, friendlyError(e), error: true);
              }
            },
            child: Text(context.read<SettingsService>().t('send_reset_email')),
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
                          final email = emp['email'] as String? ?? '';
                          final name = emp['name'] as String? ?? '';
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text(context.read<SettingsService>().t('delete_employee')),
                              content: Text(
                                  '${context.read<SettingsService>().t('delete')} $name ($email)? ${context.read<SettingsService>().t('delete_employee_after')}'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: Text(context.read<SettingsService>().t('cancel')),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red),
                                  child: Text(context.read<SettingsService>().t('delete')),
                                ),
                              ],
                            ),
                          );
                          if (confirmed != true || !mounted) return;
                          try {
                            await FirebaseFirestore.instance
                                .collection('employees')
                                .doc(email)
                                .delete();
                            if (mounted) toast(context, context.read<SettingsService>().t('employee_deleted'));
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
