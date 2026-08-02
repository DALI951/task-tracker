import 'dart:convert';
import 'dart:typed_data';

class StorageService {
  /// Interim: stores image bytes inline as base64 on the document (Firebase
  /// Storage requires the paid plan). Replaced by the PHP backend later.
  Future<String> uploadImage(Uint8List bytes, String path) async {
    return base64Encode(bytes);
  }

  /// True for remote URLs (the new photo format). False for inline base64
  /// stored on task/problem documents.
  static bool isRemotePhoto(String value) {
    return value.startsWith('http://') || value.startsWith('https://');
  }
}
