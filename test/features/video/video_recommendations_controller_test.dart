import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/community/data/models/community_post_model.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/video_recommendations_controller.dart';

Video createTestVideo({
  required String id,
  required String title,
  String channelId = 'channel_1',
  String channelName = 'Truth Channel',
  String category = 'Science',
  List<String> tags = const ['physics', 'space'],
}) {
  return Video(
    id: id,
    title: title,
    description: 'Description for $title',
    thumbnailUrl: 'https://example.com/$id.jpg',
    ownerId: 'owner_1',
    channelId: channelId,
    channelName: channelName,
    category: category,
    tags: tags,
    views: 100,
    createdAt: DateTime(2026),
  );
}

void main() {
  group('VideoRecommendationsController Tests', () {
    late Video baseVideo;
    late VideoRecommendationsController controller;

    setUp(() {
      Get.reset();
      baseVideo = createTestVideo(
        id: 'vid_base',
        title: 'Quantum Mechanics Explained',
        channelId: 'chan_science',
        channelName: 'Science Daily',
        category: 'Physics',
        tags: ['quantum', 'atom'],
      );

      controller = VideoRecommendationsController(
        getVideo: () => baseVideo,
        getCurrentPlaylist: () => null,
        getPlaylistVideos: () => <Video>[],
        getNavigatedFromTopic: () => false,
      );
    });

    test('initial state is properly initialized', () {
      expect(controller.recommendedVideos, isEmpty);
      expect(controller.communityPosts, isEmpty);
      expect(controller.moreFromChannel, isEmpty);
      expect(controller.isLoadingRecommendations.value, isTrue);
      expect(controller.selectedRecommendationFilter.value, equals('All'));
      expect(controller.videoTopicsList, isEmpty);
      expect(controller.videoPlaylistsList, isEmpty);
    });

    test('recommendationFilters generates correct tags and channel tab', () {
      final filters = controller.recommendationFilters;
      expect(filters, contains('All'));
      expect(filters, contains('Flip Coin'));
      expect(filters, contains('From Science Daily'));
      expect(filters, contains('quantum'));
      expect(filters, contains('atom'));
      // Navigated from topic is false, so no topics are included yet
      expect(filters.any((f) => f.startsWith('Topic: ')), isFalse);
    });

    test('recommendationFilters includes topics when navigatedFromTopic is true', () {
      final topicController = VideoRecommendationsController(
        getVideo: () => baseVideo,
        getCurrentPlaylist: () => null,
        getPlaylistVideos: () => <Video>[],
        getNavigatedFromTopic: () => true,
      );

      final topic = Topic(
        id: 'topic_quantum',
        title: 'Quantum Computing',
        slug: 'quantum-computing',
        handle: 'quantum',
        handleLowercase: 'quantum',
        description: 'All about quantum computing',
        category: 'Science',
        thumbnailUrl: '',
        videoCount: 5,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      topicController.videoTopicsList.add(topic);

      final filters = topicController.recommendationFilters;
      expect(filters, contains('Topic: Quantum Computing'));
    });

    test('filteredRecommendedVideos returns all videos when filter is All', () {
      final v1 = createTestVideo(id: 'v1', title: 'Video 1');
      final v2 = createTestVideo(id: 'v2', title: 'Video 2');
      controller.recommendedVideos.addAll([v1, v2]);

      controller.selectedRecommendationFilter.value = 'All';
      expect(controller.filteredRecommendedVideos, equals([v1, v2]));
    });

    test('filteredRecommendedVideos filters by channel properly', () {
      final vChannel = createTestVideo(
        id: 'vc',
        title: 'Channel Vid',
        channelName: 'Science Daily',
      );
      controller.moreFromChannel.add(vChannel);

      controller.selectedRecommendationFilter.value = 'From Science Daily';
      expect(controller.filteredRecommendedVideos, equals([vChannel]));
    });

    test('filteredRecommendedVideos filters by keyword in title/tag', () {
      final v1 = createTestVideo(id: 'v1', title: 'Astrophysics Intro', tags: ['stars']);
      final v2 = createTestVideo(id: 'v2', title: 'Cooking 101', tags: ['food']);
      controller.recommendedVideos.addAll([v1, v2]);

      controller.selectedRecommendationFilter.value = 'stars';
      expect(controller.filteredRecommendedVideos, equals([v1]));
    });

    test('recommendedItems correctly interleaves videos, posts, and topics', () {
      final v1 = createTestVideo(id: 'v1', title: 'V1');
      final v2 = createTestVideo(id: 'v2', title: 'V2');
      final v3 = createTestVideo(id: 'v3', title: 'V3');
      final v4 = createTestVideo(id: 'v4', title: 'V4');
      final v5 = createTestVideo(id: 'v5', title: 'V5');
      controller.recommendedVideos.addAll([v1, v2, v3, v4, v5]);

      final post = CommunityPostModel(
        id: 'p1',
        title: 'Community update',
        description: 'Hello world',
        ownerId: 'u1',
        channelId: 'c1',
        channelName: 'Channel 1',
        channelImage: '',
        uploadedAt: DateTime.now(),
      );
      controller.communityPosts.add(post);

      final items = controller.recommendedItems;
      expect(items.isNotEmpty, isTrue);
      expect(items.contains(v1), isTrue);
      expect(items.contains(post), isTrue);
    });
  });
}
