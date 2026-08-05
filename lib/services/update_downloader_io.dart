import 'dart:io';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:task_tracker/services/update_download_types.dart';

/// flutter_downloader-backed download host (Android/iOS). Uses the system
/// DownloadManager/WorkManager so downloads survive app termination.
class UpdateDownloaderHost {
  static Future<void> initialize() async {
    if (!FlutterDownloader.initialized) {
      await FlutterDownloader.initialize(debug: false);
    }
  }

  static Future<String?> enqueue({
    required String url,
    required String savedDir,
    required String fileName,
    required bool showNotification,
  }) {
    return FlutterDownloader.enqueue(
      url: url,
      savedDir: savedDir,
      fileName: fileName,
      showNotification: showNotification,
      openFileFromNotification: false,
      requiresStorageNotLow: false,
      allowCellular: true,
    );
  }

  static Future<List<HostDownloadTask>?> loadTasks() async {
    final tasks = await FlutterDownloader.loadTasks();
    if (tasks == null) return null;
    return tasks
        .map((t) => HostDownloadTask(
              taskId: t.taskId,
              status: switch (t.status) {
                DownloadTaskStatus.complete => HostDownloadStatus.done,
                DownloadTaskStatus.failed ||
                DownloadTaskStatus.canceled =>
                  HostDownloadStatus.failed,
                _ => HostDownloadStatus.downloading,
              },
              progress: t.progress,
            ))
        .toList();
  }

  static Future<void> registerCallback(
    void Function(String, int, int) callback,
  ) async {
    await FlutterDownloader.registerCallback(callback);
  }

  static Future<void> remove(String taskId) async {
    await FlutterDownloader.remove(taskId: taskId, shouldDeleteContent: true);
  }

  static Future<bool> fileExists(String path) async =>
      await File(path).exists();
}
