import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/services/channel_payout_calculator.dart';
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
    isVerified: true,
    category: 'News',
    categories: ['News', 'Investigation'],
    language: 'English',
    monetizationTier: MonetizationTier.eligible,
  );

  group('ChannelMonetizationController Unit Tests', () {
    test('Calculates derived revenue and watch time correctly', () {
      final controller = ChannelMonetizationController(initialChannel: dummyChannel);
      controller.onInit();

      expect(controller.adRevenue, equals(50.0)); // 10000 * 0.005
      expect(controller.premiumSubRevenue, equals(2.4)); // 1200 * 0.002
      expect(controller.singleVideoWatchTimeMinutes, equals(1200));
      expect(controller.singleVideoRevenue, equals(52.4));
      expect(controller.calculateDaysLeftToSwitch(), greaterThanOrEqualTo(0));
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
      expect(find.text('Unlocked (10h+ Met)'), findsOneWidget);
      expect(find.text('12.0 / 10.0 Hours Watch Time'), findsOneWidget);
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
        find.text('Custom Channel Advantage: No watch time limits for withdrawals!'),
        findsOneWidget,
      );
    });
  });
}
