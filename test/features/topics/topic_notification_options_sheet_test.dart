import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/presentation/controllers/following_topics_controller.dart';
import 'package:truthworld/features/topics/presentation/widgets/topic_notification_options_sheet.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  tearDown(Get.reset);

  final sampleTopic = Topic(
    id: 'topic_tech_01',
    title: 'Artificial Intelligence',
    slug: 'artificial-intelligence',
    handle: '@artificial-intelligence',
    handleLowercase: '@artificial-intelligence',
    description: 'Latest breakthroughs in artificial intelligence and deep learning.',
    category: 'technology',
    tags: ['ai', 'tech'],
    videoCount: 10,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  group('TopicNotificationOptionsSheet', () {
    testWidgets('renders Options title, all 3 notification settings, divider and unfollow',
        (tester) async {
      Get.testMode = true;
      final controller = FollowingTopicsController();
      controller.topicNotificationSettings[sampleTopic.id] = 'all';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TopicNotificationOptionsSheet(
              topic: sampleTopic,
              controller: controller,
            ),
          ),
        ),
      );

      // Verify header
      expect(find.text('Options'), findsOneWidget);

      // Verify Option 1: All
      expect(find.text('All'), findsOneWidget);
      expect(find.text("You'll get all notifications"), findsOneWidget);
      expect(find.byIcon(Icons.notifications_active_rounded), findsOneWidget);

      // Verify Option 2: Personalized
      expect(find.text('Personalized'), findsOneWidget);
      expect(find.text("You'll get personalized notifications"), findsOneWidget);
      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);

      // Verify Option 3: None
      expect(find.text('None'), findsOneWidget);
      expect(find.text('Turn off all notifications'), findsOneWidget);
      expect(find.byIcon(Icons.notifications_off_outlined), findsOneWidget);

      // Verify Divider
      expect(find.byType(Divider), findsOneWidget);

      // Verify Option 4: Unfollow
      expect(find.text('Unfollow'), findsOneWidget);
      expect(find.byIcon(Icons.person_remove_outlined), findsOneWidget);

      // Trailing checkmark should be on 'All'
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('shows checkmark on Personalized when setting is personalized', (tester) async {
      Get.testMode = true;
      final controller = FollowingTopicsController();
      controller.topicNotificationSettings[sampleTopic.id] = 'personalized';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TopicNotificationOptionsSheet(
              topic: sampleTopic,
              controller: controller,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('shows checkmark on None when setting is none', (tester) async {
      Get.testMode = true;
      final controller = FollowingTopicsController();
      controller.topicNotificationSettings[sampleTopic.id] = 'none';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TopicNotificationOptionsSheet(
              topic: sampleTopic,
              controller: controller,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('tapping Unfollow triggers confirmation dialog', (tester) async {
      Get.testMode = true;
      final controller = FollowingTopicsController();
      controller.followingStates[sampleTopic.id] = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    TopicNotificationOptionsSheet.showUnfollowConfirmation(
                      context,
                      topic: sampleTopic,
                      controller: controller,
                    );
                  },
                  child: const Text('Show Dialog'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Verify confirmation dialog contents
      expect(find.text('Unfollow Artificial Intelligence?'), findsOneWidget);
      expect(
        find.text('You will no longer receive notifications or updates for this topic.'),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Unfollow'), findsOneWidget);

      // Tap Cancel to dismiss
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Unfollow Artificial Intelligence?'), findsNothing);
    });
  });
}
