import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/video_visibility_policy.dart';
import 'package:truthworld/core/utils/firestore_cache_extension.dart';
import 'package:truthworld/features/search/data/models/search_result.dart';

/// Engine for fetching curated recommendations, filter presets, and trending search terms.
class SearchRecommendationsEngine {
  SearchRecommendationsEngine({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  List<SearchResult>? _cachedRecommendedVideos;
  DateTime? _videosCacheTime;

  List<SearchResult>? _cachedRecommendedChannels;
  DateTime? _channelsCacheTime;

  List<SearchResult>? _cachedRecommendedPlaylists;
  DateTime? _playlistsCacheTime;

  List<SearchResult>? _cachedRecommendedTopics;
  DateTime? _topicsCacheTime;

  List<String>? _cachedTrendingSuggestions;
  DateTime? _trendingCacheTime;

  static const _cacheDuration = Duration(minutes: 5);

  /// Fetch recommended videos for empty search state (top 12 most viewed valid videos)
  Future<List<SearchResult>> getRecommended({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedRecommendedVideos != null &&
        _videosCacheTime != null &&
        DateTime.now().difference(_videosCacheTime!) < _cacheDuration) {
      return _cachedRecommendedVideos!;
    }

    try {
      final snapshot = await _firestore
          .collection('videos')
          .where('status', whereIn: const ['ready', 'processed', 'published', 'public'])
          .orderBy('views', descending: true)
          .limit(20)
          .getCacheFirst();

      final list = snapshot.docs
          .where((doc) => VideoVisibilityPolicy.isMapValid(doc.data()))
          .map(SearchResult.fromFirestore)
          .where((item) => item.isValid)
          .take(12)
          .toList();

      _cachedRecommendedVideos = list;
      _videosCacheTime = DateTime.now();
      return list;
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'SearchRecommendationsEngine.getRecommended');
      try {
        final snapshot =
            await _firestore.collection('videos').limit(30).getCacheFirst();
        final results = snapshot.docs
            .where((doc) => VideoVisibilityPolicy.isMapValid(doc.data()))
            .map(SearchResult.fromFirestore)
            .where((item) => item.isValid)
            .toList();
        results.sort((a, b) => b.views.compareTo(a.views));
        final list = results.take(12).toList();
        _cachedRecommendedVideos = list;
        _videosCacheTime = DateTime.now();
        return list;
      } catch (err, errStack) {
        ErrorHandler.log(err, stackTrace: errStack, tag: 'SearchRecommendationsEngine.getRecommended.fallback');
        return _cachedRecommendedVideos ?? [];
      }
    }
  }

  /// Fetch recommended channels for empty search state
  Future<List<SearchResult>> getRecommendedChannels({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedRecommendedChannels != null &&
        _channelsCacheTime != null &&
        DateTime.now().difference(_channelsCacheTime!) < _cacheDuration) {
      return _cachedRecommendedChannels!;
    }

    try {
      final snapshot = await _firestore
          .collection('channels')
          .limit(25)
          .getCacheFirst();

      final results = snapshot.docs
          .map((doc) => SearchResult.fromFirestore(doc, type: ResultType.channel))
          .where((item) => item.isValid)
          .toList();
      results.sort((a, b) => b.views.compareTo(a.views));
      final list = results.take(15).toList();
      _cachedRecommendedChannels = list;
      _channelsCacheTime = DateTime.now();
      return list;
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'SearchRecommendationsEngine.getRecommendedChannels');
      return _cachedRecommendedChannels ?? [];
    }
  }

  /// Fetch recommended playlists for empty search state (only non-private playlists with > 0 videos)
  Future<List<SearchResult>> getRecommendedPlaylists({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedRecommendedPlaylists != null &&
        _playlistsCacheTime != null &&
        DateTime.now().difference(_playlistsCacheTime!) < _cacheDuration) {
      return _cachedRecommendedPlaylists!;
    }

    try {
      final snapshot = await _firestore
          .collection('playlists')
          .limit(25)
          .getCacheFirst();

      final results = snapshot.docs
          .where((doc) {
            final data = doc.data();
            final vis = (data['visibility'] as String?)?.toLowerCase();
            final count = (data['videoCount'] as num?)?.toInt() ??
                (data['videosCount'] as num?)?.toInt() ??
                (data['videoIds'] as List?)?.length ??
                0;
            return (vis == null || (vis != 'private' && vis != 'unlisted')) && count > 0;
          })
          .map((doc) => SearchResult.fromFirestore(doc, type: ResultType.playlist))
          .where((item) => item.isValid && item.views > 0)
          .toList();
      results.sort((a, b) => b.views.compareTo(a.views));
      final list = results.take(15).toList();
      _cachedRecommendedPlaylists = list;
      _playlistsCacheTime = DateTime.now();
      return list;
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'SearchRecommendationsEngine.getRecommendedPlaylists');
      return _cachedRecommendedPlaylists ?? [];
    }
  }

  /// Fetch recommended topics for empty search state (only active topics with > 0 videos)
  Future<List<SearchResult>> getRecommendedTopics({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedRecommendedTopics != null &&
        _topicsCacheTime != null &&
        DateTime.now().difference(_topicsCacheTime!) < _cacheDuration) {
      return _cachedRecommendedTopics!;
    }

    try {
      final snapshot = await _firestore
          .collection('topics')
          .limit(25)
          .getCacheFirst();

      final results = snapshot.docs
          .where((doc) {
            final data = doc.data();
            final status = (data['status'] as String?)?.toLowerCase();
            final count = (data['videoCount'] as num?)?.toInt() ??
                (data['featuredVideoIds'] as List?)?.length ??
                0;
            return (status == null || status == 'active') && count > 0;
          })
          .map((doc) => SearchResult.fromFirestore(doc, type: ResultType.topic))
          .where((item) => item.isValid && item.views > 0)
          .toList();
      results.sort((a, b) => b.views.compareTo(a.views));
      final list = results.take(15).toList();
      _cachedRecommendedTopics = list;
      _topicsCacheTime = DateTime.now();
      return list;
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'SearchRecommendationsEngine.getRecommendedTopics');
      return _cachedRecommendedTopics ?? [];
    }
  }

  /// Fetch a balanced, diverse mix of videos, channels, playlists, and topics for 'All' tab
  Future<List<SearchResult>> getRecommendedAll({bool forceRefresh = false}) async {
    try {
      final results = await Future.wait([
        getRecommended(forceRefresh: forceRefresh),
        getRecommendedChannels(forceRefresh: forceRefresh),
        getRecommendedPlaylists(forceRefresh: forceRefresh),
        getRecommendedTopics(forceRefresh: forceRefresh),
      ]);

      final videos = results[0];
      final channels = results[1];
      final playlists = results[2];
      final topics = results[3];

      final combined = <SearchResult>[];

      // Curated layout for the 'All' tab:
      // 1. Top Channel (if available)
      if (channels.isNotEmpty) {
        combined.add(channels.first);
      }

      // 2. Top 2 Videos
      if (videos.isNotEmpty) {
        combined.addAll(videos.take(2));
      }

      // 3. Top Topic (if available)
      if (topics.isNotEmpty) {
        combined.add(topics.first);
      }

      // 4. Next 2 Videos
      if (videos.length > 2) {
        combined.addAll(videos.skip(2).take(2));
      }

      // 5. Top Playlist (if available)
      if (playlists.isNotEmpty) {
        combined.add(playlists.first);
      }

      // 6. Remaining Channels
      if (channels.length > 1) {
        combined.addAll(channels.skip(1).take(2));
      }

      // 7. Remaining Topics
      if (topics.length > 1) {
        combined.addAll(topics.skip(1).take(2));
      }

      // 8. Remaining Playlists
      if (playlists.length > 1) {
        combined.addAll(playlists.skip(1).take(2));
      }

      // 9. Remaining Videos
      if (videos.length > 4) {
        combined.addAll(videos.skip(4));
      }

      final seenKeys = <String>{};
      final uniqueCombined = <SearchResult>[];
      for (final item in combined) {
        if (seenKeys.add('${item.type.name}_${item.id}')) {
          uniqueCombined.add(item);
        }
      }

      return uniqueCombined.isNotEmpty ? uniqueCombined : videos;
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'SearchRecommendationsEngine.getRecommendedAll');
      return getRecommended(forceRefresh: forceRefresh);
    }
  }

  /// Fetch recommended content based on the active filter chip
  Future<List<SearchResult>> getRecommendedForFilter(
    String filter, {
    Set<String>? watchedVideoIds,
    bool forceRefresh = false,
  }) async {
    switch (filter) {
      case 'Channels':
        return getRecommendedChannels(forceRefresh: forceRefresh);
      case 'Playlists':
        return getRecommendedPlaylists(forceRefresh: forceRefresh);
      case 'Topics':
        return getRecommendedTopics(forceRefresh: forceRefresh);
      case 'Watched':
        final allVideos = await getRecommended(forceRefresh: forceRefresh);
        if (watchedVideoIds == null || watchedVideoIds.isEmpty) {
          return allVideos.take(6).toList();
        }
        return allVideos
            .where((v) => watchedVideoIds.contains(v.id))
            .toList();
      case 'Unwatched':
        final allVideos = await getRecommended(forceRefresh: forceRefresh);
        if (watchedVideoIds == null || watchedVideoIds.isEmpty) {
          return allVideos;
        }
        return allVideos
            .where((v) => !watchedVideoIds.contains(v.id))
            .toList();
      case 'Recently uploaded':
        final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
        final allVideos = await getRecommended(forceRefresh: forceRefresh);
        final recent = allVideos.where((v) => v.uploadedAt.isAfter(sevenDaysAgo)).toList();
        return recent.isNotEmpty ? recent : allVideos;
      case 'Videos':
        return getRecommended(forceRefresh: forceRefresh);
      case 'All':
      default:
        return getRecommendedAll(forceRefresh: forceRefresh);
    }
  }

  /// Fetch trending search queries from Firestore
  Future<List<String>> getTrendingSuggestions({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedTrendingSuggestions != null &&
        _trendingCacheTime != null &&
        DateTime.now().difference(_trendingCacheTime!) < _cacheDuration) {
      return _cachedTrendingSuggestions!;
    }

    try {
      QuerySnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot = await _firestore
            .collection('trending_searches')
            .orderBy('searchCount', descending: true)
            .limit(10)
            .getCacheFirst();
      } catch (e1, s1) {
        ErrorHandler.log(e1, stackTrace: s1, tag: 'SearchRecommendationsEngine.trending.searchCount');
        try {
          snapshot = await _firestore
              .collection('trending_searches')
              .orderBy('count', descending: true)
              .limit(10)
              .getCacheFirst();
        } catch (e2, s2) {
          ErrorHandler.log(e2, stackTrace: s2, tag: 'SearchRecommendationsEngine.trending.count');
          snapshot = await _firestore
              .collection('trending_searches')
              .limit(10)
              .getCacheFirst();
        }
      }

      final list = snapshot.docs.map((doc) {
        final data = doc.data();
        return (data['term'] ?? data['query'] ?? doc.id).toString();
      }).where((s) => s.trim().isNotEmpty).toList();

      if (list.isNotEmpty) {
        _cachedTrendingSuggestions = list;
        _trendingCacheTime = DateTime.now();
      }

      return list;
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'SearchRecommendationsEngine.getTrendingSuggestions');
      return _cachedTrendingSuggestions ?? const [];
    }
  }
}
