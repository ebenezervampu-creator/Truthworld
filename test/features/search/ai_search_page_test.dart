import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/services/ai/ai_search_service.dart';
import 'package:truthworld/core/services/ai/models/ai_search_intent.dart';
import 'package:truthworld/features/search/data/models/search_result.dart';
import '../../test_helpers/mock_firebase.dart';

// ignore: subtype_of_sealed_class
class _FakeDocSnapshot extends Fake
    implements DocumentSnapshot<Map<String, dynamic>> {
  _FakeDocSnapshot(this.id, this._data);
  @override
  final String id;
  final Map<String, dynamic> _data;

  @override
  Map<String, dynamic>? data() => _data;

  @override
  bool get exists => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  group('SearchResult Model Language & Category Support', () {
    test('serializes and deserializes language and category correctly', () {
      final now = Timestamp.now();
      final original = SearchResult(
        id: 'res_1',
        title: 'Telugu Bible Study Lesson',
        thumbnail: 'https://example.com/thumb.jpg',
        views: 2500,
        channelName: 'Telugu Gospel Church',
        channelImage: 'https://example.com/ch.jpg',
        createdAt: now,
        language: 'te',
        category: 'religion',
      );

      final map = original.toMap();
      expect(map['language'], equals('te'));
      expect(map['category'], equals('religion'));

      final restored = SearchResult.fromMap(map);
      expect(restored.id, equals('res_1'));
      expect(restored.language, equals('te'));
      expect(restored.category, equals('religion'));
      expect(restored.type, equals(ResultType.video));
    });

    test('fromFirestore extracts language and category for channel, topic, and video', () {
      final now = Timestamp.now();

      final videoDoc = _FakeDocSnapshot('v1', {
        'title': 'Cosmos & Space Exploration',
        'thumbnailUrl': 'https://example.com/cosmos.jpg',
        'views': 12000,
        'channelName': 'Space Frontier',
        'createdAt': now,
        'language': 'en',
        'category': 'science',
      });
      final videoResult = SearchResult.fromFirestore(videoDoc);
      expect(videoResult.language, equals('en'));
      expect(videoResult.category, equals('science'));

      final channelDoc = _FakeDocSnapshot('c1', {
        'channelName': 'Telugu Tech Zone',
        'avatarUrl': 'https://example.com/avatar.jpg',
        'subscriberCount': 80000,
        'createdAt': now,
        'language': 'te',
        'category': 'technology',
      });
      final channelResult = SearchResult.fromFirestore(channelDoc, type: ResultType.channel);
      expect(channelResult.language, equals('te'));
      expect(channelResult.category, equals('technology'));
    });
  });

  group('AiSearchService - SearchResult Scoring & Relevance', () {
    final aiService = AiSearchService.instance;
    final now = Timestamp.now();

    late SearchResult teluguChristianVideo;
    late SearchResult englishChristianVideo;
    late SearchResult teluguTechVideo;
    late SearchResult christianMusicVideo;
    late SearchResult spaceAstrophysicsTopic;

    setUp(() {
      teluguChristianVideo = SearchResult(
        id: 'v_te_christian',
        title: 'Telugu Christian Sermons and Bible Study',
        thumbnail: '',
        views: 15000,
        channelName: 'Telugu Faith Ministry',
        channelImage: '',
        createdAt: now,
        language: 'te',
        category: 'religion',
      );

      englishChristianVideo = SearchResult(
        id: 'v_en_christian',
        title: 'Christian Theology and Expository Bible Study',
        thumbnail: '',
        views: 50000,
        channelName: 'Global Scripture Academy',
        channelImage: '',
        createdAt: now,
        language: 'en',
        category: 'religion',
      );

      teluguTechVideo = SearchResult(
        id: 'v_te_tech',
        title: 'Flutter and Dart Full Course in Telugu',
        thumbnail: '',
        views: 45000,
        channelName: 'Telugu Coding Hub',
        channelImage: '',
        createdAt: now,
        language: 'te',
        category: 'technology',
      );

      christianMusicVideo = SearchResult(
        id: 'v_christian_music',
        title: 'Non-stop Telugu Devotional Music and Songs',
        thumbnail: '',
        views: 120000,
        channelName: 'Devotional Music Center',
        channelImage: '',
        createdAt: now,
        language: 'te',
        category: 'music',
      );

      spaceAstrophysicsTopic = SearchResult(
        id: 'top_space',
        title: 'Astrophysics and Deep Space Exploration',
        thumbnail: '',
        views: 85,
        channelName: 'T/astronomy',
        channelImage: '',
        createdAt: now,
        type: ResultType.topic,
        language: 'en',
        category: 'science',
      );
    });

    test('scores matching language and category search results highly', () async {
      const query =
          'i want all the list of telugu christian channels then showing all the christian channels';
      final intent = await aiService.parseQuery(query);

      final scoreTeChristian = aiService.scoreSearchResult(teluguChristianVideo, intent);
      final scoreEnChristian = aiService.scoreSearchResult(englishChristianVideo, intent);
      final scoreTeTech = aiService.scoreSearchResult(teluguTechVideo, intent);

      // Telugu Christian result scores very highly
      expect(scoreTeChristian, greaterThan(80.0));

      // Strict language filter: English result excluded from regional Telugu search
      expect(scoreEnChristian, equals(0.0));

      // Unrelated domain (tech) excluded
      expect(scoreTeTech, equals(0.0));
    });

    test('cross-language broadening includes other languages', () async {
      const query = 'show me all telugu christian channels';
      final intent = await aiService.parseQuery(query);

      // In strict language mode, English is 0.0
      expect(aiService.scoreSearchResult(englishChristianVideo, intent), equals(0.0));

      // In broadened mode (language cleared), English Christian content is scored highly
      final broadenedIntent = intent.copyWith(clearLanguage: true);
      final broadenedScore = aiService.scoreSearchResult(englishChristianVideo, broadenedIntent);
      expect(broadenedScore, greaterThan(60.0));
    });

    test('respects exclusions ("rather than devotional music")', () async {
      const query =
          'Telugu channels discussing Christianity rather than devotional music';
      final intent = await aiService.parseQuery(query);

      expect(intent.excludedTerms, contains('music'));

      final scoreChristian = aiService.scoreSearchResult(teluguChristianVideo, intent);
      final scoreMusic = aiService.scoreSearchResult(christianMusicVideo, intent);

      expect(scoreChristian, greaterThan(60.0));
      // Excluded due to negation phrase
      expect(scoreMusic, equals(0.0));
    });

    test('scores topic and subdomains correctly for science queries', () async {
      const query = 'top space and astronomy topics';
      final intent = await aiService.parseQuery(query);

      final score = aiService.scoreSearchResult(spaceAstrophysicsTopic, intent);
      expect(score, greaterThan(50.0));
    });

    test('exhaustive mode does not distort relevance scores with audience bias', () async {
      const queryAll = 'all telugu christian channels';
      final intentAll = await aiService.parseQuery(queryAll);
      expect(intentAll.resultMode, equals(SearchResultMode.exhaustive));

      final scoreAll = aiService.scoreSearchResult(teluguChristianVideo, intentAll);

      const queryRanked = 'top telugu christian channels';
      final intentRanked = await aiService.parseQuery(queryRanked);
      expect(intentRanked.resultMode, equals(SearchResultMode.ranked));

      final scoreRanked = aiService.scoreSearchResult(teluguChristianVideo, intentRanked);

      // Ranked mode includes additional popularity/signal boosts
      expect(scoreRanked, greaterThan(scoreAll));
    });
  });
}
