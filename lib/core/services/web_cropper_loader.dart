import 'package:truthworld/core/services/web_cropper_loader_stub.dart'
    if (dart.library.js_interop) 'package:truthworld/core/services/web_cropper_loader_web.dart';

/// Pre-flight check ensuring Cropper.js runtime is loaded on Web platforms.
Future<bool> ensureWebCropperLoaded() => ensureWebCropperLoadedImpl();
