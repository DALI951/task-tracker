import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:googleapis_auth/auth.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

class FcmSender {
  static final FcmSender _instance = FcmSender._();
  factory FcmSender() => _instance;
  FcmSender._();

  ServiceAccountCredentials? _credentials;
  AccessCredentials? _accessCredentials;
  http.Client? _client;

  static const _scope = ['https://www.googleapis.com/auth/firebase.messaging'];
  static const _fcmUrl =
      'https://fcm.googleapis.com/v1/projects/task-tracker-6d7e1/messages:send';

  Future<void> _ensureCredentials() async {
    if (_credentials != null) return;
    try {
      final jsonStr =
          await rootBundle.loadString('assets/service-account.json');
      final jsonData = json.decode(jsonStr) as Map<String, dynamic>;
      _credentials = ServiceAccountCredentials.fromJson(jsonData);
      _client = http.Client();
    } catch (e) {
      debugPrint('Failed to load service account: $e');
    }
  }

  Future<AccessCredentials> _getAccessToken() async {
    await _ensureCredentials();
    if (_credentials == null || _client == null) {
      throw Exception('Service account not loaded');
    }

    if (_accessCredentials != null &&
        _accessCredentials!.accessToken != null &&
        !_accessCredentials!.accessToken!.hasExpired) {
      return _accessCredentials!;
    }

    _accessCredentials =
        await obtainAccessCredentialsViaServiceAccount(
      _credentials!,
      _scope,
      _client!,
    );
    return _accessCredentials!;
  }

  Future<bool> sendPush({
    required String token,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      final credentials = await _getAccessToken();
      final accessToken = credentials.accessToken.data;

      final message = {
        'message': {
          'token': token,
          'notification': {
            'title': title,
            'body': body,
          },
          'android': {
            'priority': 'high',
            'notification': {
              'channel_id': 'task_tracker_channel',
            },
          },
          if (data != null) 'data': data,
        },
      };

      final response = await http.post(
        Uri.parse(_fcmUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: json.encode(message),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        debugPrint('FCM send failed (${response.statusCode}): ${response.body}');
        if (response.statusCode == 401) {
          _accessCredentials = null;
        }
        return false;
      }
    } catch (e) {
      debugPrint('FCM send error: $e');
      return false;
    }
  }

  void dispose() {
    _client?.close();
    _client = null;
    _credentials = null;
    _accessCredentials = null;
  }
}
