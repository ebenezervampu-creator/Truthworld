import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/watchhistory/presentation/controllers/watch_history_controller.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  group('WatchHistoryController Feature Tests', () {
    late WatchHistoryController controller;

    setUp(() {
      Get.reset();
      Get.put<AuthService>(AuthService());
      controller = WatchHistoryController();
    });

    test('initial state and filtering setup properly', () {
      expect(controller.searchQuery.value, isEmpty);
      expect(controller.isSearching.value, isFalse);
      expect(controller.sortBy.value, equals('recent'));
      expect(controller.isAscending.value, isFalse);
      expect(controller.selectedCategory.value, equals('All'));

      controller.searchQuery.value = 'Investigative Report';
      expect(controller.searchQuery.value, equals('Investigative Report'));

      controller.selectedCategory.value = 'News';
      expect(controller.selectedCategory.value, equals('News'));
    });

    test('retry triggers refresh sequence safely', () {
      expect(controller.refreshTrigger.value, equals(0));
      controller.retry();
      expect(controller.refreshTrigger.value, equals(1));
    });
  });
}
