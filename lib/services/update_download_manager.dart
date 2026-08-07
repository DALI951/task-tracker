import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:task_tracker/services/background_worker.dart';
import 'package:workmanager/workmanager.dart';

enum UpdateDownloadState { idle, downloading, done, failed }

/// Downloads the update APK through a Workmanager background task so the
/// download survives the app being backgrounded or killed. The worker mirrors
/// progress to `update_state.json` (app documents); this manager polls that
/// file while the UI is alive and exposes the same ChangeNotifier API the
/// home-screen banner uses. The worker also posts a progress notification
/// that transforms into a "Ready to install" notification with an Install
/// action on completion.
class UpdateDownloadManager extends ChangeNotifier {
  UpdateDownloadState _state = UpdateDownloadState.idle;
  double? _progress;
  String? _filePath;
  String? _error;
  String? _url;
  String? _version;
  Timer? _pollTimer;

  UpdateDownloadState get state => _state;
  double? get progress => _progress;
  String? get filePath => _filePath;
  String? get error => _error;

  bool get isIdle => _state == UpdateDownloadState.idle;
  bool get isDownloading => _state == UpdateDownloadState.downloading;
  bool get isDone => _state == UpdateDownloadState.done;
  bool get hasFailed => _state == UpdateDownloadState.failed;

  /// Restores state from a previous worker session (e.g. the download
  /// finished while the app was closed). Called at startup; a state matching
  /// the installed version is cleared so the banner does not offer an
  /// already-installed build.
  Future<void> restoreState() async {
    final s = await _readStateFile();
    if (s == null) return;

    String installed = '';
    try {
      installed = (await PackageInfo.fromPlatform()).version;
    } catch (_) {}

    if (s.state == 'done' &&
        installed.isNotEmpty &&
        _versionAtLeast(installed, s.version)) {
      await _deleteStateFile();
      return;
    }

    if (s.state == 'done') {
      _state = UpdateDownloadState.done;
      _progress = 1;
      _filePath = s.path;
      _version = s.version;
      notifyListeners();
    } else if (s.state == 'downloading') {
      _state = UpdateDownloadState.downloading;
      _progress = s.progress;
      _version = s.version;
      _startPolling();
      notifyListeners();
    } else if (s.state == 'failed') {
      _state = UpdateDownloadState.failed;
      _error = 'Download failed. Check your connection and try again.';
      _version = s.version;
      notifyListeners();
    }
  }

  /// Starts the background download worker. Returns immediately; progress is
  /// followed through the state file and the notification.
  Future<void> start(String url, String version) async {
    if (_state == UpdateDownloadState.downloading) return;
    _url = url;
    _version = version;
    _state = UpdateDownloadState.downloading;
    _progress = null;
    _error = null;
    notifyListeners();

    await _writeStateFile('downloading', 0, null, version);
    await Workmanager().registerOneOffTask(
      updateDownloadTaskName,
      updateDownloadTaskName,
      inputData: {'url': url, 'version': version},
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
    _startPolling();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _readStateFile().then((s) {
        if (s == null) return;
        if (s.state == 'downloading' &&
            s.progress != null &&
            (s.progress! - (_progress ?? 0)).abs() >= 0.005) {
          _progress = s.progress;
          notifyListeners();
        } else if (s.state == 'done') {
          _stopPolling();
          _state = UpdateDownloadState.done;
          _progress = 1;
          _filePath = s.path;
          notifyListeners();
        } else if (s.state == 'failed') {
          _stopPolling();
          _state = UpdateDownloadState.failed;
          _error = 'Download failed. Check your connection and try again.';
          notifyListeners();
        }
      });
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> retry() async {
    final url = _url;
    final version = _version;
    if (url == null || version == null) return;
    await start(url, version);
  }

  /// Opens the package installer for the downloaded APK (from the banner or
  /// from the notification's Install action). REQUEST_INSTALL_PACKAGES is
  /// requested at app startup.
  Future<void> install() async {
    final s = await _readStateFile();
    final path = s?.path ?? _filePath;
    if (path == null || !File(path).existsSync()) {
      _state = UpdateDownloadState.failed;
      _error = 'Download missing. Please download again.';
      notifyListeners();
      return;
    }
    await OpenFile.open(path);
  }

  void reset() {
    _stopPolling();
    _state = UpdateDownloadState.idle;
    _progress = null;
    _error = null;
    _filePath = null;
    _url = null;
    _version = null;
    _deleteStateFile();
    notifyListeners();
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }

  Future<({String state, double? progress, String? path, String? version})?>
      _readStateFile() async {
    try {
      final file = File(await updateStateFilePath());
      if (!file.existsSync()) return null;
      final map = json.decode(file.readAsStringSync()) as Map<String, dynamic>;
      return (
        state: map['state'] as String? ?? '',
        progress: (map['progress'] as num?)?.toDouble(),
        path: map['path'] as String?,
        version: map['version'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeStateFile(
      String state, double? progress, String? path, String version) async {
    try {
      final file = File(await updateStateFilePath());
      await file.writeAsString(json.encode({
        'state': state,
        'progress': progress,
        'path': path,
        'version': version,
      }));
    } catch (_) {}
  }

  Future<void> _deleteStateFile() async {
    try {
      final file = File(await updateStateFilePath());
      if (file.existsSync()) file.deleteSync();
    } catch (_) {}
  }

  bool _versionAtLeast(String installed, String? target) {
    if (target == null || target.isEmpty) return false;
    final a = installed.split('.').map(int.tryParse).toList();
    final b = target.split('.').map(int.tryParse).toList();
    for (var i = 0; i < a.length && i < b.length; i++) {
      if ((a[i] ?? 0) != (b[i] ?? 0)) return (a[i] ?? 0) > (b[i] ?? 0);
    }
    return a.length >= b.length;
  }
}
