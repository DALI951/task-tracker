import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Maximum photo dimension used by the image picker.
///
/// Web keeps 1024 (inline base64 document budget). Native devices get 2048,
/// except low-end devices (< 2 GB RAM) which drop to 1024 to avoid the OS
/// killing the app while the camera intent is open.
Future<double> pickerMaxDimension() async {
  if (kIsWeb) return 1024;
  if (await isLowEndDevice()) return 1024;
  return 2048;
}

/// True on low-RAM Android devices (< 2 GB physical RAM). These phones
/// commonly kill the Flutter process while the camera app is open; a smaller
/// decode budget reduces that pressure.
Future<bool> isLowEndDevice() async {
  if (kIsWeb) return false;
  try {
    final info = await DeviceInfoPlugin().androidInfo;
    final ramMb = info.physicalRamSize;
    if (ramMb <= 0) return false;
    return ramMb < 2048;
  } catch (_) {
    return false;
  }
}

/// Picks one photo, asking the user whether to take it with the camera or
/// choose it from the device gallery. The web build has no camera picker, so
/// it always opens the gallery.
Future<XFile?> pickPhoto(BuildContext context) async {
  final maxDim = await pickerMaxDimension();
  ImageSource source;
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    source = ImageSource.gallery;
  } else {
    source = await showModalBottomSheet<ImageSource>(
          context: context,
          builder: (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Take a photo'),
                  onTap: () => Navigator.pop(ctx, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Choose from device'),
                  onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                ),
              ],
            ),
          ),
        ) ??
        ImageSource.camera;
  }
  return ImagePicker().pickImage(
    source: source,
    maxWidth: maxDim,
    maxHeight: maxDim,
  );
}

/// Picks one or more photos. On Android the user chooses between the camera
/// (single shot) and the device gallery (multi-select); the web build and
/// desktop always open the gallery (multi-select with single-pick fallback).
Future<List<XFile>> pickPhotos(BuildContext context) async {
  final maxDim = await pickerMaxDimension();
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return _multiOrSingle(ImageSource.gallery, maxDim);
  }
  final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take a photo'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from device'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ) ??
      ImageSource.camera;
  if (source == ImageSource.camera) {
    final single = await ImagePicker().pickImage(
      source: source,
      maxWidth: maxDim,
      maxHeight: maxDim,
    );
    return single == null ? const [] : [single];
  }
  return _multiOrSingle(source, maxDim);
}

Future<List<XFile>> _multiOrSingle(ImageSource source, double maxDim) async {
  try {
    return await ImagePicker().pickMultiImage(
      maxWidth: maxDim,
      maxHeight: maxDim,
    );
  } catch (_) {
    final single = await ImagePicker().pickImage(
      source: source,
      maxWidth: maxDim,
      maxHeight: maxDim,
    );
    return single == null ? const [] : [single];
  }
}
