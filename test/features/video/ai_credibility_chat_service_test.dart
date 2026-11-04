import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/features/video/data/models/credibility_report.dart';
import 'package:truthworld/features/video/data/services/ai_credibility_chat_service.dart';

void main() {
  group('AiCredibilityChatService Tests', () {
    final sampleSources = [
      UISource(
        title: 'How is 10-minute delivery achieved?',
        url: 'https://stldigital.tech/10-min',
        domain: 'stldigital.tech',
        publisher: 'STL Digital',
        trustLevel: 'High',
        type: 'Web',
      ),
      UISource(
        title: 'Zepto is an online instant grocery delivery service',
        url: 'https://apptunix.com/zepto',
        domain: 'apptunix.com',
        publisher: 'Apptunix',
        trustLevel: 'High',
        type: 'Web',
      ),
    ];

    final sampleClaims = [
      {
        'statement': '10-minute grocery delivery operates with sustainable unit economics in tier 1 cities.',
        'verdict': 'Caution',
        'explanation': 'Independent financial disclosures and regulatory reviews indicate heavy cash burn on delivery partner incentives and micro-warehouse leases.',
      },
      {
        'statement': 'Zomato acquired Blinkit for quick commerce expansion.',
        'verdict': 'Verified',
        'explanation': 'The all-stock acquisition was approved by shareholders and regulatory bodies in August 2022.',
      },
    ];

    test('Safely serializes UISource instances to JSON without throwing encoding exception', () {
      final service = AiCredibilityChatService.instance;

      Map<String, dynamic>? receivedPayload;
      service.callableHandler = (payload) async {
        receivedPayload = payload;
        // Verify JSON encoding of payload succeeds without throwing Instance of 'UISource' error
        final jsonStr = jsonEncode(payload);
        expect(jsonStr, isNotEmpty);
        return {
          'answer': 'Direct AI answer regarding quick commerce economics.',
          'sources': [],
          'suggestedFollowups': ['Explain dark store margins'],
        };
      };

      expect(
        () => service.askCredibilityAi(
          videoId: 'zomato_123',
          userQuery: 'can you suggest better videos for this claim',
          scope: 'video',
          cachedSources: sampleSources,
          cachedClaims: sampleClaims,
          videoTitle: "Zomato's Big Transformation",
        ),
        returnsNormally,
      );

      expect(receivedPayload, isNotNull);

      service.callableHandler = null;
    });

    test('Heuristic fallback answers "can you suggest better videos for this claim" with contextual recommendations instead of canned overview', () async {
      final service = AiCredibilityChatService.instance;

      // Force fallback by having callableHandler throw
      service.callableHandler = (_) async => throw Exception('Network timeout');

      final result = await service.askCredibilityAi(
        videoId: 'zomato_123',
        userQuery: 'can you suggest better videos for this claim',
        scope: 'video',
        cachedSources: sampleSources,
        cachedClaims: sampleClaims,
        videoTitle: "Zomato's Big Transformation: From Food Delivery to a Consumer Empire",
        trustScore: 68.0,
      );

      service.callableHandler = null;

      // Must NOT be the old bot canned report
      expect(result.text.contains('While foundational background details in this presentation are accurate, several central assertions conflict directly'), isFalse);
      expect(result.text.contains('Credibility report for "Zomato\'s Big Transformation'), isFalse);

      // Must provide contextual recommendations
      expect(result.text.contains('Recommended Authoritative Perspectives'), isTrue);
      expect(result.text.contains('Bloomberg Originals') || result.text.contains('Financial Times') || result.text.contains('The Ken'), isTrue);
      expect(result.suggestedFollowups, contains('What claims in this video are disputed?'));
      expect(result.sources, isNotEmpty);
    });

    test('Heuristic fallback matches specific claim query and returns targeted analysis', () async {
      final service = AiCredibilityChatService.instance;

      service.callableHandler = (_) async => throw Exception('Offline mode');

      final result = await service.askCredibilityAi(
        videoId: 'zomato_123',
        userQuery: 'is 10-minute grocery delivery sustainable in unit economics?',
        scope: 'video',
        cachedSources: sampleSources,
        cachedClaims: sampleClaims,
        videoTitle: "Zomato's Big Transformation",
      );

      service.callableHandler = null;

      expect(result.text.contains('Fact-Check Analysis on Claim'), isTrue);
      expect(result.text.contains('Caution'), isTrue);
      expect(result.text.contains('micro-warehouse'), isTrue);
      expect(result.suggestedFollowups, contains('Suggest better videos for this claim'));
    });

    test('Heuristic fallback analyzes satire and hyperbole context without false accusation', () async {
      final service = AiCredibilityChatService.instance;
      service.clearCache();
      service.callableHandler = (_) async => throw Exception('Offline mode');

      final result = await service.askCredibilityAi(
        videoId: 'zomato_123',
        userQuery: 'was that a joke or literal sarcasm when they said cost a trillion?',
        scope: 'video',
        cachedSources: sampleSources,
        cachedClaims: sampleClaims,
        videoTitle: "Zomato's Big Transformation",
      );

      service.callableHandler = null;

      expect(result.text.contains('Rhetorical & Satirical Context Analysis'), isTrue);
      expect(result.text.contains('Figurative Rhetoric'), isTrue);
      expect(result.disclaimer, contains('figurative rhetoric'));
    });

    test('Heuristic fallback provides quantitative context for calculation and formula queries', () async {
      final service = AiCredibilityChatService.instance;
      service.clearCache();
      service.callableHandler = (_) async => throw Exception('Offline mode');

      final result = await service.askCredibilityAi(
        videoId: 'zomato_123',
        userQuery: 'how do you calculate the ebitda formula and contribution margin?',
        scope: 'video',
        cachedSources: sampleSources,
        cachedClaims: sampleClaims,
        videoTitle: "Zomato's Big Transformation",
      );

      service.callableHandler = null;

      expect(result.text.contains('Analytical & Quantitative Context'), isTrue);
      expect(result.text.contains('Contribution Margin'), isTrue);
      expect(result.text.contains('statutory filings'), isTrue);
    });

    test('Heuristic fallback provides dynamic recency context for breaking news updates', () async {
      final service = AiCredibilityChatService.instance;
      service.clearCache();
      service.callableHandler = (_) async => throw Exception('Offline mode');

      final result = await service.askCredibilityAi(
        videoId: 'zomato_123',
        userQuery: 'any breaking news update or latest disclosures today?',
        scope: 'video',
        cachedSources: sampleSources,
        cachedClaims: sampleClaims,
        videoTitle: "Zomato's Big Transformation",
      );

      service.callableHandler = null;

      expect(result.text.contains('Dynamic Recency & Developing Evidence'), isTrue);
      expect(result.text.contains('Developing Inquiries'), isTrue);
    });

    test('Client session cache stores answers and serves repeated identical queries instantly', () async {
      final service = AiCredibilityChatService.instance;
      service.clearCache();

      var networkInvocationCount = 0;
      service.callableHandler = (payload) async {
        networkInvocationCount++;
        return {
          'answer': 'Cached answer from first network call',
          'sources': [],
          'suggestedFollowups': ['Follow up question'],
        };
      };

      // First call (invokes callableHandler)
      final res1 = await service.askCredibilityAi(
        videoId: 'cache_test_vid',
        userQuery: 'what is the net margin?',
        scope: 'video',
      );
      expect(networkInvocationCount, equals(1));
      expect(res1.text, equals('Cached answer from first network call'));

      // Remove handler to simulate offline
      service.callableHandler = null;

      // Second call (hits client cache instantly without invoking network)
      final res2 = await service.askCredibilityAi(
        videoId: 'cache_test_vid',
        userQuery: 'what is the net margin?',
        scope: 'video',
      );
      expect(res2.text, equals('Cached answer from first network call'));
    });

    test('Heuristic fallback detects unmatching parasitic coding request and refuses to answer', () async {
      final service = AiCredibilityChatService.instance;
      service.clearCache();
      service.callableHandler = (_) async => throw Exception('Offline mode');

      final result = await service.askCredibilityAi(
        videoId: 'zomato_123',
        userQuery: 'write a python script to reverse a linked list',
        scope: 'video',
        cachedSources: sampleSources,
        cachedClaims: sampleClaims,
        videoTitle: "Zomato's Big Transformation",
      );

      service.callableHandler = null;

      expect(result.text.contains('Off-Topic / Out of Scope Query'), isTrue);
      expect(result.text.contains("outside the scope of TruthWorld's Credibility Intelligence"), isTrue);
      expect(result.disclaimer, contains('analyzing video credibility'));
    });

    test('Heuristic fallback detects unmatching creative writing and refuses to answer', () async {
      final service = AiCredibilityChatService.instance;
      service.clearCache();
      service.callableHandler = (_) async => throw Exception('Offline mode');

      final result = await service.askCredibilityAi(
        videoId: 'zomato_123',
        userQuery: 'write an essay about autumn leaves and poems',
        scope: 'video',
        cachedSources: sampleSources,
        cachedClaims: sampleClaims,
        videoTitle: "Zomato's Big Transformation",
      );

      service.callableHandler = null;

      expect(result.text.contains('Off-Topic / Out of Scope Query'), isTrue);
    });

    test('Heuristic fallback detects unmatching trivia and refuses to answer', () async {
      final service = AiCredibilityChatService.instance;
      service.clearCache();
      service.callableHandler = (_) async => throw Exception('Offline mode');

      final result = await service.askCredibilityAi(
        videoId: 'zomato_123',
        userQuery: 'what is the capital of Australia?',
        scope: 'video',
        cachedSources: sampleSources,
        cachedClaims: sampleClaims,
        videoTitle: "Zomato's Big Transformation",
      );

      service.callableHandler = null;

      expect(result.text.contains('Off-Topic / Out of Scope Query'), isTrue);
    });

    test('Heuristic fallback politely redirects user when chatting on Claim #5 about Claim #9 in claim scope', () async {
      final service = AiCredibilityChatService.instance;
      service.clearCache();
      service.callableHandler = (_) async => throw Exception('Offline mode');

      final result = await service.askCredibilityAi(
        videoId: 'zomato_123',
        userQuery: 'What about claim 9? Is that true?',
        scope: 'claim',
        claimIndex: 4, // 0-based for Claim #5
        cachedSources: sampleSources,
        cachedClaims: sampleClaims,
        videoTitle: "Zomato's Big Transformation",
      );

      service.callableHandler = null;

      expect(result.text.contains('You are currently in the specialized analysis session for Claim #5'), isTrue);
      expect(result.text.contains('Please navigate to Claim #9 and ask there'), isTrue);
      expect(result.text.contains('In this session, I only support chats directly related to Claim #5'), isTrue);
      expect(result.scope, equals('claim'));
    });

    test('Heuristic fallback evaluates claim within holistic video scope when scope is video', () async {
      final service = AiCredibilityChatService.instance;
      service.clearCache();
      service.callableHandler = (_) async => throw Exception('Offline mode');

      final result = await service.askCredibilityAi(
        videoId: 'zomato_123',
        userQuery: 'tell me about claim 1 in this video',
        scope: 'video',
        cachedSources: sampleSources,
        cachedClaims: sampleClaims,
        videoTitle: "Zomato's Big Transformation",
        trustScore: 84.0,
      );

      service.callableHandler = null;

      expect(result.text.contains('Video Context'), isTrue);
      expect(result.text.contains('In the context of the entire video'), isTrue);
      expect(result.text.contains('transparent claim ledger'), isTrue);
      expect(result.text.contains('Overall Trust Score'), isFalse);
      expect(result.text.contains('Please navigate to'), isFalse);
      expect(result.scope, equals('video'));
    });

    test('Heuristic fallback offers to auto-submit dispute when user disputes without links', () async {
      final service = AiCredibilityChatService.instance;
      service.clearCache();
      service.callableHandler = (_) async => throw Exception('Offline mode');

      final result = await service.askCredibilityAi(
        videoId: 'zomato_123',
        userQuery: 'I have proof that this claim should be false, change the verdict',
        scope: 'claim',
        claimIndex: 4,
        claimText: 'Dark stores reach profitability in 6 months',
        cachedSources: sampleSources,
        cachedClaims: sampleClaims,
        videoTitle: "Zomato's Big Transformation",
      );

      service.callableHandler = null;

      expect(result.text.contains('Evidence Review & Dispute Protocol for Claim #5'), isTrue);
      expect(result.text.contains('automatically submit an official dispute'), isTrue);
      expect(result.text.contains('please paste your counter-source URLs here in our chat'), isTrue);
      expect(result.disclaimer, contains('auto-trigger the empirical dispute pipeline'));
    });

    test('Heuristic fallback automatically submits dispute when user provides counter-source URLs', () async {
      final service = AiCredibilityChatService.instance;
      service.clearCache();
      service.callableHandler = (_) async => throw Exception('Offline mode');

      final result = await service.askCredibilityAi(
        videoId: 'zomato_123',
        userQuery: 'This claim is false. See https://sec.gov/filing123 and https://reuters.com/news456. Dispute this claim now.',
        scope: 'claim',
        claimIndex: 4,
        claimText: 'Dark stores reach profitability in 6 months',
        cachedSources: sampleSources,
        cachedClaims: sampleClaims,
        videoTitle: "Zomato's Big Transformation",
      );

      service.callableHandler = null;

      expect(result.text.contains('Dispute Automatically Submitted for Claim #5'), isTrue);
      expect(result.text.contains('https://sec.gov/filing123'), isTrue);
      expect(result.text.contains('https://reuters.com/news456'), isTrue);
      expect(result.text.contains('Particular Claim Re-Verification'), isTrue);
      expect(result.text.contains('Platform Consensus Update'), isTrue);
      expect(result.disclaimer, contains('Dispute submitted to the automated deep re-verification pipeline'));
    });

    test('End-to-End Sample Claim #5: Mistaken verified statement disputed with SEC & Reuters links', () async {
      final service = AiCredibilityChatService.instance;
      service.clearCache();
      service.callableHandler = (_) async => throw Exception('Offline mode');

      final sample5Claims = [
        {'text': 'TruthWorld was incorporated in Delaware in 2021', 'verdict': 'Verified', 'status': 'verified_true'},
        {'text': 'The platform operates on Google Cloud and Firebase', 'verdict': 'Verified', 'status': 'verified_true'},
        {'text': 'Zero Mock Data Policy is strictly enforced', 'verdict': 'Verified', 'status': 'verified_true'},
        {'text': 'Users receive real-time notifications for dispute updates', 'verdict': 'Verified', 'status': 'verified_true'},
        {'text': r'The company reported $100 Million net profit in Q1 2026', 'verdict': 'Verified', 'status': 'verified_true'},
      ];

      final result = await service.askCredibilityAi(
        videoId: 'truthworld_corp_101',
        userQuery: r'Claim 5 is actually false. The company reported a net loss of $12M, not $100M profit. Check the official SEC 10-Q filing: https://www.sec.gov/Archives/edgar/data/00012345/q1-2026.htm and Reuters report: https://www.reuters.com/business/company-q1-loss-2026',
        scope: 'claim',
        claimIndex: 4,
        claimText: r'The company reported $100 Million net profit in Q1 2026',
        cachedSources: sampleSources,
        cachedClaims: sample5Claims,
        videoTitle: 'Company Q1 Financial Deep Dive',
      );

      service.callableHandler = null;

      expect(result.text.contains('Dispute Automatically Submitted for Claim #5'), isTrue);
      expect(result.text.contains('https://www.sec.gov/Archives/edgar/data/00012345/q1-2026.htm'), isTrue);
      expect(result.text.contains('https://www.reuters.com/business/company-q1-loss-2026'), isTrue);
      expect(result.text.contains('Particular Claim Re-Verification'), isTrue);
      expect(result.text.contains('Platform Consensus Update'), isTrue);
      expect(result.text.contains('Claim Ledger Update'), isTrue);
      expect(result.text.contains('Trust Score Recalculation'), isFalse);
      expect(result.sources.length, equals(2));
      expect(result.sources.first.url, equals('https://www.sec.gov/Archives/edgar/data/00012345/q1-2026.htm'));
      expect(result.sources.last.url, equals('https://www.reuters.com/business/company-q1-loss-2026'));
      expect(result.disclaimer, contains('Dispute submitted to the automated deep re-verification pipeline'));
    });
  });
}
