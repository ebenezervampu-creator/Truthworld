import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/user_wallet_service.dart';
import 'package:truthworld/features/wallet/data/models/user_wallet_transaction.dart';
import 'package:truthworld/features/wallet/presentation/widgets/user_wallet_topup_sheet.dart';

/// GetX Controller orchestrating regular User Wallet state, real-time balance,
/// transaction streams, and deposit interactions.
class UserWalletController extends GetxController {
  final UserWalletService _walletService = UserWalletService.to;
  final AuthService _authService = AuthService.to;

  final RxString activeFilter = 'all'.obs; // 'all', 'credit', 'debit'
  final RxList<UserWalletTransaction> transactions =
      <UserWalletTransaction>[].obs;
  final RxBool isLoading = true.obs;

  StreamSubscription<List<UserWalletTransaction>>? _txSubscription;

  /// Real-time live balance in INR
  RxDouble get rxBalance => _authService.userWalletBalance;
  double get balance => _authService.userWalletBalance.value;

  /// Formatted localized balance
  String get formattedBalance => _walletService.formattedBalance;

  @override
  void onInit() {
    super.onInit();
    _initTransactionsStream();
  }

  void _initTransactionsStream() {
    final uid = _authService.uid;
    if (uid.isEmpty) {
      isLoading.value = false;
      return;
    }

    isLoading.value = true;
    _txSubscription?.cancel();
    _txSubscription = _walletService.streamTransactions(uid).listen(
      (list) {
        transactions.assignAll(list);
        isLoading.value = false;
      },
      onError: (err) {
        isLoading.value = false;
      },
    );
  }

  /// Filtered list based on active tab
  List<UserWalletTransaction> get filteredTransactions {
    final filter = activeFilter.value;
    if (filter == 'credit') {
      return transactions.where((t) => t.isCredit).toList();
    } else if (filter == 'debit') {
      return transactions.where((t) => t.isDebit).toList();
    }
    return transactions;
  }

  void setFilter(String filter) {
    activeFilter.value = filter;
  }

  void openTopupSheet(BuildContext context) {
    UserWalletTopupSheet.show(context);
  }

  @override
  void onClose() {
    _txSubscription?.cancel();
    super.onClose();
  }
}
