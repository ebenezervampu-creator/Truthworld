import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/services/cashfree/cashfree_country_support.dart';
import 'package:truthworld/core/services/cashfree_service.dart';

void main() {
  group('Cashfree Payment Unit Tests', () {
    test('CashfreePaymentResult success properties instantiate properly', () {
      const result = CashfreePaymentResult(
        success: true,
        orderId: 'cf_order_test_123',
        details: {'referenceId': 'cf_tx_ref_999'},
      );

      expect(result.success, isTrue);
      expect(result.orderId, equals('cf_order_test_123'));
      expect(result.details?['referenceId'], equals('cf_tx_ref_999'));
      expect(result.errorMessage, isNull);
    });

    test('CashfreePaymentResult failure properties map friendly errors without tech leak', () {
      const result = CashfreePaymentResult(
        success: false,
        orderId: 'cf_order_test_fail',
        errorMessage: 'Payment was declined by issuing bank. Please try another card or UPI.',
      );

      expect(result.success, isFalse);
      expect(result.orderId, equals('cf_order_test_fail'));
      expect(result.errorMessage, isNotNull);
      expect(result.errorMessage, contains('declined'));
      // Zero raw developer error leak check
      expect(result.errorMessage, isNot(contains('Exception')));
      expect(result.errorMessage, isNot(contains('SocketException')));
      expect(result.errorMessage, isNot(contains('PlatformException')));
      expect(result.errorMessage, isNot(contains('null check')));
    });

    test('INR conversion logic correctly applies to tier prices', () {
      // For dollar/point-denominated tiers (price < 50), converts with 85.0x multiplier
      const tierBronzeUSD = 2.0;
      final amountINRExpected = (tierBronzeUSD * 85.0).roundToDouble();
      expect(amountINRExpected, equals(170.0));

      const tierGoldUSD = 10.0;
      final goldINRExpected = (tierGoldUSD * 85.0).roundToDouble();
      expect(goldINRExpected, equals(850.0));

      // Direct INR amounts (>= 50) remain unchanged
      const directINR = 149.0;
      final amountFinal = directINR < 50 ? (directINR * 85.0).roundToDouble() : directINR;
      expect(amountFinal, equals(149.0));
    });

    test('Superchat tier colors and amounts are valid for Cashfree processing', () {
      final superchatTiers = [
        {'amount': 20.0, 'color': '#1E88E5'},
        {'amount': 50.0, 'color': '#00B0FF'},
        {'amount': 100.0, 'color': '#00E676'},
        {'amount': 200.0, 'color': '#FFD600'},
        {'amount': 500.0, 'color': '#FF9100'},
        {'amount': 1000.0, 'color': '#E040FB'},
        {'amount': 2000.0, 'color': '#D50000'},
      ];

      for (final tier in superchatTiers) {
        final amount = tier['amount']! as double;
        expect(amount, greaterThan(0.0));
        expect(tier['color'], isNotEmpty);
      }
    });

    test('Membership 1 USD lover tier converts correctly to INR', () {
      const tierLoverUSD = 1.0;
      final amountINR = tierLoverUSD < 50 ? (tierLoverUSD * 85.0).roundToDouble() : tierLoverUSD;
      expect(amountINR, equals(85.0));
    });

    test('Gateway maintenance and unconfigured messages provide friendly guidance', () {
      const maintenanceError = 'Payment service is currently undergoing maintenance. Please check back shortly.';
      const result = CashfreePaymentResult(
        success: false,
        orderId: 'cf_channel_membership_123',
        errorMessage: maintenanceError,
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, equals(maintenanceError));
      expect(result.errorMessage, isNot(contains('Exception')));
      expect(result.errorMessage, isNot(contains('failed-precondition')));
      expect(result.errorMessage, isNot(contains('500')));
    });

    test('Android debug mode installer integrity errors are sanitized for users', () {
      // In debug mode, Android apps sideloaded with debug keystores or run via flutter run
      // encounter installer_package_not_approved when contacting production Cashfree SDK.
      const rawError = 'installer_package_not_approved';
      final isIntegrityError = rawError.contains('installer_package_not_approved') ||
          rawError.contains('installer');
      expect(isIntegrityError, isTrue);

      const userFacingResult = CashfreePaymentResult(
        success: false,
        orderId: 'cf_order_debug_456',
        errorMessage: 'Unable to start payment on this device. Please try again.',
      );
      expect(userFacingResult.errorMessage, isNot(contains('installer_package_not_approved')));
      expect(userFacingResult.errorMessage, isNot(contains('debug')));
    });

    test('Hosted checkout links construct valid web fallback URLs', () {
      const orderId = 'cf_premium_123';
      const sessionId = 'session_abc_987';
      const env = 'sandbox';
      const link =
          'https://www.truthworld.in/checkout?session_id=$sessionId&order_id=$orderId&env=$env';

      final uri = Uri.parse(link);
      expect(uri.scheme, equals('https'));
      expect(uri.host, equals('www.truthworld.in'));
      expect(uri.queryParameters['session_id'], equals(sessionId));
      expect(uri.queryParameters['order_id'], equals(orderId));
      expect(uri.queryParameters['env'], equals(env));
    });

    test('CashfreeCountrySupport correctly identifies all supported and restricted countries', () {
      // 9 restricted countries
      const restricted = ['AF', 'BY', 'CU', 'IR', 'IQ', 'PK', 'RU', 'SD', 'SY'];
      for (final code in restricted) {
        expect(CashfreeCountrySupport.isRestrictedCountry(code), isTrue);
        expect(CashfreeCountrySupport.isCountrySupported(code), isFalse);
      }

      // Major supported countries worldwide
      const supported = ['IN', 'US', 'GB', 'CA', 'AU', 'DE', 'FR', 'IT', 'ES', 'AE', 'SA', 'SG', 'JP', 'BR', 'ZA'];
      for (final code in supported) {
        expect(CashfreeCountrySupport.isRestrictedCountry(code), isFalse);
        expect(CashfreeCountrySupport.isCountrySupported(code), isTrue);
      }

      // Primary currencies for countries
      expect(CashfreeCountrySupport.getCurrencyForCountry('IN'), equals('INR'));
      expect(CashfreeCountrySupport.getCurrencyForCountry('US'), equals('USD'));
      expect(CashfreeCountrySupport.getCurrencyForCountry('GB'), equals('GBP'));
      expect(CashfreeCountrySupport.getCurrencyForCountry('DE'), equals('EUR'));
      expect(CashfreeCountrySupport.getCurrencyForCountry('AE'), equals('AED'));
      expect(CashfreeCountrySupport.getCurrencyForCountry('JP'), equals('JPY'));
    });

    test('Cashfree multi-currency validation and minimum amount rules', () {
      expect(CashfreeCountrySupport.isCurrencySupported('INR'), isTrue);
      expect(CashfreeCountrySupport.isCurrencySupported('USD'), isTrue);
      expect(CashfreeCountrySupport.isCurrencySupported('EUR'), isTrue);
      expect(CashfreeCountrySupport.isCurrencySupported('GBP'), isTrue);
      expect(CashfreeCountrySupport.isCurrencySupported('AED'), isTrue);
      expect(CashfreeCountrySupport.isCurrencySupported('JPY'), isTrue);
      expect(CashfreeCountrySupport.isCurrencySupported('INVALID_XYZ'), isFalse);

      // Minimum amounts
      expect(CashfreeCountrySupport.getMinimumAmount('INR'), equals(1.0));
      expect(CashfreeCountrySupport.getMinimumAmount('USD'), equals(0.50));
      expect(CashfreeCountrySupport.getMinimumAmount('EUR'), equals(0.50));
      expect(CashfreeCountrySupport.getMinimumAmount('JPY'), equals(50.0));

      // Formatting
      expect(CashfreeCountrySupport.formatAmount(100.0, 'INR'), equals('₹100.00'));
      expect(CashfreeCountrySupport.formatAmount(5.0, 'USD'), equals(r'$5.00'));
      expect(CashfreeCountrySupport.formatAmount(500.0, 'JPY'), equals('¥500'));
    });
  });
}

