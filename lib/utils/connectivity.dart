import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ConnectivityProvider extends ChangeNotifier {
  bool _online = true;
  bool get online => _online;
  Timer? _timer;
  int _consecutiveFailures = 0;

  static const _endpoints = [
    'https://www.google.com/generate_204',
    'https://www.gstatic.com/generate_204',
    'https://cp.cloudflare.com/generate_204',
  ];

  void start() {
    _check();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _check());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _check() async {
    if (kIsWeb) {
      if (!_online) {
        _online = true;
        notifyListeners();
      }
      return;
    }

    bool reachedInternet = false;
    for (final url in _endpoints) {
      try {
        final response = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 5));
        if (response.statusCode == 204) {
          reachedInternet = true;
          break;
        }
      } catch (_) {}
    }

    if (reachedInternet) {
      _consecutiveFailures = 0;
      if (!_online) {
        _online = true;
        notifyListeners();
      }
    } else {
      _consecutiveFailures++;
      if (_consecutiveFailures >= 2 && _online) {
        _online = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
