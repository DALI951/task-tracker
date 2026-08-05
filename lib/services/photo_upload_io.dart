import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:path_provider/path_provider.dart';
import 'package:task_tracker/services/photo_upload_task_io.dart';
import 'package:task_tracker/services/upload_job.dart';

/// Main-isolate facade. Hands jobs to the background service and manages its
/// lifecycle. Android-only implementation (native). The web build uses the
/// no-op stub in [photo_upload_stub].
class PhotoUploadService {
  static final PhotoUploadService _instance = PhotoUploadService._();
  factory PhotoUploadService() => _instance;
  PhotoUploadService._();

  bool _initialized = false;

  static const int _serviceId = 29409;
  static const String _channelId = 'photo_upload';
  static const String _channelName = 'Photo uploads';
  static const String _channelDescription =
      'Uploads task photos in the background';

  Future<void> init() async {
    if (_initialized) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: _channelId,
        channelName: _channelName,
        channelDescription: _channelDescription,
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(60000),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: false,
        allowAutoRestart: true,
        stopWithTask: false,
      ),
    );
    _initialized = true;
  }

  /// Starts the foreground service (no-op if it is already running) so pending
  /// journal entries get processed.
  Future<void> start() async {
    await init();
    if (await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.startService(
      serviceId: _serviceId,
      serviceTypes: [ForegroundServiceTypes.dataSync],
      notificationTitle: 'Uploading photo…',
      notificationText: 'The photo will upload in the background',
      callback: startUploadTaskHandler,
    );
  }

  Future<void> stop() async {
    await FlutterForegroundTask.stopService();
  }

  /// Persists [job] and asks the background service to process it right away.
  /// Safe to call from anywhere in the main isolate.
  Future<void> enqueue(UploadJob job) async {
    await UploadJobJournal.add(job.toJson());
    await start();
    if (await FlutterForegroundTask.isRunningService) {
      FlutterForegroundTask.sendDataToTask(job.id);
    }
  }

  /// Writes photo bytes to a persistent temp file so the background service can
  /// read them later, even if the app is killed. Returns the file path.
  static Future<String> stagePhoto(Uint8List bytes, String jobId) async {
    final dir = await getApplicationSupportDirectory();
    final folder = Directory('${dir.path}/pending_uploads');
    await folder.create(recursive: true);
    final file = File('${folder.path}/$jobId.jpg');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }
}
