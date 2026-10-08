import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web/web.dart' as web;

/// Web browser implementation for file downloading
Future<void> downloadFileFromBytesImpl(
  Uint8List bytes,
  String fileName,
  String mimeType,
) async {
  try {
    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: mimeType),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement
      ..href = url
      ..download = fileName;
    anchor.click();
    web.URL.revokeObjectURL(url);
  } catch (e, stackTrace) {
    ErrorHandler.log(
      e,
      stackTrace: stackTrace,
      tag: 'DownloadHelperWeb.downloadFileFromBytesImpl',
    );
  }
}

/// Web browser implementation for URL downloading
Future<void> downloadFileFromUrlImpl(String url, String fileName) async {
  try {
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement
      ..href = url
      ..download = fileName
      ..target = '_blank';
    anchor.click();
  } catch (e, stackTrace) {
    ErrorHandler.log(
      e,
      stackTrace: stackTrace,
      tag: 'DownloadHelperWeb.downloadFileFromUrlImpl',
    );
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
