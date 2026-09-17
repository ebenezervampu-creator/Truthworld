import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/ai/ai_search_service.dart';
import 'package:truthworld/core/services/ai/models/ai_search_intent.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/discover/presentation/controllers/discover_channels_controller.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  tearDown(() {
    AiSearchService.instance.cloudAssistantHandler = null;
    AiSearchService.instance.clearCache();
    Get.reset();
  });

  group('Full User Journey Integration Tests (10 Scenarios)', () {
    final now = Timestamp.now();

    final cTeluguChristian1 = Channel(
      id: 'c_te_chris_1',
      name: 'Telugu Faith Ministries',
      nameLowercase: 'telugu faith ministries',
      handle: '@telugufaith',
      handleLowercase: '@telugufaith',
      description: 'Christian theology, scripture study, sermons, and church teachings in Telugu.',
      avatarUrl: '',
      bannerUrl: '',
      ownerId: 'u1',
      createdAt: now,
      updatedAt: now,
      language: 'te',
      category: 'religion',
      subscriberCount: 5000,
      categories: ['christian', 'bible', 'sermons'],
    );

    final cTeluguChristianMega = Channel(
      id: 'c_te_chris_mega',
      name: 'Andhra Gospel Fellowship',
      nameLowercase: 'andhra gospel fellowship',
      handle: '@andhragospel',
      handleLowercase: '@andhragospel',
      description: 'Worship and scripture ministry across Andhra and Telangana.',
      avatarUrl: '',
      bannerUrl: '',
      ownerId: 'u2',
      createdAt: now,
      updatedAt: now,
      language: 'te',
      category: 'religion',
      subscriberCount: 500000,
      categories: ['gospel', 'christian', 'church'],
    );

    final cTeluguMusic = Channel(
      id: 'c_te_music',
      name: 'Telugu Devotional Music Hub',
      nameLowercase: 'telugu devotional music hub',
      handle: '@telugumusic',
      handleLowercase: '@telugumusic',
      description: 'Christian devotional music and non-stop prayer songs.',
      avatarUrl: '',
      bannerUrl: '',
      ownerId: 'u3',
      createdAt: now,
      updatedAt: now,
      language: 'te',
      category: 'music',
      subscriberCount: 25000,
      categories: ['devotional music', 'songs', 'christian'],
    );

    final cEnglishChristian = Channel(
      id: 'c_en_chris',
      name: 'Global Scripture Academy',
      nameLowercase: 'global scripture academy',
      handle: '@globalscripture',
      handleLowercase: '@globalscripture',
      description: 'In-depth biblical hermeneutics and theology lectures.',
      avatarUrl: '',
      bannerUrl: '',
      ownerId: 'u4',
      createdAt: now,
      updatedAt: now,
      category: 'religion',
      subscriberCount: 150000,
      categories: ['theology', 'bible', 'christianity'],
    );

    final cTeluguTech = Channel(
      id: 'c_te_tech',
      name: 'Telugu Tech World',
      nameLowercase: 'telugu tech world',
      handle: '@telugutech',
      handleLowercase: '@telugutech',
      description: 'Telugu tutorials on artificial intelligence, coding, and software development.',
      avatarUrl: '',
      bannerUrl: '',
      ownerId: 'u5',
      createdAt: now,
      updatedAt: now,
      language: 'te',
      category: 'technology',
      subscriberCount: 40000,
      categories: ['ai', 'tech', 'coding', 'tutorials'],
    );

    final cCooking = Channel(
      id: 'c_cooking',
      name: 'Hyderabadi Biryani Masterclass',
      nameLowercase: 'hyderabadi biryani masterclass',
      handle: '@biryanimaster',
      handleLowercase: '@biryanimaster',
      description: 'Traditional cooking recipes from Telangana.',
      avatarUrl: '',
      bannerUrl: '',
      ownerId: 'u6',
      createdAt: now,
      updatedAt: now,
      language: 'te',
      category: 'food',
      subscriberCount: 75000,
      categories: ['cooking', 'food', 'recipes'],
    );

    final sampleChannels = [
      cTeluguChristian1,
      cTeluguChristianMega,
      cTeluguMusic,
      cEnglishChristian,
      cTeluguTech,
      cCooking,
    ];

    // -------------------------------------------------------------------------
    // Journey 1: Search -> Results
    // -------------------------------------------------------------------------
    test('Journey 1: Search -> Results (parses language, category, and returns matching channels)', () async {
      const query = 'Telugu Christian channels';
      final intent = await AiSearchService.instance.parseQuery(query, scope: SearchScope.channels);

      expect(intent.detectedLanguage, equals('telugu'));
      expect(intent.detectedCategory, equals('religion'));
      expect(intent.cleanKeywords, contains('christian'));

      final results = <Channel>[];
      for (final ch in sampleChannels) {
        final score = AiSearchService.instance.scoreChannel(ch, intent);
        if (score > 0) results.add(ch);
      }

      expect(results.map((c) => c.id), containsAll(['c_te_chris_1', 'c_te_chris_mega', 'c_te_music']));
      expect(results.map((c) => c.id), isNot(contains('c_en_chris')));
      expect(results.map((c) => c.id), isNot(contains('c_cooking')));
    });

    // -------------------------------------------------------------------------
    // Journey 2: Search -> Zero Results
    // -------------------------------------------------------------------------
    test('Journey 2: Search -> Zero Results (handles non-existent match gracefully without errors)', () async {
      const query = 'Telugu Quantum Nuclear Submarine Astrophysics';
      final intent = await AiSearchService.instance.parseQuery(query, scope: SearchScope.channels);

      final results = <Channel>[];
      for (final ch in sampleChannels) {
        final score = AiSearchService.instance.scoreChannel(ch, intent);
        if (score > 0) results.add(ch);
      }

      expect(results, isEmpty);
      expect(intent.rawQuery, equals(query));
    });

    // -------------------------------------------------------------------------
    // Journey 3: Search -> Broadening
    // -------------------------------------------------------------------------
    test('Journey 3: Search -> Broadening (prepares and activates cross-language fallback)', () async {
      const query = 'Telugu Christian channels';
      final intent = await AiSearchService.instance.parseQuery(query, scope: SearchScope.channels);

      expect(intent.broadenPrompt, isNotNull);

      final broadenedIntent = intent.copyWith(clearLanguage: true);
      expect(broadenedIntent.detectedLanguage, isNull);

      final broadenedResults = <Channel>[];
      for (final ch in sampleChannels) {
        final score = AiSearchService.instance.scoreChannel(ch, broadenedIntent);
        if (score > 0) broadenedResults.add(ch);
      }

      expect(broadenedResults.map((c) => c.id), contains('c_en_chris'));
      expect(broadenedResults.map((c) => c.id), contains('c_te_chris_1'));
    });

    // -------------------------------------------------------------------------
    // Journey 4: Clear AI Search -> Original Filters Restored
    // -------------------------------------------------------------------------
    test('Journey 4: Clear AI Search -> Original Filters Restored', () {
      final controller = DiscoverChannelsController();
      controller.searchController.text = 'Telugu Christian channels';
      controller.searchQuery.value = 'Telugu Christian channels';
      controller.activeAiIntent.value = AiSearchIntent(
        rawQuery: 'Telugu Christian channels',
        cleanKeywords: ['christian'],
        detectedLanguage: 'telugu',
      );
      controller.isBroadenedView.value = true;
      controller.broadenedChannels.add(cEnglishChristian);

      expect(controller.activeAiIntent.value, isNotNull);
      expect(controller.isBroadenedView.value, isTrue);

      controller.clearAiSearch();

      expect(controller.activeAiIntent.value, isNull);
      expect(controller.isBroadenedView.value, isFalse);
      expect(controller.broadenedChannels, isEmpty);
      expect(controller.searchQuery.value, isEmpty);
      expect(controller.searchController.text, isEmpty);
    });

    // -------------------------------------------------------------------------
    // Journey 5: Gemini Fallback for Complex Queries
    // -------------------------------------------------------------------------
    test('Journey 5: Gemini Fallback (invokes cloud assistant for complex queries)', () async {
      const complexQuery = 'deep historical debate about comparative epistemological realism vs subjective idealism in ancient thought';

      var cloudCalled = false;
      AiSearchService.instance.cloudAssistantHandler = (query, scope) async {
        cloudCalled = true;
        return AiSearchIntent(
          rawQuery: query,
          cleanKeywords: ['epistemological', 'realism', 'idealism'],
          detectedCategory: 'philosophy',
          subdomains: ['Epistemology', 'Philosophy of Mind'],
          confidence: 0.94,
          explanation: 'Showing philosophical debates',
          scope: scope,
        );
      };

      final intent = await AiSearchService.instance.parseQuery(complexQuery);

      expect(cloudCalled, isTrue);
      expect(intent.confidence, equals(0.94));
      expect(intent.subdomains, contains('Philosophy of Mind'));
      expect(intent.detectedCategory, equals('philosophy'));
    });

    // -------------------------------------------------------------------------
    // Journey 6: Gemini Unavailable -> Local Search Still Works
    // -------------------------------------------------------------------------
    test('Journey 6: Gemini Unavailable -> Gracefully Degrades to Local Search', () async {
      const query = 'unusual complex query that triggers cloud fallback';

      AiSearchService.instance.cloudAssistantHandler = (query, scope) async {
        throw Exception('Firebase Cloud Function unavailable (503)');
      };

      final intent = await AiSearchService.instance.parseQuery(query);

      expect(intent, isNotNull);
      expect(intent.rawQuery, equals(query));
      expect(intent.cleanKeywords, isNotEmpty);
    });

    // -------------------------------------------------------------------------
    // Journey 7: Voice -> Transcript -> AI Search
    // -------------------------------------------------------------------------
    test('Journey 7: Voice -> Transcript -> AI Search (strips conversational speech fillers)', () async {
      const voiceTranscript = 'i want all the list of telugu christian channels then showing all the christian channels';

      final intent = await AiSearchService.instance.parseQuery(voiceTranscript, scope: SearchScope.channels);

      expect(intent.isConversational, isTrue);
      expect(intent.detectedLanguage, equals('telugu'));
      expect(intent.resultMode, equals(SearchResultMode.exhaustive));
      expect(intent.cleanKeywords, contains('christian'));
      expect(intent.cleanKeywords, isNot(contains('want')));
      expect(intent.cleanKeywords, isNot(contains('list')));
      expect(intent.cleanKeywords, isNot(contains('showing')));
    });

    // -------------------------------------------------------------------------
    // Journey 8: Pagination with Exhaustive Mode vs Ranked Mode
    // -------------------------------------------------------------------------
    test('Journey 8: Exhaustive Mode vs Ranked Mode', () async {
      final exhaustiveIntent = await AiSearchService.instance.parseQuery(
        'all Telugu Christian channels',
        scope: SearchScope.channels,
      );
      expect(exhaustiveIntent.resultMode, equals(SearchResultMode.exhaustive));

      final rankedIntent = await AiSearchService.instance.parseQuery(
        'top Telugu Christian channels',
        scope: SearchScope.channels,
      );
      expect(rankedIntent.resultMode, equals(SearchResultMode.ranked));

      final scoredExhaustive = <Channel>[];
      for (final ch in [cTeluguChristian1, cTeluguChristianMega]) {
        final score = AiSearchService.instance.scoreChannel(ch, exhaustiveIntent);
        if (score > 0) scoredExhaustive.add(ch);
      }
      expect(scoredExhaustive.length, equals(2));
    });

    // -------------------------------------------------------------------------
    // Journey 9: Negation
    // -------------------------------------------------------------------------
    test('Journey 9: Negation ("rather than devotional music" excludes unwanted channels)', () async {
      const query = 'Telugu channels discussing Christianity rather than devotional music';
      final intent = await AiSearchService.instance.parseQuery(query, scope: SearchScope.channels);

      expect(intent.excludedTerms, contains('devotional music'));

      final scoreStudy = AiSearchService.instance.scoreChannel(cTeluguChristian1, intent);
      final scoreMusic = AiSearchService.instance.scoreChannel(cTeluguMusic, intent);

      expect(scoreStudy, greaterThan(0));
      expect(scoreMusic, equals(0.0));
    });

    // -------------------------------------------------------------------------
    // Journey 10: Mixed-Language Queries
    // -------------------------------------------------------------------------
    test('Journey 10: Mixed-Language Queries (matches regional language and English tech terms)', () async {
      const query = 'Telugu tech tutorials and AI coding';
      final intent = await AiSearchService.instance.parseQuery(query, scope: SearchScope.channels);

      expect(intent.detectedLanguage, equals('telugu'));
      expect(intent.cleanKeywords, containsAll(['tech', 'tutorials', 'coding']));

      final scoreTech = AiSearchService.instance.scoreChannel(cTeluguTech, intent);
      final scoreCook = AiSearchService.instance.scoreChannel(cCooking, intent);

      expect(scoreTech, greaterThan(20.0));
      expect(scoreCook, equals(0.0));
    });
  });

  group('Explore Topics AI Search Journey Tests', () {
    test('Topic scoring correctly matches space domain and astrophysics subdomains', () async {
      const query = 'top space and astronomy topics';
      final intent = await AiSearchService.instance.parseQuery(query, scope: SearchScope.topics);

      expect(intent.subdomains, contains('Astronomy'));
      expect(intent.subdomains, contains('Astrophysics'));

      final spaceTopic = Topic(
        id: 'top_space',
        title: 'James Webb Deep Field Universe',
        slug: 'james-webb-space-astronomy',
        handle: 'jameswebb',
        handleLowercase: 'jameswebb',
        description: 'Deep cosmic imagery and astrophysics discoveries.',
        category: 'science',
        tags: ['space', 'astronomy', 'universe', 'cosmology'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        videoCount: 15,
        trendingScore: 88.0,
      );

      final sportsTopic = Topic(
        id: 'top_sports',
        title: 'Premier League Weekly Goals',
        slug: 'premier-league-goals',
        handle: 'plgoals',
        handleLowercase: 'plgoals',
        description: 'Football highlights and match commentary.',
        category: 'sports',
        tags: ['football', 'soccer'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        videoCount: 22,
        trendingScore: 95.0,
      );

      final scoreSpace = AiSearchService.instance.scoreTopic(spaceTopic, intent);
      final scoreSports = AiSearchService.instance.scoreTopic(sportsTopic, intent);

      expect(scoreSpace, greaterThan(30.0));
      expect(scoreSports, equals(0.0));
    });
  });
}
