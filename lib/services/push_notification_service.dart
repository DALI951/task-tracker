import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:task_tracker/services/settings_service.dart';

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {}

class PushNotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static final PushNotificationService _instance =
      PushNotificationService._();
  factory PushNotificationService() => _instance;
  PushNotificationService._();

  NavigatorState? _navigator;
  ScaffoldMessengerState? _scaffoldMessenger;
  SettingsService? _settings;

  void bindContext(NavigatorState nav, ScaffoldMessengerState snack) {
    _navigator = nav;
    _scaffoldMessenger = snack;
  }

  void bindSettings(SettingsService settings) {
    _settings = settings;
  }

  Future<void> initialize() async {
    if (kIsWeb) return;

    await _requestPermission();
    await _initLocalNotifications();
    await _saveToken();

    _messaging.onTokenRefresh.listen((token) => _saveTokenToFirestore(token));

    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _saveToken();
      }
    });

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _onMessageOpenedApp(initialMessage);
      });
    }
  }

  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('FCM permission: ${settings.authorizationStatus}');
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        if (details.payload != null) {
          final data = json.decode(details.payload!);
          _handleNotificationTap(data);
        }
      },
    );
  }

  Future<void> _saveToken() async {
    if (kIsWeb) return;
    final token = await _messaging.getToken();
    if (token != null) await _saveTokenToFirestore(token);
  }

  Future<void> _saveTokenToFirestore(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await _db.collection('users').doc(user.uid).set({
        'fcmToken': token,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Failed to save FCM token: $e');
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    if (_settings != null && !_settings!.notificationsEnabled) return;
    final notification = message.notification;
    if (notification == null) return;

    _showLocalNotification(
      title: notification.title ?? '',
      body: notification.body ?? '',
      payload: json.encode(message.data),
    );

    _scaffoldMessenger?.showSnackBar(
      SnackBar(
        content: Text(
          '${notification.title ?? ''}\n${notification.body ?? ''}',
          maxLines: 2,
        ),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _onMessageOpenedApp(RemoteMessage message) {
    _handleNotificationTap(message.data);
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
    // Could navigate to specific task/problem based on data
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'task_tracker_channel',
      'Task Notifications',
      channelDescription: 'Notifications for task updates',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const details = NotificationDetails(android: androidDetails);
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
      payload: payload,
    );
  }
}
