import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:web/web.dart' as web;

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
    if (!globalContext.has('Cropper')) return false;
    final cropper = globalContext['Cropper'];
    if (cropper == null) return false;
    return cropper.typeofEquals('function');
  } catch (_) {
    return false;
  }
}

void _ensureStyleSheet() {
  try {
    final existingLink = web.document.querySelector('link[href*="cropper"]');
    if (existingLink == null) {
      final baseUri = web.document.baseURI;
      final cssHref = baseUri.isNotEmpty
          ? Uri.parse(baseUri).resolve('assets/cropper/cropper.min.css').toString()
          : 'assets/cropper/cropper.min.css';
      final link = web.document.createElement('link') as web.HTMLLinkElement
        ..rel = 'stylesheet'
        ..href = cssHref;
      web.document.head?.append(link);
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
  final baseUri = web.document.baseURI;
  final localSrc = baseUri.isNotEmpty
      ? Uri.parse(baseUri).resolve('assets/cropper/cropper.min.js').toString()
      : 'assets/cropper/cropper.min.js';

  final script = web.document.createElement('script') as web.HTMLScriptElement
    ..src = localSrc
    ..type = 'text/javascript';

  script.onload = ((web.Event _) {
    if (!completer.isCompleted) completer.complete();
  }).toJS;

  script.onerror = ((web.Event _) {
    // Fallback to CDN if local asset fails
    try {
      final cdnScript = web.document.createElement('script') as web.HTMLScriptElement
        ..src = 'https://cdnjs.cloudflare.com/ajax/libs/cropperjs/1.6.2/cropper.min.js'
        ..type = 'text/javascript';
      cdnScript.onload = ((web.Event _) {
        if (!completer.isCompleted) completer.complete();
      }).toJS;
      cdnScript.onerror = ((web.Event _) {
        if (!completer.isCompleted) completer.complete();
      }).toJS;
      web.document.head?.append(cdnScript);
    } catch (_) {
      if (!completer.isCompleted) completer.complete();
    }
  }).toJS;

  web.document.head?.append(script);

  await completer.future.timeout(
    const Duration(milliseconds: 3500),
    onTimeout: () {},
  );
}
