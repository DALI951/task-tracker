import 'package:cloud_functions/cloud_functions.dart';

/// Thin wrappers around the HTTPS callables in functions/index.js.
/// Server-side operations (Auth mutations, ownership checks) run with the
/// Admin SDK so the client never signs in as the employee or handles a
/// stored password.
class Callables {
  static Future<void> createEmployee({
    required String email,
    required String name,
    required String password,
    String? mode,
  }) async {
    await FirebaseFunctions.instance.httpsCallable('createEmployee').call({
      'email': email,
      'name': name,
      'password': password,
      if (mode != null) 'mode': mode,
    });
  }

  static Future<void> setEmployeePassword({
    required String email,
    required String newPassword,
  }) async {
    await FirebaseFunctions.instance.httpsCallable('setEmployeePassword').call({
      'email': email,
      'newPassword': newPassword,
    });
  }

  static Future<void> deleteEmployee({required String email}) async {
    await FirebaseFunctions.instance.httpsCallable('deleteEmployee').call({
      'email': email,
    });
  }
}
