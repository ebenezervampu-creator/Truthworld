import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/services/clip_share_service.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/clip_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Video createTestVideo({
    bool allowClipping = true,
    bool isKidFriendly = false,
    int duration = 120,
  }) {
    return Video(
      id: 'test_vid_1',
      title: 'Test Video',
      description: 'Test Description',
      videoUrl: 'https://example.com/video.mp4',
      thumbnailUrl: 'https://example.com/thumb.jpg',
      ownerId: 'owner_1',
      channelId: 'channel_1',
      channelName: 'Test Channel',
      category: 'Education',
      tags: const ['test'],
      duration: duration,
      vDurationValue: Duration(seconds: duration),
      createdAt: DateTime.now(),
      allowClipping: allowClipping,
      isKidFriendly: isKidFriendly,
    );
  }

  group('Clip Anti-Abuse: Video Eligibility Restrictions', () {
    test('disallows clipping when creator disabled allowClipping', () {
      final video = createTestVideo(allowClipping: false);
      final controller = ClipController(video: video);

      final reason = controller.getClippingRestrictionReason();
      expect(reason, isNotNull);
      expect(reason, contains('creator has disabled clipping'));
    });

    test('disallows clipping when video is Made for Kids (COPPA standard)', () {
      final video = createTestVideo(isKidFriendly: true);
      final controller = ClipController(video: video);

      final reason = controller.getClippingRestrictionReason();
      expect(reason, isNotNull);
      expect(reason, contains('content made for kids'));
    });

    test('disallows clipping when video duration is shorter than 15 seconds', () {
      final video = createTestVideo(duration: 10);
      final controller = ClipController(video: video);

      final reason = controller.getClippingRestrictionReason();
      expect(reason, isNotNull);
      expect(reason, contains('too short'));
    });

    test('allows clipping when video is eligible', () {
      final video = createTestVideo(duration: 180);
      final controller = ClipController(video: video);

      final reason = controller.getClippingRestrictionReason();
      expect(reason, isNull);
    });
  });

  group('Clip Anti-Abuse: Title Moderation via ContentValidator', () {
    final video = createTestVideo();
    late ClipController controller;

    setUp(() {
      controller = ClipController(video: video);
    });

    test('rejects empty or whitespace-only title', () {
      expect(controller.validateClipTitle(''), isNotNull);
      expect(controller.validateClipTitle('   '), isNotNull);
    });

    test('rejects titles shorter than 3 characters', () {
      final result = controller.validateClipTitle('ab');
      expect(result, isNotNull);
      expect(result, contains('at least 3 characters'));
    });

    test('rejects titles longer than 100 characters', () {
      final longTitle = 'a' * 101;
      final result = controller.validateClipTitle(longTitle);
      expect(result, isNotNull);
      expect(result, contains('cannot exceed 100 characters'));
    });

    test('rejects titles with offensive profanity or vulgar language', () {
      final result = controller.validateClipTitle('Watch this fucking clip');
      expect(result, isNotNull);
      expect(result, contains('inappropriate'));
    });

    test('rejects titles with obfuscated profanity / leetspeak', () {
      final result = controller.validateClipTitle('Watch this f.u.c.k clip');
      expect(result, isNotNull);
    });

    test('rejects titles with scam or adult domain patterns', () {
      final scam = controller.validateClipTitle('Free crypto giveaway click here');
      expect(scam, isNotNull);

      final adult = controller.validateClipTitle('Check pornhub highlight');
      expect(adult, isNotNull);
    });

    test('accepts clean, valid clip titles', () {
      expect(controller.validateClipTitle('Epic guitar solo in the verse'), isNull);
      expect(controller.validateClipTitle('Best goal of the season!'), isNull);
    });
  });

  group('Clip Anti-Abuse: Duration Boundary Enforcement', () {
    final video = createTestVideo(duration: 300);
    late ClipController controller;

    setUp(() {
      controller = ClipController(video: video);
    });

    test('enforces industry standard min (5s) and max (30s) duration constants', () {
      expect(controller.minDuration, equals(5.0));
      expect(controller.maxDuration, equals(30.0));
      expect(ClipShareService.minShareDuration, equals(5.0));
      expect(ClipShareService.maxShareDuration, equals(30.0));
    });

    test('updateStart prevents reducing clip duration below 5 seconds', () {
      controller.startSeconds.value = 10.0;
      controller.endSeconds.value = 20.0;

      // Attempt to move start to 18s (would make duration 2s, below 5s min)
      controller.updateStart(18.0);
      expect(controller.startSeconds.value, equals(10.0)); // Unchanged

      // Moving start to 14s (6s duration) is allowed
      controller.updateStart(14.0);
      expect(controller.startSeconds.value, equals(14.0));
    });

    test('updateEnd prevents reducing clip duration below 5 seconds', () {
      controller.startSeconds.value = 10.0;
      controller.endSeconds.value = 25.0;

      // Attempt to move end to 12s (would make duration 2s, below 5s min)
      controller.updateEnd(12.0);
      expect(controller.endSeconds.value, equals(25.0)); // Unchanged

      // Moving end to 18s (8s duration) is allowed
      controller.updateEnd(18.0);
      expect(controller.endSeconds.value, equals(18.0));
    });

    test('updateEnd clamps to maxDuration (30s)', () {
      controller.startSeconds.value = 10.0;
      controller.endSeconds.value = 20.0;

      // Attempt to move end to 50s (would make duration 40s > 30s)
      controller.updateEnd(50.0);
      expect(controller.endSeconds.value, equals(40.0)); // Clamped to start (10) + maxDuration (30)
      expect(controller.endSeconds.value - controller.startSeconds.value, equals(30.0));
    });
  });
}
