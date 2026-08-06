import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:task_tracker/config/app_secret.dart';

class FcmSender {
  static final FcmSender _instance = FcmSender._();
  factory FcmSender() => _instance;
  FcmSender._();

  static const _sendUrl =
      'http://modali.powerpme.com/tasktracker/api/send-push.php';
  static const _timeout = Duration(seconds: 10);

  Future<FcmSendResult> sendPush({
    required String token,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(_sendUrl),
            headers: {
              'Content-Type': 'application/json',
              'X-App-Secret': appSecret,
            },
            body: json.encode({
              'token': token,
              'title': title,
              'body': body,
              if (data != null) 'data': data,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        return const FcmSendResult.success();
      }
      debugPrint('FCM send failed (${response.statusCode}): ${response.body}');
      return FcmSendResult.failure(
        stage: 'relay_http',
        statusCode: response.statusCode,
        detail: response.body,
      );
    } catch (e) {
      debugPrint('FCM send error: $e');
      return FcmSendResult.failure(
        stage: 'relay_network',
        detail: e.toString(),
      );
    }
  }
}

class FcmSendResult {
  final bool ok;
  final String stage;
  final int? statusCode;
  final String? detail;

  const FcmSendResult.success()
      : ok = true,
        stage = 'relay_http',
        statusCode = 200,
        detail = null;

  const FcmSendResult.failure({
    required this.stage,
    this.statusCode,
    this.detail,
  }) : ok = false;
}
