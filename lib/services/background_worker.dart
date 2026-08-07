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
import 'package:task_tracker/services/settings_service.dart';
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

/// Consecutive automatic retries Workmanager is allowed to perform after a
/// connectivity failure (each with backoff + network constraint). Beyond this
/// the session stays 'failed' and only the in-app Retry button resumes it.
const int maxUploadRetries = 6;

FlutterLocalNotificationsPlugin _notifications() =>
    FlutterLocalNotificationsPlugin();

SettingsService? _workerSettings;
Future<SettingsService> _getSettings() async {
  _workerSettings ??= SettingsService();
  try {
    await _workerSettings!.load();
  } catch (_) {}
  return _workerSettings!;
}

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

  // Workmanager re-ran this task automatically (connectivity came back):
  // resume the SAME session — photos already uploaded keep their 'done'
  // flag, so only the remaining ones go up — and tell the employee.
  if (session.status == 'failed') {
    await UploadSessionService.write(
        session.copyWith(status: 'uploading', error: ''));
    final s = await _getSettings();
    await _showUploadResumed(session.notificationId, session, s);
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
  try {
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
        return !(await _markFailed(sessionId));
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
  } catch (e) {
    // Network or server failure: mark the session 'failed' with a readable
    // reason so the app can tell the employee and offer Retry. Photos that
    // were already uploaded keep their 'done' flag, so Retry continues from
    // where the upload stopped instead of starting over.
    final latest = await UploadSessionService.read(sessionId);
    if (latest == null ||
        latest.status == 'cancelled' ||
        latest.finalApplied) {
      return true;
    }
    final s = await _getSettings();
    final reason = _uploadErrorReason(s, e);
    final retries = latest.retryCount + 1;
    await UploadSessionService.write(latest.copyWith(
        status: 'failed', error: reason, retryCount: retries));
    await _showUploadFailed(notifId, latest, reason, s);
    // Connectivity failures auto-retry: Workmanager waits for the network
    // constraint, then re-runs this task (which resumes from 'failed' and
    // fires the "Upload resumed" notification). Non-connectivity errors and
    // attempts beyond the cap stop here — the in-app Retry button is the
    // only way to continue then.
    final retryable = e is DioException &&
        (e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.receiveTimeout);
    return retryable && retries <= maxUploadRetries ? false : true;
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

/// Marks a session failed and counts the attempt. Returns true when
/// Workmanager should keep auto-retrying (used by the missing-file path).
Future<bool> _markFailed(String sessionId) async {
  final session = await UploadSessionService.read(sessionId);
  if (session == null || session.status == 'cancelled') return true;
  final retries = session.retryCount + 1;
  await UploadSessionService.write(
      session.copyWith(status: 'failed', retryCount: retries));
  return retries <= maxUploadRetries;
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
  final s = await _getSettings();
  final title = isTask
      ? s.t('notif_uploading_task')
      : s.t('notif_uploading_report');
  final what = isTask ? session.taskTitle : '${session.reporterName}: ${session.description}';
  final body = '${_shorten(what, 42)}\n${s.t('notif_photo')} $done/${session.photos.length}'
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

/// Maps an upload exception to a human-readable, already-localized reason
/// stored on the session so the app can show exactly why the upload stopped.
String _uploadErrorReason(SettingsService s, Object e) {
  if (e is DioException) {
    switch (e.type) {
      case DioExceptionType.connectionError:
        return s.t('upload_error_no_internet');
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return s.t('upload_error_timeout');
      case DioExceptionType.badResponse:
        return '${s.t('upload_error_server')} (${e.response?.statusCode ?? '?'})';
      default:
        return s.t('upload_error_generic');
    }
  }
  return s.t('upload_error_generic');
}

/// Replaces the progress notification with a red "Upload stopped" one that
/// states the reason.
Future<void> _showUploadFailed(
    int notifId, UploadSession session, String reason, SettingsService s) async {
  final details = AndroidNotificationDetails(
    _channelId,
    _channelName,
    channelDescription: _channelDescription,
    importance: Importance.high,
    priority: Priority.high,
  );
  await _notifications().show(
    notifId,
    s.t('upload_stopped_title'),
    reason,
    NotificationDetails(android: details),
    payload: json.encode({
      'type': session.type == 'task_completion' ? 'task_upload' : 'problem_upload',
      'relatedId': session.docId,
    }),
  );
}

/// Replaces the stopped notification when Workmanager auto-resumes the upload
/// after connectivity comes back.
Future<void> _showUploadResumed(
    int notifId, UploadSession session, SettingsService s) async {
  final isTask = session.type == 'task_completion';
  final what = isTask
      ? session.taskTitle
      : '${session.reporterName}: ${session.description}';
  final body = '${_shorten(what, 42)}\n${s.t('notif_photo')} '
      '${session.completedPhotos}/${session.photos.length}';
  final details = AndroidNotificationDetails(
    _channelId,
    _channelName,
    channelDescription: _channelDescription,
    importance: Importance.high,
    priority: Priority.high,
  );
  await _notifications().show(
    notifId,
    s.t('notif_upload_resumed'),
    body,
    NotificationDetails(android: details),
    payload: json.encode({
      'type': isTask ? 'task_upload' : 'problem_upload',
      'relatedId': session.docId,
    }),
  );
}

/// Transforms the progress notification in place into a completion one.
Future<void> _showCompletionNotification(
    int notifId, UploadSession session) async {
  final isTask = session.type == 'task_completion';
  final s = await _getSettings();
  final (title, body, tapType) = isTask
      ? session.approveDirectly
          ? (s.t('notify_task_completed_manager'), '“${session.taskTitle}” ${s.t('notif_approved_short')}', 'task_approved')
          : (s.t('notif_task_submitted'), '“${session.taskTitle}” ${s.t('notif_sent_review_short')}', 'task_submitted')
      : (s.t('problem_reported'),
          '“${_shorten(session.description, 42)}” ${s.t('notif_problem_sent')}',
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
  final s = await _getSettings();

  final dir = await getApplicationDocumentsDirectory();
  final path = '${dir.path}/Task-Tracker-v$version.apk';
  final file = File(path);

  // Resume like a torrent: keep whatever bytes are already on disk and ask
  // the server for the rest (HTTP Range). A killed/errored download never
  // restarts from 0.
  var startBytes = file.existsSync() ? file.lengthSync() : 0;

  var lastNotify = 0.0;
  var lastWrite = 0.0;
  var absoluteProgress = startBytes > 0 ? 0.0 : null;
  var absoluteTotal = 0;
  var received = startBytes;

  void pushState(double p) {
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
  }

  try {
    if (startBytes > 0) {
      await _writeUpdateState('downloading', null, path, version, url);
    } else {
      await _writeUpdateState('downloading', 0, path, version, url);
      await _showDownloadProgress(0);
    }

    final response = await Dio().get<ResponseBody>(
      url,
      options: Options(
        responseType: ResponseType.stream,
        followRedirects: true,
        headers: {if (startBytes > 0) 'range': 'bytes=$startBytes-'},
        receiveTimeout: const Duration(seconds: 45),
      ),
    );

    final code = response.statusCode ?? 0;
    if (code == 416) {
      // The server says the range starts past the end: file already complete.
      await _writeUpdateState('done', 1, path, version, url);
      await _showDownloadReady(version);
      return true;
    }
    if (code == 200) {
      // Server ignored the Range header: start over from 0.
      try {
        file.deleteSync();
      } catch (_) {}
      startBytes = 0;
      received = 0;
    } else if (code != 206) {
      await _writeUpdateState('failed', null, path, version, url);
      return false;
    }

    final body = response.data;
    if (body == null) {
      await _writeUpdateState('paused', absoluteProgress, path, version, url);
      return false;
    }

    // For 206 the content-length is only the remaining bytes; adding the
    // bytes already on disk gives the total, so progress matches the APK.
    final contentLength =
        int.tryParse(response.headers.value(Headers.contentLengthHeader) ?? '') ?? 0;
    absoluteTotal = received + contentLength;
    if (absoluteTotal > 0) absoluteProgress = received / absoluteTotal;

    final raf = file.openSync(mode: FileMode.append);
    try {
      await for (final chunk in body.stream) {
        raf.writeFromSync(chunk);
        received += chunk.length;
        if (absoluteTotal > 0) {
          pushState(received / absoluteTotal);
        }
      }
    } finally {
      raf.closeSync();
    }

    await _writeUpdateState('done', 1, path, version, url);
    await _showDownloadReady(version);
    return true;
  } catch (e) {
    debugPrint('Background update download failed: $e');
    // Paused: keep the bytes on disk. Returning false lets Workmanager retry
    // (it waits for connectivity), and the in-app Retry button resumes from
    // where the download stopped.
    await _writeUpdateState('paused', absoluteProgress, path, version, url);
    await _showDownloadPaused(s);
    return false;
  }
}

Future<void> _showDownloadPaused(SettingsService s) async {
  final details = AndroidNotificationDetails(
    _channelId,
    _channelName,
    channelDescription: _channelDescription,
    importance: Importance.low,
    priority: Priority.low,
  );
  await _notifications().show(
    updateNotificationId,
    s.t('notif_download_paused'),
    s.t('download_paused'),
    NotificationDetails(android: details),
    payload: json.encode({'type': 'update_install'}),
  );
}

Future<void> _showDownloadProgress(int percent) async {
  final s = await _getSettings();
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
    s.t('downloading_update'),
    'Task Tracker $percent%',
    NotificationDetails(android: details),
    payload: json.encode({'type': 'update_install'}),
  );
}

Future<void> _showDownloadReady(String version) async {
  final s = await _getSettings();
  final details = AndroidNotificationDetails(
    _channelId,
    _channelName,
    channelDescription: _channelDescription,
    importance: Importance.high,
    priority: Priority.high,
    actions: [
      AndroidNotificationAction('install', s.t('install'), showsUserInterface: true),
    ],
  );
  await _notifications().show(
    updateNotificationId,
    s.t('notif_update_ready'),
    'Task Tracker v$version ${s.t('notif_downloaded')}',
    NotificationDetails(android: details),
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
