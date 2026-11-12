import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/features/video/data/models/video.dart';

void main() {
  group('Video Model', () {
    late Map<String, dynamic> validVideoMap;

    setUp(() {
      validVideoMap = {
        'id': 'test-video-123',
        'title': 'Test Video Title',
        'titleLowercase': 'test video title',
        'description': 'A test video description',
        'originalUrl': 'https://storage.example.com/original.mp4',
        'hlsUrl': 'https://storage.example.com/hls/manifest.m3u8',
        'dashUrl': '',
        'thumbnailUrl': 'https://storage.example.com/thumb.jpg',
        'thumbnailVariants': <String>[],
        'animatedPreviewUrl': '',
        'adaptiveResolutions': <Map<String, dynamic>>[],
        'ownerId': 'user-abc',
        'channelId': 'channel-xyz',
        'channelName': 'Test Channel',
        'channelAvatarUrl': 'https://storage.example.com/avatar.jpg',
        'viewCount': 1500,
        'views': 1500,
        'likeCount': 100,
        'likes': 100,
        'dislikeCount': 5,
        'dislikes': 5,
        'commentCount': 42,
        'comments': 42,
        'shareCount': 10,
        'shares': 10,
        'totalWatchTimeSeconds': 7200,
        'durationMs': 180000,
        'duration': '3:00',
        'createdAt': Timestamp.fromDate(DateTime(2026, 1, 15)),
        'uploadedAt': Timestamp.fromDate(DateTime(2026, 1, 15)),
        'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 16)),
        'status': 'ready',
        'visibility': 'Public',
        'likedBy': <String>['user-1', 'user-2'],
        'category': 'Education',
        'tags': <String>['flutter', 'dart'],
        'topics': <String>['programming'],
        'language': 'en',
        'isShort': false,
        'isKidFriendly': true,
        'enableComments': true,
        'isMonetized': false,
        'allowRatings': true,
      };
    });

    test('creates Video from map with all fields populated', () {
      final video = Video.fromMap(validVideoMap, 'test-video-123');

      expect(video.id, 'test-video-123');
      expect(video.title, 'Test Video Title');
      expect(video.description, 'A test video description');
      expect(video.ownerId, 'user-abc');
      expect(video.channelId, 'channel-xyz');
      expect(video.channelName, 'Test Channel');
      expect(video.viewCount, 1500);
      expect(video.likeCount, 100);
      expect(video.dislikeCount, 5);
      expect(video.commentCount, 42);
      expect(video.category, 'Education');
      expect(video.tags, ['flutter', 'dart']);
      expect(video.isShort, false);
      expect(video.isKidFriendly, true);
      expect(video.enableComments, true);
    });

    test('creates Video from map with missing optional fields', () {
      final minimalMap = {
        'title': 'Minimal Video',
        'ownerId': 'user-abc',
        'channelId': 'channel-xyz',
      };

      final video = Video.fromMap(minimalMap, 'minimal-id');

      expect(video.id, 'minimal-id');
      expect(video.title, 'Minimal Video');
      expect(video.description, '');
      expect(video.viewCount, 0);
      expect(video.likeCount, 0);
      expect(video.tags, isEmpty);
      expect(video.visibility, 'public');
    });

    test('toMap produces serializable output', () {
      final video = Video.fromMap(validVideoMap, 'test-video-123');
      final map = video.toMap();

      expect(map['title'], 'Test Video Title');
      expect(map['ownerId'], 'user-abc');
      expect(map['channelId'], 'channel-xyz');
      expect(map['visibility'], 'Public');
      expect(map, isA<Map<String, dynamic>>());
    });

    test('fromMap then toMap round-trip preserves key fields', () {
      final video = Video.fromMap(validVideoMap, 'test-video-123');
      final map = video.toMap();
      final roundTripped = Video.fromMap(map, 'test-video-123');

      expect(roundTripped.title, video.title);
      expect(roundTripped.ownerId, video.ownerId);
      expect(roundTripped.channelId, video.channelId);
      expect(roundTripped.category, video.category);
      expect(roundTripped.visibility, video.visibility);
    });

    test('compatibility getters work correctly', () {
      final video = Video.fromMap(validVideoMap, 'test-video-123');

      // Compatibility getters
      expect(video.likes, video.likeCount);
      expect(video.views, video.viewCount);
    });

    test('resolvedViewCount correctly resolves positive views when viewCount is 0', () {
      final videoWithViews = Video.fromMap({
        'id': 'v_views_1',
        'title': 'Test Video',
        'viewCount': 0,
        'views': 1,
        'channelId': 'ch1',
        'ownerId': 'u1',
      });
      expect(videoWithViews.views, equals(1));
      expect(videoWithViews.viewCount, equals(1));

      final videoWithViewCount = Video.fromMap({
        'id': 'v_views_2',
        'title': 'Test Video 2',
        'viewCount': 1,
        'views': 0,
        'channelId': 'ch1',
        'ownerId': 'u1',
      });
      expect(videoWithViewCount.views, equals(1));
      expect(videoWithViewCount.viewCount, equals(1));
    });

    test('VideoStatus enum values are correct', () {
      expect(VideoStatus.values.length, greaterThanOrEqualTo(6));
      expect(VideoStatus.values, contains(VideoStatus.ready));
      expect(VideoStatus.values, contains(VideoStatus.processing));
      expect(VideoStatus.values, contains(VideoStatus.deleted));
    });

    test('Video.fromMap maps deletion_pending and trashed to VideoStatus.deleted', () {
      final deletionPendingVideo = Video.fromMap({
        'id': 'v_del_1',
        'title': 'Soft Deleted Video',
        'status': 'deletion_pending',
        'channelId': 'ch1',
        'ownerId': 'u1',
      });
      expect(deletionPendingVideo.status, equals(VideoStatus.deleted));

      final trashedVideo = Video.fromMap({
        'id': 'v_del_2',
        'title': 'Trashed Video',
        'status': 'trashed',
        'channelId': 'ch1',
        'ownerId': 'u1',
      });
      expect(trashedVideo.status, equals(VideoStatus.deleted));
    });

    test('VideoResolutionV2 fromMap/toMap round-trip', () {
      final resMap = {
        'label': '1080p',
        'url': 'https://cdn.example.com/1080p.m3u8',
        'width': 1920,
        'height': 1080,
        'bitrate': 5000000,
      };

      final resolution = VideoResolutionV2.fromMap(resMap);
      expect(resolution.label, '1080p');
      expect(resolution.width, 1920);
      expect(resolution.height, 1080);

      final serialized = resolution.toMap();
      expect(serialized['label'], '1080p');
      expect(serialized['width'], 1920);
    });

    group('Moderation Resubmission Limits', () {
      test('defaults resubmitCount to 0 and allows resubmissions for rejected video', () {
        final map = Map<String, dynamic>.from(validVideoMap)..['status'] = 'rejected';
        final video = Video.fromMap(map, 'test-resubmit-0');
        expect(video.resubmitCount, 0);
        expect(video.isRejected, isTrue);
        expect(video.canResubmit, isTrue);
        expect(video.remainingResubmissions, 2);
        expect(video.hasReachedMaxResubmissions, isFalse);
      });

      test('resubmitCount 1 allows 1 remaining resubmission for rejected video', () {
        final map = Map<String, dynamic>.from(validVideoMap)
          ..['status'] = 'rejected'
          ..['resubmitCount'] = 1;
        final video = Video.fromMap(map, 'test-resubmit-1');
        expect(video.resubmitCount, 1);
        expect(video.isRejected, isTrue);
        expect(video.canResubmit, isTrue);
        expect(video.remainingResubmissions, 1);
        expect(video.hasReachedMaxResubmissions, isFalse);
      });

      test('non-rejected video cannot be resubmitted', () {
        final readyVideo = Video.fromMap(validVideoMap, 'test-ready');
        expect(readyVideo.isRejected, isFalse);
        expect(readyVideo.canResubmit, isFalse);
      });

      test('resubmitCount 2 or greater blocks further resubmissions (max 2 limit)', () {
        final map = Map<String, dynamic>.from(validVideoMap)
          ..['status'] = 'rejected'
          ..['resubmitCount'] = 2;
        final video = Video.fromMap(map, 'test-resubmit-2');
        expect(video.resubmitCount, 2);
        expect(video.canResubmit, isFalse);
        expect(video.remainingResubmissions, 0);
        expect(video.hasReachedMaxResubmissions, isTrue);

        final mapOver = Map<String, dynamic>.from(validVideoMap)
          ..['status'] = 'rejected'
          ..['resubmitCount'] = 3;
        final videoOver = Video.fromMap(mapOver, 'test-resubmit-3');
        expect(videoOver.canResubmit, isFalse);
        expect(videoOver.remainingResubmissions, 0);
        expect(videoOver.hasReachedMaxResubmissions, isTrue);
      });

      test('parses resubmitCount from moderation map if present', () {
        final map = Map<String, dynamic>.from(validVideoMap)
          ..['moderation'] = {'status': 'rejected', 'resubmitCount': 1};
        final video = Video.fromMap(map, 'test-resubmit-mod');
        expect(video.resubmitCount, 1);
        expect(video.remainingResubmissions, 1);
      });

      test('serializes resubmitCount in toMap()', () {
        final map = Map<String, dynamic>.from(validVideoMap)..['resubmitCount'] = 1;
        final video = Video.fromMap(map, 'test-resubmit-ser');
        final output = video.toMap();
        expect(output['resubmitCount'], 1);
      });

      test('isRejected accurately reflects status', () {
        final rejectedVideo = Video.fromMap(
          Map<String, dynamic>.from(validVideoMap)
            ..['status'] = 'rejected',
          'test-rejected',
        );
        expect(rejectedVideo.isRejected, isTrue);

        final pendingVideo = Video.fromMap(
          Map<String, dynamic>.from(validVideoMap)
            ..['status'] = 'pending_review'
            ..['resubmitCount'] = 1,
          'test-pending',
        );
        expect(pendingVideo.isRejected, isFalse);
      });
    });

    group('Non-English Subtitles & Localization Resilience', () {
      test('safely parses object-based subtitles maps without throwing TypeError', () {
        final map = Map<String, dynamic>.from(validVideoMap)
          ..['language'] = 'te'
          ..['subtitles'] = {
            'te': {
              'url': 'https://firebasestorage.googleapis.com/v0/b/truthworld.appspot.com/o/subtitles%2Fjob_123%2Fte.srt?alt=media',
              'format': 'srt',
              'provider': 'google-cloud-speech',
            },
            'hi': {
              'srtPath': 'https://storage.googleapis.com/truthworld/subtitles/job_123/hi.srt',
            },
          };
        final video = Video.fromMap(map, 'test-telugu-subtitles');
        expect(video.mediaSubtitles['te'], contains('te.srt'));
        expect(video.mediaSubtitles['hi'], contains('hi.srt'));
      });

      test('safely parses flat string-based subtitles maps', () {
        final map = Map<String, dynamic>.from(validVideoMap)
          ..['language'] = 'te'
          ..['media'] = {
            'subtitles': {
              'te': 'https://firebasestorage.googleapis.com/v0/b/truthworld.appspot.com/o/subtitles%2Fjob_123%2Fte.srt',
              'en': 'https://firebasestorage.googleapis.com/v0/b/truthworld.appspot.com/o/subtitles%2Fjob_123%2Fen.srt',
            },
          };
        final video = Video.fromMap(map, 'test-flat-subtitles');
        expect(video.mediaSubtitles['te'], contains('te.srt'));
        expect(video.mediaSubtitles['en'], contains('en.srt'));
      });
    });
  });
}
