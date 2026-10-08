import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' hide SearchBar;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/search/data/models/search_result.dart';
import 'package:truthworld/features/search/presentation/controllers/search/search_models.dart';
import 'package:truthworld/features/search/presentation/widgets/search_widgets.dart';
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

  group('SearchWidgets Modular Unit & Widget Tests', () {
    testWidgets('1. EmptySearchState renders query and triggers clear callback',
        (tester) async {
      var cleared = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptySearchState(
              query: 'unknown topic',
              onClearSearch: () => cleared = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No results for "unknown topic"'), findsOneWidget);
      expect(find.text('Try different keywords'), findsOneWidget);
      expect(find.text('Clear Search'), findsOneWidget);
      expect(find.byIcon(Icons.search_off), findsOneWidget);

      await tester.tap(find.text('Clear Search'));
      expect(cleared, isTrue);
    });

    testWidgets('2. RecentSearchesList renders query chips and clear all button',
        (tester) async {
      String? selected;
      var clearedAll = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecentSearchesList(
              recentSearches: const ['AI Fact Checking', 'TruthWorld Features', 'Deepfake Detection'],
              onSearchSelected: (q) => selected = q,
              onClearAll: () => clearedAll = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Recent Searches'), findsOneWidget);
      expect(find.text('Clear All'), findsOneWidget);
      expect(find.text('AI Fact Checking'), findsOneWidget);
      expect(find.text('TruthWorld Features'), findsOneWidget);
      expect(find.text('Deepfake Detection'), findsOneWidget);

      await tester.tap(find.text('AI Fact Checking'));
      expect(selected, equals('AI Fact Checking'));

      await tester.tap(find.text('Clear All'));
      expect(clearedAll, isTrue);
    });

    testWidgets('3. SearchSuggestionTile renders suggestion icon, text and subtitle',
        (tester) async {
      var tapped = false;
      var copied = false;

      final suggestion = SearchSuggestion(
        text: 'Climate change fact check',
        subtitle: 'Science & Environment',
        icon: Icons.history,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchSuggestionTile(
              suggestion: suggestion,
              onTap: () => tapped = true,
              onCopy: () => copied = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Climate change fact check'), findsOneWidget);
      expect(find.text('Science & Environment'), findsOneWidget);
      expect(find.byIcon(Icons.history), findsOneWidget);
      expect(find.byIcon(Icons.north_west), findsOneWidget);

      await tester.tap(find.text('Climate change fact check'));
      expect(tapped, isTrue);

      await tester.tap(find.byIcon(Icons.north_west));
      expect(copied, isTrue);
    });

    testWidgets('4. SearchResultCard renders Video result properly',
        (tester) async {
      final videoResult = SearchResult(
        id: 'vid_123',
        title: 'Deepfake Audio Verification Analysis',
        thumbnail: '',
        channelName: 'Truth News Desk',
        channelImage: '',
        views: 12500,
        createdAt: Timestamp.now(),
        durationMs: 185000,
        category: 'Fact Check',
        language: 'English',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchResultCard(result: videoResult),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Deepfake Audio Verification Analysis'), findsOneWidget);
      expect(find.text('Truth News Desk'), findsOneWidget);
      expect(find.textContaining('12.5K views'), findsOneWidget);
      expect(find.text('3:05'), findsOneWidget);
      expect(find.text('FACT CHECK'), findsOneWidget);
    });

    testWidgets('5. SearchResultCard renders Channel result properly',
        (tester) async {
      final channelResult = SearchResult(
        id: 'chan_456',
        title: 'Investigative Fact Checkers',
        type: ResultType.channel,
        thumbnail: '',
        channelName: 'TruthWorld Official',
        channelImage: '',
        views: 340000,
        createdAt: Timestamp.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchResultCard(result: channelResult),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Investigative Fact Checkers'), findsOneWidget);
      expect(find.textContaining('340.0K subscribers'), findsOneWidget);
      expect(find.byType(SubscribeButton), findsOneWidget);
    });

    testWidgets('6. SearchResultCard renders Playlist result properly',
        (tester) async {
      final playlistResult = SearchResult(
        id: 'pl_789',
        title: 'Disinformation Case Studies',
        type: ResultType.playlist,
        thumbnail: '',
        channelName: 'Media Literacy Institute',
        channelImage: '',
        views: 18, // video count
        createdAt: Timestamp.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchResultCard(result: playlistResult),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Disinformation Case Studies'), findsOneWidget);
      expect(find.text('Playlist • Media Literacy Institute'), findsOneWidget);
      expect(find.text('18'), findsOneWidget);
      expect(find.text('View full playlist'), findsOneWidget);
    });

    testWidgets('7. SearchResultCard renders Topic result properly',
        (tester) async {
      final topicResult = SearchResult(
        id: 'topic_999',
        title: 'Artificial Intelligence Ethics',
        type: ResultType.topic,
        thumbnail: '',
        channelName: '#ai_ethics',
        channelImage: '',
        views: 42,
        createdAt: Timestamp.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchResultCard(result: topicResult),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Artificial Intelligence Ethics'), findsOneWidget);
      expect(find.text('#ai_ethics'), findsOneWidget);
      expect(find.text('TOPIC'), findsOneWidget);
      expect(find.text('42 videos available'), findsOneWidget);
      expect(find.byType(FollowButton), findsOneWidget);
      expect(find.text('Follow'), findsOneWidget);
      final followText = tester.widget<Text>(find.text('Follow'));
      expect(followText.style?.color, equals(Colors.black));
    });

    testWidgets('8. SearchBar manages text editing and clear actions reactively',
        (tester) async {
      final controller = TextEditingController(text: 'Initial Query');
      var changedQuery = '';
      var cleared = false;
      var submitted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchBar(
              controller: controller,
              onChanged: (q) => changedQuery = q,
              onClear: () => cleared = true,
              onSearchSubmitted: () => submitted = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Initial Query'), findsOneWidget);
      expect(find.byIcon(Icons.clear_rounded), findsOneWidget);
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Typed Query');
      expect(changedQuery, equals('Typed Query'));

      await tester.tap(find.byIcon(Icons.search_rounded));
      expect(submitted, isTrue);

      await tester.tap(find.byIcon(Icons.clear_rounded));
      await tester.pump();
      expect(cleared, isTrue);
      expect(controller.text, isEmpty);
    });
  });
}
