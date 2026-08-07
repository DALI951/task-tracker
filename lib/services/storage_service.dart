import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:task_tracker/config/app_secret.dart';

class StorageService {
  static const _uploadUrl =
      'http://modali.powerpme.com/tasktracker/api/upload-photo.php';

  /// Slice size used by chunked uploads (256 KB). Small enough for smooth
  /// byte-level progress on slow connections, large enough to keep the
  /// request count low.
  static const int chunkSize = 256 * 1024;

  /// Native apps upload the photo to the PHP backend and get a public URL
  /// back (no Firestore 1 MiB document limit -> full quality). The web build
  /// can't call the HTTP endpoint from the HTTPS page (mixed content), so it
  /// keeps the inline base64 fallback.
  Future<String> uploadImage(
    Uint8List bytes,
    String path, {
    void Function(int received, int total)? onChunkProgress,
  }) async {
    if (!kIsWeb) {
      return uploadImageChunked(bytes, path,
          onChunkProgress: onChunkProgress);
    }
    return base64Encode(bytes);
  }

  /// Sends the image in fixed-size chunks; each chunk is retried up to 3
  /// times before giving up (the server overwrites a part file per chunk
  /// index, so a retried chunk is idempotent and can never double-write).
  /// The server returns how many bytes of the file it holds after every
  /// chunk, which drives byte-accurate progress even after retries.
  Future<String> uploadImageChunked(
    Uint8List bytes,
    String path, {
    void Function(int received, int total)? onChunkProgress,
  }) async {
    final total = bytes.length;
    if (total == 0) throw Exception('Empty image');
    final chunkCount = ((total + chunkSize - 1) ~/ chunkSize).clamp(1, 1 << 31);
    int received = 0;
    String url = '';
    for (var c = 0; c < chunkCount; c++) {
      final start = c * chunkSize;
      final end = c == chunkCount - 1 ? total : start + chunkSize;
      final chunk = Uint8List.fromList(bytes.sublist(start, end));
      var success = false;
      String? lastError;
      for (var attempt = 0; attempt < 3 && !success; attempt++) {
        if (attempt > 0) {
          await Future<void>.delayed(const Duration(seconds: 1));
        }
        try {
          final uri = Uri.parse(
              '$_uploadUrl?path=${Uri.encodeComponent(path)}&chunk=${c + 1}&total=$chunkCount&totalBytes=$total');
          final resp = await http
              .post(
                uri,
                body: chunk,
                headers: {'Content-Type': 'image/jpeg', 'X-App-Secret': appSecret},
              )
              .timeout(const Duration(seconds: 30));
          if (resp.statusCode == 200) {
            final data = json.decode(resp.body) as Map<String, dynamic>;
            if (c == chunkCount - 1) {
              final u = data['url'] as String?;
              if (u == null || u.isEmpty) {
                lastError = 'Server rejected final chunk';
                continue;
              }
              url = u;
              success = true;
            } else {
              received = (data['received'] as num?)?.toInt() ?? received + chunk.length;
              success = true;
            }
          } else {
            lastError = 'Server rejected upload (${resp.statusCode})';
          }
        } catch (e) {
          lastError = 'Upload request failed: $e';
        }
        if (!success) {
          debugPrint(
              'Photo upload chunk ${c + 1}/$chunkCount attempt ${attempt + 1} failed: $lastError');
        }
      }
      if (!success) {
        // On native, a failed upload must fail the whole submission instead of
        // silently falling back to inline base64, which would bloat the
        // document past Firestore's 1 MiB limit and stall the flow.
        throw Exception(lastError ?? 'Photo upload failed');
      }
      onChunkProgress?.call(received.clamp(0, total), total);
    }
    return url;
  }

  /// Uploads photos one after another (each one internally chunked). Reports
  /// per-photo completion through [onProgress] and smooth byte-level progress
  /// through [onByteProgress] (cumulative across all photos).
  Future<List<String>> uploadImages(
    List<Uint8List> images,
    String pathPrefix, {
    void Function(int completed, int total, List<String> urlsSoFar)?
        onProgress,
    void Function(int bytesSent, int totalBytes)? onByteProgress,
  }) async {
    final urls = <String>[];
    final totalBytes = images.fold<int>(0, (sum, b) => sum + b.length);
    var sentBytes = 0;
    for (var i = 0; i < images.length; i++) {
      final img = images[i];
      final url = await uploadImageChunked(
        img,
        '$pathPrefix/photo_${i + 1}_${DateTime.now().millisecondsSinceEpoch}.jpg',
        onChunkProgress: (received, total) {
          onByteProgress?.call(sentBytes + received, totalBytes);
        },
      );
      sentBytes += img.length;
      urls.add(url);
      onProgress?.call(i + 1, images.length, urls);
    }
    return urls;
  }

  /// True for remote URLs (the new photo format). False for inline base64
  /// stored on task/problem documents.
  static bool isRemotePhoto(String value) {
    return value.startsWith('http://') || value.startsWith('https://');
  }
}
