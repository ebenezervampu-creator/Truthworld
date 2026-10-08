import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/data/models/channel_wallet_models.dart';

/// Authoritative catalog of Truthworld Channel Wallet pricing tiers, packs, and calculation engines.
class ChannelWalletPricing {
  static const List<StorageTopupPack> storagePacks = [
    StorageTopupPack(
      id: 'storage_25gb',
      title: '+25 GB Storage',
      gigabytes: 25,
      priceUSD: 2.50,
    ),
    StorageTopupPack(
      id: 'storage_50gb',
      title: '+50 GB Storage',
      gigabytes: 50,
      priceUSD: 5.00,
      badge: 'Popular',
    ),
    StorageTopupPack(
      id: 'storage_100gb',
      title: '+100 GB Storage',
      gigabytes: 100,
      priceUSD: 10.00,
      badge: 'Best Value',
    ),
    StorageTopupPack(
      id: 'storage_500gb',
      title: '+500 GB Storage',
      gigabytes: 500,
      priceUSD: 40.00,
    ),
  ];

  static const List<BandwidthTopupPack> bandwidthPacks = [
    BandwidthTopupPack(
      id: 'bandwidth_100gb',
      title: '+100 GB Streaming Bandwidth',
      gigabytes: 100,
      priceUSD: 3.00,
    ),
    BandwidthTopupPack(
      id: 'bandwidth_250gb',
      title: '+250 GB Streaming Bandwidth',
      gigabytes: 250,
      priceUSD: 7.00,
      badge: 'Popular',
    ),
    BandwidthTopupPack(
      id: 'bandwidth_500gb',
      title: '+500 GB Streaming Bandwidth',
      gigabytes: 500,
      priceUSD: 13.00,
    ),
    BandwidthTopupPack(
      id: 'bandwidth_1tb',
      title: '+1 TB (1000 GB) Bandwidth',
      gigabytes: 1000,
      priceUSD: 24.00,
      badge: 'Pro Choice',
    ),
  ];

  /// Transparent flat pricing tiers for Dubbing based on video duration:
  /// Raw API provider pass-through at-cost with 0% platform profit.
  /// - Tier 1 (Shorts / Clips): <= 60s (up to 1 min) -> $0.10 per language
  /// - Tier 2 (Mini Video): 61s – 300s (1 to 5 mins) -> $0.25 per language
  /// - Tier 3 (Standard Video): 301s – 600s (5 to 10 mins) -> $0.50 per language
  /// - Tier 4 (Extended Video): 601s – 1800s (10 to 30 mins) -> $1.25 per language
  /// - Tier 5 (Long-Form Video): 1801s – 3600s (30 to 60 mins) -> $2.50 per language
  /// - Tier 6 (Feature-Length): > 3600s -> $2.50 + $1.25 / extra 30 mins
  static const List<DubbingDurationTier> dubbingDurationTiers = [
    DubbingDurationTier(
      id: 'tier_shorts',
      name: 'Shorts & Clips',
      durationLabel: '≤ 60s (Up to 1 min)',
      maxSeconds: 60,
      standardFlatRatePerLanguage: 0.10,
      customFlatRatePerLanguage: 0.10,
    ),
    DubbingDurationTier(
      id: 'tier_mini',
      name: 'Mini Video',
      durationLabel: '1 to 5 mins (61s – 300s)',
      maxSeconds: 300,
      standardFlatRatePerLanguage: 0.25,
      customFlatRatePerLanguage: 0.25,
    ),
    DubbingDurationTier(
      id: 'tier_standard',
      name: 'Standard Video',
      durationLabel: '5 to 10 mins (301s – 600s)',
      maxSeconds: 600,
      standardFlatRatePerLanguage: 0.50,
      customFlatRatePerLanguage: 0.50,
    ),
    DubbingDurationTier(
      id: 'tier_extended',
      name: 'Extended Video',
      durationLabel: '10 to 30 mins (601s – 1800s)',
      maxSeconds: 1800,
      standardFlatRatePerLanguage: 1.25,
      customFlatRatePerLanguage: 1.25,
    ),
    DubbingDurationTier(
      id: 'tier_longform',
      name: 'Long-Form Video',
      durationLabel: '30 to 60 mins (1801s – 3600s)',
      maxSeconds: 3600,
      standardFlatRatePerLanguage: 2.50,
      customFlatRatePerLanguage: 2.50,
    ),
  ];

  /// Get the flat dubbing rate per language based on video duration and channel type.
  /// Billed at raw provider pass-through cost with 0% platform profit.
  static double getFlatDubbingPricePerLanguage({
    required int durationSeconds,
    ChannelType channelType = ChannelType.standard,
  }) {
    if (durationSeconds <= 0) {
      return customDubbingRatePerLanguage;
    }
    if (durationSeconds <= 60) {
      return 0.10;
    }
    if (durationSeconds <= 300) {
      return 0.25;
    }
    if (durationSeconds <= 600) {
      return 0.50;
    }
    if (durationSeconds <= 1800) {
      return 1.25;
    }
    if (durationSeconds <= 3600) {
      return 2.50;
    }
    // Beyond 60 mins: base 60 min rate ($2.50) + $1.25 per additional 30 min block (at-cost pass-through)
    final extraSeconds = durationSeconds - 3600;
    final extraBlocks = (extraSeconds / 1800).ceil();
    const base = 2.50;
    const perBlock = 1.25;
    return double.parse((base + (extraBlocks * perBlock)).toStringAsFixed(2));
  }

  /// Get the duration tier for a given video duration in seconds.
  static DubbingDurationTier getDubbingDurationTier(int durationSeconds) {
    if (durationSeconds <= 60) return dubbingDurationTiers[0];
    if (durationSeconds <= 300) return dubbingDurationTiers[1];
    if (durationSeconds <= 600) return dubbingDurationTiers[2];
    if (durationSeconds <= 1800) return dubbingDurationTiers[3];
    return dubbingDurationTiers[4];
  }

  /// Dubbing rate per language at raw provider pass-through cost ($0.25/lang, min $0.75, cap $5.00, 0% platform profit)
  static const double standardDubbingRatePerLanguage = 0.25;
  static const double standardDubbingMinCost = 0.75;
  static const double standardDubbingCapCost = 5.00;

  /// Dubbing rate per language for custom channels ($0.25/lang, min $0.75, cap $5.00, 0% platform profit)
  static const double customDubbingRatePerLanguage = 0.25;
  static const double customDubbingMinCost = 0.75;
  static const double customDubbingCapCost = 5.00;

  /// Get dubbing rate per language based on channel type
  static double getDubbingRatePerLanguage(ChannelType type) {
    return type == ChannelType.custom
        ? customDubbingRatePerLanguage
        : standardDubbingRatePerLanguage;
  }

  /// Get minimum dubbing job cost based on channel type
  static double getDubbingMinCost(ChannelType type) {
    return type == ChannelType.custom
        ? customDubbingMinCost
        : standardDubbingMinCost;
  }

  /// Get maximum dubbing cost cap based on channel type
  static double getDubbingCapCost(ChannelType type) {
    return type == ChannelType.custom
        ? customDubbingCapCost
        : standardDubbingCapCost;
  }

  /// Calculates dubbing generation flat cost based on video duration, language count, and channel type.
  /// When [durationSeconds] > 0, calculates flat price by duration tier.
  /// When [durationSeconds] is 0 or omitted, falls back to standard base rate per language with min clamp.
  static double calculateDubbingCost({
    required int languageCount,
    int durationSeconds = 0,
    ChannelType channelType = ChannelType.standard,
  }) {
    if (languageCount <= 0) return 0.0;
    if (durationSeconds > 0) {
      final rate = getFlatDubbingPricePerLanguage(
        durationSeconds: durationSeconds,
        channelType: channelType,
      );
      return double.parse((languageCount * rate).toStringAsFixed(2));
    }
    final rate = getDubbingRatePerLanguage(channelType);
    final minCost = getDubbingMinCost(channelType);
    final capCost = getDubbingCapCost(channelType);
    return double.parse(
      (languageCount * rate).clamp(minCost, capCost).toStringAsFixed(2),
    );
  }

  /// Transparent flat pricing tiers for Subtitles based on video duration:
  /// Note: Truthworld enforces a 2-minute (120s) minimum video upload length.
  /// Billed at raw provider pass-through cost with 0% platform profit.
  /// - Tier 1 (Platform Minimum: 2 to 5 mins): 120s – 300s -> $0.025 per language
  /// - Tier 2 (Standard Video): 301s – 600s (5 to 10 mins) -> $0.05 per language
  /// - Tier 3 (Extended Video): 601s – 1800s (10 to 30 mins) -> $0.10 per language
  /// - Tier 4 (Long-Form Video): 1801s – 3600s (30 to 60 mins) -> $0.20 per language
  /// - Tier 5 (Feature-Length): > 3600s -> $0.20 + $0.075 / extra 30 mins
  static const List<SubtitleDurationTier> subtitleDurationTiers = [
    SubtitleDurationTier(
      id: 'sub_tier_mini',
      name: 'Mini Video (Platform Minimum)',
      durationLabel: '2 to 5 mins (120s – 300s)',
      minSeconds: 120,
      maxSeconds: 300,
      standardFlatRatePerLanguage: 0.025,
      customFlatRatePerLanguage: 0.025,
    ),
    SubtitleDurationTier(
      id: 'sub_tier_standard',
      name: 'Standard Video',
      durationLabel: '5 to 10 mins (301s – 600s)',
      minSeconds: 301,
      maxSeconds: 600,
      standardFlatRatePerLanguage: 0.05,
      customFlatRatePerLanguage: 0.05,
    ),
    SubtitleDurationTier(
      id: 'sub_tier_extended',
      name: 'Extended Video',
      durationLabel: '10 to 30 mins (601s – 1800s)',
      minSeconds: 601,
      maxSeconds: 1800,
      standardFlatRatePerLanguage: 0.10,
      customFlatRatePerLanguage: 0.10,
    ),
    SubtitleDurationTier(
      id: 'sub_tier_longform',
      name: 'Long-Form Video',
      durationLabel: '30 to 60 mins (1801s – 3600s)',
      minSeconds: 1801,
      maxSeconds: 3600,
      standardFlatRatePerLanguage: 0.20,
      customFlatRatePerLanguage: 0.20,
    ),
  ];

  /// Get the duration tier for subtitles for a given video duration in seconds.
  static SubtitleDurationTier getSubtitleDurationTier(int durationSeconds) {
    if (durationSeconds <= 300) return subtitleDurationTiers[0];
    if (durationSeconds <= 600) return subtitleDurationTiers[1];
    if (durationSeconds <= 1800) return subtitleDurationTiers[2];
    return subtitleDurationTiers[3];
  }

  /// Get the flat subtitle rate per language based on video duration and channel type.
  /// Billed at raw provider pass-through cost with 0% platform profit.
  static double getFlatSubtitlePricePerLanguage({
    required int durationSeconds,
    ChannelType channelType = ChannelType.standard,
  }) {
    if (durationSeconds <= 300) {
      return 0.025;
    }
    if (durationSeconds <= 600) {
      return 0.05;
    }
    if (durationSeconds <= 1800) {
      return 0.10;
    }
    if (durationSeconds <= 3600) {
      return 0.20;
    }
    // Beyond 60 mins: base 60 min rate ($0.20) + $0.075 per additional 30 min block (at-cost pass-through)
    final extraSeconds = durationSeconds - 3600;
    final extraBlocks = (extraSeconds / 1800).ceil();
    const base = 0.20;
    const perBlock = 0.075;
    return double.parse((base + (extraBlocks * perBlock)).toStringAsFixed(3));
  }

  /// Subtitle rate per language defaults (0% platform profit pass-through at-cost)
  static const double standardSubtitleRatePerLanguage = 0.05;
  static const double customSubtitleRatePerLanguage = 0.05;
  static const double standardSubtitleMinCost = 0.05;
  static const double customSubtitleMinCost = 0.05;
  static const double standardSubtitleCapCost = 2.50;
  static const double customSubtitleCapCost = 2.50;

  /// Calculates subtitle generation flat cost based on video duration, language count, and channel type.
  static double calculateSubtitleCost({
    required int languageCount,
    int durationSeconds = 0,
    ChannelType channelType = ChannelType.standard,
  }) {
    if (languageCount <= 0) return 0.0;
    final isCustom = channelType == ChannelType.custom;
    final minCost = isCustom ? customSubtitleMinCost : standardSubtitleMinCost;

    if (durationSeconds > 0) {
      final rate = getFlatSubtitlePricePerLanguage(
        durationSeconds: durationSeconds,
        channelType: channelType,
      );
      final rawCost = languageCount * rate;
      return double.parse(math.max(minCost, rawCost).toStringAsFixed(2));
    }

    final rate =
        isCustom ? customSubtitleRatePerLanguage : standardSubtitleRatePerLanguage;
    final capCost = isCustom ? customSubtitleCapCost : standardSubtitleCapCost;
    return double.parse(
      (languageCount * rate).clamp(minCost, capCost).toStringAsFixed(2),
    );
  }

  /// Transparent flat pricing tiers for AI Fact-Checking based on video duration:
  /// Fact-checking is 100% FREE for creators across all durations and channels.
  static const List<FactCheckDurationTier> factCheckDurationTiers = [
    FactCheckDurationTier(
      id: 'fc_tier_mini',
      name: 'Quick Analysis',
      durationLabel: '≤ 10 mins (Up to 600s)',
      minSeconds: 0,
      maxSeconds: 600,
      standardFlatRate: 0.0,
      customFlatRate: 0.0,
      shortStandardRate: 0.0,
      shortCustomRate: 0.0,
      fullGroundStandardRate: 0.0,
      fullGroundCustomRate: 0.0,
    ),
    FactCheckDurationTier(
      id: 'fc_tier_standard',
      name: 'Standard Video',
      durationLabel: '10 to 30 mins (601s – 1800s)',
      minSeconds: 601,
      maxSeconds: 1800,
      standardFlatRate: 0.0,
      customFlatRate: 0.0,
      shortStandardRate: 0.0,
      shortCustomRate: 0.0,
      fullGroundStandardRate: 0.0,
      fullGroundCustomRate: 0.0,
    ),
    FactCheckDurationTier(
      id: 'fc_tier_extended',
      name: 'Extended Deep-Dive',
      durationLabel: '30 to 60 mins (1801s – 3600s)',
      minSeconds: 1801,
      maxSeconds: 3600,
      standardFlatRate: 0.0,
      customFlatRate: 0.0,
      shortStandardRate: 0.0,
      shortCustomRate: 0.0,
      fullGroundStandardRate: 0.0,
      fullGroundCustomRate: 0.0,
    ),
    FactCheckDurationTier(
      id: 'fc_tier_feature',
      name: 'Feature-Length',
      durationLabel: '60+ mins (> 3600s)',
      minSeconds: 3601,
      maxSeconds: 1000000,
      standardFlatRate: 0.0,
      customFlatRate: 0.0,
      shortStandardRate: 0.0,
      shortCustomRate: 0.0,
      fullGroundStandardRate: 0.0,
      fullGroundCustomRate: 0.0,
    ),
  ];

  /// AI Fact-Checking is 100% FREE for creators across all channels
  static const double standardFactCheckBaseCost = 0.0;
  static const double customFactCheckBaseCost = 0.0;

  /// Pre-defined Fact-Checking Depth Plans:
  /// Single unified tier: All claims verified against full ground truth, 100% free for creators.
  static const List<FactCheckDepthPlan> factCheckDepthPlans = [
    FactCheckDepthPlan(
      id: 'full_ground',
      title: 'Complete Ground-Truth Fact-Checking',
      shortTitle: 'All Claims Verified',
      tagline: 'All Claims Fact-Checked & Grounded',
      badgeLabel: '100% VERIFIED',
      description:
          'TruthWorld’s complete epistemic verification: every empirical claim is deeply verified against primary authoritative sources, citations, and counter-evidence audit.',
      features: [
        'Every single empirical claim verified against ground truth',
        'Live Google Search & primary source forensic cross-referencing',
        'Permanent Ground-Truth Trust Badge on Video & Thumbnail',
        'Audience Viewer Notes & context breakdown',
        '+20% Maximum Discovery Advantage Boost',
        '100% Free for Creators (Sponsored by TruthWorld Platform)',
      ],
      icon: Icons.verified_user_outlined,
      priceMultiplier: 0.0,
    ),
  ];

  /// Get FactCheckDepthPlan by id. Returns the unified full ground-truth plan.
  static FactCheckDepthPlan getFactCheckDepthPlan(String id) {
    return factCheckDepthPlans.first;
  }

  /// Pre-defined Channel Fact-Checking Monthly Plans & Add-ons
  static const List<ChannelFactCheckAddonTier> channelFactCheckPlans = [
    ChannelFactCheckAddonTier(
      id: 'fc_plan_free_standard',
      title: 'Platform Truth Standard',
      priceUSD: 0.0,
      billingPeriod: '100% Free',
      description: 'Comprehensive epistemic verification for every video on TruthWorld at zero cost to creators.',
      perks: [
        'Complete Ground-Truth Fact-Checking on All Uploads (100% Free)',
        'Full Epistemic Claim Extraction & Authoritative Citations',
        'Truth Score Badge on Thumbnail & Video Player',
        '+20% Maximum Discovery Advantage Boost',
        'Sponsored 100% by the TruthWorld Platform',
      ],
    ),
  ];

  /// Get the duration tier for fact-checking for a given video duration in seconds.
  static FactCheckDurationTier getFactCheckDurationTier(int durationSeconds) {
    if (durationSeconds <= 600) return factCheckDurationTiers[0];
    if (durationSeconds <= 1800) return factCheckDurationTiers[1];
    if (durationSeconds <= 3600) return factCheckDurationTiers[2];
    return factCheckDurationTiers[3];
  }

  /// Get the flat fact-checking rate. 100% Free for all creators.
  static double getFlatFactCheckPrice({
    int durationSeconds = 0,
    ChannelType channelType = ChannelType.standard,
    String tierType = 'full_ground',
  }) {
    return 0.0;
  }

  /// Calculates fact-checking cost. 100% Free for all creators.
  static double calculateFactCheckCost({
    int durationSeconds = 0,
    ChannelType channelType = ChannelType.standard,
    String tierType = 'full_ground',
  }) {
    return 0.0;
  }

  /// Computes AI Feature generation cost based on selected capabilities, target languages, video duration, and channel type
  static double calculateAIFeatureCost({
    required Set<String> selectedFeatures,
    required List<String> targetLanguages,
    ChannelType channelType = ChannelType.standard,
    int durationSeconds = 0,
    String factCheckTier = 'standard',
  }) {
    if (selectedFeatures.isEmpty) return 0.0;

    var cost = 0.0;
    final langCount = targetLanguages.isEmpty ? 1 : targetLanguages.length;

    if (selectedFeatures.contains('subtitles')) {
      cost += calculateSubtitleCost(
        languageCount: langCount,
        durationSeconds: durationSeconds,
        channelType: channelType,
      );
    }

    if (selectedFeatures.contains('dubbing')) {
      cost += calculateDubbingCost(
        languageCount: langCount,
        durationSeconds: durationSeconds,
        channelType: channelType,
      );
    }

    if (selectedFeatures.contains('factcheck')) {
      // Epistemic Fact Check & Truth Score Report for Channels
      cost += calculateFactCheckCost(
        durationSeconds: durationSeconds,
        channelType: channelType,
        tierType: factCheckTier,
      );
    }

    // AI Video Summary is 100% Free (automatically generated via Community Guidelines verification)
    if (selectedFeatures.contains('chapters')) {
      // Timestamped Auto-Chapters
      cost += 0.50;
    }

    return double.parse(cost.toStringAsFixed(2));
  }

  /// Calculates the creator's live spendable balance combining funded wallet balance, rollover credits, and channel revenues
}
