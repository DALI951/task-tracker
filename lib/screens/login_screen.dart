import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:task_tracker/services/auth_service.dart';
import 'package:task_tracker/services/settings_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = AuthService();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _isSignUp = false;
  bool _showPass = false;

  String t(String key) => context.read<SettingsService>().t(key);

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final cred = _isSignUp
          ? await _auth.signUp(_emailCtrl.text.trim(), _passwordCtrl.text)
          : await _auth.signIn(_emailCtrl.text.trim(), _passwordCtrl.text);
      final user = cred.user;
      if (user != null && mounted) {
        await context.read<SettingsService>().addAccount(
              user.email ?? _emailCtrl.text.trim(),
              user.displayName ?? _emailCtrl.text.trim(),
            );
      }
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _loading = true);
    try {
      final cred = await _auth.signInWithGoogle();
      final user = cred.user;
      if (user != null && mounted) {
        await context.read<SettingsService>().addAccount(
              user.email ?? '',
              user.displayName ?? user.email ?? '',
            );
      }
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _loginAs(String email) {
    _emailCtrl.text = email;
    _passwordCtrl.text = '';
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final accounts = settings.rememberedAccounts;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.assignment, size: 64, color: Theme.of(context).primaryColor),
                const SizedBox(height: 8),
                Text(
                  settings.t('app_name'),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (accounts.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(settings.t('remembered_accounts'),
                      style: TextStyle(color: Colors.grey.shade600)),
                  const SizedBox(height: 8),
                  ...accounts.take(3).map((a) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: InkWell(
                          onTap: () => _loginAs(a['email']!),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.person_outline,
                                    size: 20, color: Colors.grey.shade500),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(a['name'] ?? a['email'] ?? '',
                                      overflow: TextOverflow.ellipsis),
                                ),
                                InkWell(
                                  onTap: () async {
                                    await settings.removeAccount(a['email']!);
                                  },
                                  child: Icon(Icons.close,
                                      size: 16, color: Colors.grey.shade400),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )),
                ],
                const SizedBox(height: 24),
                TextFormField(
                  controller: _emailCtrl,
                  decoration: InputDecoration(
                    labelText: settings.t('email'),
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) =>
                      v == null || v.isEmpty ? settings.t('email') : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordCtrl,
                  decoration: InputDecoration(
                    labelText: settings.t('password'),
                    prefixIcon: const Icon(Icons.lock_outlined),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_showPass
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setState(() => _showPass = !_showPass),
                    ),
                  ),
                  obscureText: !_showPass,
                  validator: (v) => v == null || v.length < 6
                      ? 'Min 6 characters'
                      : null,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isSignUp
                            ? settings.t('sign_up')
                            : settings.t('sign_in')),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : _signInWithGoogle,
                    icon: const Icon(Icons.g_mobiledata),
                    label: Text(settings.t('sign_in_google')),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () =>
                      setState(() => _isSignUp = !_isSignUp),
                  child: Text(_isSignUp
                      ? settings.t('has_account')
                      : settings.t('no_account')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
