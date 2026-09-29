// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'package:truthworld/core/errors/error_handler.dart';

/// Web implementation ensuring Cropper.js library and styles are loaded and initialized.
Future<bool> ensureWebCropperLoadedImpl() async {
  try {
    // 1. Check if Cropper constructor already exists on window
    if (_isCropperDefined()) {
      return true;
    }

    // 2. Ensure CSS stylesheet is present
    _ensureStyleSheet();

    // 3. If script tag is not present or not loaded yet, inject it and await readiness
    await _loadScript();

    return _isCropperDefined();
  } catch (e, stackTrace) {
    ErrorHandler.log(
      e,
      stackTrace: stackTrace,
      tag: 'WebCropperLoader.ensureWebCropperLoadedImpl',
    );
    return false;
  }
}

bool _isCropperDefined() {
  try {
    if (!js.context.hasProperty('Cropper')) return false;
    final cropper = js.context['Cropper'];
    if (cropper == null) return false;
    // Strictly verify Cropper is a constructor function to prevent TypeError: dart.global.Cropper is not a constructor
    final typeCheck = js.context.callMethod('eval', <dynamic>["typeof window.Cropper === 'function'"]);
    return typeCheck == true;
  } catch (_) {
    return false;
  }
}

void _ensureStyleSheet() {
  try {
    final existingLink = html.document.querySelector('link[href*="cropper"]');
    if (existingLink == null) {
      final baseUri = html.document.baseUri ?? '';
      final cssHref = baseUri.isNotEmpty
          ? Uri.parse(baseUri).resolve('assets/cropper/cropper.min.css').toString()
          : 'assets/cropper/cropper.min.css';
      final link = html.LinkElement()
        ..rel = 'stylesheet'
        ..href = cssHref;
      html.document.head?.append(link);
    }
  } catch (e, stackTrace) {
    ErrorHandler.log(
      e,
      stackTrace: stackTrace,
      tag: 'WebCropperLoader._ensureStyleSheet',
    );
  }
}

Future<void> _loadScript() async {
  if (_isCropperDefined()) return;

  final completer = Completer<void>();
  final baseUri = html.document.baseUri ?? '';
  final localSrc = baseUri.isNotEmpty
      ? Uri.parse(baseUri).resolve('assets/cropper/cropper.min.js').toString()
      : 'assets/cropper/cropper.min.js';

  final script = html.ScriptElement()
    ..src = localSrc
    ..type = 'text/javascript';

  script.onLoad.listen((_) {
    if (!completer.isCompleted) completer.complete();
  });

  script.onError.listen((_) {
    // Fallback to CDN if local asset fails
    try {
      final cdnScript = html.ScriptElement()
        ..src = 'https://cdnjs.cloudflare.com/ajax/libs/cropperjs/1.6.2/cropper.min.js'
        ..type = 'text/javascript';
      cdnScript.onLoad.listen((_) {
        if (!completer.isCompleted) completer.complete();
      });
      cdnScript.onError.listen((_) {
        if (!completer.isCompleted) completer.complete();
      });
      html.document.head?.append(cdnScript);
    } catch (_) {
      if (!completer.isCompleted) completer.complete();
    }
  });

  html.document.head?.append(script);

  await completer.future.timeout(
    const Duration(milliseconds: 3500),
    onTimeout: () {},
  );
}
