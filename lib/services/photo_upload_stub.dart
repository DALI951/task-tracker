import 'package:flutter/foundation.dart';
import 'package:task_tracker/services/upload_job.dart';

/// No-op main-isolate facade for web. Background photo uploads are Android-only;
/// on web the app keeps the inline base64 photo path (guarded with kIsWeb in
/// the call sites), so this never actually stages or enqueues anything.
class PhotoUploadService {
  static final PhotoUploadService _instance = PhotoUploadService._();
  factory PhotoUploadService() => _instance;
  PhotoUploadService._();

  Future<void> init() async {}

  Future<void> start() async {}

  Future<void> stop() async {}

  Future<void> enqueue(UploadJob job) async {}

  static Future<String> stagePhoto(Uint8List bytes, String jobId) async =>
      '';
}
