import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/currency_localization_service.dart';
import 'package:truthworld/features/advertiser/presentation/controllers/advertiser_portal_controller.dart';
import 'package:truthworld/features/advertiser/presentation/views/advertiser_portal_screen.dart';
import 'package:truthworld/features/analytics/data/models/creator_kyc_verification.dart';
import 'package:truthworld/features/analytics/presentation/controllers/creator_analytics_controller.dart';
import 'package:truthworld/features/analytics/presentation/controllers/revenue_analytics_controller.dart';
import 'package:truthworld/features/analytics/presentation/pages/creator_analytics_dashboard.dart';
import 'package:truthworld/features/analytics/presentation/pages/revenue_analytics_page.dart';
import 'package:truthworld/features/analytics/presentation/pages/subscribers_page.dart';
import 'package:truthworld/features/analytics/presentation/pages/views_page.dart';
import 'package:truthworld/features/analytics/presentation/pages/watch_time_page.dart';
import 'package:truthworld/features/analytics/presentation/widgets/creator_kyc_dialog.dart';
import 'package:truthworld/features/premium/presentation/controllers/premium_controller.dart';
import 'package:truthworld/features/premium/presentation/views/premium_plans_screen.dart';
import 'package:truthworld/features/watchtime/presentation/pages/watchtime_details_page.dart';
import '../test_helpers/mock_firebase.dart';
import 'page_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
    CurrencyLocalizationService.enablePersistentStorage = false;
  });

  tearDownAll(() {
    CurrencyLocalizationService.enablePersistentStorage = true;
  });

  tearDown(Get.reset);

  group('Group 5: Analytics & Monetization Pages', () {
    testWidgets('1. CreatorAnalyticsDashboard renders analytics metrics and charts',
        (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      await pumpPageInHarness(
        tester,
        const CreatorAnalyticsDashboard(),
        onBeforePump: () {
          if (!Get.isRegistered<CreatorAnalyticsController>()) {
            Get.put(CreatorAnalyticsController());
          }
        },
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(CreatorAnalyticsDashboard), findsOneWidget);
    });

    testWidgets('2. WatchTimePage renders watch time overview and breakdown',
        (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      await pumpPageInHarness(
        tester,
        const WatchTimePage(),
        onBeforePump: () {
          if (!Get.isRegistered<CreatorAnalyticsController>()) {
            Get.put(CreatorAnalyticsController());
          }
        },
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(WatchTimePage), findsOneWidget);
    });

    testWidgets('3. ViewsPage renders video and channel view metrics',
        (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      await pumpPageInHarness(
        tester,
        const ViewsPage(),
        onBeforePump: () {
          if (!Get.isRegistered<CreatorAnalyticsController>()) {
            Get.put(CreatorAnalyticsController());
          }
        },
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(ViewsPage), findsOneWidget);
    });

    testWidgets('4. SubscribersPage renders subscriber growth and analytics',
        (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      await pumpPageInHarness(
        tester,
        const SubscribersPage(),
        onBeforePump: () {
          if (!Get.isRegistered<CreatorAnalyticsController>()) {
            Get.put(CreatorAnalyticsController());
          }
        },
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(SubscribersPage), findsOneWidget);
    });

    testWidgets('5. WatchtimeDetailsPage renders video watch time lists',
        (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      await pumpPageInHarness(
        tester,
        const WatchtimeDetailsPage(
          channelId: 'test_channel_123',
          isDarkMode: true,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(WatchtimeDetailsPage), findsOneWidget);
    });

    testWidgets('6. PremiumPlansScreen renders subscription tiers and features',
        (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      await pumpPageInHarness(
        tester,
        const PremiumPlansScreen(),
        onBeforePump: () {
          if (!Get.isRegistered<PremiumController>()) {
            Get.put(PremiumController());
          }
        },
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(PremiumPlansScreen), findsOneWidget);
    });

    testWidgets('7. AdvertiserPortalScreen renders landing and dashboard',
        (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      await pumpPageInHarness(
        tester,
        const AdvertiserPortalScreen(),
        onBeforePump: () {
          if (!Get.isRegistered<AdService>()) {
            Get.put(AdService());
          }
          if (!Get.isRegistered<AdvertiserPortalController>()) {
            Get.put(AdvertiserPortalController());
          }
          AuthService.to.isAuthenticated.value = false;
        },
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(AdvertiserPortalScreen), findsOneWidget);

      // Authenticate to test portal dashboard
      AuthService.to.isAuthenticated.value = true;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(AdvertiserPortalScreen), findsOneWidget);
    });

    testWidgets('8. RevenueAnalyticsPage renders revenue streams and breakdown',
        (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      await pumpPageInHarness(
        tester,
        const RevenueAnalyticsPage(),
        onBeforePump: () {
          final ctrl = !Get.isRegistered<RevenueAnalyticsController>()
              ? Get.put(RevenueAnalyticsController())
              : Get.find<RevenueAnalyticsController>();
          ctrl.channelId.value = 'creator_default';
          ctrl.rxIsLoading.value = false;
        },
      );
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
      expect(find.byType(RevenueAnalyticsPage), findsOneWidget);
      expect(find.text('Cash Payout & Withdrawal'), findsOneWidget);
      expect(find.text('Threshold: ₹100 (100 Rupees)'), findsOneWidget);
    });

    test('9. CreatorKycVerification models and validation logic function correctly', () {
      // PAN validation
      expect(CreatorKycVerification.isValidPan('ABCDE1234F'), isTrue);
      expect(CreatorKycVerification.isValidPan('abcde1234f'), isTrue);
      expect(CreatorKycVerification.isValidPan('ABC12345'), isFalse);
      expect(CreatorKycVerification.isValidPan('12345ABCDE'), isFalse);

      // Age validation
      final adultDob = DateTime.now().subtract(const Duration(days: 365 * 20));
      final childDob = DateTime.now().subtract(const Duration(days: 365 * 15));
      expect(CreatorKycVerification.isValidAge(adultDob), isTrue);
      expect(CreatorKycVerification.isValidAge(childDob), isFalse);

      // Name similarity matching
      final score1 = CreatorKycVerification.calculateNameMatchScore('Ebenezer Vampu', 'Ebenezer Vampu');
      expect(score1, equals(1.0));
      final score2 = CreatorKycVerification.calculateNameMatchScore('Ebenezer Vampu', 'Vampu Ebenezer');
      expect(score2, greaterThanOrEqualTo(0.85));
      final score3 = CreatorKycVerification.calculateNameMatchScore('Mr. Ebenezer Vampu', 'Ebenezer Vampu');
      expect(score3, equals(1.0));
      final score4 = CreatorKycVerification.calculateNameMatchScore('Ebenezer Vampu', 'John Doe');
      expect(score4, lessThan(0.40));
    });

    testWidgets('10. CreatorKycDialog renders and displays KYC verification fields',
        (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      await pumpPageInHarness(
        tester,
        Scaffold(body: Center(child: CreatorKycDialog())),
        onBeforePump: () {
          final ctrl = !Get.isRegistered<RevenueAnalyticsController>()
              ? Get.put(RevenueAnalyticsController())
              : Get.find<RevenueAnalyticsController>();
          ctrl.rxIsLoading.value = false;
        },
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(CreatorKycDialog), findsOneWidget);
      expect(find.text('Creator Verification'), findsOneWidget);
      expect(find.text('1. Permanent Account Number (PAN)'), findsOneWidget);
      expect(find.text('2. Identity & Address Proof'), findsOneWidget);
      expect(find.text('3. Bank Account Name Matching'), findsOneWidget);
      expect(find.text('Submit for Verification'), findsOneWidget);
    });

    test('11. RevenueAnalyticsController converts USD payments to INR and tracks dual currencies', () {
      final currency = Get.isRegistered<CurrencyLocalizationService>()
          ? CurrencyLocalizationService.to
          : Get.put(CurrencyLocalizationService(), permanent: true);
      currency.liveUsdToInrRate.value = 85.00;

      final ctrl = !Get.isRegistered<RevenueAnalyticsController>()
          ? Get.put(RevenueAnalyticsController())
          : Get.find<RevenueAnalyticsController>();

      // Simulate $0.10 USD membership payment from authentic stream calculation
      const usdPrice = 0.10;
      final inrValue = usdPrice * RevenueAnalyticsController.usdToInrRate; // 8.50

      ctrl.superchatRevenue.value = 0.0;
      ctrl.adsRevenue.value = 0.0;
      ctrl.watchTimeRevenue.value = 0.0;
      ctrl.originalUsdMemberships.value = usdPrice;
      ctrl.membershipsRevenueINR.value = inrValue;
      ctrl.membershipsRevenueUSD.value = usdPrice;
      ctrl.membershipsRevenue.value = inrValue;
      ctrl.totalRevenue.value = inrValue;
      ctrl.totalRevenueUSD.value = inrValue / RevenueAnalyticsController.usdToInrRate;

      // In INR view
      ctrl.setCurrencyView('INR');
      expect(ctrl.isViewingINR, isTrue);
      expect(ctrl.totalRevenue.value, equals(8.50));
      expect(ctrl.totalRevenueUSD.value, closeTo(0.10, 0.001));
      expect(ctrl.formatCurrency(8.50), equals('₹8.50'));

      // In USD view
      ctrl.setCurrencyView('USD');
      expect(ctrl.isViewingINR, isFalse);
      expect(ctrl.formatCurrency(8.50), equals(r'$0.10'));
    });

    testWidgets('12. RevenueAnalyticsPage renders currency switcher and USD conversion badges', (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      await pumpPageInHarness(
        tester,
        const RevenueAnalyticsPage(),
        onBeforePump: () {
          final currency = Get.isRegistered<CurrencyLocalizationService>()
              ? CurrencyLocalizationService.to
              : Get.put(CurrencyLocalizationService(), permanent: true);
          currency.liveUsdToInrRate.value = 85.00;

          final ctrl = !Get.isRegistered<RevenueAnalyticsController>()
              ? Get.put(RevenueAnalyticsController())
              : Get.find<RevenueAnalyticsController>();

          ctrl.channelId.value = 'creator_default';
          ctrl.rxIsLoading.value = false;
          ctrl.channelName.value = 'Truth Channel';
          ctrl.superchatRevenue.value = 0.0;
          ctrl.adsRevenue.value = 0.0;
          ctrl.watchTimeRevenue.value = 0.0;
          ctrl.originalUsdMemberships.value = 0.10;
          ctrl.membershipsRevenueINR.value = 8.50;
          ctrl.membershipsRevenueUSD.value = 0.10;
          ctrl.membershipsRevenue.value = 8.50;
          ctrl.totalRevenue.value = 8.50;
          ctrl.totalRevenueUSD.value = 0.10;
          ctrl.setCurrencyView('INR');
        },
      );
      await tester.pump(const Duration(seconds: 3));

      expect(tester.takeException(), isNull);
      expect(find.text('₹ INR'), findsOneWidget);
      expect(find.text(r'$ USD'), findsOneWidget);
      expect(find.text('₹8.50'), findsWidgets);
      expect(find.text(r'Available: ₹8.50 (≈ $0.10 USD)'), findsOneWidget);
      expect(find.text('Exchange Rate: 1 USD = ₹85.00 INR'), findsOneWidget);
    });
  });
}
