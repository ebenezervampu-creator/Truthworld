/// Centralised Firestore collection-name constants.
///
/// Every Firestore collection or subcollection path used in the app MUST be
/// referenced through this class. This prevents hard-coded string typos and
/// ensures schema changes are a single-file operation.
class FirestoreCollections {
  const FirestoreCollections._();

  // ── Root Collections ──────────────────────────────────────────────
  static const String users = 'users';
  static const String channels = 'channels';
  static const String videos = 'videos';
  static const String playlists = 'playlists';
  static const String notifications = 'notifications';
  static const String searchResults = 'search_results';
  static const String community = 'Community';
  static const String reports = 'reports';
  static const String feedback = 'feedback';
  static const String subscriptions = 'subscriptions';
  static const String categories = 'categories';
  static const String hashtags = 'hashtags';
  static const String topics = 'topics';
  static const String trending = 'trending';
  static const String ads = 'ads';
  static const String watchHistory = 'watchHistory';
  static const String analytics = 'analytics';
  static const String impressions = 'impressions';
  static const String auditLogs = 'auditLogs';
  static const String premiumSubscriptions = 'premiumSubscriptions';
  static const String channelLanguageRequests = 'channel_language_requests';
  static const String factCheckRequests = 'fact_check_requests';

  // ── Video Subcollections ──────────────────────────────────────────
  static String videoComments(String videoId) => 'videos/$videoId/comments';
  static String videoLikes(String videoId) => 'videos/$videoId/likes';
  static String videoDislikes(String videoId) => 'videos/$videoId/dislikes';
  static String videoShards(String videoId) => 'videos/$videoId/shards';

  // ── Channel Subcollections ────────────────────────────────────────
  static String channelVideos(String channelId) => 'channels/$channelId/videos';
  static String channelSubscribers(String channelId) =>
      'channels/$channelId/subscribers';
  static String channelShards(String channelId) =>
      'channels/$channelId/shards';

  // ── Playlist Subcollections ───────────────────────────────────────
  static String videoPlaylistItems(String playlistId) =>
      'playlists/$playlistId/items';

  // ── User Subcollections ───────────────────────────────────────────
  static String userHistory(String userId) => 'users/$userId/history';
  static String userSubscriptions(String userId) =>
      'users/$userId/subscriptions';
  static String userNotifications(String userId) =>
      'users/$userId/notifications';
  static String userBookmarks(String userId) => 'users/$userId/bookmarks';
  static String userSavedPosts(String userId) => 'users/$userId/savedPosts';

  // ── Community Subcollections ──────────────────────────────────────
  static String communityComments(String postId) =>
      'Community/$postId/comments';
  static String communityLikes(String postId) => 'Community/$postId/likes';
  static String communityDislikes(String postId) =>
      'Community/$postId/dislikes';

  // ── Topic Subcollections ──────────────────────────────────────────
  static String topicComments(String topicId) => 'topics/$topicId/comments';
  static String topicShards(String topicId) => 'topics/$topicId/shards';
  static String videoCommentShards(String videoId) =>
      'videos/$videoId/comment_shards';
}
