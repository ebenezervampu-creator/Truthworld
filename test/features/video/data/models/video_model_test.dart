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
        'trustScore': 85.0,
        'videoRating': 4.5,
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
      expect(video.trustScore, 85.0);
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
      expect(video.trustIndex, video.trustScore);
    });

    test('VideoStatus enum values are correct', () {
      expect(VideoStatus.values.length, greaterThanOrEqualTo(6));
      expect(VideoStatus.values, contains(VideoStatus.ready));
      expect(VideoStatus.values, contains(VideoStatus.processing));
      expect(VideoStatus.values, contains(VideoStatus.deleted));
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
  });
}
