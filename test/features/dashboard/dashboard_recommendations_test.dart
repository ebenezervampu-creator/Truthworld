import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/sections/dashboard_recommendations_section.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/video_management.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  group('DashboardRecommendationsSection Logic Tests', () {
    late DashboardController controller;
    late Channel testChannel;

    setUp(() {
      Get.reset();
      controller = DashboardController(
        channelId: 'test_ch_1',
        autoInitialize: false,
      );
      controller.rxIsLoading.value = false;

      testChannel = Channel(
        id: 'test_ch_1',
        ownerId: 'user_1',
        name: 'Truth Channel',
        nameLowercase: 'truth channel',
        handle: 'truthchannel',
        handleLowercase: 'truthchannel',
        description:
            'A very informative and interesting channel about facts and truth.',
        bannerUrl: 'https://example.com/banner.jpg',
        avatarUrl: 'https://example.com/avatar.jpg',
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
        videoCount: 1,
      );
    });

    tearDown(Get.reset);

    test(
        'Does NOT recommend "Upload Your First Video" when channel has uploaded a video',
        () {
      final recentVideo = Video(
        id: 'v1',
        title: 'Are Eggs Vegetarian or Non-Vegetarian? 🥚 The Science',
        description: 'Scientific breakdown',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        ownerId: 'user_1',
        channelId: 'test_ch_1',
        channelName: 'Truth Channel',
        category: 'Education',
        tags: const ['science', 'food'],
        createdAt: Timestamp.now(),
        uploadedAt: Timestamp.now(),
      );

      final recs = DashboardRecommendationsSection.generateRecommendations(
        testChannel,
        [recentVideo],
        {},
        controller,
      );

      final firstVideoRec = recs.firstWhereOrNull(
        (r) => r['title'] == 'Upload Your First Video',
      );
      expect(firstVideoRec, isNull);
    });

    test(
        'Does NOT recommend "Upload Your First Video" when videos list is empty but channel.videoCount > 0',
        () {
      // Channel says videoCount: 1 even if videos list hasn't arrived
      final channelWithVideoCount = testChannel.copyWith(videoCount: 1);

      final recs = DashboardRecommendationsSection.generateRecommendations(
        channelWithVideoCount,
        [],
        {},
        controller,
      );

      final firstVideoRec = recs.firstWhereOrNull(
        (r) => r['title'] == 'Upload Your First Video',
      );
      expect(firstVideoRec, isNull);
    });

    test(
        'Does NOT recommend "Upload Your First Video" when VideoManagementController has videos',
        () {
      final vmCtrl = Get.put(VideoManagementController());
      final vmVideo = Video(
        id: 'v_vm_1',
        title: 'Are Eggs Vegetarian or Non-Vegetarian?',
        description: 'Scientific breakdown',
        thumbnailUrl: '',
        ownerId: 'user_1',
        channelId: 'test_ch_1',
        channelName: 'Truth Channel',
        category: 'Education',
        tags: const ['science'],
        createdAt: Timestamp.now(),
      );
      vmCtrl.channelVideos.assignAll([vmVideo]);

      // channel videoCount is 0, but VideoManagementController already loaded the video
      final channelZeroCount = testChannel.copyWith(videoCount: 0);

      final recs = DashboardRecommendationsSection.generateRecommendations(
        channelZeroCount,
        [],
        {},
        controller,
      );

      final firstVideoRec = recs.firstWhereOrNull(
        (r) => r['title'] == 'Upload Your First Video',
      );
      expect(firstVideoRec, isNull);
    });

    test(
        'Does NOT recommend "Upload Your First Video" while controller is still loading',
        () {
      controller.rxIsLoading.value = true;
      final freshChannel = testChannel.copyWith(videoCount: 0);

      final recs = DashboardRecommendationsSection.generateRecommendations(
        freshChannel,
        [],
        {},
        controller,
      );

      final firstVideoRec = recs.firstWhereOrNull(
        (r) => r['title'] == 'Upload Your First Video',
      );
      expect(firstVideoRec, isNull);
    });

    test(
        'RECOMMENDS "Upload Your First Video" only when channel has truly 0 videos and loading is complete',
        () {
      controller.rxIsLoading.value = false;
      final trueZeroChannel = testChannel.copyWith(videoCount: 0);

      final recs = DashboardRecommendationsSection.generateRecommendations(
        trueZeroChannel,
        [],
        {'videos': 0},
        controller,
      );

      final firstVideoRec = recs.firstWhereOrNull(
        (r) => r['title'] == 'Upload Your First Video',
      );
      expect(firstVideoRec, isNotNull);
      expect(
        firstVideoRec!['description'],
        contains("You haven't uploaded any videos yet"),
      );
    });

    test(
        'Recommends "Upload New Content" when last upload was more than 14 days ago',
        () {
      final oldDate = DateTime.now().subtract(const Duration(days: 20));
      final oldVideo = Video(
        id: 'v_old',
        title: 'Old Video',
        description: 'Old content',
        thumbnailUrl: '',
        ownerId: 'user_1',
        channelId: 'test_ch_1',
        channelName: 'Truth Channel',
        category: 'Education',
        tags: const ['old'],
        createdAt: Timestamp.fromDate(oldDate),
        uploadedAt: Timestamp.fromDate(oldDate),
      );

      final recs = DashboardRecommendationsSection.generateRecommendations(
        testChannel,
        [oldVideo],
        {},
        controller,
      );

      final uploadNewRec = recs.firstWhereOrNull(
        (r) => r['title'] == 'Upload New Content',
      );
      expect(uploadNewRec, isNotNull);
      expect(uploadNewRec!['description'], contains('20 days'));
    });

    test(
        'Auto-heals channel videoCount in DashboardController when recent videos are loaded',
        () {
      final zeroChannel = testChannel.copyWith(videoCount: 0);
      controller.currentChannel.value = zeroChannel;

      final video = Video(
        id: 'v_autoheal',
        title: 'Fresh Video',
        description: 'Video description',
        thumbnailUrl: '',
        ownerId: 'user_1',
        channelId: 'test_ch_1',
        channelName: 'Truth Channel',
        category: 'Education',
        tags: const [],
        createdAt: Timestamp.now(),
      );

      controller.applyRecentVideosForTest([video]);

      expect(controller.recentVideos.length, equals(1));
      expect(controller.currentChannel.value?.videoCount, equals(1));
    });
  });
}
