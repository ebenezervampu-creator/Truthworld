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
      expect(controller.currentChapters[1].startTime, equals(const Duration(minutes: 3)));
      expect(controller.currentChapters[2].title, equals('Outro'));
      expect(controller.currentChapters[2].startTime, equals(const Duration(minutes: 10)));
      expect(controller.hasUnsavedChanges.value, isTrue);
    });

    test('addChapter replaces existing chapter when startTime is duplicated', () {
      controller.addChapter('Original Intro', Duration.zero);
      controller.addChapter('Updated Intro', Duration.zero);

      expect(controller.currentChapters.length, equals(1));
      expect(controller.currentChapters.first.title, equals('Updated Intro'));
      expect(controller.hasUnsavedChanges.value, isTrue);
    });

    test('updateChapter modifies existing chapter properly', () {
      controller.addChapter('Chapter 1', Duration.zero);
      controller.updateChapter(0, title: 'Renamed Chapter 1', startTime: const Duration(seconds: 15));

      expect(controller.currentChapters[0].title, equals('Renamed Chapter 1'));
      expect(controller.currentChapters[0].startTime, equals(const Duration(seconds: 15)));
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
      expect(controller.currentChapters[0].startTime, equals(const Duration(seconds: 35)));

      controller.shiftChapterTiming(0, -10000); // -10 seconds
      expect(controller.currentChapters[0].startTime, equals(const Duration(seconds: 25)));
    });
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
      controller = DashboardController(channelId: 'test_channel_123', autoInitialize: false);
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

    testWidgets('Obx with analyticsData.toList() does not throw GetX improper use error', (tester) async {
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
    });

    test('channelStats revenue reflects actual computed earnings (e.g. ₹9.60)', () {
      controller.rxMembershipsRevenue.value = 9.60;
      controller.updateRevenueStats();

      expect(controller.rxTotalRevenue.value, equals(9.60));
      expect(controller.channelStats['revenue'], equals('₹9.60'));
      expect(controller.channelStats['revenueChange'], equals('+₹9.60'));
    });

    test('channelStats dynamically formats revenue and does not trap stale ₹0.00', () {
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
    });

    test('bidirectional sync between RevenueAnalyticsController and DashboardController', () {
      Get.put<DashboardController>(controller);
      final revCtrl = Get.put(RevenueAnalyticsController());
      revCtrl.channelId.value = 'test_channel_123';
      revCtrl.membershipsRevenue.value = 9.60;

      // When RevenueAnalyticsController recalculates, it should sync to matching DashboardController
      revCtrl.setCurrencyView('INR'); // triggers _recalculateTotal

      expect(controller.rxMembershipsRevenue.value, equals(9.60));
      expect(controller.channelStats['revenue'], equals('₹9.60'));
    });
  });
}
