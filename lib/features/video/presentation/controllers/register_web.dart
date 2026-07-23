import 'dart:ui_web' as ui_web;

import 'package:web/web.dart' as web;

void registerVideoElement(String videoId, String videoUrl) {
  // ignore: undefined_prefixed_name
  ui_web.platformViewRegistry.registerViewFactory('video-$videoId', (
    int viewId,
  ) {
    final video = web.HTMLVideoElement()
      ..src = videoUrl
      ..controls = true
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'contain';
    return video;
  });
}
