import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/cashfree_service.dart';
import 'package:truthworld/core/services/currency_localization_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/wallet/data/models/user_wallet_transaction.dart';

/// Central production service managing regular user wallet operations,
/// real-time balance tracking, Cashfree PG top-ups, and 1-click in-app spending.
class UserWalletService extends GetxService {
  UserWalletService({FirebaseFirestore? firestore})
      : _firestoreOverride = firestore;

  static UserWalletService get to {
    if (!Get.isRegistered<UserWalletService>()) {
      Get.put(UserWalletService(), permanent: true);
    }
    return Get.find<UserWalletService>();
  }

  final FirebaseFirestore? _firestoreOverride;
  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  final RxBool isProcessing = false.obs;

  /// Current user's reactive wallet balance in INR
  RxDouble get rxBalance {
    if (Get.isRegistered<AuthService>()) {
      return AuthService.to.userWalletBalance;
    }
    return 0.0.obs;
  }

  /// Live numeric balance in INR
  double get balance => rxBalance.value;

  /// Whether current user can afford a given INR cost
  bool canAfford(double amountINR) => balance >= amountINR;

  /// Formatted localized balance string (e.g. "₹500.00" or "$5.23")
  String get formattedBalance {
    if (Get.isRegistered<CurrencyLocalizationService>()) {
      return CurrencyLocalizationService.to.formatForUser(
        price: balance,
        itemCurrency: 'INR',
      );
    }
    return '₹${balance.toStringAsFixed(2)}';
  }

  /// Format an arbitrary amount based on user's current currency
  String formatAmount(double amountINR) {
    if (Get.isRegistered<CurrencyLocalizationService>()) {
      return CurrencyLocalizationService.to.formatForUser(
        price: amountINR,
        itemCurrency: 'INR',
      );
    }
    return '₹${amountINR.toStringAsFixed(2)}';
  }

  /// Top up user wallet with Cashfree Payment Gateway (UPI, Cards, NetBanking).
  Future<bool> topupUserWalletWithCashfree({
    required double amountINR,
    required String userId,
  }) async {
    if (userId.isEmpty) {
      AppSnackbar.warning('Please sign in to add money to your wallet.');
      return false;
    }

    if (amountINR.isNaN || amountINR.isInfinite || amountINR < 1.0) {
      AppSnackbar.warning('Minimum top-up amount is ₹1.00.');
      return false;
    }

    final sanitizedAmount = double.parse(amountINR.toStringAsFixed(2));
    isProcessing.value = true;

    try {
      final paymentResult = await CashfreePaymentService.to.startPayment(
        amount: sanitizedAmount,
        purpose: 'user_wallet_topup',
        orderNote: 'User Wallet Top-Up (₹${sanitizedAmount.toStringAsFixed(0)})',
        metadata: {
          'userId': userId,
          'amountINR': sanitizedAmount,
          'packType': 'user_wallet',
          'category': 'topup',
          'description':
              'User Wallet Deposit (+₹${sanitizedAmount.toStringAsFixed(2)})',
        },
      );

      if (paymentResult.success) {
        await topupUserWalletDirect(
          userId: userId,
          amountINR: sanitizedAmount,
          orderId: paymentResult.orderId,
          description:
              'Wallet Top-Up (+₹${sanitizedAmount.toStringAsFixed(2)}) via Cashfree',
        );

        AppSnackbar.success(
          '₹${sanitizedAmount.toStringAsFixed(2)} added to your wallet successfully! 🎉',
          title: 'Money Added',
        );
        return true;
      } else if (paymentResult.errorMessage != null &&
          !paymentResult.errorMessage!.toLowerCase().contains('cancel')) {
        AppSnackbar.error(paymentResult.errorMessage!);
      }
      return false;
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'UserWalletService.topupUserWalletWithCashfree',
      );
      AppSnackbar.error(
        'Unable to complete wallet top-up. Please try again.',
      );
      return false;
    } finally {
      isProcessing.value = false;
    }
  }

  /// Direct authoritative deposit into `users/{userId}` with subcollection transaction log.
  Future<bool> topupUserWalletDirect({
    required String userId,
    required double amountINR,
    required String orderId,
    String? description,
  }) async {
    if (userId.isEmpty || amountINR <= 0.0) return false;

    try {
      final userRef =
          _firestore.collection(FirestoreCollections.users).doc(userId);
      final txRef = userRef.collection('wallet_transactions').doc(orderId);

      await _firestore.runTransaction((transaction) async {
        final userSnapshot = await transaction.get(userRef);
        final currentBal = userSnapshot.exists
            ? ((userSnapshot.data()?['walletBalance'] as num?)?.toDouble() ??
                0.0)
            : 0.0;
        final newBal = currentBal + amountINR;

        transaction.set(
          userRef,
          {
            'walletBalance': newBal,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        transaction.set(txRef, {
          'id': orderId,
          'userId': userId,
          'amount': amountINR,
          'type': UserWalletTransactionType.credit.name,
          'category': UserWalletTransactionCategory.topup.name,
          'description': description ??
              'Wallet Top-Up (+₹${amountINR.toStringAsFixed(2)})',
          'balanceBefore': currentBal,
          'balanceAfter': newBal,
          'timestamp': FieldValue.serverTimestamp(),
          'paymentGateway': 'cashfree',
          'orderId': orderId,
        });
      });

      return true;
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'UserWalletService.topupUserWalletDirect',
      );
      return false;
    }
  }

  /// Spend from user wallet for Superchats, Memberships, Tipping, or Features.
  Future<UserWalletTransaction?> spendWallet({
    required double amountINR,
    required UserWalletTransactionCategory category,
    required String description,
    Map<String, dynamic>? metadata,
  }) async {
    final auth = AuthService.to;
    final userId = auth.uid;

    if (!auth.isAuthenticated.value || userId.isEmpty) {
      AppSnackbar.warning('Please sign in to spend from your wallet.');
      return null;
    }

    if (amountINR.isNaN || amountINR.isInfinite || amountINR <= 0.0) {
      AppSnackbar.warning('Invalid transaction amount.');
      return null;
    }

    final sanitizedAmount = double.parse(amountINR.toStringAsFixed(2));

    try {
      final userRef =
          _firestore.collection(FirestoreCollections.users).doc(userId);
      final txDocRef = userRef.collection('wallet_transactions').doc();

      UserWalletTransaction? resultingTx;

      await _firestore.runTransaction((transaction) async {
        final userSnapshot = await transaction.get(userRef);
        if (!userSnapshot.exists) {
          throw Exception('User account not found');
        }

        final currentBal =
            (userSnapshot.data()?['walletBalance'] as num?)?.toDouble() ?? 0.0;

        if (currentBal < sanitizedAmount) {
          throw Exception('Insufficient wallet balance');
        }

        final newBal = currentBal - sanitizedAmount;

        transaction.update(userRef, {
          'walletBalance': newBal,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        final txData = {
          'id': txDocRef.id,
          'userId': userId,
          'amount': sanitizedAmount,
          'type': UserWalletTransactionType.debit.name,
          'category': category.name,
          'description': description,
          'balanceBefore': currentBal,
          'balanceAfter': newBal,
          'timestamp': FieldValue.serverTimestamp(),
          'metadata': ?metadata,
        };

        transaction.set(txDocRef, txData);

        resultingTx = UserWalletTransaction(
          id: txDocRef.id,
          userId: userId,
          amount: sanitizedAmount,
          type: UserWalletTransactionType.debit,
          category: category,
          description: description,
          balanceBefore: currentBal,
          balanceAfter: newBal,
          timestamp: DateTime.now(),
          metadata: metadata,
        );
      });

      return resultingTx;
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'UserWalletService.spendWallet',
      );
      if (e.toString().contains('Insufficient')) {
        AppSnackbar.warning(
          'Your wallet balance is low. Please add money to continue.',
          title: 'Insufficient Balance',
        );
      } else {
        AppSnackbar.error(
          'Transaction could not be completed. Please try again.',
        );
      }
      return null;
    }
  }

  /// Real-time stream of user wallet transactions ordered newest first.
  Stream<List<UserWalletTransaction>> streamTransactions(String userId) {
    if (userId.isEmpty) {
      return Stream.value(<UserWalletTransaction>[]);
    }

    return _firestore
        .collection(FirestoreCollections.users)
        .doc(userId)
        .collection('wallet_transactions')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(UserWalletTransaction.fromFirestore)
              .toList(),
        );
  }
}
