import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:truthworld/core/utils/download_helper_stub.dart'
    if (dart.library.js_interop) 'package:truthworld/core/utils/download_helper_web.dart';

/// Cross-platform universal file download utility
class DownloadHelper {
  DownloadHelper._();

  /// Trigger browser / device download from raw bytes
  static Future<void> downloadBytes(
    Uint8List bytes,
    String fileName, {
    String mimeType = 'text/plain',
  }) async {
    await downloadFileFromBytesImpl(bytes, fileName, mimeType);
  }

  /// Trigger browser / device download from a text string (e.g. SRT, VTT)
  static Future<void> downloadText(
    String text,
    String fileName, {
    String mimeType = 'text/plain',
  }) async {
    final bytes = Uint8List.fromList(utf8.encode(text));
    await downloadBytes(bytes, fileName, mimeType: mimeType);
  }

  /// Trigger browser / device download from a remote storage URL (e.g. audio/video stream)
  static Future<void> downloadFromUrl(String url, String fileName) async {
    await downloadFileFromUrlImpl(url, fileName);
  }
}
