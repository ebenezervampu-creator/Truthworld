import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/algorithm/scored_video.dart';

/// Versioned algorithm weight configuration.
/// Supports A/B testing via version-based rollout:
///   5% users → v2 weights
///   95% users → v1 weights
///
/// Currently uses local defaults. When firebase_remote_config is added,
/// weights will be fetched remotely with 12-hour cache.
class AlgorithmRemoteConfig extends GetxService {
  static const String _currentVersion = 'v1';

  /// Default weight profiles (compile-time fallback)
  static const Map<String, Map<String, Map<String, double>>> _versionedWeights =
      {
        'v1': {
          'homeFeedAll': {
            'topicAffinity': 0.20,
            'channelAffinity': 0.12,
            'engagement': 0.05,
            'freshness': 0.13,
            'trending': 0.08,
            'watchCompletion': 0.05,
            'sessionBoost': 0.15,
            'penalty': 0.07,
            'knowledgeQuality': 0.10,
          },
          'homeFeedCategory': {
            'topicAffinity': 0.08,
            'channelAffinity': 0.08,
            'engagement': 0.22,
            'freshness': 0.18,
            'trending': 0.13,
            'watchCompletion': 0.05,
            'sessionBoost': 0.10,
            'penalty': 0.08,
            'knowledgeQuality': 0.00,
          },
          'videoRelated': {
            'topicAffinity': 0.25,
            'channelAffinity': 0.18,
            'engagement': 0.05,
            'freshness': 0.08,
            'trending': 0.04,
            'watchCompletion': 0.05,
            'sessionBoost': 0.15,
            'penalty': 0.07,
            'knowledgeQuality': 0.08,
          },
          'autoplayNext': {
            'topicAffinity': 0.20,
            'channelAffinity': 0.22,
            'engagement': 0.12,
            'freshness': 0.08,
            'trending': 0.04,
            'watchCompletion': 0.05,
            'sessionBoost': 0.17,
            'penalty': 0.07,
            'knowledgeQuality': 0.00,
          },
          'searchResults': {
            'topicAffinity': 0.07,
            'channelAffinity': 0.03,
            'engagement': 0.02,
            'freshness': 0.10,
            'trending': 0.07,
            'watchCompletion': 0.07,
            'sessionBoost': 0.05,
            'penalty': 0.04,
            'knowledgeQuality': 0.12,
          },
          'subscriptionFeed': {
            'topicAffinity': 0.08,
            'channelAffinity': 0.25,
            'engagement': 0.13,
            'freshness': 0.18,
            'trending': 0.08,
            'watchCompletion': 0.05,
            'sessionBoost': 0.10,
            'penalty': 0.05,
            'knowledgeQuality': 0.00,
          },
          'trending': {
            'topicAffinity': 0.04,
            'channelAffinity': 0.04,
            'engagement': 0.18,
            'freshness': 0.13,
            'trending': 0.32,
            'watchCompletion': 0.05,
            'sessionBoost': 0.08,
            'penalty': 0.08,
            'knowledgeQuality': 0.00,
          },
          'discoverChannels': {
            'topicAffinity': 0.28,
            'channelAffinity': 0.00,
            'engagement': 0.13,
            'freshness': 0.08,
            'trending': 0.13,
            'watchCompletion': 0.08,
            'sessionBoost': 0.10,
            'penalty': 0.10,
            'knowledgeQuality': 0.00,
          },
          'exploreTopics': {
            'topicAffinity': 0.32,
            'channelAffinity': 0.04,
            'engagement': 0.13,
            'freshness': 0.08,
            'trending': 0.13,
            'watchCompletion': 0.04,
            'sessionBoost': 0.10,
            'penalty': 0.08,
            'knowledgeQuality': 0.00,
          },
          'shortsFeed': {
            'topicAffinity': 0.17,
            'channelAffinity': 0.12,
            'engagement': 0.18,
            'freshness': 0.13,
            'trending': 0.13,
            'watchCompletion': 0.00,
            'sessionBoost': 0.12,
            'penalty': 0.07,
            'knowledgeQuality': 0.00,
          },
          'endScreen': {
            'topicAffinity': 0.20,
            'channelAffinity': 0.17,
            'engagement': 0.13,
            'freshness': 0.08,
            'trending': 0.04,
            'watchCompletion': 0.04,
            'sessionBoost': 0.12,
            'penalty': 0.14,
            'knowledgeQuality': 0.00,
          },
          'unexplored': {
            'topicAffinity': 0.12,
            'channelAffinity': 0.05,
            'engagement': 0.14,
            'freshness': 0.14,
            'trending': 0.08,
            'watchCompletion': 0.07,
            'sessionBoost': 0.10,
            'penalty': 0.05,
            'knowledgeQuality': 0.15,
          },
        },
      };

  String _activeVersion = _currentVersion;

  String get activeVersion => _activeVersion;

  /// Get weight profile for a surface, using the active algorithm version
  Map<String, double> getWeightProfile(RecommendationSurface surface) {
    final versionWeights =
        _versionedWeights[_activeVersion] ??
        _versionedWeights[_currentVersion]!;
    return versionWeights[surface.name] ?? versionWeights['homeFeedAll']!;
  }

  /// Set active version (for future Remote Config integration)
  void setVersion(String version) {
    if (_versionedWeights.containsKey(version)) {
      _activeVersion = version;
      debugPrint(
        '[AlgorithmRemoteConfig] Switched to algorithm version: $version',
      );
    }
  }

  String _homeFeedEndpoint = const String.fromEnvironment(
    'TRUTHWORLD_HOME_FEED_ENDPOINT',
    defaultValue: 'https://asia-south1-truthworld-1.cloudfunctions.net/getHomeFeed',
  );
  String get homeFeedEndpoint => _homeFeedEndpoint;

  /// Update home feed server endpoint dynamically
  void setHomeFeedEndpoint(String endpoint) {
    _homeFeedEndpoint = endpoint.trim();
  }
}
