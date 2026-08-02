import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

enum UpdateDownloadState { idle, downloading, done, failed }

/// Downloads the update APK in the background so the user can keep using
/// the app while it runs. Progress is exposed to the UI (home-screen banner);
/// installation is triggered by the user when the download completes.
class UpdateDownloadManager extends ChangeNotifier {
  final Dio _dio = Dio();

  UpdateDownloadState _state = UpdateDownloadState.idle;
  double? _progress;
  String? _filePath;
  String? _error;
  String? _url;
  String? _version;

  UpdateDownloadState get state => _state;
  double? get progress => _progress;
  String? get filePath => _filePath;
  String? get error => _error;

  bool get isIdle => _state == UpdateDownloadState.idle;
  bool get isDownloading => _state == UpdateDownloadState.downloading;
  bool get isDone => _state == UpdateDownloadState.done;
  bool get hasFailed => _state == UpdateDownloadState.failed;

  Future<void> start(String url, String version) async {
    if (_state == UpdateDownloadState.downloading) return;
    _url = url;
    _version = version;
    _state = UpdateDownloadState.downloading;
    _progress = null;
    _error = null;
    notifyListeners();

    final dir = await getApplicationDocumentsDirectory();
    final filePath = '${dir.path}/Task-Tracker-v$version.apk';
    _filePath = filePath;

    try {
      await _dio.download(
        url,
        filePath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            _progress = received / total;
            notifyListeners();
          }
        },
      );
      _state = UpdateDownloadState.done;
      notifyListeners();
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

  void reset() {
    _state = UpdateDownloadState.idle;
    _progress = null;
    _error = null;
    _filePath = null;
    _url = null;
    _version = null;
    notifyListeners();
  }
}
