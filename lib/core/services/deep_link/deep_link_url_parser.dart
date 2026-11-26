import 'package:truthworld/core/services/deep_link/parsed_truthworld_url.dart';

/// URL parsing engine supporting standard web URLs and TruthWorld routes.
class DeepLinkUrlParser {
  const DeepLinkUrlParser._();

  /// Reserved routes that must NEVER be hijacked as vanity creator handles
  static const Set<String> reservedRoutes = {
    'home',
    'explore',
    'explore-topics',
    'following-topics',
    'trending',
    'library',
    'history',
    'likedvideos',
    'watchlater',
    'subscriptions',
    'discover',
    'about',
    'privacy',
    'terms',
    'community-guidelines',
    'copyright-complaint',
    'dmca',
    'feedback',
    'settings',
    'studio',
    'dubbing',
    'dubbing-studio',
    'admin',
    'advertiser',
    'advertisements',
    'ads',
    'search',
    'notifications',
    'downloads',
    'playlists',
    'playlistscreen',
    'clips',
    'claim',
    'claims',
    'claim-detail',
    'claimdetailscreen',
    'video-analysis',
    'analysis',
    'premium',
    'checkout',
    'payment-result',
    'payment_result',
    'upload',
    'uploadscreen',
    'create-post',
    'create-playlist',
    'create-topic',
    'myvideos',
    'saved-community-posts',
    'saved-comments',
    'wallet',
    'user-wallet',
    'analytics',
    'browse',
    'login',
    'signup',
    'watch',
    'watchtime',
    'watch-time',
    'videoscreen',
    'video',
    'v',
    'shorts',
    'clip',
  };

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
        clean.startsWith('intent://') ||
        clean.startsWith('truthworld:') ||
        clean.startsWith('truthworldstudio:') ||
        clean.startsWith('truthworlddubbing:') ||
        clean.startsWith('truthworldads:')) {
      return true;
    }

    final uri = Uri.tryParse(clean.startsWith('http://') || clean.startsWith('https://') ? clean : 'https://$clean');
    if (uri != null && uri.host.isNotEmpty) {
      final host = uri.host.toLowerCase();
      return host == 'truthworld.in' ||
          host.endsWith('.truthworld.in') ||
          host == 'localhost';
    }
    return false;
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

    // Convert custom schemes, Android intent URLs, and relative paths to standard URI for parsing
    var uriStr = clean;
    if (uriStr.startsWith('intent://')) {
      // Extract target host/path from intent://host/path#Intent;...
      final match = RegExp(r'^intent:\/\/([^#]+)').firstMatch(uriStr);
      if (match != null) {
        uriStr = 'https://${match.group(1)}';
      }
    } else if (RegExp(r'^truthworldstudio:\/{1,3}').hasMatch(uriStr)) {
      uriStr = uriStr.replaceFirst(
        RegExp(r'^truthworldstudio:\/{1,3}'),
        'https://studio.truthworld.in/',
      );
    } else if (RegExp(r'^truthworlddubbing:\/{1,3}').hasMatch(uriStr)) {
      uriStr = uriStr.replaceFirst(
        RegExp(r'^truthworlddubbing:\/{1,3}'),
        'https://dubbing.truthworld.in/',
      );
    } else if (RegExp(r'^truthworldadmin:\/{1,3}').hasMatch(uriStr)) {
      uriStr = uriStr.replaceFirst(
        RegExp(r'^truthworldadmin:\/{1,3}'),
        'https://admin.truthworld.in/',
      );
    } else if (RegExp(r'^truthworld(ads|advertiser):\/{1,3}').hasMatch(uriStr)) {
      uriStr = uriStr.replaceFirst(
        RegExp(r'^truthworld(ads|advertiser):\/{1,3}'),
        'https://www.truthworld.in/advertisements/',
      );
    } else if (RegExp(r'^truthworld[a-z]*:\/{1,3}').hasMatch(uriStr)) {
      uriStr = uriStr.replaceFirst(
        RegExp(r'^truthworld[a-z]*:\/{1,3}'),
        'https://www.truthworld.in/',
      );
    } else if (uriStr.startsWith('//')) {
      uriStr = 'https:$uriStr';
    } else if (uriStr.startsWith('/')) {
      uriStr = 'https://www.truthworld.in$uriStr';
    } else if (uriStr.startsWith('@')) {
      uriStr = 'https://www.truthworld.in/$uriStr';
    } else if (!uriStr.startsWith('http://') && !uriStr.startsWith('https://')) {
      final candidateHost = uriStr.split('/').first.split('?').first.toLowerCase();
      final isTw = candidateHost == 'truthworld.in' ||
          candidateHost.endsWith('.truthworld.in');
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
    final isTWDomain = host == 'truthworld.in' ||
        host.endsWith('.truthworld.in') ||
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
    final firstSegment =
        pathSegments.isNotEmpty ? pathSegments.first.toLowerCase() : '';

    // Studio, Dubbing Studio & Admin Subdomains
    if (host.startsWith('studio') || firstSegment == 'studio') {
      return ParsedTruthworldUrl(
        type: TruthworldUrlType.studio,
        rawUrl: rawUrl,
        queryParameters: queryParams,
      );
    }
    if (host.startsWith('dubbing') ||
        firstSegment == 'dubbing' ||
        firstSegment == 'dubbing-studio') {
      return ParsedTruthworldUrl(
        type: TruthworldUrlType.dubbing,
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
    final timeParam =
        queryParams['t'] ?? queryParams['time'] ?? queryParams['start'];
    final timestamp = parseTimestamp(timeParam);

    // Clip parsing
    final clipStart = double.tryParse(
      queryParams['start'] ?? queryParams['clipStart'] ?? '',
    );
    final clipEnd = double.tryParse(
      queryParams['end'] ?? queryParams['clipEnd'] ?? '',
    );
    final clipTitleParam = queryParams['clipTitle'] ?? queryParams['title'];
    final clipTitle =
        clipTitleParam != null ? Uri.decodeComponent(clipTitleParam) : null;
    final clipId = queryParams['clipId'];

    // Playlist ID
    final playlistIdParam = queryParams['list'] ?? queryParams['playlistId'];

    // Claim Index / Number parsing
    int? claimIndex;
    final claimIndexParam = queryParams['claimIndex'] ?? queryParams['index'];
    if (claimIndexParam != null && int.tryParse(claimIndexParam) != null) {
      claimIndex = int.parse(claimIndexParam);
    } else if (queryParams['claim'] != null && int.tryParse(queryParams['claim']!) != null) {
      final cNum = int.parse(queryParams['claim']!);
      claimIndex = (cNum > 0) ? cNum - 1 : 0;
    }

    // 0. CLAIM PATTERNS:
    // /claim-detail?videoId=...&claimIndex=... or /claim?videoId=...&claimIndex=...
    // /claim-detail/VIDEO_ID/CLAIM_INDEX or /claim/VIDEO_ID/CLAIM_INDEX
    // /ClaimDetailScreen?videoId=...&claimIndex=...
    if (firstSegment == 'claim-detail' ||
        firstSegment == 'claim' ||
        firstSegment == 'claims' ||
        firstSegment == 'claimdetailscreen') {
      String? videoId;
      final vParam = queryParams['videoId'] ?? queryParams['v'] ?? queryParams['id'];
      if (vParam != null && vParam.isNotEmpty) {
        videoId = vParam;
      } else if (pathSegments.length >= 2 && pathSegments[1].isNotEmpty) {
        videoId = pathSegments[1];
      }

      var pathClaimIdx = claimIndex;
      if (pathClaimIdx == null &&
          pathSegments.length >= 3 &&
          int.tryParse(pathSegments[2]) != null) {
        pathClaimIdx = int.parse(pathSegments[2]);
      }

      if (videoId != null && videoId.isNotEmpty) {
        return ParsedTruthworldUrl(
          type: TruthworldUrlType.claim,
          id: videoId,
          claimIndex: pathClaimIdx,
          rawUrl: rawUrl,
          queryParameters: queryParams,
        );
      }
    }

    // 1. VIDEO PATTERNS:
    // /watch?v=VIDEO_ID or /watch/VIDEO_ID or /v/VIDEO_ID or /shorts/VIDEO_ID
    // /clip/VIDEO_ID or /clips/VIDEO_ID or /chapter/VIDEO_ID or /chapters/VIDEO_ID
    if (firstSegment == 'watch' ||
        firstSegment == 'v' ||
        firstSegment == 'shorts' ||
        firstSegment == 'clip' ||
        firstSegment == 'clips' ||
        firstSegment == 'chapter' ||
        firstSegment == 'chapters') {
      String? videoId;
      final vParam = queryParams['v'] ?? queryParams['videoId'];
      if (vParam != null && vParam.isNotEmpty) {
        videoId = vParam;
      } else if (pathSegments.length >= 2 && pathSegments[1].isNotEmpty) {
        videoId = pathSegments[1];
      }

      if (videoId != null && videoId.isNotEmpty) {
        if (claimIndex != null) {
          return ParsedTruthworldUrl(
            type: TruthworldUrlType.claim,
            id: videoId,
            claimIndex: claimIndex,
            timestamp: timestamp,
            playlistId: playlistIdParam,
            rawUrl: rawUrl,
            queryParameters: queryParams,
          );
        }
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
    if (firstSegment == 'channel' ||
        firstSegment == 'c' ||
        firstSegment == 'user') {
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
    if (firstSegment == 't' ||
        firstSegment == 'topic' ||
        firstSegment == 'topics') {
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
    // /community/POST_ID or /post/POST_ID or /p/POST_ID
    if (firstSegment == 'community' ||
        firstSegment == 'post' ||
        firstSegment == 'p') {
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

    // 7. PAYMENT & CHECKOUT RESULT PATTERNS:
    if (firstSegment == 'payment-result' || firstSegment == 'payment_result') {
      final orderId = queryParams['order_id'] ?? queryParams['orderId'] ?? '';
      return ParsedTruthworldUrl(
        type: TruthworldUrlType.paymentResult,
        id: orderId,
        rawUrl: rawUrl,
        queryParameters: queryParams,
      );
    }

    if (firstSegment == 'checkout') {
      final orderId = queryParams['order_id'] ?? queryParams['orderId'] ?? '';
      final action = (queryParams['action'] ?? '').toLowerCase();
      if (action == 'result') {
        return ParsedTruthworldUrl(
          type: TruthworldUrlType.paymentResult,
          id: orderId,
          rawUrl: rawUrl,
          queryParameters: queryParams,
        );
      }
      return ParsedTruthworldUrl(
        type: TruthworldUrlType.unknown,
        id: orderId,
        rawUrl: rawUrl,
        queryParameters: queryParams,
      );
    }

    // 8. SETTINGS / ABOUT / POLICY / LEGAL ROUTES
    if (firstSegment == 'settings') {
      return ParsedTruthworldUrl(
        type: TruthworldUrlType.settings,
        rawUrl: rawUrl,
        queryParameters: queryParams,
      );
    }

    if (firstSegment == 'community-guidelines' ||
        firstSegment == 'terms' ||
        firstSegment == 'privacy' ||
        firstSegment == 'about' ||
        firstSegment == 'copyright-complaint' ||
        firstSegment == 'dmca' ||
        firstSegment == 'feedback') {
      return ParsedTruthworldUrl(
        type: TruthworldUrlType.policy,
        id: firstSegment,
        rawUrl: rawUrl,
        queryParameters: queryParams,
      );
    }

    if (firstSegment.isEmpty || firstSegment == 'home') {
      return ParsedTruthworldUrl(
        type: TruthworldUrlType.home,
        rawUrl: rawUrl,
        queryParameters: queryParams,
      );
    }

    // Reserved routes that must NEVER be hijacked as vanity creator handles
    if (pathSegments.length == 1 &&
        !reservedRoutes.contains(firstSegment.toLowerCase())) {
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
}
