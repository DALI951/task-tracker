import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:task_tracker_employee/services/settings_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Appearance',
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: cs.primary)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Dark Mode'),
                  subtitle: const Text('Toggle dark / light theme'),
                  value: settings.themeMode == ThemeMode.dark,
                  onChanged: (v) async {
                    await settings.setThemeMode(
                        v ? ThemeMode.dark : ThemeMode.light);
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Language',
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: cs.primary)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                RadioListTile<String>(
                  title: const Text('English'),
                  value: 'en',
                  groupValue: settings.language,
                  onChanged: (v) async {
                    if (v != null) {
                      await settings.setLanguage(v);
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                ),
                RadioListTile<String>(
                  title: const Text('Français'),
                  value: 'fr',
                  groupValue: settings.language,
                  onChanged: (v) async {
                    if (v != null) {
                      await settings.setLanguage(v);
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                ),
                RadioListTile<String>(
                  title: const Text('العربية'),
                  value: 'ar',
                  groupValue: settings.language,
                  onChanged: (v) async {
                    if (v != null) {
                      await settings.setLanguage(v);
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Account',
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: cs.primary)),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Icon(Icons.logout, color: cs.error),
              title: Text('Sign Out',
                  style: TextStyle(color: cs.error)),
              onTap: () => FirebaseAuth.instance.signOut(),
            ),
          ),
        ],
      ),
    );
  }
}
