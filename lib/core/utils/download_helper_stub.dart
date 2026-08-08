import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Non-web fallback implementation for file downloading
Future<void> downloadFileFromBytesImpl(
  Uint8List bytes,
  String fileName,
  String mimeType,
) async {
  try {
    final content = utf8.decode(bytes);
    final uri = Uri.dataFromString(content, mimeType: mimeType, encoding: utf8);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  } catch (e) {
    debugPrint('Download stub error: $e');
  }
}

/// Non-web fallback implementation for URL downloading
Future<void> downloadFileFromUrlImpl(String url, String fileName) async {
  try {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  } catch (e) {
    debugPrint('Download URL stub error: $e');
  }
}
