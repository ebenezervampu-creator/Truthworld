import 'package:truthworld/core/services/deep_link/deep_link_barrel.dart';

export 'package:truthworld/core/services/deep_link/deep_link_barrel.dart';

/// Centralized deep-link service coordinator for TruthWorld.
///
/// Single source of truth for:
/// - Instant YouTube-style URL parsing and low-latency internal dispatch
/// - Share URL generation (video, channel, playlist, topic)
/// - Ultra-fast multi-tier in-memory entity cache (0ms navigation)
/// - AppLinks / Universal Links background stream and cold-launch listener
/// - Firestore content loading with timeout + retry fallback
class DeepLinkService
    with
        DeepLinkCacheManager,
        DeepLinkContentLoader,
        DeepLinkNavigator,
        DeepLinkUrlBuilderAndShare {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  static const String baseUrl = DeepLinkUrlBuilderAndShare.baseUrl;

  /// Cleans trailing punctuation from URLs.
  static String cleanUrlString(String rawUrl) =>
      DeepLinkUrlParser.cleanUrlString(rawUrl);

  /// Parses timestamp expressions (e.g. "90", "90s", "1m30s", "1h2m3s").
  static Duration? parseTimestamp(String? timeStr) =>
      DeepLinkUrlParser.parseTimestamp(timeStr);

  /// Checks whether a given URL belongs to Truthworld.
  static bool isTruthworldUrl(String rawUrl) =>
      DeepLinkUrlParser.isTruthworldUrl(rawUrl);

  /// Parses any URL string into a structured [ParsedTruthworldUrl].
  static ParsedTruthworldUrl parseUrl(String rawUrl) =>
      DeepLinkUrlParser.parseUrl(rawUrl);

  /// Generates a shareable video URL.
  static String videoUrl(String videoId) =>
      DeepLinkUrlBuilderAndShare.videoUrl(videoId);

  /// Generates a shareable channel URL.
  static String channelUrl(String channelId) =>
      DeepLinkUrlBuilderAndShare.channelUrl(channelId);

  /// Generates a shareable playlist URL.
  static String playlistUrl(String playlistId) =>
      DeepLinkUrlBuilderAndShare.playlistUrl(playlistId);

  /// Generates a shareable topic URL.
  static String topicUrl(String slugOrHandle) =>
      DeepLinkUrlBuilderAndShare.topicUrl(slugOrHandle);
}
