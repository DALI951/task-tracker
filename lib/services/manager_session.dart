/// Holds the signed-in manager's credentials in memory for the current app
/// session only, so employee-account creation can briefly switch the auth
/// session and switch back without re-prompting on every screen. Never
/// persisted to disk — cleared on app restart.
class ManagerSession {
  static String? _email;
  static String? _password;

  static void cache(String email, String password) {
    _email = email;
    _password = password;
  }

  static void clear() {
    _email = null;
    _password = null;
  }

  static String? get email => _email;
  static String? get password => _password;
  static bool get hasCredentials => _email != null && _password != null;
}
