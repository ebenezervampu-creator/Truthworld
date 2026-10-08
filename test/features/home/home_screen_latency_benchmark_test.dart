// ⚡ TRUTHWORLD HOME SCREEN P95 & P99 LOW-LATENCY BENCHMARK SUITE
//
// Measures microsecond-precision latencies for core Home Screen operations:
// 1. Category Filter Matching across 1,000 videos (10,000 ops) -> P95 <= 0.10ms, P99 <= 0.30ms
// 2. Feed Pagination & Deduplication (5,000 ops) -> P95 <= 0.20ms, P99 <= 0.50ms
// 3. SWR Cache Metadata Evaluation & Expiry Check (10,000 ops) -> P95 <= 0.05ms, P99 <= 0.15ms
// 4. VideoCard Metric Formatting (10,000 ops) -> P95 <= 0.05ms, P99 <= 0.10ms

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/components/ui/video_card/video_card_formatters.dart';
import 'package:truthworld/features/home/data/services/feed_cache_manager.dart';
import 'package:truthworld/features/video/data/models/video.dart';

class LatencyPercentiles {
  LatencyPercentiles({
    required this.name,
    required this.count,
    required this.minMs,
    required this.meanMs,
    required this.p50Ms,
    required this.p90Ms,
    required this.p95Ms,
    required this.p99Ms,
    required this.maxMs,
    required this.budgetP95Ms,
    required this.budgetP99Ms,
  });

  final String name;
  final int count;
  final double minMs;
  final double meanMs;
  final double p50Ms;
  final double p90Ms;
  final double p95Ms;
  final double p99Ms;
  final double maxMs;
  final double budgetP95Ms;
  final double budgetP99Ms;

  bool get p95Pass => p95Ms <= budgetP95Ms;
  bool get p99Pass => p99Ms <= budgetP99Ms;
}

LatencyPercentiles computePercentiles(
  String name,
  List<double> samplesMs,
  double budgetP95Ms,
  double budgetP99Ms,
) {
  samplesMs.sort();
  final n = samplesMs.length;
  final sum = samplesMs.reduce((a, b) => a + b);

  return LatencyPercentiles(
    name: name,
    count: n,
    minMs: samplesMs.first,
    meanMs: sum / n,
    p50Ms: samplesMs[(n * 0.50).floor()],
    p90Ms: samplesMs[(n * 0.90).floor()],
    p95Ms: samplesMs[(n * 0.95).floor()],
    p99Ms: samplesMs[(n * 0.99).floor()],
    maxMs: samplesMs.last,
    budgetP95Ms: budgetP95Ms,
    budgetP99Ms: budgetP99Ms,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('🏠 Home Screen P95 & P99 Low-Latency SLA Benchmarks', () {
    test('1. Category Matching & Filter Logic P95/P99 SLA', () {
      final now = Timestamp.now();
      final videos = List<Video>.generate(1000, (i) {
        return Video(
          id: 'v_$i',
          title: 'Video Title $i',
          description: 'Description $i',
          thumbnailUrl: 'https://example.com/thumb_$i.jpg',
          ownerId: 'owner_$i',
          channelId: 'ch_$i',
          channelName: 'Channel $i',
          category: (i % 3 == 0) ? 'News & Politics' : (i % 3 == 1) ? 'Technology' : 'Documentary',
          tags: ['news', 'factcheck', 'truthworld'],
          topics: ['journalism', 'tech'],
          videoUrl: 'https://cdn.truthworld.com/v_$i.mp4',
          isApproved: true,
          geminiApproved: true,
          createdAt: now,
        );
      });

      bool matchesCategory(Video v, String category) {
        if (category == 'All') return true;
        final target = category.toLowerCase();
        if (v.category.toLowerCase().contains(target)) return true;
        if (v.tags.any((t) => t.toLowerCase() == target)) return true;
        if (v.topics.any((top) => top.toLowerCase() == target)) return true;
        return false;
      }

      const iterations = 10000;
      final samples = <double>[];

      // Warmup
      for (var i = 0; i < 200; i++) {
        matchesCategory(videos[i % 1000], 'Technology');
      }

      final sw = Stopwatch();
      for (var i = 0; i < iterations; i++) {
        final video = videos[i % 1000];
        sw.reset();
        sw.start();
        matchesCategory(video, 'Technology');
        sw.stop();
        samples.add(sw.elapsedMicroseconds / 1000.0);
      }

      final stats = computePercentiles('HomeScreen Category Matching', samples, 0.10, 0.30);
      expect(stats.p95Pass, isTrue,
          reason: 'P95 latency (${stats.p95Ms.toStringAsFixed(4)} ms) exceeded budget <= ${stats.budgetP95Ms} ms');
      expect(stats.p99Pass, isTrue,
          reason: 'P99 latency (${stats.p99Ms.toStringAsFixed(4)} ms) exceeded budget <= ${stats.budgetP99Ms} ms');
    });

    test('2. Feed Pagination & Deduplication P95/P99 SLA', () {
      final existingIds = <String>{};
      for (var i = 0; i < 500; i++) {
        existingIds.add('vid_existing_$i');
      }

      const iterations = 5000;
      final samples = <double>[];

      List<String> deduplicatePage(List<String> incomingPage, Set<String> existing) {
        final result = <String>[];
        for (final id in incomingPage) {
          if (!existing.contains(id)) {
            result.add(id);
          }
        }
        return result;
      }

      final incomingBatch = List<String>.generate(24, (i) => (i % 2 == 0) ? 'vid_existing_$i' : 'vid_new_$i');

      // Warmup
      for (var i = 0; i < 100; i++) {
        deduplicatePage(incomingBatch, existingIds);
      }

      final sw = Stopwatch();
      for (var i = 0; i < iterations; i++) {
        sw.reset();
        sw.start();
        deduplicatePage(incomingBatch, existingIds);
        sw.stop();
        samples.add(sw.elapsedMicroseconds / 1000.0);
      }

      final stats = computePercentiles('HomeScreen Feed Deduplication', samples, 0.20, 0.50);
      expect(stats.p95Pass, isTrue,
          reason: 'P95 latency (${stats.p95Ms.toStringAsFixed(4)} ms) exceeded budget <= ${stats.budgetP95Ms} ms');
      expect(stats.p99Pass, isTrue,
          reason: 'P99 latency (${stats.p99Ms.toStringAsFixed(4)} ms) exceeded budget <= ${stats.budgetP99Ms} ms');
    });

    test('3. SWR Cache Metadata Evaluation P95/P99 SLA', () {
      final meta = CacheMetadata(
        cacheType: 'home_feed',
        generatedAt: DateTime.now().subtract(const Duration(minutes: 1)).millisecondsSinceEpoch,
        expiresAt: DateTime.now().add(const Duration(minutes: 2)).millisecondsSinceEpoch,
      );

      const iterations = 10000;
      final samples = <double>[];

      // Warmup
      for (var i = 0; i < 200; i++) {
        meta.isExpired;
      }

      final sw = Stopwatch();
      for (var i = 0; i < iterations; i++) {
        sw.reset();
        sw.start();
        final _ = meta.isExpired;
        sw.stop();
        samples.add(sw.elapsedMicroseconds / 1000.0);
      }

      final stats = computePercentiles('HomeScreen SWR Cache Evaluation', samples, 0.05, 0.15);
      expect(stats.p95Pass, isTrue,
          reason: 'P95 latency (${stats.p95Ms.toStringAsFixed(4)} ms) exceeded budget <= ${stats.budgetP95Ms} ms');
      expect(stats.p99Pass, isTrue,
          reason: 'P99 latency (${stats.p99Ms.toStringAsFixed(4)} ms) exceeded budget <= ${stats.budgetP99Ms} ms');
    });

    test('4. VideoCard Metric Formatting P95/P99 SLA', () {
      final testCounts = [0, 42, 999, 1200, 15000, 250000, 1200000, 85000000];

      const iterations = 10000;
      final samples = <double>[];

      // Warmup
      for (var i = 0; i < 200; i++) {
        VideoCardFormatters.formatViews(testCounts[i % testCounts.length]);
      }

      final sw = Stopwatch();
      for (var i = 0; i < iterations; i++) {
        final count = testCounts[i % testCounts.length];
        sw.reset();
        sw.start();
        VideoCardFormatters.formatViews(count);
        sw.stop();
        samples.add(sw.elapsedMicroseconds / 1000.0);
      }

      final stats = computePercentiles('HomeScreen VideoCard Formatting', samples, 0.05, 0.10);
      expect(stats.p95Pass, isTrue,
          reason: 'P95 latency (${stats.p95Ms.toStringAsFixed(4)} ms) exceeded budget <= ${stats.budgetP95Ms} ms');
      expect(stats.p99Pass, isTrue,
          reason: 'P99 latency (${stats.p99Ms.toStringAsFixed(4)} ms) exceeded budget <= ${stats.budgetP99Ms} ms');
    });
  });
}
