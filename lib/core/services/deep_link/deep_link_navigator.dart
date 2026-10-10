import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/navigation/app_navigator.dart';
import 'package:truthworld/core/services/cashfree_service.dart';
import 'package:truthworld/core/services/deep_link/deep_link_cache_manager.dart';
import 'package:truthworld/core/services/deep_link/deep_link_url_parser.dart';
import 'package:truthworld/core/services/deep_link/parsed_truthworld_url.dart';
import 'package:truthworld/core/utils/studio_launcher.dart';
import 'package:truthworld/core/utils/web_platform_utils.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/video/data/models/video_clip.dart';
import 'package:truthworld/features/video/presentation/controllers/video_playback_handoff.dart';
import 'package:url_launcher/url_launcher.dart';

/// Mixin providing AppLinks stream listeners and low-latency in-app navigation.
mixin DeepLinkNavigator on DeepLinkCacheManager {
  AppLinks? _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  bool _isInitialized = false;
  String? _lastHandledUrl;
  DateTime? _lastHandledTime;

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

    // Deduplicate identical deep link events within 1.5 seconds
    final now = DateTime.now();
    if (_lastHandledUrl == clean &&
        _lastHandledTime != null &&
        now.difference(_lastHandledTime!) < const Duration(milliseconds: 1500)) {
      debugPrint('[DeepLinkService] ⏩ Skipping duplicate deep link event: $clean');
      return;
    }
    _lastHandledUrl = clean;
    _lastHandledTime = now;

    // Ensure GetX navigator is mounted and initial routing is complete
    var attempts = 0;
    while ((Get.key.currentState == null || Get.currentRoute.isEmpty) && attempts < 40) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      attempts++;
    }

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
            AppNavigator.offNamed('/studio');
          } else {
            AppNavigator.toStudio();
          }
        }

      case TruthworldUrlType.admin:
        if (replace) {
          AppNavigator.offNamed('/admin');
        } else {
          AppNavigator.toAdmin();
        }

      case TruthworldUrlType.upload:
        if (replace) {
          AppNavigator.offNamed('/upload');
        } else {
          AppNavigator.toUpload();
        }

      case TruthworldUrlType.settings:
        if (Get.isRegistered<HomeController>()) {
          final isAtHome = Get.currentRoute == '/' || Get.currentRoute == '/home';
          if (isAtHome) {
            Get.find<HomeController>().onSideNavItemSelect(HomeController.indexSettings);
            if (kIsWeb) {
              WebPlatformUtils.pushUrlHistory('/settings');
            }
            break;
          }
        }
        if (replace) {
          AppNavigator.offNamed('/settings');
        } else {
          AppNavigator.toSettings();
        }

      case TruthworldUrlType.home:
        AppNavigator.offAllNamed('/');

      case TruthworldUrlType.policy:
        _handlePolicyNavigation(parsed, replace: replace);

      case TruthworldUrlType.paymentResult:
        _handlePaymentResultNavigation(parsed);

      case TruthworldUrlType.checkout:
        break;

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
      AppNavigator.offNamed(routeUrl, arguments: args, preventDuplicates: false);
    } else {
      AppNavigator.toNamed(routeUrl, arguments: args, preventDuplicates: false);
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
      AppNavigator.offNamed(routeUrl, arguments: args, preventDuplicates: false);
    } else {
      AppNavigator.toNamed(routeUrl, arguments: args, preventDuplicates: false);
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
      AppNavigator.offNamed(routeUrl, arguments: args, preventDuplicates: false);
    } else {
      AppNavigator.toNamed(routeUrl, arguments: args, preventDuplicates: false);
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
      AppNavigator.offNamed(routeUrl, arguments: args, preventDuplicates: false);
    } else {
      AppNavigator.toNamed(routeUrl, arguments: args, preventDuplicates: false);
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
      AppNavigator.offNamed(routeUrl);
    } else {
      AppNavigator.toNamed(routeUrl);
    }
  }

  void _handlePolicyNavigation(
    ParsedTruthworldUrl parsed, {
    required bool replace,
  }) {
    final policySlug = parsed.id ?? 'terms';
    final route = '/$policySlug';

    if (Get.isRegistered<HomeController>()) {
      final homeController = Get.find<HomeController>();
      final isAtHome = Get.currentRoute == '/' || Get.currentRoute == '/home';
      if (isAtHome) {
        int? targetIndex;
        switch (policySlug) {
          case 'community-guidelines':
            targetIndex = HomeController.indexCommunityGuidelines;
          case 'terms':
            targetIndex = HomeController.indexTerms;
          case 'privacy':
            targetIndex = HomeController.indexPrivacy;
          case 'about':
            targetIndex = HomeController.indexAbout;
          case 'feedback':
            targetIndex = HomeController.indexFeedback;
        }
        if (targetIndex != null) {
          homeController.onSideNavItemSelect(targetIndex);
          if (kIsWeb) {
            WebPlatformUtils.pushUrlHistory(route);
          }
          return;
        }
      }
    }

    if (replace) {
      AppNavigator.offNamed(route);
    } else {
      AppNavigator.toNamed(route);
    }
  }

  /// Launches the native mobile TruthWorld app from mobile web browsers.
  Future<void> launchNativeAppFromWeb({String? path}) async {
    if (!kIsWeb) return;
    try {
      final currentPath = path ??
          (Uri.base.path + (Uri.base.hasQuery ? '?${Uri.base.query}' : ''));
      final clean = currentPath.replaceFirst(RegExp(r'^\/+'), '');
      final isAndroid = defaultTargetPlatform == TargetPlatform.android;

      final urlStr = isAndroid
          ? 'intent://www.truthworld.in/$clean#Intent;scheme=https;package=com.truthworld.app;end'
          : 'truthworld://$clean';

      final uri = Uri.parse(urlStr);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'DeepLinkService.launchNativeAppFromWeb',
      );
    }
  }

  /// Dispatches Cashfree payment completion deep links directly to CashfreePaymentService.
  void _handlePaymentResultNavigation(ParsedTruthworldUrl parsed) {
    final orderId = parsed.id ??
        parsed.queryParameters['order_id'] ??
        parsed.queryParameters['orderId'] ??
        '';
    final status = parsed.queryParameters['status'] ?? 'PAID';
    final subscriptionId = parsed.queryParameters['subscription_id'] ??
        parsed.queryParameters['subscriptionId'];

    if (Get.isRegistered<CashfreePaymentService>()) {
      unawaited(
        CashfreePaymentService.to.handlePaymentResult(
          orderId: orderId,
          status: status,
          subscriptionId: subscriptionId,
        ),
      );
    }
  }
}
