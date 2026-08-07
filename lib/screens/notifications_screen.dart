import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:task_tracker/models/app_notification.dart';
import 'package:task_tracker/screens/notification_preferences_screen.dart';
import 'package:task_tracker/services/auth_service.dart';
import 'package:task_tracker/services/notification_service.dart';
import 'package:task_tracker/services/settings_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _service = NotificationService();

  @override
  Widget build(BuildContext context) {
    final email = AuthService().currentUser?.email ?? '';
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.read<SettingsService>().t('notifications')),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Preferences',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const NotificationPreferencesScreen()),
            ),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: _service.unreadCountStream(email),
            builder: (context, snapshot) {
              final count = snapshot.data?.docs
                      .where((d) =>
                          (d.data() as Map<String, dynamic>?)?['read'] != true)
                      .length ??
                  0;
              if (count == 0) return const SizedBox.shrink();
              return TextButton(
                onPressed: () async {
                  await _service.markAllRead(email);
                },
                child: Text('Mark all read',
                    style: TextStyle(fontSize: 12, color: cs.primary)),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _service.streamForUser(email),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_none,
                      size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('No notifications yet',
                      style:
                          TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                ],
              ),
            );
          }

          final notifications = snapshot.data!.docs
              .map((d) => AppNotification.fromMap(
                  d.data() as Map<String, dynamic>, d.id))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final n = notifications[index];
              return _NotificationTile(
                notification: n,
                onTap: () async {
                  if (!n.read) await _service.markRead(n.id);
                },
                onDelete: () async {
                  await _service.deleteNotification(n.id);
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onDelete,
  });

  IconData _iconForType(String type) {
    switch (type) {
      case 'task_assigned':
        return Icons.assignment_turned_in;
      case 'task_started':
        return Icons.play_circle_outline;
      case 'task_submitted':
        return Icons.pending_actions;
      case 'task_approved':
        return Icons.check_circle_outline;
      case 'task_rejected':
        return Icons.cancel_outlined;
      case 'task_completed_manager':
        return Icons.task_alt;
      case 'problem_reported':
        return Icons.warning_amber_rounded;
      case 'problem_converted':
        return Icons.transform;
      case 'task_status_changed':
        return Icons.sync;
      default:
        return Icons.notifications;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'task_assigned':
      case 'task_started':
        return const Color(0xFF1565C0);
      case 'task_submitted':
      case 'task_status_changed':
        return const Color(0xFFF57F17);
      case 'task_approved':
      case 'task_completed_manager':
        return const Color(0xFF2E7D32);
      case 'task_rejected':
        return const Color(0xFFC62828);
      case 'problem_reported':
        return const Color(0xFFE65100);
      case 'problem_converted':
        return const Color(0xFF6A1B9A);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorForType(notification.type);
    final icon = _iconForType(notification.type);
    final timeAgo = _timeAgo(notification.createdAt);
    final t = context.read<SettingsService>().t;
    final title = _localizedTitle(t, notification);
    final message = _localizedMessage(t, notification);

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(context.read<SettingsService>().t('delete_notification_q')),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(context.read<SettingsService>().t('cancel'))),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(context.read<SettingsService>().t('delete'))),
            ],
          ),
        );
      },
      onDismissed: (_) => onDelete(),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: notification.read ? FontWeight.normal : FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          message,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(timeAgo,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
            if (!notification.read) ...[
              const SizedBox(height: 4),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _localizedTitle(String Function(String) t, AppNotification n) {
    switch (n.type) {
      case 'task_assigned': return t('notify_task_assigned');
      case 'task_started': return t('notify_task_started');
      case 'task_submitted': return t('notify_task_submitted');
      case 'task_approved': return t('notify_task_approved');
      case 'task_rejected': return t('notify_task_rejected');
      case 'problem_reported': return t('notify_problem_reported');
      case 'problem_converted': return t('notify_problem_converted');
      default: return n.title;
    }
  }

  String _localizedMessage(String Function(String) t, AppNotification n) {
    final name = n.senderName;
    switch (n.type) {
      case 'task_assigned': return '"${_extractQuoted(n.message)}" ${t('notif_task_assigned_msg')}';
      case 'task_started': return '${t('notif_task_started_msg')} "${_extractQuoted(n.message)}"'.replaceAll('{name}', name);
      case 'task_submitted': return '${t('notif_task_submitted_msg')} "${_extractQuoted(n.message)}"'.replaceAll('{name}', name);
      case 'task_approved': return '"${_extractQuoted(n.message)}" ${t('notif_task_approved_msg')}';
      case 'task_rejected': return '"${_extractQuoted(n.message)}" ${t('notif_task_rejected_msg')}';
      case 'problem_reported': return t('notif_problem_reported_msg').replaceAll('{name}', name);
      case 'problem_converted': return t('notif_problem_converted_msg');
      default: return n.message;
    }
  }

  String _extractQuoted(String text) {
    final match = RegExp(r'"([^"]+)"').firstMatch(text);
    return match?.group(1) ?? text;
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${(diff.inDays / 7).floor()}w';
  }
}
