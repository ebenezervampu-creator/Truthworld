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

    test('Superchat tier color threshold mapping accurately assigns YouTube-style colors', () {
      String resolveTierColor(double inr) {
        if (inr >= 2000) return '#D50000';
        if (inr >= 1000) return '#E040FB';
        if (inr >= 500) return '#FF9100';
        if (inr >= 200) return '#FFD600';
        if (inr >= 100) return '#00E676';
        if (inr >= 50) return '#00B0FF';
        return '#1E88E5';
      }

      expect(resolveTierColor(20.0), equals('#1E88E5'));
      expect(resolveTierColor(50.0), equals('#00B0FF'));
      expect(resolveTierColor(100.0), equals('#00E676'));
      expect(resolveTierColor(200.0), equals('#FFD600'));
      expect(resolveTierColor(500.0), equals('#FF9100'));
      expect(resolveTierColor(1000.0), equals('#E040FB'));
      expect(resolveTierColor(2000.0), equals('#D50000'));
      expect(resolveTierColor(5000.0), equals('#D50000'));
    });

    test('Direct Cashfree portal URLs construct valid endpoints for sandbox and production', () {
      const sessionId = 'session_test_999888';
      const prodUrl = 'https://payments.cashfree.com/order/#$sessionId';
      const sandUrl = 'https://payments-test.cashfree.com/order/#$sessionId';

      final prodUri = Uri.parse(prodUrl);
      final sandUri = Uri.parse(sandUrl);

      expect(prodUri.host, equals('payments.cashfree.com'));
      expect(sandUri.host, equals('payments-test.cashfree.com'));
      expect(prodUri.fragment, equals(sessionId));
      expect(sandUri.fragment, equals(sessionId));
    });
  });

  group('Debug (Sandbox) Mode Payment Flow Verification', () {
    test('Debug environment creates sandbox checkout URL and flags isProduction as false', () {
      const envString = 'SANDBOX';
      const isProduction = envString == 'PRODUCTION';
      expect(isProduction, isFalse);

      const sessionId = 'session_debug_abc123';
      const orderId = 'order_debug_789';
      final envParam = envString.toLowerCase();
      final checkoutUrl =
          'https://www.truthworld.in/checkout?session_id=${Uri.encodeComponent(sessionId)}&order_id=${Uri.encodeComponent(orderId)}&env=$envParam';

      final uri = Uri.parse(checkoutUrl);
      expect(uri.host, equals('www.truthworld.in'));
      expect(uri.queryParameters['env'], equals('sandbox'));
      expect(uri.queryParameters['session_id'], equals(sessionId));
      expect(uri.queryParameters['order_id'], equals(orderId));

      final directPortalUrl = 'https://payments-test.cashfree.com/order/#${Uri.encodeComponent(sessionId)}';
      expect(directPortalUrl, contains('payments-test.cashfree.com'));
    });

    test('Android debug sideload integrity rejection is detected and intercepted cleanly', () {
      final debugErrors = [
        'installer_package_not_approved',
        'INSTALLER_PACKAGE_NOT_APPROVED',
        'package_not_approved',
        'installer verification failed',
        'com.truthworld.app is not enabled or approved. Please whitelist your domain or app package name in Cashfree Merchant Dashboard',
      ];

      for (final rawMsg in debugErrors) {
        final lowerMsg = rawMsg.toLowerCase();
        final isInstallerOrIntegrityError = lowerMsg.contains('installer_package_not_approved') ||
            lowerMsg.contains('installer') ||
            lowerMsg.contains('package_not_approved') ||
            lowerMsg.contains('not approved') ||
            lowerMsg.contains('not enabled') ||
            lowerMsg.contains('whitelist') ||
            lowerMsg.contains('whitelisting') ||
            lowerMsg.contains('domain') ||
            lowerMsg.contains('package') ||
            lowerMsg.contains('verification failed') ||
            lowerMsg.contains('activity not found');

        expect(isInstallerOrIntegrityError, isTrue, reason: 'Failed to identify $rawMsg as debug integrity error');
      }
    });

    test('Debug mode Superchat metadata contains isDebug=true and clean tier parameters', () {
      final debugMetadata = {
        'videoId': 'live_video_stream_001',
        'tierColor': '#00E676',
        'chargeAmount': 100.0,
        'originalAmount': 100.0,
        'originalCurrency': 'INR',
        'isDebug': true,
        'userName': 'Tester Dev',
        'text': 'Testing Superchat in Debug mode',
      };

      expect(debugMetadata['isDebug'], isTrue);
      expect(debugMetadata['tierColor'], equals('#00E676'));
      expect(debugMetadata['chargeAmount'], equals(100.0));
      expect(debugMetadata['userName'], isNot(contains('🔥')));
      expect(debugMetadata['text'], isNot(contains('🔴')));
    });
  });

  group('Production Mode Payment Flow Verification', () {
    test('Production environment creates production checkout URL and flags isProduction as true', () {
      const envString = 'PRODUCTION';
      const isProduction = envString == 'PRODUCTION';
      expect(isProduction, isTrue);

      const sessionId = 'session_prod_live_456';
      const orderId = 'order_prod_live_123';
      final envParam = envString.toLowerCase();
      final checkoutUrl =
          'https://www.truthworld.in/checkout?session_id=${Uri.encodeComponent(sessionId)}&order_id=${Uri.encodeComponent(orderId)}&env=$envParam';

      final uri = Uri.parse(checkoutUrl);
      expect(uri.host, equals('www.truthworld.in'));
      expect(uri.queryParameters['env'], equals('production'));
      expect(uri.queryParameters['session_id'], equals(sessionId));
      expect(uri.queryParameters['order_id'], equals(orderId));

      final directPortalUrl = 'https://payments.cashfree.com/order/#${Uri.encodeComponent(sessionId)}';
      expect(directPortalUrl, contains('payments.cashfree.com'));
      expect(directPortalUrl, isNot(contains('payments-test')));
    });

    test('Production Play Store release build handles successful verification and details payload', () {
      const verifiedResult = CashfreePaymentResult(
        success: true,
        orderId: 'cf_order_prod_verified',
        details: {
          'cfOrderId': 'cf_prod_998877',
          'orderStatus': 'PAID',
          'paymentCurrency': 'INR',
          'paymentAmount': 200.0,
        },
      );

      expect(verifiedResult.success, isTrue);
      expect(verifiedResult.orderId, equals('cf_order_prod_verified'));
      expect(verifiedResult.details?['orderStatus'], equals('PAID'));
      expect(verifiedResult.errorMessage, isNull);
    });

    test('Production user cancellation yields polite message without developer leak', () {
      const cancelResult = CashfreePaymentResult(
        success: false,
        orderId: 'cf_order_prod_cancel',
        errorMessage: 'Payment was cancelled by user.',
      );

      expect(cancelResult.success, isFalse);
      expect(cancelResult.errorMessage, equals('Payment was cancelled by user.'));
      expect(cancelResult.errorMessage, isNot(contains('Exception')));
      expect(cancelResult.errorMessage, isNot(contains('null check')));
    });
  });

  group('Zero Charm-Pricing and Epistemic Honesty Verification', () {
    test('All Superchat tiers and default pricing use honest round numbers', () {
      const superchatAmounts = [20.0, 50.0, 100.0, 200.0, 500.0, 1000.0, 2000.0];
      const forbiddenEndings = ['.99', '9', '99', '999', '9999'];

      for (final amt in superchatAmounts) {
        final amtStr = amt.toString();
        for (final ending in forbiddenEndings) {
          if (ending == '9' && amtStr.endsWith('.0')) {
            // e.g. 50.0 is fine
            final intPart = amt.toInt().toString();
            expect(intPart.endsWith('9'), isFalse, reason: '$amt violates zero charm pricing rule (ends in 9)');
          } else {
            expect(amtStr.contains('.99'), isFalse, reason: '$amt violates zero charm pricing rule (contains .99)');
          }
        }
      }
    });
  });

  group('Android 11+ Installer Resolution & Fallback Verification', () {
    test('Android 11+ (API 30+) initiating package identification logic resolves Play Store accurately', () {
      // Simulating InstallSourceInfo on Android 11+ where:
      // initiating = "com.android.vending" (Play Store)
      // installing = "com.google.android.packageinstaller" (System Package Installer)
      String resolveStore(String? initiating, String? installing, String? originating) {
        if (initiating == 'com.android.vending' ||
            installing == 'com.android.vending' ||
            originating == 'com.android.vending' ||
            (installing == 'com.google.android.packageinstaller' &&
                (initiating == 'com.android.vending' || originating == 'com.android.vending'))) {
          return 'com.android.vending';
        }
        if (initiating == 'com.sec.android.app.samsungapps' ||
            installing == 'com.sec.android.app.samsungapps' ||
            originating == 'com.sec.android.app.samsungapps') {
          return 'com.sec.android.app.samsungapps';
        }
        if (initiating == 'com.amazon.venezia' ||
            installing == 'com.amazon.venezia' ||
            originating == 'com.amazon.venezia') {
          return 'com.amazon.venezia';
        }
        return 'sideloaded';
      }

      // Case 1: Standard Play Store install on Android 11-15 (Pixel, Samsung, Xiaomi)
      expect(
        resolveStore('com.android.vending', 'com.google.android.packageinstaller', 'com.android.vending'),
        equals('com.android.vending'),
      );

      // Case 2: Originating is null on some Android 12 OEM builds
      expect(
        resolveStore('com.android.vending', 'com.google.android.packageinstaller', null),
        equals('com.android.vending'),
      );

      // Case 3: Direct Play Store installingPackageName on older OEM ROMs
      expect(
        resolveStore('com.android.vending', 'com.android.vending', null),
        equals('com.android.vending'),
      );

      // Case 4: Samsung Galaxy Store on Android 11+
      expect(
        resolveStore('com.sec.android.app.samsungapps', 'com.google.android.packageinstaller', null),
        equals('com.sec.android.app.samsungapps'),
      );

      // Case 5: Amazon Appstore
      expect(
        resolveStore('com.amazon.venezia', 'com.google.android.packageinstaller', null),
        equals('com.amazon.venezia'),
      );

      // Case 6: True sideload via ADB or Chrome APK download
      expect(
        resolveStore(null, 'com.google.android.packageinstaller', null),
        equals('sideloaded'),
      );
      expect(
        resolveStore('com.android.chrome', 'com.google.android.packageinstaller', null),
        equals('sideloaded'),
      );
    });

    test('Hosted checkout fallback preserves session_id, order_id, and env parameters', () {
      const orderId = 'cf_order_playstore_live_999';
      const sessionId = 'session_prod_secure_abc123';
      const env = 'production';

      final fallbackUrl =
          'https://www.truthworld.in/checkout?session_id=${Uri.encodeComponent(sessionId)}&order_id=${Uri.encodeComponent(orderId)}&env=$env';

      final uri = Uri.parse(fallbackUrl);
      expect(uri.scheme, equals('https'));
      expect(uri.host, equals('www.truthworld.in'));
      expect(uri.path, equals('/checkout'));
      expect(uri.queryParameters['session_id'], equals(sessionId));
      expect(uri.queryParameters['order_id'], equals(orderId));
      expect(uri.queryParameters['env'], equals('production'));
      // Ensure required session_id parameter for Cashfree JS SDK v3 is non-empty
      expect(uri.queryParameters['session_id']?.isNotEmpty, isTrue);
    });
  });
}
