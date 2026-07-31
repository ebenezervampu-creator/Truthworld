import 'dart:math';

/// The user's computed interest profile — their personalization DNA.
/// Loaded once on auth, refreshed every 15 minutes, consumed by all surfaces.
///
/// Incorporates all 6 improvements from architecture review:
/// 1. Long-term interests (from users/{uid}.interests)
/// 2. Session interests (from SessionInterestTracker)
/// 3. Interest graph (topic co-occurrence for interaction terms)
/// 4. Negative signals (skips, early exits, blocks)
/// 5. Creator exposure tracking
/// 6. Satisfaction signals (session continuation)
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

  // === Watch History ===
  final Set<String> recentlyWatchedVideoIds; // last 200
  final Map<String, double> watchProgress; // videoId → 0.0-1.0
  final Map<String, int> categoryWatchCounts; // last 30 days
  final Map<String, int> topicWatchCounts; // last 30 days

  // === Engagement Signals ===
  final Set<String> recentlyLikedVideoIds; // last 100
  final Set<String> recentlyDislikedVideoIds; // last 50

  // === Negative Signals ===
  final Set<String> notInterestedVideoIds;
  final Set<String> blockedChannelIds;
  final Map<String, int> skippedCategoryCounts; // categories frequently skipped
  final Map<String, int> earlyExitCategoryCounts; // categories exited < 5s

  // === Search History ===
  final List<String> recentSearchQueries; // last 20

  // === Creator Exposure Tracking ===
  final Map<String, int> channelExposureCounts; // channelId → times shown today

  // === New Fields ===
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
    this.recentlyLikedVideoIds = const {},
    this.recentlyDislikedVideoIds = const {},
    this.notInterestedVideoIds = const {},
    this.blockedChannelIds = const {},
    this.skippedCategoryCounts = const {},
    this.earlyExitCategoryCounts = const {},
    this.recentSearchQueries = const [],
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
      'recentlyLikedVideoIds': recentlyLikedVideoIds.toList(),
      'recentlyDislikedVideoIds': recentlyDislikedVideoIds.toList(),
      'notInterestedVideoIds': notInterestedVideoIds.toList(),
      'blockedChannelIds': blockedChannelIds.toList(),
      'skippedCategoryCounts': skippedCategoryCounts,
      'earlyExitCategoryCounts': earlyExitCategoryCounts,
      'recentSearchQueries': recentSearchQueries,
      'channelExposureCounts': channelExposureCounts,
      'recentSignals': recentSignals.map((s) => s.toMap()).toList(),
      'dislikedCategories': dislikedCategories.toList(),
      'channelAffinities': channelAffinities,
      'flipCoinCount': flipCoinCount,
      'oppositeWatchesCount': oppositeWatchesCount,
    };
  }

  factory UserInterestProfile.fromMap(Map<String, dynamic> data) {
    return UserInterestProfile.fromFirestore(data);
  }

  factory UserInterestProfile.fromFirestore(Map<String, dynamic> data) {
    return UserInterestProfile(
      userId: data['userId']?.toString() ?? '',
      categoryAffinities: Map<String, double>.from(
        data['categoryAffinities'] ?? {},
      ),
      topicAffinities: Map<String, double>.from(data['topicAffinities'] ?? {}),
      interestGraph: Map<String, double>.from(data['interestGraph'] ?? {}),
      followedTopicSlugs: Set<String>.from(data['followedTopicSlugs'] ?? []),
      subscribedChannelIds: Set<String>.from(
        data['subscribedChannelIds'] ?? [],
      ),
      recentlyWatchedVideoIds: Set<String>.from(
        data['recentlyWatchedVideoIds'] ?? [],
      ),
      watchProgress: Map<String, double>.from(data['watchProgress'] ?? {}),
      categoryWatchCounts: Map<String, int>.from(
        data['categoryWatchCounts'] ?? {},
      ),
      topicWatchCounts: Map<String, int>.from(data['topicWatchCounts'] ?? {}),
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
        data['skippedCategoryCounts'] ?? {},
      ),
      earlyExitCategoryCounts: Map<String, int>.from(
        data['earlyExitCategoryCounts'] ?? {},
      ),
      recentSearchQueries: List<String>.from(data['recentSearchQueries'] ?? []),
      channelExposureCounts: Map<String, int>.from(
        data['channelExposureCounts'] ?? {},
      ),
      recentSignals:
          (data['recentSignals'] as List<dynamic>?)
              ?.map((e) => UserSignal.fromMap(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
      dislikedCategories: Set<String>.from(data['dislikedCategories'] ?? []),
      channelAffinities: Map<String, double>.from(
        data['channelAffinities'] ?? {},
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
    Set<String>? recentlyLikedVideoIds,
    Set<String>? recentlyDislikedVideoIds,
    Set<String>? notInterestedVideoIds,
    Set<String>? blockedChannelIds,
    Map<String, int>? skippedCategoryCounts,
    Map<String, int>? earlyExitCategoryCounts,
    List<String>? recentSearchQueries,
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
      channelExposureCounts:
          channelExposureCounts ?? this.channelExposureCounts,
      recentSignals: recentSignals ?? this.recentSignals,
      dislikedCategories: dislikedCategories ?? this.dislikedCategories,
      channelAffinities: channelAffinities ?? this.channelAffinities,
      flipCoinCount: flipCoinCount ?? this.flipCoinCount,
      oppositeWatchesCount: oppositeWatchesCount ?? this.oppositeWatchesCount,
    );
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
        subscribedChannelIds.isEmpty;
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

    double maxAffinity = 0.0;
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

    double strength = 0.0;
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
