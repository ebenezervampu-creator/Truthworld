import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/services/video_sanitizer.dart';
import 'package:truthworld/core/services/video_visibility_policy.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/downloadcontroller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Content Moderation Rejection & Recommendation Guards', () {
    test('Video with moderation.status "rejected" is marked rejected and not visible for recommendation', () {
      final video = Video.fromMap({
        'title': '2026 World Turning Point',
        'status': 'published',
        'isPublished': true,
        'publishedAt': 1729440000000,
        'moderation': {
          'status': 'rejected',
          'policyReason': 'Content rejected — policy violation detected',
        },
        'videoUrl': 'https://firebasestorage.googleapis.com/.../video.mp4',
        'thumbnailUrl': 'https://firebasestorage.googleapis.com/.../thumb.jpg',
        'ownerId': 'user_123',
        'channelId': 'chan_123',
        'visibility': 'public',
      }, 'vid_rejected_1');

      expect(video.status, equals(VideoStatus.rejected));
      expect(video.isRejected, isTrue);
      expect(video.isApprovedByGeminiOrManual, isFalse);
      expect(VideoVisibilityPolicy.isValidVideo(video), isFalse);
      expect(VideoVisibilityPolicy.isVisibleForRecommendation(video), isFalse);
    });

    test('Video with policyAction "reject" or "block" is marked rejected', () {
      final videoBlock = Video.fromMap({
        'title': 'Contraband Instructions',
        'status': 'ready',
        'moderation': {
          'policyAction': 'block',
          'reason': 'Hazardous material instructions',
        },
        'videoUrl': 'https://firebasestorage.googleapis.com/.../video.mp4',
        'thumbnailUrl': 'https://firebasestorage.googleapis.com/.../thumb.jpg',
      }, 'vid_block');

      expect(videoBlock.status, equals(VideoStatus.rejected));
      expect(videoBlock.isRejected, isTrue);
      expect(videoBlock.isApprovedByGeminiOrManual, isFalse);
      expect(VideoVisibilityPolicy.isValidVideo(videoBlock), isFalse);
      expect(VideoVisibilityPolicy.isVisibleForRecommendation(videoBlock), isFalse);
    });

    test('Video with stages.moderation.status "failed" is marked rejected', () {
      final videoStageFailed = Video.fromMap({
        'title': 'Dangerous Activities',
        'status': 'published',
        'stages': {
          'moderation': {
            'status': 'failed',
            'reason': 'Violent extremism',
          },
        },
        'videoUrl': 'https://firebasestorage.googleapis.com/.../video.mp4',
        'thumbnailUrl': 'https://firebasestorage.googleapis.com/.../thumb.jpg',
      }, 'vid_stage_failed');

      expect(videoStageFailed.status, equals(VideoStatus.rejected));
      expect(videoStageFailed.isRejected, isTrue);
      expect(videoStageFailed.isApprovedByGeminiOrManual, isFalse);
      expect(VideoVisibilityPolicy.isValidVideo(videoStageFailed), isFalse);
      expect(VideoVisibilityPolicy.isVisibleForRecommendation(videoStageFailed), isFalse);
    });

    test('Video with rejectionReason is marked rejected', () {
      final videoRejectionReason = Video.fromMap({
        'title': 'Violating Content',
        'status': 'published',
        'rejectionReason': 'Severe safety policy breach',
        'videoUrl': 'https://firebasestorage.googleapis.com/.../video.mp4',
        'thumbnailUrl': 'https://firebasestorage.googleapis.com/.../thumb.jpg',
      }, 'vid_reason');

      expect(videoRejectionReason.status, equals(VideoStatus.rejected));
      expect(videoRejectionReason.isRejected, isTrue);
      expect(videoRejectionReason.isApprovedByGeminiOrManual, isFalse);
      expect(VideoVisibilityPolicy.isValidVideo(videoRejectionReason), isFalse);
    });

    test('VideoSanitizer.sanitizeForRecommendation removes all rejected videos', () {
      final validVideo1 = Video.fromMap({
        'title': 'Telugu News Special',
        'status': 'published',
        'isPublished': true,
        'publishedAt': 1729440000000,
        'moderation': {'status': 'approved'},
        'videoUrl': 'https://firebasestorage.googleapis.com/.../video1.mp4',
        'thumbnailUrl': 'https://firebasestorage.googleapis.com/.../thumb1.jpg',
        'visibility': 'public',
      }, 'valid_1');

      final rejectedVideo = Video.fromMap({
        'title': '2026 World Turning Point',
        'status': 'published',
        'isPublished': true,
        'publishedAt': 1729440000000,
        'moderation': {'status': 'rejected'},
        'videoUrl': 'https://firebasestorage.googleapis.com/.../video2.mp4',
        'thumbnailUrl': 'https://firebasestorage.googleapis.com/.../thumb2.jpg',
        'visibility': 'public',
      }, 'rejected_1');

      final validVideo2 = Video.fromMap({
        'title': 'Comedy Skit Telugu',
        'status': 'published',
        'isPublished': true,
        'publishedAt': 1729440000000,
        'moderation': {'status': 'approved'},
        'videoUrl': 'https://firebasestorage.googleapis.com/.../video3.mp4',
        'thumbnailUrl': 'https://firebasestorage.googleapis.com/.../thumb3.jpg',
        'visibility': 'public',
      }, 'valid_2');

      final rawList = [validVideo1, rejectedVideo, validVideo2];
      final sanitized = VideoSanitizer.sanitizeForRecommendation(rawList);

      expect(sanitized.length, equals(2));
      expect(sanitized.map((v) => v.id), containsAll(['valid_1', 'valid_2']));
      expect(sanitized.map((v) => v.id), isNot(contains('rejected_1')));
    });

    test('DownloadsController rejects download of moderation-rejected videos', () async {
      final controller = DownloadsController();

      final rejectedVideo = Video.fromMap({
        'title': 'Rejected Content',
        'status': 'rejected',
        'videoUrl': 'https://firebasestorage.googleapis.com/.../video.mp4',
        'thumbnailUrl': 'https://firebasestorage.googleapis.com/.../thumb.jpg',
      }, 'vid_rej');

      final result = await controller.downloadVideoOffline(video: rejectedVideo);
      expect(result, isFalse);
      expect(controller.activeDownloads.containsKey('vid_rej'), isFalse);
    });

    test('VideoVisibilityPolicy.isMapValid rejects raw map with moderation rejection', () {
      final validMap = {
        'title': 'Valid Public News',
        'status': 'published',
        'isPublished': true,
        'publishedAt': 1729440000000,
        'videoUrl': 'https://firebasestorage.googleapis.com/.../video.mp4',
        'thumbnailUrl': 'https://firebasestorage.googleapis.com/.../thumb.jpg',
        'visibility': 'public',
        'moderation': {'status': 'approved'},
      };
      expect(VideoVisibilityPolicy.isMapValid(validMap), isTrue);

      final rejectedMap = {
        'title': 'Rejected Raw Video',
        'status': 'published',
        'isPublished': true,
        'publishedAt': 1729440000000,
        'videoUrl': 'https://firebasestorage.googleapis.com/.../video.mp4',
        'thumbnailUrl': 'https://firebasestorage.googleapis.com/.../thumb.jpg',
        'visibility': 'public',
        'moderation': {'status': 'rejected'},
      };
      expect(VideoVisibilityPolicy.isMapValid(rejectedMap), isFalse);
    });
  });
}
