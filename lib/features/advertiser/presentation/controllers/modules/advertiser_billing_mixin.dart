import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/cashfree_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/theme/app_theme.dart';

mixin AdvertiserBillingMixin {
  StreamSubscription<DocumentSnapshot>? _advertiserProfileSub;
  StreamSubscription<QuerySnapshot>? _billingTransactionsSub;

  final RxDouble walletBalance = 0.0.obs;
  final RxBool autoReloadEnabled = false.obs;
  final RxDouble autoReloadThreshold = 200.0.obs;
  final RxDouble autoReloadAmount = 2000.0.obs;
  final RxString billingCompanyName = ''.obs;
  final RxString billingGstin = ''.obs;
  final RxString billingAddress = ''.obs;
  final RxString billingEmail = ''.obs;

  final RxList<Map<String, dynamic>> transactions = <Map<String, dynamic>>[].obs;

  void disposeBilling() {
    _advertiserProfileSub?.cancel();
    _billingTransactionsSub?.cancel();
  }

  void listenToBillingData() {
    _advertiserProfileSub?.cancel();
    _billingTransactionsSub?.cancel();

    final uid = AuthService.to.uid;
    if (uid.isEmpty) {
      walletBalance.value = 0.0;
      transactions.clear();
      return;
    }

    _advertiserProfileSub = FirebaseFirestore.instance
        .collection('advertiser_profiles')
        .doc(uid)
        .snapshots()
        .listen((doc) {
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        walletBalance.value = (data['walletBalance'] as num?)?.toDouble() ?? 0.0;
        if (data['companyName'] != null) billingCompanyName.value = data['companyName'];
        if (data['gstin'] != null) billingGstin.value = data['gstin'];
        if (data['address'] != null) billingAddress.value = data['address'];
        if (data['billingEmail'] != null) billingEmail.value = data['billingEmail'];
        if (data['autoReloadEnabled'] != null) autoReloadEnabled.value = data['autoReloadEnabled'] == true;
        if (data['autoReloadThreshold'] != null) {
          autoReloadThreshold.value = (data['autoReloadThreshold'] as num).toDouble();
        }
        if (data['autoReloadAmount'] != null) {
          autoReloadAmount.value = (data['autoReloadAmount'] as num).toDouble();
        }
      }
    }, onError: (e) {
      ErrorHandler.log(e);
    });

    _billingTransactionsSub = FirebaseFirestore.instance
        .collection('advertiser_profiles')
        .doc(uid)
        .collection('billing_transactions')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snap) {
      transactions.value = snap.docs.map((d) {
        final data = d.data();
        return {
          'id': data['id'] ?? d.id,
          'date': data['date'] ?? 'Recent',
          'description': data['description'] ?? 'Transaction',
          'amount': (data['amount'] as num?)?.toDouble() ?? 0.0,
          'status': data['status'] ?? 'Paid',
          'paymentMethod': data['paymentMethod'] ?? 'Cashfree PG',
          'tax': (data['tax'] as num?)?.toDouble() ?? 0.0,
          'net': (data['net'] as num?)?.toDouble() ?? 0.0,
        };
      }).toList();
    }, onError: (e) {
      ErrorHandler.log(e);
    });
  }

  Future<void> topUpWallet(double amount, {double? netAmount, double? taxAmount}) async {
    if (amount.isNaN || amount.isInfinite || amount < 1.0) {
      AppSnackbar.warning('Minimum wallet recharge amount is ₹1.00.');
      return;
    }

    try {
      final sanitizedAmount = double.parse(amount.toStringAsFixed(2));
      final spendable = netAmount ?? double.parse((sanitizedAmount * (100 / 118)).toStringAsFixed(2));
      final calculatedTax = taxAmount ?? double.parse((sanitizedAmount - spendable).toStringAsFixed(2));

      final paymentResult = await CashfreePaymentService.to.startPayment(
        amount: sanitizedAmount,
        purpose: 'advertiser_wallet',
        orderNote: 'Advertiser Wallet Top-Up',
        metadata: {
          'purpose': 'advertiser_wallet',
          'netAmount': spendable,
          'taxAmount': calculatedTax,
        },
      );

      if (paymentResult.success) {
        walletBalance.value += spendable;
        transactions.insert(0, {
          'id':
              'INV-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
          'date': 'Today',
          'description': 'Wallet Top-Up (Cashfree)',
          'amount': sanitizedAmount,
          'status': 'Paid',
          'paymentMethod': 'Cashfree PG',
          'tax': calculatedTax,
          'net': spendable,
        });

        AppSnackbar.success(
          '₹${spendable.toStringAsFixed(2)} added to your advertiser wallet balance successfully.',
          title: 'Wallet Recharged',
        );
      } else if (paymentResult.errorMessage != null &&
          !paymentResult.errorMessage!.toLowerCase().contains('cancel')) {
        AppSnackbar.error(paymentResult.errorMessage!);
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(e, stackTrace: stackTrace, tag: 'AdvertiserPortalController.topUpWallet');
      AppSnackbar.error('Unable to complete wallet recharge. Please try again.');
    }
  }

  Future<void> saveBillingDetails({
    required String company,
    required String gstin,
    required String address,
    required String email,
  }) async {
    billingCompanyName.value = company;
    billingGstin.value = gstin;
    billingAddress.value = address;
    billingEmail.value = email;

    final uid = AuthService.to.uid;
    if (uid.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('advertiser_profiles')
            .doc(uid)
            .set({
          'companyName': company,
          'gstin': gstin,
          'address': address,
          'billingEmail': email,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        ErrorHandler.log(e);
      }
    }

    AppSnackbar.show(
      'Settings Updated',
      'Billing details and GSTIN registered successfully.',
      backgroundColor: AppColors.success,
      colorText: AppColors.textPrimary,
    );
  }
}
