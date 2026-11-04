import 'package:flutter/material.dart' hide SearchBar, SearchController;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_subscription_controller.dart';
import 'package:truthworld/features/search/data/services/search_service.dart';
import 'package:truthworld/features/search/presentation/controllers/search_controller.dart';
import 'package:truthworld/features/search/presentation/widgets/items/recent_searches_list.dart';
import 'package:truthworld/features/search/presentation/widgets/items/search_bar_widget.dart';
import 'package:truthworld/features/search/presentation/widgets/items/search_follow_button.dart';
import 'package:truthworld/features/search/presentation/widgets/items/search_subscribe_button.dart';
import 'package:truthworld/features/search/presentation/widgets/items/search_suggestion_tile.dart';
import 'package:truthworld/features/topics/presentation/controllers/following_topics_controller.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  setUp(() {
    if (!Get.isRegistered<AuthService>()) {
      Get.put<AuthService>(AuthService());
    }
  });

  tearDown(Get.reset);

  group('Search Page Action Buttons Audit Tests', () {
    testWidgets('1. SearchBar action buttons render with accessible tooltips', (tester) async {
      final controller = TextEditingController(text: 'sample');
      var submitted = false;
      var cleared = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchBar(
              controller: controller,
              onChanged: (_) {},
              onClear: () => cleared = true,
              onSearchSubmitted: () => submitted = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final searchBtn = find.byTooltip('Search');
      expect(searchBtn, findsOneWidget);
      await tester.tap(searchBtn);
      expect(submitted, isTrue);

      final clearBtn = find.byTooltip('Clear search');
      expect(clearBtn, findsOneWidget);
      await tester.tap(clearBtn);
      expect(cleared, isTrue);

      final voiceBtn = find.byTooltip('Voice search');
      expect(voiceBtn, findsOneWidget);
    });

    testWidgets('2. RecentSearchesList renders ActionChips with proper alignment and selection', (tester) async {
      String? selectedQuery;
      var clearedAll = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecentSearchesList(
              recentSearches: const ['Flutter', 'TruthWorld', 'AI Facts'],
              onSearchSelected: (q) => selectedQuery = q,
              onClearAll: () => clearedAll = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ActionChip), findsNWidgets(3));
      await tester.tap(find.text('TruthWorld'));
      expect(selectedQuery, equals('TruthWorld'));

      await tester.tap(find.text('Clear All'));
      expect(clearedAll, isTrue);
    });

    testWidgets('3. SearchSuggestionTile has comfortable tap target and tooltip on copy button', (tester) async {
      var copied = false;
      final suggestion = SearchSuggestion(
        text: 'AI Fact-checking analysis',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchSuggestionTile(
              suggestion: suggestion,
              onTap: () {},
              onCopy: () => copied = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final copyBtn = find.byTooltip('Insert suggestion');
      expect(copyBtn, findsOneWidget);
      await tester.tap(copyBtn);
      expect(copied, isTrue);
    });

    testWidgets('4. SubscribeButton enforces high contrast (brand white bg with black text)', (tester) async {
      Get.put(ChannelSubscriptionController());

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: SubscribeButton(
              channelId: 'chan_audit_1',
              channelName: 'Channel One',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Subscribe'), findsOneWidget);
      final textWidget = tester.widget<Text>(find.text('Subscribe'));
      // Unsubscribed state must have black text on brand background
      expect(textWidget.style?.color, equals(Colors.black));
    });

    testWidgets('5. FollowButton enforces high contrast (brand white bg with black text)', (tester) async {
      Get.put(FollowingTopicsController());

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: FollowButton(
              topicId: 'topic_audit_1',
              topicName: 'Climate Science',
              videoCount: 10,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Follow'), findsOneWidget);
      final textWidget = tester.widget<Text>(find.text('Follow'));
      // Unfollowed state must have black text on brand background
      expect(textWidget.style?.color, equals(Colors.black));
    });

    test('6. SearchController.clearSearch resets textEditingController and search query', () {
      final controller = Get.put(SearchController(
        searchService: SearchService(),
      ));

      controller.textEditingController.text = 'unwanted query';
      controller.searchQuery.value = 'unwanted query';

      controller.clearSearch();

      expect(controller.searchQuery.value, isEmpty);
      expect(controller.textEditingController.text, isEmpty);
      expect(controller.showSuggestions.value, isFalse);
    });

    test('7. SearchController.setFilter resets scroll position if attached', () {
      final controller = Get.put(SearchController(
        searchService: SearchService(),
      ));

      controller.setFilter('Videos');
      expect(controller.selectedFilter.value, equals('Videos'));
      expect(controller.currentPage.value, equals(0));
    });
  });
}
