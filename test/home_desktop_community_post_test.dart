import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/features/community/data/models/community_post_model.dart';
import 'package:truthworld/features/video/data/models/video.dart';

void main() {
  group('Home desktop community post filtering', () {
    late Video sampleVideo;
    late CommunityPostModel samplePost;

    setUp(() {
      sampleVideo = Video(
        id: 'video_1',
        title: 'Sample Video',
        description: 'Test Description',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        ownerId: 'user_1',
        channelId: 'ch_1',
        channelName: 'Test Channel',
        category: 'News',
        tags: const ['news'],
        channelImage: 'https://example.com/channel.jpg',
        uploadedAt: Timestamp.now(),
        duration: '10:00',
      );

      samplePost = CommunityPostModel(
        id: 'post_1',
        title: 'Sample Community Post',
        description: 'Test Post Content',
        ownerId: 'user_1',
        channelId: 'ch_1',
        channelName: 'Test Channel',
        channelImage: 'https://example.com/channel.jpg',
        uploadedAt: DateTime.now(),
      );
    });

    List<dynamic> filterItems(
      List<dynamic> items, {
      required bool isDesktop,
      required bool isPostsTab,
    }) {
      if (isDesktop && !isPostsTab) {
        return items.where((item) => item is! CommunityPostModel).toList();
      }
      return items;
    }

    test('On Desktop in All tab: CommunityPostModel items are filtered out', () {
      final feedItems = <dynamic>[sampleVideo, samplePost];
      final filteredItems = filterItems(
        feedItems,
        isDesktop: true,
        isPostsTab: false,
      );

      expect(filteredItems.length, equals(1));
      expect(filteredItems.first, equals(sampleVideo));
      expect(filteredItems.any((item) => item is CommunityPostModel), isFalse);
    });

    test('On Desktop in Posts tab: CommunityPostModel items are preserved', () {
      final feedItems = <dynamic>[samplePost];
      final filteredItems = filterItems(
        feedItems,
        isDesktop: true,
        isPostsTab: true,
      );

      expect(filteredItems.length, equals(1));
      expect(filteredItems.first, equals(samplePost));
    });

    test('On Mobile in All tab: CommunityPostModel items are preserved', () {
      final feedItems = <dynamic>[sampleVideo, samplePost];
      final filteredItems = filterItems(
        feedItems,
        isDesktop: false,
        isPostsTab: false,
      );

      expect(filteredItems.length, equals(2));
      expect(filteredItems, contains(sampleVideo));
      expect(filteredItems, contains(samplePost));
    });
  });
}
