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
    this.isVoiceClone = false,
  });

  static const DubbingProductionTier audioTrack = DubbingProductionTier(
    id: 'audio_track',
    name: 'Audio Track',
    category: 'audio',
    perMinuteRateUSD: 0.30,
    tenMinutePriceUSD: 3.00,
    asrProvider: 'AssemblyAI Universal 3.5 Pro (18 Languages)',
    translationEngine: 'Google Cloud Translation v3',
    ttsEngine: 'ElevenLabs v4 Studio Voice Cloning',
    visualSync: 'Viseme Cadence Locking (Zero Overhang)',
    badge: '100% BGM Preserved',
    description: 'Replicates creator vocal identity with 100% Studio Preservation & Viseme Cadence Locking (prevents vocal overhang on talking-head videos with zero phase cancellation).',
    isCinemaGrade: false,
    isVoiceClone: true,
  );

  // Backward compatibility aliases pointing to the single unified Audio Track plan
  static const DubbingProductionTier audioUltra = audioTrack;
  static const DubbingProductionTier audioPro = audioTrack;
  static const DubbingProductionTier audioStarter = audioTrack;
  static const DubbingProductionTier videoPro = audioTrack;
  static const DubbingProductionTier videoUltra = audioTrack;

  static const List<DubbingProductionTier> allTiers = [
    audioTrack,
  ];

  static List<DubbingProductionTier> get audioTiers => allTiers;

  static List<DubbingProductionTier> get videoTiers => const [];

  static DubbingProductionTier fromId(String? id) {
    return audioTrack;
  }

  String get tenMinuteRateFormatted => '\$${tenMinutePriceUSD.toInt()}';
}

/// Authoritative definition of TruthWorld Subtitle Tiers.
/// Clean, transparent, zero charm-pricing ($0.50 for 10-minute video subtitles).
class SubtitleProductionTier {
  final String id; // 'ultra'
  final String name;
  final double perMinuteRateUSD; // 0.05 (Ultra: $0.50 for 10m)
  final double tenMinutePriceUSD; // 0.50
  final double additionalLangTenMinutePriceUSD; // 0.20
  final double additionalLangPerMinuteUSD; // 0.02
  final String asrProvider;
  final String translationEngine;
  final String badge;
  final String description;
  final bool isUltra;
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
    this.isUltra = true,
    this.isPro = true,
  });

  static const SubtitleProductionTier ultra = SubtitleProductionTier(
    id: 'ultra',
    name: 'Ultra Subtitles',
    perMinuteRateUSD: 0.05,
    tenMinutePriceUSD: 0.50,
    additionalLangTenMinutePriceUSD: 0.20,
    additionalLangPerMinuteUSD: 0.02,
    asrProvider: 'AssemblyAI Universal 3.5 Pro (18 Languages)',
    translationEngine: 'Google Cloud Translation v3',
    badge: 'Ultra',
    description: 'Cinema-grade cultural adaptation, idiomatic transcreation, and precision split timing powered by Google Cloud Translation v3.',
    isUltra: true,
    isPro: true,
  );

  // Backward-compatibility aliases mapping legacy tiers to ultra
  static const SubtitleProductionTier starter = ultra;
  static const SubtitleProductionTier pro = ultra;

  static const List<SubtitleProductionTier> allTiers = [ultra];

  static SubtitleProductionTier fromId(String? id) {
    return ultra;
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


