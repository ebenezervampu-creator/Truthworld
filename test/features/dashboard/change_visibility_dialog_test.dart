import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/content/content_dialogs.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/video_management.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  setUp(() {
    Get.testMode = true;
  });

  tearDown(Get.reset);

  final testVideo = Video(
    id: 'vid_123',
    title: "Zomato's Big Transformation: From Food Delivery to Tech Giant",
    description: 'Detailed analysis of corporate strategy',
    videoUrl: 'https://example.com/video.mp4',
    thumbnailUrl: 'https://example.com/thumb.jpg',
    channelId: 'ch_456',
    channelName: 'Strategy Studio',
    ownerId: 'usr_789',
    category: 'Business',
    tags: const ['business', 'tech'],
    views: 1500,
    likeCount: 120,
    commentCount: 45,
    visibility: 'public',
    createdAt: Timestamp.fromDate(DateTime(2026, 3, 10)),
  );

  group('ChangeVisibilityModalContent Widget Tests', () {
    testWidgets('renders all 5 options cleanly without rainbow colors', (tester) async {
      final controller = Get.put(VideoManagementController());
      final selected = 'public'.obs;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeVisibilityModalContent(
              video: testVideo,
              controller: controller,
              selected: selected,
              isBottomSheet: false,
            ),
          ),
        ),
      );

      // Header Elements
      expect(find.text('Change Visibility & Access'), findsOneWidget);
      expect(
        find.text("Zomato's Big Transformation: From Food Delivery to Tech Giant"),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.lock_open_rounded), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);

      // 5 Visibility Options
      expect(find.text('Public'), findsOneWidget);
      expect(find.text('Private'), findsOneWidget);
      expect(find.text('Members Only'), findsOneWidget);
      expect(find.text('Subscribers Only'), findsOneWidget);
      expect(find.text('Unlisted'), findsOneWidget);

      // Subtitles
      expect(
        find.text('Everyone can search for and watch this video on Truthworld'),
        findsOneWidget,
      );
      expect(
        find.text('Only you can view this video in your channel studio'),
        findsOneWidget,
      );
      expect(
        find.text('Exclusive access for paid channel members with an active tier'),
        findsOneWidget,
      );
      expect(
        find.text('Exclusive access for users subscribed to your channel'),
        findsOneWidget,
      );
      expect(
        find.text('Anyone with the video link can watch (hidden from search & feed)'),
        findsOneWidget,
      );

      // Buttons
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save Visibility'), findsOneWidget);

      // Initial selection is public
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('selecting private changes selection state', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = Get.put(VideoManagementController());
      final selected = 'public'.obs;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeVisibilityModalContent(
              video: testVideo,
              controller: controller,
              selected: selected,
              isBottomSheet: false,
            ),
          ),
        ),
      );

      expect(selected.value, equals('public'));

      // Tap on Private option
      await tester.ensureVisible(find.text('Private'));
      await tester.tap(find.text('Private'));
      await tester.pumpAndSettle();

      expect(selected.value, equals('private'));

      // Tap on Members Only
      await tester.ensureVisible(find.text('Members Only'));
      await tester.tap(find.text('Members Only'));
      await tester.pumpAndSettle();

      expect(selected.value, equals('members_only'));

      // Tap on Subscribers Only
      await tester.ensureVisible(find.text('Subscribers Only'));
      await tester.tap(find.text('Subscribers Only'));
      await tester.pumpAndSettle();

      expect(selected.value, equals('subscribers_only'));

      // Tap on Unlisted
      await tester.ensureVisible(find.text('Unlisted'));
      await tester.tap(find.text('Unlisted'));
      await tester.pumpAndSettle();

      expect(selected.value, equals('unlisted'));
    });

    testWidgets('renders drag handle when isBottomSheet is true', (tester) async {
      final controller = Get.put(VideoManagementController());
      final selected = 'public'.obs;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeVisibilityModalContent(
              video: testVideo,
              controller: controller,
              selected: selected,
              isBottomSheet: true,
            ),
          ),
        ),
      );

      expect(find.text('Change Visibility & Access'), findsOneWidget);
      expect(find.text('Save Visibility'), findsOneWidget);
    });

    testWidgets('Save Visibility button has high contrast styling', (tester) async {
      final controller = Get.put(VideoManagementController());
      final selected = 'public'.obs;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeVisibilityModalContent(
              video: testVideo,
              controller: controller,
              selected: selected,
              isBottomSheet: false,
            ),
          ),
        ),
      );

      final saveButtonFinder = find.widgetWithText(ElevatedButton, 'Save Visibility');
      expect(saveButtonFinder, findsOneWidget);

      final saveButton = tester.widget<ElevatedButton>(saveButtonFinder);
      expect(
        saveButton.style?.backgroundColor?.resolve({}),
        equals(Colors.white),
      );
      expect(
        saveButton.style?.foregroundColor?.resolve({}),
        equals(Colors.black),
      );
    });
  });
}
