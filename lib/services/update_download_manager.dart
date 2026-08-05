import 'dart:isolate';
import 'dart:ui' show IsolateNameServer;
import 'package:flutter/foundation.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task_tracker/services/update_download.dart';

enum UpdateDownloadState { idle, downloading, done, failed }

const String _kPortName = 'tt_downloader_send_port';
const String _kPendingVersion = 'pending_update_version';
const String _kPendingTaskId = 'pending_update_task_id';
const String _kPendingFilePath = 'pending_update_file_path';

/// Runs in flutter_downloader's background isolate. Forwards download events to
/// the main isolate over an IsolateNameServer port.
@pragma('vm:entry-point')
void ttDownloadCallback(String id, int status, int progress) {
  final send = IsolateNameServer.lookupPortByName(_kPortName);
  send?.send([id, status, progress]);
}

/// Downloads the update APK with the system DownloadManager (WorkManager), so
/// the download keeps running even if the app is killed. Progress reaches the
/// UI through [ttDownloadCallback]; a pending download/version is persisted in
/// SharedPreferences and restored on the next launch via [restore].
class UpdateDownloadManager extends ChangeNotifier {
  UpdateDownloadState _state = UpdateDownloadState.idle;
  double? _progress;
  String? _filePath;
  String? _error;
  String? _url;
  String? _version;
  String? _taskId;

  ReceivePort? _port;
  Future<void>? _initFuture;

  UpdateDownloadState get state => _state;
  double? get progress => _progress;
  String? get filePath => _filePath;
  String? get error => _error;

  bool get isIdle => _state == UpdateDownloadState.idle;
  bool get isDownloading => _state == UpdateDownloadState.downloading;
  bool get isDone => _state == UpdateDownloadState.done;
  bool get hasFailed => _state == UpdateDownloadState.failed;

  /// Reconnects to any in-flight/completed download left from a previous app
  /// run (the DownloadManager keeps downloading while the app is dead).
  Future<void> restore() async {
    if (kIsWeb) return;
    try {
      await _ensureInitialized();
      _setupPort();
      await UpdateDownloaderHost.registerCallback(ttDownloadCallback);

      final prefs = await SharedPreferences.getInstance();
      final version = prefs.getString(_kPendingVersion);
      final path = prefs.getString(_kPendingFilePath);
      final taskId = prefs.getString(_kPendingTaskId);
      if (version == null || path == null) return;

      var found = false;
      final tasks = await UpdateDownloaderHost.loadTasks();
      if (tasks != null) {
        for (final t in tasks) {
          if (t.taskId == taskId) {
            found = true;
            _version = version;
            _filePath = path;
            _taskId = t.taskId;
            switch (t.status) {
              case HostDownloadStatus.done:
                _state = UpdateDownloadState.done;
                _progress = 1;
                break;
              case HostDownloadStatus.failed:
                _state = UpdateDownloadState.failed;
                _error = 'Download failed. Check your connection and try again.';
                break;
              case HostDownloadStatus.downloading:
                _state = UpdateDownloadState.downloading;
                _progress = t.progress / 100;
            }
            notifyListeners();
            break;
          }
        }
      }

      if (!found && await UpdateDownloaderHost.fileExists(path)) {
        _version = version;
        _filePath = path;
        _state = UpdateDownloadState.done;
        _progress = 1;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> start(String url, String version) async {
    if (_state == UpdateDownloadState.downloading) return;
    if (kIsWeb) return;

    try {
      await _ensureInitialized();
      _setupPort();
      await UpdateDownloaderHost.registerCallback(ttDownloadCallback);

      final dir = await getApplicationDocumentsDirectory();
      final fileName = 'Task-Tracker-v$version.apk';
      final taskId = await UpdateDownloaderHost.enqueue(
        url: url,
        savedDir: dir.path,
        fileName: fileName,
        showNotification: true,
      );
      if (taskId == null) {
        _state = UpdateDownloadState.failed;
        _error = 'Download failed. Check your connection and try again.';
        notifyListeners();
        return;
      }

      _url = url;
      _version = version;
      _taskId = taskId;
      _filePath = '${dir.path}/$fileName';
      _state = UpdateDownloadState.downloading;
      _progress = 0;
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPendingVersion, version);
      await prefs.setString(_kPendingTaskId, taskId);
      await prefs.setString(_kPendingFilePath, _filePath!);
    } catch (_) {
      _state = UpdateDownloadState.failed;
      _error = 'Download failed. Check your connection and try again.';
      notifyListeners();
    }
  }

  Future<void> retry() async {
    final url = _url;
    final version = _version;
    if (url == null || version == null) return;
    await start(url, version);
  }

  Future<void> install() async {
    final path = _filePath;
    if (path == null) return;
    await OpenFile.open(path);
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPendingVersion);
    await prefs.remove(_kPendingTaskId);
    await prefs.remove(_kPendingFilePath);
    if (_taskId != null) {
      try {
        await UpdateDownloaderHost.remove(_taskId!);
      } catch (_) {}
    }
    _state = UpdateDownloadState.idle;
    _progress = null;
    _error = null;
    _filePath = null;
    _url = null;
    _version = null;
    _taskId = null;
    notifyListeners();
  }

  Future<void> _ensureInitialized() {
    return _initFuture ??= UpdateDownloaderHost.initialize();
  }

  void _setupPort() {
    if (_port != null) return;
    final port = ReceivePort();
    IsolateNameServer.removePortNameMapping(_kPortName);
    IsolateNameServer.registerPortWithName(port.sendPort, _kPortName);
    port.listen((data) {
      if (data is List && data.length >= 3) {
        _onDownloadEvent(data[0] as String, data[1] as int, data[2] as int);
      }
    });
    _port = port;
  }

  void _onDownloadEvent(String id, int status, int progress) {
    if (_taskId != null && id != _taskId) return;
    switch (status) {
      case 3: // complete
        _state = UpdateDownloadState.done;
        _progress = 1;
        break;
      case 4: // failed
      case 5: // canceled
        _state = UpdateDownloadState.failed;
        _error = 'Download failed. Check your connection and try again.';
        break;
      case 1: // enqueued
      case 2: // running
      case 6: // paused
        _state = UpdateDownloadState.downloading;
        _progress = progress / 100;
        break;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    IsolateNameServer.removePortNameMapping(_kPortName);
    _port?.close();
    _port = null;
    super.dispose();
  }
}
