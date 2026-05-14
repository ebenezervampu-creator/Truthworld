class RouteMetadata {
  final String title;
  final String description;
  final String? image;
  final String? keywords;
  final String? author;

  const RouteMetadata({
    required this.title,
    required this.description,
    this.image,
    this.keywords,
    this.author,
  });
}

class RouteMetadataConfig {
  static const String _defaultImage = 'https://www.truthworld.in/og-image.png';
  static const String _defaultAuthor = 'Truthworld';
  static const String _defaultKeywords =
      'video, sharing, streaming, Truthworld, creators';

  static final Map<String, RouteMetadata> _routes = {
    '/': const RouteMetadata(
      title: 'Home | Truthworld',
      description: 'Truthworld - Share and discover amazing video content',
      keywords: 'home, video, discovery, Truthworld',
    ),
    '/home': const RouteMetadata(
      title: 'Home | Truthworld',
      description: 'Truthworld - Share and discover amazing video content',
      keywords: 'home, video, discovery, Truthworld',
    ),
    '/studio': const RouteMetadata(
      title: 'Creator Studio',
      description: 'Manage your videos, analytics, and channel on Truthworld',
      keywords: 'studio, creator, analytics, management',
    ),
    '/dashboard': const RouteMetadata(
      title: 'Dashboard',
      description: 'View your channel performance and recent activity',
      keywords: 'dashboard, analytics, overview',
    ),
    '/history': const RouteMetadata(
      title: 'Watch History',
      description: 'Keep track of the videos you have watched',
      keywords: 'history, watched, videos',
    ),
    '/watchlater': const RouteMetadata(
      title: 'Watch Later',
      description: 'Videos you have saved to watch later',
      keywords: 'watch later, saved, videos',
    ),
    '/likedvideos': const RouteMetadata(
      title: 'Liked Videos',
      description: 'All the videos you have liked on Truthworld',
      keywords: 'liked, favorites, videos',
    ),
    '/playlistscreen': const RouteMetadata(
      title: 'Playlists',
      description: 'View and manage your video playlists',
      keywords: 'playlists, collection, videos',
    ),
    '/myvideos': const RouteMetadata(
      title: 'My Videos',
      description: 'Manage and view your uploaded videos',
      keywords: 'my videos, uploads, content',
    ),
    '/uploadscreen': const RouteMetadata(
      title: 'Upload Video',
      description: 'Share your content with the world on Truthworld',
      keywords: 'upload, share, video, content',
    ),
    '/library': const RouteMetadata(
      title: 'Library',
      description: 'Your collection of history, likes, and playlists',
      keywords: 'library, collection, history, likes',
    ),
    '/category': const RouteMetadata(
      title: 'Categories',
      description: 'Discover videos by category on Truthworld',
      keywords: 'category, discover, genres',
    ),
    '/settings': const RouteMetadata(
      title: 'Settings',
      description: 'Manage your account settings and preferences',
      keywords: 'settings, account, preferences',
    ),
    '/feedback': const RouteMetadata(
      title: 'Feedback',
      description: 'Help us improve Truthworld by sharing your thoughts',
      keywords: 'feedback, suggestion, improvement',
    ),
    '/help': const RouteMetadata(
      title: 'Help Center',
      description: 'Get support and find answers to your questions',
      keywords: 'help, support, faq',
    ),
    '/notifications': const RouteMetadata(
      title: 'Notifications',
      description: 'Stay updated with latest activity on Truthworld',
      keywords: 'notifications, updates, activity',
    ),
    '/downloads': const RouteMetadata(
      title: 'Downloads',
      description: 'Access your downloaded videos for offline viewing',
      keywords: 'downloads, offline, videos',
    ),
    '/privacy': const RouteMetadata(
      title: 'Privacy Policy',
      description: 'Learn how we protect your data and privacy',
      keywords: 'privacy, policy, data protection',
    ),
    '/terms': const RouteMetadata(
      title: 'Terms & Conditions',
      description: 'Read our terms of service and usage guidelines',
      keywords: 'terms, conditions, service',
    ),
    '/subscriptions': const RouteMetadata(
      title: 'Subscriptions',
      description: 'Keep up with the creators you follow',
      keywords: 'subscriptions, following, creators',
    ),
  };

  /// Get metadata for a specific route
  static RouteMetadata? getMetadata(String? route) {
    if (route == null || route.isEmpty) return _routes['/'];

    // Exact match
    if (_routes.containsKey(route)) {
      final meta = _routes[route]!;
      return RouteMetadata(
        title: meta.title,
        description: meta.description,
        image: meta.image ?? _defaultImage,
        keywords: meta.keywords ?? _defaultKeywords,
        author: meta.author ?? _defaultAuthor,
      );
    }

    // Dynamic routes handling (e.g., /watch/:id, /channel/:id)
    if (route.startsWith('/watch/')) {
      return const RouteMetadata(
        title: 'Watching Video',
        description: 'Watch this amazing video on Truthworld',
        image: _defaultImage,
        keywords: 'video, watch, streaming',
        author: _defaultAuthor,
      );
    }

    if (route.startsWith('/channel/')) {
      return const RouteMetadata(
        title: 'Channel',
        description: 'Discover content from this creator on Truthworld',
        image: _defaultImage,
        keywords: 'channel, creator, videos',
        author: _defaultAuthor,
      );
    }

    if (route.startsWith('/playlist/')) {
      return const RouteMetadata(
        title: 'Playlist',
        description: 'Enjoy this collection of videos on Truthworld',
        image: _defaultImage,
        keywords: 'playlist, collection, videos',
        author: _defaultAuthor,
      );
    }

    // Default metadata if route not found
    return _routes['/'];
  }
}





