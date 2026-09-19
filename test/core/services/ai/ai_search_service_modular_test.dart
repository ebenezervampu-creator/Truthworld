import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/services/ai/ai_search_service.dart';
import 'package:truthworld/core/services/ai/models/ai_search_intent.dart';
import 'package:truthworld/core/services/ai/search/ai_search_barrel.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/search/data/models/search_result.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';

void main() {
  final now = Timestamp.now();

  group('AiSearchKnowledgeGraph', () {
    test('contains 12 semantic domains with required schema', () {
      expect(AiSearchKnowledgeGraph.semanticDomains.length, greaterThanOrEqualTo(12));
      for (final entry in AiSearchKnowledgeGraph.semanticDomains.entries) {
        expect(entry.value.containsKey('category'), isTrue);
        expect(entry.value.containsKey('domain'), isTrue);
        expect(entry.value.containsKey('synonyms'), isTrue);
        expect(entry.value.containsKey('subdomains'), isTrue);
      }
    });

    test('maps languages to ISO codes and aliases correctly', () {
      expect(AiSearchKnowledgeGraph.languageMap['telugu'], contains('te'));
      expect(AiSearchKnowledgeGraph.languageCodeMap['telugu'], equals('te'));
      expect(AiSearchKnowledgeGraph.languageCodeMap['english'], equals('en'));
      expect(AiSearchKnowledgeGraph.fillerWords, contains('want'));
      expect(AiSearchKnowledgeGraph.fillerWords, contains('channels'));
    });
  });

  group('AiSearchLocalParser', () {
    const parser = AiSearchLocalParser();

    test('parses simple query with mode and keywords', () {
      final intent = parser.parseLocally('Telugu Christian channels');
      expect(intent.detectedLanguage, equals('telugu'));
      expect(intent.detectedLanguageCode, equals('te'));
      expect(intent.detectedCategory, equals('religion'));
      expect(intent.cleanKeywords, contains('christian'));
      expect(intent.resultMode, equals(SearchResultMode.ranked));
      expect(intent.confidence, greaterThanOrEqualTo(0.85));
    });

    test('parses negation and exclusions correctly', () {
      final intent = parser.parseLocally('Telugu Christian channels rather than devotional music');
      expect(intent.excludedTerms, contains('devotional music'));
      expect(intent.cleanKeywords, isNot(contains('devotional')));
    });

    test('detects exhaustive result mode from list keywords', () {
      final intent = parser.parseLocally('all space exploration channels');
      expect(intent.resultMode, equals(SearchResultMode.exhaustive));
      expect(intent.subdomains, isNotEmpty);
    });
  });

  group('AiSearchScoringEngine', () {
    const engine = AiSearchScoringEngine();

    test('scores channel with language and category match', () {
      final intent = AiSearchIntent(
        rawQuery: 'telugu christian channels',
        cleanKeywords: ['christian'],
        detectedLanguage: 'telugu',
        detectedCategory: 'religion',
      );

      final channel = Channel(
        id: 'ch-1',
        name: 'Telugu Christian Fellowship',
        nameLowercase: 'telugu christian fellowship',
        handle: 'teluguchristian',
        handleLowercase: 'teluguchristian',
        description: 'Christian ministry and bible studies',
        category: 'religion',
        language: 'telugu',
        subscriberCount: 15000,
        videoCount: 120,
        isVerified: true,
        avatarUrl: '',
        bannerUrl: '',
        ownerId: 'u1',
        createdAt: now,
        updatedAt: now,
      );

      final score = engine.scoreChannel(channel, intent);
      expect(score, greaterThan(100.0));
    });

    test('returns 0.0 for channel with excluded term', () {
      final intent = AiSearchIntent(
        rawQuery: 'test',
        cleanKeywords: ['test'],
        excludedTerms: ['music'],
      );

      final channel = Channel(
        id: 'ch-2',
        name: 'Gospel Music Hub',
        nameLowercase: 'gospel music hub',
        handle: 'gospelmusic',
        handleLowercase: 'gospelmusic',
        description: 'devotional songs',
        category: 'music',
        language: 'english',
        avatarUrl: '',
        bannerUrl: '',
        ownerId: 'u2',
        createdAt: now,
        updatedAt: now,
      );

      final score = engine.scoreChannel(channel, intent);
      expect(score, equals(0.0));
    });

    test('scores topic against AI intent', () {
      final intent = AiSearchIntent(
        rawQuery: 'space astronomy',
        cleanKeywords: ['space', 'astronomy'],
        subdomains: ['Astronomy', 'Cosmology'],
        detectedCategory: 'science',
      );

      final topic = Topic(
        id: 'top-1',
        title: 'Space Astronomy & Cosmology',
        slug: 'space-astronomy',
        handle: '@space-astronomy',
        handleLowercase: '@space-astronomy',
        description: 'Explore the universe',
        category: 'science',
        tags: ['space', 'astronomy'],
        videoCount: 50,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final score = engine.scoreTopic(topic, intent);
      expect(score, greaterThan(50.0));
    });

    test('scores SearchResult against AI intent', () {
      final intent = AiSearchIntent(
        rawQuery: 'Telugu tech news',
        cleanKeywords: ['tech', 'news'],
        detectedLanguage: 'telugu',
        detectedCategory: 'technology',
      );

      final item = SearchResult(
        id: 'res-1',
        title: 'Telugu Tech News Today',
        channelName: 'Telugu Tech World',
        channelImage: '',
        type: ResultType.channel,
        language: 'telugu',
        category: 'technology',
        views: 25000,
        thumbnail: '',
        createdAt: now,
      );

      final score = engine.scoreSearchResult(item, intent);
      expect(score, greaterThan(80.0));
    });
  });

  group('AiSearchCloudClient & Circuit Breaker', () {
    test('handles circuit breaker trip on consecutive failures', () {
      final client = AiSearchCloudClient();
      expect(client.isCloudAssistantInCooldown, isFalse);

      client.recordFailure();
      expect(client.isCloudAssistantInCooldown, isTrue);

      client.resetCircuitBreaker();
      expect(client.isCloudAssistantInCooldown, isFalse);
    });
  });

  group('AiSearchService Coordinator Facade', () {
    test('caches queries and serves instantly on repeat lookup', () async {
      AiSearchService.instance.clearCache();

      final intent1 = await AiSearchService.instance.parseQuery('Telugu Christian channels');
      final intent2 = await AiSearchService.instance.parseQuery('Telugu Christian channels');

      expect(identical(intent1, intent2), isTrue);
    });

    test('delegates scoring to engine seamlessly', () {
      final intent = AiSearchIntent(
        rawQuery: 'space',
        cleanKeywords: ['space'],
      );
      final topic = Topic(
        id: 't-1',
        title: 'Deep Space',
        slug: 'deep-space',
        handle: '@deep-space',
        handleLowercase: '@deep-space',
        description: 'Universe',
        category: 'science',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final score = AiSearchService.instance.scoreTopic(topic, intent);
      expect(score, greaterThan(0.0));
    });
  });
}
