/// Controls feed diversity to prevent content monotony and enforce creator exposure limits.
class DiversityConfig {
  final int maxConsecutiveSameChannel;
  final int maxConsecutiveSameTopic;
  final int maxConsecutiveSameCategory;
  final double
  maxCreatorExposurePercent; // Max % of feed from one creator (e.g. 0.18 = 18%)
  final double maxSingleTopicShare;
  final double explorationRate; // % of feed reserved for discovery (5-10%)
  final double smallCreatorBoostFactor; // Boost for small high-quality creators

  const DiversityConfig({
    this.maxConsecutiveSameChannel = 2,
    this.maxConsecutiveSameTopic = 3,
    this.maxConsecutiveSameCategory = 4,
    this.maxCreatorExposurePercent = 0.18,
    this.maxSingleTopicShare = 0.30,
    this.explorationRate = 0.08,
    this.smallCreatorBoostFactor = 1.3,
  });

  // Alias for compatibility
  double get maxSingleChannelShare => maxCreatorExposurePercent;

  // Surface-specific presets:
  static const homeFeed = DiversityConfig(
    maxConsecutiveSameChannel: 2,
    maxConsecutiveSameTopic: 3,
    maxConsecutiveSameCategory: 4,
    maxCreatorExposurePercent: 0.18, // Creator exposure budget: max 18%
    maxSingleTopicShare: 0.30,
    explorationRate: 0.08,
    smallCreatorBoostFactor: 1.3,
  );

  static const videoRelated = DiversityConfig(
    maxConsecutiveSameChannel: 3,
    maxConsecutiveSameTopic: 4,
    maxConsecutiveSameCategory: 5,
    maxCreatorExposurePercent: 0.25,
    maxSingleTopicShare: 0.40,
    explorationRate: 0.05,
    smallCreatorBoostFactor: 1.2,
  );

  static const autoplayNext = DiversityConfig(
    maxConsecutiveSameChannel: 2,
    maxConsecutiveSameTopic: 3,
    maxConsecutiveSameCategory: 4,
    maxCreatorExposurePercent: 0.20,
    maxSingleTopicShare: 0.35,
    explorationRate: 0.05,
    smallCreatorBoostFactor: 1.1,
  );

  static const search = DiversityConfig(
    maxConsecutiveSameChannel: 3,
    maxConsecutiveSameTopic: 5,
    maxConsecutiveSameCategory: 6,
    maxCreatorExposurePercent: 0.30,
    maxSingleTopicShare: 0.50,
    explorationRate: 0.02, // Search is intent-driven
    smallCreatorBoostFactor: 1.0,
  );

  static const subscriptionFeed = DiversityConfig(
    maxConsecutiveSameChannel: 3,
    maxConsecutiveSameTopic: 4,
    maxConsecutiveSameCategory: 5,
    maxCreatorExposurePercent: 0.35,
    maxSingleTopicShare: 0.50,
    explorationRate: 0.0, // Subscriptions are explicit
    smallCreatorBoostFactor: 1.0,
  );

  static const trending = DiversityConfig(
    maxConsecutiveSameChannel: 2,
    maxConsecutiveSameTopic: 3,
    maxConsecutiveSameCategory: 4,
    maxCreatorExposurePercent: 0.20,
    maxSingleTopicShare: 0.35,
    explorationRate: 0.10,
    smallCreatorBoostFactor: 1.4,
  );

  static const shorts = DiversityConfig(
    maxConsecutiveSameChannel: 1,
    maxConsecutiveSameTopic: 2,
    maxConsecutiveSameCategory: 3,
    maxCreatorExposurePercent: 0.15,
    maxSingleTopicShare: 0.25,
    explorationRate: 0.12,
    smallCreatorBoostFactor: 1.5,
  );

  static const endScreen = DiversityConfig(
    maxConsecutiveSameChannel: 2,
    maxConsecutiveSameTopic: 3,
    maxConsecutiveSameCategory: 4,
    maxCreatorExposurePercent: 0.25,
    maxSingleTopicShare: 0.40,
    explorationRate: 0.05,
    smallCreatorBoostFactor: 1.2,
  );
}
