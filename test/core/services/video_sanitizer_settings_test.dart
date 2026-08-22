import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/video_sanitizer.dart';
import 'package:truthworld/features/video/data/models/video.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(Get.reset);

  Video createMockVideo({
    required String id,
    required String title,
    required String channelId,
    required String channelName,
    List<String> tags = const [],
    String description = 'mock description',
  }) {
    return Video(
      id: id,
      title: title,
      description: description,
      thumbnailUrl: 'https://example.com/$id.jpg',
      ownerId: 'owner_$channelId',
      channelId: channelId,
      channelName: channelName,
      category: 'Tech',
      tags: tags,
      videoUrl: 'https://example.com/$id.mp4',
      views: 10,
      createdAt: Timestamp.now(),
      status: VideoStatus.ready,
    );
  }

  group('VideoSanitizer Settings & Policy Filtering', () {
    test('deduplicates identical video IDs', () {
      final v1 = createMockVideo(
        id: 'vid1',
        title: 'Flutter Tutorial',
        channelId: 'ch1',
        channelName: 'FlutterDev',
      );
      final v2 = createMockVideo(
        id: 'vid1',
        title: 'Flutter Tutorial (Duplicate)',
        channelId: 'ch1',
        channelName: 'FlutterDev',
      );

      final result = VideoSanitizer.sanitizeForFeed([v1, v2]);
      expect(result.length, equals(1));
      expect(result.first.id, equals('vid1'));
    });

    test('filters explicit blocked channel IDs', () {
      final v1 = createMockVideo(
        id: 'vid1',
        title: 'Good Video',
        channelId: 'ch_good',
        channelName: 'GoodChannel',
      );
      final v2 = createMockVideo(
        id: 'vid2',
        title: 'Blocked Video',
        channelId: 'ch_blocked',
        channelName: 'BlockedChannel',
      );

      final result = VideoSanitizer.sanitizeForFeed(
        [v1, v2],
        blockedChannelIds: ['ch_blocked'],
      );
      expect(result.length, equals(1));
      expect(result.first.id, equals('vid1'));
    });

    test('filters out deleted videos', () {
      final v1 = Video(
        id: 'vid1',
        title: 'Deleted Video',
        description: 'Desc',
        thumbnailUrl: 'https://example.com/v1.jpg',
        ownerId: 'o1',
        channelId: 'ch1',
        channelName: 'Channel 1',
        category: 'General',
        tags: [],
        status: VideoStatus.deleted,
      );

      final result = VideoSanitizer.sanitizeForFeed([v1]);
      expect(result, isEmpty);
    });
  });
}
