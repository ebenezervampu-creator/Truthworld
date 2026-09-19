import 'package:truthworld/core/services/deep_link/parsed_truthworld_url.dart';

/// URL parsing engine supporting YouTube-standard URLs and TruthWorld routes.
class DeepLinkUrlParser {
  const DeepLinkUrlParser._();

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
      uriStr = uriStr.replaceFirst(
        RegExp(r'truthworld[a-z]*:\/\/'),
        'https://www.truthworld.in/',
      );
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
    final firstSegment =
        pathSegments.isNotEmpty ? pathSegments.first.toLowerCase() : '';

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

    // 1. VIDEO PATTERNS:
    // /watch?v=VIDEO_ID or /watch/VIDEO_ID or /v/VIDEO_ID or /shorts/VIDEO_ID
    if (firstSegment == 'watch' ||
        firstSegment == 'v' ||
        firstSegment == 'shorts') {
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
        ![
          'home',
          'explore',
          'trending',
          'library',
          'history',
          'likedvideos',
          'watchlater',
          'subscriptions',
          'about',
          'privacy',
          'terms',
        ].contains(firstSegment)) {
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
