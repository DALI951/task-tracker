import 'dart:convert';
import 'dart:typed_data';

class StorageService {
  String encodeImage(Uint8List bytes) {
    return base64Encode(bytes);
  }

  Uint8List decodeImage(String base64String) {
    return base64Decode(base64String);
  }
}
