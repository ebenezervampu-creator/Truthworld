import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/topic_management_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/topics/edit_topic/edit_topic_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/topics/edit_topic/edit_topic_dialog.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/theme/app_theme.dart';
import '../../test_helpers/mock_firebase.dart';

class FakeTopicManagementController extends TopicManagementController {
  bool updateTopicResult = true;
  bool updateTopicCalled = false;
  Topic? lastUpdatedTopic;
  String? lastUpdatedTitle;
  List<String>? lastSelectedVideoIds;

  @override
  Future<List<Map<String, dynamic>>> fetchChannelVideos(String channelId) async {
    return [
      {
        'id': 'v1',
        'title': 'Test Video 1',
        'thumbnailUrl': 'https://example.com/thumb1.jpg',
      },
      {
        'id': 'v2',
        'title': 'Test Video 2',
        'thumbnailUrl': 'https://example.com/thumb2.jpg',
      },
    ];
  }

  @override
  Future<List<String>> fetchTopicVideos(String topicSlug) async {
    return ['v1'];
  }

  @override
  Future<bool> updateTopic({
    required Topic topic,
    required String title,
    required String description,
    required String category,
    required List<String> selectedVideoIds,
    required TopicVisibilityType visibilityType,
    String? accessCode,
    String? thumbnailUrl,
    bool showSuccessFeedback = false,
  }) async {
    updateTopicCalled = true;
    lastUpdatedTopic = topic;
    lastUpdatedTitle = title;
    lastSelectedVideoIds = selectedVideoIds;
    return updateTopicResult;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  late Topic sampleTopic;
  late FakeTopicManagementController fakeMgmtController;

  setUp(() {
    Get.reset();
    Get.testMode = true;
    if (!Get.isRegistered<AuthService>()) {
      Get.put<AuthService>(AuthService(), permanent: true);
    }
    fakeMgmtController = FakeTopicManagementController();
    sampleTopic = Topic(
      id: 'topic_123',
      title: 'Christian songs',
      slug: 'christian-songs',
      handle: 'christiansongs',
      handleLowercase: 'christiansongs',
      description: 'Gospel and spiritual songs',
      category: 'Music',
      thumbnailUrl: 'https://example.com/thumb1.jpg',
      channelId: 'ch_1',
      creatorId: 'user_1',
      videoCount: 1,
      featuredVideoIds: ['v1'],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  });

  tearDown(Get.reset);

  group('EditTopicController Logic Tests', () {
    test('initializes with topic values and loads linked videos', () async {
      final ctrl = EditTopicController(
        topic: sampleTopic,
        channelId: 'ch_1',
        managementController: fakeMgmtController,
      );

      ctrl.onInit();
      expect(ctrl.titleController.text, 'Christian songs');
      expect(ctrl.descriptionController.text, 'Gospel and spiritual songs');
      expect(ctrl.categoryController.text, 'Music');
      expect(ctrl.selectedVisibility.value, TopicVisibilityType.public);

      await ctrl.loadData();
      expect(ctrl.channelVideos.length, 2);
      expect(ctrl.selectedVideoIds, contains('v1'));
      expect(ctrl.chosenVideoThumbnailUrl.value, 'https://example.com/thumb1.jpg');
      expect(ctrl.isLoading.value, isFalse);

      ctrl.onClose();
    });

    test('submitUpdate fails when title is too short', () async {
      final ctrl = EditTopicController(
        topic: sampleTopic,
        channelId: 'ch_1',
        managementController: fakeMgmtController,
      );
      ctrl.onInit();
      await ctrl.loadData();

      ctrl.titleController.text = 'AB';
      await ctrl.submitUpdate();

      expect(fakeMgmtController.updateTopicCalled, isFalse);
      expect(ctrl.isSaving.value, isFalse);
      ctrl.onClose();
    });

    test('submitUpdate fails when no videos are selected', () async {
      final ctrl = EditTopicController(
        topic: sampleTopic,
        channelId: 'ch_1',
        managementController: fakeMgmtController,
      );
      ctrl.onInit();
      await ctrl.loadData();

      ctrl.selectedVideoIds.clear();
      await ctrl.submitUpdate();

      expect(fakeMgmtController.updateTopicCalled, isFalse);
      expect(ctrl.isSaving.value, isFalse);
      ctrl.onClose();
    });

    test('submitUpdate successfully calls updateTopic and resets isSaving', () async {
      final ctrl = EditTopicController(
        topic: sampleTopic,
        channelId: 'ch_1',
        managementController: fakeMgmtController,
      );
      ctrl.onInit();
      await ctrl.loadData();

      ctrl.titleController.text = 'Updated Worship Songs';
      await ctrl.submitUpdate();

      expect(fakeMgmtController.updateTopicCalled, isTrue);
      expect(fakeMgmtController.lastUpdatedTitle, 'Updated Worship Songs');
      expect(ctrl.isSaving.value, isFalse);
      ctrl.onClose();
    });
  });

  group('EditTopicDialog Widget and Interaction Tests', () {
    testWidgets('renders Edit Topic dialog UI with all required controls', (tester) async {
      await tester.pumpWidget(
        GetMaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  EditTopicDialog.show(
                    context: ctx,
                    topic: sampleTopic,
                    channelId: 'ch_1',
                    isDarkMode: true,
                    controller: fakeMgmtController,
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Topic'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(find.text('Topic Title'), findsOneWidget);
      expect(find.text('Description'), findsOneWidget);
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Visibility Type'), findsOneWidget);
      expect(find.text('Topic Thumbnail'), findsOneWidget);
      expect(find.text('Use Video Thumbnail'), findsOneWidget);
      expect(find.text('Upload Custom'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);
    });

    testWidgets('Cancel button dismisses dialog cleanly and deletes controller', (tester) async {
      await tester.pumpWidget(
        GetMaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  EditTopicDialog.show(
                    context: ctx,
                    topic: sampleTopic,
                    channelId: 'ch_1',
                    isDarkMode: true,
                    controller: fakeMgmtController,
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();
      expect(find.text('Edit Topic'), findsOneWidget);
      expect(Get.isRegistered<EditTopicController>(tag: sampleTopic.slug), isTrue);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Topic'), findsNothing);
      expect(Get.isRegistered<EditTopicController>(tag: sampleTopic.slug), isFalse);
    });

    testWidgets('Save Changes calls updateTopic, pops dialog, and deletes controller', (tester) async {
      await tester.pumpWidget(
        GetMaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  EditTopicDialog.show(
                    context: ctx,
                    topic: sampleTopic,
                    channelId: 'ch_1',
                    isDarkMode: true,
                    controller: fakeMgmtController,
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();
      expect(find.text('Edit Topic'), findsOneWidget);

      // Tap Save Changes
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      expect(fakeMgmtController.updateTopicCalled, isTrue);
      // Dialog must be popped and closed
      expect(find.text('Edit Topic'), findsNothing);
      expect(Get.isRegistered<EditTopicController>(tag: sampleTopic.slug), isFalse);
    });
  });
}
