import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:truthworld/data/models/channel.dart';

enum WalletTransactionCategory {
  walletTopup,
  customChannelPlan,
  storageTopup,
  bandwidthTopup,
  aiSubtitles,
  aiDubbing,
  aiFactcheck,
  aiSummaryChapters,
  aiBundle,
  payoutWithdrawal,
  revenueEarned,
}

class SpendableBalance {
  final double fundedBalance;
  final double trialCreditRemaining;
  final double rolloverCredit;
  final double withdrawableRevenue;
  final double lockedRevenue;

  const SpendableBalance({
    required this.withdrawableRevenue,
    required this.lockedRevenue,
    this.trialCreditRemaining = 0.0,
    this.fundedBalance = 0.0,
    this.rolloverCredit = 0.0,
  });

  double get totalRevenue => withdrawableRevenue + lockedRevenue;
  double get totalSpendableBalance =>
      fundedBalance + trialCreditRemaining + rolloverCredit + totalRevenue;

  bool canAfford(double amount) => totalSpendableBalance >= amount;
}

class WalletTransaction {
  final String id;
  final String channelId;
  final String userId;
  final double amount;
  final double trialCreditDeducted;
  final double rolloverDeducted;
  final double fundedDeducted;
  final double revenueDeducted;
  final WalletTransactionCategory category;
  final String description;
  final double balanceBefore;
  final double balanceAfter;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  WalletTransaction({
    required this.id,
    required this.channelId,
    required this.userId,
    required this.amount,
    required this.trialCreditDeducted,
    required this.revenueDeducted,
    required this.category,
    required this.description,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.timestamp,
    this.rolloverDeducted = 0.0,
    this.fundedDeducted = 0.0,
    this.metadata,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'channelId': channelId,
    'userId': userId,
    'amount': amount,
    'trialCreditDeducted': trialCreditDeducted,
    'rolloverDeducted': rolloverDeducted,
    'fundedDeducted': fundedDeducted,
    'revenueDeducted': revenueDeducted,
    'category': category.name,
    'description': description,
    'balanceBefore': balanceBefore,
    'balanceAfter': balanceAfter,
    'timestamp': Timestamp.fromDate(timestamp),
    'metadata': metadata,
  };

  factory WalletTransaction.fromMap(Map<String, dynamic> map, String docId) {
    return WalletTransaction(
      id: docId,
      channelId: map['channelId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      trialCreditDeducted:
          (map['trialCreditDeducted'] as num?)?.toDouble() ?? 0.0,
      rolloverDeducted:
          (map['rolloverDeducted'] as num?)?.toDouble() ?? 0.0,
      fundedDeducted:
          (map['fundedDeducted'] as num?)?.toDouble() ?? 0.0,
      revenueDeducted: (map['revenueDeducted'] as num?)?.toDouble() ?? 0.0,
      category: WalletTransactionCategory.values.firstWhere(
        (e) => e.name == map['category'],
        orElse: () => WalletTransactionCategory.aiBundle,
      ),
      description: map['description'] as String? ?? '',
      balanceBefore: (map['balanceBefore'] as num?)?.toDouble() ?? 0.0,
      balanceAfter: (map['balanceAfter'] as num?)?.toDouble() ?? 0.0,
      timestamp: (map['timestamp'] is Timestamp)
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      metadata: map['metadata'] != null
          ? Map<String, dynamic>.from(map['metadata'] as Map)
          : null,
    );
  }
}

class StorageTopupPack {
  final String id;
  final String title;
  final int gigabytes;
  final double priceUSD;
  final String badge;

  const StorageTopupPack({
    required this.id,
    required this.title,
    required this.gigabytes,
    required this.priceUSD,
    this.badge = '',
  });

  int get bytes => gigabytes * 1024 * 1024 * 1024;
}

class BandwidthTopupPack {
  final String id;
  final String title;
  final int gigabytes;
  final double priceUSD;
  final String badge;

  const BandwidthTopupPack({
    required this.id,
    required this.title,
    required this.gigabytes,
    required this.priceUSD,
    this.badge = '',
  });

  int get bytes => gigabytes * 1024 * 1024 * 1024;
}

/// Video duration tiers for flat dubbing pricing.
/// Dubbing is NOT free: compute & synthesis costs scale with video duration and language count.
class DubbingDurationTier {
  final String id;
  final String name;
  final String durationLabel;
  final int maxSeconds;
  final double standardFlatRatePerLanguage;
  final double customFlatRatePerLanguage;
  final double? voiceCloneRatePerLanguage;

  const DubbingDurationTier({
    required this.id,
    required this.name,
    required this.durationLabel,
    required this.maxSeconds,
    required this.standardFlatRatePerLanguage,
    required this.customFlatRatePerLanguage,
    this.voiceCloneRatePerLanguage,
  });

  double flatRateForChannel(ChannelType type) {
    return type == ChannelType.custom
        ? customFlatRatePerLanguage
        : standardFlatRatePerLanguage;
  }

  double flatRateForVoiceType({
    required String voiceType,
    ChannelType type = ChannelType.standard,
  }) {
    if (voiceType == 'cloned' || voiceType == 'voice_clone') {
      return voiceCloneRatePerLanguage ?? flatRateForChannel(type);
    }
    return flatRateForChannel(type);
  }

  String get label => durationLabel;
}

/// Authoritative definition of TruthWorld Audio and Video Dubbing Tiers.
/// Clean, transparent, zero charm-pricing ($1, $2, $3, $4, $5 for 10-minute videos).
class DubbingProductionTier {
  final String id;
  final String name;
  final String category; // 'audio' | 'video'
  final double perMinuteRateUSD; // 0.10, 0.20, 0.30, 0.40, 0.50
  final double tenMinutePriceUSD; // 1.0, 2.0, 3.0, 4.0, 5.0
  final String asrProvider;
  final String translationEngine;
  final String ttsEngine;
  final String visualSync;
  final String badge;
  final String description;
  final bool isCinemaGrade;
  final bool isLipSync;
  final bool isVoiceClone;

  const DubbingProductionTier({
    required this.id,
    required this.name,
    required this.category,
    required this.perMinuteRateUSD,
    required this.tenMinutePriceUSD,
    required this.asrProvider,
    required this.translationEngine,
    required this.ttsEngine,
    required this.visualSync,
    required this.badge,
    required this.description,
    this.isCinemaGrade = false,
    this.isLipSync = false,
    this.isVoiceClone = false,
  });

  static const DubbingProductionTier audioStarter = DubbingProductionTier(
    id: 'audio_starter',
    name: 'Audio Starter',
    category: 'audio',
    perMinuteRateUSD: 0.10,
    tenMinutePriceUSD: 1.00,
    asrProvider: 'AssemblyAI Universal 3.5 Pro (18 Core Langs) + Google Chirp',
    translationEngine: 'Google Cloud Translation v3 + Gemini 2.5',
    ttsEngine: 'Google Chirp HD 3 (Journey & Studio)',
    visualSync: 'None (Clean Audio Track)',
    badge: '100% BGM Preserved',
    description: 'Clean localized multi-language narration with 100% Studio Preservation (discrete Vocals, Drums, Bass, Foley separation & zero phase cancellation).',
    isCinemaGrade: false,
    isLipSync: false,
    isVoiceClone: false,
  );

  static const DubbingProductionTier audioPro = DubbingProductionTier(
    id: 'audio_pro',
    name: 'Audio Pro',
    category: 'audio',
    perMinuteRateUSD: 0.20,
    tenMinutePriceUSD: 2.00,
    asrProvider: 'AssemblyAI (18 Langs) + Sarvam AI Indic + Google Chirp',
    translationEngine: 'Google Cloud Translation v3 + Gemini 2.5',
    ttsEngine: 'ElevenLabs v4 Fast API (Ultra-Expressive)',
    visualSync: 'None (Clean Audio Track)',
    badge: '100% BGM Preserved',
    description: 'Emotionally expressive neural voices with Sarvam AI Indic accuracy and 100% Studio Preservation (discrete stems with zero phase cancellation).',
    isCinemaGrade: false,
    isLipSync: false,
    isVoiceClone: false,
  );

  static const DubbingProductionTier audioUltra = DubbingProductionTier(
    id: 'audio_ultra',
    name: 'Audio Ultra',
    category: 'audio',
    perMinuteRateUSD: 0.30,
    tenMinutePriceUSD: 3.00,
    asrProvider: 'AssemblyAI (18 Langs) + Sarvam AI Indic + Google Chirp',
    translationEngine: 'Google Cloud Translation v3 + Gemini 2.5',
    ttsEngine: 'ElevenLabs v4 Studio Voice Cloning',
    visualSync: 'Viseme Cadence Locking (Zero Overhang)',
    badge: '100% BGM Preserved',
    description: 'Replicates creator vocal identity with 100% Studio Preservation & Viseme Cadence Locking (prevents vocal overhang on talking-head videos with zero phase cancellation).',
    isCinemaGrade: false,
    isLipSync: false,
    isVoiceClone: true,
  );

  static const DubbingProductionTier videoPro = DubbingProductionTier(
    id: 'video_pro',
    name: 'Video Pro',
    category: 'video',
    perMinuteRateUSD: 0.40,
    tenMinutePriceUSD: 4.00,
    asrProvider: 'AssemblyAI (18 Langs) + Sarvam AI Indic + Google Chirp',
    translationEngine: 'Google Cloud Translation v3 + Gemini 2.5',
    ttsEngine: 'ElevenLabs v4 Voice Cloning',
    visualSync: 'AI Visual Lip-Sync (LatentSync GPU)',
    badge: '100% BGM Preserved',
    description: 'Synchronized mouth movement re-targeting with 100% Studio Preservation (discrete stems, CodeFormer & ElevenLabs voice cloning).',
    isCinemaGrade: false,
    isLipSync: true,
    isVoiceClone: true,
  );

  static const DubbingProductionTier videoUltra = DubbingProductionTier(
    id: 'video_ultra',
    name: 'Video Ultra',
    category: 'video',
    perMinuteRateUSD: 0.50,
    tenMinutePriceUSD: 5.00,
    asrProvider: 'AssemblyAI (18 Langs) + Sarvam AI Indic + Google Chirp',
    translationEngine: 'Google Cloud Translation v3 + Gemini 4 Argon (Isometric)',
    ttsEngine: 'ElevenLabs v4 Voice Cloning + Multi-Speaker Diarized Casting',
    visualSync: 'Cinema Neural Lip-Sync & Face Motion Retention',
    badge: 'Cinema Grade',
    description: 'Hollywood theatrical grade with 100% Studio Preservation (discrete 4-stem Demucs M&E isolation, Gemini 4 Argon isometry & Poisson blending).',
    isCinemaGrade: true,
    isLipSync: true,
    isVoiceClone: true,
  );

  static const List<DubbingProductionTier> allTiers = [
    audioStarter,
    audioPro,
    audioUltra,
    videoPro,
    videoUltra,
  ];

  static List<DubbingProductionTier> get audioTiers =>
      allTiers.where((t) => t.category == 'audio').toList();

  static List<DubbingProductionTier> get videoTiers =>
      allTiers.where((t) => t.category == 'video').toList();

  static DubbingProductionTier fromId(String? id) {
    if (id == null || id.isEmpty) return audioStarter;
    return allTiers.firstWhere(
      (t) => t.id == id,
      orElse: () => audioStarter,
    );
  }

  String get tenMinuteRateFormatted => '\$${tenMinutePriceUSD.toInt()}';
}

/// Authoritative definition of TruthWorld Subtitle Tiers (Starter & Pro).
/// Clean, transparent, zero charm-pricing ($0.50 & $0.75 for 10-minute video subtitles).
class SubtitleProductionTier {
  final String id; // 'starter' | 'pro'
  final String name;
  final double perMinuteRateUSD; // 0.05 (Starter: $0.50 for 10m), 0.075 (Pro: $0.75 for 10m)
  final double tenMinutePriceUSD; // 0.50, 0.75
  final double additionalLangTenMinutePriceUSD; // 0.20 (Starter), 0.30 (Pro)
  final double additionalLangPerMinuteUSD; // 0.02 (Starter), 0.03 (Pro)
  final String asrProvider;
  final String translationEngine;
  final String badge;
  final String description;
  final bool isPro;

  const SubtitleProductionTier({
    required this.id,
    required this.name,
    required this.perMinuteRateUSD,
    required this.tenMinutePriceUSD,
    required this.additionalLangTenMinutePriceUSD,
    required this.additionalLangPerMinuteUSD,
    required this.asrProvider,
    required this.translationEngine,
    required this.badge,
    required this.description,
    this.isPro = false,
  });

  static const SubtitleProductionTier starter = SubtitleProductionTier(
    id: 'starter',
    name: 'Starter Subtitles',
    perMinuteRateUSD: 0.05,
    tenMinutePriceUSD: 0.50,
    additionalLangTenMinutePriceUSD: 0.20,
    additionalLangPerMinuteUSD: 0.02,
    asrProvider: 'AssemblyAI Universal 3.5 Pro + Sarvam AI Indic + Google Chirp',
    translationEngine: 'Google Cloud Translation v3 + Gemini 2.5 Flash',
    badge: 'Starter',
    description: 'High-speed, cost-effective subtitles with duration-aware sync and clean reading flow.',
    isPro: false,
  );

  static const SubtitleProductionTier pro = SubtitleProductionTier(
    id: 'pro',
    name: 'Pro Subtitles',
    perMinuteRateUSD: 0.075,
    tenMinutePriceUSD: 0.75,
    additionalLangTenMinutePriceUSD: 0.30,
    additionalLangPerMinuteUSD: 0.03,
    asrProvider: 'AssemblyAI Universal 3.5 Pro + Sarvam AI Indic + Google Chirp',
    translationEngine: 'Google Cloud Translation v3 + Gemini 4 Argon',
    badge: 'Cinema-Grade',
    description: 'Cinema-grade cultural adaptation, idiomatic transcreation, and precision split timing.',
    isPro: true,
  );

  static const List<SubtitleProductionTier> allTiers = [starter, pro];

  static SubtitleProductionTier fromId(String? id) {
    if (id == 'pro') return pro;
    return starter;
  }
}

/// Video duration tiers for flat subtitle pricing.
/// Truthworld enforces a 2-minute (120s) minimum video upload length.
class SubtitleDurationTier {
  final String id;
  final String name;
  final String durationLabel;
  final int minSeconds;
  final int maxSeconds;
  final double standardFlatRatePerLanguage;
  final double customFlatRatePerLanguage;

  const SubtitleDurationTier({
    required this.id,
    required this.name,
    required this.durationLabel,
    required this.minSeconds,
    required this.maxSeconds,
    required this.standardFlatRatePerLanguage,
    required this.customFlatRatePerLanguage,
  });

  double flatRateForChannel(ChannelType type) {
    return type == ChannelType.custom
        ? customFlatRatePerLanguage
        : standardFlatRatePerLanguage;
  }

  String get label => durationLabel;
}

/// Video duration tiers for transparent channel fact-checking pricing.
/// Epistemic AI verification extracts claims, cross-references citations, and computes Truth Scores.
class FactCheckDurationTier {
  final String id;
  final String name;
  final String durationLabel;
  final int minSeconds;
  final int maxSeconds;
  // Standard Tier (Current)
  final double standardFlatRate;
  final double customFlatRate; // 50% Custom Channel Partner discount
  // Short Fact-Checking (Overview)
  final double shortStandardRate;
  final double shortCustomRate;
  // Full Ground Fact-Checking (Ground-Truth Verified Claims)
  final double fullGroundStandardRate;
  final double fullGroundCustomRate;

  const FactCheckDurationTier({
    required this.id,
    required this.name,
    required this.durationLabel,
    required this.minSeconds,
    required this.maxSeconds,
    required this.standardFlatRate,
    required this.customFlatRate,
    required this.shortStandardRate,
    required this.shortCustomRate,
    required this.fullGroundStandardRate,
    required this.fullGroundCustomRate,
  });

  double rateFor({
    required ChannelType channelType,
    String tierType = 'standard',
  }) {
    final isCustom = channelType == ChannelType.custom;
    final normalizedTier = tierType.toLowerCase();
    if (normalizedTier == 'short') {
      return isCustom ? shortCustomRate : shortStandardRate;
    } else if (normalizedTier == 'full_ground' ||
        normalizedTier == 'fullground' ||
        normalizedTier == 'ground') {
      return isCustom ? fullGroundCustomRate : fullGroundStandardRate;
    }
    return isCustom ? customFlatRate : standardFlatRate;
  }

  double flatRateForChannel(ChannelType type, [String tierType = 'standard']) {
    return rateFor(channelType: type, tierType: tierType);
  }

  String get label => durationLabel;
}

/// Defines metadata and features for the 3 distinct Fact-Checking depth tiers:
/// 1. Short Fact-Checking (Epistemic Overview - broader than a simple summary)
/// 2. Standard Fact-Checking (Current Fact-Checking - claims verified & Truth Score)
/// 3. Full Ground Fact-Checking (Exhaustive Ground-Truth Verification of every claim)
class FactCheckDepthPlan {
  final String id; // 'short' | 'standard' | 'full_ground'
  final String title;
  final String shortTitle;
  final String tagline;
  final String badgeLabel;
  final String description;
  final List<String> features;
  final IconData icon;
  final double priceMultiplier;

  const FactCheckDepthPlan({
    required this.id,
    required this.title,
    required this.shortTitle,
    required this.tagline,
    required this.badgeLabel,
    required this.description,
    required this.features,
    required this.icon,
    this.priceMultiplier = 1.0,
  });

  String get name => title;
}

/// Optional Channel-level monthly Fact-Checking passes for high-volume creators.
class ChannelFactCheckAddonTier {
  final String id;
  final String title;
  final double priceUSD;
  final String billingPeriod;
  final String description;
  final List<String> perks;
  final bool isPopular;

  const ChannelFactCheckAddonTier({
    required this.id,
    required this.title,
    required this.priceUSD,
    required this.billingPeriod,
    required this.description,
    required this.perks,
    this.isPopular = false,
  });
}

/// Category classification for the unified channel financial activity feed.
enum UnifiedTransactionType {
  topup,
  aiSpend,
  planUpgrade,
  payout,
  revenueEarned,
}

/// Unified model representing any channel financial transaction:
/// Pre-funded top-ups, AI feature spends, custom plan upgrades, creator bank payouts, and finalized revenue statements.
class UnifiedChannelTransaction {
  final String id;
  final String title;
  final String subtitle;
  final double amount;
  final String currency; // 'USD' or 'INR'
  final bool isCredit;
  final UnifiedTransactionType type;
  final String status; // 'completed', 'pending', 'processing', 'held', 'rejected'
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  const UnifiedChannelTransaction({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.currency,
    required this.isCredit,
    required this.type,
    required this.timestamp,
    this.status = 'completed',
    this.metadata,
  });

  String get formattedAmount {
    final prefix = isCredit ? '+' : '-';
    final symbol = currency.toUpperCase() == 'INR' ? '₹' : r'$';
    return '$prefix$symbol${amount.toStringAsFixed(2)}';
  }

  factory UnifiedChannelTransaction.fromWalletTransaction(WalletTransaction tx) {
    UnifiedTransactionType type;
    bool isCredit = false;
    String currency = 'USD';

    switch (tx.category) {
      case WalletTransactionCategory.walletTopup:
        type = UnifiedTransactionType.topup;
        isCredit = true;
        currency = 'USD';
        break;
      case WalletTransactionCategory.payoutWithdrawal:
        type = UnifiedTransactionType.payout;
        isCredit = false;
        currency = 'INR';
        break;
      case WalletTransactionCategory.revenueEarned:
        type = UnifiedTransactionType.revenueEarned;
        isCredit = true;
        currency = 'INR';
        break;
      case WalletTransactionCategory.customChannelPlan:
      case WalletTransactionCategory.storageTopup:
      case WalletTransactionCategory.bandwidthTopup:
        type = UnifiedTransactionType.planUpgrade;
        isCredit = false;
        currency = 'USD';
        break;
      case WalletTransactionCategory.aiSubtitles:
      case WalletTransactionCategory.aiDubbing:
      case WalletTransactionCategory.aiFactcheck:
      case WalletTransactionCategory.aiSummaryChapters:
      case WalletTransactionCategory.aiBundle:
        type = UnifiedTransactionType.aiSpend;
        isCredit = false;
        currency = 'USD';
        break;
    }

    final rawStatus = tx.metadata?['status'] as String? ?? 'completed';

    return UnifiedChannelTransaction(
      id: tx.id,
      title: tx.description.isNotEmpty ? tx.description : 'Channel Transaction',
      subtitle: tx.category.name,
      amount: tx.amount,
      currency: currency,
      isCredit: isCredit,
      type: type,
      status: rawStatus,
      timestamp: tx.timestamp,
      metadata: tx.metadata,
    );
  }

  factory UnifiedChannelTransaction.fromPayoutRequest(Map<String, dynamic> data, String docId) {
    final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
    final currency = data['currency'] as String? ?? 'INR';
    final method = data['paymentMethod'] as String? ?? 'Bank / UPI';
    final status = (data['status'] as String? ?? 'pending').toLowerCase();
    final ts = (data['createdAt'] is Timestamp)
        ? (data['createdAt'] as Timestamp).toDate()
        : DateTime.now();

    return UnifiedChannelTransaction(
      id: docId,
      title: 'Cash Out ($method)',
      subtitle: 'Payout Request • ${status.toUpperCase()}',
      amount: amount,
      currency: currency,
      isCredit: false,
      type: UnifiedTransactionType.payout,
      status: status,
      timestamp: ts,
      metadata: data,
    );
  }

  factory UnifiedChannelTransaction.fromRevenueStatement(Map<String, dynamic> data, String docId) {
    final creatorShare = (data['creatorShare'] as num?)?.toDouble() ?? 0.0;
    final month = data['month'] as String? ?? '';
    final ts = (data['updatedAt'] is Timestamp)
        ? (data['updatedAt'] as Timestamp).toDate()
        : ((data['createdAt'] is Timestamp)
            ? (data['createdAt'] as Timestamp).toDate()
            : DateTime.now());

    return UnifiedChannelTransaction(
      id: docId,
      title: month.isNotEmpty ? 'Revenue Settlement ($month)' : 'Revenue Settlement',
      subtitle: 'Verified Creator Earnings Finalized',
      amount: creatorShare,
      currency: 'INR',
      isCredit: true,
      type: UnifiedTransactionType.revenueEarned,
      status: 'completed',
      timestamp: ts,
      metadata: data,
    );
  }
}


