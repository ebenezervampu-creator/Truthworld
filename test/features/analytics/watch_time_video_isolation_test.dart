import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/core/utils/watch_time_formatter.dart';
import 'package:truthworld/features/analytics/data/models/watch_event_model.dart';
import 'package:truthworld/features/analytics/data/services/geolocation_service.dart';
import 'package:truthworld/features/analytics/data/services/video_analytics_service.dart';
import 'package:truthworld/features/analytics/presentation/controllers/creator_analytics_controller.dart';
import 'package:truthworld/features/analytics/presentation/pages/watch_time_page.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  group('Watch Time Page & Video Isolation Critical Bug Verification', () {
    late CreatorAnalyticsController controller;

    final videoA = Video(
      id: 'vid_nonzero_1',
      title: 'Active Video With Watchtime',
      description: 'Test description',
      thumbnailUrl: '',
      ownerId: 'owner_1',
      channelId: 'channel_100',
      channelName: 'Truth Channel',
      duration: '15:00',
      vDurationValue: const Duration(seconds: 900),
      totalWatchTimeSeconds: 840, // 14 mins
      viewCount: 1,
      category: 'News',
      tags: const [],
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    );

    final videoZero = Video(
      id: 'vid_zero_1',
      title: 'phone cheyye',
      description: 'Zero watch time video',
      thumbnailUrl: '',
      ownerId: 'owner_1',
      channelId: 'channel_100',
      channelName: 'Truth Channel',
      duration: '00:24',
      vDurationValue: const Duration(seconds: 24),
      category: 'General',
      tags: const [],
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    );

    final channelSnapshot = ChannelAnalyticsSnapshot(
      channelId: 'channel_100',
      channelName: 'Truth Channel',
      totalVideoWatches: 1,
      totalUniqueViewers: 1,
      averageWatchDuration: 240,
      averageWatchPercentage: 80,
      totalWatchTimeSeconds: 840, // 14 mins
      videoCount: 2,
      totalEngagementScore: 80,
      stateTraffic: const {},
      stateTrafficPercentage: const {},
      generatedAt: DateTime.now(),
    );

    final videoZeroSnapshot = VideoAnalyticsSnapshot(
      videoId: 'vid_zero_1',
      title: 'phone cheyye',
      totalViews: 0,
      totalUniqueViewers: 0,
      averageWatchDuration: 0,
      averageWatchPercentage: 0,
      usersCompletedVideo: 0,
      watchtimeCategoryCount: const {},
      stateTraffic: const {},
      stateTrafficPercentage: const {},
      deviceTypeBreakdown: const {},
      qualityBreakdown: const {},
      generatedAt: DateTime.now(),
      estimatedReadCount: 0,
    );

    setUp(() {
      Get.reset();
      Get.testMode = true;
      Get.put<ConnectivityService>(ConnectivityService());
      Get.put<VideoAnalyticsService>(VideoAnalyticsService());
      Get.put<GeolocationService>(GeolocationService());
      controller = Get.put<CreatorAnalyticsController>(
        _TestCreatorAnalyticsController(
          testChannelSnapshot: channelSnapshot,
          testVideoSnapshot: videoZeroSnapshot,
        ),
        permanent: true,
      );
    });

    tearDown(Get.reset);

    test('Unit: Controller does not overwrite video metrics when channel analytics finish', () async {
      controller.selectedChannelId.value = 'channel_100';
      controller.channelVideos.assignAll([videoA, videoZero]);

      controller.updateChannelSummaryMetrics(
        channelSnapshot,
        buildTrendData: controller.buildContinuousTrendData,
        populateCountryChart: controller.populateCountryChart,
        days: 28,
      );
      expect(controller.totalWatchTime.value, equals('14 mins'));

      // Now user selects zero watch time video
      controller.selectedVideoId.value = videoZero.id;
      final matchingVideo = controller.channelVideos.firstWhere((v) => v.id == videoZero.id);
      controller.totalWatchTime.value = WatchTimeFormatter.format(matchingVideo.totalWatchTimeSeconds);
      expect(controller.totalWatchTime.value, equals('0 mins'));

      // Simulated background channel analytics update finishes while video is selected
      controller.channelAnalytics.value = channelSnapshot;
      if (controller.selectedVideoId.value.isEmpty) {
        controller.updateChannelSummaryMetrics(
          channelSnapshot,
          buildTrendData: controller.buildContinuousTrendData,
          populateCountryChart: controller.populateCountryChart,
          days: 28,
        );
      }

      // totalWatchTime should REMAIN '0 mins' and NOT be overwritten to 14 mins!
      expect(controller.totalWatchTime.value, equals('0 mins'));
    });

    testWidgets('Widget: Selecting zero watchtime video shows 0 mins and not channel 14 mins',
        (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;

      controller.selectedChannelId.value = 'channel_100';
      controller.channelVideos.assignAll([videoA, videoZero]);
      controller.totalWatchTime.value = '14 mins';

      await tester.pumpWidget(
        GetMaterialApp(
          theme: buildAppTheme(),
          onGenerateRoute: (settings) {
            return GetPageRoute(
              settings: const RouteSettings(
                arguments: {
                  'channelId': 'channel_100',
                  'channelName': 'Truth Channel',
                  'watchTime': '14 mins',
                  'watchTimeChange': '+0%',
                },
              ),
              page: () => const WatchTimePage(),
            );
          },
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Channel view assertions:
      expect(find.text('Channel Watch Time'), findsOneWidget);
      expect(find.text('Total Watch Time'), findsOneWidget);
      // '14 mins' appears in main metric and in videoA's list card
      expect(find.text('14 mins'), findsWidgets);
      expect(find.text('phone cheyye'), findsOneWidget);

      // Scroll to and tap on the video "phone cheyye" (which has 0 watch time)
      final zeroVideoCard = find.text('phone cheyye');
      expect(zeroVideoCard, findsOneWidget);
      await tester.ensureVisible(zeroVideoCard);
      await tester.pumpAndSettle();
      await tester.tap(zeroVideoCard);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Video view assertions:
      expect(find.text('Video Watch Time'), findsOneWidget);
      expect(find.text('Back to Channel Watch Time'), findsOneWidget);

      // CRITICAL BUG VERIFICATION:
      // The video title card should display 'phone cheyye'
      // The main stat card MUST display '0 mins' for 'phone cheyye', NOT '14 mins'!
      expect(find.text('0 mins'), findsWidgets); // header stat card + list card both display '0 mins'
      // '14 mins' should NOT be the main metric of phone cheyye (only videoA in the list still has 14 mins)
      expect(find.text('14 mins'), findsOneWidget); // Only videoA's card in the list

      // Tap 'Back to Channel Watch Time'
      final backButton = find.text('Back to Channel Watch Time');
      expect(backButton, findsOneWidget);
      await tester.ensureVisible(backButton);
      await tester.pumpAndSettle();
      await tester.tap(backButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Restored channel view assertions:
      expect(find.text('Channel Watch Time'), findsOneWidget);
      expect(find.text('Total Watch Time'), findsOneWidget);
      // Both the main metric and videoA show '14 mins'
      expect(find.text('14 mins'), findsNWidgets(2));
    });
  });
}

class _TestCreatorAnalyticsController extends CreatorAnalyticsController {
  final ChannelAnalyticsSnapshot testChannelSnapshot;
  final VideoAnalyticsSnapshot testVideoSnapshot;

  _TestCreatorAnalyticsController({
    required this.testChannelSnapshot,
    required this.testVideoSnapshot,
  });

  @override
  Future<void> fetchChannelVideos(String channelId) async {
    // Keep in-memory channelVideos without calling external Firestore
  }

  @override
  Future<void> loadChannelAnalytics(String channelId, {String? channelName}) async {
    isLoadingChannelAnalytics.value = false;
    channelAnalytics.value = testChannelSnapshot;
    if (selectedVideoId.value.isEmpty) {
      updateChannelSummaryMetrics(
        testChannelSnapshot,
        buildTrendData: buildContinuousTrendData,
        populateCountryChart: populateCountryChart,
        days: 28,
      );
    }
  }

  @override
  Future<void> loadVideoAnalytics(String videoId, {String? videoTitle}) async {
    isLoadingVideoAnalytics.value = false;
    final matchingVideo = channelVideos.firstWhereOrNull((v) => v.id == videoId);
    final videoWatch = matchingVideo?.totalWatchTimeSeconds ?? 0;
    totalWatchTime.value = WatchTimeFormatter.format(videoWatch);
    videoAnalytics.value = testVideoSnapshot;
    updateVideoSummaryMetrics(
      testVideoSnapshot,
      buildTrendData: buildContinuousTrendData,
      populateCountryChart: populateCountryChart,
      days: 28,
    );
  }
}
