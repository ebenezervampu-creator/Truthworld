import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/video_visibility_policy.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/search/data/models/search_result.dart';
import 'package:truthworld/features/search/data/services/engine/search_sanitizer.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Direct Firestore search engine for Videos, Channels, Playlists, and Topics
/// with multi-tier indexing and fallback strategies.
class SearchEntityQueryEngine {
  SearchEntityQueryEngine({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  // ==========================================================================
  // 🎬 VIDEO SEARCH
  // ==========================================================================

  /// Search videos using indexed keywords, title prefix, token fallback, and local fallback
  Future<List<SearchResult>> searchVideos(String query) async {
    final cleanQuery = SearchSanitizer.sanitizeQuery(query);
    if (cleanQuery.isEmpty) return [];

    final tokens = SearchSanitizer.extractTokens(cleanQuery);

    final titleCased = cleanQuery.isEmpty
        ? cleanQuery
        : '${cleanQuery[0].toUpperCase()}${cleanQuery.substring(1)}';

    final foundIds = <String>{};
    final results = <SearchResult>[];

    void addResult(SearchResult item, [Map<String, dynamic>? data]) {
      if (!item.isValid) return;
      if (data != null && !VideoVisibilityPolicy.isMapValid(data)) return;
      if (foundIds.add(item.id)) {
        results.add(item);
      }
    }

    // 1. Try keywords (fast, indexed query)
    try {
      final s = await _firestore
          .collection('videos')
          .where('keywords', arrayContains: cleanQuery)
          .limit(20)
          .get();
      for (final doc in s.docs) {
        addResult(SearchResult.fromFirestore(doc), doc.data());
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'SearchEntityQueryEngine.searchVideos.keywords');
    }

    // 2. Try prefix search with lowercase, TitleCase, and UPPERCASE
    if (results.isEmpty) {
      for (final qPrefix in [query, titleCased, query.toUpperCase()]) {
        try {
          final s = await _firestore
              .collection('videos')
              .where('title', isGreaterThanOrEqualTo: qPrefix)
              .where('title', isLessThanOrEqualTo: '$qPrefix\uf8ff')
              .limit(20)
              .get();
          for (final doc in s.docs) {
            addResult(SearchResult.fromFirestore(doc), doc.data());
          }
        } catch (e, s) {
          ErrorHandler.log(e, stackTrace: s, tag: 'SearchEntityQueryEngine.searchVideos.prefix');
        }
        if (results.isNotEmpty) break;
      }
    }

    // 3. Indexed Multi-Token Fallback
    if (results.isEmpty && tokens.isNotEmpty) {
      for (final tok in tokens.take(2)) {
        if (tok.length < 3) continue;
        try {
          final s = await _firestore
              .collection('videos')
              .where('keywords', arrayContains: tok)
              .where('visibility', isEqualTo: 'public')
              .limit(10)
              .get();
          for (final doc in s.docs) {
            addResult(SearchResult.fromFirestore(doc), doc.data());
          }
        } catch (e, s) {
          ErrorHandler.log(e, stackTrace: s, tag: 'SearchEntityQueryEngine.searchVideos.tokenFallback');
        }
        if (results.isNotEmpty) break;
      }
    }

    // 4. Free Local Multi-Token Fallback (for development/testing or offline capability)
    if (results.isEmpty) {
      try {
        if (Get.isRegistered<HomeController>()) {
          final homeCtrl = Get.find<HomeController>();
          final localMatches = homeCtrl.videos
              .whereType<Video>()
              .where((v) {
                final t = v.title.toLowerCase();
                final c = v.channelName.toLowerCase();
                if (t.contains(cleanQuery) || c.contains(cleanQuery)) return true;
                if (tokens.isNotEmpty) {
                  return tokens.every(
                    (token) => t.contains(token) || c.contains(token),
                  );
                }
                return false;
              })
              .map(
                (v) => SearchResult(
                  id: v.id,
                  title: v.title,
                  thumbnail: v.thumbnailUrl,
                  views: v.viewCount,
                  channelName: v.channelName,
                  channelImage: v.channelAvatarUrl,
                  createdAt: v.createdAt,
                  durationMs: v.durationValue.inMilliseconds,
                  visibility: v.visibility,
                ),
              );
          localMatches.forEach(addResult);
        }
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'SearchEntityQueryEngine.searchVideos.localCache');
      }
    }

    return results;
  }

  // ==========================================================================
  // 🎙️ CHANNEL SEARCH
  // ==========================================================================

  /// Search channels using nameLowercase, name TitleCase, and handle prefix queries
  Future<List<SearchResult>> searchChannels(String query) async {
    final cleanQuery = SearchSanitizer.sanitizeQuery(query);
    if (cleanQuery.isEmpty) return [];

    final tokens = SearchSanitizer.extractTokens(cleanQuery);

    final titleCased = cleanQuery.isEmpty
        ? cleanQuery
        : '${cleanQuery[0].toUpperCase()}${cleanQuery.substring(1)}';

    final foundIds = <String>{};
    final results = <SearchResult>[];

    void addResult(SearchResult item) {
      if (!item.isValid) return;
      if (foundIds.add(item.id)) {
        results.add(item);
      }
    }

    try {
      // 1. Try nameLowercase prefix
      final s1 = await _firestore
          .collection('channels')
          .where('nameLowercase', isGreaterThanOrEqualTo: cleanQuery)
          .where('nameLowercase', isLessThanOrEqualTo: '$cleanQuery\uf8ff')
          .limit(10)
          .get();
      for (final doc in s1.docs) {
        addResult(SearchResult.fromFirestore(doc, type: ResultType.channel));
      }

      // 2. Try name prefix (query and TitleCase)
      if (results.isEmpty) {
        for (final qPrefix in [cleanQuery, titleCased]) {
          final s2 = await _firestore
              .collection('channels')
              .where('name', isGreaterThanOrEqualTo: qPrefix)
              .where('name', isLessThanOrEqualTo: '$qPrefix\uf8ff')
              .limit(10)
              .get();
          for (final doc in s2.docs) {
            addResult(SearchResult.fromFirestore(doc, type: ResultType.channel));
          }
          if (results.isNotEmpty) break;
        }
      }

      // 3. Try handle / handleLowercase prefix
      if (results.isEmpty) {
        for (final handleQ in [cleanQuery, '@$cleanQuery']) {
          final s3 = await _firestore
              .collection('channels')
              .where('handleLowercase', isGreaterThanOrEqualTo: handleQ)
              .where('handleLowercase', isLessThanOrEqualTo: '$handleQ\uf8ff')
              .limit(10)
              .get();
          for (final doc in s3.docs) {
            addResult(SearchResult.fromFirestore(doc, type: ResultType.channel));
          }
          if (results.isNotEmpty) break;
        }
      }

      // 4. Token prefix search over channel handles
      if (results.isEmpty && tokens.isNotEmpty) {
        for (final tok in tokens.take(2)) {
          if (tok.length < 3) continue;
          final s4 = await _firestore
              .collection('channels')
              .where('nameLowercase', isGreaterThanOrEqualTo: tok)
              .where('nameLowercase', isLessThanOrEqualTo: '$tok\uf8ff')
              .limit(5)
              .get();
          for (final doc in s4.docs) {
            addResult(SearchResult.fromFirestore(doc, type: ResultType.channel));
          }
          if (results.isNotEmpty) break;
        }
      }

      return results;
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'SearchEntityQueryEngine.searchChannels');
      return results;
    }
  }

  // ==========================================================================
  // 📂 PLAYLIST SEARCH
  // ==========================================================================

  /// Search playlists using name and title prefix queries, filtering private/empty playlists
  Future<List<SearchResult>> searchPlaylists(String query) async {
    final cleanQuery = SearchSanitizer.sanitizeQuery(query);
    if (cleanQuery.isEmpty) return [];

    final tokens = SearchSanitizer.extractTokens(cleanQuery);

    final titleCased = cleanQuery.isEmpty
        ? cleanQuery
        : '${cleanQuery[0].toUpperCase()}${cleanQuery.substring(1)}';

    final foundIds = <String>{};
    final results = <SearchResult>[];

    void addResult(SearchResult item, [Map<String, dynamic>? data]) {
      if (!item.isValid) return;
      if (data != null) {
        final vis = (data['visibility'] as String?)?.toLowerCase();
        if (vis == 'private') return;
        final count = (data['videoCount'] as num?)?.toInt() ??
            (data['videosCount'] as num?)?.toInt() ??
            (data['videoIds'] as List?)?.length ??
            0;
        if (count <= 0) return;
      }
      if (foundIds.add(item.id)) {
        results.add(item);
      }
    }

    try {
      // 1. Try name prefix (query and TitleCase)
      for (final qPrefix in [cleanQuery, titleCased]) {
        final s1 = await _firestore
            .collection('playlists')
            .where('name', isGreaterThanOrEqualTo: qPrefix)
            .where('name', isLessThanOrEqualTo: '$qPrefix\uf8ff')
            .limit(10)
            .get();
        for (final doc in s1.docs) {
          addResult(SearchResult.fromFirestore(doc, type: ResultType.playlist), doc.data());
        }
        if (results.isNotEmpty) break;
      }

      // 2. Try title prefix if empty
      if (results.isEmpty) {
        for (final qPrefix in [cleanQuery, titleCased]) {
          final s2 = await _firestore
              .collection('playlists')
              .where('title', isGreaterThanOrEqualTo: qPrefix)
              .where('title', isLessThanOrEqualTo: '$qPrefix\uf8ff')
              .limit(10)
              .get();
          for (final doc in s2.docs) {
            addResult(SearchResult.fromFirestore(doc, type: ResultType.playlist), doc.data());
          }
          if (results.isNotEmpty) break;
        }
      }

      // 3. Token prefix search over playlist titles
      if (results.isEmpty && tokens.isNotEmpty) {
        for (final tok in tokens.take(2)) {
          if (tok.length < 3) continue;
          final s3 = await _firestore
              .collection('playlists')
              .where('name', isGreaterThanOrEqualTo: tok)
              .where('name', isLessThanOrEqualTo: '$tok\uf8ff')
              .limit(5)
              .get();
          for (final doc in s3.docs) {
            addResult(SearchResult.fromFirestore(doc, type: ResultType.playlist), doc.data());
          }
          if (results.isNotEmpty) break;
        }
      }

      return results;
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'SearchEntityQueryEngine.searchPlaylists');
      return results;
    }
  }

  // ==========================================================================
  // 🏷️ TOPIC SEARCH
  // ==========================================================================

  /// Search topics using title prefix, slug prefix, and tags arrayContains
  Future<List<SearchResult>> searchTopics(String query) async {
    final cleanQuery = SearchSanitizer.sanitizeQuery(query);
    if (cleanQuery.isEmpty) return [];

    final tokens = SearchSanitizer.extractTokens(cleanQuery);

    final titleCased = cleanQuery.isEmpty
        ? cleanQuery
        : '${cleanQuery[0].toUpperCase()}${cleanQuery.substring(1)}';

    final foundIds = <String>{};
    final results = <SearchResult>[];

    void addResult(SearchResult item, [Map<String, dynamic>? data]) {
      if (!item.isValid) return;
      if (data != null) {
        final status = (data['status'] as String?)?.toLowerCase();
        if (status != null && status != 'active') return;
        final count = (data['videoCount'] as num?)?.toInt() ??
            (data['featuredVideoIds'] as List?)?.length ??
            0;
        if (count <= 0) return;
      }
      if (foundIds.add(item.id)) {
        results.add(item);
      }
    }

    try {
      // 1. Try title prefix (query and TitleCase)
      for (final qPrefix in [cleanQuery, titleCased]) {
        final s1 = await _firestore
            .collection('topics')
            .where('title', isGreaterThanOrEqualTo: qPrefix)
            .where('title', isLessThanOrEqualTo: '$qPrefix\uf8ff')
            .limit(10)
            .get();
        for (final doc in s1.docs) {
          addResult(SearchResult.fromFirestore(doc, type: ResultType.topic), doc.data());
        }
        if (results.isNotEmpty) break;
      }

      // 2. Try slug prefix
      if (results.isEmpty) {
        final s2 = await _firestore
            .collection('topics')
            .where('slug', isGreaterThanOrEqualTo: cleanQuery)
            .where('slug', isLessThanOrEqualTo: '$cleanQuery\uf8ff')
            .limit(10)
            .get();
        for (final doc in s2.docs) {
          addResult(SearchResult.fromFirestore(doc, type: ResultType.topic), doc.data());
        }
      }

      // 3. Try tags arrayContains
      if (results.isEmpty) {
        final s3 = await _firestore
            .collection('topics')
            .where('tags', arrayContains: cleanQuery)
            .limit(10)
            .get();
        for (final doc in s3.docs) {
          addResult(SearchResult.fromFirestore(doc, type: ResultType.topic), doc.data());
        }
      }

      // 4. Token prefix search over topic slugs
      if (results.isEmpty && tokens.isNotEmpty) {
        for (final tok in tokens.take(2)) {
          if (tok.length < 3) continue;
          final s4 = await _firestore
              .collection('topics')
              .where('slug', isGreaterThanOrEqualTo: tok)
              .where('slug', isLessThanOrEqualTo: '$tok\uf8ff')
              .limit(5)
              .get();
          for (final doc in s4.docs) {
            addResult(SearchResult.fromFirestore(doc, type: ResultType.topic), doc.data());
          }
          if (results.isNotEmpty) break;
        }
      }

      return results;
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'SearchEntityQueryEngine.searchTopics');
      return results;
    }
  }
}
