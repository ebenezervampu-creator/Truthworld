// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:url_launcher/url_launcher.dart';

/// Web browser implementation for file downloading
Future<void> downloadFileFromBytesImpl(
  Uint8List bytes,
  String fileName,
  String mimeType,
) async {
  try {
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
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
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..setAttribute('target', '_blank');
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
