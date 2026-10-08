import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/features/watchtime/presentation/controllers/watchtime_details_controller.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  group('WatchtimeDetailsController Tests', () {
    setUp(Get.reset);

    test('initializes with default channelId and empty videoItems', () {
      final controller = WatchtimeDetailsController();
      expect(controller.channelId, isEmpty);
      expect(controller.videoItems, isEmpty);
      expect(controller.state, equals(ViewState.idle));
    });

    test('initializes with custom channelId', () {
      final controller = WatchtimeDetailsController(channelId: 'custom_ch_123');
      expect(controller.channelId, equals('custom_ch_123'));
      expect(controller.videoItems, isEmpty);
    });

    test('fetchWatchtimeDetails executes safely and handles failures gracefully', () async {
      final controller = WatchtimeDetailsController(channelId: 'empty_channel');
      await controller.fetchWatchtimeDetails();

      expect(controller.videoItems, isEmpty);
      // Fails-safe via safeExecute and records friendly error
      expect(controller.isError, isTrue);
    });

    test('WatchtimeVideoItem model instantiates with correct default values', () {
      const item = WatchtimeVideoItem(
        id: 'vid_1',
        title: 'Test Video',
      );

      expect(item.id, equals('vid_1'));
      expect(item.title, equals('Test Video'));
      expect(item.totalViews, equals(0));
      expect(item.uniqueUsers, equals(0));
      expect(item.totalWatchSeconds, equals(0));
      expect(item.avgWatchSeconds, equals(0.0));
      expect(item.completionRate, equals(0.0));
      expect(item.fullWatched, equals(0));
      expect(item.halfWatched, equals(0));
      expect(item.under20Sec, equals(0));
    });

    test('WatchtimeVideoItem model retains custom analytical metrics', () {
      const item = WatchtimeVideoItem(
        id: 'vid_2',
        title: 'Analytical Video',
        totalViews: 1500,
        uniqueUsers: 950,
        totalWatchSeconds: 45000,
        avgWatchSeconds: 30.0,
        completionRate: 0.75,
        fullWatched: 600,
        halfWatched: 300,
        under20Sec: 50,
      );

      expect(item.id, equals('vid_2'));
      expect(item.totalViews, equals(1500));
      expect(item.uniqueUsers, equals(950));
      expect(item.totalWatchSeconds, equals(45000));
      expect(item.avgWatchSeconds, equals(30.0));
      expect(item.completionRate, equals(0.75));
      expect(item.fullWatched, equals(600));
      expect(item.halfWatched, equals(300));
      expect(item.under20Sec, equals(50));
    });
  });
}
