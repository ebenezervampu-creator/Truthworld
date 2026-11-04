import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/services/channel_payout_calculator.dart';
import 'package:truthworld/core/services/channel_wallet_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/channel/presentation/views/channel/monetization/monetization_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final dummyChannel = Channel(
    id: 'test_chan_1',
    name: 'Truth Investigates',
    nameLowercase: 'truth investigates',
    handle: 'truth_inv',
    handleLowercase: 'truth_inv',
    description: 'Channel description',
    avatarUrl: 'https://example.com/avatar.jpg',
    bannerUrl: 'https://example.com/banner.jpg',
    ownerId: 'owner_123',
    createdAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
    subscriberCount: 500,
    videoCount: 10,
    metrics: ChannelMetricsV2(
      totalViews: 10000,
      totalWatchTimeMinutes: 1200,
      averageRetention: 0.75,
    ),
    adsRevenueTotal: 50.0,
    premiumSubsRevenueTotal: 2.4,
    isVerified: true,
    category: 'News',
    categories: ['News', 'Investigation'],
    language: 'English',
    monetizationTier: MonetizationTier.eligible,
  );

  group('ChannelMonetizationController Unit Tests', () {
    test('Calculates authentic revenue and watch time correctly', () {
      final controller = ChannelMonetizationController(initialChannel: dummyChannel);
      controller.onInit();

      expect(controller.adRevenue, equals(50.0));
      expect(controller.premiumSubRevenue, equals(2.4));
      expect(controller.singleVideoWatchTimeMinutes, equals(1200));
      expect(controller.singleVideoRevenue, equals(52.4));
      expect(controller.calculateDaysLeftToSwitch(), greaterThanOrEqualTo(0));
    });

    test('Never shows mock revenue when channel has zero authentic ad revenue', () {
      final zeroRevChannel = dummyChannel.copyWith(
        adsRevenueTotal: 0.0,
        premiumSubsRevenueTotal: 0.0,
      );
      final controller = ChannelMonetizationController(initialChannel: zeroRevChannel);
      controller.onInit();

      expect(controller.adRevenue, equals(0.0));
      expect(controller.premiumSubRevenue, equals(0.0));
      expect(controller.singleVideoRevenue, equals(0.0));
    });
  });

  group('ChannelZeroLossSafeguardCard Tests', () {
    testWidgets('renders zero loss protection active text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChannelZeroLossSafeguardCard(),
          ),
        ),
      );

      expect(find.text('Zero-Loss Protection Active'), findsOneWidget);
      expect(find.byIcon(Icons.shield), findsOneWidget);
    });
  });

  group('ChannelRevenueRow Tests', () {
    testWidgets('renders creator share and platform share', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChannelRevenueRow(
              label: 'Ad Revenue (70% Creator)',
              creatorShare: 70.0,
              platformShare: 30.0,
            ),
          ),
        ),
      );

      expect(find.text('Ad Revenue (70% Creator)'), findsOneWidget);
      expect(find.text('₹70'), findsOneWidget);
      expect(find.text('(Platform: ₹30)'), findsOneWidget);
    });
  });

  group('ChannelMeterBar Tests', () {
    testWidgets('renders meter title and value text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChannelMeterBar(
              title: 'Video Storage',
              valueText: '10.5 GB / 50 GB',
              progress: 0.21,
            ),
          ),
        ),
      );

      expect(find.text('Video Storage'), findsOneWidget);
      expect(find.text('10.5 GB / 50 GB'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });
  });

  group('ChannelWithdrawalRulesCard Tests', () {
    testWidgets('renders unlocked state when criteria met', (tester) async {
      const eligibility = VideoWithdrawalEligibility(
        videoId: 'vid_123',
        totalEarnedRevenue: 85.0,
        watchTimeMinutes: 720,
        withdrawableAmount: 85.0,
        pendingLockedAmount: 0.0,
        isUnlockedForWithdrawal: true,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChannelWithdrawalRulesCard(
              eligibility: eligibility,
              isCustom: false,
            ),
          ),
        ),
      );

      expect(find.text('Day 1 Earnings Active'), findsOneWidget);
      expect(find.text('Unlocked (1k Views & 30h Met)'), findsOneWidget);
      expect(find.text('0 / 1,000 Views • 12.0 / 30.0 Hours'), findsOneWidget);
      expect(find.text('Withdrawable: ₹85'), findsOneWidget);
    });

    testWidgets('renders custom channel advantage when isCustom is true', (tester) async {
      const eligibility = VideoWithdrawalEligibility(
        videoId: 'vid_123',
        totalEarnedRevenue: 200.0,
        watchTimeMinutes: 120,
        withdrawableAmount: 200.0,
        pendingLockedAmount: 0.0,
        isUnlockedForWithdrawal: true,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChannelWithdrawalRulesCard(
              eligibility: eligibility,
              isCustom: true,
            ),
          ),
        ),
      );

      expect(
        find.text('Pro Channel: 100% Creator revenue retained upon reaching 1,000 views and 30 hours watch time.'),
        findsOneWidget,
      );
    });
  });

  group('Channel Hype Surge & Capacity Advisory Tests', () {
    test('Correctly detects hype surge when bandwidth exceeds 75% or quota', () {
      final surgeChannel = dummyChannel.copyWith(
        channelType: ChannelType.custom,
        adsRevenueTotal: 120.0,
        premiumSubsRevenueTotal: 30.0,
        superchatRevenueTotal: 50.0,
        membershipRevenueTotal: 40.0,
        infraConfig: CustomChannelInfraConfig(
          subscriptionId: 'sub_test_1',
          bandwidthQuotaBytesThisMonth: 100 * 1024 * 1024 * 1024,
          bandwidthUsedBytesThisMonth: 180 * 1024 * 1024 * 1024, // 180 GB > 100 GB
          storageQuotaBytes: 25 * 1024 * 1024 * 1024,
          storageUsedBytes: 15 * 1024 * 1024 * 1024,
          lossPreventionMode: LossPreventionMode.autoScaled,
        ),
      );

      final controller = ChannelMonetizationController(initialChannel: surgeChannel);
      controller.onInit();

      expect(controller.isHypeSurgeActive, isTrue);
      final summary = controller.hypeSurgeSummary;
      expect(summary.grossTotalRevenue, equals(240.0)); // 120 + 30 + 50 + 40
      expect(summary.adRevenue, equals(120.0));
      expect(summary.premiumSubRevenue, equals(30.0));
      expect(summary.tipsRevenue, equals(50.0));
      expect(summary.membershipsRevenue, equals(40.0));
      expect(summary.recommendedUpgradePlan.id, equals('growth_30')); // 300 GB covers 180 GB
      expect(summary.isCoveredByRevenue, isTrue);
      expect(summary.netWithdrawableAfterUpgrade, equals(210.0)); // 240 - 30
    });

    testWidgets('Renders ChannelHypeSurgeAdvisoryCard with all 4 collected revenue streams and upgrade option', (tester) async {
      final surgeChannel = dummyChannel.copyWith(
        channelType: ChannelType.custom,
        adsRevenueTotal: 100.0,
        premiumSubsRevenueTotal: 25.0,
        superchatRevenueTotal: 45.0,
        membershipRevenueTotal: 30.0,
        infraConfig: CustomChannelInfraConfig(
          subscriptionId: 'sub_test_2',
          bandwidthQuotaBytesThisMonth: 100 * 1024 * 1024 * 1024,
          bandwidthUsedBytesThisMonth: 150 * 1024 * 1024 * 1024,
          storageQuotaBytes: 25 * 1024 * 1024 * 1024,
          storageUsedBytes: 10 * 1024 * 1024 * 1024,
          lossPreventionMode: LossPreventionMode.autoScaled,
        ),
      );

      final controller = ChannelMonetizationController(initialChannel: surgeChannel);
      controller.onInit();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ChannelHypeSurgeAdvisoryCard(controller: controller),
            ),
          ),
        ),
      );

      expect(find.text('Sudden Hype Surge Detected'), findsOneWidget);
      expect(find.text('AUTO-SCALED AT 480P (ZERO-LOSS ACTIVE)'), findsOneWidget);
      expect(find.text('Ads Revenue'), findsOneWidget);
      expect(find.text(r'$100.00'), findsOneWidget);
      expect(find.text('Premium Subs'), findsOneWidget);
      expect(find.text(r'$25.00'), findsOneWidget);
      expect(find.text('Memberships'), findsOneWidget);
      expect(find.text(r'$30.00'), findsOneWidget);
      expect(find.text('Superchats & Tips'), findsOneWidget);
      expect(find.text(r'$45.00'), findsOneWidget);
      expect(find.text('Withdraw 100%'), findsOneWidget);
      expect(find.textContaining('Upgrade to Growth'), findsOneWidget);
    });
  });

  group('Zero-Waste Plan Rollover Tests', () {
    test(r'Calculates unspent plan balance accurately (e.g. $15 plan with $5 spent leaves $10 safe, not $0)', () {
      final config = CustomChannelInfraConfig(
        subscriptionId: 'sub_123',
        currentMonthInfraCost: 5.0,
      );

      // 1 cent cannot be wasted: 15 - 5 = 10
      expect(config.unspentCurrentMonthPlanBalance, equals(10.0));
      expect(config.totalProtectedBalance, equals(10.0));
    });

    test(r'Combines previous rollover credit with current unspent balance without resetting to $0', () {
      final configWithRollover = CustomChannelInfraConfig(
        subscriptionId: 'sub_123',
        currentMonthInfraCost: 5.0,
        rolloverCreditUSD: 7.50, // rolled over from prior month
      );

      expect(configWithRollover.unspentCurrentMonthPlanBalance, equals(10.0));
      expect(configWithRollover.totalProtectedBalance, equals(17.50));
    });

    test('SpendableBalance includes rolloverCredit safely', () {
      final customChannel = dummyChannel.copyWith(
        channelType: ChannelType.custom,
        walletBalanceUSD: 20.0,
        infraConfig: CustomChannelInfraConfig(
          subscriptionId: 'sub_123',
          rolloverCreditUSD: 10.0, // $10 unspent rolled over
        ),
      );

      final walletService = ChannelWalletService();
      final spendable = walletService.getSpendableBalance(
        channel: customChannel,
        withdrawableRevenue: 50.0,
      );

      expect(spendable.rolloverCredit, equals(10.0));
      // Total spendable = 20 (funded) + 0 (trial) + 10 (rollover) + 50 (revenue) = 80.0
      expect(spendable.totalSpendableBalance, equals(80.0));
      expect(spendable.canAfford(75.0), isTrue);
    });

    testWidgets('Renders ChannelZeroWasteRolloverCard showing 0 cents wasted and protected balance', (tester) async {
      final customChannel = dummyChannel.copyWith(
        channelType: ChannelType.custom,
        infraConfig: CustomChannelInfraConfig(
          subscriptionId: 'sub_123',
          currentMonthInfraCost: 5.0,
        ),
      );

      final controller = ChannelMonetizationController(initialChannel: customChannel);
      controller.onInit();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ChannelZeroWasteRolloverCard(controller: controller),
            ),
          ),
        ),
      );

      expect(find.text('Zero-Waste Rollover Guarantee'), findsOneWidget);
      expect(find.text('0 CENTS WASTED'), findsOneWidget);
      expect(find.text(r'$15.00'), findsWidgets);
      expect(find.text('Safe For Next Month'), findsOneWidget);
    });
  });
}
