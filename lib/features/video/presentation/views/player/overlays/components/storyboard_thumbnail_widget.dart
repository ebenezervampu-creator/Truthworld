import 'dart:async';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/features/video/data/services/storyboard_service.dart';
import 'package:truthworld/theme/app_theme.dart';

/// High-performance memory cache for loaded sprite sheet ui.Image instances
/// with strict LRU eviction to prevent GPU/RAM memory leaks during long-form video scrubbing.
class SpriteSheetImageCache {
  static const int _maxCacheSize = 24;
  static final Map<String, ui.Image> _cache = {};
  static final List<String> _lruOrder = [];
  static final Map<String, Completer<ui.Image?>> _inFlight = {};

  static Future<ui.Image?> load(String url) async {
    if (_cache.containsKey(url)) {
      // Move to end (most recently used)
      _lruOrder.remove(url);
      _lruOrder.add(url);
      return _cache[url];
    }
    if (_inFlight.containsKey(url)) return _inFlight[url]!.future;

    final completer = Completer<ui.Image?>();
    _inFlight[url] = completer;

    try {
      final imageProvider = NetworkImage(url);
      final stream = imageProvider.resolve(ImageConfiguration.empty);
      late ImageStreamListener listener;
      listener = ImageStreamListener(
        (info, _) {
          // LRU eviction if cache size exceeds limit
          while (_lruOrder.length >= _maxCacheSize) {
            final oldestUrl = _lruOrder.removeAt(0);
            final evicted = _cache.remove(oldestUrl);
            evicted?.dispose();
          }

          _cache[url] = info.image;
          _lruOrder.add(url);
          completer.complete(info.image);
          _inFlight.remove(url);
          stream.removeListener(listener);
        },
        onError: (e, s) {
          ErrorHandler.log(
            e,
            stackTrace: s,
            tag: 'SpriteSheetImageCache.load',
          );
          completer.complete(null);
          _inFlight.remove(url);
          stream.removeListener(listener);
        },
      );
      stream.addListener(listener);
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'SpriteSheetImageCache.exception');
      completer.complete(null);
      _inFlight.remove(url);
    }

    return completer.future;
  }

  /// Fire-and-forget preloading for a single sprite sheet URL.
  static void preload(String url) {
    if (url.trim().isNotEmpty && !_cache.containsKey(url) && !_inFlight.containsKey(url)) {
      unawaited(load(url));
    }
  }

  /// Lookahead preloading for all sprite sheets within a temporal window around [position].
  static void preloadAround(
    StoryboardTrack track,
    Duration position, {
    Duration window = const Duration(seconds: 30),
  }) {
    final urls = track.getImageUrlsAround(position, window: window);
    urls.forEach(preload);
  }

  /// Clears cache and releases native GPU texture handles.
  static void clear() {
    for (final img in _cache.values) {
      img.dispose();
    }
    _cache.clear();
    _lruOrder.clear();
    _inFlight.clear();
  }
}

/// Pure declarative trick-play thumbnail widget (Zero setState) that renders either:
/// - Cropped WebVTT sprite coordinates
/// - Frame variants
/// - Chapter / Video fallback cover thumbnails
class StoryboardThumbnailWidget extends StatelessWidget {
  const StoryboardThumbnailWidget({
    required this.position,
    required this.fallbackThumbnailUrl,
    this.storyboardTrack,
    this.width = 144,
    this.height = 81,
    this.borderRadius,
    super.key,
  });

  final Duration position;
  final String? fallbackThumbnailUrl;
  final StoryboardTrack? storyboardTrack;
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final r = borderRadius ?? BorderRadius.circular(8);
    final cue = storyboardTrack?.getCueAt(position);

    // 1. Cropped sprite frame
    if (cue != null && cue.cropRect != null) {
      return ClipRRect(
        borderRadius: r,
        child: FutureBuilder<ui.Image?>(
          future: SpriteSheetImageCache.load(cue.imageUrl),
          builder: (context, snapshot) {
            final img = snapshot.data;
            if (img != null) {
              return CustomPaint(
                size: Size(width, height),
                painter: _CroppedSpritePainter(
                  image: img,
                  cropRect: cue.cropRect!,
                ),
              );
            }
            return _buildFallback(r);
          },
        ),
      );
    }

    // 2. Direct variant frame URL
    if (cue != null && cue.cropRect == null && cue.imageUrl.isNotEmpty) {
      return _buildNetworkImage(cue.imageUrl, r);
    }

    // 3. Fallback video/chapter cover thumbnail
    return _buildFallback(r);
  }

  Widget _buildFallback(BorderRadius r) {
    if (fallbackThumbnailUrl != null && fallbackThumbnailUrl!.isNotEmpty) {
      return _buildNetworkImage(fallbackThumbnailUrl!, r);
    }
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: r,
      ),
      child: const Center(
        child: Icon(
          Icons.movie_creation_rounded,
          color: AppColors.textPrimary,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildNetworkImage(String url, BorderRadius r) {
    return ClipRRect(
      borderRadius: r,
      child: CachedNetworkImage(
        imageUrl: url,
        width: width,
        height: height,
        fit: BoxFit.cover,
        memCacheWidth: (width * 2).round(),
        memCacheHeight: (height * 2).round(),
        placeholder: (context, _) => Container(
          width: width,
          height: height,
          color: Colors.black45,
          child: const Center(
            child: Icon(
              Icons.movie_creation_rounded,
              color: AppColors.textPrimary,
              size: 22,
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          width: width,
          height: height,
          color: Colors.black45,
          child: const Center(
            child: Icon(
              Icons.movie_creation_rounded,
              color: AppColors.textPrimary,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

class _CroppedSpritePainter extends CustomPainter {
  const _CroppedSpritePainter({
    required this.image,
    required this.cropRect,
  });

  final ui.Image image;
  final Rect cropRect;

  @override
  void paint(Canvas canvas, Size size) {
    final destRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high;

    canvas.drawImageRect(image, cropRect, destRect, paint);
  }

  @override
  bool shouldRepaint(_CroppedSpritePainter oldDelegate) {
    return oldDelegate.image != image || oldDelegate.cropRect != cropRect;
  }
}
