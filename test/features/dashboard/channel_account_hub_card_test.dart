import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/channel_wallet_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/data/models/channel_wallet_models.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/monetization/channel_account_hub_card.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/monetization/channel_financial_history_page.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  tearDown(Get.reset);

  final testChannel = Channel(
    id: 'channel_hub_1',
    name: 'Truth Hub Channel',
    nameLowercase: 'truth hub channel',
    handle: '@truthhub',
    handleLowercase: '@truthhub',
    description: 'Testing unified hub',
    avatarUrl: '',
    bannerUrl: '',
    ownerId: 'owner_hub_1',
    channelType: ChannelType.custom,
    walletBalanceUSD: 50.0,
    infraConfig: CustomChannelInfraConfig(
      subscriptionId: 'sub_hub_1',
      rolloverCreditUSD: 20.0,
      flatPlatformFee: 15.0,
    ),
    createdAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
  );

  final sampleVideo = Video(
    id: 'vid_hub_1',
    channelId: 'channel_hub_1',
    channelName: 'Truth Hub Channel',
    ownerId: 'owner_hub_1',
    title: 'Hub Video #1',
    category: 'News',
    tags: const ['news'],
    description: 'Test video',
    videoUrl: 'https://example.com/video.mp4',
    thumbnailUrl: '',
    duration: 1200,
    viewCount: 2000,
    totalWatchTimeSeconds: 43200, // 12 hours (>= 10h)
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  Widget createTestWidget(Widget child) {
    return GetMaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    );
  }

  group('ChannelAccountHubCard Widget Tests', () {
    testWidgets('renders unified channel account, hero balance, breakdown and action buttons', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = Get.put(DashboardController(channelId: 'channel_hub_1'));
      controller.rxTotalRevenue.value = 8400.0; // ₹8,400 INR
      controller.rxMembershipsRevenue.value = 4200.0;
      controller.rxSuperchatRevenue.value = 1000.0;
      controller.rxAdsRevenue.value = 2000.0;
      controller.rxWatchTimeRevenue.value = 1200.0;
      controller.recentVideos.assignAll([sampleVideo]);

      await tester.pumpWidget(
        createTestWidget(
          ChannelAccountHubCard(channel: testChannel, controller: controller),
        ),
      );
      await tester.pump(const Duration(seconds: 2));

      // Header
      expect(find.text('Channel Account'), findsOneWidget);
      expect(find.text('Unified Wallet & Monetization Hub'), findsOneWidget);
      expect(find.text('CUSTOM ACCOUNT'), findsOneWidget);

      // Hero Total Purchasing Power
      expect(find.text('Total Purchasing Power & Spendable Balance'), findsOneWidget);

      // 3-Way Sub-metrics
      expect(find.text('Withdrawable Cash'), findsOneWidget);
      expect(find.text('Locked Earnings'), findsOneWidget);
      expect(find.text('Pre-Funded Credits'), findsOneWidget);

      // 3 Core Action Buttons
      expect(find.text('Add Funds'), findsOneWidget);
      expect(find.text('Cash Out'), findsOneWidget);
      expect(find.text('Spend on AI'), findsOneWidget);

      // Unified Activity Feed & Filter Chips
      expect(find.text('Unified Activity Feed'), findsOneWidget);
      expect(find.text('All Activity'), findsOneWidget);
      expect(find.text('Earnings & Payouts'), findsOneWidget);
      expect(find.text('Spends & Deposits'), findsOneWidget);

      // 8-Year Audit History & Statement Button
      expect(find.text('View 8-Year Audit History & Export Statements'), findsOneWidget);
    });

    testWidgets('UnifiedChannelTransaction maps categories and formatting accurately', (tester) async {
      final topupTx = WalletTransaction(
        id: 'tx_topup_1',
        channelId: 'ch_1',
        userId: 'user_1',
        amount: 25.0,
        trialCreditDeducted: 0.0,
        revenueDeducted: 0.0,
        category: WalletTransactionCategory.walletTopup,
        description: 'Wallet Deposit',
        balanceBefore: 0.0,
        balanceAfter: 25.0,
        timestamp: DateTime(2026, 10, 21, 10, 30),
      );

      final unifiedTopup = UnifiedChannelTransaction.fromWalletTransaction(topupTx);
      expect(unifiedTopup.type, UnifiedTransactionType.topup);
      expect(unifiedTopup.isCredit, isTrue);
      expect(unifiedTopup.formattedAmount, r'+$25.00');

      final payoutData = {
        'amount': 500.0,
        'currency': 'INR',
        'paymentMethod': 'UPI',
        'status': 'processing',
        'createdAt': Timestamp.now(),
      };
      final unifiedPayout = UnifiedChannelTransaction.fromPayoutRequest(payoutData, 'req_123');
      expect(unifiedPayout.type, UnifiedTransactionType.payout);
      expect(unifiedPayout.isCredit, isFalse);
      expect(unifiedPayout.status, 'processing');
      expect(unifiedPayout.formattedAmount, '-₹500.00');
    });

    testWidgets('ChannelWalletService generates RFC-4180 CSV statement with statutory retention header', (tester) async {
      final walletService = ChannelWalletService();
      final txList = [
        UnifiedChannelTransaction(
          id: 'tx_1',
          title: 'Ad Revenue Allocation',
          subtitle: 'revenueEarned',
          amount: 1500.0,
          currency: 'INR',
          isCredit: true,
          type: UnifiedTransactionType.revenueEarned,
          timestamp: DateTime(2026, 10, 21, 12, 0),
        ),
        UnifiedChannelTransaction(
          id: 'payout_1',
          title: 'Bank Withdrawal',
          subtitle: 'Payout Request',
          amount: 500.0,
          currency: 'INR',
          isCredit: false,
          type: UnifiedTransactionType.payout,
          timestamp: DateTime(2026, 10, 21, 14, 0),
        ),
      ];

      final csv = walletService.generateFinancialStatementCSV(
        channelName: 'Truth Hub Channel',
        channelId: 'channel_hub_1',
        transactions: txList,
      );

      expect(csv.contains('# TruthWorld Creator Financial Ledger & Audit Statement'), isTrue);
      expect(csv.contains('Statutory 8-Year Audit Archive'), isTrue);
      expect(csv.contains('Date,Transaction ID,Type,Category,Description,Status,Inflow (Credit),Outflow (Debit),Currency'), isTrue);
      expect(csv.contains('tx_1,revenueEarned,revenueEarned,"Ad Revenue Allocation",completed,1500.00,0.00,INR'), isTrue);
      expect(csv.contains('payout_1,payout,Payout Request,"Bank Withdrawal",completed,0.00,500.00,INR'), isTrue);
    });

    testWidgets('ChannelFinancialHistoryPage renders range selectors, search bar and statutory footer', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        GetMaterialApp(
          home: ChannelFinancialHistoryPage(channel: testChannel),
        ),
      );
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Financial History & Ledger'), findsOneWidget);
      expect(find.textContaining('8-Year Statutory Archive'), findsWidgets);
      expect(find.text('Last 30 Days'), findsOneWidget);
      expect(find.text('Last 90 Days'), findsOneWidget);
      expect(find.text('Current FY (2026-27)'), findsOneWidget);
      expect(find.text('All Time (8-Year Audit)'), findsOneWidget);
      expect(find.text('TOTAL CREDITS (INFLOW)'), findsOneWidget);
      expect(find.text('TOTAL DEBITS (OUTFLOW)'), findsOneWidget);
      expect(find.textContaining('Companies Act 2013 §128'), findsOneWidget);
    });

    test('Cost-Effective Ledger Caching: memoizes queries and invalidates accurately', () async {
      final service = ChannelWalletService();
      ChannelWalletService.invalidateLedgerCache();

      // First query populates cache
      final items1 = await service.fetchHistoricalLedger(
        channelId: 'channel_hub_1',
        limit: 10,
      );

      // Second query with same parameters should return from memory cache immediately
      final items2 = await service.fetchHistoricalLedger(
        channelId: 'channel_hub_1',
        limit: 10,
      );
      expect(identical(items1, items2), isFalse); // returns a new list copy of cached items
      expect(items1.length, equals(items2.length));

      // Force refresh bypasses cache
      final items3 = await service.fetchHistoricalLedger(
        channelId: 'channel_hub_1',
        limit: 10,
        forceRefresh: true,
      );
      expect(items3.length, equals(items1.length));

      // Targeted invalidation clears specific channel
      ChannelWalletService.invalidateLedgerCache(channelId: 'channel_hub_1');
      final items4 = await service.fetchHistoricalLedger(
        channelId: 'channel_hub_1',
        limit: 10,
      );
      expect(items4.length, equals(items1.length));
    });

    test('Cost-Effective Smart Routing: filterType query paths', () async {
      final service = ChannelWalletService();

      // Payouts only: skips wallet transactions & revenue statements
      final payouts = await service.fetchHistoricalLedger(
        channelId: 'channel_hub_1',
        filterType: UnifiedTransactionType.payout,
        limit: 10,
      );
      for (final tx in payouts) {
        expect(tx.type, equals(UnifiedTransactionType.payout));
      }

      // Spends only: skips payout requests & revenue statements
      final spends = await service.fetchHistoricalLedger(
        channelId: 'channel_hub_1',
        filterType: UnifiedTransactionType.aiSpend,
        limit: 10,
      );
      for (final tx in spends) {
        expect(tx.isCredit, isFalse);
      }
    });
  });
}
