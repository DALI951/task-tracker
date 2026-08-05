import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task_tracker/firebase_options.dart';
import 'package:task_tracker/models/task.dart';
import 'package:task_tracker/services/fcm_sender.dart';
import 'package:task_tracker/services/firestore_service.dart';
import 'package:task_tracker/services/storage_service.dart';
import 'package:task_tracker/services/upload_job.dart';

/// Persists queued uploads to a JSON file so the background service can pick
/// them up even if the app (or the service) is restarted mid-upload.
class UploadJobJournal {
  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/upload_jobs.json');
  }

  static Future<List<Map<String, dynamic>>> readAll() async {
    try {
      final f = await _file();
      if (!await f.exists()) return [];
      final data = json.decode(await f.readAsString());
      if (data is List) return data.cast<Map<String, dynamic>>();
    } catch (_) {}
    return [];
  }

  static Future<void> _writeAll(List<Map<String, dynamic>> jobs) async {
    final f = await _file();
    await f.writeAsString(json.encode(jobs));
  }

  static Future<void> add(Map<String, dynamic> job) async {
    final jobs = await readAll();
    jobs.removeWhere((j) => j['id'] == job['id']);
    jobs.add(job);
    await _writeAll(jobs);
  }

  static Future<void> update(String id, Map<String, dynamic> patch) async {
    final jobs = await readAll();
    final idx = jobs.indexWhere((j) => j['id'] == id);
    if (idx < 0) return;
    jobs[idx] = {...jobs[idx], ...patch};
    await _writeAll(jobs);
  }

  static Future<void> remove(String id) async {
    final jobs = await readAll();
    jobs.removeWhere((j) => j['id'] == id);
    await _writeAll(jobs);
  }
}

/// Top-level entry point required by flutter_foreground_task. Must be a
/// top-level function so the plugin can spawn the background isolate from it.
void startUploadTaskHandler() {
  FlutterForegroundTask.setTaskHandler(UploadTaskHandler());
}

/// Runs inside the plugin's background isolate. Drains the persisted upload
/// journal: reads the photo file, uploads it to the PHP server, then applies
/// the Firestore update + notification for the job's [UploadJobType].
///
/// The app can be killed mid-upload — the journal survives in
/// `getApplicationSupportDirectory()` and the next drain retries remaining jobs.
class UploadTaskHandler extends TaskHandler {
  bool _processing = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _processing = false;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
    } catch (e) {
      debugPrint('[UploadTaskHandler] firebase init error: $e');
    }
    await _drainQueue();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    unawaited(_drainQueue());
  }

  @override
  void onReceiveData(Object data) {
    unawaited(_drainQueue());
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onNotificationButtonPressed(String id) {}

  @override
  void onNotificationPressed() {}

  @override
  void onNotificationDismissed() {}

  Future<void> _drainQueue() async {
    if (_processing) return;
    _processing = true;
    try {
      final jobs = await UploadJobJournal.readAll();
      for (final json in jobs) {
        final job = UploadJob.fromJson(json);
        if (job.status == 'done') {
          await UploadJobJournal.remove(job.id);
          continue;
        }
        if (job.status == 'uploading') continue;

        await UploadJobJournal.update(job.id, {'status': 'uploading'});
        final ok = await _process(job);
        if (ok) {
          await UploadJobJournal.remove(job.id);
        } else {
          await UploadJobJournal.update(job.id, {'status': 'failed'});
        }
      }
    } catch (e) {
      debugPrint('[UploadTaskHandler] drain error: $e');
    }
    _processing = false;

    final remaining = await UploadJobJournal.readAll();
    final pending = remaining.where((j) => j['status'] != 'failed').toList();
    if (pending.isEmpty) {
      await FlutterForegroundTask.stopService();
    }
  }

  Future<bool> _process(UploadJob job) async {
    try {
      final bytes = await File(job.filePath).readAsBytes();
      final url = await StorageService.uploadImageBytes(bytes, job.uploadPath);
      if (url == null) return false;

      final fs = FirestoreService();
      switch (job.type) {
        case UploadJobType.taskSubmit:
          await fs.updateTask(job.taskId!, {
            'status': 'pending_review',
            'photoUrl': url,
            'completedAt': DateTime.now(),
            'rejectionReason': null,
          });
          await fs.appendHistory(
            job.taskId!,
            HistoryEvent(
              action: job.historyAction ?? 'submitted_proof',
              by: job.historyBy ?? job.actorName ?? job.actorEmail ?? '',
              detail: job.historyBy ?? job.actorName ?? job.actorEmail ?? '',
              at: DateTime.now(),
            ).toMap(),
          );
          break;

        case UploadJobType.taskApprove:
          await fs.updateTask(job.taskId!, {
            'status': 'completed',
            'photoUrl': url,
            'completedAt': DateTime.now(),
            'approvedBy': job.actorEmail,
            'rejectionReason': null,
          });
          await fs.appendHistory(
            job.taskId!,
            HistoryEvent(
              action: job.historyAction ?? 'approved',
              by: job.historyBy ?? job.actorName ?? job.actorEmail ?? '',
              detail: job.historyBy ?? job.actorName ?? job.actorEmail ?? '',
              at: DateTime.now(),
            ).toMap(),
          );
          break;

        case UploadJobType.problemReport:
          await fs.addProblem({
            'reportedBy': job.reporterEmail,
            'reporterName': job.reporterName,
            'description': job.description,
            'photoUrl': url,
            'carOrThing': job.carOrThing,
            'createdAt': DateTime.now(),
            'status': 'open',
            'convertedToTaskId': null,
            'managerEmail': job.managerEmail,
          });
          break;
      }

      await _notify(job);

      try {
        final f = File(job.filePath);
        if (await f.exists()) await f.delete();
      } catch (_) {}
      return true;
    } catch (e) {
      debugPrint('[UploadTaskHandler] job ${job.id} failed: $e');
      return false;
    }
  }

  Future<void> _notify(UploadJob job) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pref = prefs.getBool('notif_${job.recipientEmail}\_${job.notifType}');
      if (pref == false) return;

      final doc = <String, dynamic>{
        'recipientEmail': job.recipientEmail,
        'type': job.notifType,
        'title': job.notifTitle,
        'message': job.notifMessage,
        'senderName': job.senderName,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      };
      if (job.taskId != null) doc['relatedId'] = job.taskId;
      await FirebaseFirestore.instance.collection('notifications').add(doc);
    } catch (e) {
      debugPrint('[UploadTaskHandler] notification doc error: $e');
    }

    try {
      final usersSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: job.recipientEmail)
          .limit(1)
          .get();
      final token = usersSnap.docs.isEmpty
          ? null
          : usersSnap.docs.first.data()['fcmToken'] as String?;
      if (token != null && token.isNotEmpty) {
        FcmSender().sendPush(
          token: token,
          title: job.notifTitle,
          body: job.notifMessage,
          data: {
            'type': job.notifType,
            if (job.taskId != null) 'relatedId': job.taskId!,
          },
        );
      }
    } catch (e) {
      debugPrint('[UploadTaskHandler] fcm error: $e');
    }
  }
}
