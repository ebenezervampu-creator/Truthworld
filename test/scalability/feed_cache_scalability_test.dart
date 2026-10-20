// Feed Cache Scalability Tests
//
// Verifies FeedCacheManager's pure-logic components at scale:
// - Cache key generation collision resistance across 1,000+ users
// - CacheMetadata TTL expiry correctness and round-trip serialization
// - Category normalization for all known feed types and arbitrary strings
//
// NOTE: Tests that require GetStorage (saveFeedToCache, getValidCachedVideos)
// are covered in integration tests, as GetStorage requires platform initialization.
// This test file focuses on the pure-Dart, platform-free logic.

import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/features/home/data/services/feed_cache_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ── Group 1: Cache Key Generation at Scale ─────────────────────────────

  group('Cache Key Generation — Correctness & Collision Resistance', () {
    test('1,000 unique user IDs produce 1,000 distinct home feed cache keys', () {
      final keys = <String>{};
      for (var i = 0; i < 1000; i++) {
        final key = FeedCacheManager.cacheKeyForCategory('All', userId: 'user_$i');
        keys.add(key);
      }
      expect(keys.length, equals(1000),
          reason: 'Each user must have a unique home feed cache key. '
              'Collision detected in 1,000-user key set.');
    });

    test('5,000 unique user IDs produce 5,000 distinct trending cache keys', () {
      final keys = <String>{};
      for (var i = 0; i < 5000; i++) {
        final key = FeedCacheManager.cacheKeyForCategory('Trending', userId: 'usr_$i');
        keys.add(key);
      }
      expect(keys.length, equals(5000),
          reason: '5,000 users must each get a distinct trending cache key.');
    });

    test('All 7 named feed categories map to their canonical constant keys', () {
      expect(FeedCacheManager.cacheKeyForCategory('All'), equals(FeedCacheManager.keyHomeFeed));
      expect(FeedCacheManager.cacheKeyForCategory('Unexplored'), equals(FeedCacheManager.keyUnexploredFeed));
      expect(FeedCacheManager.cacheKeyForCategory('🧭 Unexplored'), equals(FeedCacheManager.keyUnexploredFeed));
      expect(FeedCacheManager.cacheKeyForCategory('Trending'), equals(FeedCacheManager.keyTrendingFeed));
      expect(FeedCacheManager.cacheKeyForCategory('🔥 Trending'), equals(FeedCacheManager.keyTrendingFeed));
      expect(FeedCacheManager.cacheKeyForCategory('Popular'), equals(FeedCacheManager.keyPopularFeed));
      expect(FeedCacheManager.cacheKeyForCategory('⭐ Popular'), equals(FeedCacheManager.keyPopularFeed));
      expect(FeedCacheManager.cacheKeyForCategory('New'), equals(FeedCacheManager.keyNewFeed));
      expect(FeedCacheManager.cacheKeyForCategory('✨ New'), equals(FeedCacheManager.keyNewFeed));
      expect(FeedCacheManager.cacheKeyForCategory('Flip Coin'), equals(FeedCacheManager.keyFlipCoinFeed));
      expect(FeedCacheManager.cacheKeyForCategory('🪙 Flip Coin'), equals(FeedCacheManager.keyFlipCoinFeed));
      expect(FeedCacheManager.cacheKeyForCategory('Music'), equals(FeedCacheManager.keyMusicFeed));
    });

    test('20 arbitrary category strings produce stable, lowercase, alphanumeric keys', () {
      final categories = [
        'Business & Finance',
        'Health & Wellness',
        'Arts & Culture',
        'Science & Nature',
        'Travel & Lifestyle',
        'Food & Cooking',
        'Short Films',
        'News & Politics',
        'Comedy',
        'Documentary',
        'Self Improvement',
        'Tech Reviews',
        'Philosophy',
        'Geopolitics',
        'Space & Astronomy',
        'Climate',
        'Economics',
        'History',
        'Spirituality',
        'Language Learning',
      ];

      final keys = <String>[];
      for (final cat in categories) {
        final key = FeedCacheManager.cacheKeyForCategory(cat);
        keys.add(key);
        // Must only contain alphanumeric, underscores, lowercase
        expect(RegExp(r'^[a-z0-9_]+$').hasMatch(key), isTrue,
            reason: 'Cache key "$key" for category "$cat" '
                'contains invalid characters.');
      }

      // All 20 keys must be unique (no category collision)
      expect(keys.toSet().length, equals(categories.length),
          reason: 'Two category strings produced identical cache keys.');
    });

    test('Cache key generation is idempotent: same inputs → same key, always', () {
      // Call 100 times with the same args — must produce identical keys
      final firstKey = FeedCacheManager.cacheKeyForCategory(
        'Trending',
        userId: 'user_idempotent_test',
      );

      for (var i = 0; i < 100; i++) {
        final key = FeedCacheManager.cacheKeyForCategory(
          'Trending',
          userId: 'user_idempotent_test',
        );
        expect(key, equals(firstKey),
            reason: 'cacheKeyForCategory must be deterministic — call $i returned a different key.');
      }
    });

    test('User-scoped key always contains the base (non-user) key as a substring', () {
      const userId = 'user_abc123';
      final keyWithUser = FeedCacheManager.cacheKeyForCategory('All', userId: userId);
      final keyWithoutUser = FeedCacheManager.cacheKeyForCategory('All');
      expect(keyWithUser, contains(keyWithoutUser),
          reason: 'User-scoped key must embed the base key for routing clarity.');
      expect(keyWithUser, isNot(equals(keyWithoutUser)),
          reason: 'User-scoped and global keys must be distinct.');
    });

    test(
        'Empty userId produces same result as no userId '
        '(no empty suffix appended)', () {
      final keyNoUser = FeedCacheManager.cacheKeyForCategory('All');
      final keyEmptyUser = FeedCacheManager.cacheKeyForCategory('All', userId: '');
      expect(keyNoUser, equals(keyEmptyUser),
          reason: 'An empty userId must produce the same key as omitting userId entirely.');
    });

    test('100 different category/userId combinations generate in under 10 ms', () {
      // Warm-up pass to prime JIT compiler
      for (var i = 0; i < 20; i++) {
        FeedCacheManager.cacheKeyForCategory(
          'Warmup_$i',
          userId: 'warmup_user_$i',
        );
      }

      final stopwatch = Stopwatch()..start();

      for (var i = 0; i < 100; i++) {
        FeedCacheManager.cacheKeyForCategory(
          'Category_$i',
          userId: 'user_$i',
        );
      }

      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, lessThan(10),
          reason: 'Generating 100 cache keys must complete in under 10 ms. '
              'Took ${stopwatch.elapsedMilliseconds} ms.');
    });

    test('Named feed key constants are unique and non-empty', () {
      final constants = [
        FeedCacheManager.keyHomeFeed,
        FeedCacheManager.keyUnexploredFeed,
        FeedCacheManager.keyTrendingFeed,
        FeedCacheManager.keyPopularFeed,
        FeedCacheManager.keyNewFeed,
        FeedCacheManager.keyFlipCoinFeed,
        FeedCacheManager.keyMusicFeed,
      ];

      for (final key in constants) {
        expect(key, isNotEmpty, reason: 'Cache key constant must not be empty.');
      }

      expect(constants.toSet().length, equals(constants.length),
          reason: 'All 7 feed key constants must be unique.');
    });
  });

  // ── Group 2: Schema Version ─────────────────────────────────────────────

  group('Schema Version Constant', () {
    test('currentSchemaVersion is 3 (gate for cache compatibility checks)', () {
      expect(FeedCacheManager.currentSchemaVersion, equals(3));
    });

    test('defaultTTL is 3 minutes', () {
      expect(FeedCacheManager.defaultTTL, equals(const Duration(minutes: 3)));
    });
  });

  // ── Group 3: CacheMetadata — TTL Expiry & Serialization ────────────────

  group('CacheMetadata — TTL Expiry Logic', () {
    test('isExpired returns false for a future expiresAt', () {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final meta = CacheMetadata(
        cacheType: 'home_feed',
        generatedAt: nowMs,
        expiresAt: nowMs + 180000, // 3 minutes from now
      );
      expect(meta.isExpired, isFalse);
    });

    test('isExpired returns true for a past expiresAt', () {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final meta = CacheMetadata(
        cacheType: 'home_feed',
        generatedAt: nowMs - 300000,
        expiresAt: nowMs - 1, // 1 ms in the past
      );
      expect(meta.isExpired, isTrue);
    });

    test('isExpired = false for expiresAt = now + 1 ms (tight boundary)', () {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final meta = CacheMetadata(
        cacheType: 'home_feed',
        generatedAt: nowMs,
        expiresAt: nowMs + 1,
      );
      expect(meta.isExpired, isFalse,
          reason: 'A cache expiring 1 ms in the future should still be valid.');
    });

    test('CacheMetadata round-trips through toMap/fromMap without data loss', () {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final original = CacheMetadata(
        schemaVersion: FeedCacheManager.currentSchemaVersion,
        cacheType: 'home_feed',
        generatedAt: nowMs,
        expiresAt: nowMs + 180000,
        feedVersion: 2,
        queryHash: 'abc123_test',
      );

      final restored = CacheMetadata.fromMap(original.toMap());

      expect(restored.schemaVersion, equals(original.schemaVersion));
      expect(restored.cacheType, equals(original.cacheType));
      expect(restored.generatedAt, equals(original.generatedAt));
      expect(restored.expiresAt, equals(original.expiresAt));
      expect(restored.feedVersion, equals(original.feedVersion));
      expect(restored.queryHash, equals(original.queryHash));
    });

    test('CacheMetadata.fromMap with missing fields falls back to defaults safely', () {
      // Simulate a partial/corrupt metadata map
      final partial = <String, dynamic>{
        'cacheType': 'home_feed',
        'generatedAt': 1000000,
        'expiresAt': 9999999999999, // far future
        // schemaVersion, feedVersion, queryHash are omitted
      };

      expect(
        () => CacheMetadata.fromMap(partial),
        returnsNormally,
        reason: 'fromMap must not throw on a partial metadata map.',
      );

      final meta = CacheMetadata.fromMap(partial);
      expect(meta.schemaVersion, equals(2), reason: 'Default schemaVersion is 2.');
      expect(meta.feedVersion, equals(1), reason: 'Default feedVersion is 1.');
      expect(meta.queryHash, equals(''), reason: 'Default queryHash is empty string.');
    });

    test('1,000 CacheMetadata round-trips remain consistent under load', () {
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      for (var i = 0; i < 1000; i++) {
        final original = CacheMetadata(
          schemaVersion: FeedCacheManager.currentSchemaVersion,
          cacheType: 'feed_type_$i',
          generatedAt: nowMs + i,
          expiresAt: nowMs + i + 180000,
          feedVersion: i % 5,
          queryHash: 'hash_$i',
        );

        final restored = CacheMetadata.fromMap(original.toMap());
        expect(restored.cacheType, equals(original.cacheType),
            reason: 'Round-trip failed for iteration $i.');
        expect(restored.expiresAt, equals(original.expiresAt),
            reason: 'expiresAt mismatch at iteration $i.');
        expect(restored.queryHash, equals(original.queryHash),
            reason: 'queryHash mismatch at iteration $i.');
      }
    });
  });

  // ── Group 4: Multi-User Key Isolation ──────────────────────────────────

  group('Multi-User Cache Key Isolation', () {
    test(
        '50 users × 7 feed types = 350 unique keys '
        '(no cross-user, cross-category collision)', () {
      final allKeys = <String>{};
      final categories = [
        'All', 'Trending', 'Popular', 'New',
        'Unexplored', 'Flip Coin', 'Music',
      ];

      for (var u = 0; u < 50; u++) {
        for (final cat in categories) {
          final key = FeedCacheManager.cacheKeyForCategory(cat, userId: 'user_$u');
          allKeys.add(key);
        }
      }

      expect(allKeys.length, equals(350),
          reason: '50 users × 7 categories must produce 350 unique cache keys.');
    });

    test(
        'Keys for different users with the same category never collide '
        '(checked across 1,000 user pairs)', () {
      // Spot-check 1,000 pairs of adjacent users
      for (var i = 0; i < 1000; i++) {
        final key1 = FeedCacheManager.cacheKeyForCategory('All', userId: 'user_$i');
        final key2 = FeedCacheManager.cacheKeyForCategory('All', userId: 'user_${i + 1}');
        expect(key1, isNot(equals(key2)),
            reason: 'user_$i and user_${i + 1} must not share a cache key for "All".');
      }
    });
  });
}
