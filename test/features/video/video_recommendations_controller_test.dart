import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/data/models/playlist_model.dart';
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

    test('recommendationFilters places topic tab in between All and Flip Coin when navigatedFromTopic is true', () {
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

      final topicController = VideoRecommendationsController(
        getVideo: () => baseVideo,
        getCurrentPlaylist: () => null,
        getPlaylistVideos: () => <Video>[],
        getCurrentTopic: () => topic,
        getTopicVideos: () => <Video>[],
        getNavigatedFromTopic: () => true,
        getNavigatedFromPlaylist: () => false,
      );

      final filters = topicController.recommendationFilters;
      expect(filters.length, greaterThanOrEqualTo(3));
      expect(filters[0], equals('All'));
      expect(filters[1], equals('Quantum Computing'));
      expect(filters[2], equals('Flip Coin'));
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

    test('recommendationFilters places playlist tab in between All and Flip Coin', () {
      final samplePlaylist = PlaylistModel(
        id: 'watchlater',
        ownerId: 'u1',
        channelId: 'c1',
        playlistName: 'Watch Later',
        videoIds: ['v1', 'v2'],
      );

      final playlistController = VideoRecommendationsController(
        getVideo: () => baseVideo,
        getCurrentPlaylist: () => samplePlaylist,
        getPlaylistVideos: () => <Video>[],
        getNavigatedFromTopic: () => false,
        getNavigatedFromPlaylist: () => true,
      );

      final filters = playlistController.recommendationFilters;
      expect(filters.length, greaterThanOrEqualTo(3));
      expect(filters[0], equals('All'));
      expect(filters[1], equals('Watch Later'));
      expect(filters[2], equals('Flip Coin'));
    });

    test('filteredRecommendedVideos returns playlist videos when playlist tab selected', () {
      final p1 = createTestVideo(id: 'p1', title: 'Playlist Video 1');
      final p2 = createTestVideo(id: 'p2', title: 'Playlist Video 2');
      final samplePlaylist = PlaylistModel(
        id: 'pl_favorites',
        ownerId: 'u1',
        channelId: 'c1',
        playlistName: 'Favorites',
        videoIds: ['p1', 'p2'],
      );

      final playlistController = VideoRecommendationsController(
        getVideo: () => baseVideo,
        getCurrentPlaylist: () => samplePlaylist,
        getPlaylistVideos: () => [p1, p2],
        getNavigatedFromTopic: () => false,
        getNavigatedFromPlaylist: () => true,
      );

      playlistController.selectedRecommendationFilter.value = 'Favorites';
      expect(playlistController.filteredRecommendedVideos, equals([p1, p2]));
    });

    test('onInit automatically selects playlist tab when navigatedFromPlaylist', () {
      final samplePlaylist = PlaylistModel(
        id: 'watchlater',
        ownerId: 'u1',
        channelId: 'c1',
        playlistName: 'Watch Later',
        videoIds: ['v1'],
      );

      final playlistController = VideoRecommendationsController(
        getVideo: () => baseVideo,
        getCurrentPlaylist: () => samplePlaylist,
        getPlaylistVideos: () => <Video>[],
        getNavigatedFromTopic: () => false,
        getNavigatedFromPlaylist: () => true,
      );
      playlistController.onInit();

      expect(playlistController.selectedRecommendationFilter.value, equals('Watch Later'));
    });

    test('filteredRecommendedVideos returns topic videos when topic tab selected', () {
      final t1 = createTestVideo(id: 't1', title: 'Topic Video 1');
      final t2 = createTestVideo(id: 't2', title: 'Topic Video 2');
      final sampleTopic = Topic(
        id: 'topic_ai',
        title: 'Artificial Intelligence',
        slug: 'artificial-intelligence',
        handle: 'ai',
        handleLowercase: 'ai',
        description: 'All about AI',
        category: 'Tech',
        thumbnailUrl: '',
        videoCount: 2,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final topicController = VideoRecommendationsController(
        getVideo: () => baseVideo,
        getCurrentPlaylist: () => null,
        getPlaylistVideos: () => <Video>[],
        getCurrentTopic: () => sampleTopic,
        getTopicVideos: () => [t1, t2],
        getNavigatedFromTopic: () => true,
        getNavigatedFromPlaylist: () => false,
      );

      topicController.selectedRecommendationFilter.value = 'Artificial Intelligence';
      expect(topicController.filteredRecommendedVideos, equals([t1, t2]));
    });

    test('onInit automatically selects topic tab when navigatedFromTopic', () {
      final sampleTopic = Topic(
        id: 'topic_ai',
        title: 'Artificial Intelligence',
        slug: 'artificial-intelligence',
        handle: 'ai',
        handleLowercase: 'ai',
        description: 'All about AI',
        category: 'Tech',
        thumbnailUrl: '',
        videoCount: 2,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final topicController = VideoRecommendationsController(
        getVideo: () => baseVideo,
        getCurrentPlaylist: () => null,
        getPlaylistVideos: () => <Video>[],
        getCurrentTopic: () => sampleTopic,
        getTopicVideos: () => <Video>[],
        getNavigatedFromTopic: () => true,
        getNavigatedFromPlaylist: () => false,
      );
      topicController.onInit();

      expect(topicController.selectedRecommendationFilter.value, equals('Artificial Intelligence'));
    });

    test('Flip Coin tab returns plain video list without community posts or ads', () {
      final v1 = createTestVideo(id: 'v1', title: 'Video 1');
      final v2 = createTestVideo(id: 'v2', title: 'Video 2');
      controller.recommendedVideos.addAll([v1, v2]);

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

      controller.selectedRecommendationFilter.value = 'Flip Coin';
      expect(controller.filteredRecommendedVideos, equals([v1, v2]));
      expect(controller.recommendedItems, equals([v1, v2]));
    });

    test('filteredRecommendedVideos matches channel tab with whitespace trimming and startsWith', () {
      final channelVideo = createTestVideo(
        id: 'v_chan',
        title: 'Channel Extra Video',
        channelName: 'Science Daily',
      );
      controller.moreFromChannel.add(channelVideo);

      // Exact match
      controller.selectedRecommendationFilter.value = 'From Science Daily';
      expect(controller.filteredRecommendedVideos, equals([channelVideo]));

      // With prefix
      controller.selectedRecommendationFilter.value = 'From Science Daily ';
      expect(controller.filteredRecommendedVideos, equals([channelVideo]));
    });

    test('filteredRecommendedVideos retrieves from tagVideosCache when cached', () {
      final tagVideo = createTestVideo(
        id: 'v_quantum',
        title: 'Quantum Computers 2026',
        tags: ['quantum'],
      );
      controller.tagVideosCache['quantum'] = [tagVideo];

      controller.selectedRecommendationFilter.value = 'quantum';
      expect(controller.filteredRecommendedVideos, equals([tagVideo]));
    });

    test('filteredRecommendedVideos excludes playing video from in-memory tag/title search', () {
      final currentVid = createTestVideo(
        id: 'vid_base',
        title: 'Quantum Mechanics Explained',
        tags: ['quantum'],
      );
      final otherVid = createTestVideo(
        id: 'v_other',
        title: 'Quantum Entanglement',
        tags: ['quantum'],
      );
      controller.recommendedVideos.addAll([currentVid, otherVid]);

      controller.selectedRecommendationFilter.value = 'quantum';
      final results = controller.filteredRecommendedVideos;
      expect(results.contains(otherVid), isTrue);
      expect(results.contains(currentVid), isFalse);
    });

    test('recommendationFilters includes category when tags are empty', () {
      final noTagsVideo = createTestVideo(
        id: 'v_notags',
        title: 'No Tags Video',
        category: 'Documentary',
        tags: [],
      );

      final catController = VideoRecommendationsController(
        getVideo: () => noTagsVideo,
        getCurrentPlaylist: () => null,
        getPlaylistVideos: () => <Video>[],
        getNavigatedFromTopic: () => false,
      );

      final filters = catController.recommendationFilters;
      expect(filters, contains('All'));
      expect(filters, contains('Flip Coin'));
      expect(filters, contains('From Truth Channel'));
      expect(filters, contains('Documentary'));
    });

    test('ensureFilterVideosLoaded handles channel tab safely without throwing', () async {
      // Calling ensureFilterVideosLoaded with channel tab should invoke fetchChannelVideos safely
      await controller.ensureFilterVideosLoaded('From Science Daily');
      // Should not throw and controller remains stable
      expect(controller.isTabLoading.value, isFalse);
    });

    test('ensureFilterVideosLoaded handles tag and category tabs safely without throwing', () async {
      await controller.ensureFilterVideosLoaded('quantum');
      expect(controller.isTabLoading.value, isFalse);
    });

    test('fetchChannelVideos returns safely without throwing when uninitialized', () async {
      final result = await controller.fetchChannelVideos();
      expect(result, isA<List<Video>>());
    });
  });
}
