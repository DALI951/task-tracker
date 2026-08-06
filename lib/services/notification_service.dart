import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task_tracker/models/app_notification.dart';
import 'package:task_tracker/services/fcm_sender.dart';

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
    String senderName = '',
  }) async {
    final prefs = await getPrefs(recipientEmail);
    if (prefs[type] == false) return;

    final notificationRef = await _ref.add({
      'recipientEmail': recipientEmail,
      'type': type,
      'title': title,
      'message': message,
      'senderName': senderName,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
      'relatedId': relatedId,
    });

    unawaited(_sendAndRecordPush(
      notificationId: notificationRef.id,
      recipientEmail: recipientEmail,
      type: type,
      title: title,
      body: message,
      data: {'type': type, if (relatedId != null) 'relatedId': relatedId},
    ));
  }

  Future<void> _sendAndRecordPush({
    required String notificationId,
    required String recipientEmail,
    required String type,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    final result = await _sendFcmPush(
      recipientEmail: recipientEmail,
      title: title,
      body: body,
      data: data,
    );

    try {
      await _db.collection('push_diagnostics').add({
        'notificationId': notificationId,
        'senderEmail': FirebaseAuth.instance.currentUser?.email ?? '',
        'recipientEmail': recipientEmail,
        'type': type,
        'ok': result.ok,
        'stage': result.stage,
        'statusCode': result.statusCode,
        'detail': _diagnosticDetail(result.detail),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[Notif] Could not write push diagnostic: $e');
    }
  }

  Future<FcmSendResult> _sendFcmPush({
    required String recipientEmail,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      final usersSnap = await _db
          .collection('users')
          .where('email', isEqualTo: recipientEmail)
          .where('role', isEqualTo: 'manager')
          .limit(1)
          .get();
      if (usersSnap.docs.isEmpty) {
        debugPrint('[Notif] No user doc found for $recipientEmail');
        return const FcmSendResult.failure(stage: 'user_lookup_empty');
      }

      final fcmToken = usersSnap.docs.first.data()['fcmToken'] as String?;
      if (fcmToken == null || fcmToken.isEmpty) {
        debugPrint('[Notif] No fcmToken for $recipientEmail');
        return const FcmSendResult.failure(stage: 'token_missing');
      }

      return FcmSender().sendPush(
        token: fcmToken,
        title: title,
        body: body,
        data: data,
      );
    } catch (e) {
      debugPrint('[Notif] _sendFcmPush error: $e');
      return FcmSendResult.failure(
        stage: 'user_lookup_error',
        detail: e.toString(),
      );
    }
  }

  String? _diagnosticDetail(String? detail) {
    if (detail == null || detail.isEmpty) return null;
    return detail.length <= 500 ? detail : detail.substring(0, 500);
  }

  Stream<QuerySnapshot> streamForUser(String email) {
    // Single-field filter only (no composite index needed); caller sorts by
    // createdAt client-side.
    return _ref
        .where('recipientEmail', isEqualTo: email)
        .snapshots();
  }

  Stream<QuerySnapshot> unreadCountStream(String email) {
    // Single-field filter only; caller filters by read client-side.
    return _ref
        .where('recipientEmail', isEqualTo: email)
        .snapshots();
  }

  Future<void> markRead(String notificationId) async {
    await _ref.doc(notificationId).update({'read': true});
  }

  Future<void> markAllRead(String email) async {
    final snap = await _ref
        .where('recipientEmail', isEqualTo: email)
        .get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      if ((doc.data() as Map<String, dynamic>?)?['read'] != true) {
        batch.update(doc.reference, {'read': true});
      }
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
    String senderName = '',
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
          senderName: senderName,
        );
      }
    }
  }
}
