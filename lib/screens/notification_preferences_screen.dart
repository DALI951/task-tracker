import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:task_tracker/services/auth_service.dart';
import 'package:task_tracker/services/notification_service.dart';
import 'package:task_tracker/services/settings_service.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  final _service = NotificationService();
  Map<String, bool> _prefs = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final email = AuthService().currentUser?.email ?? '';
    final prefs = await _service.getPrefs(email);
    setState(() {
      _prefs = prefs;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.read<SettingsService>().t;
    final role = context.read<SettingsService>().currentRole;
    final email = AuthService().currentUser?.email ?? '';
    final cs = Theme.of(context).colorScheme;
    final allowedPrefs = NotificationService.prefsForRole(role);

    final managerPrefs = [
      'task_started',
      'task_submitted',
      'task_completed_manager',
      'problem_reported',
      'problem_converted',
      'task_status_changed',
    ];
    final employeePrefs = [
      'task_assigned',
      'task_approved',
      'task_rejected',
      'task_status_changed',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(t('notification_preferences')),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                if (role == 'manager') ...[
                  _sectionHeader(t('manager_notifications'), cs),
                  ...managerPrefs.map((pref) => _buildToggle(
                        pref: pref,
                        email: email,
                        cs: cs,
                      )),
                ],
                if (role == 'employee') ...[
                  _sectionHeader(t('employee_notifications'), cs),
                  ...employeePrefs.map((pref) => _buildToggle(
                        pref: pref,
                        email: email,
                        cs: cs,
                      )),
                ],
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _sectionHeader(String title, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: cs.onSurfaceVariant.withAlpha(150),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildToggle({
    required String pref,
    required String email,
    required ColorScheme cs,
  }) {
    final labelKey = NotificationService.labelKey(pref);
    final t = context.read<SettingsService>().t;
    final enabled = _prefs[pref] ?? true;
    final descKey = '${labelKey}_desc';

    return SwitchListTile(
      title: Text(t(labelKey), style: const TextStyle(fontSize: 14)),
      subtitle: Text(
        t(descKey),
        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
      ),
      value: enabled,
      onChanged: (val) async {
        setState(() => _prefs[pref] = val);
        await _service.setPref(email, pref, val);
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }
}
