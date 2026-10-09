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
  policy,
  paymentResult,
  checkout,
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
