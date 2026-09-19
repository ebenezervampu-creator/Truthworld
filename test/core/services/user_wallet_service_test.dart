import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/features/wallet/data/models/user_wallet_transaction.dart';

void main() {
  group('UserWalletTransaction Model Tests', () {
    test('Serializes and deserializes credit transaction correctly', () {
      final now = DateTime(2026, 9, 19, 14);
      final tx = UserWalletTransaction(
        id: 'order_12345',
        userId: 'user_abc',
        amount: 500.0,
        type: UserWalletTransactionType.credit,
        category: UserWalletTransactionCategory.topup,
        description: 'Wallet Top-Up (+₹500.00) via Cashfree',
        balanceBefore: 0.0,
        balanceAfter: 500.0,
        timestamp: now,
        paymentGateway: 'cashfree',
        orderId: 'order_12345',
      );

      expect(tx.isCredit, isTrue);
      expect(tx.isDebit, isFalse);
      expect(tx.formattedAmountWithSign, equals('+₹500.00'));
      expect(tx.category.displayName, equals('Wallet Top-Up'));

      final map = tx.toMap();
      expect(map['id'], equals('order_12345'));
      expect(map['userId'], equals('user_abc'));
      expect(map['amount'], equals(500.0));
      expect(map['type'], equals('credit'));
      expect(map['category'], equals('topup'));
      expect(map['balanceBefore'], equals(0.0));
      expect(map['balanceAfter'], equals(500.0));
      expect(map['paymentGateway'], equals('cashfree'));

      final reconstructed = UserWalletTransaction.fromMap(map, 'order_12345');
      expect(reconstructed.id, equals('order_12345'));
      expect(reconstructed.amount, equals(500.0));
      expect(reconstructed.type, equals(UserWalletTransactionType.credit));
      expect(reconstructed.category, equals(UserWalletTransactionCategory.topup));
      expect(reconstructed.balanceBefore, equals(0.0));
      expect(reconstructed.balanceAfter, equals(500.0));
    });

    test('Serializes and deserializes debit transaction correctly', () {
      final now = DateTime(2026, 9, 19, 14, 30);
      final tx = UserWalletTransaction(
        id: 'tx_spend_999',
        userId: 'user_abc',
        amount: 100.0,
        type: UserWalletTransactionType.debit,
        category: UserWalletTransactionCategory.superchat,
        description: 'Superchat on Breaking News (-₹100.00)',
        balanceBefore: 500.0,
        balanceAfter: 400.0,
        timestamp: now,
        metadata: {'videoId': 'video_xyz', 'tierColor': '#1E88E5'},
      );

      expect(tx.isCredit, isFalse);
      expect(tx.isDebit, isTrue);
      expect(tx.formattedAmountWithSign, equals('-₹100.00'));
      expect(tx.category.displayName, equals('Superchat'));

      final map = tx.toMap();
      expect(map['type'], equals('debit'));
      expect(map['category'], equals('superchat'));
      expect(map['balanceBefore'], equals(500.0));
      expect(map['balanceAfter'], equals(400.0));
      expect(map['metadata'], isNotNull);
      expect(map['metadata']['videoId'], equals('video_xyz'));

      final reconstructed = UserWalletTransaction.fromMap(map, 'tx_spend_999');
      expect(reconstructed.id, equals('tx_spend_999'));
      expect(reconstructed.isDebit, isTrue);
      expect(reconstructed.category, equals(UserWalletTransactionCategory.superchat));
      expect(reconstructed.balanceAfter, equals(400.0));
    });

    test('Category parsing handles unknown string gracefully', () {
      expect(
        UserWalletTransactionCategory.fromString('unknown_category'),
        equals(UserWalletTransactionCategory.other),
      );
      expect(
        UserWalletTransactionCategory.fromString(null),
        equals(UserWalletTransactionCategory.other),
      );
      expect(
        UserWalletTransactionCategory.fromString('membership'),
        equals(UserWalletTransactionCategory.membership),
      );
      expect(
        UserWalletTransactionCategory.fromString('tip'),
        equals(UserWalletTransactionCategory.tip),
      );
      expect(
        UserWalletTransactionCategory.fromString('premium'),
        equals(UserWalletTransactionCategory.premium),
      );
      expect(
        UserWalletTransactionCategory.fromString('ppv'),
        equals(UserWalletTransactionCategory.ppv),
      );
      expect(
        UserWalletTransactionCategory.fromString('refund'),
        equals(UserWalletTransactionCategory.refund),
      );
    });

    test('Type parsing handles unknown string gracefully', () {
      expect(
        UserWalletTransactionType.fromString('credit'),
        equals(UserWalletTransactionType.credit),
      );
      expect(
        UserWalletTransactionType.fromString('debit'),
        equals(UserWalletTransactionType.debit),
      );
      expect(
        UserWalletTransactionType.fromString('CREDIT'),
        equals(UserWalletTransactionType.credit),
      );
      expect(
        UserWalletTransactionType.fromString(null),
        equals(UserWalletTransactionType.debit),
      );
      expect(
        UserWalletTransactionType.fromString('anything_else'),
        equals(UserWalletTransactionType.debit),
      );
    });
  });
}
