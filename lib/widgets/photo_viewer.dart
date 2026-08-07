import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:task_tracker/config/brand.dart';
import 'package:task_tracker/services/storage_service.dart';

/// Full-screen, zoomable photo viewer. Accepts the same values stored in
/// `photoUrls` fields: remote URLs and/or inline base64. Swipe between
/// photos, pinch to zoom, tap the photo to hide/show the controls.
class PhotoViewer {
  static Future<void> show(
    BuildContext context, {
    required List<String> photos,
    required int initialIndex,
  }) {
    if (photos.isEmpty) return Future.value();
    return Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _PhotoViewerScreen(
          photos: photos,
          initialIndex: initialIndex.clamp(0, photos.length - 1),
        ),
      ),
    );
  }
}

class _PhotoViewerScreen extends StatefulWidget {
  final List<String> photos;
  final int initialIndex;

  const _PhotoViewerScreen({
    required this.photos,
    required this.initialIndex,
  });

  @override
  State<_PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<_PhotoViewerScreen> {
  late final PageController _controller =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;
  bool _showOverlay = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.photos.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => setState(() => _showOverlay = !_showOverlay),
              child: SizedBox.expand(
                child: InteractiveViewer(
                  maxScale: 6,
                  child: Center(child: _buildImage(widget.photos[i])),
                ),
              ),
            ),
          ),
          AnimatedOpacity(
            opacity: _showOverlay ? 1 : 0,
            duration: const Duration(milliseconds: 150),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    Text(
                      '${_index + 1} / ${widget.photos.length}',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage(String photo) {
    const broken = Center(
      child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
    );
    if (StorageService.isRemotePhoto(photo)) {
      return CachedNetworkImage(
        imageUrl: photo,
        fit: BoxFit.contain,
        placeholder: (_, __) => const Center(
          child: CircularProgressIndicator(color: Colors.white54),
        ),
        errorWidget: (_, __, ___) => broken,
        fadeInDuration: const Duration(milliseconds: 120),
      );
    }
    try {
      return Image.memory(
        base64Decode(photo),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => broken,
      );
    } catch (_) {
      return broken;
    }
  }
}

/// Thumbnail that shows a placeholder box instantly and swaps in the image
/// preview once its bytes have been read lazily from the picked file. Picking
/// many large photos stays instant; the heavy disk reads happen in the
/// background per thumbnail.
class LazyPhotoThumb extends StatefulWidget {
  final XFile file;
  final double size;
  final BorderRadius borderRadius;

  const LazyPhotoThumb({
    super.key,
    required this.file,
    required this.size,
    this.borderRadius = const BorderRadius.all(Radius.circular(Brand.radiusSm)),
  });

  @override
  State<LazyPhotoThumb> createState() => _LazyPhotoThumbState();
}

class _LazyPhotoThumbState extends State<LazyPhotoThumb> {
  late final Future<Uint8List> _bytes = widget.file.readAsBytes();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: FutureBuilder<Uint8List>(
        future: _bytes,
        builder: (context, snap) {
          if (snap.hasData) {
            return Image.memory(
              snap.data!,
              width: widget.size,
              height: widget.size,
              fit: BoxFit.cover,
              cacheWidth: (widget.size * 2).round(),
            );
          }
          return Container(
            width: widget.size,
            height: widget.size,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Remote thumbnail with an instant spinner placeholder, a broken-image
/// fallback and disk + memory caching (via `cached_network_image`), so
/// re-viewing a photo never waits on the network again. Fixed-size by design
/// (like [LazyPhotoThumb]); for full-screen viewing use [PhotoViewer].
class RemotePhoto extends StatelessWidget {
  final String url;
  final double width;
  final double height;
  final BoxFit fit;
  final BorderRadius borderRadius;

  const RemotePhoto({
    super.key,
    required this.url,
    required this.width,
    required this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = const BorderRadius.all(Radius.circular(Brand.radiusSm)),
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final placeholder = Container(
      width: width,
      height: height,
      color: cs.surfaceContainerHighest,
      child: Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: cs.outline,
          ),
        ),
      ),
    );
    return ClipRRect(
      borderRadius: borderRadius,
      child: CachedNetworkImage(
        imageUrl: url,
        width: width,
        height: height,
        fit: fit,
        memCacheWidth: (width * 2).round(),
        maxWidthDiskCache: 2048,
        placeholder: (_, __) => placeholder,
        errorWidget: (_, __, ___) => Container(
          width: width,
          height: height,
          color: cs.surfaceContainerHighest,
          child: Icon(Icons.broken_image, size: 24, color: cs.outline),
        ),
        fadeInDuration: const Duration(milliseconds: 120),
        fadeOutDuration: const Duration(milliseconds: 60),
      ),
    );
  }
}
