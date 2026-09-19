import 'dart:math';
import 'package:truthworld/data/models/channel.dart';

class ChannelPayoutBreakdown {
  ChannelPayoutBreakdown({
    required this.grossRevenue,
    required this.creatorPayout,
    required this.platformShare,
    required this.infraCostDeducted,
    required this.flatServiceFeeDeducted,
    required this.isZeroDebtProtected,
  });
  final double grossRevenue;
  final double creatorPayout;
  final double platformShare;
  final double infraCostDeducted;
  final double flatServiceFeeDeducted;
  final bool isZeroDebtProtected;
}

class VideoWithdrawalEligibility {
  final String videoId;
  final double totalEarnedRevenue;
  final int watchTimeMinutes;
  final bool isUnlockedForWithdrawal;
  final double withdrawableAmount;
  final double pendingLockedAmount;

  const VideoWithdrawalEligibility({
    required this.videoId,
    required this.totalEarnedRevenue,
    required this.watchTimeMinutes,
    required this.isUnlockedForWithdrawal,
    required this.withdrawableAmount,
    required this.pendingLockedAmount,
  });
}

class ChannelPayoutCalculator {
  /// Standard Channel video withdrawal threshold: 10 Hours (600 mins) of watch time per video
  static const int standardChannelWithdrawalWatchTimeMinutesThreshold =
      600; // 10 Hours

  /// Calculates revenue payout for a Standard Channel:
  /// - Ad Revenue: 70% Creator / 30% Platform
  /// - Premium Subscriptions: 70% Creator / 30% Platform
  /// - Superchats & Tips: 100% Creator / 0% Platform
  /// - Channel Memberships: 100% Creator / 0% Platform
  static ChannelPayoutBreakdown calculateStandardChannelPayout({
    required double adRevenue,
    required double premiumSubRevenue,
    required double tipsRevenue,
    required double membershipsRevenue,
  }) {
    final creatorAd = adRevenue * 0.70;
    final platformAd = adRevenue * 0.30;

    final creatorSub = premiumSubRevenue * 0.70;
    final platformSub = premiumSubRevenue * 0.30;

    final creatorTips = tipsRevenue; // 100% Creator / 0% Platform
    final creatorMemberships = membershipsRevenue; // 100% Creator / 0% Platform

    final gross =
        adRevenue + premiumSubRevenue + tipsRevenue + membershipsRevenue;
    final creatorTotal =
        creatorAd + creatorSub + creatorTips + creatorMemberships;
    final platformTotal = platformAd + platformSub;

    return ChannelPayoutBreakdown(
      grossRevenue: gross,
      creatorPayout: creatorTotal,
      platformShare: platformTotal,
      infraCostDeducted: 0.0,
      flatServiceFeeDeducted: 0.0,
      isZeroDebtProtected: false,
    );
  }

  /// Calculates revenue payout for a Custom Channel:
  /// - Platform Revenue Share: 0% Platform from Ads, Premium Subs, Superchats, and Memberships (100% Creator retention).
  /// - Custom channels take plans ($15, $30, $45/mo etc.) plus actual infrastructure costs.
  /// - Net Payout: Gross Revenue - Infra Cost - Plan/Service Fee
  /// - Zero-Debt Protection: Payout is capped at floor of 0 (creator balance never goes negative).
  static ChannelPayoutBreakdown calculateCustomChannelPayout({
    required double grossRevenue,
    required double actualInfraCost,
    double flatPlatformFee = 25.0,
  }) {

    final netBeforeFee = grossRevenue - actualInfraCost - flatPlatformFee;

    // Zero-Debt Floor: Creator balance cannot drop below 0
    final creatorPayout = max(0.0, netBeforeFee);
    final isProtected = netBeforeFee < 0;

    final platformTotal = actualInfraCost + flatPlatformFee;

    return ChannelPayoutBreakdown(
      grossRevenue: grossRevenue,
      creatorPayout: creatorPayout,
      platformShare: platformTotal,
      infraCostDeducted: actualInfraCost,
      flatServiceFeeDeducted: flatPlatformFee,
      isZeroDebtProtected: isProtected,
    );
  }

  /// Calculates payout based on ChannelType
  static ChannelPayoutBreakdown calculatePayout(
    Channel channel, {
    double adRevenue = 0.0,
    double premiumSubRevenue = 0.0,
    double tipsRevenue = 0.0,
    double membershipsRevenue = 0.0,
    double grossRevenue = 0.0,
    double actualInfraCost = 0.0,
  }) {
    if (channel.channelType == ChannelType.custom) {
      final fee = channel.infraConfig?.flatPlatformFee ?? 25.0;
      final totalGross = grossRevenue > 0
          ? grossRevenue
          : (adRevenue + premiumSubRevenue + tipsRevenue + membershipsRevenue);
      return calculateCustomChannelPayout(
        grossRevenue: totalGross,
        actualInfraCost: actualInfraCost,
        flatPlatformFee: fee,
      );
    } else {
      return calculateStandardChannelPayout(
        adRevenue: adRevenue,
        premiumSubRevenue: premiumSubRevenue,
        tipsRevenue: tipsRevenue,
        membershipsRevenue: membershipsRevenue,
      );
    }
  }

  /// Calculates video withdrawal eligibility for a video on a Channel:
  /// - Day 1 Earning: Both Standard & Custom channels start earning from Day 1.
  /// - Standard Channels: Earnings on a video can be withdrawn ONLY after that video reaches 10 Hours (600 mins) watch time.
  /// - Custom Channels: Earnings can be withdrawn immediately without watch time restrictions.
  static VideoWithdrawalEligibility calculateVideoWithdrawalEligibility({
    required Channel channel,
    required String videoId,
    required double videoRevenue,
    required int videoWatchTimeMinutes,
  }) {
    if (channel.channelType == ChannelType.custom) {
      return VideoWithdrawalEligibility(
        videoId: videoId,
        totalEarnedRevenue: videoRevenue,
        watchTimeMinutes: videoWatchTimeMinutes,
        isUnlockedForWithdrawal: true,
        withdrawableAmount: videoRevenue,
        pendingLockedAmount: 0.0,
      );
    }

    // Standard Channel 10-Hour Watch Time Threshold Rule
    final isUnlocked =
        videoWatchTimeMinutes >=
        standardChannelWithdrawalWatchTimeMinutesThreshold;
    return VideoWithdrawalEligibility(
      videoId: videoId,
      totalEarnedRevenue: videoRevenue,
      watchTimeMinutes: videoWatchTimeMinutes,
      isUnlockedForWithdrawal: isUnlocked,
      withdrawableAmount: isUnlocked ? videoRevenue : 0.0,
      pendingLockedAmount: isUnlocked ? 0.0 : videoRevenue,
    );
  }
}
