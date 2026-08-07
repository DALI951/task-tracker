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
      // A stale 'downloading' file can outlive a worker that was killed after
      // the bytes were all received (a p == 1 progress write clobbered 'done'
      // in older builds). If the APK is actually on disk, call it done.
      final recovered = _recoverDone(s);
      if (recovered != null) {
        _state = UpdateDownloadState.done;
        _progress = 1;
        _filePath = recovered;
        _version = s.version;
        notifyListeners();
        return;
      }
      _state = UpdateDownloadState.downloading;
      _progress = s.progress;
      _version = s.version;
      await _ensureWorkerRunning(s);
      _startPolling();
      notifyListeners();
    } else if (s.state == 'failed') {
      _state = UpdateDownloadState.failed;
      _error = 'download_failed';
      _version = s.version;
      notifyListeners();
    }
  }

  /// Starts the background download worker. Returns immediately; progress is
  /// followed through the state file and the notification. Never restarts an
  /// already-running or already-finished download: reopening the app (or the
  /// update modal reappearing) must not wipe the downloaded APK and start
  /// from 0.
  Future<void> start(String url, String version) async {
    final s = await _readStateFile();
    if (s != null && s.state == 'done') {
      _state = UpdateDownloadState.done;
      _progress = 1;
      _filePath = s.path;
      _version = s.version;
      notifyListeners();
      return;
    }
    if (s != null && s.state == 'downloading') {
      final recovered = _recoverDone(s);
      if (recovered != null) {
        _state = UpdateDownloadState.done;
        _progress = 1;
        _filePath = recovered;
        _version = s.version;
        notifyListeners();
        return;
      }
      // A worker may already be running: keep (no-op) instead of replace.
      // If it was killed, the keep registration starts a fresh one.
      _url = url;
      _version = version;
      _state = UpdateDownloadState.downloading;
      _progress = s.progress;
      _error = null;
      notifyListeners();
      await _ensureWorkerRunning(s, url: url, version: version);
      _startPolling();
      return;
    }
    _url = url;
    _version = version;
    _state = UpdateDownloadState.downloading;
    _progress = null;
    _error = null;
    notifyListeners();

    await _writeStateFile('downloading', 0, null, version, url);
    await Workmanager().registerOneOffTask(
      updateDownloadTaskName,
      updateDownloadTaskName,
      inputData: {'url': url, 'version': version},
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
    _startPolling();
  }

  /// Registers the update worker only if a state file exists but no worker is
  /// known to be running; `keep` never clobbers an active task.
  Future<void> _ensureWorkerRunning(
    ({String state, double? progress, String? path, String? version, String? url}) s, {
    String? url,
    String? version,
  }) async {
    final u = url ?? s.url;
    final v = version ?? s.version;
    if (u == null || v == null || u.isEmpty || v.isEmpty) return;
    try {
      await Workmanager().registerOneOffTask(
        updateDownloadTaskName,
        updateDownloadTaskName,
        inputData: {'url': u, 'version': v},
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingWorkPolicy.keep,
      );
    } catch (_) {}
  }

  /// If the state file says 'downloading' but the bytes were all received
  /// (progress >= 99%) and the APK exists on disk, the download is effectively
  /// complete -> returns the APK path, otherwise null.
  String? _recoverDone(
      ({String state, double? progress, String? path, String? version, String? url}) s) {
    final p = s.progress;
    final path = s.path;
    if (p == null || p < 0.99 || path == null) return null;
    try {
      final f = File(path);
      return f.existsSync() && f.lengthSync() > 0 ? path : null;
    } catch (_) {
      return null;
    }
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
        } else if (s.state == 'done' ||
            (s.state == 'downloading' && _recoverDone(s) != null)) {
          _stopPolling();
          _state = UpdateDownloadState.done;
          _progress = 1;
          _filePath = s.path;
          _url = s.url;
          _version = s.version;
          notifyListeners();
        } else if (s.state == 'failed') {
          _stopPolling();
          _state = UpdateDownloadState.failed;
          _error = 'download_failed';
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
      _error = 'download_missing';
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

  Future<({String state, double? progress, String? path, String? version, String? url})?>
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
        url: map['url'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeStateFile(
      String state, double? progress, String? path, String version, String? url) async {
    try {
      final file = File(await updateStateFilePath());
      await file.writeAsString(json.encode({
        'state': state,
        'progress': progress,
        'path': path,
        'version': version,
        'url': url,
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
