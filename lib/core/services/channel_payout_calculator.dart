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
    this.isMemberAdFreeEnabled = false,
    this.membershipPlatformCut = 0.0,
  });
  final double grossRevenue;
  final double creatorPayout;
  final double platformShare;
  final double infraCostDeducted;
  final double flatServiceFeeDeducted;
  final bool isZeroDebtProtected;
  final bool isMemberAdFreeEnabled;
  final double membershipPlatformCut;
}

class VideoWithdrawalEligibility {
  final String videoId;
  final double totalEarnedRevenue;
  final int watchTimeMinutes;
  final int viewCount;
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
    this.viewCount = 0,
  });
}

class ChannelPayoutCalculator {
  /// Channel video withdrawal threshold: 10 Hours (600 mins) of watch time per video (Standard & Custom)
  static const int channelWithdrawalWatchTimeMinutesThreshold =
      600; // 10 Hours
  static const int standardChannelWithdrawalWatchTimeMinutesThreshold =
      channelWithdrawalWatchTimeMinutesThreshold;

  /// Channel video withdrawal threshold: 1,000 views per video (Standard & Custom)
  static const int channelWithdrawalViewsThreshold = 1000; // 1k Views

  /// Calculates revenue payout for a Standard Channel:
  /// - Ad Revenue: 70% Creator / 30% Platform
  /// - Premium Subscriptions: 70% Creator / 30% Platform
  /// - Superchats & Tips: 100% Creator / 0% Platform
  /// - Channel Memberships:
  ///   - Standard (Default): 100% Creator / 0% Platform
  ///   - Member Ad-Free Playback Enabled: 70% Creator / 30% Platform (Platform retains 30% cut to cover ad suppression for members)
  static ChannelPayoutBreakdown calculateStandardChannelPayout({
    required double adRevenue,
    required double premiumSubRevenue,
    required double tipsRevenue,
    required double membershipsRevenue,
    bool noAdsForMembers = false,
  }) {
    final creatorAd = adRevenue * 0.70;
    final platformAd = adRevenue * 0.30;

    final creatorSub = premiumSubRevenue * 0.70;
    final platformSub = premiumSubRevenue * 0.30;

    final creatorTips = tipsRevenue; // 100% Creator / 0% Platform

    // When noAdsForMembers is enabled, platform takes a 30% cut on memberships
    final membershipPlatformCutRate = noAdsForMembers ? 0.30 : 0.0;
    final creatorMemberships = membershipsRevenue * (1.0 - membershipPlatformCutRate);
    final platformMemberships = membershipsRevenue * membershipPlatformCutRate;

    final gross =
        adRevenue + premiumSubRevenue + tipsRevenue + membershipsRevenue;
    final creatorTotal =
        creatorAd + creatorSub + creatorTips + creatorMemberships;
    final platformTotal = platformAd + platformSub + platformMemberships;

    return ChannelPayoutBreakdown(
      grossRevenue: gross,
      creatorPayout: creatorTotal,
      platformShare: platformTotal,
      infraCostDeducted: 0.0,
      flatServiceFeeDeducted: 0.0,
      isZeroDebtProtected: false,
      isMemberAdFreeEnabled: noAdsForMembers,
      membershipPlatformCut: platformMemberships,
    );
  }

  /// Calculates revenue payout for a Custom Channel:
  /// - Platform Revenue Share: 0% Platform from Ads, Premium Subs, Superchats, and Memberships (100% Creator retention).
  /// - Custom channels take plans ($15, $30, $45, $100, $200/mo etc.) plus actual infrastructure costs.
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
    bool? noAdsForMembers,
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
      final isNoAds = noAdsForMembers ?? channel.noAdsForMembers;
      return calculateStandardChannelPayout(
        adRevenue: adRevenue,
        premiumSubRevenue: premiumSubRevenue,
        tipsRevenue: tipsRevenue,
        membershipsRevenue: membershipsRevenue,
        noAdsForMembers: isNoAds,
      );
    }
  }

  /// Calculates video withdrawal eligibility for a video on a Channel:
  /// - Day 1 Earning: Both Standard & Custom channels start earning from Day 1.
  /// - Standard & Custom Channels: Earnings on a video can be withdrawn ONLY after that video reaches 1,000 views AND 10 Hours (600 mins) watch time.
  /// - Custom channels retain 100% of revenue across all sources, with cash withdrawals unlocking per video at 1,000 views and 10 hours watch time.
  static VideoWithdrawalEligibility calculateVideoWithdrawalEligibility({
    required Channel channel,
    required String videoId,
    required double videoRevenue,
    required int videoWatchTimeMinutes,
    int videoViews = 0,
  }) {
    // Both 1,000 views AND 10-Hour Watch Time (600 mins) thresholds are enforced for all channels
    final isUnlocked =
        videoWatchTimeMinutes >= channelWithdrawalWatchTimeMinutesThreshold &&
        videoViews >= channelWithdrawalViewsThreshold;
    return VideoWithdrawalEligibility(
      videoId: videoId,
      totalEarnedRevenue: videoRevenue,
      watchTimeMinutes: videoWatchTimeMinutes,
      viewCount: videoViews,
      isUnlockedForWithdrawal: isUnlocked,
      withdrawableAmount: isUnlocked ? videoRevenue : 0.0,
      pendingLockedAmount: isUnlocked ? 0.0 : videoRevenue,
    );
  }
}
