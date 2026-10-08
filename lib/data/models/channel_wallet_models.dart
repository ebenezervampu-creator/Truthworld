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

  const DubbingDurationTier({
    required this.id,
    required this.name,
    required this.durationLabel,
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

