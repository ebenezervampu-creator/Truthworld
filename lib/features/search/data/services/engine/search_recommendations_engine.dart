import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/video_visibility_policy.dart';
import 'package:truthworld/features/search/data/models/search_result.dart';

/// Engine for fetching curated recommendations, filter presets, and trending search terms.
class SearchRecommendationsEngine {
  SearchRecommendationsEngine({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Fetch recommended videos for empty search state (top 12 most viewed valid videos)
  Future<List<SearchResult>> getRecommended() async {
    try {
      final snapshot = await _firestore
          .collection('videos')
          .where('status', whereIn: const ['ready', 'processed', 'published', 'public'])
          .orderBy('views', descending: true)
          .limit(20)
          .get();

      return snapshot.docs
          .where((doc) => VideoVisibilityPolicy.isMapValid(doc.data()))
          .map(SearchResult.fromFirestore)
          .where((item) => item.isValid)
          .take(12)
          .toList();
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'SearchRecommendationsEngine.getRecommended');
      // Secondary fallback: query without composite ordering (and sort locally) if index is building
      try {
        final snapshot = await _firestore.collection('videos').limit(30).get();
        final results = snapshot.docs
            .where((doc) => VideoVisibilityPolicy.isMapValid(doc.data()))
            .map(SearchResult.fromFirestore)
            .where((item) => item.isValid)
            .toList();
        results.sort((a, b) => b.views.compareTo(a.views));
        return results.take(12).toList();
      } catch (err, errStack) {
        ErrorHandler.log(err, stackTrace: errStack, tag: 'SearchRecommendationsEngine.getRecommended.fallback');
        return [];
      }
    }
  }

  /// Fetch recommended channels for empty search state
  Future<List<SearchResult>> getRecommendedChannels() async {
    try {
      final snapshot = await _firestore
          .collection('channels')
          .limit(25)
          .get();

      final results = snapshot.docs
          .map((doc) => SearchResult.fromFirestore(doc, type: ResultType.channel))
          .where((item) => item.isValid)
          .toList();
      results.sort((a, b) => b.views.compareTo(a.views));
      return results.take(15).toList();
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'SearchRecommendationsEngine.getRecommendedChannels');
      return [];
    }
  }

  /// Fetch recommended playlists for empty search state (only non-private playlists with > 0 videos)
  Future<List<SearchResult>> getRecommendedPlaylists() async {
    try {
      final snapshot = await _firestore
          .collection('playlists')
          .limit(25)
          .get();

      final results = snapshot.docs
          .where((doc) {
            final data = doc.data();
            final vis = (data['visibility'] as String?)?.toLowerCase();
            final count = (data['videoCount'] as num?)?.toInt() ??
                (data['videosCount'] as num?)?.toInt() ??
                (data['videoIds'] as List?)?.length ??
                0;
            return (vis == null || vis != 'private') && count > 0;
          })
          .map((doc) => SearchResult.fromFirestore(doc, type: ResultType.playlist))
          .where((item) => item.isValid && item.views > 0)
          .toList();
      results.sort((a, b) => b.views.compareTo(a.views));
      return results.take(15).toList();
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'SearchRecommendationsEngine.getRecommendedPlaylists');
      return [];
    }
  }

  /// Fetch recommended topics for empty search state (only active topics with > 0 videos)
  Future<List<SearchResult>> getRecommendedTopics() async {
    try {
      final snapshot = await _firestore
          .collection('topics')
          .limit(25)
          .get();

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
      return results.take(15).toList();
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'SearchRecommendationsEngine.getRecommendedTopics');
      return [];
    }
  }

  /// Fetch a balanced, diverse mix of videos, channels, playlists, and topics for 'All' tab
  Future<List<SearchResult>> getRecommendedAll() async {
    try {
      final results = await Future.wait([
        getRecommended(),
        getRecommendedChannels(),
        getRecommendedPlaylists(),
        getRecommendedTopics(),
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
      return getRecommended();
    }
  }

  /// Fetch recommended content based on the active filter chip
  Future<List<SearchResult>> getRecommendedForFilter(
    String filter, {
    Set<String>? watchedVideoIds,
  }) async {
    switch (filter) {
      case 'Channels':
        return getRecommendedChannels();
      case 'Playlists':
        return getRecommendedPlaylists();
      case 'Topics':
        return getRecommendedTopics();
      case 'Watched':
        final allVideos = await getRecommended();
        if (watchedVideoIds == null || watchedVideoIds.isEmpty) {
          return allVideos.take(6).toList();
        }
        return allVideos
            .where((v) => watchedVideoIds.contains(v.id))
            .toList();
      case 'Unwatched':
        final allVideos = await getRecommended();
        if (watchedVideoIds == null || watchedVideoIds.isEmpty) {
          return allVideos;
        }
        return allVideos
            .where((v) => !watchedVideoIds.contains(v.id))
            .toList();
      case 'Recently uploaded':
        final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
        final allVideos = await getRecommended();
        final recent = allVideos.where((v) => v.uploadedAt.isAfter(sevenDaysAgo)).toList();
        return recent.isNotEmpty ? recent : allVideos;
      case 'Videos':
        return getRecommended();
      case 'All':
      default:
        return getRecommendedAll();
    }
  }

  /// Fetch trending search queries from Firestore
  Future<List<String>> getTrendingSuggestions() async {
    try {
      QuerySnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot = await _firestore
            .collection('trending_searches')
            .orderBy('searchCount', descending: true)
            .limit(10)
            .get();
      } catch (e1, s1) {
        ErrorHandler.log(e1, stackTrace: s1, tag: 'SearchRecommendationsEngine.trending.searchCount');
        try {
          snapshot = await _firestore
              .collection('trending_searches')
              .orderBy('count', descending: true)
              .limit(10)
              .get();
        } catch (e2, s2) {
          ErrorHandler.log(e2, stackTrace: s2, tag: 'SearchRecommendationsEngine.trending.count');
          snapshot = await _firestore
              .collection('trending_searches')
              .limit(10)
              .get();
        }
      }

      if (snapshot.docs.isEmpty) {
        return const [
          'Flutter Tutorial',
          'Web Development',
          'Mobile Apps',
          'UI Design',
          'Firebase',
        ];
      }

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return (data['term'] ?? data['query'] ?? doc.id).toString();
      }).toList();
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'SearchRecommendationsEngine.getTrendingSuggestions');
      return const [
        'Flutter Tutorial',
        'Web Development',
        'Mobile Apps',
        'UI Design',
        'Firebase',
      ];
    }
  }
}
