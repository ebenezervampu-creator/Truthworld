import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/create_content_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_controller.dart';
import 'package:truthworld/features/video/presentation/views/upload/components/create_content_footer_actions.dart';
import 'package:truthworld/features/video/presentation/views/upload/models/upload_type.dart';
import 'package:truthworld/features/video/presentation/views/upload/widgets/create_content_category_visibility_sections.dart';

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

  Channel createTestChannel({String id = 'chan-123', String name = 'Truth Channel'}) {
    return Channel(
      id: id,
      name: name,
      nameLowercase: name.toLowerCase(),
      handle: '@$name',
      handleLowercase: '@${name.toLowerCase()}',
      description: 'Channel for testing',
      avatarUrl: 'https://example.com/avatar.jpg',
      bannerUrl: '',
      ownerId: 'user-1',
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
      walletBalanceUSD: 50.0,
    );
  }

  group('Video Scheduling in Creator Studio Upload Tests', () {
    test('1. VideoMapParser correctly parses scheduled video status and timestamp', () {
      final scheduledTime = DateTime.now().add(const Duration(days: 2));
      final map = {
        'id': 'vid-sched-123',
        'title': 'Scheduled Sermon Video',
        'status': 'scheduled',
        'visibility': 'private',
        'targetVisibility': 'public',
        'scheduledTime': Timestamp.fromDate(scheduledTime),
        'channelName': 'Truth Channel',
        'channelId': 'chan-123',
      };

      final video = Video.fromMap(map, 'vid-sched-123');
      expect(video.status, equals(VideoStatus.scheduled));
      expect(video.isScheduled, isTrue);
      expect(video.scheduledPublishAt, isNotNull);
      expect(video.scheduledPublishAt!.year, equals(scheduledTime.year));
      expect(video.scheduledPublishAt!.month, equals(scheduledTime.month));
      expect(video.scheduledPublishAt!.day, equals(scheduledTime.day));
    });

    test('2. CreateContentController restores scheduled state from video draft', () {
      final uploadCtrl = Get.put(UploadController());
      final schedDate = DateTime.now().add(const Duration(days: 3, hours: 4));

      final scheduledVideo = Video(
        id: 'sched-vid-001',
        title: 'Upcoming Documentary',
        description: 'Scheduled for next week',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        channelName: 'Truth Channel',
        channelId: 'chan-123',
        ownerId: 'user-1',
        category: 'Education',
        tags: ['truth', 'documentary'],
        status: VideoStatus.scheduled,
        scheduledPublishAt: schedDate,
      );

      final contentCtrl = Get.put(
        CreateContentController(
          uploadType: UploadType.video,
          existingVideo: scheduledVideo,
        ),
      );

      expect(uploadCtrl.isScheduled.value, isTrue);
      expect(uploadCtrl.scheduledDate.value, equals(schedDate));
      expect(contentCtrl.titleController.text, equals('Upcoming Documentary'));
    });

    test('3. canPublishVideo() rejects past schedule dates and accepts future dates', () {
      final uploadCtrl = Get.put(UploadController());
      final contentCtrl = Get.put(CreateContentController(uploadType: UploadType.video));

      uploadCtrl.videoUrl.value = 'https://example.com/video.mp4';
      uploadCtrl.thumbnailUrl.value = 'https://example.com/thumb.jpg';
      uploadCtrl.selectedCategory.value = 'Education';
      uploadCtrl.selectedChannel.value = createTestChannel();

      // Normal publish mode: should be ready
      uploadCtrl.isScheduled.value = false;
      expect(contentCtrl.canPublishVideo(), isTrue);

      // In schedule mode with past date: must be false
      uploadCtrl.isScheduled.value = true;
      uploadCtrl.scheduledDate.value = DateTime.now().subtract(const Duration(hours: 1));
      expect(contentCtrl.canPublishVideo(), isFalse);

      // In schedule mode with future date: must be true
      uploadCtrl.scheduledDate.value = DateTime.now().add(const Duration(days: 1));
      expect(contentCtrl.canPublishVideo(), isTrue);
    });

    testWidgets('4. CreateContentVisibilitySection renders visibility dropdown and schedule controls', (tester) async {
      final uploadCtrl = Get.put(UploadController());
      uploadCtrl.isScheduled.value = false;
      uploadCtrl.selectedVisibility.value = 'Public';

      await tester.pumpWidget(
        GetMaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: CreateContentVisibilitySection(uploadController: uploadCtrl),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Section header and dropdown are rendered
      expect(find.text('7. Visibility'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
      expect(find.text('Choose when to publish and who can see your video.'), findsOneWidget);

      // Default value is Public
      expect(find.text('Public'), findsOneWidget);

      // Tap dropdown to open menu
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();

      // Options should be present in menu
      expect(find.text('Schedule').last, findsOneWidget);
      expect(find.text('Private').last, findsOneWidget);
      expect(find.text('Unlisted').last, findsOneWidget);

      // Select 'Schedule' from dropdown
      await tester.tap(find.text('Schedule').last);
      await tester.pumpAndSettle();

      expect(uploadCtrl.isScheduled.value, isTrue);
      expect(find.text('Video will be private until published'), findsOneWidget);
    });

    testWidgets('5. Desktop Footer renders Save (renamed), Publish (renamed) and Schedule buttons', (tester) async {
      final uploadCtrl = Get.put(UploadController());
      final contentCtrl = Get.put(CreateContentController(uploadType: UploadType.video));
      uploadCtrl.isScheduled.value = false;

      await tester.pumpWidget(
        GetMaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: CreateContentDesktopFooterActions(
              contentController: contentCtrl,
              uploadController: uploadCtrl,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify renames and buttons:
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Save Draft'), findsNothing);
      expect(find.text('Publish'), findsOneWidget);
      expect(find.text('Publish Video'), findsNothing);
      expect(find.text('Schedule'), findsOneWidget);

      // Tap Schedule button to switch to schedule mode
      await tester.tap(find.text('Schedule'));
      await tester.pumpAndSettle();

      expect(uploadCtrl.isScheduled.value, isTrue);
      // Primary button is now Schedule, and secondary button allows switching to Publish
      expect(find.text('Schedule'), findsOneWidget);
      expect(find.text('Publish'), findsOneWidget);
    });

    testWidgets('6. Mobile Footer renders Save, Schedule and Publish buttons', (tester) async {
      final uploadCtrl = Get.put(UploadController());
      final contentCtrl = Get.put(CreateContentController(uploadType: UploadType.video));
      uploadCtrl.isScheduled.value = false;

      await tester.pumpWidget(
        GetMaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: CreateContentMobileFooterActions(
              contentController: contentCtrl,
              uploadController: uploadCtrl,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Publish'), findsOneWidget);
      expect(find.text('Schedule'), findsOneWidget);
    });
  });
}
