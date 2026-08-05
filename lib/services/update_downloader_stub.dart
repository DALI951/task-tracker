import 'package:task_tracker/services/update_download_types.dart';

/// No-op download host for web (auto-update is Android-only).
class UpdateDownloaderHost {
  static Future<void> initialize() async {}

  static Future<String?> enqueue({
    required String url,
    required String savedDir,
    required String fileName,
    required bool showNotification,
  }) async =>
      null;

  static Future<List<HostDownloadTask>?> loadTasks() async => null;

  static Future<void> registerCallback(
    void Function(String, int, int) callback,
  ) async {}

  static Future<void> remove(String taskId) async {}

  static Future<bool> fileExists(String path) async => false;
}
