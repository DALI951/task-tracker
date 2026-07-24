import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ConnectivityProvider extends ChangeNotifier {
  bool _online = true;
  bool get online => _online;
  Timer? _timer;

  void start() {
    _check();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _check());
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
    try {
      final response = await http
          .get(Uri.parse('https://clients3.google.com/generate_204'))
          .timeout(const Duration(seconds: 5));
      final online = response.statusCode == 204;
      if (online != _online) {
        _online = online;
        notifyListeners();
      }
    } catch (_) {
      if (_online) {
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
