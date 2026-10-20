import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/ai_languages.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/cashfree_service.dart';
import 'package:truthworld/core/services/channel_wallet_pricing.dart';
import 'package:truthworld/core/services/currency_localization_service.dart';
import 'package:truthworld/core/services/infrastructure_metering_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/data/models/channel_wallet_models.dart';

// Re-export models and pricing for 100% backward compatibility
export 'package:truthworld/core/services/channel_wallet_pricing.dart';
export 'package:truthworld/data/models/channel_wallet_models.dart';

class ChannelWalletService {
  final FirebaseFirestore? _firestoreInstance;
  FirebaseFirestore get _firestore => _firestoreInstance ?? FirebaseFirestore.instance;
  final FirebaseFunctions? _functionsInstance;
  FirebaseFunctions get _functions => _functionsInstance ?? FirebaseFunctions.instanceFor(region: 'asia-south1');

  ChannelWalletService({FirebaseFirestore? firestore, FirebaseFunctions? functions})
    : _firestoreInstance = firestore,
      _functionsInstance = functions;

  // =========================================================================
  // DELEGATED PRICING CATALOGS & CALCULATIONS (Backed by ChannelWalletPricing)
  // =========================================================================
  static const List<StorageTopupPack> storagePacks = ChannelWalletPricing.storagePacks;
  static const List<BandwidthTopupPack> bandwidthPacks = ChannelWalletPricing.bandwidthPacks;
  static const List<DubbingDurationTier> dubbingDurationTiers = ChannelWalletPricing.dubbingDurationTiers;
  static const List<SubtitleDurationTier> subtitleDurationTiers = ChannelWalletPricing.subtitleDurationTiers;
  static const List<FactCheckDurationTier> factCheckDurationTiers = ChannelWalletPricing.factCheckDurationTiers;
  static const List<FactCheckDepthPlan> factCheckDepthPlans = ChannelWalletPricing.factCheckDepthPlans;
  static const List<ChannelFactCheckAddonTier> channelFactCheckPlans = ChannelWalletPricing.channelFactCheckPlans;

  static const double standardDubbingRatePerLanguage = ChannelWalletPricing.standardDubbingRatePerLanguage;
  static const double standardDubbingMinCost = ChannelWalletPricing.standardDubbingMinCost;
  static const double standardDubbingCapCost = ChannelWalletPricing.standardDubbingCapCost;
  static const double customDubbingRatePerLanguage = ChannelWalletPricing.customDubbingRatePerLanguage;
  static const double customDubbingMinCost = ChannelWalletPricing.customDubbingMinCost;
  static const double customDubbingCapCost = ChannelWalletPricing.customDubbingCapCost;
  static const double standardSubtitleRatePerLanguage = ChannelWalletPricing.standardSubtitleRatePerLanguage;
  static const double customSubtitleRatePerLanguage = ChannelWalletPricing.customSubtitleRatePerLanguage;
  static const double standardSubtitleMinCost = ChannelWalletPricing.standardSubtitleMinCost;
  static const double customSubtitleMinCost = ChannelWalletPricing.customSubtitleMinCost;
  static const double standardSubtitleCapCost = ChannelWalletPricing.standardSubtitleCapCost;
  static const double customSubtitleCapCost = ChannelWalletPricing.customSubtitleCapCost;
  static const double standardFactCheckBaseCost = ChannelWalletPricing.standardFactCheckBaseCost;
  static const double customFactCheckBaseCost = ChannelWalletPricing.customFactCheckBaseCost;

  static double getFlatDubbingPricePerLanguage({
    required int durationSeconds,
    ChannelType channelType = ChannelType.standard,
  }) => ChannelWalletPricing.getFlatDubbingPricePerLanguage(
    durationSeconds: durationSeconds,
    channelType: channelType,
  );

  static DubbingDurationTier getDubbingDurationTier(int durationSeconds) =>
      ChannelWalletPricing.getDubbingDurationTier(durationSeconds);

  static double getDubbingRatePerLanguage(ChannelType type) =>
      ChannelWalletPricing.getDubbingRatePerLanguage(type);

  static double getDubbingMinCost(ChannelType type) =>
      ChannelWalletPricing.getDubbingMinCost(type);

  static double getDubbingCapCost(ChannelType type) =>
      ChannelWalletPricing.getDubbingCapCost(type);

  static double calculateDubbingCost({
    required int languageCount,
    ChannelType channelType = ChannelType.standard,
    int durationSeconds = 0,
  }) => ChannelWalletPricing.calculateDubbingCost(
    languageCount: languageCount,
    channelType: channelType,
    durationSeconds: durationSeconds,
  );

  static double getFlatSubtitlePricePerLanguage({
    required ChannelType channelType,
    int durationSeconds = 0,
  }) => ChannelWalletPricing.getFlatSubtitlePricePerLanguage(
    channelType: channelType,
    durationSeconds: durationSeconds,
  );

  static SubtitleDurationTier getSubtitleDurationTier(int durationSeconds) =>
      ChannelWalletPricing.getSubtitleDurationTier(durationSeconds);

  static double calculateSubtitleCost({
    required int languageCount,
    ChannelType channelType = ChannelType.standard,
    int durationSeconds = 0,
  }) => ChannelWalletPricing.calculateSubtitleCost(
    languageCount: languageCount,
    channelType: channelType,
    durationSeconds: durationSeconds,
  );

  static FactCheckDepthPlan getFactCheckDepthPlan(String id) =>
      ChannelWalletPricing.getFactCheckDepthPlan(id);

  static double getFlatFactCheckPrice({
    int durationSeconds = 0,
    ChannelType channelType = ChannelType.standard,
    String tierType = 'full_ground',
  }) => ChannelWalletPricing.getFlatFactCheckPrice(
    durationSeconds: durationSeconds,
    channelType: channelType,
    tierType: tierType,
  );

  static FactCheckDurationTier getFactCheckDurationTier(int durationSeconds) =>
      ChannelWalletPricing.getFactCheckDurationTier(durationSeconds);

  static double calculateFactCheckCost({
    int durationSeconds = 0,
    ChannelType channelType = ChannelType.standard,
    String tierType = 'standard',
  }) => ChannelWalletPricing.calculateFactCheckCost(
    durationSeconds: durationSeconds,
    channelType: channelType,
    tierType: tierType,
  );

  static double calculateAIFeatureCost({
    required Set<String> selectedFeatures,
    required List<String> targetLanguages,
    ChannelType channelType = ChannelType.standard,
    int durationSeconds = 0,
    String factCheckTier = 'standard',
  }) => ChannelWalletPricing.calculateAIFeatureCost(
    selectedFeatures: selectedFeatures,
    targetLanguages: targetLanguages,
    channelType: channelType,
    durationSeconds: durationSeconds,
    factCheckTier: factCheckTier,
  );

  SpendableBalance getSpendableBalance({
    required Channel channel,
    double rawTotalRevenue = 0.0,
    double withdrawableRevenue = 0.0,
    double lockedRevenue = 0.0,
  }) {
    final rollover = channel.infraConfig?.rolloverCreditUSD ?? 0.0;
    final funded = channel.walletBalanceUSD;
    final withdrawable = withdrawableRevenue > 0
        ? withdrawableRevenue
        : (rawTotalRevenue * 0.5);
    final locked = lockedRevenue > 0
        ? lockedRevenue
        : (rawTotalRevenue - withdrawable).clamp(0.0, double.infinity);

    return SpendableBalance(
      fundedBalance: funded,
      rolloverCredit: rollover,
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
    if (amount <= 0) {
      ErrorHandler.log(
        ArgumentError('spendBalance: amount must be positive, got $amount'),
        stackTrace: StackTrace.current,
        tag: 'ChannelWalletService.spendBalance',
      );
      return null;
    }

    final balance = customBalance ?? getSpendableBalance(channel: channel);

    if (!balance.canAfford(amount)) {
      debugPrint('[ChannelWalletService] Insufficient balance for spend: required \$$amount, available \$${balance.totalSpendableBalance}');
      return null;
    }

    final balanceBefore = balance.totalSpendableBalance;

    // Determine breakdown of deduction:
    // 1. Rollover credits first (Zero-Waste Policy: unspent plan money utilized first)
    // 2. Funded wallet balance second
    // 3. Unwithdrawn revenue third
    var remaining = amount;

    var rolloverDeduction = 0.0;
    if (remaining > 0 && balance.rolloverCredit > 0) {
      rolloverDeduction = math.min(balance.rolloverCredit, remaining);
      remaining -= rolloverDeduction;
    }

    var fundedDeduction = 0.0;
    if (remaining > 0 && balance.fundedBalance > 0) {
      fundedDeduction = math.min(balance.fundedBalance, remaining);
      remaining -= fundedDeduction;
    }

    final revenueDeduction = remaining;

    final newRolloverRemaining = (balance.rolloverCredit - rolloverDeduction).clamp(0.0, 1000000.0);
    final newFundedBalance = (balance.fundedBalance - fundedDeduction).clamp(0.0, 1000000.0);
    final balanceAfter = balanceBefore - amount;

    final txDocRef = _firestore.collection('channel_wallet_transactions').doc();
    final transaction = WalletTransaction(
      id: txDocRef.id,
      channelId: channel.id,
      userId: userId,
      amount: amount,
      trialCreditDeducted: 0.0,
      rolloverDeducted: rolloverDeduction,
      fundedDeducted: fundedDeduction,
      revenueDeducted: revenueDeduction,
      category: category,
      description: description,
      balanceBefore: balanceBefore,
      balanceAfter: balanceAfter,
      timestamp: DateTime.now(),
      metadata: metadata,
    );

    // 1. Authoritative server-side atomic execution via Cloud Function
    try {
      final callable = _functions.httpsCallable('spendChannelWallet');
      final resp = await callable.call<dynamic>({
        'channelId': channel.id,
        'amount': amount,
        'category': category.name,
        'description': description,
        'metadata': metadata ?? {},
      });

      if (resp.data is Map) {
        final data = Map<String, dynamic>.from(resp.data as Map);
        return WalletTransaction(
          id: (data['transactionId'] as String?) ?? txDocRef.id,
          channelId: channel.id,
          userId: userId,
          amount: amount,
          trialCreditDeducted: 0.0,
          rolloverDeducted: (data['rolloverDeducted'] as num?)?.toDouble() ?? rolloverDeduction,
          fundedDeducted: (data['fundedDeducted'] as num?)?.toDouble() ?? fundedDeduction,
          revenueDeducted: (data['revenueDeducted'] as num?)?.toDouble() ?? revenueDeduction,
          category: category,
          description: description,
          balanceBefore: (data['balanceBefore'] as num?)?.toDouble() ?? balanceBefore,
          balanceAfter: (data['balanceAfter'] as num?)?.toDouble() ?? balanceAfter,
          timestamp: DateTime.fromMillisecondsSinceEpoch(
            (data['timestamp'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
          ),
          metadata: metadata,
        );
      }
    } catch (callableError, callableTrace) {
      // In offline / mock test environments where Cloud Functions are not active or throw,
      // fallback to atomic transaction via _firestore.runTransaction
      ErrorHandler.log(
        callableError,
        stackTrace: callableTrace,
        tag: 'ChannelWalletService.spendBalance.callableFallback',
      );
    }

    // 2. Atomic Firestore transaction fallback (offline/testing)
    try {
      final existingInfra = channel.infraConfig ?? CustomChannelInfraConfig(
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
        rolloverCreditUSD: newRolloverRemaining,
        planTier: existingInfra.planTier,
        lossPreventionMode: existingInfra.lossPreventionMode,
      );

      final updateData = <String, dynamic>{
        'infraConfig': updatedInfra.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (fundedDeduction > 0) {
        updateData['walletBalanceUSD'] = newFundedBalance;
        updateData['walletBalance'] = newFundedBalance;
      }

      if (revenueDeduction > 0) {
        // Anti-double-spend: unwithdrawn revenue spent on plans/tools is accounted into withdrawnRevenueTotal
        final deductionINR = revenueDeduction * 84.0;
        updateData['withdrawnRevenueTotal'] = FieldValue.increment(deductionINR);
      }

      await _firestore.runTransaction((batchTx) async {
        final channelDocRef = _firestore.collection(FirestoreCollections.channels).doc(channel.id);
        batchTx.set(txDocRef, transaction.toMap());
        batchTx.update(channelDocRef, updateData);
      });

      return transaction;
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'ChannelWalletService.spendBalance',
      );
      return null; // Return null on failure so caller does not proceed as if spend succeeded
    }
  }

  /// Zero-Waste Policy Execution:
  /// When a monthly billing cycle closes:
  /// If a custom channel took a $15 plan and spent only $5 on infra/features,
  /// the remaining $10 is NEVER reset to $0 or wasted.
  /// It is preserved down to the exact cent into `rolloverCreditUSD` for the next cycle.
  Future<double> rolloverUnspentPlanBalance({
    required Channel channel,
    double actualInfraCost = 0.0,
  }) async {
    final infra = channel.infraConfig;
    if (channel.channelType != ChannelType.custom || infra == null) {
      return 0.0;
    }

    final planBudget = infra.flatPlatformFee > 0 ? infra.flatPlatformFee : 15.0;
    final cost = actualInfraCost > 0 ? actualInfraCost : infra.currentMonthInfraCost;
    final unspent = (planBudget - cost).clamp(0.0, planBudget);

    if (unspent <= 0.0) return 0.0;

    final newRolloverTotal = double.parse(
      (infra.rolloverCreditUSD + unspent).toStringAsFixed(2),
    );

    final updatedInfra = CustomChannelInfraConfig(
      subscriptionId: infra.subscriptionId,
      stripeConnectAccountId: infra.stripeConnectAccountId,
      storageUsedBytes: infra.storageUsedBytes,
      storageQuotaBytes: infra.storageQuotaBytes,
      bandwidthQuotaBytesThisMonth: infra.bandwidthQuotaBytesThisMonth,
      flatPlatformFee: infra.flatPlatformFee,
      rolloverCreditUSD: newRolloverTotal,
      planTier: infra.planTier,
      autoPay: infra.autoPay,
    );

    try {
      await _firestore
          .collection(FirestoreCollections.channels)
          .doc(channel.id)
          .update({
            'infraConfig': updatedInfra.toMap(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      // Record rollover transaction in Firestore ledger for transparent audit
      final txDocRef = _firestore.collection('channel_wallet_transactions').doc();
      final tx = WalletTransaction(
        id: txDocRef.id,
        channelId: channel.id,
        userId: channel.ownerId,
        amount: unspent,
        trialCreditDeducted: 0.0,
        revenueDeducted: 0.0,
        category: WalletTransactionCategory.walletTopup,
        description: 'Zero-Waste Rollover: \$${unspent.toStringAsFixed(2)} unspent plan balance rolled over to next month (0 cents wasted).',
        balanceBefore: infra.rolloverCreditUSD,
        balanceAfter: newRolloverTotal,
        timestamp: DateTime.now(),
        metadata: {
          'type': 'zero_waste_rollover',
          'planFee': planBudget,
          'actualSpent': cost,
          'unspentPreserved': unspent,
        },
      );
      await txDocRef.set(tx.toMap());
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'ChannelWalletService.rolloverUnspentPlanBalance',
      );
    }

    return unspent;
  }

  /// Spend balance to upgrade or renew a Custom Channel Tier Plan
  Future<bool> spendForCustomPlan({
    required Channel channel,
    required String userId,
    required String planTier,
    required double priceUSD,
    bool autoPay = true,
  }) async {
    final tx = await spendBalance(
      channel: channel,
      userId: userId,
      amount: priceUSD,
      category: WalletTransactionCategory.customChannelPlan,
      description: 'Custom Channel Tier Subscription: ${planTier.toUpperCase()}',
      metadata: {'planTier': planTier, 'priceUSD': priceUSD, 'autoPay': autoPay},
    );

    if (tx == null) return false;
    // Server-side spendChannelWallet Cloud Function has atomically applied channelType & infraConfig quotas
    return true;
  }

  /// Buy Custom Channel Tier Plan directly via Cashfree PG
  Future<bool> buyCustomPlanWithCashfree({
    required Channel channel,
    required CustomChannelPlanTier plan,
    required bool autoPay,
  }) async {
    try {
      await CurrencyLocalizationService.to.fetchRealtimeRate();
      final rate = Get.isRegistered<CurrencyLocalizationService>()
          ? CurrencyLocalizationService.to.rate
          : CurrencyLocalizationService.defaultRate;
      final isIndian = !Get.isRegistered<CurrencyLocalizationService>() ||
          CurrencyLocalizationService.to.isIndianUser;
      final currency = isIndian ? 'INR' : 'USD';
      final chargeAmount = isIndian
          ? math.max(1.0, double.parse((plan.priceUSD * rate).toStringAsFixed(2)))
          : plan.priceUSD;
      final autoPaySuffix = autoPay ? ' (Auto Pay)' : ' (One-Time)';
      final paymentResult = await CashfreePaymentService.to.startPayment(
        amount: chargeAmount,
        currency: currency,
        purpose: 'custom_channel_plan',
        orderNote: 'Custom Channel Plan$autoPaySuffix: ${plan.title}',
        metadata: {
          'channelId': channel.id,
          'planTier': plan.id,
          'priceUSD': plan.priceUSD,
          'currency': currency,
          'chargeAmount': chargeAmount,
          'autoPay': autoPay,
          'billingType': autoPay ? 'recurring' : 'one_time',
          'category': 'customChannelPlan',
          'description': 'Custom Channel Plan via Cashfree: ${plan.title}',
        },
      );

      // Server-side fulfillOrder webhook handles the channelType and infraConfig quota upgrades
      return paymentResult.success;
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'ChannelWalletService.buyCustomPlanWithCashfree',
      );
      return false;
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
    // Server-side spendChannelWallet Cloud Function has atomically incremented storageQuotaBytes
    return true;
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
    // Server-side spendChannelWallet Cloud Function has atomically incremented bandwidthQuotaBytesThisMonth
    return true;
  }

  /// Buy Storage pack directly via Cashfree PG
  Future<bool> buyStoragePackWithCashfree({
    required Channel channel,
    required StorageTopupPack pack,
  }) async {
    try {
      await CurrencyLocalizationService.to.fetchRealtimeRate();
      final rate = Get.isRegistered<CurrencyLocalizationService>()
          ? CurrencyLocalizationService.to.rate
          : CurrencyLocalizationService.defaultRate;
      final isIndian = !Get.isRegistered<CurrencyLocalizationService>() ||
          CurrencyLocalizationService.to.isIndianUser;
      final currency = isIndian ? 'INR' : 'USD';
      final chargeAmount = isIndian
          ? math.max(1.0, double.parse((pack.priceUSD * rate).toStringAsFixed(2)))
          : pack.priceUSD;
      final paymentResult = await CashfreePaymentService.to.startPayment(
        amount: chargeAmount,
        currency: currency,
        purpose: 'channel_topup',
        orderNote: 'Storage Top-Up: ${pack.title}',
        metadata: {
          'channelId': channel.id,
          'packType': 'storage',
          'gigabytes': pack.gigabytes,
          'category': 'storageTopup',
          'description': 'Storage Add-on via Cashfree: ${pack.title}',
          'currency': currency,
          'chargeAmount': chargeAmount,
        },
      );

      if (paymentResult.success) {
        // Quota is incremented authoritatively by backend fulfillOrder transaction
        return true;
      }
      return false;
    } catch (e, stackTrace) {
      ErrorHandler.log(e, stackTrace: stackTrace, tag: 'ChannelWalletService.buyStoragePackWithCashfree');
      return false;
    }
  }

  /// Buy Bandwidth pack directly via Cashfree PG
  Future<bool> buyBandwidthPackWithCashfree({
    required Channel channel,
    required BandwidthTopupPack pack,
  }) async {
    try {
      await CurrencyLocalizationService.to.fetchRealtimeRate();
      final rate = Get.isRegistered<CurrencyLocalizationService>()
          ? CurrencyLocalizationService.to.rate
          : CurrencyLocalizationService.defaultRate;
      final isIndian = !Get.isRegistered<CurrencyLocalizationService>() ||
          CurrencyLocalizationService.to.isIndianUser;
      final currency = isIndian ? 'INR' : 'USD';
      final chargeAmount = isIndian
          ? math.max(1.0, double.parse((pack.priceUSD * rate).toStringAsFixed(2)))
          : pack.priceUSD;
      final paymentResult = await CashfreePaymentService.to.startPayment(
        amount: chargeAmount,
        currency: currency,
        purpose: 'channel_topup',
        orderNote: 'Bandwidth Top-Up: ${pack.title}',
        metadata: {
          'channelId': channel.id,
          'packType': 'bandwidth',
          'gigabytes': pack.gigabytes,
          'category': 'bandwidthTopup',
          'description': 'Bandwidth Add-on via Cashfree: ${pack.title}',
          'currency': currency,
          'chargeAmount': chargeAmount,
        },
      );

      if (paymentResult.success) {
        // Quota is incremented authoritatively by backend fulfillOrder transaction
        return true;
      }
      return false;
    } catch (e, stackTrace) {
      ErrorHandler.log(e, stackTrace: stackTrace, tag: 'ChannelWalletService.buyBandwidthPackWithCashfree');
      return false;
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
    int durationSeconds = 0,
    String priorityMode = 'accuracy',
    bool autoChapters = true,
    String factCheckTier = 'standard',
  }) async {
    final cost = calculateAIFeatureCost(
      selectedFeatures: features,
      targetLanguages: targetLanguages,
      channelType: channel.channelType,
      durationSeconds: durationSeconds,
      factCheckTier: factCheckTier,
    );

    var category = WalletTransactionCategory.aiBundle;
    if (features.length == 1) {
      if (features.contains('subtitles')) category = WalletTransactionCategory.aiSubtitles;
      if (features.contains('dubbing')) category = WalletTransactionCategory.aiDubbing;
      if (features.contains('factcheck')) category = WalletTransactionCategory.aiFactcheck;
      if (features.contains('chapters')) {
        category = WalletTransactionCategory.aiSummaryChapters;
      }
    }

    final flatRate = durationSeconds > 0
        ? getFlatDubbingPricePerLanguage(
            durationSeconds: durationSeconds,
            channelType: channel.channelType,
          )
        : getDubbingRatePerLanguage(channel.channelType);

    final tx = await spendBalance(
      channel: channel,
      userId: userId,
      amount: cost,
      category: category,
      description: 'AI Processing for "$videoTitle" (${features.join(", ")})',
      metadata: {
        'videoId': videoId,
        'channelType': channel.channelType.name,
        'features': features.toList(),
        'targetLanguages': targetLanguages,
        'durationSeconds': durationSeconds,
        'factCheckTier': factCheckTier,
        'priorityMode': priorityMode,
        'costUSD': cost,
        'flatDubbingRatePerLanguage': flatRate,
        'voiceCloneIncluded': channel.channelType == ChannelType.custom,
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
          'durationSeconds': durationSeconds,
          'flatDubbingCostUSD': features.contains('dubbing')
              ? calculateDubbingCost(
                  languageCount:
                      targetLanguages.where(isDubbingSupported).length,
                  durationSeconds: durationSeconds,
                  channelType: channel.channelType,
                )
              : 0.0,
          'enablePath1': features.contains('factcheck'),
          'enablePath2': features.contains('dubbing') || features.contains('subtitles'),
          'autoChapters': autoChapters,
          'priorityMode': priorityMode,
          'channelType': channel.channelType.name,
          'dubbingMode': channel.channelType == ChannelType.custom ? 'voice_clone' : 'standard',
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
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'ChannelWalletService.spendForVideoAIFeatures',
      );
      return true;
    }
  }

  /// Fetches spendable balance for a channel by channel ID
  Future<SpendableBalance> getSpendableBalanceForChannelId(String channelId) async {
    try {
      final doc = await _firestore.collection(FirestoreCollections.channels).doc(channelId).get();
      if (!doc.exists || doc.data() == null) {
        return const SpendableBalance(
          withdrawableRevenue: 0,
          lockedRevenue: 0,
        );
      }
      final channel = Channel.fromMap(doc.data()!, channelId);
      return getSpendableBalance(channel: channel);
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'ChannelWalletService.getSpendableBalanceForChannelId',
      );
      return const SpendableBalance(
        withdrawableRevenue: 0,
        lockedRevenue: 0,
      );
    }
  }

  /// Top up channel wallet with funded money via Cashfree PG
  Future<bool> topupChannelWalletWithCashfree({
    required Channel channel,
    required double amountUSD,
    required String userId,
  }) async {
    try {
      await CurrencyLocalizationService.to.fetchRealtimeRate();
      final rate = Get.isRegistered<CurrencyLocalizationService>()
          ? CurrencyLocalizationService.to.rate
          : CurrencyLocalizationService.defaultRate;
      final isIndian = !Get.isRegistered<CurrencyLocalizationService>() ||
          CurrencyLocalizationService.to.isIndianUser;
      final currency = isIndian ? 'INR' : 'USD';
      final amountINR = math.max(1.0, double.parse((amountUSD * rate).toStringAsFixed(2)));
      final chargeAmount = isIndian ? amountINR : amountUSD;

      final paymentResult = await CashfreePaymentService.to.startPayment(
        amount: chargeAmount,
        currency: currency,
        purpose: 'channel_wallet_topup',
        orderNote: 'Channel Wallet Top-Up (${isIndian ? '₹$amountINR' : '\$${amountUSD.toStringAsFixed(2)}'})',
        metadata: {
          'channelId': channel.id,
          'amountUSD': amountUSD,
          'amountINR': amountINR,
          'currency': currency,
          'chargeAmount': chargeAmount,
          'packType': 'balance',
          'category': 'walletTopup',
          'description': 'Channel Wallet Deposit (+${isIndian ? '₹$amountINR' : '\$${amountUSD.toStringAsFixed(2)}'})',
        },
      );

      if (paymentResult.success) {
        // NOTE: Server-side fulfillOrder webhook handles the wallet balance increment.
        // We do NOT call topupChannelWalletDirect here to avoid duplicate credit.
        return true;
      }
      return false;
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'ChannelWalletService.topupChannelWalletWithCashfree',
      );
      return false;
    }
  }

  /// Directly increments channel wallet balance in Firestore and records a transaction
  Future<WalletTransaction?> topupChannelWalletDirect({
    required String channelId,
    required String userId,
    required double amountUSD,
    String? orderId,
    String? description,
  }) async {
    try {
      final txDocRef = orderId != null && orderId.isNotEmpty
          ? _firestore.collection('channel_wallet_transactions').doc(orderId)
          : _firestore.collection('channel_wallet_transactions').doc();

      final channelDocRef = _firestore.collection(FirestoreCollections.channels).doc(channelId);
      final channelSnapshot = await channelDocRef.get();
      final currentBalance = (channelSnapshot.data()?['walletBalanceUSD'] as num?)?.toDouble() ??
          (channelSnapshot.data()?['walletBalance'] as num?)?.toDouble() ??
          0.0;
      final newBalance = currentBalance + amountUSD;

      final transaction = WalletTransaction(
        id: txDocRef.id,
        channelId: channelId,
        userId: userId,
        amount: amountUSD,
        trialCreditDeducted: 0.0,
        revenueDeducted: 0.0,
        category: WalletTransactionCategory.walletTopup,
        description: description ?? 'Wallet Deposit (+\$${amountUSD.toStringAsFixed(2)})',
        balanceBefore: currentBalance,
        balanceAfter: newBalance,
        timestamp: DateTime.now(),
        metadata: {
          'amountUSD': amountUSD,
          'orderId': ?orderId,
        },
      );

      await _firestore.runTransaction((batchTx) async {
        batchTx.set(txDocRef, transaction.toMap());
        batchTx.update(channelDocRef, {
          'walletBalanceUSD': FieldValue.increment(amountUSD),
          'walletBalance': FieldValue.increment(amountUSD),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      return transaction;
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'ChannelWalletService.topupChannelWalletDirect',
      );
      return null;
    }
  }

  /// Streams recent wallet spend transactions for a channel.
  /// Scopes query with [userId] (or [AuthService.to.uid]) when available to satisfy Firestore security rules.
  Stream<List<WalletTransaction>> streamChannelTransactions(
    String channelId, {
    String? userId,
  }) {
    var query = _firestore
        .collection('channel_wallet_transactions')
        .where('channelId', isEqualTo: channelId);

    final resolvedUserId = userId ??
        (Get.isRegistered<AuthService>() ? AuthService.to.uid : null);
    if (resolvedUserId != null && resolvedUserId.isNotEmpty) {
      query = query.where('userId', isEqualTo: resolvedUserId);
    }

    return query
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => WalletTransaction.fromMap(doc.data(), doc.id))
            .toList());
  }
}
