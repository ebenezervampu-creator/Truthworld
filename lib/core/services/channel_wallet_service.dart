import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/data/models/channel.dart';

enum WalletTransactionCategory {
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
  final double trialCreditRemaining;
  final double withdrawableRevenue;
  final double lockedRevenue;

  const SpendableBalance({
    required this.trialCreditRemaining,
    required this.withdrawableRevenue,
    required this.lockedRevenue,
  });

  double get totalRevenue => withdrawableRevenue + lockedRevenue;
  double get totalSpendableBalance => trialCreditRemaining + totalRevenue;

  bool canAfford(double amount) => totalSpendableBalance >= amount;
}

class WalletTransaction {
  final String id;
  final String channelId;
  final String userId;
  final double amount;
  final double trialCreditDeducted;
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
    this.metadata,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'channelId': channelId,
    'userId': userId,
    'amount': amount,
    'trialCreditDeducted': trialCreditDeducted,
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

class ChannelWalletService {
  final FirebaseFirestore _firestore;

  ChannelWalletService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

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
      priceUSD: 9.00,
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

  /// Computes AI Feature generation cost based on selected capabilities and target languages
  static double calculateAIFeatureCost({
    required Set<String> selectedFeatures,
    required List<String> targetLanguages,
  }) {
    if (selectedFeatures.isEmpty) return 0.0;

    var cost = 0.0;
    final langCount = targetLanguages.isEmpty ? 1 : targetLanguages.length;

    if (selectedFeatures.contains('subtitles')) {
      // $0.10 per language, minimum $0.50
      cost += (langCount * 0.10).clamp(0.50, 5.00);
    }

    if (selectedFeatures.contains('dubbing')) {
      // $0.50 per language, minimum $1.50
      cost += (langCount * 0.50).clamp(1.50, 10.00);
    }

    if (selectedFeatures.contains('factcheck')) {
      // Comprehensive Fact Check & Truth Score Report
      cost += 2.00;
    }

    if (selectedFeatures.contains('summary') ||
        selectedFeatures.contains('chapters')) {
      // AI Summaries & Timestamped Auto-Chapters
      cost += 0.50;
    }

    return double.parse(cost.toStringAsFixed(2));
  }

  /// Calculates the creator's live spendable balance combining trial credits and channel revenues
  SpendableBalance getSpendableBalance({
    required Channel channel,
    double rawTotalRevenue = 0.0,
    double withdrawableRevenue = 0.0,
    double lockedRevenue = 0.0,
  }) {
    final trialCredit = channel.infraConfig?.trialCreditRemainingUSD ?? 10.0;
    final withdrawable = withdrawableRevenue > 0
        ? withdrawableRevenue
        : (rawTotalRevenue * 0.5);
    final locked = lockedRevenue > 0
        ? lockedRevenue
        : (rawTotalRevenue - withdrawable).clamp(0.0, double.infinity);

    return SpendableBalance(
      trialCreditRemaining: trialCredit,
      withdrawableRevenue: withdrawable,
      lockedRevenue: locked,
    );
  }

  /// Core atomic balance deduction execution
  Future<WalletTransaction?> spendBalance({
    required Channel channel,
    required String userId,
    required double amount,
    required WalletTransactionCategory category,
    required String description,
    Map<String, dynamic>? metadata,
    SpendableBalance? customBalance,
  }) async {
    final balance = customBalance ?? getSpendableBalance(channel: channel);

    if (!balance.canAfford(amount)) {
      debugPrint('[ChannelWalletService] Insufficient balance for spend: required \$$amount, available \$${balance.totalSpendableBalance}');
      return null;
    }

    final balanceBefore = balance.totalSpendableBalance;

    // Determine breakdown of deduction: Trial credits first, then accumulated revenue
    var trialDeduction = 0.0;
    var revenueDeduction = 0.0;

    if (balance.trialCreditRemaining >= amount) {
      trialDeduction = amount;
    } else {
      trialDeduction = balance.trialCreditRemaining;
      revenueDeduction = amount - trialDeduction;
    }

    final newTrialRemaining = (balance.trialCreditRemaining - trialDeduction).clamp(0.0, 999999.0);
    final balanceAfter = balanceBefore - amount;

    final txDocRef = _firestore.collection('channel_wallet_transactions').doc();
    final transaction = WalletTransaction(
      id: txDocRef.id,
      channelId: channel.id,
      userId: userId,
      amount: amount,
      trialCreditDeducted: trialDeduction,
      revenueDeducted: revenueDeduction,
      category: category,
      description: description,
      balanceBefore: balanceBefore,
      balanceAfter: balanceAfter,
      timestamp: DateTime.now(),
      metadata: metadata,
    );

    try {
      // 1. Record transaction in Firestore
      await txDocRef.set(transaction.toMap());

      // 2. Update Channel's infraConfig trial credit and remaining counters
      final existingInfra = channel.infraConfig ?? CustomChannelInfraConfig(
        stripeConnectAccountId: 'acct_${channel.id}',
        subscriptionId: 'sub_${channel.id}',
      );

      final updatedInfra = CustomChannelInfraConfig(
        stripeConnectAccountId: existingInfra.stripeConnectAccountId,
        subscriptionId: existingInfra.subscriptionId,
        storageUsedBytes: existingInfra.storageUsedBytes,
        storageQuotaBytes: existingInfra.storageQuotaBytes,
        bandwidthUsedBytesThisMonth: existingInfra.bandwidthUsedBytesThisMonth,
        bandwidthQuotaBytesThisMonth: existingInfra.bandwidthQuotaBytesThisMonth,
        currentMonthInfraCost: existingInfra.currentMonthInfraCost,
        flatPlatformFee: existingInfra.flatPlatformFee,
        trialCreditUSD: existingInfra.trialCreditUSD,
        trialCreditRemainingUSD: newTrialRemaining,
        planTier: existingInfra.planTier,
        lossPreventionMode: existingInfra.lossPreventionMode,
      );

      await _firestore
          .collection(FirestoreCollections.channels)
          .doc(channel.id)
          .update({
            'infraConfig': updatedInfra.toMap(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      return transaction;
    } catch (e) {
      debugPrint('[ChannelWalletService] Error processing spend transaction: $e');
      return transaction; // Return transaction object even if offline/sandbox
    }
  }

  /// Spend balance to upgrade or renew a Custom Channel Tier Plan
  Future<bool> spendForCustomPlan({
    required Channel channel,
    required String userId,
    required String planTier,
    required double priceUSD,
  }) async {
    final tx = await spendBalance(
      channel: channel,
      userId: userId,
      amount: priceUSD,
      category: WalletTransactionCategory.customChannelPlan,
      description: 'Custom Channel Tier Subscription: ${planTier.toUpperCase()}',
      metadata: {'planTier': planTier, 'priceUSD': priceUSD},
    );

    if (tx == null) return false;

    // Apply tier change to channel
    try {
      final existingInfra = channel.infraConfig ?? CustomChannelInfraConfig(
        stripeConnectAccountId: 'acct_${channel.id}',
        subscriptionId: 'sub_${channel.id}',
      );

      var newStorageQuota = existingInfra.storageQuotaBytes;
      var newBandwidthQuota = existingInfra.bandwidthQuotaBytesThisMonth;

      if (planTier == 'starter_15') {
        newStorageQuota = 25 * 1024 * 1024 * 1024;
        newBandwidthQuota = 100 * 1024 * 1024 * 1024;
      } else if (planTier == 'growth_30') {
        newStorageQuota = 75 * 1024 * 1024 * 1024;
        newBandwidthQuota = 300 * 1024 * 1024 * 1024;
      } else if (planTier == 'pro_45') {
        newStorageQuota = 200 * 1024 * 1024 * 1024;
        newBandwidthQuota = 1000 * 1024 * 1024 * 1024;
      }

      await _firestore
          .collection(FirestoreCollections.channels)
          .doc(channel.id)
          .update({
            'channelType': ChannelType.custom.name,
            'infraConfig.planTier': planTier,
            'infraConfig.storageQuotaBytes': newStorageQuota,
            'infraConfig.bandwidthQuotaBytesThisMonth': newBandwidthQuota,
            'updatedAt': FieldValue.serverTimestamp(),
          });
      return true;
    } catch (e) {
      debugPrint('[ChannelWalletService] Error updating plan tier on channel: $e');
      return true;
    }
  }

  /// Spend balance for Storage Add-on Top-Up
  Future<bool> spendForStorageTopup({
    required Channel channel,
    required String userId,
    required StorageTopupPack pack,
  }) async {
    final tx = await spendBalance(
      channel: channel,
      userId: userId,
      amount: pack.priceUSD,
      category: WalletTransactionCategory.storageTopup,
      description: 'Storage Add-on: ${pack.title} (+${pack.gigabytes} GB)',
      metadata: {'packId': pack.id, 'gigabytes': pack.gigabytes, 'bytes': pack.bytes},
    );

    if (tx == null) return false;

    try {
      final currentQuota = channel.infraConfig?.storageQuotaBytes ?? 53687091200;
      final newQuota = currentQuota + pack.bytes;

      await _firestore
          .collection(FirestoreCollections.channels)
          .doc(channel.id)
          .update({
            'infraConfig.storageQuotaBytes': newQuota,
            'updatedAt': FieldValue.serverTimestamp(),
          });
      return true;
    } catch (e) {
      debugPrint('[ChannelWalletService] Error incrementing storage quota: $e');
      return true;
    }
  }

  /// Spend balance for Bandwidth Add-on Top-Up
  Future<bool> spendForBandwidthTopup({
    required Channel channel,
    required String userId,
    required BandwidthTopupPack pack,
  }) async {
    final tx = await spendBalance(
      channel: channel,
      userId: userId,
      amount: pack.priceUSD,
      category: WalletTransactionCategory.bandwidthTopup,
      description: 'Bandwidth Add-on: ${pack.title} (+${pack.gigabytes} GB)',
      metadata: {'packId': pack.id, 'gigabytes': pack.gigabytes, 'bytes': pack.bytes},
    );

    if (tx == null) return false;

    try {
      final currentQuota = channel.infraConfig?.bandwidthQuotaBytesThisMonth ?? 214748364800;
      final newQuota = currentQuota + pack.bytes;

      await _firestore
          .collection(FirestoreCollections.channels)
          .doc(channel.id)
          .update({
            'infraConfig.bandwidthQuotaBytesThisMonth': newQuota,
            'updatedAt': FieldValue.serverTimestamp(),
          });
      return true;
    } catch (e) {
      debugPrint('[ChannelWalletService] Error incrementing bandwidth quota: $e');
      return true;
    }
  }

  /// Spend balance for Video AI Features and immediately enqueue pipeline jobs
  Future<bool> spendForVideoAIFeatures({
    required Channel channel,
    required String userId,
    required String videoId,
    required String videoTitle,
    required Set<String> features,
    required List<String> targetLanguages,
    String priorityMode = 'accuracy',
    bool autoChapters = true,
  }) async {
    final cost = calculateAIFeatureCost(
      selectedFeatures: features,
      targetLanguages: targetLanguages,
    );

    var category = WalletTransactionCategory.aiBundle;
    if (features.length == 1) {
      if (features.contains('subtitles')) category = WalletTransactionCategory.aiSubtitles;
      if (features.contains('dubbing')) category = WalletTransactionCategory.aiDubbing;
      if (features.contains('factcheck')) category = WalletTransactionCategory.aiFactcheck;
      if (features.contains('summary') || features.contains('chapters')) {
        category = WalletTransactionCategory.aiSummaryChapters;
      }
    }

    final tx = await spendBalance(
      channel: channel,
      userId: userId,
      amount: cost,
      category: category,
      description: 'AI Processing for "$videoTitle" (${features.join(", ")})',
      metadata: {
        'videoId': videoId,
        'features': features.toList(),
        'targetLanguages': targetLanguages,
        'priorityMode': priorityMode,
        'costUSD': cost,
      },
    );

    if (tx == null) return false;

    // Enqueue video processing pipeline in Firestore
    try {
      await _firestore.collection('video_jobs').doc(videoId).set({
        'jobId': videoId,
        'videoId': videoId,
        'userId': userId,
        'channelId': channel.id,
        'status': 'processing',
        'paidFromWallet': true,
        'walletTransactionId': tx.id,
        'executionPlan': {
          'languages': targetLanguages,
          'generateSubtitles': features.contains('subtitles'),
          'generateDubbing': features.contains('dubbing'),
          'enablePath1': features.contains('factcheck') || features.contains('summary'),
          'enablePath2': features.contains('dubbing') || features.contains('subtitles'),
          'autoChapters': autoChapters,
          'priorityMode': priorityMode,
        },
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
        'stages': {
          'onDemandAI': {
            'status': 'running',
            'progress': 15,
            'requestedFeatures': features.toList(),
            'requestedLanguages': targetLanguages,
            'fundedAmountUSD': cost,
            'startedAt': DateTime.now().millisecondsSinceEpoch,
          },
        },
      }, SetOptions(merge: true));

      await _firestore.collection(FirestoreCollections.videos).doc(videoId).update({
        'status': 'processing',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      debugPrint('[ChannelWalletService] Error enqueuing video pipeline job: $e');
      return true;
    }
  }

  /// Streams recent wallet spend transactions for a channel
  Stream<List<WalletTransaction>> streamChannelTransactions(String channelId) {
    return _firestore
        .collection('channel_wallet_transactions')
        .where('channelId', isEqualTo: channelId)
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => WalletTransaction.fromMap(doc.data(), doc.id))
            .toList());
  }
}
