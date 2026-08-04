import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class FcmSender {
  static final FcmSender _instance = FcmSender._();
  factory FcmSender() => _instance;
  FcmSender._();

  static const _sendUrl =
      'http://modali.powerpme.com/tasktracker/api/send-push.php';
  static const _timeout = Duration(seconds: 10);

  Future<bool> sendPush({
    required String token,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(_sendUrl),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'token': token,
              'title': title,
              'body': body,
              if (data != null) 'data': data,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        return true;
      }
      debugPrint('FCM send failed (${response.statusCode}): ${response.body}');
      return false;
    } catch (e) {
      debugPrint('FCM send error: $e');
      return false;
    }
  }
}
