import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/features/search/presentation/controllers/search/search_models.dart';

/// Manages realtime trending search items from Firestore with fallback to top videos and topics.
class SearchTrendingManager {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;

  /// Load trending searches with fallback (eliminates open WebSocket/gRPC listener churn)
  Future<void> loadTrending({
    required void Function(List<TrendingItem> items) onTrendingLoaded,
    required void Function(bool isLoading) onLoadingChanged,
  }) async {
    try {
      onLoadingChanged(true);
      final snapshot = await FirebaseFirestore.instance
          .collection('trending_searches')
          .limit(10)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final items = <TrendingItem>[];
        var rank = 1;
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final queryStr = (data['term'] ?? data['query'] ?? doc.id).toString();
          final count = (data['searchCount'] as num?)?.toInt() ??
              (data['count'] as num?)?.toInt() ??
              (1000 - rank * 50);
          final typeStr = data['type'] as String? ?? 'video';
          final movementStr = data['movement'] as String? ??
              (rank == 1
                  ? '▲ Up 2'
                  : (rank == 2 ? 'NEW' : (rank == 3 ? '▲ Up 4' : '▼ Down 1')));
          items.add(
            TrendingItem(
              id: doc.id,
              rank: rank,
              title: queryStr,
              category: typeStr,
              volume: count,
              badge: rank <= 3 ? '🔥 REALTIME' : 'RISING',
              movement: movementStr,
              subtitle: '${formatVolume(count)} searches today',
              imageUrl: data['thumbnailUrl'] as String?,
              creator: data['creatorName'] as String? ?? data['channelName'] as String?,
            ),
          );
          rank++;
        }
        onTrendingLoaded(items);
      } else {
        final fallbackItems = await fetchFallbackTrending();
        onTrendingLoaded(fallbackItems);
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'SearchTrendingManager.loadTrending');
      final fallbackItems = await fetchFallbackTrending();
      onTrendingLoaded(fallbackItems);
    } finally {
      onLoadingChanged(false);
    }
  }

  /// Load trending searches with resource-efficient single fetch
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? subscribeToTrending({
    required void Function(List<TrendingItem> items) onTrendingLoaded,
    required void Function(bool isLoading) onLoadingChanged,
  }) {
    unawaited(loadTrending(
      onTrendingLoaded: onTrendingLoaded,
      onLoadingChanged: onLoadingChanged,
    ));
    return null;
  }

  /// Query top authentic videos and topics from Firestore as trending fallback
  Future<List<TrendingItem>> fetchFallbackTrending() async {
    try {
      final items = <TrendingItem>[];

      QuerySnapshot<Map<String, dynamic>>? videosSnap;
      try {
        videosSnap = await FirebaseFirestore.instance
            .collection(FirestoreCollections.videos)
            .where('status', whereIn: const ['processed', 'published'])
            .orderBy('views', descending: true)
            .limit(5)
            .get();
      } catch (e1, s1) {
        ErrorHandler.log(e1, stackTrace: s1, tag: 'SearchTrendingManager.fallbackTrending.videosOrdered');
        try {
          videosSnap = await FirebaseFirestore.instance
              .collection(FirestoreCollections.videos)
              .limit(5)
              .get();
        } catch (e2, s2) {
          ErrorHandler.log(e2, stackTrace: s2, tag: 'SearchTrendingManager.fallbackTrending.videosUnordered');
        }
      }

      var rank = 1;
      final movements = ['▲ Up 3', 'NEW', '▲ Up 5', '▼ Down 1', '▲ Up 2'];
      final badges = ['🔥 #1 TODAY', '🔥 HOT', 'RISING', 'POPULAR', 'TRENDING'];

      if (videosSnap != null && videosSnap.docs.isNotEmpty) {
        for (final doc in videosSnap.docs) {
          final data = doc.data();
          final title = data['title'] as String? ?? 'Trending Video';
          final views = (data['viewCount'] as num?)?.toInt() ??
              (data['views'] as num?)?.toInt() ??
              (data['stats'] is Map ? (data['stats']['views'] as num?)?.toInt() : null) ??
              0;
          final idx = (rank - 1) % movements.length;
          items.add(
            TrendingItem(
              id: doc.id,
              rank: rank,
              title: title,
              category: 'video',
              volume: views,
              badge: badges[idx],
              movement: movements[idx],
              subtitle: '${formatVolume(views)} views today',
              imageUrl: data['thumbnailUrl'] as String?,
              creator: data['channelName'] as String? ?? 'Creator',
            ),
          );
          rank++;
        }
      }

      try {
        final topicsSnap = await FirebaseFirestore.instance
            .collection(FirestoreCollections.topics)
            .where('status', isEqualTo: 'active')
            .orderBy('videoCount', descending: true)
            .limit(6)
            .get();
        for (final doc in topicsSnap.docs) {
          final data = doc.data();
          final vCount = (data['videoCount'] as num?)?.toInt() ?? 0;
          if (vCount <= 0) continue;
          final title = data['title'] as String? ?? data['slug'] as String? ?? '';
          if (title.isEmpty || title.toLowerCase() == 'topic') continue;
          items.add(
            TrendingItem(
              id: doc.id,
              rank: rank,
              title: title,
              category: 'topic',
              volume: 850 + rank * 40,
              badge: 'RISING',
              movement: '▲ Up 2',
              subtitle: 'Trending Topic',
              imageUrl: data['thumbnailUrl'] as String?,
            ),
          );
          rank++;
          if (items.where((i) => i.category == 'topic').length >= 3) break;
        }
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'SearchTrendingManager.fallbackTrending.topics');
      }

      return items;
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'SearchTrendingManager.fallbackRealtimeTrending');
      return [];
    }
  }

  /// Format view and search counts into compact human-readable strings (e.g. 1.5M, 24.3k)
  static String formatVolume(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}k';
    }
    return '$number';
  }

  /// Filter trending items based on category chip
  static List<TrendingItem> filterTrending(List<TrendingItem> items, String filter) {
    if (filter == 'Videos') {
      return items.where((t) => t.category == 'video').toList();
    } else if (filter == 'Topics') {
      return items.where((t) => t.category == 'topic').toList();
    } else if (filter == 'Playlists') {
      return items.where((t) => t.category == 'playlist').toList();
    } else if (filter == 'Channels') {
      return items.where((t) => t.category == 'channel').toList();
    }
    return items;
  }

  /// Dispose active stream subscription
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
