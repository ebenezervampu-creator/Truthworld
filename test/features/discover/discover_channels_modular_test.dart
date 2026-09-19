import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/ai/models/ai_search_intent.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_subscription_controller.dart';
import 'package:truthworld/features/discover/presentation/controllers/discover_channels_controller.dart';
import 'package:truthworld/features/discover/presentation/views/discover_channels.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  setUp(() {
    Get.reset();
    if (!Get.isRegistered<AuthService>()) {
      Get.put<AuthService>(AuthService());
    }
    if (!Get.isRegistered<ChannelSubscriptionController>()) {
      Get.put<ChannelSubscriptionController>(ChannelSubscriptionController());
    }
  });

  tearDown(Get.reset);

  group('DiscoverChannels Modular Unit & Widget Tests', () {
    testWidgets('1. DiscoverChannelsAppBar renders title and triggers refresh',
        (tester) async {
      var refreshed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: DiscoverChannelsAppBar(
              onRefresh: () => refreshed = true,
              isDesktop: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Discover Channels'), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
      expect(find.byIcon(Icons.explore_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.refresh_rounded));
      expect(refreshed, isTrue);
    });

    testWidgets('2. DiscoverChannelsDashboardHeader renders correctly in slivers',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                DiscoverChannelsDashboardHeader(
                  padding: EdgeInsets.all(16),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Discover Channels'), findsOneWidget);
      expect(find.byIcon(Icons.explore_rounded), findsOneWidget);
    });

    testWidgets('3. DiscoverSearchBar renders input, formatters, and clear button',
        (tester) async {
      final controller = DiscoverChannelsController();
      Get.put<DiscoverChannelsController>(controller);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DiscoverSearchBar(
              controller: controller,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);

      // Typing updates search query
      await tester.enterText(find.byType(TextField), 'physics');
      await tester.pumpAndSettle();

      expect(controller.searchQuery.value, equals('physics'));
      expect(find.byIcon(Icons.clear_rounded), findsOneWidget);

      // Clear button clears search
      await tester.tap(find.byIcon(Icons.clear_rounded));
      await tester.pumpAndSettle();

      expect(controller.searchQuery.value, isEmpty);
    });

    testWidgets('4. DiscoverAiBanner displays intent, criteria chips, and broadening',
        (tester) async {
      final controller = DiscoverChannelsController();
      Get.put<DiscoverChannelsController>(controller);

      final intent = AiSearchIntent(
        rawQuery: 'telugu science channels',
        detectedCategory: 'Science',
        detectedLanguage: 'Telugu',
        cleanKeywords: ['robotics', 'space'],
        explanation: 'Telugu science and technology creators',
      );
      controller.activeAiIntent.value = intent;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DiscoverAiBanner(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Telugu science and technology creators'), findsOneWidget);
      expect(find.text('Telugu'), findsOneWidget);
      expect(find.text('Science'), findsOneWidget);
      expect(find.text('robotics'), findsOneWidget);
      expect(find.text('space'), findsOneWidget);

      // Clear AI search
      await tester.tap(find.byTooltip('Clear AI Search'));
      await tester.pumpAndSettle();
      expect(controller.activeAiIntent.value, isNull);
    });

    testWidgets('5. DiscoverCategoryCard displays category name and triggers tap',
        (tester) async {
      var tapped = false;
      final category = {'name': 'Science', 'icon': 'science'};

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DiscoverCategoryCard(
              category: category,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Science'), findsOneWidget);
      await tester.tap(find.byType(DiscoverCategoryCard));
      expect(tapped, isTrue);
    });

    testWidgets('6. DiscoverSelectedCategoryHeader renders category and back navigation',
        (tester) async {
      var backPressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                DiscoverSelectedCategoryHeader(
                  selectedCategory: 'Technology',
                  onBack: () => backPressed = true,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Technology'), findsOneWidget);
      expect(find.text('Exploring Technology channels'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      expect(backPressed, isTrue);
    });

    testWidgets('7. DiscoverCategoryGrid renders category items in slivers',
        (tester) async {
      final controller = DiscoverChannelsController();
      Get.put<DiscoverChannelsController>(controller);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                DiscoverCategoryGrid(
                  controller: controller,
                  isDesktop: true,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DiscoverCategoryCard), findsWidgets);
      expect(find.text('Education'), findsOneWidget);
    });

    testWidgets('8. DiscoverChannelCard displays channel details and verified icon',
        (tester) async {
      final channel = Channel(
        id: 'ch_test_42',
        name: 'Cosmos Explorer',
        nameLowercase: 'cosmos explorer',
        handle: 'cosmosexplorer',
        handleLowercase: 'cosmosexplorer',
        description: 'Exploring planets, astrophysics, and the deep universe.',
        avatarUrl: '',
        bannerUrl: '',
        ownerId: 'user_cosmos',
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
        isVerified: true,
        subscriberCount: 254000,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: DiscoverChannelCard(
              channel: channel,
              subscriberCount: 254000,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cosmos Explorer'), findsOneWidget);
      expect(find.byIcon(Icons.verified), findsOneWidget);
      expect(find.text('@cosmosexplorer • 254.0K subscribers'), findsOneWidget);
      expect(
        find.text('Exploring planets, astrophysics, and the deep universe.'),
        findsOneWidget,
      );
    });

    testWidgets('9. DiscoverEmptyState displays contextual message and resets',
        (tester) async {
      final controller = DiscoverChannelsController();
      Get.put<DiscoverChannelsController>(controller);

      controller.selectedCategory.value = 'Comedy';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DiscoverEmptyState(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No Comedy channels found'), findsOneWidget);
      expect(find.text('Explore All Categories'), findsOneWidget);
      expect(find.byIcon(Icons.explore_off_outlined), findsOneWidget);

      await tester.tap(find.text('Explore All Categories'));
      await tester.pumpAndSettle();

      expect(controller.selectedCategory.value, equals('All'));
    });

    testWidgets('10. DiscoverChannelsPage renders declaratively with layout',
        (tester) async {
      final controller = DiscoverChannelsController();
      Get.put<DiscoverChannelsController>(controller);

      await tester.pumpWidget(
        const GetMaterialApp(
          home: DiscoverChannelsPage(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.byType(DiscoverChannelsPage), findsOneWidget);
      expect(find.byType(DiscoverChannelsAppBar), findsOneWidget);
      expect(find.byType(DiscoverSearchBar), findsOneWidget);
    });
  });
}
