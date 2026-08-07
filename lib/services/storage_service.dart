import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:task_tracker/config/app_secret.dart';

class StorageService {
  static const _uploadUrl =
      'http://modali.powerpme.com/tasktracker/api/upload-photo.php';

  /// Native apps upload the photo to the PHP backend and get a public URL
  /// back (no Firestore 1 MiB document limit -> full quality). Retries once
  /// before giving up. The web build can't call the HTTP endpoint from the
  /// HTTPS page (mixed content), so it keeps the inline base64 fallback.
  Future<String> uploadImage(Uint8List bytes, String path) async {
    if (!kIsWeb) {
      final uri = Uri.parse(
          '$_uploadUrl?path=${Uri.encodeComponent(path)}');
      // Two attempts: the first may fail on a transient connection hiccup.
      const attempts = 2;
      String? lastError;
      for (var attempt = 0; attempt < attempts; attempt++) {
        if (attempt > 0) {
          await Future<void>.delayed(const Duration(seconds: 1));
        }
        try {
          final resp = await http
              .post(
                uri,
                body: bytes,
                headers: {'Content-Type': 'image/jpeg', 'X-App-Secret': appSecret},
              )
              .timeout(const Duration(seconds: 45));
          if (resp.statusCode == 200) {
            final data = json.decode(resp.body) as Map<String, dynamic>;
            final url = data['url'] as String?;
            if (url != null && url.isNotEmpty) return url;
            lastError = 'Server rejected upload (${resp.statusCode}): ${resp.body}';
          } else {
            lastError = 'Server rejected upload (${resp.statusCode})';
          }
        } catch (e) {
          lastError = 'Upload request failed: $e';
        }
        debugPrint('Photo upload attempt ${attempt + 1} failed: $lastError');
      }
      // On native, a failed upload must fail the whole submission instead of
      // silently falling back to inline base64, which would bloat the task
      // document past Firestore's 1 MiB limit and stall the flow.
      throw Exception(lastError ?? 'Photo upload failed');
    }
    return base64Encode(bytes);
  }

  /// Runs independently of the current route. The provider can therefore
  /// continue uploading when the user navigates away from the form.
  Future<List<String>> uploadImages(
    List<Uint8List> images,
    String pathPrefix, {
    void Function(int completed, int total)? onProgress,
  }) async {
    final urls = <String>[];
    for (var i = 0; i < images.length; i++) {
      urls.add(await uploadImage(
        images[i],
        '$pathPrefix/photo_${i + 1}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));
      onProgress?.call(i + 1, images.length);
    }
    return urls;
  }

  /// True for remote URLs (the new photo format). False for inline base64
  /// stored on task/problem documents.
  static bool isRemotePhoto(String value) {
    return value.startsWith('http://') || value.startsWith('https://');
  }
}
