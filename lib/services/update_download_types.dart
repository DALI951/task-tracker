/// Platform-agnostic view of a download task, so the web build never imports
/// flutter_downloader (which pulls in dart:io).
enum HostDownloadStatus { downloading, done, failed }

class HostDownloadTask {
  final String taskId;
  final HostDownloadStatus status;
  final int progress;
  const HostDownloadTask({
    required this.taskId,
    required this.status,
    required this.progress,
  });
}
