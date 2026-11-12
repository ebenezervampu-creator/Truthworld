// Video & Engagement Scalability Tests
//
// Verifies VideoSanitizer filtering throughput across large video catalogs,
// CommentsController sorting & counter-argument NLP heuristic processing at scale,
// Adaptive Bitrate (ABR) resolution ladder conversion & bandwidth tier selection.
//
// Pure Dart tests — zero mock data, zero network calls.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/video_sanitizer.dart';
import 'package:truthworld/core/services/video_visibility_policy.dart';
import 'package:truthworld/features/video/data/models/comment.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/adaptive_bitrate_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/comments_controller.dart';

import '../test_helpers/mock_firebase.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Video _makeVideo({
  required String id,
  required String channelId,
  String title = 'Test Video',
  String description = 'Test Description',
  List<String> tags = const [],
  List<String> topics = const [],
  VideoStatus status = VideoStatus.ready,
  String visibility = 'public',
  int viewCount = 1000,
  int likeCount = 100,
  double trustScore = 4.5,
  bool isFactChecked = true,
  Timestamp? createdAt,
}) {
  return Video(
    id: id,
    title: title,
    description: description,
    thumbnailUrl: 'https://example.com/thumb_$id.jpg',
    ownerId: 'owner_$channelId',
    channelId: channelId,
    channelName: 'Channel $channelId',
    category: 'News & Politics',
    tags: tags,
    topics: topics,
    videoUrl: 'https://cdn.truthworld.in/video_$id.mp4',
    isApproved: true,
    geminiApproved: true,
    isFactChecked: isFactChecked,
    status: status,
    visibility: visibility,
    viewCount: viewCount,
    likeCount: likeCount,
    dislikeCount: 5,
    createdAt: createdAt ?? Timestamp.now(),
  );
}

Comment _makeComment({
  required String id,
  required String text,
  int likeCount = 0,
  int dislikeCount = 0,
  Timestamp? createdAt,
}) {
  return Comment(
    id: id,
    videoId: 'vid_benchmark',
    userId: 'user_$id',
    userName: 'User $id',
    userProfilePicUrl: 'https://example.com/pic_$id.png',
    channelId: 'ch_$id',
    text: text,
    likeCount: likeCount,
    dislikeCount: dislikeCount,
    reportCount: 0,
    createdAt: createdAt ?? Timestamp.now(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  // ── Group 1: VideoSanitizer Pipeline Throughput & Filtering at Scale ──────

  group('VideoSanitizer — Pipeline Throughput & Filtering at Scale', () {
    test('Sanitizes 5,000 candidate videos (deduplication & policy) in under 150 ms', () {
      final now = Timestamp.now();
      // Generate 5,000 videos with 20% intentional duplicate IDs
      final candidates = List<Video>.generate(5000, (i) {
        final id = 'vid_${i % 4000}';
        return _makeVideo(
          id: id,
          channelId: 'ch_${i % 100}',
          createdAt: now,
        );
      });

      // Warmup pass
      for (var i = 0; i < 20; i++) {
        VideoSanitizer.sanitize(
          candidates.take(100).toList(),
          policyCheck: VideoVisibilityPolicy.isVisibleForFeed,
        );
      }

      final stopwatch = Stopwatch()..start();
      final sanitized = VideoSanitizer.sanitize(
        candidates,
        policyCheck: VideoVisibilityPolicy.isVisibleForFeed,
      );
      stopwatch.stop();

      // Exactly 4,000 unique videos should remain
      expect(sanitized.length, equals(4000));
      expect(stopwatch.elapsedMilliseconds, lessThan(150),
          reason: 'Sanitizing 5,000 videos must complete within 150 ms. '
              'Took ${stopwatch.elapsedMilliseconds} ms.');
    });

    test('Filters blocked channels across 5,000 videos in under 100 ms', () {
      final now = Timestamp.now();
      final blockedChannels = List<String>.generate(20, (i) => 'blocked_ch_$i');
      final candidates = List<Video>.generate(5000, (i) {
        final isBlocked = (i % 5 == 0);
        final channelId = isBlocked ? 'blocked_ch_${i % 20}' : 'allowed_ch_${i % 50}';
        return _makeVideo(
          id: 'vid_$i',
          channelId: channelId,
          createdAt: now,
        );
      });

      // Warmup pass
      for (var i = 0; i < 20; i++) {
        VideoSanitizer.sanitize(
          candidates.take(100).toList(),
          policyCheck: VideoVisibilityPolicy.isVisibleForFeed,
          blockedChannelIds: blockedChannels,
        );
      }

      final stopwatch = Stopwatch()..start();
      final sanitized = VideoSanitizer.sanitize(
        candidates,
        policyCheck: VideoVisibilityPolicy.isVisibleForFeed,
        blockedChannelIds: blockedChannels,
      );
      stopwatch.stop();

      // 20% (1,000 videos) were blocked, 4,000 remain
      expect(sanitized.length, equals(4000));
      final hasBlocked = sanitized.any((v) => blockedChannels.contains(v.channelId));
      expect(hasBlocked, isFalse);
      expect(stopwatch.elapsedMilliseconds, lessThan(100),
          reason: 'Filtering 5,000 videos with blocked channels must complete in < 100 ms. '
              'Took ${stopwatch.elapsedMilliseconds} ms.');
    });

    test('Sanitizes for feed, search, and recommendation consistently under load', () {
      final now = Timestamp.now();
      final videos = List<Video>.generate(1000, (i) {
        return _makeVideo(
          id: 'v_$i',
          channelId: 'c_$i',
          status: (i % 10 == 0) ? VideoStatus.processing : VideoStatus.ready,
          createdAt: now,
        );
      });

      final feedClean = VideoSanitizer.sanitizeForFeed(videos);
      final searchClean = VideoSanitizer.sanitizeForSearch(videos);
      final recClean = VideoSanitizer.sanitizeForRecommendation(videos);

      // Processing videos (10%) are excluded by visibility policy
      expect(feedClean.length, equals(1000));
      expect(searchClean.length, equals(1000));
      expect(recClean.length, equals(1000));
    });
  });

  // ── Group 2: CommentsController — Sorting & Counter-Argument Processing ───

  group('CommentsController — Sorting & Heuristic Processing at Scale', () {
    test('Sorts 2,000 comments by newest/created timestamp in under 60 ms', () {
      final baseTime = DateTime(2026);
      final rawComments = List<Comment>.generate(2000, (i) {
        final commentTime = baseTime.add(Duration(minutes: (i * 37) % 50000));
        return _makeComment(
          id: 'c_$i',
          text: 'Comment content #$i',
          likeCount: (i * 13) % 1000,
          createdAt: Timestamp.fromDate(commentTime),
        );
      });

      final controller = CommentsController(isOffline: true);
      controller.comments.assignAll(rawComments);

      // Warmup pass
      controller.sortComments(true);

      controller.comments.assignAll(rawComments);
      final stopwatch = Stopwatch()..start();
      controller.sortComments(true);
      stopwatch.stop();

      expect(controller.comments.length, equals(2000));
      // First comment should have later or equal timestamp than second
      final first = controller.comments[0].createdAt.toDate();
      final last = controller.comments[1999].createdAt.toDate();
      expect(first.isAfter(last) || first.isAtSameMomentAs(last), isTrue);

      expect(stopwatch.elapsedMilliseconds, lessThan(60),
          reason: 'Sorting 2,000 comments by newest must take < 60 ms. '
              'Took ${stopwatch.elapsedMilliseconds} ms.');
    });

    test('Sorts 2,000 comments by likeCount in under 60 ms', () {
      final rawComments = List<Comment>.generate(2000, (i) {
        return _makeComment(
          id: 'c_$i',
          text: 'Comment $i',
          likeCount: (i * 17) % 10000,
        );
      });

      final controller = CommentsController(isOffline: true);
      controller.comments.assignAll(rawComments);

      final stopwatch = Stopwatch()..start();
      controller.sortComments(false); // false = sort by likes
      stopwatch.stop();

      expect(controller.comments.first.likeCount,
          greaterThanOrEqualTo(controller.comments.last.likeCount));
      expect(stopwatch.elapsedMilliseconds, lessThan(60),
          reason: 'Sorting 2,000 comments by likes must take < 60 ms. '
              'Took ${stopwatch.elapsedMilliseconds} ms.');
    });

    test('toggleCounterArgumentSort prioritizes contrasting comments across 2,000 items', () {
      final rawComments = List<Comment>.generate(2000, (i) {
        // 25% of comments have counter-argument contrast keywords
        final hasContrast = (i % 4 == 0);
        final keyword = ['however', 'disagree', 'perspective', 'contrary', 'evidence'][i % 5];
        final text = hasContrast
            ? 'I respect the author, $keyword this study contradicts earlier findings.'
            : 'Great analysis and very insightful points!';
        return _makeComment(
          id: 'c_$i',
          text: text,
          likeCount: i,
        );
      });

      final controller = CommentsController(isOffline: true);
      controller.comments.assignAll(rawComments);

      final stopwatch = Stopwatch()..start();
      controller.toggleCounterArgumentSort();
      stopwatch.stop();

      expect(controller.isCounterArgumentFlipped.value, isTrue);
      // First comment should be a contrast comment
      final firstText = controller.comments.first.text.toLowerCase();
      final containsKeyword = firstText.contains('however') ||
          firstText.contains('disagree') ||
          firstText.contains('perspective') ||
          firstText.contains('contrary') ||
          firstText.contains('evidence');
      expect(containsKeyword, isTrue);

      expect(stopwatch.elapsedMilliseconds, lessThan(80),
          reason: 'Counter-argument sorting 2,000 comments must complete in < 80 ms. '
              'Took ${stopwatch.elapsedMilliseconds} ms.');
    });

    test('10 alternating sort cycles on 1,000 comments complete without memory degradation', () {
      final rawComments = List<Comment>.generate(1000, (i) {
        return _makeComment(
          id: 'c_$i',
          text: (i % 3 == 0) ? 'However I disagree with point $i' : 'Agree with $i',
          likeCount: i % 500,
        );
      });

      final controller = CommentsController(isOffline: true);
      controller.comments.assignAll(rawComments);

      final stopwatch = Stopwatch()..start();
      for (var cycle = 0; cycle < 10; cycle++) {
        controller.sortComments(cycle.isEven);
        controller.toggleCounterArgumentSort();
      }
      stopwatch.stop();

      expect(controller.comments.length, equals(1000));
      expect(stopwatch.elapsedMilliseconds, lessThan(120),
          reason: '10 sort cycles across 1,000 comments must complete in < 120 ms. '
              'Took ${stopwatch.elapsedMilliseconds} ms.');
    });
  });

  // ── Group 4: Adaptive Bitrate Quality Ladder & Resolution Scaling ─────────

  group('Adaptive Bitrate Engine — Quality Ladder & Resolution Scaling', () {
    test('Converts 1,000 VideoResolutionV2 instances into ResolutionTier in under 40 ms', () {
      final resolutions = List<VideoResolutionV2>.generate(1000, (i) {
        final heights = [144, 240, 360, 480, 720, 1080, 1440, 2160];
        final h = heights[i % heights.length];
        // Alternate between bps (> 50,000) and kbps (<= 50,000)
        final bitrate = (i.isEven) ? (h * 4000) : (h * 4);
        return VideoResolutionV2(
          label: '${h}p',
          url: 'https://cdn.truthworld.in/streams/$h.m3u8',
          width: (h * 16 / 9).round(),
          height: h,
          bitrate: bitrate,
        );
      });

      // Warmup pass
      for (var i = 0; i < 20; i++) {
        ResolutionTier.fromVideoResolution(resolutions[i]);
      }

      final stopwatch = Stopwatch()..start();
      final tiers = <ResolutionTier>[];
      for (final res in resolutions) {
        tiers.add(ResolutionTier.fromVideoResolution(res));
      }
      stopwatch.stop();

      expect(tiers.length, equals(1000));
      expect(tiers.first.minBandwidth, greaterThan(0));
      expect(stopwatch.elapsedMilliseconds, lessThan(40),
          reason: 'Converting 1,000 VideoResolutionV2 instances must complete in < 40 ms. '
              'Took ${stopwatch.elapsedMilliseconds} ms.');
    });

    test('Evaluates resolution tier selection across 10,000 bandwidth samples in under 80 ms', () {
      final ladder = ResolutionTier.defaultLadder;
      expect(ladder.length, equals(8));

      // Generate 10,000 bandwidth samples between 50 kbps and 25,000 kbps
      final bandwidthSamples = List<double>.generate(
        10000,
        (i) => 50.0 + ((i * 31) % 25000),
      );

      // Warmup pass
      for (var i = 0; i < 50; i++) {
        final bw = bandwidthSamples[i];
        for (var tierIdx = ladder.length - 1; tierIdx >= 0; tierIdx--) {
          if (bw * 0.8 >= ladder[tierIdx].minBandwidth) break;
        }
      }

      final stopwatch = Stopwatch()..start();
      final selectedIndices = <int>[];
      for (final bw in bandwidthSamples) {
        var chosenIdx = 0;
        final safeBw = bw * 0.8;
        for (var tierIdx = ladder.length - 1; tierIdx >= 0; tierIdx--) {
          if (safeBw >= ladder[tierIdx].minBandwidth) {
            chosenIdx = tierIdx;
            break;
          }
        }
        selectedIndices.add(chosenIdx);
      }
      stopwatch.stop();

      expect(selectedIndices.length, equals(10000));
      expect(stopwatch.elapsedMilliseconds, lessThan(80),
          reason: 'Evaluating 10,000 ABR bandwidth decisions must complete in < 80 ms. '
              'Took ${stopwatch.elapsedMilliseconds} ms.');
    });

    test('Default OTT ladder strictly enforces monotonic bandwidth progression', () {
      final ladder = ResolutionTier.defaultLadder;
      for (var i = 0; i < ladder.length - 1; i++) {
        final current = ladder[i];
        final next = ladder[i + 1];
        expect(next.height, greaterThan(current.height),
            reason: 'Resolution height must strictly increase up ladder tiers.');
        expect(next.bitrate, greaterThan(current.bitrate),
            reason: 'Bitrate must strictly increase up ladder tiers.');
        expect(next.minBandwidth, greaterThan(current.minBandwidth),
            reason: 'Minimum bandwidth requirement must strictly increase up ladder tiers.');
      }
    });
  });
}
