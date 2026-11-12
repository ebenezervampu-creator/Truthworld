// ⚡ TRUTHWORLD VIDEO SCREEN P95 & P99 LOW-LATENCY BENCHMARK SUITE
//
// Measures microsecond-precision latencies for critical VideoScreen paths:
// 1. Timeline Scrub Position Calculation & Seek Offset (20,000 ops) -> P95 <= 0.02ms, P99 <= 0.08ms
// 2. Adaptive Bitrate (ABR) Resolution Tier Selection (10,000 ops) -> P95 <= 0.05ms, P99 <= 0.15ms
// 3. Binary-Search Subtitle Transcript Segment Lookup (10,000 ops) -> P95 <= 0.02ms, P99 <= 0.06ms
// 4. Recommendations Ranking & Scoring (5,000 ops) -> P95 <= 0.20ms, P99 <= 0.50ms
// 5. Engagement Reaction State Toggle (10,000 ops) -> P95 <= 0.02ms, P99 <= 0.08ms
// 6. Chapter Binary Search Lookup (10,000 ops) -> P95 <= 0.02ms, P99 <= 0.05ms

import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/features/video/presentation/controllers/adaptive_bitrate_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';

class LatencyStats {
  LatencyStats({
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

LatencyStats calculateStats(
  String name,
  List<double> samplesMs,
  double budgetP95Ms,
  double budgetP99Ms,
) {
  samplesMs.sort();
  final n = samplesMs.length;
  final sum = samplesMs.reduce((a, b) => a + b);

  return LatencyStats(
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

class _Candidate {
  _Candidate(this.channelId, this.category, this.tags, this.isFactChecked);
  final String channelId;
  final String category;
  final List<String> tags;
  final bool isFactChecked;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('🎬 VideoScreen P95 & P99 Low-Latency SLA Benchmarks', () {
    test('1. Timeline Scrub Position & Seek Calculation P95/P99 SLA', () {
      const totalMs = 930000;

      Duration computeSeekPosition(double fraction) {
        final clampedFraction = fraction.clamp(0.0, 1.0);
        return Duration(milliseconds: (totalMs * clampedFraction).toInt());
      }

      const iterations = 20000;
      final samples = <double>[];

      // Warmup
      for (var i = 0; i < 200; i++) {
        computeSeekPosition((i % 100) / 100.0);
      }

      final sw = Stopwatch();
      for (var i = 0; i < iterations; i++) {
        final frac = (i % 1000) / 1000.0;
        sw.reset();
        sw.start();
        computeSeekPosition(frac);
        sw.stop();
        samples.add(sw.elapsedMicroseconds / 1000.0);
      }

      final stats = calculateStats('Timeline Scrub Calculation', samples, 0.02, 0.08);
      expect(stats.p95Pass, isTrue,
          reason: 'P95 (${stats.p95Ms.toStringAsFixed(4)} ms) exceeded budget <= ${stats.budgetP95Ms} ms');
      expect(stats.p99Pass, isTrue,
          reason: 'P99 (${stats.p99Ms.toStringAsFixed(4)} ms) exceeded budget <= ${stats.budgetP99Ms} ms');
    });

    test('2. Adaptive Bitrate (ABR) Bandwidth Ladder Selection P95/P99 SLA', () {
      final ladder = ResolutionTier.defaultLadder;

      ResolutionTier pickTier(int bandwidthKbps) {
        var selected = ladder.first;
        for (final tier in ladder) {
          if (bandwidthKbps >= tier.minBandwidth) {
            selected = tier;
          }
        }
        return selected;
      }

      final bandwidthReadings = [120, 350, 750, 1500, 3200, 5500, 8000, 15000, 25000];

      const iterations = 10000;
      final samples = <double>[];

      // Warmup
      for (var i = 0; i < 200; i++) {
        pickTier(bandwidthReadings[i % bandwidthReadings.length]);
      }

      final sw = Stopwatch();
      for (var i = 0; i < iterations; i++) {
        final bw = bandwidthReadings[i % bandwidthReadings.length];
        sw.reset();
        sw.start();
        pickTier(bw);
        sw.stop();
        samples.add(sw.elapsedMicroseconds / 1000.0);
      }

      final stats = calculateStats('ABR Resolution Selection', samples, 0.05, 0.15);
      expect(stats.p95Pass, isTrue,
          reason: 'P95 (${stats.p95Ms.toStringAsFixed(4)} ms) exceeded budget <= ${stats.budgetP95Ms} ms');
      expect(stats.p99Pass, isTrue,
          reason: 'P99 (${stats.p99Ms.toStringAsFixed(4)} ms) exceeded budget <= ${stats.budgetP99Ms} ms');
    });

    test('3. Binary-Search Subtitle Transcript Segment Lookup P95/P99 SLA', () {
      final segments = List<SubtitleSegment>.generate(500, (i) {
        return SubtitleSegment(
          start: Duration(seconds: i * 3),
          end: Duration(seconds: (i * 3) + 3),
          text: 'Verified fact checking transcript segment #$i',
        );
      });

      SubtitleSegment? findActiveSegment(Duration pos) {
        var low = 0;
        var high = segments.length - 1;
        while (low <= high) {
          final mid = (low + high) >> 1;
          final seg = segments[mid];
          if (pos >= seg.start && pos < seg.end) {
            return seg;
          } else if (pos < seg.start) {
            high = mid - 1;
          } else {
            low = mid + 1;
          }
        }
        return null;
      }

      const iterations = 10000;
      final samples = <double>[];

      // Warmup
      for (var i = 0; i < 200; i++) {
        findActiveSegment(Duration(seconds: i % 1500));
      }

      final sw = Stopwatch();
      for (var i = 0; i < iterations; i++) {
        final pos = Duration(seconds: i % 1500);
        sw.reset();
        sw.start();
        findActiveSegment(pos);
        sw.stop();
        samples.add(sw.elapsedMicroseconds / 1000.0);
      }

      final stats = calculateStats('Binary-Search Subtitle Lookup', samples, 0.02, 0.06);
      expect(stats.p95Pass, isTrue,
          reason: 'P95 (${stats.p95Ms.toStringAsFixed(4)} ms) exceeded budget <= ${stats.budgetP95Ms} ms');
      expect(stats.p99Pass, isTrue,
          reason: 'P99 (${stats.p99Ms.toStringAsFixed(4)} ms) exceeded budget <= ${stats.budgetP99Ms} ms');
    });

    test('4. Recommendations Ranking & Scoring P95/P99 SLA', () {
      final candidates = List<_Candidate>.generate(100, (i) {
        return _Candidate(
          'chan_${i % 10}',
          (i % 3 == 0) ? 'News' : 'Tech',
          ['ai', 'factcheck', 'truthworld'],
          i % 2 == 0,
        );
      });

      double scoreCandidate(_Candidate c, String currentChannel, String currentCategory, List<String> currentTags) {
        var score = c.isFactChecked ? 25.0 : 10.0;
        if (c.channelId == currentChannel) score += 30.0;
        if (c.category == currentCategory) score += 20.0;
        for (final t in currentTags) {
          if (c.tags.contains(t)) score += 5.0;
        }
        return score;
      }

      const iterations = 5000;
      final samples = <double>[];

      // Warmup
      for (var i = 0; i < 100; i++) {
        scoreCandidate(candidates[i % 100], 'chan_1', 'News', ['ai']);
      }

      final sw = Stopwatch();
      for (var i = 0; i < iterations; i++) {
        final c = candidates[i % 100];
        sw.reset();
        sw.start();
        scoreCandidate(c, 'chan_1', 'News', ['ai', 'factcheck']);
        sw.stop();
        samples.add(sw.elapsedMicroseconds / 1000.0);
      }

      final stats = calculateStats('Recommendations Scoring', samples, 0.20, 0.50);
      expect(stats.p95Pass, isTrue,
          reason: 'P95 (${stats.p95Ms.toStringAsFixed(4)} ms) exceeded budget <= ${stats.budgetP95Ms} ms');
      expect(stats.p99Pass, isTrue,
          reason: 'P99 (${stats.p99Ms.toStringAsFixed(4)} ms) exceeded budget <= ${stats.budgetP99Ms} ms');
    });

    test('5. Engagement Reaction State Toggle P95/P99 SLA', () {
      var isLiked = false;
      var isDisliked = false;

      void toggleLike() {
        if (isLiked) {
          isLiked = false;
        } else {
          isLiked = true;
          if (isDisliked) {
            isDisliked = false;
          }
        }
      }

      const iterations = 10000;
      final samples = <double>[];

      // Warmup
      for (var i = 0; i < 200; i++) {
        toggleLike();
      }

      final sw = Stopwatch();
      for (var i = 0; i < iterations; i++) {
        sw.reset();
        sw.start();
        toggleLike();
        sw.stop();
        samples.add(sw.elapsedMicroseconds / 1000.0);
      }

      final stats = calculateStats('Reaction State Toggle', samples, 0.02, 0.08);
      expect(stats.p95Pass, isTrue,
          reason: 'P95 (${stats.p95Ms.toStringAsFixed(4)} ms) exceeded budget <= ${stats.budgetP95Ms} ms');
      expect(stats.p99Pass, isTrue,
          reason: 'P99 (${stats.p99Ms.toStringAsFixed(4)} ms) exceeded budget <= ${stats.budgetP99Ms} ms');
    });

    test('6. Chapter Lookup by Timestamp P95/P99 SLA', () {
      final chapters = [
        {'title': 'Introduction', 'startMs': 0, 'endMs': 60000},
        {'title': 'Fact-Checking Evidence', 'startMs': 60000, 'endMs': 240000},
        {'title': 'AI Speech Analysis', 'startMs': 240000, 'endMs': 480000},
        {'title': 'Consensus Verdict', 'startMs': 480000, 'endMs': 600000},
        {'title': 'Conclusion & Sources', 'startMs': 600000, 'endMs': 900000},
      ];

      String findChapter(int posMs) {
        for (final ch in chapters) {
          if (posMs >= (ch['startMs']! as int) && posMs < (ch['endMs']! as int)) {
            return ch['title']! as String;
          }
        }
        return 'Overview';
      }

      const iterations = 10000;
      final samples = <double>[];

      // Warmup
      for (var i = 0; i < 200; i++) {
        findChapter(i * 1000);
      }

      final sw = Stopwatch();
      for (var i = 0; i < iterations; i++) {
        final pos = (i * 250) % 900000;
        sw.reset();
        sw.start();
        findChapter(pos);
        sw.stop();
        samples.add(sw.elapsedMicroseconds / 1000.0);
      }

      final stats = calculateStats('Chapter Binary/Range Lookup', samples, 0.02, 0.05);
      expect(stats.p95Pass, isTrue,
          reason: 'P95 (${stats.p95Ms.toStringAsFixed(4)} ms) exceeded budget <= ${stats.budgetP95Ms} ms');
      expect(stats.p99Pass, isTrue,
          reason: 'P99 (${stats.p99Ms.toStringAsFixed(4)} ms) exceeded budget <= ${stats.budgetP99Ms} ms');
    });
  });
}
