import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/myvideos/presentation/controllers/my_videos_controller.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  group('MyVideosController Feature Tests', () {
    late MyVideosController controller;

    setUp(() {
      Get.reset();
      Get.testMode = true;
      Get.put<AuthService>(AuthService());
      controller = MyVideosController();
    });

    test('initial state defaults are initialized properly', () {
      expect(controller.videos, isEmpty);
      expect(controller.sortBy.value, equals('recent'));
      expect(controller.isAscending.value, isFalse);
      expect(controller.selectedCategory.value, equals('All'));
      expect(controller.isSearching.value, isFalse);
    });

    test('search query and sorting can be toggled reactively', () {
      controller.searchQuery.value = 'Truthworld Production';
      expect(controller.searchQuery.value, equals('Truthworld Production'));

      controller.sortBy.value = 'views';
      expect(controller.sortBy.value, equals('views'));

      controller.isAscending.value = true;
      expect(controller.isAscending.value, isTrue);
    });

    test('hasChannel returns false when unauthenticated or no channel', () {
      expect(controller.hasChannel, isFalse);
    });

    test('handleUploadTap safely handles unauthenticated/no-channel user', () {
      expect(() => controller.handleUploadTap(), returnsNormally);
    });
  });
}
