import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/utils/studio_launcher.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/models/video_clip.dart';
import 'package:truthworld/features/video/presentation/controllers/video_playback_handoff.dart';
import 'package:url_launcher/url_launcher.dart';

/// Supported types of Truthworld deep links / URLs.
enum TruthworldUrlType {
  video,
  channel,
  playlist,
  topic,
  post,
  studio,
  admin,
  settings,
  upload,
  home,
  external,
  unknown,
}

/// Structured representation of a parsed Truthworld URL with all query parameters.
class ParsedTruthworldUrl {
  final TruthworldUrlType type;
  final String? id; // videoId, channelId, playlistId, topicSlug, postId
  final String? handle; // @handle or handle
  final Duration? timestamp; // parsed from t=90s, t=1m30s, start=90, etc.
  final String? playlistId; // from list=...
  final double? clipStart;
  final double? clipEnd;
  final String? clipTitle;
  final String? clipId;
  final String rawUrl;
  final Map<String, String> queryParameters;

  const ParsedTruthworldUrl({
    required this.type,
    required this.rawUrl,
    this.id,
    this.handle,
    this.timestamp,
    this.playlistId,
    this.clipStart,
    this.clipEnd,
    this.clipTitle,
    this.clipId,
    this.queryParameters = const {},
  });

  bool get isTruthworldEntity =>
      type == TruthworldUrlType.video ||
      type == TruthworldUrlType.channel ||
      type == TruthworldUrlType.playlist ||
      type == TruthworldUrlType.topic ||
      type == TruthworldUrlType.post;
}

/// Centralized deep-link service for TruthWorld.
///
/// Single source of truth for:
/// - Instant YouTube-style URL parsing and low-latency internal dispatch
/// - Share URL generation (video, channel, playlist, topic)
/// - Ultra-fast multi-tier in-memory entity cache (0ms navigation)
/// - AppLinks / Universal Links background stream and cold-launch listener
/// - Firestore content loading with timeout + retry fallback
class DeepLinkService {
  DeepLinkService._();
  static final instance = DeepLinkService._();

  // ═══════════════════════════════════════════════════════════════════
  // CONSTANTS
  // ═══════════════════════════════════════════════════════════════════

  static const String baseUrl = 'https://www.truthworld.in';
  static const Duration _loadTimeout = Duration(seconds: 10);
  static const int _maxRetries = 2;
  static const int _maxCacheSize = 100;

  FirebaseFirestore? _firestoreOverride;
  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;
  AppLinks? _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  bool _isInitialized = false;

  // ═══════════════════════════════════════════════════════════════════
  // IN-MEMORY HIGH-SPEED ENTITY CACHE (0ms latency for cached models)
  // ═══════════════════════════════════════════════════════════════════

  final Map<String, Video> _videoCache = {};
  final Map<String, Channel> _channelCache = {};
  final Map<String, PlaylistModel> _playlistCache = {};
  final Map<String, Topic> _topicCache = {};

  void cacheVideo(Video video) {
    if (video.id.isEmpty) return;
    if (_videoCache.length >= _maxCacheSize) {
      _videoCache.remove(_videoCache.keys.first);
    }
    _videoCache[video.id] = video;
  }

  void cacheChannel(Channel channel) {
    if (channel.id.isEmpty) return;
    if (_channelCache.length >= _maxCacheSize) {
      _channelCache.remove(_channelCache.keys.first);
    }
    _channelCache[channel.id] = channel;
    if (channel.handle.isNotEmpty) {
      final clean = channel.handle.replaceAll(RegExp('^@'), '').toLowerCase();
      _channelCache['@$clean'] = channel;
      _channelCache[clean] = channel;
    }
  }

  void cachePlaylist(PlaylistModel playlist) {
    if (playlist.id.isEmpty) return;
    if (_playlistCache.length >= _maxCacheSize) {
      _playlistCache.remove(_playlistCache.keys.first);
    }
    _playlistCache[playlist.id] = playlist;
  }

  void cacheTopic(Topic topic) {
    if (topic.id.isEmpty && topic.slug.isEmpty) return;
    if (_topicCache.length >= _maxCacheSize) {
      _topicCache.remove(_topicCache.keys.first);
    }
    if (topic.id.isNotEmpty) _topicCache[topic.id] = topic;
    if (topic.slug.isNotEmpty) _topicCache[topic.slug] = topic;
  }

  Video? getVideoFromCache(String videoId) => _videoCache[videoId];

  Channel? getChannelFromCache(String idOrHandle) {
    final clean = idOrHandle.replaceAll(RegExp('^@'), '').toLowerCase();
    return _channelCache[idOrHandle] ??
        _channelCache['@$clean'] ??
        _channelCache[clean];
  }

  PlaylistModel? getPlaylistFromCache(String playlistId) =>
      _playlistCache[playlistId];

  Topic? getTopicFromCache(String slugOrId) => _topicCache[slugOrId];

  // ═══════════════════════════════════════════════════════════════════
  // INITIALIZATION & APPLINKS LISTENER
  // ═══════════════════════════════════════════════════════════════════

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
          ErrorHandler.log(err, stackTrace: stackTrace, tag: 'DeepLinkService.linkStream');
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

  // ═══════════════════════════════════════════════════════════════════
  // URL PARSER (YouTube-style format support)
  // ═══════════════════════════════════════════════════════════════════

  /// Cleans trailing punctuation from URLs.
  static String cleanUrlString(String rawUrl) {
    var url = rawUrl.trim();
    while (url.endsWith('.') ||
        url.endsWith(',') ||
        url.endsWith(')') ||
        url.endsWith(']') ||
        url.endsWith('!') ||
        url.endsWith('?')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  /// Parses timestamp expressions (e.g. "90", "90s", "1m30s", "1h2m3s").
  static Duration? parseTimestamp(String? timeStr) {
    if (timeStr == null || timeStr.trim().isEmpty) return null;
    final clean = timeStr.trim().toLowerCase();

    // Pure numeric seconds
    final pureSec = int.tryParse(clean.replaceAll(RegExp('[^0-9]'), ''));
    if (!clean.contains('m') && !clean.contains('h')) {
      if (pureSec != null) return Duration(seconds: pureSec);
    }

    // Format: 1h2m3s or 2m30s or 45s
    var totalSeconds = 0;
    final hourMatch = RegExp(r'(\d+)h').firstMatch(clean);
    final minMatch = RegExp(r'(\d+)m').firstMatch(clean);
    final secMatch = RegExp(r'(\d+)s').firstMatch(clean);

    if (hourMatch != null) {
      totalSeconds += (int.tryParse(hourMatch.group(1)!) ?? 0) * 3600;
    }
    if (minMatch != null) {
      totalSeconds += (int.tryParse(minMatch.group(1)!) ?? 0) * 60;
    }
    if (secMatch != null) {
      totalSeconds += int.tryParse(secMatch.group(1)!) ?? 0;
    }

    if (totalSeconds > 0) return Duration(seconds: totalSeconds);
    if (pureSec != null && pureSec > 0) return Duration(seconds: pureSec);
    return null;
  }

  /// Checks whether a given URL belongs to Truthworld.
  static bool isTruthworldUrl(String rawUrl) {
    final clean = cleanUrlString(rawUrl);
    if (clean.isEmpty) return false;

    if (clean.startsWith('/') ||
        clean.startsWith('@') ||
        clean.startsWith('truthworld://') ||
        clean.startsWith('truthworldstudio://') ||
        clean.startsWith('truthworldads://')) {
      return true;
    }

    final lower = clean.toLowerCase();
    return lower.contains('truthworld.in') ||
        lower.contains('www.truthworld.in') ||
        lower.contains('studio.truthworld.in') ||
        lower.contains('admin.truthworld.in');
  }

  /// Parses any URL string into a structured [ParsedTruthworldUrl].
  static ParsedTruthworldUrl parseUrl(String rawUrl) {
    final clean = cleanUrlString(rawUrl);
    if (clean.isEmpty) {
      return ParsedTruthworldUrl(
        type: TruthworldUrlType.unknown,
        rawUrl: rawUrl,
      );
    }

    // Convert custom schemes and relative paths to standard URI for parsing
    var uriStr = clean;
    if (uriStr.startsWith('truthworld://') ||
        uriStr.startsWith('truthworldstudio://') ||
        uriStr.startsWith('truthworldads://')) {
      uriStr = uriStr.replaceFirst(RegExp(r'truthworld[a-z]*:\/\/'), 'https://www.truthworld.in/');
    } else if (uriStr.startsWith('//')) {
      uriStr = 'https:$uriStr';
    } else if (uriStr.startsWith('/')) {
      uriStr = 'https://www.truthworld.in$uriStr';
    } else if (uriStr.startsWith('@')) {
      uriStr = 'https://www.truthworld.in/$uriStr';
    } else if (!uriStr.startsWith('http://') && !uriStr.startsWith('https://')) {
      final isTw = uriStr.toLowerCase().contains('truthworld.in');
      if (isTw) {
        uriStr = 'https://$uriStr';
      }
    }

    final uri = Uri.tryParse(uriStr);
    if (uri == null) {
      return ParsedTruthworldUrl(
        type: TruthworldUrlType.unknown,
        rawUrl: rawUrl,
      );
    }

    final host = uri.host.toLowerCase();
    final isTWDomain = host.contains('truthworld.in') ||
        host.isEmpty ||
        host == 'localhost';

    if (!isTWDomain) {
      return ParsedTruthworldUrl(
        type: TruthworldUrlType.external,
        rawUrl: rawUrl,
      );
    }

    final pathSegments = uri.pathSegments;
    final queryParams = uri.queryParameters;
    final firstSegment = pathSegments.isNotEmpty ? pathSegments.first.toLowerCase() : '';

    // Studio & Admin Subdomains
    if (host.startsWith('studio') || firstSegment == 'studio') {
      return ParsedTruthworldUrl(
        type: TruthworldUrlType.studio,
        rawUrl: rawUrl,
        queryParameters: queryParams,
      );
    }
    if (host.startsWith('admin') || firstSegment == 'admin') {
      return ParsedTruthworldUrl(
        type: TruthworldUrlType.admin,
        rawUrl: rawUrl,
        queryParameters: queryParams,
      );
    }

    // Timestamp parsing
    final timeParam = queryParams['t'] ?? queryParams['time'] ?? queryParams['start'];
    final timestamp = parseTimestamp(timeParam);

    // Clip parsing
    final clipStart = double.tryParse(queryParams['start'] ?? queryParams['clipStart'] ?? '');
    final clipEnd = double.tryParse(queryParams['end'] ?? queryParams['clipEnd'] ?? '');
    final clipTitleParam = queryParams['clipTitle'] ?? queryParams['title'];
    final clipTitle = clipTitleParam != null ? Uri.decodeComponent(clipTitleParam) : null;
    final clipId = queryParams['clipId'];

    // Playlist ID
    final playlistIdParam = queryParams['list'] ?? queryParams['playlistId'];

    // 1. VIDEO PATTERNS:
    // /watch?v=VIDEO_ID or /watch/VIDEO_ID or /v/VIDEO_ID or /shorts/VIDEO_ID
    if (firstSegment == 'watch' || firstSegment == 'v' || firstSegment == 'shorts') {
      String? videoId;
      final vParam = queryParams['v'];
      if (vParam != null && vParam.isNotEmpty) {
        videoId = vParam;
      } else if (pathSegments.length >= 2 && pathSegments[1].isNotEmpty) {
        videoId = pathSegments[1];
      }

      if (videoId != null && videoId.isNotEmpty) {
        return ParsedTruthworldUrl(
          type: TruthworldUrlType.video,
          id: videoId,
          timestamp: timestamp,
          playlistId: playlistIdParam,
          clipStart: clipStart,
          clipEnd: clipEnd,
          clipTitle: clipTitle,
          clipId: clipId,
          rawUrl: rawUrl,
          queryParameters: queryParams,
        );
      }
    }

    // 2. CHANNEL PATTERNS:
    // /channel/CHANNEL_ID or /@HANDLE or /c/CUSTOM_URL or /user/USERNAME or /:HANDLE
    if (firstSegment == 'channel' || firstSegment == 'c' || firstSegment == 'user') {
      if (pathSegments.length >= 2 && pathSegments[1].isNotEmpty) {
        final channelTarget = pathSegments[1];
        final cleanHandle = channelTarget.startsWith('@')
            ? channelTarget.substring(1)
            : null;
        return ParsedTruthworldUrl(
          type: TruthworldUrlType.channel,
          id: cleanHandle == null ? channelTarget : null,
          handle: cleanHandle,
          rawUrl: rawUrl,
          queryParameters: queryParams,
        );
      }
    }

    if (firstSegment.startsWith('@')) {
      final cleanHandle = firstSegment.substring(1);
      return ParsedTruthworldUrl(
        type: TruthworldUrlType.channel,
        handle: cleanHandle,
        rawUrl: rawUrl,
        queryParameters: queryParams,
      );
    }

    // 3. PLAYLIST PATTERNS:
    // /playlist/PLAYLIST_ID or /playlist?list=PLAYLIST_ID
    if (firstSegment == 'playlist') {
      var playlistId = queryParams['list'] ?? queryParams['playlistId'];
      if ((playlistId == null || playlistId.isEmpty) &&
          pathSegments.length >= 2) {
        playlistId = pathSegments[1];
      }
      if (playlistId != null && playlistId.isNotEmpty) {
        return ParsedTruthworldUrl(
          type: TruthworldUrlType.playlist,
          id: playlistId,
          playlistId: playlistId,
          rawUrl: rawUrl,
          queryParameters: queryParams,
        );
      }
    }

    // 4. TOPIC PATTERNS:
    // /T/SLUG or /topic/SLUG or /t/SLUG or /topics/SLUG
    if (firstSegment == 't' || firstSegment == 'topic' || firstSegment == 'topics') {
      if (pathSegments.length >= 2 && pathSegments[1].isNotEmpty) {
        return ParsedTruthworldUrl(
          type: TruthworldUrlType.topic,
          id: pathSegments[1],
          rawUrl: rawUrl,
          queryParameters: queryParams,
        );
      }
    }

    // 5. POST / COMMUNITY PATTERNS:
    // /community/POST_ID or /post/POST_ID
    if (firstSegment == 'community' || firstSegment == 'post') {
      if (pathSegments.length >= 2 && pathSegments[1].isNotEmpty) {
        return ParsedTruthworldUrl(
          type: TruthworldUrlType.post,
          id: pathSegments[1],
          rawUrl: rawUrl,
          queryParameters: queryParams,
        );
      }
    }

    // 6. UPLOAD / CREATION PATTERNS:
    if (firstSegment == 'upload' ||
        firstSegment == 'create-post' ||
        firstSegment == 'create-playlist' ||
        firstSegment == 'create-topic') {
      return ParsedTruthworldUrl(
        type: TruthworldUrlType.upload,
        rawUrl: rawUrl,
        queryParameters: queryParams,
      );
    }

    // 7. SETTINGS / ABOUT / ETC.
    if (firstSegment == 'settings') {
      return ParsedTruthworldUrl(
        type: TruthworldUrlType.settings,
        rawUrl: rawUrl,
        queryParameters: queryParams,
      );
    }

    if (firstSegment.isEmpty) {
      return ParsedTruthworldUrl(
        type: TruthworldUrlType.home,
        rawUrl: rawUrl,
        queryParameters: queryParams,
      );
    }

    // Vanity Handle Fallback: /ebenezervampu
    if (pathSegments.length == 1 &&
        !['home', 'explore', 'trending', 'library', 'history', 'likedvideos', 'watchlater', 'subscriptions', 'about', 'privacy', 'terms'].contains(firstSegment)) {
      return ParsedTruthworldUrl(
        type: TruthworldUrlType.channel,
        handle: '@$firstSegment',
        rawUrl: rawUrl,
        queryParameters: queryParams,
      );
    }

    return ParsedTruthworldUrl(
      type: TruthworldUrlType.unknown,
      rawUrl: rawUrl,
      queryParameters: queryParams,
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // LOW-LATENCY ROUTER & DISPATCHER (YouTube-style instant in-app jump)
  // ═══════════════════════════════════════════════════════════════════

  /// Handles any URL with instant low-latency in-app navigation when possible,
  /// or opens external browser for non-Truthworld links.
  Future<void> handleUrl(String rawUrl, {bool replace = false}) async {
    final clean = cleanUrlString(rawUrl);
    if (clean.isEmpty) return;

    final parsed = parseUrl(clean);

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
            ErrorHandler.log(e, stackTrace: s, tag: 'DeepLinkService.launchExternalUrl');
          }
        }
    }
  }

  void _handleVideoNavigation(ParsedTruthworldUrl parsed, {required bool replace}) {
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
        title: parsed.clipTitle ?? (cachedVideo?.title != null ? '${cachedVideo!.title} Clip' : 'Clip'),
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
    debugPrint('[DeepLinkService] 🧭 Low-latency navigating to video: $routeUrl (cached: ${cachedVideo != null})');

    if (replace) {
      Get.offNamed<void>(routeUrl, arguments: args, preventDuplicates: false);
    } else {
      Get.toNamed<void>(routeUrl, arguments: args, preventDuplicates: false);
    }
  }

  void _handleChannelNavigation(ParsedTruthworldUrl parsed, {required bool replace}) {
    final target = parsed.handle ?? parsed.id;
    if (target == null || target.isEmpty) return;

    final cachedChannel = getChannelFromCache(target);
    final args = <String, dynamic>{};
    if (cachedChannel != null) {
      args['channel'] = cachedChannel;
    }

    final routeUrl = target.startsWith('@') ? '/$target' : '/channel/$target';
    debugPrint('[DeepLinkService] 🧭 Low-latency navigating to channel: $routeUrl (cached: ${cachedChannel != null})');

    if (replace) {
      Get.offNamed<void>(routeUrl, arguments: args, preventDuplicates: false);
    } else {
      Get.toNamed<void>(routeUrl, arguments: args, preventDuplicates: false);
    }
  }

  void _handlePlaylistNavigation(ParsedTruthworldUrl parsed, {required bool replace}) {
    final playlistId = parsed.id;
    if (playlistId == null || playlistId.isEmpty) return;

    final cachedPlaylist = getPlaylistFromCache(playlistId);
    final args = <String, dynamic>{};
    if (cachedPlaylist != null) {
      args['playlist'] = cachedPlaylist;
    }

    final routeUrl = '/playlist/$playlistId';
    debugPrint('[DeepLinkService] 🧭 Low-latency navigating to playlist: $routeUrl (cached: ${cachedPlaylist != null})');

    if (replace) {
      Get.offNamed<void>(routeUrl, arguments: args, preventDuplicates: false);
    } else {
      Get.toNamed<void>(routeUrl, arguments: args, preventDuplicates: false);
    }
  }

  void _handleTopicNavigation(ParsedTruthworldUrl parsed, {required bool replace}) {
    final slug = parsed.id;
    if (slug == null || slug.isEmpty) return;

    final cachedTopic = getTopicFromCache(slug);
    final args = <String, dynamic>{'slug': slug};
    if (cachedTopic != null) {
      args['topic'] = cachedTopic;
    }

    final routeUrl = '/T/$slug';
    debugPrint('[DeepLinkService] 🧭 Low-latency navigating to topic: $routeUrl (cached: ${cachedTopic != null})');

    if (replace) {
      Get.offNamed<void>(routeUrl, arguments: args, preventDuplicates: false);
    } else {
      Get.toNamed<void>(routeUrl, arguments: args, preventDuplicates: false);
    }
  }

  void _handlePostNavigation(ParsedTruthworldUrl parsed, {required bool replace}) {
    final postId = parsed.id;
    if (postId == null || postId.isEmpty) return;

    final routeUrl = '/post/$postId';
    if (replace) {
      Get.offNamed<void>(routeUrl);
    } else {
      Get.toNamed<void>(routeUrl);
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // URL BUILDERS (single source of truth)
  // ═══════════════════════════════════════════════════════════════════

  /// Generates a shareable video URL.
  /// Pattern: https://www.truthworld.in/watch/{videoId}
  static String videoUrl(String videoId) => '$baseUrl/watch/$videoId';

  /// Generates a shareable channel URL.
  /// Pattern: https://www.truthworld.in/channel/{channelId}
  static String channelUrl(String channelId) => '$baseUrl/channel/$channelId';

  /// Generates a shareable playlist URL.
  /// Pattern: https://www.truthworld.in/playlist/{playlistId}
  static String playlistUrl(String playlistId) =>
      '$baseUrl/playlist/$playlistId';

  /// Generates a shareable topic URL.
  /// Pattern: https://www.truthworld.in/T/{id_or_slug_or_handle}
  static String topicUrl(String slugOrHandle) {
    var clean = slugOrHandle.trim();
    if (clean.startsWith('T/')) {
      clean = clean.substring(2);
    } else if (clean.startsWith('t/')) {
      clean = clean.substring(2);
    }
    return '$baseUrl/T/$clean';
  }

  // ═══════════════════════════════════════════════════════════════════
  // SHARE FUNCTIONS
  // ═══════════════════════════════════════════════════════════════════

  /// Share a video with title and URL.
  Future<void> shareVideo(
    String videoId,
    String videoTitle, {
    String? channelName,
  }) async {
    try {
      final url = videoUrl(videoId);
      final byChannel = (channelName != null &&
              channelName.isNotEmpty &&
              channelName != 'Channel' &&
              !videoTitle.toLowerCase().contains(channelName.toLowerCase()))
          ? ' by $channelName'
          : '';
      await SharePlus.instance.share(
        ShareParams(
          text: 'Watch "$videoTitle"$byChannel on TruthWorld:\n$url',
          subject: videoTitle,
        ),
      );
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'DeepLinkService.shareVideo');
    }
  }

  /// Share a channel with name, handle, and URL.
  Future<void> shareChannel(
    String channelId, {
    String? channelName,
    String? handle,
  }) async {
    try {
      final url = channelUrl(channelId);
      final cleanHandle = (handle ?? '').replaceAll(RegExp('^@'), '').trim();
      final handleStr = cleanHandle.isNotEmpty ? ' (@$cleanHandle)' : '';
      final text = channelName != null
          ? 'Check out $channelName$handleStr on TruthWorld:\n$url'
          : 'Check out this channel on TruthWorld:\n$url';
      await SharePlus.instance.share(
        ShareParams(
          text: text,
          subject: channelName ?? 'TruthWorld Channel',
        ),
      );
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'DeepLinkService.shareChannel');
    }
  }

  /// Share a playlist with name and URL.
  Future<void> sharePlaylist(String playlistId, String playlistName) async {
    try {
      final url = playlistUrl(playlistId);
      await SharePlus.instance.share(
        ShareParams(
          text: 'Check out "$playlistName" playlist on TruthWorld:\n$url',
          subject: playlistName,
        ),
      );
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'DeepLinkService.sharePlaylist');
    }
  }

  /// Share a topic with name and URL.
  Future<void> shareTopic(String slugOrHandle, String topicTitle) async {
    try {
      final url = topicUrl(slugOrHandle);
      final cleanTitle = topicTitle.replaceAll(RegExp('^[#Tt]/'), '').trim();
      await SharePlus.instance.share(
        ShareParams(
          text: 'Explore #$cleanTitle on TruthWorld:\n$url',
          subject: '#$cleanTitle',
        ),
      );
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'DeepLinkService.shareTopic');
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // CONTENT LOADERS (with cache + timeout + retry)
  // ═══════════════════════════════════════════════════════════════════

  /// Load a video by ID. Checks in-memory cache first, then Firestore.
  /// Returns null if not found or on error.
  Future<Video?> loadVideo(String videoId) async {
    final cached = getVideoFromCache(videoId);
    if (cached != null) return cached;

    return _withRetry<Video?>(() async {
      final doc = await _firestore
          .collection(FirestoreCollections.videos)
          .doc(videoId)
          .get()
          .timeout(_loadTimeout);

      if (!doc.exists) return null;
      final video = Video.fromDocumentSnapshot(doc);
      cacheVideo(video);
      return video;
    });
  }

  /// Load a channel by ID or handle. Checks in-memory cache first, then Firestore.
  Future<Channel?> loadChannel(String channelIdOrHandle) async {
    final cached = getChannelFromCache(channelIdOrHandle);
    if (cached != null) return cached;

    return _withRetry<Channel?>(() async {
      var clean = channelIdOrHandle.trim();
      if (clean.startsWith('@')) {
        clean = clean.substring(1);
      }

      // Direct lookup by document ID (fastest, 1 read)
      final doc = await _firestore
          .collection(FirestoreCollections.channels)
          .doc(channelIdOrHandle)
          .get()
          .timeout(_loadTimeout);

      if (doc.exists) {
        final channel = Channel.fromDocumentSnapshot(doc);
        cacheChannel(channel);
        return channel;
      }

      // Fallback 1: search by handleLowercase
      final queryByHandle = await _firestore
          .collection(FirestoreCollections.channels)
          .where('handleLowercase', isEqualTo: clean.toLowerCase())
          .limit(1)
          .get()
          .timeout(_loadTimeout);

      if (queryByHandle.docs.isNotEmpty) {
        final channel = Channel.fromDocumentSnapshot(queryByHandle.docs.first);
        cacheChannel(channel);
        return channel;
      }

      // Fallback 2: search by customUrl
      final querySnap = await _firestore
          .collection(FirestoreCollections.channels)
          .where('customUrlLowercase', isEqualTo: clean.toLowerCase())
          .limit(1)
          .get()
          .timeout(_loadTimeout);

      if (querySnap.docs.isNotEmpty) {
        final channel = Channel.fromDocumentSnapshot(querySnap.docs.first);
        cacheChannel(channel);
        return channel;
      }

      return null;
    });
  }

  /// Load a playlist by ID. Checks in-memory cache first, then Firestore.
  Future<PlaylistModel?> loadPlaylist(String playlistId) async {
    final cached = getPlaylistFromCache(playlistId);
    if (cached != null) return cached;

    return _withRetry<PlaylistModel?>(() async {
      final userId = FirebaseAuth.instance.currentUser?.uid;

      final futures = <Future<DocumentSnapshot>>[
        _firestore
            .collection('public_playlists')
            .doc(playlistId)
            .get()
            .timeout(_loadTimeout),
      ];

      if (userId != null) {
        futures.add(
          _firestore
              .collection(FirestoreCollections.users)
              .doc(userId)
              .collection(FirestoreCollections.playlists)
              .doc(playlistId)
              .get()
              .timeout(_loadTimeout),
        );
      }

      final docs = await Future.wait(futures);

      for (final doc in docs) {
        if (doc.exists) {
          final playlist = PlaylistModel.fromDocumentSnapshot(doc);
          cachePlaylist(playlist);
          return playlist;
        }
      }

      return null;
    });
  }

  // ═══════════════════════════════════════════════════════════════════
  // RETRY HELPER
  // ═══════════════════════════════════════════════════════════════════

  /// Executes [action] with retry logic and timeout.
  /// Returns null on all failures after retries.
  Future<T?> _withRetry<T>(Future<T?> Function() action) async {
    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        return await action();
      } on TimeoutException {
        debugPrint('DeepLink: Timeout (attempt ${attempt + 1}/$_maxRetries)');
        if (attempt == _maxRetries) return null;
        await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      } on FirebaseException catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'DeepLinkService._withRetry.firebase');
        if (attempt == _maxRetries) return null;
        await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'DeepLinkService._withRetry.unexpected');
        return null;
      }
    }
    return null;
  }
}

