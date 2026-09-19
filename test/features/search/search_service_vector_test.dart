import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/services/ai/models/ai_search_intent.dart';
import 'package:truthworld/features/search/data/models/search_cache.dart';
import 'package:truthworld/features/search/data/models/search_result.dart';
import 'package:truthworld/features/search/data/services/search_service.dart';
import 'package:truthworld/features/search/presentation/controllers/search/search_execution_pipeline.dart';

class _MockSearchService extends Fake implements SearchService {
  @override
  Future<List<SearchResult>> search(
    String query, {
    AiSearchIntent? intent,
    String? filter,
    int limit = 20,
  }) async {
    return [];
  }

  @override
  Future<List<SearchResult>> getRecommendedForFilter(
    String filter, {
    Set<String>? watchedVideoIds,
  }) async {
    return [];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Vector Search — SearchResult Payload Deserialization', () {
    test('Correctly deserializes backend searchTruthWorld JSON payload', () {
      final backendJson = {
        'id': 'vid_vector_001',
        'title': 'James Webb Space Discoveries',
        'thumbnail': 'https://example.com/jwst.jpg',
        'views': 45200,
        'channelName': 'Cosmic Insights',
        'channelImage': 'https://example.com/avatar.jpg',
        'createdAt': '2026-09-18T04:00:00.000Z',
        'type': 'ResultType.video',
        'durationMs': 720000,
        'language': 'english',
        'category': 'science',
        'relevanceScore': 94.5,
      };

      final result = SearchResult.fromMap(backendJson);

      expect(result.id, 'vid_vector_001');
      expect(result.title, 'James Webb Space Discoveries');
      expect(result.views, 45200);
      expect(result.channelName, 'Cosmic Insights');
      expect(result.type, ResultType.video);
      expect(result.durationMs, 720000);
      expect(result.duration, 720); // seconds getter
      expect(result.language, 'english');
      expect(result.category, 'science');
      expect(result.relevanceScore, 94.5);
      expect(result.isValid, isTrue);
    });

    test('Supports both ResultType enum string and short name notations', () {
      final item1 = SearchResult.fromMap({
        'id': 'chan_1',
        'title': 'Truth Channel',
        'thumbnail': 'https://example.com/c.jpg',
        'views': 1000,
        'channelName': '@truth',
        'channelImage': '',
        'createdAt': '2026-09-18T00:00:00.000Z',
        'type': 'ResultType.channel',
      });

      final item2 = SearchResult.fromMap({
        'id': 'chan_2',
        'title': 'Truth Channel 2',
        'thumbnail': 'https://example.com/c2.jpg',
        'views': 2000,
        'channelName': '@truth2',
        'channelImage': '',
        'createdAt': '2026-09-18T00:00:00.000Z',
        'type': 'channel',
      });

      expect(item1.type, ResultType.channel);
      expect(item2.type, ResultType.channel);
    });

    test('Rejects invalid or draft records according to VideoVisibilityPolicy', () {
      final invalid1 = SearchResult.fromMap({
        'id': 'vid_bad',
        'title': 'untitled draft',
        'thumbnail': '',
        'views': 0,
        'channelName': 'creator',
        'channelImage': '',
        'createdAt': '2026-09-18T00:00:00.000Z',
        'type': 'video',
      });

      final invalid2 = SearchResult.fromMap({
        'id': 'vid_bad2',
        'title': 'uploading...',
        'thumbnail': '',
        'views': 0,
        'channelName': 'creator',
        'channelImage': '',
        'createdAt': '2026-09-18T00:00:00.000Z',
        'type': 'video',
      });

      expect(invalid1.isValid, isFalse);
      expect(invalid2.isValid, isFalse);
    });
  });

  group('Vector Search — Query Sanitization & Cache Keys', () {
    test('sanitizeQuery strips punctuation and collapses whitespace', () {
      expect(SearchService.sanitizeQuery('  telugu christian  debates?!.  '), 'telugu christian debates');
      expect(SearchService.sanitizeQuery('---isro space mission...'), 'isro space mission');
    });

    test('extractTokens removes non-alphanumerics and extracts words', () {
      final tokens = SearchService.extractTokens('AI & Deep-Learning in 2026!');
      expect(tokens, containsAll(['ai', 'deeplearning', 'in', '2026']));
    });

    test('SearchCache maintains distinct keys for different filters', () {
      final cache = SearchCache();
      final videoResults = [
        SearchResult(
          id: 'v1',
          title: 'Science Video',
          thumbnail: '',
          views: 100,
          channelName: 'Sci',
          channelImage: '',
          createdAt: Timestamp.now(),
        ),
      ];

      final channelResults = [
        SearchResult(
          id: 'c1',
          title: 'Science Channel',
          thumbnail: '',
          views: 5000,
          channelName: '@science',
          channelImage: '',
          createdAt: Timestamp.now(),
          type: ResultType.channel,
        ),
      ];

      cache.put('Videos:science', videoResults);
      cache.put('Channels:science', channelResults);

      expect(cache.get('Videos:science')!.first.type, ResultType.video);
      expect(cache.get('Channels:science')!.first.type, ResultType.channel);
      expect(cache.getStats()['totalHits'], 2);
    });
  });

  group('Vector Search — Execution Pipeline Resilience', () {
    test('SearchExecutionPipeline processes query and broadens language intent', () async {
      final mockService = _MockSearchService();
      
      final result = await SearchExecutionPipeline.execute(
        query: 'telugu science debates',
        searchService: mockService,
        activeFilter: 'Videos',
        watchedVideoIds: {},
      );

      expect(result.activeAiIntent, isNotNull);
      expect(result.activeAiIntent?.detectedLanguage, 'telugu');
      expect(result.activeAiIntent?.detectedCategory, 'science');
    });
  });
}
