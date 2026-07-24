import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task_tracker/screens/update_modal.dart';

class UpdateService {
  static const _repo = 'DALI951/task-tracker';
  static const _apiUrl =
      'https://api.github.com/repos/$_repo/releases/latest';
  static const _dismissedKey = 'dismissed_version';
  static const _retryAtKey = 'retry_update_at';
  static const _retryVersionKey = 'retry_version';
  static const _retryUrlKey = 'retry_url';
  static const _retryBodyKey = 'retry_body';
  static const _lastCheckKey = 'last_update_check';

  bool isOnHomeScreen = false;
  bool suppressUpdates = false;

  Timer? _retryTimer;
  final Dio _dio = Dio();
  BuildContext? _homeContext;

  static final UpdateService _instance = UpdateService._();
  factory UpdateService() => _instance;
  UpdateService._();

  void setHomeContext(BuildContext context) {
    _homeContext = context;
  }

  void clearHomeContext() {
    _homeContext = null;
    _retryTimer?.cancel();
  }

  void checkPendingRetry() {
    if (!isOnHomeScreen || suppressUpdates || _homeContext == null) return;
    _tryFireRetry();
  }

  void dispose() {
    _retryTimer?.cancel();
  }

  Future<bool> checkForUpdate(BuildContext context,
      {bool force = false}) async {
    if (kIsWeb) return false;
    if (suppressUpdates && !force) return false;

    final prefs = await SharedPreferences.getInstance();

    if (!force) {
      final lastCheck = prefs.getInt(_lastCheckKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - lastCheck < 30 * 60 * 1000) return false;
    }

    try {
      final response = await _dio.get(_apiUrl);
      final data = response.data as Map<String, dynamic>;
      final tagName = data['tag_name'] as String? ?? '';
      final body = data['body'] as String? ?? '';
      final assets = (data['assets'] as List?) ?? [];

      final apkAsset = assets.cast<Map<String, dynamic>?>().firstWhere(
            (a) => (a?['name'] as String?)?.endsWith('.apk') == true,
            orElse: () => null,
          );

      if (apkAsset == null) return false;

      final downloadUrl = apkAsset['browser_download_url'] as String;
      final latestVersion = tagName.replaceFirst('v', '');

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      if (_compareVersions(latestVersion, currentVersion) <= 0) return false;

      await prefs.setInt(_lastCheckKey, DateTime.now().millisecondsSinceEpoch);

      if (!force) {
        final dismissed = prefs.getString(_dismissedKey);
        if (dismissed == latestVersion) return false;
      }

      if (!context.mounted) return false;
      _showUpdateModal(context, currentVersion, latestVersion, downloadUrl,
          body, latestVersion);
      return true;
    } catch (_) {
      return false;
    }
  }

  int _compareVersions(String a, String b) {
    final aParts = a.split('.').map(int.tryParse).toList();
    final bParts = b.split('.').map(int.tryParse).toList();
    final len = aParts.length > bParts.length ? aParts.length : bParts.length;
    for (var i = 0; i < len; i++) {
      final av = i < aParts.length ? (aParts[i] ?? 0) : 0;
      final bv = i < bParts.length ? (bParts[i] ?? 0) : 0;
      if (av != bv) return av.compareTo(bv);
    }
    return 0;
  }

  void _showUpdateModal(
    BuildContext context,
    String currentVersion,
    String latestVersion,
    String downloadUrl,
    String changelog,
    String versionTag,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => UpdateModal(
        currentVersion: currentVersion,
        latestVersion: latestVersion,
        changelog: changelog,
        downloadUrl: downloadUrl,
        onLater: () async {
          Navigator.pop(context);
          final prefs = await SharedPreferences.getInstance();
          final retryAt =
              DateTime.now().millisecondsSinceEpoch + 10 * 60 * 1000;
          await prefs.setInt(_retryAtKey, retryAt);
          await prefs.setString(_retryVersionKey, versionTag);
          await prefs.setString(_retryUrlKey, downloadUrl);
          await prefs.setString(_retryBodyKey, changelog);
          _scheduleRetry();
        },
        onNever: () async {
          Navigator.pop(context);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_dismissedKey, versionTag);
          await prefs.remove(_retryAtKey);
          await prefs.remove(_retryVersionKey);
          await prefs.remove(_retryUrlKey);
          await prefs.remove(_retryBodyKey);
          _retryTimer?.cancel();
        },
      ),
    );
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    SharedPreferences.getInstance().then((prefs) {
      final retryAt = prefs.getInt(_retryAtKey);
      if (retryAt == null) return;

      final now = DateTime.now().millisecondsSinceEpoch;
      final delay = retryAt - now;
      if (delay <= 0) {
        _tryFireRetry();
        return;
      }

      _retryTimer = Timer(Duration(milliseconds: delay), () {
        _tryFireRetry();
      });
    });
  }

  Future<void> _tryFireRetry() async {
    if (!isOnHomeScreen || suppressUpdates || _homeContext == null) return;

    final prefs = await SharedPreferences.getInstance();
    final retryAt = prefs.getInt(_retryAtKey);
    if (retryAt == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now < retryAt) return;

    final version = prefs.getString(_retryVersionKey) ?? '';
    final url = prefs.getString(_retryUrlKey) ?? '';
    final body = prefs.getString(_retryBodyKey) ?? '';

    final dismissed = prefs.getString(_dismissedKey);
    if (dismissed == version) return;

    await prefs.remove(_retryAtKey);
    await prefs.remove(_retryVersionKey);
    await prefs.remove(_retryUrlKey);
    await prefs.remove(_retryBodyKey);

    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    if (_homeContext == null || !_homeContext!.mounted) return;
    _showUpdateModal(
      _homeContext!,
      currentVersion,
      version,
      url,
      body,
      version,
    );
  }
}
