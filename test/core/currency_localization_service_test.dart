import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/cashfree_service.dart';
import 'package:truthworld/core/services/currency_localization_service.dart';
import 'package:truthworld/features/analytics/presentation/controllers/revenue_analytics_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/memberships_controller.dart';
import 'package:truthworld/features/premium/presentation/controllers/premium_controller.dart';
import '../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CurrencyLocalizationService currencyService;

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (methodCall) async => '.',
    );
    await GetStorage.init();
    await setupMockFirebase();
    CurrencyLocalizationService.enablePersistentStorage = false;
    CashfreePaymentService.enableNativeGateway = false;
  });

  tearDownAll(() {
    CurrencyLocalizationService.enablePersistentStorage = true;
    CashfreePaymentService.enableNativeGateway = true;
  });

  setUp(() {
    Get.reset();
    Get.testMode = true;
    if (!Get.isRegistered<AuthService>()) {
      Get.put<AuthService>(AuthService(), permanent: true);
    }
    currencyService = Get.put(CurrencyLocalizationService());
  });

  tearDown(Get.reset);

  group('CurrencyLocalizationService Tests', () {
    test('Defaults to Indian user when no country or non-US locale is set', () {
      currencyService.currencyOverride.value = null;
      expect(CurrencyLocalizationService.usdToInrRate, 84.0);
      expect(currencyService.rate, 84.0);
    });

    test('Non-Indian user detection when country is US', () {
      currencyService.currencyOverride.value = 'USD';
      expect(currencyService.isIndianUser, isFalse);
      expect(currencyService.activeUserCurrency, 'USD');
      expect(currencyService.activeUserCurrencySymbol, r'$');
    });

    test('Indian user detection when country is IN', () {
      currencyService.currencyOverride.value = 'INR';
      expect(currencyService.isIndianUser, isTrue);
      expect(currencyService.activeUserCurrency, 'INR');
      expect(currencyService.activeUserCurrencySymbol, '₹');
    });

    test('Converts USD to INR correctly at live exchange rate', () {
      currencyService.liveUsdToInrRate.value = 95.60;
      expect(currencyService.convertUsdToInr(1.0), 95.60);
      expect(currencyService.convertUsdToInr(0.10), 9.56);
      expect(currencyService.convertUsdToInr(2.0), 191.20);
    });

    test('Converts INR to USD correctly', () {
      currencyService.liveUsdToInrRate.value = 95.60;
      expect(currencyService.convertInrToUsd(95.60), 1.0);
      expect(currencyService.convertInrToUsd(191.20), 2.0);
    });

    test('formatForUser formats in USD for non-Indian viewers', () {
      currencyService.currencyOverride.value = 'USD';
      currencyService.liveUsdToInrRate.value = 95.60;
      final formatted = currencyService.formatForUser(price: 95.60, itemCurrency: 'INR');
      expect(formatted, r'$1.00');

      final formattedUsd = currencyService.formatForUser(price: 5.0, itemCurrency: 'USD');
      expect(formattedUsd, r'$5.00');
    });

    test('formatForUser formats in INR for Indian viewers', () {
      currencyService.currencyOverride.value = 'INR';
      currencyService.liveUsdToInrRate.value = 95.96;
      final formatted = currencyService.formatForUser(price: 1.0, itemCurrency: 'USD');
      expect(formatted, '₹95.96');

      final formattedInr = currencyService.formatForUser(price: 100.0, itemCurrency: 'INR');
      expect(formattedInr, '₹100');
    });
  });

  group('ChannelMembershipTier & ChannelMember currency localization', () {
    test(r'Formats $1.00 USD tier dynamically to ₹95.96 for Indian viewer rather than hardcoded ₹85', () {
      currencyService.liveUsdToInrRate.value = 95.96;

      final tierUsd1 = ChannelMembershipTier(
        id: 'tier_lover',
        name: 'lover',
        price: 1.0,
        badgeColorHex: '#FF5722',
        perks: const ['Loyalty badge', 'Custom emojis', 'Early access'],
      );

      // Non-Indian viewer sees $1.00
      expect(tierUsd1.formattedPriceForUser(false), r'$1.00');
      // Indian viewer sees live converted ₹95.96
      expect(tierUsd1.formattedPriceForUser(true), '₹95.96');
    });

    test('Formats tier in USD for non-Indian viewer and INR for Indian viewer', () {
      currencyService.liveUsdToInrRate.value = 95.60;
      final tierInr = ChannelMembershipTier(
        id: 'tier_supporter',
        name: 'Supporter',
        price: 95.60,
        currency: 'INR',
        badgeColorHex: '#FF5722',
        perks: const ['Member badge', 'Custom emojis'],
      );

      // Non-Indian viewer
      expect(tierInr.formattedPriceForUser(false), r'$1.00');
      // Indian viewer
      expect(tierInr.formattedPriceForUser(true), '₹95.60');

      final tierUsd = ChannelMembershipTier(
        id: 'tier_vip',
        name: 'VIP',
        price: 2.0,
        badgeColorHex: '#FFD700',
        badgeIcon: 'crown',
        perks: const ['All Supporter perks', 'VIP badge'],
      );

      // Non-Indian viewer
      expect(tierUsd.formattedPriceForUser(false), r'$2.00');
      // Indian viewer
      expect(tierUsd.formattedPriceForUser(true), '₹191.20');
    });

    test('ChannelMember formats membership price according to viewer nationality', () {
      currencyService.liveUsdToInrRate.value = 85.0;
      final member = ChannelMember(
        userId: 'user_1',
        userName: 'Fan',
        userAvatarUrl: '',
        tierId: 'tier_1',
        tierName: 'Gold',
        price: 170.0,
        currency: 'INR',
        joinedAt: DateTime.now(),
      );

      expect(member.formattedPriceForUser(false), r'$2.00');
      expect(member.formattedPriceForUser(true), '₹170');
    });
  });

  group('PremiumController USD vs INR localization', () {
    test('Calculates correct USD prices and proration upgrades for non-Indian viewers', () {
      currencyService.currencyOverride.value = 'USD';
      final premiumCtrl = Get.put(PremiumController());

      expect(premiumCtrl.getPriceUSDForPlan('audio_monthly'), 0.50);
      expect(premiumCtrl.getPriceUSDForPlan('individual_monthly'), 2.0);
      expect(premiumCtrl.getPriceUSDForPlan('4k_factchecked_monthly'), 3.0);

      expect(premiumCtrl.getFormattedPrice('audio_monthly'), r'$0.50');
      expect(premiumCtrl.getFormattedPrice('individual_monthly'), r'$2');
      expect(premiumCtrl.getFormattedPrice('4k_factchecked_monthly'), r'$3');
    });

    test('Calculates correct INR prices for Indian viewers', () {
      currencyService.currencyOverride.value = 'INR';
      final premiumCtrl = Get.put(PremiumController());

      expect(premiumCtrl.getPriceForPlan('audio_monthly'), 40.0);
      expect(premiumCtrl.getPriceForPlan('individual_monthly'), 169.0);
      expect(premiumCtrl.getPriceForPlan('4k_factchecked_monthly'), 249.0);

      expect(premiumCtrl.getFormattedPrice('audio_monthly'), '₹40');
      expect(premiumCtrl.getFormattedPrice('individual_monthly'), '₹169');
      expect(premiumCtrl.getFormattedPrice('4k_factchecked_monthly'), '₹249');
    });
  });

  group('Real-Time Dollar Pricing Tests', () {
    test('Reacts dynamically to live market rate updates', () {
      // Market rate changes from 85.0 to 96.0
      currencyService.liveUsdToInrRate.value = 96.0;
      expect(currencyService.rate, 96.0);
      expect(CurrencyLocalizationService.usdToInrRate, 96.0);

      // USD to INR conversion with live rate
      expect(currencyService.convertUsdToInr(1.0), 96.0);
      expect(currencyService.convertUsdToInr(2.0), 192.0);

      // INR to USD conversion with live rate
      expect(currencyService.convertInrToUsd(96.0), 1.0);
      expect(currencyService.convertInrToUsd(192.0), 2.0);

      // Tier price formats with live rate
      final tier = ChannelMembershipTier(
        id: 'tier_test',
        name: 'Supporter',
        price: 96.0,
        currency: 'INR',
        badgeColorHex: '#FF5722',
        perks: const ['Perk 1'],
      );
      // For non-Indian viewer, ₹96 / 96.0 = $1.00
      expect(tier.formattedPriceForUser(false), r'$1.00');
      // For Indian viewer, ₹96
      expect(tier.formattedPriceForUser(true), '₹96');
    });

    test('Live rate updates trigger reactive recalculation in RevenueAnalyticsController', () {
      final revCtrl = Get.put(RevenueAnalyticsController());
      revCtrl.originalUsdMemberships.value = 1.0;
      revCtrl.originalInrMemberships.value = 0.0;

      // When rate is 85.0
      currencyService.liveUsdToInrRate.value = 85.0;
      expect(revCtrl.membershipsRevenueINR.value, 85.0);

      // When live market rate jumps to 96.0
      currencyService.liveUsdToInrRate.value = 96.0;
      expect(revCtrl.membershipsRevenueINR.value, 96.0);
    });
  });

  group('Critical Bug & Edge Case Resilience Tests', () {
    test('Handles NaN, Infinite, zero, and negative exchange rates by falling back safely to defaultRate', () {
      // NaN rate fallback
      currencyService.liveUsdToInrRate.value = double.nan;
      expect(currencyService.rate, CurrencyLocalizationService.defaultRate);

      // Infinite rate fallback
      currencyService.liveUsdToInrRate.value = double.infinity;
      expect(currencyService.rate, CurrencyLocalizationService.defaultRate);

      // Negative Infinity fallback
      currencyService.liveUsdToInrRate.value = double.negativeInfinity;
      expect(currencyService.rate, CurrencyLocalizationService.defaultRate);

      // Zero rate fallback
      currencyService.liveUsdToInrRate.value = 0.0;
      expect(currencyService.rate, CurrencyLocalizationService.defaultRate);

      // Negative rate fallback
      currencyService.liveUsdToInrRate.value = -85.0;
      expect(currencyService.rate, CurrencyLocalizationService.defaultRate);

      // Flash-crash / spike corridor violation (< 10 or > 500)
      currencyService.liveUsdToInrRate.value = 5.0;
      expect(currencyService.rate, CurrencyLocalizationService.defaultRate);

      currencyService.liveUsdToInrRate.value = 999999.0;
      expect(currencyService.rate, CurrencyLocalizationService.defaultRate);
    });

    test('Handles NaN, Infinite, zero, and negative prices safely without crashing or throwing', () {
      // Normal rate
      currencyService.liveUsdToInrRate.value = 85.0;

      // USD to INR with NaN or negative
      expect(currencyService.convertUsdToInr(double.nan), 0.0);
      expect(currencyService.convertUsdToInr(double.infinity), 0.0);
      expect(currencyService.convertUsdToInr(-10.0), 0.0);
      expect(currencyService.convertUsdToInr(0.0), 0.0);

      // INR to USD with NaN or negative
      expect(currencyService.convertInrToUsd(double.nan), 0.0);
      expect(currencyService.convertInrToUsd(double.infinity), 0.0);
      expect(currencyService.convertInrToUsd(-10.0), 0.0);
      expect(currencyService.convertInrToUsd(0.0), 0.0);

      // Formatting with invalid inputs
      currencyService.currencyOverride.value = 'USD';
      expect(currencyService.formatForUser(price: double.nan, itemCurrency: 'USD'), r'$0.00');
      expect(currencyService.formatForUser(price: -5.0, itemCurrency: 'USD'), r'$0.00');

      currencyService.currencyOverride.value = 'INR';
      expect(currencyService.formatForUser(price: double.nan, itemCurrency: 'INR'), '₹0');
      expect(currencyService.formatForUser(price: -5.0, itemCurrency: 'INR'), '₹0');
    });

    test('CashfreePaymentService rejects amount < 1.00 and NaN/Infinity with clear error', () async {
      final auth = AuthService.to;
      auth.isAuthenticated.value = true;

      final cashfree = CashfreePaymentService.to;

      // Below ₹1.00 minimum
      final subOneRes = await cashfree.startPayment(
        amount: 0.50,
        purpose: 'test_purpose',
        orderNote: 'Test note',
      );
      expect(subOneRes.success, isFalse);
      expect(subOneRes.errorMessage, contains('at least ₹1.00'));

      // Zero amount
      final zeroRes = await cashfree.startPayment(
        amount: 0.0,
        purpose: 'test_purpose',
        orderNote: 'Test note',
      );
      expect(zeroRes.success, isFalse);

      // NaN amount
      final nanRes = await cashfree.startPayment(
        amount: double.nan,
        purpose: 'test_purpose',
        orderNote: 'Test note',
      );
      expect(nanRes.success, isFalse);
    });
  });
}
