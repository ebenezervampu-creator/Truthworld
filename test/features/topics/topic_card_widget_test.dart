import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/presentation/controllers/following_topics_controller.dart';
import 'package:truthworld/features/topics/presentation/widgets/topic_card_widget.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  setUp(() {
    Get.reset();
    Get.put(FollowingTopicsController());
  });

  tearDown(Get.reset);

  final testTopic = Topic(
    id: 'test_topic_1',
    title: 'Technology & AI',
    slug: 'technology-ai',
    category: 'Technology',
    description: 'All about tech and artificial intelligence',
    videoCount: 15,
    followerCount: 250,
    thumbnailUrl: 'https://example.com/thumb.jpg',
    coverImage: 'https://example.com/cover.jpg',
    handle: '#technology',
    handleLowercase: '#technology',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  group('TopicCardWidget Tests', () {
    testWidgets('TopicCardWidget renders topic title, video count, and follower count', (tester) async {
      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: TopicCardWidget(
              topic: testTopic,
              isDashboard: true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Technology & AI'), findsOneWidget);
      expect(find.text('15 Videos'), findsOneWidget);
      expect(find.text('250 Followers'), findsOneWidget);
      expect(find.text('Follow'), findsOneWidget);
      expect(find.byIcon(Icons.reply_rounded), findsOneWidget);
    });

    testWidgets('TopicCardWidget has zero bottom border line artifact in container decoration', (tester) async {
      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: TopicCardWidget(
              topic: testTopic,
              isDashboard: true,
            ),
          ),
        ),
      );
      await tester.pump();

      // Find the main card Container (child of InkWell)
      final inkWellFinder = find.byType(InkWell);
      expect(inkWellFinder, findsWidgets);

      // Verify inkWell has rounded radius 16
      final inkWell = tester.widget<InkWell>(inkWellFinder.first);
      expect(inkWell.borderRadius, equals(BorderRadius.circular(16)));

      // Find the container directly inside InkWell
      final container = inkWell.child! as Container;
      final decoration = container.decoration! as BoxDecoration;

      // Assert that there is NO border on the card container (guaranteeing zero bottom border line bug)
      expect(decoration.border, isNull);
      expect(decoration.borderRadius, equals(BorderRadius.circular(16)));
      expect(decoration.color, equals(const Color(0xFF14171F)));
    });

    testWidgets('TopicCardWidget toggles follow state when follow button is tapped', (tester) async {
      var followToggled = false;
      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: TopicCardWidget(
              topic: testTopic,
              isDashboard: true,
              onFollowToggle: () => followToggled = true,
            ),
          ),
        ),
      );
      await tester.pump();

      final followButtonFinder = find.text('Follow');
      expect(followButtonFinder, findsOneWidget);

      await tester.tap(followButtonFinder);
      await tester.pump();

      expect(followToggled, isTrue);
    });
  });
}
