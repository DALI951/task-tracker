import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task_tracker/models/app_notification.dart';

class NotificationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  CollectionReference get _ref => _db.collection('notifications');

  static const Map<String, bool> _defaultPrefs = {
    'task_assigned': true,
    'task_started': true,
    'task_submitted': true,
    'task_approved': true,
    'task_rejected': true,
    'task_completed_manager': true,
    'problem_reported': true,
    'problem_converted': true,
    'task_status_changed': true,
  };

  static const Map<String, String> _prefLabels = {
    'task_assigned': 'notify_task_assigned',
    'task_started': 'notify_task_started',
    'task_submitted': 'notify_task_submitted',
    'task_approved': 'notify_task_approved',
    'task_rejected': 'notify_task_rejected',
    'task_completed_manager': 'notify_task_completed_manager',
    'problem_reported': 'notify_problem_reported',
    'problem_converted': 'notify_problem_converted',
    'task_status_changed': 'notify_task_status_changed',
  };

  static const Map<String, List<String>> _rolePrefs = {
    'manager': [
      'task_started',
      'task_submitted',
      'task_completed_manager',
      'problem_reported',
      'problem_converted',
      'task_status_changed',
    ],
    'employee': [
      'task_assigned',
      'task_approved',
      'task_rejected',
      'task_status_changed',
    ],
  };

  static List<String> prefsForRole(String role) =>
      _rolePrefs[role] ?? _rolePrefs['employee']!;

  static String labelKey(String pref) => _prefLabels[pref] ?? pref;

  Future<Map<String, bool>> getPrefs(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final result = <String, bool>{};
    for (final key in _defaultPrefs.keys) {
      result[key] = prefs.getBool('notif_$email\_$key') ?? _defaultPrefs[key]!;
    }
    return result;
  }

  Future<void> setPref(String email, String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_$email\_$key', value);
  }

  Future<void> send({
    required String recipientEmail,
    required String type,
    required String title,
    required String message,
    String? relatedId,
  }) async {
    final prefs = await getPrefs(recipientEmail);
    if (prefs[type] == false) return;

    await _ref.add({
      'recipientEmail': recipientEmail,
      'type': type,
      'title': title,
      'message': message,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
      'relatedId': relatedId,
    });
  }

  Stream<QuerySnapshot> streamForUser(String email) {
    return _ref
        .where('recipientEmail', isEqualTo: email)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots();
  }

  Stream<QuerySnapshot> unreadCountStream(String email) {
    return _ref
        .where('recipientEmail', isEqualTo: email)
        .where('read', isEqualTo: false)
        .snapshots();
  }

  Future<void> markRead(String notificationId) async {
    await _ref.doc(notificationId).update({'read': true});
  }

  Future<void> markAllRead(String email) async {
    final snap = await _ref
        .where('recipientEmail', isEqualTo: email)
        .where('read', isEqualTo: false)
        .get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  Future<void> deleteNotification(String id) async {
    await _ref.doc(id).delete();
  }

  Future<void> clearAll(String email) async {
    final snap = await _ref
        .where('recipientEmail', isEqualTo: email)
        .get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<void> sendToManagers({
    required String type,
    required String title,
    required String message,
    String? relatedId,
  }) async {
    final usersSnap = await _db.collection('users')
        .where('role', isEqualTo: 'manager')
        .get();
    for (final doc in usersSnap.docs) {
      final email = doc.data()['email'] as String? ?? '';
      if (email.isNotEmpty) {
        await send(
          recipientEmail: email,
          type: type,
          title: title,
          message: message,
          relatedId: relatedId,
        );
      }
    }
  }
}
