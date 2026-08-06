import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:task_tracker/config/brand.dart';
import 'package:task_tracker/models/preset_task.dart';
import 'package:task_tracker/providers/task_provider.dart';
import 'package:task_tracker/screens/manage_employees_screen.dart';
import 'package:task_tracker/screens/notification_preferences_screen.dart';
import 'package:task_tracker/screens/preset_items_screen.dart';
import 'package:task_tracker/services/settings_service.dart';
import 'package:task_tracker/services/update_service.dart';
import 'package:task_tracker/utils/error_handler.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final t = settings.t;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(t('settings')),
      ),
      body: ListView(
        children: [
          _section(t('language')),
          ListTile(
            title: const Text('English'),
            trailing: settings.language == 'en'
                ? Icon(Icons.check, color: settings.accentColor)
                : null,
            onTap: () => settings.setLanguage('en'),
          ),
          ListTile(
            title: const Text('Français'),
            trailing: settings.language == 'fr'
                ? Icon(Icons.check, color: settings.accentColor)
                : null,
            onTap: () => settings.setLanguage('fr'),
          ),
          ListTile(
            title: const Text('العربية'),
            trailing: settings.language == 'ar'
                ? Icon(Icons.check, color: settings.accentColor)
                : null,
            onTap: () => settings.setLanguage('ar'),
          ),
          const Divider(),
          _section(t('theme')),
          ListTile(
            title: Text(t('light')),
            trailing: settings.themeMode == ThemeMode.light
                ? Icon(Icons.check, color: settings.accentColor)
                : null,
            onTap: () => settings.setThemeMode(ThemeMode.light),
          ),
          ListTile(
            title: Text(t('dark')),
            trailing: settings.themeMode == ThemeMode.dark
                ? Icon(Icons.check, color: settings.accentColor)
                : null,
            onTap: () => settings.setThemeMode(ThemeMode.dark),
          ),
          const Divider(),
          _section(t('accent_color')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                Brand.primary,
                Colors.indigo,
                Colors.blue,
                Colors.teal,
                Colors.green,
                Colors.orange,
                Colors.deepPurple,
                Colors.pink,
              ].map((c) {
                final isSelected = settings.accentColor == c;
                return GestureDetector(
                  onTap: () => settings.setAccentColor(c),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: Colors.white, width: 3)
                          : Border.all(color: c.withAlpha(60)),
                      boxShadow: isSelected
                          ? [BoxShadow(color: c.withAlpha(128), blurRadius: 8)]
                          : null,
                    ),
                    child: isSelected
                        ? Icon(Icons.check,
                            color: c.computeLuminance() > 0.5
                                ? Colors.black54
                                : Colors.white,
                            size: 20)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(),
          _section(t('data')),
          ListTile(
            leading: const Icon(Icons.file_download_outlined),
            title: Text(t('export_data')),
            onTap: () async {
              final tp = context.read<TaskProvider>();
              await tp.exportToClipboard();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(t('exported'))),
                );
              }
            },
          ),
          if (settings.currentRole == 'manager') ...[
            const Divider(),
            _section(t('manage_employees')),
            ListTile(
              leading: const Icon(Icons.people_outline),
              title: Text(t('manage_employees')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ManageEmployeesScreen()),
              ),
            ),
            const Divider(),
            _section(t('manage_items')),
            ListTile(
              leading: const Icon(Icons.list_alt),
              title: Text(t('manage_items')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PresetItemsScreen()),
              ),
            ),
            const Divider(),
            _section(t('preset_tasks')),
            _PresetManager(),
          ],
          const Divider(),
          _section(t('about')),
          SwitchListTile(
            secondary: Icon(
              settings.notificationsEnabled
                  ? Icons.notifications_active
                  : Icons.notifications_off,
              color: settings.notificationsEnabled ? settings.accentColor : Colors.grey,
            ),
            title: Text(t('push_notifications')),
            subtitle: Text(t('push_notifications_desc')),
            value: settings.notificationsEnabled,
            onChanged: (val) => settings.setNotificationsEnabled(val),
          ),
          ListTile(
            leading: const Icon(Icons.tune),
            title: Text(t('notification_preferences')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const NotificationPreferencesScreen(),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.system_update_outlined),
            title: Text(t('check_for_updates')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final updateService = UpdateService();
              final messenger = ScaffoldMessenger.of(context);
              final snackBar = SnackBar(
                content: Text(t('checking_for_updates')),
                duration: const Duration(seconds: 2),
              );
              messenger.showSnackBar(snackBar);
              final found = await updateService.checkForUpdate(context, force: true);
              if (context.mounted && found != true) {
                messenger.hideCurrentSnackBar();
                messenger.showSnackBar(
                  SnackBar(content: Text(t('up_to_date'))),
                );
              }
            },
          ),
          if (!kIsWeb && defaultTargetPlatform != TargetPlatform.android)
            ListTile(
              leading: const Icon(Icons.language),
              title: Text(t('open_web_version')),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => launchUrl(
                Uri.parse('https://dali951.github.io/task-tracker/'),
              ),
            ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              Brand.enterpriseName,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withAlpha(100),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(title,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.grey,
              letterSpacing: 0.5)),
    );
  }
}

class _PresetManager extends StatefulWidget {
  @override
  State<_PresetManager> createState() => _PresetManagerState();
}

class _PresetManagerState extends State<_PresetManager> {
  void _addPreset() {
    showDialog(
      context: context,
      builder: (ctx) => const _AddPresetDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final presets = provider.presets;
    final error = provider.presetsError;
    return Column(
      children: [
        if (error != null)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline,
                    size: 18,
                    color: Theme.of(context).colorScheme.onErrorContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    error,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ...presets.map((p) => ListTile(
              title: Text(p.name),
              subtitle: p.defaultDescription != null
                  ? Text(p.defaultDescription!,
                      maxLines: 1, overflow: TextOverflow.ellipsis)
                  : null,
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () async {
                  final ok = await context
                      .read<TaskProvider>()
                      .deletePreset(p.id);
                  if (!mounted) return;
                  toast(context,
                      ok ? 'Preset deleted' : 'Failed to delete preset',
                      error: !ok);
                },
              ),
            )),
        Padding(
          padding: const EdgeInsets.all(8),
          child: OutlinedButton.icon(
            onPressed: _addPreset,
            icon: const Icon(Icons.add),
            label: Text(context.read<SettingsService>().t('new_preset')),
          ),
        ),
      ],
    );
  }
}

class _AddPresetDialog extends StatefulWidget {
  const _AddPresetDialog();

  @override
  State<_AddPresetDialog> createState() => _AddPresetDialogState();
}

class _AddPresetDialogState extends State<_AddPresetDialog> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _reqCar = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.read<SettingsService>().t;
    return AlertDialog(
      title: Text(t('new_preset')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: t('preset_name'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descCtrl,
              decoration: InputDecoration(
                labelText: t('default_desc'),
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            CheckboxListTile(
              value: _reqCar,
              onChanged: (v) => setState(() => _reqCar = v ?? false),
              title: Text(t('req_car')),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t('cancel')),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_nameCtrl.text.trim().isEmpty) return;
            final ok = await context.read<TaskProvider>().addPreset(
                  PresetTask(
                    id: DateTime.now()
                        .millisecondsSinceEpoch
                        .toString(),
                    name: _nameCtrl.text.trim(),
                    defaultDescription: _descCtrl.text.trim().isEmpty
                        ? null
                        : _descCtrl.text.trim(),
                    requireCarOrThing: _reqCar,
                    createdBy: FirebaseAuth.instance.currentUser?.email,
                  ),
                );
            if (!context.mounted) return;
            if (!ok) {
              toast(context, 'Failed to create preset', error: true);
              return;
            }
            toast(context, 'Preset created');
            Navigator.pop(context);
          },
          child: Text(t('save')),
        ),
      ],
    );
  }
}
