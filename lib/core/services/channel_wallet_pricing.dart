import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:truthworld/core/constants/ai_languages.dart';
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

  /// Transparent proportional per-minute pricing rate cards (like ElevenLabs model):
  /// - Audio Starter: $0.10 / min ($1.00 for 10-minute video)
  /// - Audio Pro: $0.20 / min ($2.00 for 10-minute video)
  /// - Audio Ultra: $0.30 / min ($3.00 for 10-minute video)
  /// - Video Pro: $0.40 / min ($4.00 for 10-minute video)
  /// - Video Ultra (Hollywood Cinema Grade): $0.50 / min ($5.00 for 10-minute video)
  /// Transparent proportional per-minute pricing rate card:
  /// - Audio Starter: $0.10 / min ($1.00 for 10-minute video)
  /// - Audio Pro: $0.20 / min ($2.00 for 10-minute video)
  /// - Audio Track / Ultra (Studio Voice Cloning & 100% BGM Preservation): $0.30 / min ($3.00 for 10-minute video)
  /// - Video Pro: $0.40 / min ($4.00 for 10-minute video)
  /// - Video Ultra (Cinema Grade): $0.50 / min ($5.00 for 10-minute video)
  static const double perMinuteAudioTrackRate = 0.30;

  // Tier-specific rates ($0.30/min baseline for ElevenLabs v4 Studio Dubbing)
  static const double perMinuteAudioStarterRate = 0.30;
  static const double perMinuteAudioProRate = 0.30;
  static const double perMinuteAudioUltraRate = 0.30;
  static const double perMinuteVideoProRate = 0.40;
  static const double perMinuteVideoUltraRate = 0.50;

  // Legacy aliases for backward compatibility ($0.30/min baseline)
  static const double perMinuteStandardDubbingRate = 0.30;
  static const double perMinuteVoiceCloneRate = 0.30;
  static const double perMinuteLipSyncRate = 0.30;

  /// Production-Ready Dubbing Tiers Catalog
  static const List<DubbingProductionTier> productionTiers = DubbingProductionTier.allTiers;

  /// Resolve the per-minute rate for a given tier ID
  static double getTierRatePerMinute(String tierId) {
    switch (tierId) {
      case 'audio_starter':
        return perMinuteAudioStarterRate;
      case 'audio_pro':
        return perMinuteAudioProRate;
      case 'video_pro':
        return perMinuteVideoProRate;
      case 'video_ultra':
        return perMinuteVideoUltraRate;
      case 'audio_ultra':
      case 'audio_track':
      default:
        return perMinuteAudioTrackRate;
    }
  }

  /// Get the flat dubbing rate per language based on tier and duration.
  static double getFlatRateForTier({
    required String tierId,
    required int durationSeconds,
  }) {
    final perMinuteRate = getTierRatePerMinute(tierId);
    if (durationSeconds <= 0) {
      return perMinuteRate;
    }
    final effectiveSeconds = math.max(60, durationSeconds);
    final calculated = (effectiveSeconds / 60.0) * perMinuteRate;
    return double.parse(calculated.toStringAsFixed(2));
  }

  /// Calculate total cost for a specific Dubbing Production Tier
  static double calculateProductionTierCost({
    required String tierId,
    required int languageCount,
    required int durationSeconds,
    Channel? channel,
    double? discountPercent,
  }) {
    if (languageCount <= 0) return 0.0;
    final effDiscount = (discountPercent ??
            channel?.effectiveDubbingDiscountPercent ??
            0.0)
        .clamp(0.0, 100.0);

    if (effDiscount >= 100.0 || (channel != null && channel.isDubbingFree)) {
      return 0.0;
    }

    final rate = getFlatRateForTier(tierId: tierId, durationSeconds: durationSeconds);
    final baseCost = languageCount * rate;

    if (effDiscount > 0.0) {
      final discountedCost = baseCost * (1.0 - (effDiscount / 100.0));
      return double.parse(discountedCost.toStringAsFixed(2));
    }
    return double.parse(baseCost.toStringAsFixed(2));
  }

  /// Duration tier references for display, grouping, and ceiling calculation ($0.30/min baseline)
  static const List<DubbingDurationTier> dubbingDurationTiers = [
    DubbingDurationTier(
      id: 'tier_shorts',
      name: 'Shorts & Clips',
      durationLabel: '≤ 60s (Up to 1 min)',
      maxSeconds: 60,
      standardFlatRatePerLanguage: 0.30,
      customFlatRatePerLanguage: 0.30,
      voiceCloneRatePerLanguage: 0.30,
    ),
    DubbingDurationTier(
      id: 'tier_mini',
      name: 'Mini Video',
      durationLabel: '1 to 5 mins (61s – 300s)',
      maxSeconds: 300,
      standardFlatRatePerLanguage: 1.50,
      customFlatRatePerLanguage: 1.50,
      voiceCloneRatePerLanguage: 1.50,
    ),
    DubbingDurationTier(
      id: 'tier_standard',
      name: 'Standard Video',
      durationLabel: '5 to 10 mins (301s – 600s)',
      maxSeconds: 600,
      standardFlatRatePerLanguage: 3.00,
      customFlatRatePerLanguage: 3.00,
      voiceCloneRatePerLanguage: 3.00,
    ),
    DubbingDurationTier(
      id: 'tier_extended',
      name: 'Extended Video',
      durationLabel: '10 to 30 mins (601s – 1800s)',
      maxSeconds: 1800,
      standardFlatRatePerLanguage: 9.00,
      customFlatRatePerLanguage: 9.00,
      voiceCloneRatePerLanguage: 9.00,
    ),
    DubbingDurationTier(
      id: 'tier_longform',
      name: 'Long-Form Video',
      durationLabel: '30 to 60 mins (1801s – 3600s)',
      maxSeconds: 3600,
      standardFlatRatePerLanguage: 18.00,
      customFlatRatePerLanguage: 18.00,
      voiceCloneRatePerLanguage: 18.00,
    ),
  ];

  /// Get the flat dubbing rate per language based on video duration, channel type, and voice synthesis mode.
  /// Billed at raw provider pass-through cost with 0% platform profit.
  /// Proportional per-minute calculation (ElevenLabs model) so 7-min video pays less than 10-min video.
  static double getFlatDubbingPricePerLanguage({
    required int durationSeconds,
    ChannelType channelType = ChannelType.standard,
    String voiceType = 'standard',
    bool isVoiceClone = false,
  }) {
    final clone = isVoiceClone || voiceType == 'cloned' || voiceType == 'voice_clone';
    final perMinuteRate = clone ? perMinuteVoiceCloneRate : perMinuteStandardDubbingRate;

    if (durationSeconds <= 0) {
      return perMinuteRate; // Default 1-minute floor
    }

    // Proportional per-minute calculation (ElevenLabs model) with 60s minimum floor
    final effectiveSeconds = math.max(60, durationSeconds);
    final calculated = (effectiveSeconds / 60.0) * perMinuteRate;
    return double.parse(calculated.toStringAsFixed(2));
  }

  /// Get the duration tier for a given video duration in seconds.
  static DubbingDurationTier getDubbingDurationTier(int durationSeconds) {
    if (durationSeconds <= 60) return dubbingDurationTiers[0];
    if (durationSeconds <= 300) return dubbingDurationTiers[1];
    if (durationSeconds <= 600) return dubbingDurationTiers[2];
    if (durationSeconds <= 1800) return dubbingDurationTiers[3];
    return dubbingDurationTiers[4];
  }

  /// Base rates per minute ($0.30/min baseline)
  static const double standardDubbingRatePerLanguage = 0.30;
  static const double standardDubbingMinCost = 0.30;
  static const double standardDubbingCapCost = 30.00;

  static const double customDubbingRatePerLanguage = 0.30;
  static const double customDubbingMinCost = 0.30;
  static const double customDubbingCapCost = 30.00;

  static const double standardVoiceCloneRatePerLanguage = 0.30;
  static const double standardVoiceCloneMinCost = 0.30;
  static const double standardVoiceCloneCapCost = 30.00;

  static const double customVoiceCloneRatePerLanguage = 0.30;
  static const double customVoiceCloneMinCost = 0.30;
  static const double customVoiceCloneCapCost = 30.00;

  /// Get dubbing rate per language based on channel type and voice synthesis mode
  static double getDubbingRatePerLanguage(
    ChannelType type, {
    String voiceType = 'standard',
    bool isVoiceClone = false,
  }) {
    final clone = isVoiceClone || voiceType == 'cloned' || voiceType == 'voice_clone';
    if (clone) {
      return standardVoiceCloneRatePerLanguage;
    }
    return standardDubbingRatePerLanguage;
  }

  /// Get minimum dubbing job cost based on channel type and voice synthesis mode
  static double getDubbingMinCost(
    ChannelType type, {
    String voiceType = 'standard',
    bool isVoiceClone = false,
  }) {
    final clone = isVoiceClone || voiceType == 'cloned' || voiceType == 'voice_clone';
    if (clone) {
      return standardVoiceCloneMinCost;
    }
    return standardDubbingMinCost;
  }

  /// Get maximum dubbing cost cap based on channel type and voice synthesis mode
  static double getDubbingCapCost(
    ChannelType type, {
    String voiceType = 'standard',
    bool isVoiceClone = false,
  }) {
    final clone = isVoiceClone || voiceType == 'cloned' || voiceType == 'voice_clone';
    if (clone) {
      return standardVoiceCloneCapCost;
    }
    return standardDubbingCapCost;
  }

  /// Calculates dubbing generation flat cost based on video duration, language count, channel type, voice synthesis mode, and channel discounts.
  /// When [durationSeconds] > 0, calculates flat price by duration tier.
  /// When [durationSeconds] is 0 or omitted, falls back to base rate per language with min/cap clamps.
  /// Applies any Super Admin granted [discountPercent] or [channel] discounts (e.g. Free, 50%, or custom %).
  static double calculateDubbingCost({
    required int languageCount,
    int durationSeconds = 0,
    ChannelType channelType = ChannelType.standard,
    String voiceType = 'standard',
    bool isVoiceClone = false,
    Channel? channel,
    double? discountPercent,
  }) {
    if (languageCount <= 0) return 0.0;

    // Resolve applicable discount (Super Admin benefit)
    final effDiscount = (discountPercent ??
            channel?.effectiveDubbingDiscountPercent ??
            0.0)
        .clamp(0.0, 100.0);

    if (effDiscount >= 100.0 || (channel != null && channel.isDubbingFree)) {
      return 0.0;
    }

    double baseCost;
    if (durationSeconds > 0) {
      final rate = getFlatDubbingPricePerLanguage(
        durationSeconds: durationSeconds,
        channelType: channelType,
        voiceType: voiceType,
        isVoiceClone: isVoiceClone,
      );
      baseCost = languageCount * rate;
    } else {
      final rate = getDubbingRatePerLanguage(
        channelType,
        voiceType: voiceType,
        isVoiceClone: isVoiceClone,
      );
      final minCost = getDubbingMinCost(
        channelType,
        voiceType: voiceType,
        isVoiceClone: isVoiceClone,
      );
      final capCost = getDubbingCapCost(
        channelType,
        voiceType: voiceType,
        isVoiceClone: isVoiceClone,
      );
      baseCost = (languageCount * rate).clamp(minCost, capCost);
    }

    if (effDiscount > 0.0) {
      final discountedCost = baseCost * (1.0 - (effDiscount / 100.0));
      return double.parse(discountedCost.toStringAsFixed(2));
    }
    return double.parse(baseCost.toStringAsFixed(2));
  }

  /// AI Visual Lip-Sync feature has been discontinued and removed.
  static double getFlatLipSyncPricePerLanguage({
    required int durationSeconds,
    ChannelType channelType = ChannelType.standard,
  }) {
    return 0.0;
  }

  /// AI Visual Lip-Sync feature has been discontinued and removed.
  static double calculateLipSyncCost({
    required int languageCount,
    int durationSeconds = 0,
    ChannelType channelType = ChannelType.standard,
    double discountPercent = 0.0,
  }) {
    return 0.0;
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

  /// Production-Ready Subtitle Tier Catalog (Single unified Ultra Tier: $0.50 / 10m)
  static const List<SubtitleProductionTier> subtitleTiers = SubtitleProductionTier.allTiers;

  /// Transparent proportional per-minute pricing for Subtitles:
  /// - Ultra: $0.05 / min ($0.50 for 10-minute video)
  static const double perMinuteSubtitleUltraRate = 0.05;
  static const double perMinuteSubtitleUltraAddLangRate = 0.02;

  // Backward compatibility aliases
  static const double perMinuteSubtitleStarterRate = 0.05;
  static const double perMinuteSubtitleProRate = 0.05;
  static const double perMinuteSubtitleStarterAddLangRate = 0.02;
  static const double perMinuteSubtitleProAddLangRate = 0.02;

  /// Calculate total cost for Subtitles (Ultra tier default)
  static double calculateSubtitleTierCost({
    required int languageCount,
    required int durationSeconds,
    String tierId = 'ultra', // 'ultra'
    Channel? channel,
    double? discountPercent,
  }) {
    if (languageCount <= 0) return 0.0;
    final effDiscount = (discountPercent ??
            channel?.effectiveSubtitlesDiscountPercent ??
            0.0)
        .clamp(0.0, 100.0);

    if (effDiscount >= 100.0 || (channel != null && channel.isSubtitlesFree)) {
      return 0.0;
    }

    final tier = SubtitleProductionTier.fromId(tierId);
    final effectiveSeconds = math.max(60, durationSeconds > 0 ? durationSeconds : 600);
    final effectiveMinutes = effectiveSeconds / 60.0;

    final baseCost = effectiveMinutes * tier.perMinuteRateUSD;
    final additionalLanguages = math.max(0, languageCount - 1);
    final additionalCost = additionalLanguages * effectiveMinutes * tier.additionalLangPerMinuteUSD;

    final total = baseCost + additionalCost;

    if (effDiscount > 0.0) {
      final discountedCost = total * (1.0 - (effDiscount / 100.0));
      return double.parse(discountedCost.toStringAsFixed(2));
    }
    return double.parse(total.toStringAsFixed(2));
  }

  /// Get the flat subtitle rate per language based on video duration, channel type, and tier.
  static double getFlatSubtitlePricePerLanguage({
    required int durationSeconds,
    ChannelType channelType = ChannelType.standard,
    String tierId = 'ultra',
  }) {
    final tier = SubtitleProductionTier.fromId(tierId);
    final effectiveSeconds = math.max(60, durationSeconds > 0 ? durationSeconds : 600);
    final cost = (effectiveSeconds / 60.0) * tier.perMinuteRateUSD;
    return double.parse(cost.toStringAsFixed(3));
  }

  /// Subtitle rate per language defaults (0% platform profit pass-through at-cost)
  static const double standardSubtitleRatePerLanguage = 0.05;
  static const double customSubtitleRatePerLanguage = 0.05;
  static const double standardSubtitleMinCost = 0.05;
  static const double customSubtitleMinCost = 0.05;
  static const double standardSubtitleCapCost = 2.50;
  static const double customSubtitleCapCost = 2.50;

  /// Calculates subtitle generation flat cost based on video duration, language count, channel type, tier, and channel discounts.
  /// Applies any Super Admin granted [discountPercent] or [channel] discounts (e.g. Free, 50%, or custom %).
  static double calculateSubtitleCost({
    required int languageCount,
    int durationSeconds = 0,
    ChannelType channelType = ChannelType.standard,
    Channel? channel,
    double? discountPercent,
    String? tierId,
  }) {
    if (languageCount <= 0) return 0.0;
    final isCustom = channelType == ChannelType.custom;
    final minCost = isCustom ? customSubtitleMinCost : standardSubtitleMinCost;

    if (tierId != null && tierId != 'ultra' && tierId != 'default' && tierId != 'starter') {
      return calculateSubtitleTierCost(
        tierId: tierId,
        languageCount: languageCount,
        durationSeconds: durationSeconds,
        channel: channel,
        discountPercent: discountPercent,
      );
    }

    if (durationSeconds > 0) {
      final tier = getSubtitleDurationTier(durationSeconds);
      final rate = isCustom ? tier.customFlatRatePerLanguage : tier.standardFlatRatePerLanguage;
      final rawCost = languageCount * rate;
      final effDiscount = (discountPercent ??
              channel?.effectiveSubtitlesDiscountPercent ??
              0.0)
          .clamp(0.0, 100.0);
      if (effDiscount >= 100.0 || (channel != null && channel.isSubtitlesFree)) {
        return 0.0;
      }
      final discounted = effDiscount > 0.0 ? rawCost * (1.0 - (effDiscount / 100.0)) : rawCost;
      return double.parse(math.max(minCost, discounted).toStringAsFixed(2));
    }

    final rate = isCustom ? customSubtitleRatePerLanguage : standardSubtitleRatePerLanguage;
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
        'Credibility Badge on Thumbnail & Video Player',
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

  /// Computes AI Feature generation cost based on selected capabilities, target languages, video duration, channel type, and channel discounts.
  static double calculateAIFeatureCost({
    required Set<String> selectedFeatures,
    required List<String> targetLanguages,
    ChannelType channelType = ChannelType.standard,
    int durationSeconds = 0,
    String factCheckTier = 'standard',
    String voiceType = 'standard',
    bool isVoiceClone = false,
    Channel? channel,
    double? dubbingDiscountPercent,
    double? subtitlesDiscountPercent,
    String subtitleTier = 'ultra',
  }) {
    if (selectedFeatures.isEmpty) return 0.0;

    var cost = 0.0;
    final langCount = targetLanguages.isEmpty ? 1 : targetLanguages.length;

    if (selectedFeatures.contains('subtitles')) {
      cost += calculateSubtitleCost(
        languageCount: langCount,
        durationSeconds: durationSeconds,
        channelType: channelType,
        channel: channel,
        discountPercent: subtitlesDiscountPercent,
        tierId: subtitleTier,
      );
    }

    if (selectedFeatures.contains('dubbing')) {
      final dubbingCount = targetLanguages.where(isDubbingSupported).length;
      cost += calculateDubbingCost(
        languageCount: dubbingCount,
        durationSeconds: durationSeconds,
        channelType: channelType,
        voiceType: voiceType,
        isVoiceClone: isVoiceClone,
        channel: channel,
        discountPercent: dubbingDiscountPercent,
      );
    }

    // Epistemic Ground-Truth Fact-Checking is 100% Free for all creators (sponsored by TruthWorld)
    if (selectedFeatures.contains('factcheck')) {
      cost += calculateFactCheckCost(
        durationSeconds: durationSeconds,
        channelType: channelType,
        tierType: factCheckTier,
      ); // Always returns 0.00
    }

    // AI Video Summary & Timestamped Auto-Chapters are 100% Free platform features
    // (generated via Community Guidelines verification & Gemini Gateway with 0% creator markup).
    // Maintained at $0.00 for creator adoption and platform parity with YouTube.
    if (selectedFeatures.contains('chapters')) {
      cost += 0.00;
    }

    return double.parse(cost.toStringAsFixed(2));
  }

  /// Calculates the creator's live spendable balance combining funded wallet balance, rollover credits, and channel revenues
}
