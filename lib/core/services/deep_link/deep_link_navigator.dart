import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/deep_link/deep_link_cache_manager.dart';
import 'package:truthworld/core/services/deep_link/deep_link_url_parser.dart';
import 'package:truthworld/core/services/deep_link/parsed_truthworld_url.dart';
import 'package:truthworld/core/utils/studio_launcher.dart';
import 'package:truthworld/features/video/data/models/video_clip.dart';
import 'package:truthworld/features/video/presentation/controllers/video_playback_handoff.dart';
import 'package:url_launcher/url_launcher.dart';

/// Mixin providing AppLinks stream listeners and low-latency in-app navigation.
mixin DeepLinkNavigator on DeepLinkCacheManager {
  AppLinks? _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  bool _isInitialized = false;

  /// Initialize deep link listeners for Android App Links and iOS Universal Links.
  Future<void> initAppLinks() async {
    if (_isInitialized) return;
    _isInitialized = true;

    // Deep linking on web is handled natively by the browser URL and Flutter routing.
    if (kIsWeb) return;

    try {
      _appLinks = AppLinks();

      // 1. Listen to incoming deep links while app is running in foreground/background
      _linkSubscription = _appLinks?.uriLinkStream.listen(
        (uri) {
          debugPrint('[DeepLinkService] 🔗 Incoming stream URI: $uri');
          handleUrl(uri.toString());
        },
        onError: (err, stackTrace) {
          ErrorHandler.log(
            err,
            stackTrace: stackTrace,
            tag: 'DeepLinkService.linkStream',
          );
        },
      );

      // 2. Check for initial link when app is cold-launched from a URL
      final initialUri = await _appLinks?.getInitialLink();
      if (initialUri != null) {
        debugPrint('[DeepLinkService] 🚀 Cold launch URI: $initialUri');
        // Wait for first frame before routing
        WidgetsBinding.instance.addPostFrameCallback((_) {
          handleUrl(initialUri.toString());
        });
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'DeepLinkService.initAppLinks');
    }
  }

  void dispose() {
    _linkSubscription?.cancel();
    _linkSubscription = null;
  }

  /// Handles any URL with instant low-latency in-app navigation when possible,
  /// or opens external browser for non-Truthworld links.
  Future<void> handleUrl(String rawUrl, {bool replace = false}) async {
    final clean = DeepLinkUrlParser.cleanUrlString(rawUrl);
    if (clean.isEmpty) return;

    final parsed = DeepLinkUrlParser.parseUrl(clean);

    switch (parsed.type) {
      case TruthworldUrlType.video:
        _handleVideoNavigation(parsed, replace: replace);

      case TruthworldUrlType.channel:
        _handleChannelNavigation(parsed, replace: replace);

      case TruthworldUrlType.playlist:
        _handlePlaylistNavigation(parsed, replace: replace);

      case TruthworldUrlType.topic:
        _handleTopicNavigation(parsed, replace: replace);

      case TruthworldUrlType.post:
        _handlePostNavigation(parsed, replace: replace);

      case TruthworldUrlType.studio:
        if (!kIsWeb) {
          StudioLauncher.openStudio();
        } else {
          if (replace) {
            Get.offNamed<void>('/studio');
          } else {
            Get.toNamed<void>('/studio');
          }
        }

      case TruthworldUrlType.admin:
        if (replace) {
          Get.offNamed<void>('/admin');
        } else {
          Get.toNamed<void>('/admin');
        }

      case TruthworldUrlType.upload:
        if (replace) {
          Get.offNamed<void>('/upload');
        } else {
          Get.toNamed<void>('/upload');
        }

      case TruthworldUrlType.settings:
        if (replace) {
          Get.offNamed<void>('/settings');
        } else {
          Get.toNamed<void>('/settings');
        }

      case TruthworldUrlType.home:
        Get.offAllNamed<void>('/');

      case TruthworldUrlType.external:
      case TruthworldUrlType.unknown:
        final uri = Uri.tryParse(clean);
        // L-41: Block dangerous schemes (e.g. javascript:, file:, data:)
        if (uri != null && (uri.isScheme('https') || uri.isScheme('http'))) {
          try {
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            } else {
              await launchUrl(uri);
            }
          } catch (e, s) {
            ErrorHandler.log(
              e,
              stackTrace: s,
              tag: 'DeepLinkService.launchExternalUrl',
            );
          }
        }
    }
  }

  void _handleVideoNavigation(
    ParsedTruthworldUrl parsed, {
    required bool replace,
  }) {
    final videoId = parsed.id;
    if (videoId == null || videoId.isEmpty) return;

    final cachedVideo = getVideoFromCache(videoId);
    final args = <String, dynamic>{};

    if (cachedVideo != null) {
      args['video'] = cachedVideo;
      // Pre-warm CDN stream immediately for 0ms startup
      VideoPlaybackHandoff.prewarmVideo(cachedVideo);
    }

    if (parsed.timestamp != null) {
      args['initialPosition'] = parsed.timestamp;
    }

    if (parsed.clipStart != null &&
        parsed.clipEnd != null &&
        parsed.clipEnd! > parsed.clipStart!) {
      args['clip'] = VideoClip(
        id: parsed.clipId ?? 'temp_${DateTime.now().millisecondsSinceEpoch}',
        videoId: videoId,
        userId: '',
        title: parsed.clipTitle ??
            (cachedVideo?.title != null
                ? '${cachedVideo!.title} Clip'
                : 'Clip'),
        startTime: parsed.clipStart!,
        endTime: parsed.clipEnd!,
        thumbnailUrl: cachedVideo?.thumbnailUrl ?? '',
        videoTitle: cachedVideo?.title ?? '',
        channelName: cachedVideo?.channelName ?? '',
        createdAt: DateTime.now(),
      );
    }

    final queryParams = <String>[];
    queryParams.add('v=$videoId');
    if (parsed.timestamp != null) {
      queryParams.add('t=${parsed.timestamp!.inSeconds}');
    }
    if (parsed.playlistId != null) {
      queryParams.add('list=${parsed.playlistId}');
    }
    if (parsed.clipStart != null && parsed.clipEnd != null) {
      queryParams.add('start=${parsed.clipStart!.toInt()}');
      queryParams.add('end=${parsed.clipEnd!.toInt()}');
      if (parsed.clipTitle != null) {
        queryParams.add('clipTitle=${Uri.encodeComponent(parsed.clipTitle!)}');
      }
    }

    final routeUrl = '/watch?${queryParams.join('&')}';
    debugPrint(
      '[DeepLinkService] 🧭 Low-latency navigating to video: $routeUrl (cached: ${cachedVideo != null})',
    );

    if (replace) {
      Get.offNamed<void>(routeUrl, arguments: args, preventDuplicates: false);
    } else {
      Get.toNamed<void>(routeUrl, arguments: args, preventDuplicates: false);
    }
  }

  void _handleChannelNavigation(
    ParsedTruthworldUrl parsed, {
    required bool replace,
  }) {
    final target = parsed.handle ?? parsed.id;
    if (target == null || target.isEmpty) return;

    final cachedChannel = getChannelFromCache(target);
    final args = <String, dynamic>{};
    if (cachedChannel != null) {
      args['channel'] = cachedChannel;
    }

    final routeUrl = target.startsWith('@') ? '/$target' : '/channel/$target';
    debugPrint(
      '[DeepLinkService] 🧭 Low-latency navigating to channel: $routeUrl (cached: ${cachedChannel != null})',
    );

    if (replace) {
      Get.offNamed<void>(routeUrl, arguments: args, preventDuplicates: false);
    } else {
      Get.toNamed<void>(routeUrl, arguments: args, preventDuplicates: false);
    }
  }

  void _handlePlaylistNavigation(
    ParsedTruthworldUrl parsed, {
    required bool replace,
  }) {
    final playlistId = parsed.id;
    if (playlistId == null || playlistId.isEmpty) return;

    final cachedPlaylist = getPlaylistFromCache(playlistId);
    final args = <String, dynamic>{};
    if (cachedPlaylist != null) {
      args['playlist'] = cachedPlaylist;
    }

    final routeUrl = '/playlist/$playlistId';
    debugPrint(
      '[DeepLinkService] 🧭 Low-latency navigating to playlist: $routeUrl (cached: ${cachedPlaylist != null})',
    );

    if (replace) {
      Get.offNamed<void>(routeUrl, arguments: args, preventDuplicates: false);
    } else {
      Get.toNamed<void>(routeUrl, arguments: args, preventDuplicates: false);
    }
  }

  void _handleTopicNavigation(
    ParsedTruthworldUrl parsed, {
    required bool replace,
  }) {
    final slug = parsed.id;
    if (slug == null || slug.isEmpty) return;

    final cachedTopic = getTopicFromCache(slug);
    final args = <String, dynamic>{'slug': slug};
    if (cachedTopic != null) {
      args['topic'] = cachedTopic;
    }

    final routeUrl = '/T/$slug';
    debugPrint(
      '[DeepLinkService] 🧭 Low-latency navigating to topic: $routeUrl (cached: ${cachedTopic != null})',
    );

    if (replace) {
      Get.offNamed<void>(routeUrl, arguments: args, preventDuplicates: false);
    } else {
      Get.toNamed<void>(routeUrl, arguments: args, preventDuplicates: false);
    }
  }

  void _handlePostNavigation(
    ParsedTruthworldUrl parsed, {
    required bool replace,
  }) {
    final postId = parsed.id;
    if (postId == null || postId.isEmpty) return;

    final routeUrl = '/post/$postId';
    if (replace) {
      Get.offNamed<void>(routeUrl);
    } else {
      Get.toNamed<void>(routeUrl);
    }
  }
}
