import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:task_tracker/firebase_options.dart';
import 'package:task_tracker/services/storage_service.dart';
import 'package:task_tracker/services/upload_finalizer.dart';
import 'package:task_tracker/services/upload_session.dart';
import 'package:workmanager/workmanager.dart';

/// Task names registered with Workmanager.
const String uploadTaskName = 'bg-upload';
const String updateDownloadTaskName = 'bg-update-download';

const String _channelId = 'task_tracker_channel';
const String _channelName = 'Task Notifications';
const String _channelDescription = 'Notifications for task updates';
const int updateNotificationId = 20000;

FlutterLocalNotificationsPlugin _notifications() =>
    FlutterLocalNotificationsPlugin();

Future<void> _ensureChannel() async {
  const channel = AndroidNotificationChannel(
    _channelId,
    _channelName,
    description: _channelDescription,
    importance: Importance.high,
  );
  await _notifications()
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}

/// Entry point for the background isolate. Workmanager runs this function in
/// a fresh isolate when a registered task is due; plugins are available there
/// through `DartPluginRegistrant`.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    switch (task) {
      case uploadTaskName:
        return _runUploadTask((inputData?['sessionId'] as String?) ?? '');
      case updateDownloadTaskName:
        return _runUpdateDownloadTask(inputData);
      default:
        return true;
    }
  });
}

/// Uploads the photos of one session (the ones not marked done), keeps the
/// progress notification + the document counters in sync, then applies the
/// final flip and the completion notification. Returns false on failure so
/// Workmanager retries with backoff; a cancelled or finished session returns
/// true immediately.
Future<bool> _runUploadTask(String sessionId) async {
  if (sessionId.isEmpty) return true;
  await _ensureChannel();
  final session = await UploadSessionService.read(sessionId);
  if (session == null) return true;
  if (session.status == 'cancelled' || session.finalApplied) {
    await UploadSessionService.delete(sessionId);
    return true;
  }

  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {}

  // The Firebase auth session is persisted natively; give it a moment to
  // restore so the final document flip runs as the right user.
  try {
    await FirebaseAuth.instance.authStateChanges().first
        .timeout(const Duration(seconds: 5));
  } catch (_) {}

  final notifId = session.notificationId;
  var done = session.completedPhotos;
  var doneBytes = session.bytesSent;
  var lastByteNotify = DateTime.now().millisecondsSinceEpoch;
  await _showUploadProgress(notifId, session, done, doneBytes, force: true);

  final sessionDir = await UploadSessionService.dir(sessionId);
  for (var i = 0; i < session.photos.length; i++) {
    final photo = session.photos[i];
    if (photo.done) continue;

    // The user may have pressed Stop while this worker ran.
    final latest = await UploadSessionService.read(sessionId);
    if (latest == null ||
        latest.status == 'cancelled' ||
        latest.finalApplied) {
      return true;
    }

    final path = '${sessionDir.path}/${photo.file}';
    if (!File(path).existsSync()) {
      await _markFailed(sessionId);
      return false;
    }
    final bytes = File(path).readAsBytesSync();

    final url = await StorageService().uploadImageChunked(
      bytes,
      '${session.type == 'task_completion' ? 'task_photos' : 'problem_photos'}/$sessionId/photo_${i + 1}_${session.createdAt.millisecondsSinceEpoch}.jpg',
      onChunkProgress: (received, total) {
        doneBytes = session.bytesSent + received;
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - lastByteNotify > 700) {
          lastByteNotify = now;
          unawaited(_showUploadProgress(
              notifId, session, done, doneBytes));
        }
      },
    );

    photo.url = url;
    photo.done = true;
    done++;
    doneBytes += bytes.length;
    final updated = session.copyWith(bytesSent: doneBytes, photos: [
      for (var j = 0; j < session.photos.length; j++)
        if (j == i)
          SessionPhoto(
              file: photo.file, bytes: photo.bytes, url: url, done: true)
        else
          session.photos[j],
    ]);
    await UploadSessionService.write(updated);

    unawaited(_updateDocProgress(updated, done));
    await _showUploadProgress(notifId, updated, done, doneBytes, force: true);
  }

  final completed = await UploadSessionService.read(sessionId);
  if (completed == null || completed.status == 'cancelled') return true;

  final ok = await UploadFinalizer.apply(completed);
  if (!ok) {
    // Document flip failed (usually auth restore): keep the photos uploaded
    // and let the app reconcile the final write on next launch.
    await UploadSessionService.write(completed.copyWith(
      status: 'done',
      finalApplied: false,
      pendingApply: true,
    ));
    await _showCompletionNotification(notifId, completed);
    return true;
  }

  await UploadSessionService.write(
      completed.copyWith(status: 'done', finalApplied: true));
  await _showCompletionNotification(notifId, completed);
  await UploadSessionService.delete(sessionId);
  return true;
}

Future<void> _markFailed(String sessionId) async {
  final session = await UploadSessionService.read(sessionId);
  if (session == null || session.status == 'cancelled') return;
  await UploadSessionService.write(session.copyWith(status: 'failed'));
}

/// Keeps the task/problem document's per-photo counters in sync while the
/// worker uploads (both roles see live progress without opening the app).
Future<void> _updateDocProgress(UploadSession session, int done) async {
  try {
    final urls = session.photos
        .map((p) => p.url)
        .where((u) => u.isNotEmpty)
        .toList();
    final db = FirebaseFirestore.instance;
    if (session.type == 'task_completion') {
      await db.collection('tasks').doc(session.docId).update({
        'photoUrls': urls,
        'uploadCompleted': done,
        'uploadTotal': session.photos.length,
      });
    } else {
      await db.collection('problems').doc(session.docId).update({
        'photoUrls': urls,
        'uploadCompleted': done,
        'uploadTotal': session.photos.length,
      });
    }
  } catch (_) {}
}

Future<void> _showUploadProgress(
  int notifId,
  UploadSession session,
  int done,
  int sentBytes, {
  bool force = false,
}) async {
  final pct = session.totalBytes > 0
      ? (sentBytes / session.totalBytes).clamp(0.0, 1.0)
      : null;
  // Identify WHICH upload this is: with several tasks + problem reports
  // uploading at once each session gets its own notification, and the title
  // says what is being uploaded.
  final isTask = session.type == 'task_completion';
  final title = isTask ? 'Uploading task…' : 'Uploading report…';
  final what = isTask ? session.taskTitle : '${session.reporterName}: ${session.description}';
  final body = '${_shorten(what, 42)}\nPhoto $done/${session.photos.length}'
      '${pct == null ? '' : ' · ${(pct * 100).round()}%'}';
  final details = AndroidNotificationDetails(
    _channelId,
    _channelName,
    channelDescription: _channelDescription,
    importance: Importance.low,
    priority: Priority.low,
    showProgress: pct != null,
    indeterminate: pct == null,
    progress: pct == null ? 0 : (pct * 100).round(),
    onlyAlertOnce: true,
  );
  await _notifications().show(
    notifId,
    title,
    body,
    NotificationDetails(android: details),
    payload: json.encode({
      'type': isTask ? 'task_upload' : 'problem_upload',
      'relatedId': session.docId,
    }),
  );
}

String _shorten(String? s, int max) {
  final trimmed = (s ?? '').trim();
  if (trimmed.length <= max) return trimmed;
  return '${trimmed.substring(0, max - 1)}…';
}

/// Transforms the progress notification in place into a completion one.
Future<void> _showCompletionNotification(
    int notifId, UploadSession session) async {
  final isTask = session.type == 'task_completion';
  final (title, body, tapType) = isTask
      ? session.approveDirectly
          ? ('Task completed', '“${session.taskTitle}” approved', 'task_approved')
          : ('Task submitted', '“${session.taskTitle}” sent for review', 'task_submitted')
      : ('Problem reported',
          '“${_shorten(session.description, 42)}” was sent to the manager',
          'problem_reported');
  final details = AndroidNotificationDetails(
    _channelId,
    _channelName,
    channelDescription: _channelDescription,
    importance: Importance.high,
    priority: Priority.high,
  );
  await _notifications().show(
    notifId,
    title,
    body,
    NotificationDetails(android: details),
    payload: json.encode({'type': tapType, 'relatedId': session.docId}),
  );
}

/// Downloads the update APK in a background task. Progress is mirrored to a
/// state file (`update_state.json` in app documents) so the in-app banner can
/// follow it, and to the progress notification. On completion the
/// notification transforms into "Ready to install" with an Install action
/// that opens the package installer even if the app was closed.
Future<bool> _runUpdateDownloadTask(Map<String, dynamic>? inputData) async {
  final url = inputData?['url'] as String?;
  final version = inputData?['version'] as String?;
  if (url == null || version == null) return true;
  await _ensureChannel();

  final dir = await getApplicationDocumentsDirectory();
  final path = '${dir.path}/Task-Tracker-v$version.apk';
  final file = File(path);
  if (file.existsSync()) {
    try {
      file.deleteSync();
    } catch (_) {}
  }

  await _writeUpdateState('downloading', 0, path, version, url);
  await _showDownloadProgress(0);

  var lastNotify = 0.0;
  var lastWrite = 0.0;
  try {
    await Dio().download(
      url,
      path,
      onReceiveProgress: (received, total) {
        if (total <= 0) return;
        final p = received / total;
        // Never write p >= 1 as 'downloading': the synchronous 'done' write
        // below must be the last thing the state file ever sees.
        if (p < 1 && p - lastWrite >= 0.01) {
          lastWrite = p;
          unawaited(_writeUpdateState('downloading', p, path, version, url));
        }
        if (p - lastNotify >= 0.02 || p >= 1) {
          lastNotify = p;
          unawaited(_showDownloadProgress((p * 100).round()));
        }
      },
    );

    await _writeUpdateState('done', 1, path, version, url);
    await _showDownloadReady(version);
    return true;
  } catch (e) {
    debugPrint('Background update download failed: $e');
    await _writeUpdateState('failed', null, path, version, url);
    return false;
  }
}

Future<void> _showDownloadProgress(int percent) async {
  final details = AndroidNotificationDetails(
    _channelId,
    _channelName,
    channelDescription: _channelDescription,
    importance: Importance.low,
    priority: Priority.low,
    showProgress: true,
    progress: percent,
    onlyAlertOnce: true,
  );
  await _notifications().show(
    updateNotificationId,
    'Downloading update…',
    'Task Tracker $percent%',
    NotificationDetails(android: details),
    payload: json.encode({'type': 'update_install'}),
  );
}

Future<void> _showDownloadReady(String version) async {
  const details = AndroidNotificationDetails(
    _channelId,
    _channelName,
    channelDescription: _channelDescription,
    importance: Importance.high,
    priority: Priority.high,
    actions: [
      AndroidNotificationAction('install', 'Install', showsUserInterface: true),
    ],
  );
  await _notifications().show(
    updateNotificationId,
    'Update ready to install',
    'Task Tracker v$version downloaded',
    const NotificationDetails(android: details),
    payload: json.encode({'type': 'update_install'}),
  );
}

/// State file path shared with `UpdateDownloadManager`.
Future<String> updateStateFilePath() async {
  final dir = await getApplicationDocumentsDirectory();
  return '${dir.path}/update_state.json';
}

/// Synchronous write so the progress/final writes can never interleave out of
/// order: the final 'done' write is guaranteed to land last, and the app can
/// never observe a stale 'downloading' state after completion.
Future<void> _writeUpdateState(String state, double? progress, String path,
    String version, String? url) async {
  try {
    final file = File(await updateStateFilePath());
    file.writeAsStringSync(json.encode({
      'state': state,
      'progress': progress,
      'path': path,
      'version': version,
      'url': url,
    }));
  } catch (_) {}
}
