import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:task_tracker/config/app_secret.dart';

class StorageService {
  static const String uploadUrl =
      'http://modali.powerpme.com/tasktracker/api/upload-photo.php';

  /// Native apps upload the photo to the PHP backend and get a public URL
  /// back (no Firestore 1 MiB document limit -> full quality). The web build
  /// can't call the HTTP endpoint from the HTTPS page (mixed content), so it
  /// keeps the inline base64 fallback.
  Future<String> uploadImage(Uint8List bytes, String path) async {
    if (!kIsWeb) {
      final url = await uploadImageBytes(bytes, path);
      if (url != null) return url;
    }
    return base64Encode(bytes);
  }

  /// Uploads raw image bytes to the server and returns the public URL, or
  /// null on failure. Shared by the foreground upload service so the upload
  /// logic lives in one place.
  static Future<String?> uploadImageBytes(Uint8List bytes, String path) async {
    try {
      final uri = Uri.parse('$uploadUrl?path=${Uri.encodeComponent(path)}');
      final resp = await http
          .post(uri,
              body: bytes,
              headers: {
                'Content-Type': 'image/jpeg',
                'X-App-Secret': appSecret,
              })
          .timeout(const Duration(seconds: 60));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        final url = data['url'] as String?;
        if (url != null && url.isNotEmpty) return url;
      }
      debugPrint('Photo upload failed (${resp.statusCode}): ${resp.body}');
    } catch (e) {
      debugPrint('Photo upload error: $e');
    }
    return null;
  }

  /// True for remote URLs (the new photo format). False for inline base64
  /// stored on task/problem documents.
  static bool isRemotePhoto(String value) {
    return value.startsWith('http://') || value.startsWith('https://');
  }
}
