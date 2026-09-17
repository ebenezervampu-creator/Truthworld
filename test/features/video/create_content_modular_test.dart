import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/create_content_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_controller.dart';
import 'package:truthworld/features/video/presentation/views/upload/create_content_screen.dart';
import 'package:truthworld/features/video/presentation/views/upload/models/upload_type.dart';
import '../../pages/page_test_harness.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  setUp(() {
    Get.reset();
    Get.testMode = true;
    if (!Get.isRegistered<AuthService>()) {
      Get.put<AuthService>(AuthService());
    }
  });

  tearDown(Get.reset);

  group('CreateContentController Modular Tests', () {
    test('1. Initializes controllers and text fields cleanly', () {
      final uploadCtrl = Get.put(UploadController());
      final playlistCtrl = Get.put(PlaylistController());
      final ctrl = Get.put(CreateContentController(uploadType: UploadType.video));

      expect(ctrl.uploadController, equals(uploadCtrl));
      expect(ctrl.playlistController, equals(playlistCtrl));
      expect(ctrl.titleController.text, isEmpty);
      expect(ctrl.descriptionController.text, isEmpty);
      expect(ctrl.tagsController.text, isEmpty);
      expect(ctrl.communityTitleController.text, isEmpty);
      expect(ctrl.communityDescriptionController.text, isEmpty);
      expect(ctrl.communityTagsController.text, isEmpty);
      expect(ctrl.canPublishVideo(), isFalse);
    });

    test('2. canPublishVideo validates media, thumb, category, and channel', () {
      final uploadCtrl = Get.put(UploadController());
      Get.put(PlaylistController());
      final ctrl = Get.put(CreateContentController(uploadType: UploadType.video));

      expect(ctrl.canPublishVideo(), isFalse);

      // Add media
      uploadCtrl.videoUrl.value = 'https://example.com/video.mp4';
      expect(ctrl.canPublishVideo(), isFalse);

      // Add thumbnail
      uploadCtrl.thumbnailUrl.value = 'https://example.com/thumb.jpg';
      expect(ctrl.canPublishVideo(), isFalse);

      // Add category
      uploadCtrl.selectedCategory.value = 'Technology';
      expect(ctrl.canPublishVideo(), isFalse);

      // Add channel
      uploadCtrl.selectedChannel.value = Channel(
        id: 'ch-1',
        name: 'Tech Channel',
        nameLowercase: 'tech channel',
        handle: '@tech',
        handleLowercase: '@tech',
        description: 'Testing channel',
        avatarUrl: '',
        bannerUrl: '',
        ownerId: 'user-1',
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      );

      expect(ctrl.canPublishVideo(), isTrue);
    });

    test('3. Prepopulates form fields when initialized with existingVideo', () {
      final uploadCtrl = Get.put(UploadController());
      Get.put(PlaylistController());

      final video = Video(
        id: 'vid-101',
        title: 'Existing Draft Video',
        description: 'Existing Draft Description',
        videoUrl: 'https://example.com/existing.mp4',
        thumbnailUrl: 'https://example.com/existing_thumb.jpg',
        channelId: 'ch-1',
        channelName: 'Test Channel',
        ownerId: 'user-1',
        category: 'Technology',
        tags: const ['news', 'tech'],
      );

      final ctrl = Get.put(CreateContentController(
        uploadType: UploadType.video,
        existingVideo: video,
      ));

      expect(ctrl.titleController.text, equals('Existing Draft Video'));
      expect(ctrl.descriptionController.text, equals('Existing Draft Description'));
      expect(ctrl.tagsController.text, equals('news, tech'));
      expect(uploadCtrl.videoUrl.value, equals('https://example.com/existing.mp4'));
      expect(uploadCtrl.thumbnailUrl.value, equals('https://example.com/existing_thumb.jpg'));
      expect(uploadCtrl.selectedCategory.value, equals('Technology'));
    });

    test('4. Disposes form controllers cleanly', () {
      Get.put(UploadController());
      Get.put(PlaylistController());
      final ctrl = Get.put(CreateContentController(uploadType: UploadType.video));

      Get.delete<CreateContentController>();
      expect(ctrl.isClosed, isTrue);
    });

    testWidgets('5. CreateContentScreen (Video) renders cleanly via pumpPageInHarness', (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      await pumpPageInHarness(
        tester,
        const CreateContentScreen(uploadType: UploadType.video),
        onBeforePump: () {
          Get.put<UploadController>(UploadController());
        },
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(CreateContentScreen), findsOneWidget);
    });

    testWidgets('6. CreateContentScreen (Community) renders cleanly via pumpPageInHarness', (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      await pumpPageInHarness(
        tester,
        const CreateContentScreen(uploadType: UploadType.communityPost),
        onBeforePump: () {
          Get.put<UploadController>(UploadController());
        },
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(CreateContentScreen), findsOneWidget);
    });
  });
}
