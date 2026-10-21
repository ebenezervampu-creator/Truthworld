import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/services/channel_payout_calculator.dart';
import 'package:truthworld/data/models/channel.dart';

Channel createTestChannel({
  ChannelType channelType = ChannelType.standard,
  CustomChannelInfraConfig? infraConfig,
}) {
  return Channel.fromMap({
    'name': 'Test Channel',
    'nameLowercase': 'test channel',
    'handle': '@test',
    'handleLowercase': '@test',
    'description': 'Test',
    'avatarUrl': '',
    'bannerUrl': '',
    'ownerId': 'user-1',
    'channelType': channelType.name,
    if (infraConfig != null) 'infraConfig': infraConfig.toMap(),
  }, 'ch-1');
}

void main() {
  group('ChannelPayoutCalculator Tests', () {
    group('Standard Channel Payouts', () {
      test('calculates 70/30 split on ads and subs, 100% on tips and memberships', () {
        final breakdown = ChannelPayoutCalculator.calculateStandardChannelPayout(
          adRevenue: 100.0,
          premiumSubRevenue: 50.0,
          tipsRevenue: 20.0,
          membershipsRevenue: 40.0,
        );

        expect(breakdown.grossRevenue, equals(210.0));
        // Creator: 70 (ads) + 35 (subs) + 20 (tips) + 40 (memberships) = 165.0
        expect(breakdown.creatorPayout, closeTo(165.0, 0.001));
        // Platform: 30 (ads) + 15 (subs) = 45.0
        expect(breakdown.platformShare, closeTo(45.0, 0.001));
        expect(breakdown.infraCostDeducted, equals(0.0));
        expect(breakdown.flatServiceFeeDeducted, equals(0.0));
        expect(breakdown.isZeroDebtProtected, isFalse);
      });

      test('handles zero revenue gracefully', () {
        final breakdown = ChannelPayoutCalculator.calculateStandardChannelPayout(
          adRevenue: 0.0,
          premiumSubRevenue: 0.0,
          tipsRevenue: 0.0,
          membershipsRevenue: 0.0,
        );

        expect(breakdown.grossRevenue, equals(0.0));
        expect(breakdown.creatorPayout, equals(0.0));
        expect(breakdown.platformShare, equals(0.0));
        expect(breakdown.isZeroDebtProtected, isFalse);
      });

      test('applies 30% platform cut to memberships when noAdsForMembers is enabled', () {
        final breakdown = ChannelPayoutCalculator.calculateStandardChannelPayout(
          adRevenue: 100.0,
          premiumSubRevenue: 50.0,
          tipsRevenue: 20.0,
          membershipsRevenue: 100.0,
          noAdsForMembers: true,
        );

        expect(breakdown.grossRevenue, equals(270.0));
        // Creator: 70 (ads) + 35 (subs) + 20 (tips) + 70 (70% of memberships) = 195.0
        expect(breakdown.creatorPayout, closeTo(195.0, 0.001));
        // Platform: 30 (ads) + 15 (subs) + 30 (30% of memberships) = 75.0
        expect(breakdown.platformShare, closeTo(75.0, 0.001));
        expect(breakdown.isMemberAdFreeEnabled, isTrue);
        expect(breakdown.membershipPlatformCut, closeTo(30.0, 0.001));
      });
    });

    group('Custom Channel Payouts & Zero-Debt Protection', () {
      test('calculates net payout deducting actual infra and flat fee', () {
        final breakdown = ChannelPayoutCalculator.calculateCustomChannelPayout(
          grossRevenue: 500.0,
          actualInfraCost: 120.0,
        );

        expect(breakdown.grossRevenue, equals(500.0));
        // Creator: 500 - 120 - 25 = 355.0
        expect(breakdown.creatorPayout, equals(355.0));
        expect(breakdown.platformShare, equals(145.0));
        expect(breakdown.infraCostDeducted, equals(120.0));
        expect(breakdown.flatServiceFeeDeducted, equals(25.0));
        expect(breakdown.isZeroDebtProtected, isFalse);
      });

      test('activates Zero-Debt Protection when costs exceed revenue', () {
        final breakdown = ChannelPayoutCalculator.calculateCustomChannelPayout(
          grossRevenue: 50.0,
          actualInfraCost: 100.0,
        );

        // Net before fee would be: 50 - 100 - 25 = -75.0
        // Creator payout must floor at 0.0
        expect(breakdown.creatorPayout, equals(0.0));
        expect(breakdown.isZeroDebtProtected, isTrue);
        expect(breakdown.grossRevenue, equals(50.0));
        expect(breakdown.infraCostDeducted, equals(100.0));
        expect(breakdown.flatServiceFeeDeducted, equals(25.0));
      });

      test('break-even revenue produces exactly 0 payout without debt trigger', () {
        final breakdown = ChannelPayoutCalculator.calculateCustomChannelPayout(
          grossRevenue: 145.0,
          actualInfraCost: 120.0,
        );

        expect(breakdown.creatorPayout, equals(0.0));
        expect(breakdown.isZeroDebtProtected, isFalse);
      });
    });

    group('Polymorphic calculatePayout', () {
      test('dispatches correctly for standard channel', () {
        final channel = createTestChannel();

        final breakdown = ChannelPayoutCalculator.calculatePayout(
          channel,
          adRevenue: 100.0,
          tipsRevenue: 50.0,
        );

        expect(breakdown.grossRevenue, equals(150.0));
        expect(breakdown.creatorPayout, closeTo(120.0, 0.001)); // 70 + 50
        expect(breakdown.infraCostDeducted, equals(0.0));
      });

      test('dispatches correctly for standard channel with noAdsForMembers enabled', () {
        final channel = createTestChannel().copyWith(noAdsForMembers: true);

        final breakdown = ChannelPayoutCalculator.calculatePayout(
          channel,
          adRevenue: 100.0,
          membershipsRevenue: 100.0,
        );

        expect(breakdown.grossRevenue, equals(200.0));
        // Creator: 70 (ads) + 70 (70% memberships) = 140.0
        expect(breakdown.creatorPayout, closeTo(140.0, 0.001));
        // Platform: 30 (ads) + 30 (30% memberships) = 60.0
        expect(breakdown.platformShare, closeTo(60.0, 0.001));
        expect(breakdown.isMemberAdFreeEnabled, isTrue);
      });

      test('dispatches correctly for custom channel with configured fee', () {
        final infraConfig = CustomChannelInfraConfig(
          stripeConnectAccountId: 'acct_123',
          subscriptionId: 'sub_123',
          flatPlatformFee: 30.0,
        );
        final channel = createTestChannel(
          channelType: ChannelType.custom,
          infraConfig: infraConfig,
        );

        final breakdown = ChannelPayoutCalculator.calculatePayout(
          channel,
          grossRevenue: 300.0,
          actualInfraCost: 50.0,
        );

        // 300 - 50 - 30 = 220
        expect(breakdown.creatorPayout, equals(220.0));
        expect(breakdown.flatServiceFeeDeducted, equals(30.0));
      });
    });

    group('Video Withdrawal Eligibility Rules (1k Views & 10h Watch Time)', () {
      test('Custom channel requires both 10 hours watch time and 1,000 views', () {
        final channel = createTestChannel(channelType: ChannelType.custom);

        // 1. Below watch time threshold (599 minutes), 1000 views: Locked
        final lockedByTime = ChannelPayoutCalculator.calculateVideoWithdrawalEligibility(
          channel: channel,
          videoId: 'vid-custom-1',
          videoRevenue: 150.0,
          videoWatchTimeMinutes: 599,
          videoViews: 1000,
        );
        expect(lockedByTime.isUnlockedForWithdrawal, isFalse);
        expect(lockedByTime.withdrawableAmount, equals(0.0));
        expect(lockedByTime.pendingLockedAmount, equals(150.0));

        // 2. Met watch time (600 minutes), but below views threshold (999 views): Locked
        final lockedByViews = ChannelPayoutCalculator.calculateVideoWithdrawalEligibility(
          channel: channel,
          videoId: 'vid-custom-1',
          videoRevenue: 150.0,
          videoWatchTimeMinutes: 600,
          videoViews: 999,
        );
        expect(lockedByViews.isUnlockedForWithdrawal, isFalse);
        expect(lockedByViews.withdrawableAmount, equals(0.0));
        expect(lockedByViews.pendingLockedAmount, equals(150.0));

        // 3. Exactly at both thresholds (600 minutes, 1,000 views): Unlocked
        final exact = ChannelPayoutCalculator.calculateVideoWithdrawalEligibility(
          channel: channel,
          videoId: 'vid-custom-1',
          videoRevenue: 150.0,
          videoWatchTimeMinutes: 600,
          videoViews: 1000,
        );
        expect(exact.isUnlockedForWithdrawal, isTrue);
        expect(exact.withdrawableAmount, equals(150.0));
        expect(exact.pendingLockedAmount, equals(0.0));
      });

      test('Standard channel requires both 10 hours watch time and 1,000 views', () {
        final channel = createTestChannel();

        // 1. Below watch time (599 mins), 1,000 views: Locked
        final locked = ChannelPayoutCalculator.calculateVideoWithdrawalEligibility(
          channel: channel,
          videoId: 'vid-std-1',
          videoRevenue: 85.0,
          videoWatchTimeMinutes: 599,
          videoViews: 1000,
        );
        expect(locked.isUnlockedForWithdrawal, isFalse);
        expect(locked.withdrawableAmount, equals(0.0));
        expect(locked.pendingLockedAmount, equals(85.0));

        // 2. Below views (999 views), 600 mins: Locked
        final lockedViews = ChannelPayoutCalculator.calculateVideoWithdrawalEligibility(
          channel: channel,
          videoId: 'vid-std-1',
          videoRevenue: 85.0,
          videoWatchTimeMinutes: 600,
          videoViews: 999,
        );
        expect(lockedViews.isUnlockedForWithdrawal, isFalse);
        expect(lockedViews.withdrawableAmount, equals(0.0));
        expect(lockedViews.pendingLockedAmount, equals(85.0));

        // 3. Exactly at thresholds (600 mins, 1000 views): Unlocked
        final exact = ChannelPayoutCalculator.calculateVideoWithdrawalEligibility(
          channel: channel,
          videoId: 'vid-std-1',
          videoRevenue: 85.0,
          videoWatchTimeMinutes: 600,
          videoViews: 1000,
        );
        expect(exact.isUnlockedForWithdrawal, isTrue);
        expect(exact.withdrawableAmount, equals(85.0));
        expect(exact.pendingLockedAmount, equals(0.0));

        // 4. Above thresholds (1200 mins, 5000 views): Unlocked
        final above = ChannelPayoutCalculator.calculateVideoWithdrawalEligibility(
          channel: channel,
          videoId: 'vid-std-1',
          videoRevenue: 200.0,
          videoWatchTimeMinutes: 1200,
          videoViews: 5000,
        );
        expect(above.isUnlockedForWithdrawal, isTrue);
        expect(above.withdrawableAmount, equals(200.0));
        expect(above.pendingLockedAmount, equals(0.0));
      });
    });

    group('Channel Monetization Gate (Any Video >= 1k views & 10h + KYC completed)', () {
      test('constants match exact qualification rules', () {
        expect(ChannelPayoutCalculator.channelMonetizationViewsThreshold, equals(1000));
        expect(ChannelPayoutCalculator.channelMonetizationWatchTimeMinutesThreshold, equals(600));
      });

      test('monetization turns ON only when both qualified video and KYC completed', () {
        // Neither met: false
        expect(
          ChannelPayoutCalculator.isChannelMonetizationEligible(
            hasQualifiedVideo: false,
            isKycVerified: false,
          ),
          isFalse,
        );

        // Video threshold met (>=1k views & 10h), but KYC not verified: false
        expect(
          ChannelPayoutCalculator.isChannelMonetizationEligible(
            hasQualifiedVideo: true,
            isKycVerified: false,
          ),
          isFalse,
        );

        // KYC verified, but no video crossed threshold: false
        expect(
          ChannelPayoutCalculator.isChannelMonetizationEligible(
            hasQualifiedVideo: false,
            isKycVerified: true,
          ),
          isFalse,
        );

        // Both met: Monetization turns ON!
        expect(
          ChannelPayoutCalculator.isChannelMonetizationEligible(
            hasQualifiedVideo: true,
            isKycVerified: true,
          ),
          isTrue,
        );
      });
    });

    group('Minimum Withdrawal Threshold Tests', () {
      test(r'correctly configures ₹100 for Indian channels and $10 for other countries', () {
        expect(ChannelPayoutCalculator.minWithdrawalAmountINR, equals(100.0));
        expect(ChannelPayoutCalculator.minWithdrawalAmountUSD, equals(10.0));

        expect(
          ChannelPayoutCalculator.getMinimumWithdrawalThreshold(),
          equals(100.0),
        );
        expect(
          ChannelPayoutCalculator.getMinimumWithdrawalThreshold(isIndian: false),
          equals(10.0),
        );

        expect(
          ChannelPayoutCalculator.getMinimumWithdrawalFormatted(),
          equals('₹100'),
        );
        expect(
          ChannelPayoutCalculator.getMinimumWithdrawalFormatted(isIndian: false),
          equals(r'$10'),
        );
      });
    });
  });
}
