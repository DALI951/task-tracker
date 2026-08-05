import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:task_tracker/screens/notifications_screen.dart';
import 'package:task_tracker/services/auth_service.dart';
import 'package:task_tracker/services/notification_service.dart';

/// Bell icon with unread-count badge that opens [NotificationsScreen].
/// Shown in the app bar of both role dashboards.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    final email = AuthService().currentUser?.email ?? '';
    return StreamBuilder<QuerySnapshot>(
      stream: NotificationService().unreadCountStream(email),
      builder: (context, snapshot) {
        final unread = snapshot.data?.docs
                .where(
                    (d) => (d.data() as Map<String, dynamic>?)?['read'] != true)
                .length ??
            0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              tooltip: 'Notifications',
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              ),
            ),
            if (unread > 0)
              Positioned(
                right: 2,
                top: 2,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  constraints: const BoxConstraints(minWidth: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    unread > 99 ? '99+' : '$unread',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      height: 1,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
