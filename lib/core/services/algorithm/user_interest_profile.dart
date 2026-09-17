import 'dart:math';

import 'package:truthworld/features/topics/data/models/topic.dart';

/// Inferred behavioral cognitive consumption styles
enum CognitiveArchetype {
  analyticalDeepDiver,
  curiousExplorer,
  focusedSpecialist,
  actionOrientedConsumer,
  balancedInquirer,
}

/// Inferred user behavioral psychology and personality profile
class UserPsychologyProfile {
  final CognitiveArchetype archetype;
  final String archetypeDisplayName;
  final String archetypeDescription;
  final double opennessToNovelty; // 0.0 - 1.0
  final double criticalThinkingIndex; // 0.0 - 1.0
  final double intellectualDepthScore; // 0.0 - 1.0
  final double focusVsBreadth; // 0.0 (broad generalist) - 1.0 (deep specialist)
  final List<String> topLovedCategories;
  final List<String> topLovedTopics;
  final List<String> topLovedChannels;
  final Map<String, double> categoryLoveScores;
  final Map<String, double> topicLoveScores;

  const UserPsychologyProfile({
    required this.archetype,
    required this.archetypeDisplayName,
    required this.archetypeDescription,
    this.opennessToNovelty = 0.5,
    this.criticalThinkingIndex = 0.5,
    this.intellectualDepthScore = 0.5,
    this.focusVsBreadth = 0.5,
    this.topLovedCategories = const [],
    this.topLovedTopics = const [],
    this.topLovedChannels = const [],
    this.categoryLoveScores = const {},
    this.topicLoveScores = const {},
  });

  /// Compute how much this video aligns with what the user deeply loves (0.0 to 1.0)
  double calculateLoveScore({
    required String category,
    List<String> topics = const [],
    String channelId = '',
  }) {
    var score = 0.0;

    // Category love component (40%)
    final catLove = categoryLoveScores[category] ??
        categoryLoveScores[category.toLowerCase()] ??
        0.0;
    score += catLove * 0.40;

    // Topic love component (40%)
    var maxTopicLove = 0.0;
    for (final t in topics) {
      final clean = t.toLowerCase().replaceFirst('topic:', '');
      final tLove = topicLoveScores[clean] ??
          topicLoveScores['topic:$clean'] ??
          topicLoveScores[t] ??
          0.0;
      if (tLove > maxTopicLove) maxTopicLove = tLove;
    }
    score += maxTopicLove * 0.40;

    // Channel love component (20%)
    if (topLovedChannels.contains(channelId)) {
      score += 0.20;
    }

    return score.clamp(0.0, 1.0);
  }

  // Aliases for intuitive access
  double get noveltyPreference => opennessToNovelty;
  double get criticalThinkingScore => criticalThinkingIndex;
}

/// The user's computed interest profile — their personalization DNA.
/// Loaded once on auth, refreshed every 15 minutes, consumed by all surfaces.
class UserInterestProfile {
  // === Long-term Interests (from Firestore) ===
  final String userId;
  final Map<String, double> categoryAffinities; // 'Technology' → 0.85
  final Map<String, double> topicAffinities; // 'topic:ai' → 0.72

  // === Interest Graph (topic co-occurrence) ===
  final Map<String, double> interestGraph;

  // === Following & Subscriptions ===
  final Set<String> followedTopicSlugs;
  final Set<String> subscribedChannelIds;

  // === Watch History & Behavioral Metrics ===
  final Set<String> recentlyWatchedVideoIds; // last 200
  final Map<String, double> watchProgress; // videoId → 0.0-1.0
  final Map<String, int> categoryWatchCounts; // last 30 days
  final Map<String, int> topicWatchCounts; // last 30 days
  final int totalWatchDurationSec;
  final double avgWatchCompletion;
  final int factCheckedWatchCount;
  final int longFormWatchCount;

  // === Engagement Signals ===
  final Set<String> recentlyLikedVideoIds; // last 100
  final Set<String> recentlyDislikedVideoIds; // last 50

  // === Negative Signals ===
  final Set<String> notInterestedVideoIds;
  final Set<String> blockedChannelIds;
  final Map<String, int> skippedCategoryCounts; // categories frequently skipped
  final Map<String, int> earlyExitCategoryCounts; // categories exited < 5s

  // === Search History & Intent ===
  final List<String> recentSearchQueries; // last 20
  final Map<String, int> searchTopicCounts; // query/topic term → count

  // === Exploration & Discovery Tracking ===
  final Set<String> exploredTopicSlugs; // topics explicitly explored/clicked
  final Map<String, int> topicExploreCounts;
  final Set<String> discoveredChannelIds; // channels discovered
  final Map<String, int> channelExploreCounts;

  // === Creator Exposure Tracking ===
  final Map<String, int> channelExposureCounts; // channelId → times shown today

  // === Signals & Additional Affinities ===
  final List<UserSignal> recentSignals;
  final Set<String> dislikedCategories;
  final Map<String, double> channelAffinities;

  // === Flip Coin / Perspective Exposure Tracking ===
  final int flipCoinCount;
  final int oppositeWatchesCount;

  UserInterestProfile({
    this.userId = '',
    this.categoryAffinities = const {},
    this.topicAffinities = const {},
    this.interestGraph = const {},
    this.followedTopicSlugs = const {},
    this.subscribedChannelIds = const {},
    this.recentlyWatchedVideoIds = const {},
    this.watchProgress = const {},
    this.categoryWatchCounts = const {},
    this.topicWatchCounts = const {},
    this.totalWatchDurationSec = 0,
    this.avgWatchCompletion = 0.0,
    this.factCheckedWatchCount = 0,
    this.longFormWatchCount = 0,
    this.recentlyLikedVideoIds = const {},
    this.recentlyDislikedVideoIds = const {},
    this.notInterestedVideoIds = const {},
    this.blockedChannelIds = const {},
    this.skippedCategoryCounts = const {},
    this.earlyExitCategoryCounts = const {},
    this.recentSearchQueries = const [],
    this.searchTopicCounts = const {},
    this.exploredTopicSlugs = const {},
    this.topicExploreCounts = const {},
    this.discoveredChannelIds = const {},
    this.channelExploreCounts = const {},
    this.channelExposureCounts = const {},
    this.recentSignals = const [],
    this.dislikedCategories = const {},
    this.channelAffinities = const {},
    this.flipCoinCount = 0,
    this.oppositeWatchesCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'categoryAffinities': categoryAffinities,
      'topicAffinities': topicAffinities,
      'interestGraph': interestGraph,
      'followedTopicSlugs': followedTopicSlugs.toList(),
      'subscribedChannelIds': subscribedChannelIds.toList(),
      'recentlyWatchedVideoIds': recentlyWatchedVideoIds.toList(),
      'watchProgress': watchProgress,
      'categoryWatchCounts': categoryWatchCounts,
      'topicWatchCounts': topicWatchCounts,
      'totalWatchDurationSec': totalWatchDurationSec,
      'avgWatchCompletion': avgWatchCompletion,
      'factCheckedWatchCount': factCheckedWatchCount,
      'longFormWatchCount': longFormWatchCount,
      'recentlyLikedVideoIds': recentlyLikedVideoIds.toList(),
      'recentlyDislikedVideoIds': recentlyDislikedVideoIds.toList(),
      'notInterestedVideoIds': notInterestedVideoIds.toList(),
      'blockedChannelIds': blockedChannelIds.toList(),
      'skippedCategoryCounts': skippedCategoryCounts,
      'earlyExitCategoryCounts': earlyExitCategoryCounts,
      'recentSearchQueries': recentSearchQueries,
      'searchTopicCounts': searchTopicCounts,
      'exploredTopicSlugs': exploredTopicSlugs.toList(),
      'topicExploreCounts': topicExploreCounts,
      'discoveredChannelIds': discoveredChannelIds.toList(),
      'channelExploreCounts': channelExploreCounts,
      'channelExposureCounts': channelExposureCounts,
      'recentSignals': recentSignals.map((s) => s.toMap()).toList(),
      'dislikedCategories': dislikedCategories.toList(),
      'channelAffinities': channelAffinities,
      'flipCoinCount': flipCoinCount,
      'oppositeWatchesCount': oppositeWatchesCount,
    };
  }

  factory UserInterestProfile.guest({String userId = 'guest'}) {
    return UserInterestProfile(
      userId: userId,
      avgWatchCompletion: 0.5,
    );
  }

  factory UserInterestProfile.fromMap(Map<String, dynamic> data) {
    return UserInterestProfile.fromFirestore(data);
  }

  factory UserInterestProfile.fromFirestore(Map<String, dynamic> data) {
    return UserInterestProfile(
      userId: data['userId']?.toString() ?? '',
      categoryAffinities: Map<String, double>.from(
        (data['categoryAffinities'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
            ) ??
            {},
      ),
      topicAffinities: Map<String, double>.from(
        (data['topicAffinities'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
            ) ??
            {},
      ),
      interestGraph: Map<String, double>.from(
        (data['interestGraph'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
            ) ??
            {},
      ),
      followedTopicSlugs: Set<String>.from(data['followedTopicSlugs'] ?? []),
      subscribedChannelIds: Set<String>.from(
        data['subscribedChannelIds'] ?? [],
      ),
      recentlyWatchedVideoIds: Set<String>.from(
        data['recentlyWatchedVideoIds'] ?? [],
      ),
      watchProgress: Map<String, double>.from(
        (data['watchProgress'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
            ) ??
            {},
      ),
      categoryWatchCounts: Map<String, int>.from(
        (data['categoryWatchCounts'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), (v as num).toInt()),
            ) ??
            {},
      ),
      topicWatchCounts: Map<String, int>.from(
        (data['topicWatchCounts'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), (v as num).toInt()),
            ) ??
            {},
      ),
      totalWatchDurationSec:
          (data['totalWatchDurationSec'] as num?)?.toInt() ?? 0,
      avgWatchCompletion:
          (data['avgWatchCompletion'] as num?)?.toDouble() ?? 0.0,
      factCheckedWatchCount:
          (data['factCheckedWatchCount'] as num?)?.toInt() ?? 0,
      longFormWatchCount:
          (data['longFormWatchCount'] as num?)?.toInt() ?? 0,
      recentlyLikedVideoIds: Set<String>.from(
        data['recentlyLikedVideoIds'] ?? [],
      ),
      recentlyDislikedVideoIds: Set<String>.from(
        data['recentlyDislikedVideoIds'] ?? [],
      ),
      notInterestedVideoIds: Set<String>.from(
        data['notInterestedVideoIds'] ?? [],
      ),
      blockedChannelIds: Set<String>.from(data['blockedChannelIds'] ?? []),
      skippedCategoryCounts: Map<String, int>.from(
        (data['skippedCategoryCounts'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), (v as num).toInt()),
            ) ??
            {},
      ),
      earlyExitCategoryCounts: Map<String, int>.from(
        (data['earlyExitCategoryCounts'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), (v as num).toInt()),
            ) ??
            {},
      ),
      recentSearchQueries: List<String>.from(data['recentSearchQueries'] ?? []),
      searchTopicCounts: Map<String, int>.from(
        (data['searchTopicCounts'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), (v as num).toInt()),
            ) ??
            {},
      ),
      exploredTopicSlugs: Set<String>.from(data['exploredTopicSlugs'] ?? []),
      topicExploreCounts: Map<String, int>.from(
        (data['topicExploreCounts'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), (v as num).toInt()),
            ) ??
            {},
      ),
      discoveredChannelIds:
          Set<String>.from(data['discoveredChannelIds'] ?? []),
      channelExploreCounts: Map<String, int>.from(
        (data['channelExploreCounts'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), (v as num).toInt()),
            ) ??
            {},
      ),
      channelExposureCounts: Map<String, int>.from(
        (data['channelExposureCounts'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), (v as num).toInt()),
            ) ??
            {},
      ),
      recentSignals:
          (data['recentSignals'] as List<dynamic>?)
              ?.map((e) => UserSignal.fromMap(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
      dislikedCategories: Set<String>.from(data['dislikedCategories'] ?? []),
      channelAffinities: Map<String, double>.from(
        (data['channelAffinities'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
            ) ??
            {},
      ),
      flipCoinCount: (data['flipCoinCount'] as num?)?.toInt() ?? 0,
      oppositeWatchesCount:
          (data['oppositeWatchesCount'] as num?)?.toInt() ?? 0,
    );
  }

  UserInterestProfile copyWith({
    String? userId,
    Map<String, double>? categoryAffinities,
    Map<String, double>? topicAffinities,
    Map<String, double>? interestGraph,
    Set<String>? followedTopicSlugs,
    Set<String>? subscribedChannelIds,
    Set<String>? recentlyWatchedVideoIds,
    Map<String, double>? watchProgress,
    Map<String, int>? categoryWatchCounts,
    Map<String, int>? topicWatchCounts,
    int? totalWatchDurationSec,
    double? avgWatchCompletion,
    int? factCheckedWatchCount,
    int? longFormWatchCount,
    Set<String>? recentlyLikedVideoIds,
    Set<String>? recentlyDislikedVideoIds,
    Set<String>? notInterestedVideoIds,
    Set<String>? blockedChannelIds,
    Map<String, int>? skippedCategoryCounts,
    Map<String, int>? earlyExitCategoryCounts,
    List<String>? recentSearchQueries,
    Map<String, int>? searchTopicCounts,
    Set<String>? exploredTopicSlugs,
    Map<String, int>? topicExploreCounts,
    Set<String>? discoveredChannelIds,
    Map<String, int>? channelExploreCounts,
    Map<String, int>? channelExposureCounts,
    List<UserSignal>? recentSignals,
    Set<String>? dislikedCategories,
    Map<String, double>? channelAffinities,
    int? flipCoinCount,
    int? oppositeWatchesCount,
  }) {
    return UserInterestProfile(
      userId: userId ?? this.userId,
      categoryAffinities: categoryAffinities ?? this.categoryAffinities,
      topicAffinities: topicAffinities ?? this.topicAffinities,
      interestGraph: interestGraph ?? this.interestGraph,
      followedTopicSlugs: followedTopicSlugs ?? this.followedTopicSlugs,
      subscribedChannelIds: subscribedChannelIds ?? this.subscribedChannelIds,
      recentlyWatchedVideoIds:
          recentlyWatchedVideoIds ?? this.recentlyWatchedVideoIds,
      watchProgress: watchProgress ?? this.watchProgress,
      categoryWatchCounts: categoryWatchCounts ?? this.categoryWatchCounts,
      topicWatchCounts: topicWatchCounts ?? this.topicWatchCounts,
      totalWatchDurationSec:
          totalWatchDurationSec ?? this.totalWatchDurationSec,
      avgWatchCompletion: avgWatchCompletion ?? this.avgWatchCompletion,
      factCheckedWatchCount:
          factCheckedWatchCount ?? this.factCheckedWatchCount,
      longFormWatchCount: longFormWatchCount ?? this.longFormWatchCount,
      recentlyLikedVideoIds:
          recentlyLikedVideoIds ?? this.recentlyLikedVideoIds,
      recentlyDislikedVideoIds:
          recentlyDislikedVideoIds ?? this.recentlyDislikedVideoIds,
      notInterestedVideoIds:
          notInterestedVideoIds ?? this.notInterestedVideoIds,
      blockedChannelIds: blockedChannelIds ?? this.blockedChannelIds,
      skippedCategoryCounts:
          skippedCategoryCounts ?? this.skippedCategoryCounts,
      earlyExitCategoryCounts:
          earlyExitCategoryCounts ?? this.earlyExitCategoryCounts,
      recentSearchQueries: recentSearchQueries ?? this.recentSearchQueries,
      searchTopicCounts: searchTopicCounts ?? this.searchTopicCounts,
      exploredTopicSlugs: exploredTopicSlugs ?? this.exploredTopicSlugs,
      topicExploreCounts: topicExploreCounts ?? this.topicExploreCounts,
      discoveredChannelIds:
          discoveredChannelIds ?? this.discoveredChannelIds,
      channelExploreCounts:
          channelExploreCounts ?? this.channelExploreCounts,
      channelExposureCounts:
          channelExposureCounts ?? this.channelExposureCounts,
      recentSignals: recentSignals ?? this.recentSignals,
      dislikedCategories: dislikedCategories ?? this.dislikedCategories,
      channelAffinities: channelAffinities ?? this.channelAffinities,
      flipCoinCount: flipCoinCount ?? this.flipCoinCount,
      oppositeWatchesCount: oppositeWatchesCount ?? this.oppositeWatchesCount,
    );
  }

  // === User Psychology & Inferred Personality Profiling ===

  UserPsychologyProfile get psychologyProfile {
    // 1. Compute Category Love Scores
    final catLoveScores = <String, double>{};
    final allCats = <String>{
      ...categoryAffinities.keys,
      ...categoryWatchCounts.keys,
    };

    final maxWatches = categoryWatchCounts.values.isEmpty
        ? 1
        : categoryWatchCounts.values.reduce(max);

    for (final cat in allCats) {
      final affinity = categoryAffinities[cat] ?? 0.0;
      final watchRatio = maxWatches > 0
          ? ((categoryWatchCounts[cat] ?? 0) / max(maxWatches, 1))
          : (avgWatchCompletion > 0 ? avgWatchCompletion * 0.6 : 0.0);
      final searchTopicCount = searchTopicCounts[cat] ?? searchTopicCounts[cat.toLowerCase()] ?? 0;
      final searchQueriesCount = recentSearchQueries
              .where((q) => q.toLowerCase().contains(cat.toLowerCase()))
              .length;
      final searchWeight = (searchTopicCount * 0.04) + (searchQueriesCount * 0.05);
      final score = (affinity * 0.50) +
          (watchRatio * 0.30) +
          min(searchWeight, 0.20);
      catLoveScores[cat] = score.clamp(0.0, 1.0);
    }

    // 2. Compute Topic Love Scores
    final topLoveScores = <String, double>{};
    final allTopics = <String>{
      ...topicAffinities.keys,
      ...topicWatchCounts.keys,
      ...topicExploreCounts.keys,
      ...searchTopicCounts.keys,
    };

    for (final t in allTopics) {
      final clean = t.replaceFirst('topic:', '');
      final affinity = topicAffinities[t] ?? topicAffinities['topic:$clean'] ?? 0.0;
      final watches = topicWatchCounts[clean] ?? topicWatchCounts[t] ?? 0;
      final explores = topicExploreCounts[clean] ?? topicExploreCounts[t] ?? 0;
      final searches = searchTopicCounts[clean] ?? searchTopicCounts[t] ?? 0;

      final score = (affinity * 0.45) +
          (min(watches * 0.1, 0.20)) +
          (min(explores * 0.15, 0.20)) +
          (min(searches * 0.05, 0.15));
      topLoveScores[clean] = score.clamp(0.0, 1.0);
    }

    // Top Loved Lists
    final sortedCats = catLoveScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topLovedCategories = sortedCats
        .where((e) => e.value > 0.2)
        .take(4)
        .map((e) => e.key)
        .toList();

    final sortedTopics = topLoveScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topLovedTopics = sortedTopics
        .where((e) => e.value > 0.2)
        .take(6)
        .map((e) => e.key)
        .toList();

    // Top Loved Channels
    final lovedChannels = <String>{...subscribedChannelIds, ...discoveredChannelIds};
    channelAffinities.forEach((ch, aff) {
      if (aff >= 0.5) lovedChannels.add(ch);
    });
    channelExploreCounts.forEach((ch, count) {
      if (count >= 2) lovedChannels.add(ch);
    });

    // 3. Behavioral Metrics
    // Openness to Novelty (0.0 to 1.0): diversity of exploration vs sticking to 1 thing
    final totalExplorations = exploredTopicSlugs.length +
        discoveredChannelIds.length +
        categoryWatchCounts.length;
    final openness = min(
      1.0,
      (totalExplorations * 0.08) +
          (flipCoinCount * 0.06) +
          (oppositeWatchesCount * 0.08),
    );

    // Critical Thinking Index (0.0 to 1.0): fact-checks, evidence, debate pairs, flip coin
    final totalWatches = max(recentlyWatchedVideoIds.length, factCheckedWatchCount);
    final factCheckRatio = totalWatches > 0
        ? (factCheckedWatchCount / totalWatches)
        : (factCheckedWatchCount > 0 ? 1.0 : 0.0);
    final criticalThinking = min(
      1.0,
      (factCheckRatio * 0.60) +
          (factCheckedWatchCount >= 5 ? 0.25 : (factCheckedWatchCount > 0 ? 0.15 : 0.0)) +
          (flipCoinCount > 0 ? 0.20 : 0.0) +
          (oppositeWatchesCount * 0.15),
    );

    // Intellectual Depth Score (0.0 to 1.0): depth vs light entertainment
    const deepCategories = {
      'science',
      'technology',
      'education',
      'philosophy',
      'geopolitics',
      'history',
      'documentary',
      'economics',
      'research',
    };
    var deepWatches = 0;
    categoryWatchCounts.forEach((cat, count) {
      if (deepCategories.contains(cat.toLowerCase())) deepWatches += count;
    });
    final totalCatWatches = categoryWatchCounts.values.fold(0, (a, b) => a + b);
    final deepRatio = totalCatWatches > 0 ? (deepWatches / totalCatWatches) : 0.5;
    final depthScore = (deepRatio * 0.60 + (avgWatchCompletion * 0.40)).clamp(0.0, 1.0);

    // Focus vs Breadth (0.0 = broad generalist, 1.0 = focused specialist)
    var focusVsBreadth = 0.5;
    if (totalCatWatches > 0 && sortedCats.isNotEmpty) {
      final topCatCount = categoryWatchCounts[sortedCats.first.key] ?? 0;
      focusVsBreadth = (topCatCount / totalCatWatches).clamp(0.0, 1.0);
    } else if (sortedCats.isNotEmpty) {
      final totalCatScore = sortedCats.fold<double>(0.0, (sum, e) => sum + e.value);
      if (totalCatScore > 0) {
        focusVsBreadth = (sortedCats.first.value / totalCatScore).clamp(0.0, 1.0);
      }
    }

    // 4. Inferred Cognitive Archetype
    CognitiveArchetype archetype;
    String archetypeDisplayName;
    String archetypeDescription;

    if (depthScore >= 0.55 && (criticalThinking >= 0.50 || factCheckedWatchCount >= 3 || avgWatchCompletion >= 0.70)) {
      archetype = CognitiveArchetype.analyticalDeepDiver;
      archetypeDisplayName = 'Analytical Deep Diver';
      archetypeDescription =
          'Prefers comprehensive, evidence-rich, in-depth investigations and fact-checked knowledge.';
    } else if (flipCoinCount >= 2 || oppositeWatchesCount >= 2) {
      archetype = CognitiveArchetype.balancedInquirer;
      archetypeDisplayName = 'Balanced Inquirer';
      archetypeDescription =
          'Values diverse perspectives, debate rigor, and truth-seeking across multiple angles.';
    } else if (focusVsBreadth >= 0.60 ||
        (exploredTopicSlugs.length <= 3 && topicAffinities.values.any((v) => v >= 0.8))) {
      archetype = CognitiveArchetype.focusedSpecialist;
      archetypeDisplayName = 'Focused Specialist';
      archetypeDescription =
          'Passionate and deeply focused in core favorite domains with high domain dedication.';
    } else if (openness >= 0.50 || exploredTopicSlugs.length >= 4 || categoryWatchCounts.length >= 4) {
      archetype = CognitiveArchetype.curiousExplorer;
      archetypeDisplayName = 'Curious Explorer';
      archetypeDescription =
          'Enjoys discovering new topics, fresh creators, and wide intellectual horizons.';
    } else {
      archetype = CognitiveArchetype.actionOrientedConsumer;
      archetypeDisplayName = 'Action-Oriented Consumer';
      archetypeDescription =
          'Enjoys fast-paced, high-momentum, trending, and concise impactful content.';
    }

    return UserPsychologyProfile(
      archetype: archetype,
      archetypeDisplayName: archetypeDisplayName,
      archetypeDescription: archetypeDescription,
      opennessToNovelty: openness,
      criticalThinkingIndex: criticalThinking,
      intellectualDepthScore: depthScore,
      focusVsBreadth: focusVsBreadth,
      topLovedCategories: topLovedCategories,
      topLovedTopics: topLovedTopics,
      topLovedChannels: lovedChannels.toList(),
      categoryLoveScores: catLoveScores,
      topicLoveScores: topLoveScores,
    );
  }

  // === Unexplored Horizon / "The Other Side" Engine ===

  /// Get categories the user has NEVER or LEAST explored
  List<String> getUnexploredCategories([List<String> allAvailableCategories = const []]) {
    const defaultCategories = [
      'Science',
      'Technology',
      'Education',
      'Philosophy',
      'News',
      'Documentary',
      'Business & Finance',
      'Health & Fitness',
      'Travel',
      'History',
    ];

    final candidatePool = allAvailableCategories.isNotEmpty
        ? allAvailableCategories
        : defaultCategories;

    final unexplored = <String>[];
    for (final cat in candidatePool) {
      if (cat == 'All' || cat == 'Flip Coin' || cat == 'Subscriptions' || cat == 'Posts') {
        continue;
      }

      final count = categoryWatchCounts[cat] ??
          categoryWatchCounts[cat.toLowerCase()] ??
          0;
      final affinity = categoryAffinities[cat] ??
          categoryAffinities[cat.toLowerCase()] ??
          0.0;

      // User has not explored if <= 1 watch and low affinity
      if (count <= 1 && affinity < 0.25) {
        unexplored.add(cat);
      }
    }

    // Sort by lowest affinity (highest novelty)
    unexplored.sort((a, b) {
      final affA = categoryAffinities[a] ?? 0.0;
      final affB = categoryAffinities[b] ?? 0.0;
      return affA.compareTo(affB);
    });

    return unexplored;
  }

  /// Check if a category belongs to the user's unexplored horizon
  bool isUnexploredCategory(String category) {
    if (category.isEmpty) return false;
    final count = categoryWatchCounts[category] ??
        categoryWatchCounts[category.toLowerCase()] ??
        0;
    final affinity = categoryAffinities[category] ??
        categoryAffinities[category.toLowerCase()] ??
        0.0;
    return count <= 1 && affinity < 0.25;
  }

  /// Get topics the user has never explored or followed
  List<Topic> getUnexploredTopics(List<Topic> allTopics) {
    final candidateTopics = allTopics.where((t) {
      if (!t.isValidTopic || t.videoCount <= 0) return false;
      final slug = t.slug.isNotEmpty ? t.slug : t.id;
      if (followedTopicSlugs.contains(slug)) return false;
      if (exploredTopicSlugs.contains(slug)) return false;
      final count = topicWatchCounts[slug] ?? topicWatchCounts[t.id] ?? 0;
      if (count > 0) return false;
      return true;
    }).toList();

    // Sort by topic quality and popularity
    candidateTopics.sort((a, b) => b.trendingScore.compareTo(a.trendingScore));
    return candidateTopics;
  }

  /// Get topic slugs or names the user has never explored
  List<String> getUnexploredTopicSlugs(List<String> topicSlugs) {
    return topicSlugs.where((s) {
      final clean = s.toLowerCase().replaceFirst('topic:', '').trim();
      return !exploredTopicSlugs.contains(clean) &&
          !followedTopicSlugs.contains(clean) &&
          !topicAffinities.containsKey('topic:$clean');
    }).toList();
  }

  // === Computed Properties ===

  double get echoChamberBreakScore {
    final ratio = oppositeWatchesCount / (recentlyWatchedVideoIds.length + 1);
    final score = (ratio * 70.0) + (flipCoinCount * 3.0);
    return min(100.0, score);
  }

  String get perspectiveBadge {
    final score = echoChamberBreakScore;
    if (score >= 75.0) return 'Truth Seeker';
    if (score >= 40.0) return 'Perspective Explorer';
    return 'Curious Mind';
  }

  String? get dominantCategory {
    if (categoryAffinities.isEmpty) return null;
    return categoryAffinities.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  List<String> get top3Categories {
    final sorted = categoryAffinities.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(3).map((e) => e.key).toList();
  }

  List<String> get top5Topics {
    final sorted = topicAffinities.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(5).map((e) => e.key).toList();
  }

  bool get hasEnoughSignals {
    return recentlyWatchedVideoIds.length >= 10 ||
        categoryAffinities.length >= 2 ||
        topicAffinities.length >= 5;
  }

  bool get isNewUser {
    return recentlyWatchedVideoIds.length < 3 &&
        recentlyLikedVideoIds.isEmpty &&
        subscribedChannelIds.isEmpty &&
        categoryAffinities.isEmpty &&
        topicAffinities.isEmpty &&
        exploredTopicSlugs.isEmpty;
  }

  // === Interest Graph Queries ===

  /// Get related topics for a given topic (from co-occurrence graph)
  List<String> getRelatedTopics(String topic) {
    final related = <String, double>{};
    interestGraph.forEach((pair, weight) {
      final parts = pair.split('|');
      if (parts.length == 2) {
        if (parts[0] == topic) {
          related[parts[1]] = weight;
        } else if (parts[1] == topic) {
          related[parts[0]] = weight;
        }
      }
    });
    final sorted = related.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.map((e) => e.key).toList();
  }

  /// Get combined affinity for a video considering topic interactions
  double getCombinedTopicAffinity(List<String> videoTopics) {
    if (videoTopics.isEmpty) return 0.0;

    var maxAffinity = 0.0;
    for (final topic in videoTopics) {
      final directAffinity = topicAffinities[topic] ?? 0.0;
      if (directAffinity > maxAffinity) {
        maxAffinity = directAffinity;
      }

      // Check graph for interactions with top5Topics
      for (final myTopic in top5Topics) {
        final pair1 = '$topic|$myTopic';
        final pair2 = '$myTopic|$topic';
        final weight = interestGraph[pair1] ?? interestGraph[pair2] ?? 0.0;
        final indirectAffinity = (topicAffinities[myTopic] ?? 0.0) * weight;
        if (indirectAffinity > maxAffinity) {
          maxAffinity = indirectAffinity;
        }
      }
    }

    return min(maxAffinity, 1.0);
  }

  // === Negative Signal Queries ===

  /// Check if a category has been frequently skipped/exited
  bool isCategoryDisliked(String category) {
    final skips = skippedCategoryCounts[category] ?? 0;
    final earlyExits = earlyExitCategoryCounts[category] ?? 0;
    return (skips + earlyExits) > 5;
  }

  /// Get negative signal strength for a video (0.0 = no negative signals, 1.0 = heavy negative signals)
  double getNegativeSignalStrength(
    String videoId,
    String category,
    String channelId,
  ) {
    if (notInterestedVideoIds.contains(videoId) ||
        blockedChannelIds.contains(channelId)) {
      return 1.0;
    }
    if (recentlyDislikedVideoIds.contains(videoId)) {
      return 0.8;
    }

    var strength = 0.0;
    final skips = skippedCategoryCounts[category] ?? 0;
    final earlyExits = earlyExitCategoryCounts[category] ?? 0;

    if (skips > 0 || earlyExits > 0) {
      strength += min((skips * 0.1) + (earlyExits * 0.15), 0.5);
    }

    return min(strength, 1.0);
  }
}

/// Structured user feedback signal with confidence and decay
class UserSignal {
  final String type; // 'like', 'dislike', 'not_interested', 'block_channel'
  final String targetId; // videoId or channelId
  final String? category;
  final List<String> topics;
  final double confidence; // 0.0-1.0 (like=0.95, dislike=0.90, skip=0.3)
  final String source; // 'explicit', 'implicit', 'inferred'
  final DateTime timestamp;
  final double
  decayHalfLifeHours; // how quickly signal fades (168h for explicit)

  UserSignal({
    required this.type,
    required this.targetId,
    required this.confidence,
    required this.source,
    required this.timestamp,
    required this.decayHalfLifeHours,
    this.category,
    this.topics = const [],
  });

  Map<String, dynamic> toMap() => {
    'type': type,
    'targetId': targetId,
    'category': category,
    'topics': topics,
    'confidence': confidence,
    'source': source,
    'timestamp': timestamp.toIso8601String(),
    'decayHalfLifeHours': decayHalfLifeHours,
  };

  factory UserSignal.fromMap(Map<String, dynamic> map) {
    return UserSignal(
      type: map['type'] as String,
      targetId: map['targetId'] as String,
      category: map['category'] as String?,
      topics: List<String>.from(map['topics'] ?? []),
      confidence: (map['confidence'] as num).toDouble(),
      source: map['source'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      decayHalfLifeHours: (map['decayHalfLifeHours'] as num).toDouble(),
    );
  }

  /// Get current effective confidence after time decay
  double get effectiveConfidence {
    final hoursElapsed = DateTime.now().difference(timestamp).inHours;
    return confidence * pow(0.5, hoursElapsed / decayHalfLifeHours);
  }
}
