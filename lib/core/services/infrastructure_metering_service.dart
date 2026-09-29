import 'package:truthworld/data/models/channel.dart';

class CustomChannelPlanTier {
  final String id;
  final String title;
  final double priceUSD;
  final int storageGB;
  final int bandwidthGB;
  final String maxResolution;
  final List<String> features;
  final bool isPopular;

  const CustomChannelPlanTier({
    required this.id,
    required this.title,
    required this.priceUSD,
    required this.storageGB,
    required this.bandwidthGB,
    required this.maxResolution,
    required this.features,
    this.isPopular = false,
  });

  /// TruthWorld platform profit margin (2/3 of plan subscription price = 66.67%)
  double get platformProfitUSD => (priceUSD * 2.0) / 3.0;

  /// Infrastructure cost budget covering storage, CDN, Firestore, and compute (1/3 of plan subscription price = 33.33%)
  double get infraBudgetUSD => priceUSD / 3.0;

  /// Storage cost at tier capacity ($0.02 / GB / month)
  double get storageCostUSD =>
      storageGB * InfrastructureMeteringService.storageCostPerGBMonth;

  /// Bandwidth streaming egress cost at tier capacity ($0.015 / GB)
  double get bandwidthCostUSD =>
      bandwidthGB * InfrastructureMeteringService.bandwidthCostPerGB;

  /// Direct media delivery cost (Cloud Storage + CDN Bandwidth)
  double get deliveryCostUSD => storageCostUSD + bandwidthCostUSD;

  /// Remaining amount of the 1/3 infrastructure budget strictly allocated for other costs
  /// such as Firestore database operations (reads, writes, deletes), Cloud Functions serverless compute,
  /// database indexing, authentication, and search overhead.
  double get firestoreAndOtherCostsUSD =>
      priceUSD <= 0 ? 0.0 : (infraBudgetUSD - deliveryCostUSD).clamp(0.0, double.infinity);

  /// Theoretical infrastructure delivery cost at current tier allocations
  double get estimatedMaxInfraCostUSD => deliveryCostUSD;
}

class InfrastructureMeteringService {
  /// The 2/3 platform profit margin ratio for Custom Channel SaaS subscriptions (66.67%).
  static const double platformProfitMarginRatio = 2.0 / 3.0;

  /// The 1/3 infrastructure cost coverage ratio for Custom Channel SaaS subscriptions (33.33%).
  /// This budget fully covers cloud storage, CDN egress, and all other costs (Firestore operations, Cloud Functions, and DB ops).
  static const double infraCostBudgetRatio = 1.0 / 3.0;

  /// Storage cost per GB per month ($0.02)
  static const double storageCostPerGBMonth = 0.02;

  /// Bandwidth streaming egress cost per GB ($0.015)
  static const double bandwidthCostPerGB = 0.015;

  /// Returns the platform profit margin for a given custom channel plan price (2/3).
  static double getPlanProfitMarginUSD(double planPriceUSD) =>
      (planPriceUSD * 2.0) / 3.0;

  /// Returns the infrastructure budget that covers all delivery & Firestore costs for a given plan price (1/3).
  static double getPlanInfraBudgetUSD(double planPriceUSD) =>
      planPriceUSD / 3.0;

  /// Returns the remaining infrastructure budget for Firestore & backend compute after storage and bandwidth are deducted.
  static double getPlanFirestoreAndOtherCostsUSD({
    required double planPriceUSD,
    required int storageGB,
    required int bandwidthGB,
  }) {
    if (planPriceUSD <= 0) return 0.0;
    final totalInfraBudget = getPlanInfraBudgetUSD(planPriceUSD);
    final deliveryCost = (storageGB * storageCostPerGBMonth) +
        (bandwidthGB * bandwidthCostPerGB);
    return (totalInfraBudget - deliveryCost).clamp(0.0, double.infinity);
  }

  /// Pre-defined Custom Channel Plans ($15, $30, $45, $100, $200, Custom)
  /// Sized strictly so 1/3 of the fee covers all infrastructure and 2/3 is TruthWorld profit margin.
  static const List<CustomChannelPlanTier> availablePlans = [
    CustomChannelPlanTier(
      id: 'starter_15',
      title: 'Starter',
      priceUSD: 15.0,
      storageGB: 50,
      bandwidthGB: 250,
      maxResolution: '1080p',
      features: [
        '0% Platform Commission',
        '50 GB Video Storage',
        '250 GB CDN Streaming Bandwidth',
        'Firestore & Database Operations Included',
        '1080p HD Video Quality',
        '100% Free AI Fact-Checking & Ground-Truth Verification',
        'Direct Creator Payouts',
        'Community Posts & Tipping',
      ],
    ),
    CustomChannelPlanTier(
      id: 'growth_30',
      title: 'Growth',
      priceUSD: 30.0,
      storageGB: 100,
      bandwidthGB: 500,
      maxResolution: '1080p 60fps',
      isPopular: true,
      features: [
        '0% Platform Commission',
        '100 GB Video Storage',
        '500 GB CDN Streaming Bandwidth',
        'Firestore & Database Operations Included',
        '1080p 60fps Ultra Smooth',
        '100% Free AI Fact-Checking & Ground-Truth Verification',
        'Custom Domain Support',
        'Paid Q&A & Priority Reply',
        'Standard Analytics Dashboard',
      ],
    ),
    CustomChannelPlanTier(
      id: 'pro_45',
      title: 'Pro',
      priceUSD: 45.0,
      storageGB: 150,
      bandwidthGB: 750,
      maxResolution: '4K Ultra HD',
      features: [
        '0% Platform Commission',
        '150 GB Storage (~750 hrs)',
        '750 GB (0.75 TB) CDN Bandwidth',
        'Firestore & Database Operations Included',
        '4K Ultra HD HDR Streaming',
        '100% Free AI Fact-Checking & Ground-Truth Verification',
        'Custom Branding & Theme CSS',
        'Advanced Revenue Analytics',
        'Priority Email & Chat Support',
      ],
    ),
    CustomChannelPlanTier(
      id: 'scale_100',
      title: 'Studio',
      priceUSD: 100.0,
      storageGB: 400,
      bandwidthGB: 1600,
      maxResolution: '4K HDR & 8K',
      features: [
        '0% Platform Commission',
        '400 GB Storage (~2,000 hrs)',
        '1,600 GB (1.6 TB) CDN Bandwidth',
        'Firestore & Database Operations Included',
        '4K HDR & 8K Multi-Track Transcoding',
        '100% Free AI Fact-Checking & Ground-Truth Verification',
        'Custom Domain & Brand CSS',
        'VIP 24/7 Priority Support Queue',
      ],
    ),
    CustomChannelPlanTier(
      id: 'premier_200',
      title: 'Premier',
      priceUSD: 200.0,
      storageGB: 800,
      bandwidthGB: 3200,
      maxResolution: '8K Cinema Master',
      features: [
        '0% Platform Commission',
        '800 GB (0.8 TB) Storage (~4,000 hrs)',
        '3,200 GB (3.2 TB) High-Speed CDN Bandwidth',
        'Firestore & Database Operations Included',
        '8K Cinema Master & Dolby Atmos Audio',
        '100% Free AI Fact-Checking & Ground-Truth Verification',
        'Dedicated Fast Transcoding Pipeline',
        '24/7 VIP Dedicated Account Manager',
      ],
    ),
    CustomChannelPlanTier(
      id: 'custom_enterprise',
      title: 'Custom',
      priceUSD: 0.0, // Custom Quote
      storageGB: 1000,
      bandwidthGB: 5000,
      maxResolution: '4K / 8K',
      features: [
        '0% Platform Commission',
        'Unlimited / Custom Storage & Bandwidth',
        'Dedicated Server Node',
        'Firestore & Database Operations Included',
        'Unlimited AI Fact-Checking & Epistemic Verification',
        'White-Label Native iOS & Android App',
        'Custom SLA & 99.99% Uptime',
        '24/7 Dedicated Account Manager',
      ],
    ),
  ];

  /// Estimates actual cloud infrastructure cost based on storage, bandwidth, and other backend costs (Firestore, etc.)
  static double calculateInfraCost({
    required int storageUsedBytes,
    required int bandwidthUsedBytes,
    double estimatedOtherCostsUSD = 0.0,
  }) {
    final storageGB = storageUsedBytes / (1024 * 1024 * 1024);
    final bandwidthGB = bandwidthUsedBytes / (1024 * 1024 * 1024);

    final storageCost = storageGB * storageCostPerGBMonth;
    final bandwidthCost = bandwidthGB * bandwidthCostPerGB;

    return storageCost + bandwidthCost + estimatedOtherCostsUSD;
  }

  /// Evaluates loss-prevention status for a custom channel given current gross revenue and infra cost
  static LossPreventionMode evaluateLossPreventionStatus({
    required double grossRevenue,
    required double currentInfraCost,
  }) {
    if (grossRevenue <= 0 && currentInfraCost > 10.0) {
      // High cost with zero revenue -> auto-scale video resolution to prevent debt
      return LossPreventionMode.autoScaled;
    }

    if (grossRevenue > 0) {
      final costToRevenueRatio = currentInfraCost / grossRevenue;
      if (costToRevenueRatio >= 1.0) {
        return LossPreventionMode.autoScaled;
      } else if (costToRevenueRatio >= 0.8) {
        return LossPreventionMode.warning;
      }
    }

    return LossPreventionMode.active;
  }

  /// Returns max allowed video playback resolution based on loss-prevention mode
  /// TruthWorld Zero-Throttling Guarantee:
  /// Video playback is NEVER degraded or throttled when traffic surges.
  /// TruthWorld covers 100% of all infrastructure costs upfront (even exceeding plan limits),
  /// keeping the stream live at full quality (1080p/4K) while placing a temporary hold
  /// on revenue withdrawals until the creator upgrades their custom plan.
  static String getRecommendedStreamingResolution(LossPreventionMode mode) {
    switch (mode) {
      case LossPreventionMode.suspended:
        return '360p';
      case LossPreventionMode.active:
      case LossPreventionMode.warning:
      case LossPreventionMode.autoScaled:
        return '1080p';
    }
  }

  /// Evaluates whether a custom channel is currently undergoing a viral hype spike or bandwidth strain.
  static bool isHypeSurgeActive({
    required Channel channel,
    required double grossRevenue,
    required double currentInfraCost,
  }) {
    if (channel.channelType != ChannelType.custom) return false;

    final infra = channel.infraConfig;
    final usedBytes = infra?.bandwidthUsedBytesThisMonth ?? 0;
    final quotaBytes = infra?.bandwidthQuotaBytesThisMonth ?? (100 * 1024 * 1024 * 1024);
    final mode = infra?.lossPreventionMode ?? LossPreventionMode.active;

    final currentPlanTier = infra?.planTier ?? 'starter_15';
    final plan = availablePlans.firstWhere(
      (p) => p.id == currentPlanTier,
      orElse: () => availablePlans.first,
    );

    final isBandwidthStrained = quotaBytes > 0 && (usedBytes >= (quotaBytes * 0.75));
    final isLossPreventionEngaged =
        mode == LossPreventionMode.warning || mode == LossPreventionMode.autoScaled;
    final isInfraCostSurging = currentInfraCost >= (plan.infraBudgetUSD * 0.9);
    final isOverQuota = quotaBytes > 0 && usedBytes > quotaBytes;
    final isOverBudget = plan.infraBudgetUSD > 0 && currentInfraCost > plan.infraBudgetUSD;
    final isHeld = infra?.isWithdrawalHeld == true;

    return isBandwidthStrained ||
        isLossPreventionEngaged ||
        isInfraCostSurging ||
        isOverQuota ||
        isOverBudget ||
        isHeld;
  }

  /// Finds the recommended plan upgrade tier to comfortably cover the hype surge bandwidth.
  static CustomChannelPlanTier getRecommendedSurgeUpgradePlan({
    required Channel channel,
    required int bandwidthUsedBytes,
  }) {
    final currentPlanId = channel.infraConfig?.planTier ?? 'starter_15';
    final currentIndex = availablePlans.indexWhere((p) => p.id == currentPlanId);

    // Provide at least 20% headroom over current surge consumption
    final targetBytes = (bandwidthUsedBytes * 1.2).toInt();

    for (var i = currentIndex >= 0 ? currentIndex + 1 : 0; i < availablePlans.length; i++) {
      final plan = availablePlans[i];
      if (plan.id == 'custom_enterprise') continue;
      final planBandwidthBytes = plan.bandwidthGB * 1024 * 1024 * 1024;
      if (planBandwidthBytes >= targetBytes) {
        return plan;
      }
    }

    if (currentPlanId == 'starter_15') {
      return availablePlans.firstWhere(
        (p) => p.id == 'growth_30',
        orElse: () => availablePlans[1],
      );
    }
    return availablePlans.firstWhere(
      (p) => p.id == 'pro_45',
      orElse: () => availablePlans.last,
    );
  }

  /// Aggregates all revenue streams (100% creator retention) and computes hype surge metrics.
  static HypeSurgeSummary computeHypeSurgeSummary({
    required Channel channel,
    required double adRevenue,
    required double premiumSubRevenue,
    required double membershipsRevenue,
    required double tipsRevenue,
  }) {
    final infra = channel.infraConfig;
    final storageBytes = infra?.storageUsedBytes ?? 0;
    final bandwidthBytes = infra?.bandwidthUsedBytesThisMonth ?? 0;
    final quotaBytes = infra?.bandwidthQuotaBytesThisMonth ?? (100 * 1024 * 1024 * 1024);

    final grossTotalRevenue =
        adRevenue + premiumSubRevenue + membershipsRevenue + tipsRevenue;
    final infraCost = calculateInfraCost(
      storageUsedBytes: storageBytes,
      bandwidthUsedBytes: bandwidthBytes,
    );

    final lossMode = (infra?.lossPreventionMode != null &&
            infra!.lossPreventionMode != LossPreventionMode.active)
        ? infra.lossPreventionMode
        : evaluateLossPreventionStatus(
            grossRevenue: grossTotalRevenue,
            currentInfraCost: infraCost,
          );

    final currentPlanId = infra?.planTier ?? 'starter_15';
    final currentPlan = availablePlans.firstWhere(
      (p) => p.id == currentPlanId,
      orElse: () => availablePlans.first,
    );

    final recommendedUpgrade = getRecommendedSurgeUpgradePlan(
      channel: channel,
      bandwidthUsedBytes: bandwidthBytes,
    );

    final isSurge = isHypeSurgeActive(
      channel: channel,
      grossRevenue: grossTotalRevenue,
      currentInfraCost: infraCost,
    );

    final isCovered = grossTotalRevenue >= recommendedUpgrade.priceUSD;
    final netWithdrawable =
        (grossTotalRevenue - recommendedUpgrade.priceUSD).clamp(0.0, double.infinity);

    final isOverQuota = quotaBytes > 0 && bandwidthBytes > quotaBytes;
    final isOverBudget = currentPlan.infraBudgetUSD > 0 && infraCost > currentPlan.infraBudgetUSD;
    final isWithdrawalHeld = infra?.isWithdrawalHeld == true || isOverQuota || isOverBudget;
    final holdReason = (infra?.withdrawalHoldReason != null && infra!.withdrawalHoldReason.isNotEmpty)
        ? infra.withdrawalHoldReason
        : (isWithdrawalHeld
            ? 'TruthWorld has fronted and paid 100% of your viral infrastructure surge costs. Withdrawals are on hold until you upgrade to ${recommendedUpgrade.title} (\$${recommendedUpgrade.priceUSD.toStringAsFixed(0)}/mo) to cover the surge bandwidth.'
            : '');

    return HypeSurgeSummary(
      adRevenue: adRevenue,
      premiumSubRevenue: premiumSubRevenue,
      membershipsRevenue: membershipsRevenue,
      tipsRevenue: tipsRevenue,
      grossTotalRevenue: grossTotalRevenue,
      storageUsedBytes: storageBytes,
      bandwidthUsedBytes: bandwidthBytes,
      bandwidthQuotaBytes: quotaBytes,
      currentInfraCost: infraCost,
      lossPreventionMode: lossMode,
      currentPlan: currentPlan,
      recommendedUpgradePlan: recommendedUpgrade,
      netWithdrawableAfterUpgrade: netWithdrawable,
      isHypeSurgeActive: isSurge,
      isCoveredByRevenue: isCovered,
      isWithdrawalHeld: isWithdrawalHeld,
      withdrawalHoldReason: holdReason,
    );
  }
}

/// Encapsulates the financial and infrastructural status of a custom channel during a sudden hype surge.
class HypeSurgeSummary {
  final double adRevenue;
  final double premiumSubRevenue;
  final double membershipsRevenue;
  final double tipsRevenue;
  final double grossTotalRevenue;
  final int storageUsedBytes;
  final int bandwidthUsedBytes;
  final int bandwidthQuotaBytes;
  final double currentInfraCost;
  final LossPreventionMode lossPreventionMode;
  final CustomChannelPlanTier currentPlan;
  final CustomChannelPlanTier recommendedUpgradePlan;
  final double netWithdrawableAfterUpgrade;
  final bool isHypeSurgeActive;
  final bool isCoveredByRevenue;
  final bool isWithdrawalHeld;
  final String withdrawalHoldReason;

  const HypeSurgeSummary({
    required this.adRevenue,
    required this.premiumSubRevenue,
    required this.membershipsRevenue,
    required this.tipsRevenue,
    required this.grossTotalRevenue,
    required this.storageUsedBytes,
    required this.bandwidthUsedBytes,
    required this.bandwidthQuotaBytes,
    required this.currentInfraCost,
    required this.lossPreventionMode,
    required this.currentPlan,
    required this.recommendedUpgradePlan,
    required this.netWithdrawableAfterUpgrade,
    required this.isHypeSurgeActive,
    required this.isCoveredByRevenue,
    this.isWithdrawalHeld = false,
    this.withdrawalHoldReason = '',
  });

  double get bandwidthUsedGB => bandwidthUsedBytes / (1024 * 1024 * 1024);
  double get bandwidthQuotaGB => bandwidthQuotaBytes / (1024 * 1024 * 1024);
  double get storageUsedGB => storageUsedBytes / (1024 * 1024 * 1024);
  double get bandwidthUsagePercent =>
      bandwidthQuotaBytes > 0 ? (bandwidthUsedBytes / bandwidthQuotaBytes).clamp(0.0, 5.0) : 1.0;
}
