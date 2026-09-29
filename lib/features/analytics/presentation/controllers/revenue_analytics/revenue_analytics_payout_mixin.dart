import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/analytics/data/models/creator_bank_account.dart';
import 'package:truthworld/features/analytics/presentation/controllers/revenue_analytics/revenue_analytics_state_base.dart';

/// Mixin handling creator withdrawal requests, bank account storage, and direct bank transfers.
mixin RevenueAnalyticsPayoutMixin on RevenueAnalyticsStateBase {
  /// Submits a general payout withdrawal request to 'payout_requests'.
  Future<bool> submitWithdrawalRequest({
    required double amount,
    required String paymentMethod,
    required String accountDetails,
  }) async {
    if (isWithdrawalHeld.value) {
      AppSnackbar.warning(
        withdrawalHoldReason.value.isNotEmpty
            ? withdrawalHoldReason.value
            : 'TruthWorld has covered 100% of your viral infrastructure surge costs. Please upgrade your custom channel plan to release revenue withdrawals.',
        title: 'Withdrawal On Hold',
      );
      return false;
    }

    if (amount < RevenueAnalyticsStateBase.minimumWithdrawalAmount) {
      AppSnackbar.warning(
        'Minimum withdrawal amount is ₹${RevenueAnalyticsStateBase.minimumWithdrawalAmount.toInt()} (100 Rupees).',
      );
      return false;
    }

    if (amount > totalRevenue.value) {
      AppSnackbar.warning(
        'Requested amount exceeds your available balance of ₹${totalRevenue.value.toStringAsFixed(2)}.',
      );
      return false;
    }

    try {
      isSubmittingWithdrawal.value = true;
      final sanitizedAmount = double.parse(amount.toStringAsFixed(2));
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final payoutRef = firestore.collection('payout_requests').doc();

      await payoutRef.set({
        'id': payoutRef.id,
        'userId': uid,
        'channelId': channelId.value,
        'channelName': channelName.value,
        'amount': sanitizedAmount,
        'currency': RevenueAnalyticsStateBase.currencyCode,
        'currencySymbol': RevenueAnalyticsStateBase.currencySymbol,
        'paymentMethod': paymentMethod,
        'accountDetails': accountDetails,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      isSubmittingWithdrawal.value = false;
      AppSnackbar.success(
        'Withdrawal request of ₹${amount.toStringAsFixed(2)} (Rupees) submitted successfully. Funds will be transferred to your registered account.',
      );
      return true;
    } catch (e, stackTrace) {
      isSubmittingWithdrawal.value = false;
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'RevenueAnalyticsPayoutMixin.submitWithdrawalRequest',
      );
      AppSnackbar.error(
        'Unable to submit withdrawal request. Please check your connection and try again.',
      );
      return false;
    }
  }

  /// Saves the creator's bank account to channel and user payout settings for future 1-click payouts.
  Future<bool> saveBankAccount(CreatorBankAccount account) async {
    final chId = channelId.value;
    if (chId.isEmpty) return false;

    try {
      isLoadingBankAccount.value = true;
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

      final batch = firestore.batch();

      // 1. Channel Payout Settings
      final channelBankRef = firestore
          .collection(FirestoreCollections.channels)
          .doc(chId)
          .collection('payout_settings')
          .doc('bank_account');
      batch.set(channelBankRef, account.toMap(), SetOptions(merge: true));

      // 2. User Payout Settings Fallback
      if (uid.isNotEmpty) {
        final userBankRef = firestore
            .collection(FirestoreCollections.users)
            .doc(uid)
            .collection('payout_settings')
            .doc('bank_account');
        batch.set(userBankRef, account.toMap(), SetOptions(merge: true));
      }

      await batch.commit();
      savedBankAccount.value = account;
      isLoadingBankAccount.value = false;
      AppSnackbar.success(
        'Bank account for direct payouts saved successfully.',
      );
      return true;
    } catch (e, stackTrace) {
      isLoadingBankAccount.value = false;
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'RevenueAnalyticsPayoutMixin.saveBankAccount',
      );
      AppSnackbar.error(
        'Unable to save bank account. Please check your connection and try again.',
      );
      return false;
    }
  }

  /// Processes withdrawal directly to the creator's bank account with full validation.
  Future<bool> submitDirectBankWithdrawal({
    required double amount,
    required CreatorBankAccount bankAccount,
    bool saveAsDefault = true,
  }) async {
    // 0. Custom Channel Viral Surge Withdrawal Hold Gate
    if (isWithdrawalHeld.value) {
      AppSnackbar.warning(
        withdrawalHoldReason.value.isNotEmpty
            ? withdrawalHoldReason.value
            : 'TruthWorld has covered 100% of your viral infrastructure surge costs. Please upgrade your custom channel plan to release revenue withdrawals.',
        title: 'Withdrawal On Hold',
      );
      return false;
    }

    // 1. Mandatory KYC Verification Gate
    if (!isKycVerified) {
      AppSnackbar.warning(
        'KYC document verification (PAN & ID) is required before withdrawing earnings. Please complete verification first.',
      );
      return false;
    }

    if (amount < RevenueAnalyticsStateBase.minimumWithdrawalAmount) {
      AppSnackbar.warning(
        'Minimum withdrawal amount is ₹${RevenueAnalyticsStateBase.minimumWithdrawalAmount.toInt()} (100 Rupees).',
      );
      return false;
    }

    if (amount > totalRevenue.value) {
      AppSnackbar.warning(
        'Requested amount exceeds your available balance of ₹${totalRevenue.value.toStringAsFixed(2)}.',
      );
      return false;
    }

    if (!CreatorBankAccount.isValidAccountNumber(bankAccount.accountNumber)) {
      AppSnackbar.warning(
        'Please enter a valid bank account number (9 to 18 digits).',
      );
      return false;
    }

    if (!CreatorBankAccount.isValidIfsc(bankAccount.ifscCode)) {
      AppSnackbar.warning(
        'Please enter a valid 11-character Indian IFSC code (e.g. SBIN0001234).',
      );
      return false;
    }

    if (bankAccount.accountHolderName.trim().isEmpty) {
      AppSnackbar.warning(
        'Please enter the Account Holder Name as registered with your bank.',
      );
      return false;
    }

    try {
      isSubmittingWithdrawal.value = true;

      if (saveAsDefault) {
        await saveBankAccount(bankAccount);
      }

      final sanitizedAmount = double.parse(amount.toStringAsFixed(2));
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final payoutRef = firestore.collection('payout_requests').doc();

      await payoutRef.set({
        'id': payoutRef.id,
        'userId': uid,
        'channelId': channelId.value,
        'channelName': channelName.value,
        'amount': sanitizedAmount,
        'currency': RevenueAnalyticsStateBase.currencyCode,
        'currencySymbol': RevenueAnalyticsStateBase.currencySymbol,
        'paymentMethod': 'direct_bank_transfer',
        'payoutDestination': 'Direct Bank Account (NEFT/IMPS)',
        'beneficiaryName': bankAccount.accountHolderName.trim(),
        'bankName': bankAccount.bankName.trim(),
        'accountNumber': bankAccount.accountNumber.trim(),
        'accountNumberMasked': bankAccount.maskedAccountNumber,
        'ifscCode': bankAccount.formattedIfsc,
        'accountType': bankAccount.accountType,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      isSubmittingWithdrawal.value = false;
      AppSnackbar.success(
        'Withdrawal request of ₹${amount.toStringAsFixed(2)} to ${bankAccount.bankName} (${bankAccount.maskedAccountNumber}) submitted successfully! Direct transfer is being processed.',
      );
      return true;
    } catch (e, stackTrace) {
      isSubmittingWithdrawal.value = false;
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'RevenueAnalyticsPayoutMixin.submitDirectBankWithdrawal',
      );
      AppSnackbar.error(
        'Unable to process bank withdrawal. Please check your connection and try again.',
      );
      return false;
    }
  }
}
