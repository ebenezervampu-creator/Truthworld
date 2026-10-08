import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/watchlater/presentation/controllers/watchlater_controller.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  group('WatchLaterController Feature Tests', () {
    late WatchLaterController controller;

    setUp(() {
      Get.reset();
      Get.testMode = true;
      Get.put<AuthService>(AuthService());
      controller = WatchLaterController();
    });

    test('initial state has default filters and empty video list', () {
      expect(controller.watchLaterVideos, isEmpty);
      expect(controller.selectedCategory.value, equals('All'));
      expect(controller.sortBy.value, equals('recent'));
      expect(controller.isAscending.value, isFalse);
      expect(controller.showFab.value, isTrue);
    });

    test('category, sorting, and view updates execute reactively', () {
      controller.selectedCategory.value = 'Technology';
      expect(controller.selectedCategory.value, equals('Technology'));

      controller.sortBy.value = 'views';
      expect(controller.sortBy.value, equals('views'));

      controller.isAscending.value = true;
      expect(controller.isAscending.value, isTrue);
    });

    test('showFab state can be toggled reactively', () {
      expect(controller.showFab.value, isTrue);
      controller.showFab.value = false;
      expect(controller.showFab.value, isFalse);
      controller.showFab.value = true;
      expect(controller.showFab.value, isTrue);
    });
  });
}
