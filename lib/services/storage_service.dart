import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  /// Uploads image bytes to Firebase Storage and returns the download URL.
  Future<String> uploadImage(Uint8List bytes, String path) async {
    final ref = FirebaseStorage.instance.ref(path);
    final task =
        await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return await task.ref.getDownloadURL();
  }

  /// True for remote Storage download URLs (the new photo format). False for
  /// legacy inline base64 data stored on older task/problem documents.
  static bool isRemotePhoto(String value) {
    return value.startsWith('http://') || value.startsWith('https://');
  }
}
