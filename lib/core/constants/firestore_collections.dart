class FirestoreCollections {
  // Root Collections
  static const String users = 'users';
  static const String channels = 'channels';
  static const String videos = 'videos';
  static const String playlists = 'playlists';
  static const String notifications = 'notifications';
  static const String searchResults = 'search_results';

  // Subcollections (Patterns)
  static String channelVideos(String channelId) => 'channels/$channelId/videos';
  static String channelSubscribers(String channelId) =>
      'channels/$channelId/subscribers';
  static String videoComments(String videoId) => 'videos/$videoId/comments';
  static String videoLikes(String videoId) => 'videos/$videoId/likes';
  static String videoPlaylistItems(String playlistId) =>
      'playlists/$playlistId/items';
  static String userHistory(String userId) => 'users/$userId/history';
  static String userSubscriptions(String userId) =>
      'users/$userId/subscriptions';
  static String userNotifications(String userId) =>
      'users/$userId/notifications';
}





