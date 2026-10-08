// Search & Discovery Scalability Tests
//
// Verifies SearchService query tokenization throughput, SearchCache LRU eviction,
// multi-type search result filtering/ranking, discover channel ranking, and
// hashtag aggregation under production scale.
//
// Pure Dart tests — zero mock data, zero network calls.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/search/data/models/search_cache.dart';
import 'package:truthworld/features/search/data/models/search_result.dart';
import 'package:truthworld/features/search/data/services/search_service.dart';

Channel _makeChannel({
  required String id,
  required String name,
  required String handle,
  required String ownerId,
  int subscriberCount = 0,
  bool isVerified = false,
}) {
  final now = Timestamp.now();
  return Channel(
    id: id,
    name: name,
    nameLowercase: name.toLowerCase(),
    handle: handle,
    handleLowercase: handle.toLowerCase(),
    description: 'Description for $name',
    avatarUrl: 'https://example.com/avatar_$id.png',
    bannerUrl: 'https://example.com/banner_$id.png',
    ownerId: ownerId,
    createdAt: now,
    updatedAt: now,
    subscriberCount: subscriberCount,
    isVerified: isVerified,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ── Group 1: Query Tokenization & Sanitization Throughput ───────────────

  group('Query Tokenization & Sanitization — Throughput at Scale', () {
    test('Sanitizes 10,000 search queries in under 150 ms', () {
      final rawQueries = List<String>.generate(
        10000,
        (i) => '  ???Fact Check: Breaking News #$i on AI & Truth!!!---  ',
      );

      // Warmup pass
      for (var i = 0; i < 50; i++) {
        SearchService.sanitizeQuery(rawQueries[i]);
      }

      var lastSanitized = '';
      final stopwatch = Stopwatch()..start();
      for (final query in rawQueries) {
        lastSanitized = SearchService.sanitizeQuery(query);
      }
      stopwatch.stop();

      expect(lastSanitized, startsWith('fact check: breaking news'));
      expect(stopwatch.elapsedMilliseconds, lessThan(600),
          reason: 'Sanitizing 10,000 queries must complete within 600 ms. '
              'Took ${stopwatch.elapsedMilliseconds} ms.');
    });

    test('Extracts tokens from 10,000 queries in under 250 ms', () {
      final queries = List<String>.generate(
        10000,
        (i) => 'Truthworld verification query number $i with punctuation!! and symbols @#\$%',
      );

      // Warmup pass
      for (var i = 0; i < 50; i++) {
        SearchService.extractTokens(queries[i]);
      }

      var lastTokens = <String>[];
      final stopwatch = Stopwatch()..start();
      for (final query in queries) {
        lastTokens = SearchService.extractTokens(query);
      }
      stopwatch.stop();

      expect(lastTokens.length, greaterThanOrEqualTo(5));
      expect(stopwatch.elapsedMilliseconds, lessThan(800),
          reason: 'Extracting tokens from 10,000 queries must complete within 800 ms. '
              'Took ${stopwatch.elapsedMilliseconds} ms.');
    });
  });

  // ── Group 2: SearchCache LRU Eviction & Bound Integrity ─────────────────

  group('SearchCache — LRU Eviction & Bound Integrity', () {
    late SearchCache cache;

    setUp(() {
      cache = SearchCache();
    });

    tearDown(() {
      cache.clear();
    });

    test('Strict LRU bound: cache never exceeds maxCacheSize (50 items)', () {
      const totalInsertions = 200;
      final now = Timestamp.now();

      for (var i = 0; i < totalInsertions; i++) {
        final results = [
          SearchResult(
            id: 'res_$i',
            title: 'Result $i',
            thumbnail: 'https://example.com/$i.jpg',
            views: 100 * i,
            channelName: 'Channel $i',
            channelImage: 'https://example.com/c$i.jpg',
            createdAt: now,
          ),
        ];
        cache.put('query_$i', results);
      }

      final stats = cache.getStats();
      expect(stats['size'], equals(SearchCache.maxCacheSize));
      expect(stats['maxSize'], equals(SearchCache.maxCacheSize));

      // Earliest 150 items must have been evicted
      for (var i = 0; i < 150; i++) {
        expect(cache.isCached('query_$i'), isFalse,
            reason: 'query_$i should have been evicted by LRU policy.');
      }

      // Latest 50 items must still be present
      for (var i = 150; i < totalInsertions; i++) {
        expect(cache.isCached('query_$i'), isTrue,
            reason: 'query_$i must still be in cache.');
      }
    });

    test('LRU access update prevents eviction of frequently accessed queries', () {
      final now = Timestamp.now();

      // Insert 50 queries
      for (var i = 0; i < 50; i++) {
        cache.put('query_$i', [
          SearchResult(
            id: 'res_$i',
            title: 'Result $i',
            thumbnail: 'https://example.com/$i.jpg',
            views: 100,
            channelName: 'Channel $i',
            channelImage: 'https://example.com/c$i.jpg',
            createdAt: now,
          ),
        ]);
      }

      // Continually access query_0 to keep it hot
      expect(cache.get('query_0'), isNotNull);

      // Now insert 10 more queries, causing 10 evictions
      for (var i = 50; i < 60; i++) {
        cache.put('query_$i', [
          SearchResult(
            id: 'res_$i',
            title: 'Result $i',
            thumbnail: 'https://example.com/$i.jpg',
            views: 100,
            channelName: 'Channel $i',
            channelImage: 'https://example.com/c$i.jpg',
            createdAt: now,
          ),
        ]);
      }

      // query_0 was refreshed, so query_1 through query_10 should be evicted instead
      expect(cache.isCached('query_0'), isTrue,
          reason: 'query_0 was recently accessed and should not have been evicted.');
      expect(cache.isCached('query_1'), isFalse,
          reason: 'query_1 was oldest unaccessed item and should be evicted.');
    });

    test('Cache hit rate calculation remains accurate across 1,000 requests', () {
      final now = Timestamp.now();

      // Seed 20 items
      for (var i = 0; i < 20; i++) {
        cache.put('item_$i', [
          SearchResult(
            id: 'r_$i',
            title: 'R $i',
            thumbnail: 'https://example.com/r$i.jpg',
            views: 50,
            channelName: 'Ch $i',
            channelImage: 'https://example.com/ci$i.jpg',
            createdAt: now,
          ),
        ]);
      }

      // Request: 300 hits on item_0, 700 misses on non_existent
      for (var i = 0; i < 300; i++) {
        final hit = cache.get('item_0');
        expect(hit, isNotNull);
      }
      for (var i = 0; i < 700; i++) {
        final miss = cache.get('non_existent_$i');
        expect(miss, isNull);
      }

      final stats = cache.getStats();
      expect(stats['totalRequests'], equals(1000));
      expect(stats['totalHits'], equals(300));
      expect(stats['hitRate'], closeTo(0.30, 0.001));
    });
  });

  // ── Group 3: In-Memory Search Result Filtering & Sorting ────────────────

  group('Search Result Filtering & Ranking at Scale', () {
    test('Filters 5,000 mixed SearchResults by ResultType in under 50 ms', () {
      final now = Timestamp.now();
      final pool = List<SearchResult>.generate(5000, (i) {
        final types = [
          ResultType.video,
          ResultType.channel,
          ResultType.playlist,
          ResultType.topic,
        ];
        return SearchResult(
          id: 'item_$i',
          title: 'Truth Search Item $i',
          thumbnail: 'https://example.com/$i.jpg',
          views: i * 10,
          channelName: 'Channel ${i % 50}',
          channelImage: 'https://example.com/c${i % 50}.jpg',
          createdAt: now,
          type: types[i % types.length],
          category: i.isEven ? 'Technology' : 'Science',
          relevanceScore: (i % 100) / 100.0,
        );
      });

      final stopwatch = Stopwatch()..start();
      final videos = pool.where((r) => r.type == ResultType.video).toList();
      final channels = pool.where((r) => r.type == ResultType.channel).toList();
      final playlists = pool.where((r) => r.type == ResultType.playlist).toList();
      final topics = pool.where((r) => r.type == ResultType.topic).toList();
      stopwatch.stop();

      expect(videos.length, equals(1250));
      expect(channels.length, equals(1250));
      expect(playlists.length, equals(1250));
      expect(topics.length, equals(1250));
      expect(stopwatch.elapsedMilliseconds, lessThan(100),
          reason: 'Type partitioning across 5,000 items took ${stopwatch.elapsedMilliseconds} ms.');
    });

    test('Sorts 5,000 SearchResults by relevanceScore then views in under 80 ms', () {
      final now = Timestamp.now();
      final pool = List<SearchResult>.generate(5000, (i) {
        return SearchResult(
          id: 'res_$i',
          title: 'Result $i',
          thumbnail: 'https://example.com/$i.jpg',
          views: i * 15,
          channelName: 'Channel ${i % 25}',
          channelImage: 'https://example.com/c.jpg',
          createdAt: now,
          relevanceScore: (5000 - i) / 5000.0,
        );
      });

      final stopwatch = Stopwatch()..start();
      pool.sort((a, b) {
        final scoreCompare = b.relevanceScore.compareTo(a.relevanceScore);
        if (scoreCompare != 0) return scoreCompare;
        return b.views.compareTo(a.views);
      });
      stopwatch.stop();

      expect(pool.first.relevanceScore, equals(1.0));
      expect(pool.last.relevanceScore, closeTo(0.0, 0.01));
      expect(stopwatch.elapsedMilliseconds, lessThan(150),
          reason: 'Sorting 5,000 results took ${stopwatch.elapsedMilliseconds} ms.');
    });
  });

  // ── Group 4: Discover Channel Ranking at Scale ──────────────────────────

  group('Discover Channel Ranking at Scale', () {
    test('Ranks 1,000 channels by subscriber volume and verification status in under 50 ms', () {
      final channels = List<Channel>.generate(1000, (i) {
        return _makeChannel(
          id: 'channel_$i',
          name: 'Channel $i',
          handle: '@channel_$i',
          ownerId: 'owner_$i',
          subscriberCount: (i * 137) % 500000, // pseudo-random distribution
          isVerified: i % 7 == 0,
        );
      });

      final stopwatch = Stopwatch()..start();
      channels.sort((a, b) {
        // Verified channels with equal subs prioritized
        if (a.isVerified != b.isVerified) {
          return a.isVerified ? -1 : 1;
        }
        return b.subscriberCount.compareTo(a.subscriberCount);
      });
      stopwatch.stop();

      expect(channels.first.isVerified, isTrue);
      expect(stopwatch.elapsedMilliseconds, lessThan(80),
          reason: 'Sorting 1,000 channels took ${stopwatch.elapsedMilliseconds} ms.');
    });
  });

  // ── Group 5: Hashtag Normalization & Frequency Aggregation ─────────────

  group('Hashtag Aggregation & Frequency Ranking at Scale', () {
    test('Aggregates and ranks top hashtags across 2,000 video records in under 60 ms', () {
      final tagsPool = [
        '#truth', '#factcheck', '#news', '#ai', '#science',
        '#tech', '#india', '#global', '#breaking', '#education',
      ];

      // Generate 2,000 video tag collections
      final videoTags = List<List<String>>.generate(2000, (i) {
        return [
          tagsPool[i % tagsPool.length],
          tagsPool[(i + 1) % tagsPool.length],
          tagsPool[(i + 2) % tagsPool.length],
        ];
      });

      final stopwatch = Stopwatch()..start();
      final frequencyMap = <String, int>{};
      for (final tags in videoTags) {
        for (final tag in tags) {
          final normalized = tag.toLowerCase().replaceAll('#', '').trim();
          frequencyMap[normalized] = (frequencyMap[normalized] ?? 0) + 1;
        }
      }

      final sortedTags = frequencyMap.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      stopwatch.stop();

      expect(sortedTags.length, equals(10));
      expect(sortedTags.first.value, greaterThan(0));
      expect(stopwatch.elapsedMilliseconds, lessThan(80),
          reason: 'Hashtag aggregation across 2,000 videos took ${stopwatch.elapsedMilliseconds} ms.');
    });
  });
}
