import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

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

/// True on low-RAM Android devices (< 4 GB physical RAM). Budget phones
/// (e.g. Galaxy A03s with 3 GB) commonly kill the Flutter process while the
/// camera app is open; a smaller decode budget reduces that pressure.
Future<bool> isLowEndDevice() async {
  if (kIsWeb) return false;
  try {
    final info = await DeviceInfoPlugin().androidInfo;
    final ramMb = info.physicalRamSize ?? 0;
    if (ramMb <= 0) return false;
    return ramMb < 4096;
  } catch (_) {
    return false;
  }
}
