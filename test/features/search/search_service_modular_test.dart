import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/features/search/data/models/search_result.dart';
import 'package:truthworld/features/search/data/services/search_service.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });
  final now = Timestamp.now();

  group('SearchSanitizer Tests', () {
    test('sanitizeQuery removes leading/trailing punctuation and collapses whitespace', () {
      expect(
        SearchSanitizer.sanitizeQuery('  ...??Hello   World!!--  '),
        equals('hello world'),
      );
      expect(
        SearchSanitizer.sanitizeQuery('Flutter_Tutorial:'),
        equals('flutter_tutorial'),
      );
    });

    test('extractTokens extracts clean alphanumeric tokens', () {
      final tokens = SearchSanitizer.extractTokens('What is Flutter 3.0?');
      expect(tokens, contains('what'));
      expect(tokens, contains('is'));
      expect(tokens, contains('flutter'));
      expect(tokens, contains('30'));
    });
  });

  group('SearchResultRanker Tests', () {
    const ranker = SearchResultRanker();

    test('gives highest score to exact title match', () {
      final itemExact = SearchResult(
        id: '1',
        title: 'Flutter Tutorial',
        channelName: 'Code Hub',
        channelImage: '',
        thumbnail: '',
        views: 0,
        createdAt: now,
      );
      final itemPartial = SearchResult(
        id: '2',
        title: 'Advanced Flutter Tutorial for Beginners',
        channelName: 'Dev Academy',
        channelImage: '',
        thumbnail: '',
        views: 0,
        createdAt: now,
      );

      final ranked = ranker.rankAndSortResults([itemPartial, itemExact], 'flutter tutorial');
      expect(ranked.first.id, equals('1'));
      expect(ranked.first.relevanceScore, greaterThan(ranked.last.relevanceScore));
    });

    test('breaks ties using views and then createdAt', () {
      final itemHighViews = SearchResult(
        id: '1',
        title: 'Tech News',
        channelName: 'Channel A',
        channelImage: '',
        thumbnail: '',
        views: 50000,
        createdAt: now,
      );
      final itemLowViews = SearchResult(
        id: '2',
        title: 'Tech News',
        channelName: 'Channel B',
        channelImage: '',
        thumbnail: '',
        views: 1000,
        createdAt: now,
      );

      final ranked = ranker.rankAndSortResults([itemLowViews, itemHighViews], 'tech news');
      expect(ranked.first.id, equals('1'));
      expect(ranked.last.id, equals('2'));
    });
  });

  group('SearchService Coordinator Facade Tests', () {
    test('static delegates forward to SearchSanitizer', () {
      expect(SearchService.sanitizeQuery(' Hello?! '), equals('hello'));
      expect(SearchService.extractTokens('Hello World'), equals(['hello', 'world']));
    });

    test('cache management functions properly', () {
      final service = SearchService();
      expect(service.isCached('flutter'), isFalse);
      final stats = service.getCacheStats();
      expect(stats.containsKey('size'), isTrue);

      service.clearCache();
      expect(service.getCacheStats()['size'], equals(0));
    });
  });
}
