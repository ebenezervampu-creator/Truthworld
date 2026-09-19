import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/analytics/data/models/creator_bank_account.dart';
import 'package:truthworld/features/analytics/data/models/creator_kyc_verification.dart';
import 'package:truthworld/features/analytics/presentation/controllers/revenue_analytics_controller.dart';
import 'package:truthworld/features/analytics/presentation/pages/revenue/revenue_analytics_widgets.dart';
import 'package:truthworld/features/analytics/presentation/pages/revenue_analytics_page.dart';
import 'package:truthworld/theme/app_theme.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  setUp(() {
    Get.reset();
    Get.testMode = true;
    if (!Get.isRegistered<AuthService>()) {
      Get.put<AuthService>(AuthService(), permanent: true);
    }
  });

  tearDown(Get.reset);

  Widget createHarness(Widget child) {
    return GetMaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    );
  }

  group('Revenue Analytics Modular Components Tests', () {
    testWidgets('buildRevenueSectionHeader renders title and badge properly', (tester) async {
      await tester.pumpWidget(
        createHarness(
          buildRevenueSectionHeader(
            title: 'Test Ways You Earned',
            badge: 'Test Active Badge',
          ),
        ),
      );

      expect(find.text('Test Ways You Earned'), findsOneWidget);
      expect(find.text('Test Active Badge'), findsOneWidget);
    });

    testWidgets('buildRevenueHeroMetricCard renders metrics and currency toggle', (tester) async {
      final ctrl = Get.put(RevenueAnalyticsController());
      ctrl.membershipsRevenue.value = 850.0;
      ctrl.setCurrencyView('INR');
      ctrl.totalRevenueUSD.value = 10.0;
      ctrl.originalUsdMemberships.value = 10.0;
      ctrl.revenueChange.value = r'+$5.00';

      await tester.pumpWidget(
        createHarness(
          Obx(() => buildRevenueHeroMetricCard(ctrl)),
        ),
      );

      expect(find.text('Total Estimated Revenue'), findsOneWidget);
      expect(find.text('₹850.00'), findsOneWidget);
      expect(find.text('₹ INR'), findsOneWidget);
      expect(find.text(r'$ USD'), findsOneWidget);
      expect(find.text(r'+$5.00'), findsOneWidget);
      expect(
        find.text(
          'Exchange Rate: 1 USD = ₹${RevenueAnalyticsController.usdToInrRate.toStringAsFixed(2)} INR',
        ),
        findsOneWidget,
      );

      // Switch to USD
      await tester.tap(find.text(r'$ USD'));
      await tester.pump();
      expect(ctrl.isViewingINR, isFalse);
    });

    testWidgets('buildMembershipsStreamCard displays membership stats and conversion', (tester) async {
      final ctrl = Get.put(RevenueAnalyticsController());
      ctrl.membershipsRevenue.value = 4250.0;
      ctrl.originalUsdMemberships.value = 50.0;
      ctrl.activeMembersCount.value = 12;
      ctrl.activeTiersCount.value = 3;

      await tester.pumpWidget(
        createHarness(
          Obx(() => buildMembershipsStreamCard(ctrl)),
        ),
      );

      expect(find.text('Channel Memberships & Fan Funding'), findsOneWidget);
      expect(find.text('12 Direct Supporters • 3 Active Tiers'), findsOneWidget);
      expect(find.text('0.0% (₹0.00)'), findsOneWidget);
      expect(find.text('Manage Memberships & Tiers'), findsOneWidget);
    });

    testWidgets('buildSuperchatStreamCard and ad revenue cards display correct earnings', (tester) async {
      final ctrl = Get.put(RevenueAnalyticsController());
      ctrl.superchatRevenue.value = 1000.0;
      ctrl.adsRevenue.value = 2500.0;
      ctrl.watchTimeRevenue.value = 750.0;

      await tester.pumpWidget(
        createHarness(
          Column(
            children: [
              Obx(() => buildSuperchatStreamCard(ctrl)),
              Obx(() => buildAdRevenueStreamCard(ctrl)),
              Obx(() => buildWatchTimeStreamCard(ctrl)),
            ],
          ),
        ),
      );

      expect(find.text('Superchats & Live Fan Support'), findsOneWidget);
      expect(find.text('100% Direct Payout (0% Platform Fee)'), findsOneWidget);
      expect(find.text('Video Ads & Monetization'), findsOneWidget);
      expect(find.text('Watch Time & Premium Royalties'), findsOneWidget);
      expect(find.text('70% Creator Split'), findsNWidgets(2));
    });


    testWidgets('buildRevenueDistributionCard renders stream distribution percentages', (tester) async {
      final ctrl = Get.put(RevenueAnalyticsController());
      ctrl.membershipsRevenue.value = 500.0;
      ctrl.superchatRevenue.value = 200.0;
      ctrl.adsRevenue.value = 200.0;
      ctrl.watchTimeRevenue.value = 100.0;
      ctrl.totalRevenue.value = 1000.0;

      await tester.pumpWidget(
        createHarness(
          Obx(() => buildRevenueDistributionCard(ctrl)),
        ),
      );

      expect(find.text('Revenue Distribution'), findsOneWidget);
      expect(find.text('Memberships: 50%'), findsOneWidget);
      expect(find.text('Superchats: 20%'), findsOneWidget);
      expect(find.text('Ads: 20%'), findsOneWidget);
      expect(find.text('Watch Time: 10%'), findsOneWidget);
    });

    testWidgets('buildWithdrawalThresholdCard handles below and above ₹100 threshold', (tester) async {
      final ctrl = Get.put(RevenueAnalyticsController());
      ctrl.membershipsRevenue.value = 50.0;
      ctrl.totalRevenue.value = 50.0; // below 100

      await tester.pumpWidget(
        createHarness(
          Builder(
            builder: (ctx) => Obx(() => buildWithdrawalThresholdCard(ctx, ctrl)),
          ),
        ),
      );

      expect(find.text('Cash Payout & Withdrawal'), findsOneWidget);
      expect(find.text('Min ₹100'), findsOneWidget);
      expect(find.textContaining('more needed to reach the ₹100'), findsOneWidget);
      expect(find.text('Withdraw Earnings (Minimum ₹100)'), findsOneWidget);

      // Now above threshold
      ctrl.membershipsRevenue.value = 250.0;
      ctrl.totalRevenue.value = 250.0;
      await tester.pump();
      expect(find.text('Unlocked'), findsOneWidget);
      expect(find.text('Withdraw Funds'), findsOneWidget);
    });

    testWidgets('buildDirectBankAccountCard renders unlinked and linked bank account', (tester) async {
      final ctrl = Get.put(RevenueAnalyticsController());

      await tester.pumpWidget(
        createHarness(
          Builder(
            builder: (ctx) => buildDirectBankAccountCard(ctx, ctrl),
          ),
        ),
      );

      expect(find.text('Direct Bank Account Arrangement'), findsOneWidget);
      expect(find.text('Setup Required'), findsOneWidget);
      expect(find.text('Add Bank Account for Direct Payouts'), findsOneWidget);

      // Linked account
      ctrl.savedBankAccount.value = const CreatorBankAccount(
        accountHolderName: 'John Doe',
        accountNumber: '1234567890',
        bankName: 'HDFC Bank',
        ifscCode: 'HDFC0001234',
        accountType: 'savings',
      );
      await tester.pump();
      expect(find.text('Ready for Payout'), findsOneWidget);
      expect(find.textContaining('HDFC Bank'), findsOneWidget);
    });

    testWidgets('buildCreatorKycCard renders unverified, pending, and verified status', (tester) async {
      final ctrl = Get.put(RevenueAnalyticsController());

      await tester.pumpWidget(
        createHarness(
          Builder(
            builder: (ctx) => buildCreatorKycCard(ctx, ctrl),
          ),
        ),
      );

      expect(find.text('Creator Identity Verification (KYC)'), findsOneWidget);
      expect(find.text('Verification Needed'), findsOneWidget);

      // Pending
      ctrl.channelKycStatus.value = 'pending';
      ctrl.creatorKyc.value = const CreatorKycVerification(
        channelId: 'ch_test_1',
        userId: 'user_test_1',
        panNumber: 'ABCDE1234F',
        panLegalName: 'John Doe',
        status: KycStatus.pending,
      );
      await tester.pump();
      expect(find.text('Under Review'), findsOneWidget);

      // Verified
      ctrl.channelKycStatus.value = 'verified';
      ctrl.creatorKyc.value = const CreatorKycVerification(
        channelId: 'ch_test_1',
        userId: 'user_test_1',
        panNumber: 'ABCDE1234F',
        panLegalName: 'John Doe',
        status: KycStatus.verified,
      );
      await tester.pump();
      expect(find.text('KYC Verified'), findsOneWidget);
    });

    testWidgets('RevenueAnalyticsPage full screen coordinator pumps cleanly', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final ctrl = Get.put(RevenueAnalyticsController());
      ctrl.rxIsLoading.value = false;
      ctrl.membershipsRevenue.value = 500.0;
      ctrl.totalRevenue.value = 500.0;

      await tester.pumpWidget(
        GetMaterialApp(
          theme: buildAppTheme(),
          home: const RevenueAnalyticsPage(),
        ),
      );
      await tester.pump();

      expect(find.byType(RevenueAnalyticsPage), findsOneWidget);
      expect(find.text('Revenue Analytics'), findsOneWidget);
    });
  });
}
