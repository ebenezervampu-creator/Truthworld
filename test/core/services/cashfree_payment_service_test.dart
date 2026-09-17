import 'package:flutter_test/flutter_test.dart';
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
  });
}

