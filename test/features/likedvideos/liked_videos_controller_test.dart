import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/likedvideos/presentation/controllers/likedvideos_controller.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  group('LikedVideosController Feature Tests', () {
    late LikedVideosController controller;

    setUp(() {
      Get.reset();
      Get.put<AuthService>(AuthService());
      controller = LikedVideosController();
    });

    test('initial state has empty video list and default sorting', () {
      expect(controller.videos, isEmpty);
      expect(controller.sortBy.value, equals('recent'));
      expect(controller.isAscending.value, isFalse);
      expect(controller.selectedCategory.value, equals('All'));
      expect(controller.isListView.value, isTrue);
    });

    test('view mode toggling between list and grid operates reactively', () {
      expect(controller.isListView.value, isTrue);
      controller.isListView.value = false;
      expect(controller.isListView.value, isFalse);
      controller.isListView.value = true;
      expect(controller.isListView.value, isTrue);
    });

    test('sorting criteria and category updates propagate reactively', () {
      controller.selectedCategory.value = 'Science & Tech';
      expect(controller.selectedCategory.value, equals('Science & Tech'));

      controller.sortBy.value = 'likes';
      expect(controller.sortBy.value, equals('likes'));

      controller.isAscending.value = true;
      expect(controller.isAscending.value, isTrue);
    });

    test('fetchLikedVideos handles unauthenticated gracefully', () async {
      await controller.fetchLikedVideos();
      expect(controller.rxErrorMessage.value, equals('User not authenticated'));
    });
  });
}
