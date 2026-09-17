import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/services/ai/ai_search_service.dart';
import 'package:truthworld/core/services/ai/models/ai_search_intent.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AiSearchService - Natural Language Intent Parsing', () {
    final aiService = AiSearchService.instance;

    test(
      'parses conversational query: "i want all the list of telugu christian channels then showing all the christian channels"',
      () async {
        const query =
            'i want all the list of telugu christian channels then showing all the christian channels';
        final intent = await aiService.parseQuery(
          query,
          scope: SearchScope.channels,
        );

        // Result mode should be exhaustive because of "all the list of"
        expect(intent.resultMode, equals(SearchResultMode.exhaustive));

        // Language should be detected as Telugu
        expect(intent.detectedLanguage, equals('telugu'));
        expect(intent.detectedLanguageCode, equals('te'));

        // Clean keywords should not contain conversational stop words
        expect(intent.cleanKeywords, isNot(contains('want')));
        expect(intent.cleanKeywords, isNot(contains('list')));
        expect(intent.cleanKeywords, isNot(contains('channels')));
        expect(intent.cleanKeywords, isNot(contains('showing')));

        // Semantic domain should be religion/Christianity
        expect(intent.detectedCategory, equals('religion'));
        expect(
          intent.semanticSynonyms,
          containsAll([
            'christian',
            'bible',
            'jesus',
            'church',
            'gospel',
            'worship',
          ]),
        );

        // Broaden prompt should be present
        expect(intent.broadenPrompt, isNotNull);

        // High confidence
        expect(intent.confidence, greaterThanOrEqualTo(0.85));
        expect(intent.explanation, contains('Telugu'));
        expect(intent.explanation, contains('Christianity'));
      },
    );

    test('parses topic query: "top space and astronomy topics"', () async {
      const query = 'top space and astronomy topics';
      final intent = await aiService.parseQuery(
        query,
        scope: SearchScope.topics,
      );

      // Result mode should be ranked for "top"
      expect(intent.resultMode, equals(SearchResultMode.ranked));
      expect(intent.detectedCategory, equals('science'));
      expect(
        intent.subdomains,
        containsAll(['Astronomy', 'Astrophysics', 'Space Exploration']),
      );
      expect(intent.confidence, greaterThanOrEqualTo(0.85));
    });

    test(
      'parses negation query: "Telugu channels discussing Christianity rather than devotional music"',
      () async {
        const query =
            'Telugu channels discussing Christianity rather than devotional music';
        final intent = await aiService.parseQuery(
          query,
          scope: SearchScope.channels,
        );

        expect(intent.detectedLanguage, equals('telugu'));
        expect(intent.detectedCategory, equals('religion'));
        expect(intent.excludedTerms, contains('music'));
      },
    );
  });

  group('AiSearchService - Channel Scoring & Ranking', () {
    final aiService = AiSearchService.instance;

    late Channel teluguChristianChannel;
    late Channel englishChristianChannel;
    late Channel teluguCookingChannel;
    late Channel christianMusicChannel;

    setUp(() {
      final now = Timestamp.now();
      teluguChristianChannel = Channel(
        id: 'c_te_christian',
        name: 'Telugu Christian Fellowship',
        nameLowercase: 'telugu christian fellowship',
        handle: '@teluguchristian',
        handleLowercase: '@teluguchristian',
        description:
            'Daily Telugu Bible study, Jesus teachings, and Gospel sermons.',
        avatarUrl: '',
        bannerUrl: '',
        ownerId: 'u1',
        createdAt: now,
        updatedAt: now,
        language: 'te',
        category: 'religion',
        subscriberCount: 50000,
      );

      englishChristianChannel = Channel(
        id: 'c_en_christian',
        name: 'Global Bible Academy',
        nameLowercase: 'global bible academy',
        handle: '@globalbible',
        handleLowercase: '@globalbible',
        description:
            'Christian theology, scripture study, and church ministries.',
        avatarUrl: '',
        bannerUrl: '',
        ownerId: 'u2',
        createdAt: now,
        updatedAt: now,
        category: 'religion',
        subscriberCount: 120000,
      );

      teluguCookingChannel = Channel(
        id: 'c_te_cooking',
        name: 'Telugu Vantalu',
        nameLowercase: 'telugu vantalu',
        handle: '@teluguvantalu',
        handleLowercase: '@teluguvantalu',
        description: 'Authentic Andhra spicy curry and sweet recipes.',
        avatarUrl: '',
        bannerUrl: '',
        ownerId: 'u3',
        createdAt: now,
        updatedAt: now,
        language: 'te',
        category: 'food & cooking',
        subscriberCount: 200000,
      );

      christianMusicChannel = Channel(
        id: 'c_music_christian',
        name: 'Telugu Gospel Music',
        nameLowercase: 'telugu gospel music',
        handle: '@telugugospelmusic',
        handleLowercase: '@telugugospelmusic',
        description:
            'Non-stop Telugu Christian devotional music and worship songs.',
        avatarUrl: '',
        bannerUrl: '',
        ownerId: 'u4',
        createdAt: now,
        updatedAt: now,
        language: 'te',
        category: 'music',
        subscriberCount: 80000,
      );
    });

    test(
      'scores Telugu Christian channel highly for Telugu Christian query',
      () async {
        final intent = await aiService.parseQuery(
          'i want all the list of telugu christian channels',
          scope: SearchScope.channels,
        );

        final teChristianScore = aiService.scoreChannel(
          teluguChristianChannel,
          intent,
        );
        final cookingScore = aiService.scoreChannel(
          teluguCookingChannel,
          intent,
        );

        expect(teChristianScore, greaterThan(80.0));
        expect(cookingScore, equals(0.0)); // Unrelated content has 0 score
      },
    );

    test('respects exclusions ("rather than devotional music")', () async {
      final intent = await aiService.parseQuery(
        'Telugu channels discussing Christianity rather than devotional music',
        scope: SearchScope.channels,
      );

      final fellowshipScore = aiService.scoreChannel(
        teluguChristianChannel,
        intent,
      );
      final musicScore = aiService.scoreChannel(christianMusicChannel, intent);

      expect(fellowshipScore, greaterThan(0.0));
      expect(
        musicScore,
        equals(0.0),
      ); // Excluded because description/name contains 'music'
    });

    test('broadening includes channels from other languages', () async {
      final intent = await aiService.parseQuery(
        'Christian channels across all languages',
        scope: SearchScope.channels,
      );

      final enChristianScore = aiService.scoreChannel(
        englishChristianChannel,
        intent,
      );
      final teChristianScore = aiService.scoreChannel(
        teluguChristianChannel,
        intent,
      );

      expect(enChristianScore, greaterThan(40.0));
      expect(teChristianScore, greaterThan(40.0));
    });
  });

  group('AiSearchService - Topic Scoring & Ranking', () {
    final aiService = AiSearchService.instance;

    late Topic spaceTopic;
    late Topic recipeTopic;

    setUp(() {
      final now = DateTime.now();
      spaceTopic = Topic(
        id: 't_space',
        title: 'Deep Space Astronomy & Cosmology',
        slug: 'deep-space-astronomy',
        handle: 'T/deep-space',
        handleLowercase: 't/deep-space',
        description:
            'Astrophysics, James Webb telescope images, and black hole physics.',
        category: 'science',
        tags: ['space', 'astronomy', 'universe'],
        createdAt: now,
        updatedAt: now,
        videoCount: 15,
      );

      recipeTopic = Topic(
        id: 't_recipe',
        title: 'South Indian Breakfast Recipes',
        slug: 'south-indian-breakfast',
        handle: 'T/south-indian-breakfast',
        handleLowercase: 't/south-indian-breakfast',
        description: 'How to prepare crispy dosa, idli, and chutneys.',
        category: 'food',
        tags: ['breakfast', 'cooking', 'dosa'],
        createdAt: now,
        updatedAt: now,
        videoCount: 22,
      );
    });

    test('scores space topic highly for astronomy query', () async {
      final intent = await aiService.parseQuery(
        'show me space and astronomy topics',
        scope: SearchScope.topics,
      );

      final spaceScore = aiService.scoreTopic(spaceTopic, intent);
      final recipeScore = aiService.scoreTopic(recipeTopic, intent);

      expect(spaceScore, greaterThan(60.0));
      expect(recipeScore, equals(0.0));
    });
  });

  group('AiSearchService - Resilience & Circuit Breaker', () {
    final aiService = AiSearchService.instance;

    setUp(() {
      aiService.clearCache();
      aiService.cloudAssistantHandler = null;
    });

    tearDown(() {
      aiService.clearCache();
      aiService.cloudAssistantHandler = null;
    });

    test(
      'direct keyword queries have high confidence (>= 0.75) and do not invoke cloud assistant',
      () async {
        var cloudCalled = false;
        aiService.cloudAssistantHandler = (q, s) async {
          cloudCalled = true;
          return null;
        };

        final intent = await aiService.parseQuery('cooking recipes');

        expect(cloudCalled, isFalse);
        expect(intent.confidence, greaterThanOrEqualTo(0.75));
        expect(intent.cleanKeywords, containsAll(['cooking', 'recipes']));
        expect(intent.requiresCloudAi, isFalse);
      },
    );

    test(
      'circuit breaker trips on cloud assistant failure and serves local intent without re-attempting cloud call',
      () async {
        var cloudCallCount = 0;
        aiService.cloudAssistantHandler = (q, s) async {
          cloudCallCount++;
          throw Exception(
            'Firebase Cloud Function internal error [firebase_functions/internal]',
          );
        };

        // Query with conversational words and no domain match to trigger cloud fallback
        const conversationalQuery = 'can you find me some cool channels';

        // First call fails and trips circuit breaker
        final firstIntent = await aiService.parseQuery(conversationalQuery);
        expect(firstIntent.cleanKeywords, contains('cool'));
        expect(cloudCallCount, equals(1));
        expect(aiService.isCloudAssistantInCooldown, isTrue);

        // Second call for a different query should be served immediately by circuit breaker without calling cloud
        const secondQuery = 'find me another interesting topic';
        final secondIntent = await aiService.parseQuery(secondQuery);
        expect(secondIntent.cleanKeywords, contains('interesting'));
        expect(
          cloudCallCount,
          equals(1),
        ); // Still 1! Cloud was not called again due to circuit breaker

        // Reset circuit breaker allows probing again
        aiService.resetCircuitBreaker();
        expect(aiService.isCloudAssistantInCooldown, isFalse);
      },
    );
  });
}
