import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static final SessionService _instance = SessionService._();
  factory SessionService() => _instance;
  SessionService._();

  static const _emailKey = 'manager_email';
  static const _passKey = 'manager_password';

  String? _email;
  String? _password;

  String? get managerEmail => _email;
  String? get managerPassword => _password;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _email = prefs.getString(_emailKey);
    _password = prefs.getString(_passKey);
  }

  Future<void> saveCredentials(String email, String password) async {
    _email = email;
    _password = password;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_emailKey, email);
    await prefs.setString(_passKey, password);
  }

  Future<void> clear() async {
    _email = null;
    _password = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_emailKey);
    await prefs.remove(_passKey);
  }

  Future<void> reload() async {
    final prefs = await SharedPreferences.getInstance();
    _email = prefs.getString(_emailKey);
    _password = prefs.getString(_passKey);
  }
}
