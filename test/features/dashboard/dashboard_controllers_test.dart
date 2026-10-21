import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/analytics/presentation/controllers/revenue_analytics_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audio_tracks_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/chapters_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  group('ChaptersController Tests', () {
    late ChaptersController controller;

    setUp(() {
      Get.reset();
      controller = ChaptersController();
    });

    test('addChapter adds chapter and sorts by startTime ascending', () {
      controller.addChapter('Introduction', Duration.zero);
      controller.addChapter('Outro', const Duration(minutes: 10));
      controller.addChapter('Main Content', const Duration(minutes: 3));

      expect(controller.currentChapters.length, equals(3));
      expect(controller.currentChapters[0].title, equals('Introduction'));
      expect(controller.currentChapters[0].startTime, equals(Duration.zero));
      expect(controller.currentChapters[1].title, equals('Main Content'));
      expect(
        controller.currentChapters[1].startTime,
        equals(const Duration(minutes: 3)),
      );
      expect(controller.currentChapters[2].title, equals('Outro'));
      expect(
        controller.currentChapters[2].startTime,
        equals(const Duration(minutes: 10)),
      );
      expect(controller.hasUnsavedChanges.value, isTrue);
    });

    test(
      'addChapter replaces existing chapter when startTime is duplicated',
      () {
        controller.addChapter('Original Intro', Duration.zero);
        controller.addChapter('Updated Intro', Duration.zero);

        expect(controller.currentChapters.length, equals(1));
        expect(controller.currentChapters.first.title, equals('Updated Intro'));
        expect(controller.hasUnsavedChanges.value, isTrue);
      },
    );

    test('updateChapter modifies existing chapter properly', () {
      controller.addChapter('Chapter 1', Duration.zero);
      controller.updateChapter(
        0,
        title: 'Renamed Chapter 1',
        startTime: const Duration(seconds: 15),
      );

      expect(controller.currentChapters[0].title, equals('Renamed Chapter 1'));
      expect(
        controller.currentChapters[0].startTime,
        equals(const Duration(seconds: 15)),
      );
    });

    test('deleteChapter removes chapter at specified index', () {
      controller.addChapter('Chapter 1', Duration.zero);
      controller.addChapter('Chapter 2', const Duration(minutes: 2));
      expect(controller.currentChapters.length, equals(2));

      controller.deleteChapter(0);
      expect(controller.currentChapters.length, equals(1));
      expect(controller.currentChapters.first.title, equals('Chapter 2'));
    });

    test('shiftChapterTiming shifts timestamp forward and backward', () {
      controller.addChapter('Chapter 1', const Duration(seconds: 30));
      controller.shiftChapterTiming(0, 5000); // +5 seconds
      expect(
        controller.currentChapters[0].startTime,
        equals(const Duration(seconds: 35)),
      );

      controller.shiftChapterTiming(0, -10000); // -10 seconds
      expect(
        controller.currentChapters[0].startTime,
        equals(const Duration(seconds: 25)),
      );
    });

    test('enforces video duration limit when video is under 6 minutes', () {
      final shortVideo = Video.fromMap({
        'title': 'Under 6 Min Video',
        'channelId': 'chan_1',
        'videoUrl': 'https://example.com/short.mp4',
        'duration': '05:30',
        'durationMs': (5 * 60 + 30) * 1000,
      }, 'vid_short');

      controller.selectedVideo.value = shortVideo;

      // 1. Adding chapter within duration succeeds
      final addedValid = controller.addChapter(
        'Intro',
        const Duration(minutes: 2),
      );
      expect(addedValid, isTrue);
      expect(controller.currentChapters.length, equals(1));

      // 2. Adding chapter exceeding 5:30 fails
      final addedPastDuration = controller.addChapter(
        'Out of bounds',
        const Duration(minutes: 6),
      );
      expect(addedPastDuration, isFalse);
      expect(controller.currentChapters.length, equals(1));

      // 3. Adding chapter exactly at 5:30 fails
      final addedAtDuration = controller.addChapter(
        'End boundary',
        const Duration(minutes: 5, seconds: 30),
      );
      expect(addedAtDuration, isFalse);
      expect(controller.currentChapters.length, equals(1));

      // 4. Negative timestamp fails
      final addedNegative = controller.addChapter(
        'Negative',
        const Duration(seconds: -5),
      );
      expect(addedNegative, isFalse);
      expect(controller.currentChapters.length, equals(1));

      // 5. Updating chapter past duration fails
      final updatedPast = controller.updateChapter(
        0,
        startTime: const Duration(minutes: 7),
      );
      expect(updatedPast, isFalse);
      expect(
        controller.currentChapters[0].startTime,
        equals(const Duration(minutes: 2)),
      );

      // 6. Shifting chapter past duration is blocked
      controller.shiftChapterTiming(0, 4 * 60 * 1000); // 2m + 4m = 6m > 5m30s
      expect(
        controller.currentChapters[0].startTime,
        equals(const Duration(minutes: 2)),
      );

      // 7. Shifting backwards cannot go below 0
      controller.shiftChapterTiming(0, -3 * 60 * 1000); // 2m - 3m -> 0
      expect(controller.currentChapters[0].startTime, equals(Duration.zero));
    });

    test(
      'importFromTimestampFormat skips timestamps exceeding video duration',
      () {
        final shortVideo = Video.fromMap({
          'title': 'Under 6 Min Video',
          'channelId': 'chan_1',
          'videoUrl': 'https://example.com/short.mp4',
          'duration': '05:30',
          'durationMs': (5 * 60 + 30) * 1000,
        }, 'vid_short');

        controller.selectedVideo.value = shortVideo;

        const importText = '''
00:00 Introduction
02:15 Topic Discussion
05:10 Conclusion
06:00 Extra Out of Bounds
07:30 Bonus Not Allowed
''';

        controller.importFromTimestampFormat(importText);

        expect(controller.currentChapters.length, equals(3));
        expect(
          controller.currentChapters[0].formattedStartTime,
          equals('00:00'),
        );
        expect(
          controller.currentChapters[1].formattedStartTime,
          equals('02:15'),
        );
        expect(
          controller.currentChapters[2].formattedStartTime,
          equals('05:10'),
        );
      },
    );
  });

  group('AudioTrackItem Tests', () {
    test('audio track item properties initialize correctly', () {
      final track = AudioTrackItem(
        id: 'track_es',
        languageCode: 'es',
        languageName: 'Spanish',
        audioUrl: 'https://example.com/audio_es.m4a',
        isResolved: true,
      );

      expect(track.id, equals('track_es'));
      expect(track.languageCode, equals('es'));
      expect(track.languageName, equals('Spanish'));
      expect(track.isBaseTrack, isFalse);
      expect(track.isResolved, isTrue);
    });
  });

  group('DashboardController Reactivity Tests', () {
    late DashboardController controller;

    setUp(() {
      Get.reset();
      controller = DashboardController(
        channelId: 'test_channel_123',
        autoInitialize: false,
      );
    });

    test('filteredVideos returns reactive copy and filters properly', () {
      final v1 = Video(
        id: 'v1',
        title: 'Flutter Tutorial',
        description: 'Learn Flutter',
        thumbnailUrl: '',
        ownerId: 'u1',
        channelId: 'c1',
        channelName: 'Channel',
        category: 'Tech',
        tags: const ['flutter'],
      );
      final v2 = Video(
        id: 'v2',
        title: 'Cooking Pasta',
        description: 'Italian recipe',
        thumbnailUrl: '',
        ownerId: 'u1',
        channelId: 'c1',
        channelName: 'Channel',
        category: 'Food',
        tags: const ['cooking'],
      );

      controller.recentVideos.assignAll([v1, v2]);
      expect(controller.filteredVideos.length, equals(2));

      controller.searchQuery.value = 'pasta';
      expect(controller.filteredVideos.length, equals(1));
      expect(controller.filteredVideos.first.id, equals('v2'));

      controller.searchQuery.value = '';
      expect(controller.filteredVideos.length, equals(2));
    });

    testWidgets(
      'Obx with analyticsData.toList() does not throw GetX improper use error',
      (tester) async {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Obx(() {
              final data = controller.analyticsData.toList();
              return Text('Count: ${data.length}');
            }),
          ),
        );

        expect(find.text('Count: 0'), findsOneWidget);

        controller.analyticsData.assignAll([
          AnalyticsData(DateTime(2026), 100),
          AnalyticsData(DateTime(2026, 1, 2), 250),
        ]);
        await tester.pump();

        expect(find.text('Count: 2'), findsOneWidget);
      },
    );

    test(
      'channelStats revenue reflects actual computed earnings (e.g. ₹9.60)',
      () {
        controller.rxMembershipsRevenue.value = 9.60;
        controller.updateRevenueStats();

        expect(controller.rxTotalRevenue.value, equals(9.60));
        expect(controller.channelStats['revenue'], equals('₹9.60'));
        expect(controller.channelStats['revenueChange'], equals('+₹9.60'));
      },
    );

    test(
      'channelStats dynamically formats revenue and does not trap stale ₹0.00',
      () {
        // Simulate initial zero revenue
        controller.channelStats.value = {
          'revenue': '₹0.00',
          'revenueChange': '+₹0.00',
        };

        // Now revenue becomes available (e.g., from authentic tier supporter of $0.10 USD)
        controller.rxMembershipsRevenue.value = 9.60;
        controller.updateRevenueStats();

        expect(controller.channelStats['revenue'], equals('₹9.60'));
        expect(controller.channelStats['revenueChange'], equals('+₹9.60'));
      },
    );

    test(
      'bidirectional sync between RevenueAnalyticsController and DashboardController',
      () {
        Get.put<DashboardController>(controller);
        final revCtrl = Get.put(RevenueAnalyticsController());
        revCtrl.channelId.value = 'test_channel_123';
        revCtrl.membershipsRevenue.value = 9.60;

        // When RevenueAnalyticsController recalculates, it should sync to matching DashboardController
        revCtrl.setCurrencyView('INR'); // triggers _recalculateTotal

        expect(controller.rxMembershipsRevenue.value, equals(9.60));
        expect(controller.channelStats['revenue'], equals('₹9.60'));
      },
    );

    test(
      'channelStats reconciles views and watch time to match authentic video sums (15 views, 35 mins)',
      () {
        // Initial state: channel document has stale 5 views and 4 mins (240s) watch time
        controller.channelStats.value = {
          'views': '5',
          'watchTime': '4 mins',
        };
        controller.totalWatchTimeSeconds.value = 240;

        // Active videos have 10 views (1200s) and 5 views (900s) -> total 15 views, 2100s (35 mins)
        final v1 = Video(
          id: 'v_sync_1',
          title: 'Truth Fact Check',
          description: '',
          thumbnailUrl: '',
          ownerId: 'u1',
          channelId: 'test_channel_123',
          channelName: 'Truth Channel',
          category: 'News',
          tags: const ['news'],
          views: 10,
          viewCount: 10,
          totalWatchTimeSeconds: 1200, // 20 mins
        );
        final v2 = Video(
          id: 'v_sync_2',
          title: 'Dubbed Video',
          description: '',
          thumbnailUrl: '',
          ownerId: 'u1',
          channelId: 'test_channel_123',
          channelName: 'Truth Channel',
          category: 'News',
          tags: const ['news'],
          views: 5,
          viewCount: 5,
          totalWatchTimeSeconds: 900, // 15 mins
        );

        controller.applyRecentVideosForTest([v1, v2]);

        // Dashboard overview must now reflect true 15 views and 35 mins, not stale 5 and 4 mins
        expect(controller.channelStats['views'], equals('15'));
        expect(controller.channelStats['watchTime'], equals('35 mins'));
        expect(controller.totalWatchTimeSeconds.value, equals(2100));
      },
    );

    test(
      'syncMetricsFromAnalytics updates views and watch time and never downgrades',
      () {
        controller.channelStats.value = {
          'views': '5',
          'watchTime': '4 mins',
        };
        controller.totalWatchTimeSeconds.value = 240;

        controller.syncMetricsFromAnalytics(views: 15, watchTimeSeconds: 2100);

        expect(controller.channelStats['views'], equals('15'));
        expect(controller.channelStats['watchTime'], equals('35 mins'));
        expect(controller.totalWatchTimeSeconds.value, equals(2100));

        // If an older/stale event sends lower numbers, it must never downgrade
        controller.syncMetricsFromAnalytics(views: 3, watchTimeSeconds: 100);
        expect(controller.channelStats['views'], equals('15'));
        expect(controller.channelStats['watchTime'], equals('35 mins'));
        expect(controller.totalWatchTimeSeconds.value, equals(2100));
      },
    );

    test(
      'channelStats reconciles down from inflated 27 views to authentic 15 views (8 + 7 views)',
      () {
        // Initial state: channel document or stale counter has 27 views
        controller.channelStats.value = {
          'views': '27',
          'watchTime': '50 mins',
        };
        controller.totalWatchTimeSeconds.value = 3000;

        // Active videos have 8 views and 7 views -> total 15 views
        final v1 = Video(
          id: 'v_bug_1',
          title: 'Truth World Video 1',
          description: '',
          thumbnailUrl: '',
          ownerId: 'u1',
          channelId: 'test_channel_123',
          channelName: 'Truth Channel',
          category: 'News',
          tags: const ['news'],
          views: 8,
          viewCount: 8,
          totalWatchTimeSeconds: 960, // 16 mins
        );
        final v2 = Video(
          id: 'v_bug_2',
          title: 'Truth World Video 2',
          description: '',
          thumbnailUrl: '',
          ownerId: 'u1',
          channelId: 'test_channel_123',
          channelName: 'Truth Channel',
          category: 'News',
          tags: const ['news'],
          views: 7,
          viewCount: 7,
          totalWatchTimeSeconds: 840, // 14 mins
        );

        controller.applyRecentVideosForTest([v1, v2]);

        // Dashboard overview must now display authentic 15 views, NOT stale 27 views
        expect(controller.channelStats['views'], equals('15'));
        expect(controller.channelStats['watchTime'], equals('30 mins'));
        expect(controller.totalWatchTimeSeconds.value, equals(1800));
      },
    );

    test(
      'syncMetricsFromAnalytics reconciles down from inflated 27 views to authentic 15 views',
      () {
        // Active videos have 8 and 7 views (sum = 15 views)
        final v1 = Video(
          id: 'v_sync_1',
          title: 'Video 1',
          description: '',
          thumbnailUrl: '',
          ownerId: 'u1',
          channelId: 'test_channel_123',
          channelName: 'Truth Channel',
          category: 'News',
          tags: const [],
          views: 8,
          viewCount: 8,
          totalWatchTimeSeconds: 1000,
        );
        final v2 = Video(
          id: 'v_sync_2',
          title: 'Video 2',
          description: '',
          thumbnailUrl: '',
          ownerId: 'u1',
          channelId: 'test_channel_123',
          channelName: 'Truth Channel',
          category: 'News',
          tags: const [],
          views: 7,
          viewCount: 7,
          totalWatchTimeSeconds: 800,
        );
        controller.recentVideos.assignAll([v1, v2]);

        // Channel overview is currently inflated to 27 views
        controller.channelStats.value = {
          'views': '27',
          'watchTime': '50 mins',
        };
        controller.totalWatchTimeSeconds.value = 3000;

        // Analytics reports authentic 15 views (matching total active video views)
        controller.syncMetricsFromAnalytics(views: 15, watchTimeSeconds: 1800);

        // Dashboard overview must now reconcile down to 15 views
        expect(controller.channelStats['views'], equals('15'));
        expect(controller.channelStats['watchTime'], equals('30 mins'));

        // Stale out-of-order lower events below total video views are still rejected
        controller.syncMetricsFromAnalytics(views: 5, watchTimeSeconds: 600);
        expect(controller.channelStats['views'], equals('15'));
        expect(controller.channelStats['watchTime'], equals('30 mins'));
      },
    );

    test(
      'refreshData executes and safely resets isRefreshing flag',
      () async {
        expect(controller.isRefreshing, isFalse);
        final refreshFuture = controller.refreshData();
        await refreshFuture;
        expect(controller.isRefreshing, isFalse);
      },
    );
  });
}
