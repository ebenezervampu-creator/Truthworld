import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/currency_localization_service.dart';
import 'package:truthworld/core/services/user_wallet_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Modal bottom sheet allowing regular users & viewers to add money into their User Wallet.
class UserWalletTopupSheet {
  UserWalletTopupSheet._();

  static void show(
    BuildContext context, {
    VoidCallback? onTopupSuccess,
  }) {
    final auth = AuthService.to;
    if (!auth.isAuthenticated.value) {
      AppSnackbar.info(
        'Please sign in to add money to your wallet.',
        title: 'Sign In Required',
        actionLabel: 'SIGN IN',
        onAction: auth.signInWithGoogle,
      );
      return;
    }

    final walletService = UserWalletService.to;
    final selectedAmount = 250.0.obs;
    final isCustomAmount = false.obs;
    final customAmountController = TextEditingController();
    final isProcessing = false.obs;

    final presetAmounts = [100.0, 250.0, 500.0, 1000.0, 2000.0, 5000.0];

    Get.bottomSheet<void>(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.brand.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Add Money to Wallet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: Get.back,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Obx(() {
                final balance = auth.userWalletBalance.value;
                return Text(
                  'Current Wallet Balance: ₹${balance.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                );
              }),
              const SizedBox(height: 18),

              // Use Cases Info Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.bgPage,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.bgDivider.withValues(alpha: 0.5),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.bolt_rounded,
                      color: Color(0xFFFBBF24),
                      size: 24,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Instant 1-Click Payments',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Use your wallet balance to send instant Superchats, join channel memberships, and tip creators without checkout delays.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                'Select Deposit Amount',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),

              // Preset Amount Chips
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ...presetAmounts.map((amt) {
                    return Obx(() {
                      final isSelected = !isCustomAmount.value &&
                          selectedAmount.value == amt;
                      return ChoiceChip(
                        label: Text('₹${amt.toInt()}'),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            HapticFeedback.selectionClick();
                            selectedAmount.value = amt;
                            isCustomAmount.value = false;
                            customAmountController.clear();
                          }
                        },
                        selectedColor: AppColors.brand,
                        backgroundColor: AppColors.bgPage,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.black : AppColors.textPrimary,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.brand
                                : AppColors.bgDivider,
                          ),
                        ),
                      );
                    });
                  }),
                  // Custom amount chip
                  Obx(() {
                    return ChoiceChip(
                      label: const Text('Custom'),
                      selected: isCustomAmount.value,
                      onSelected: (selected) {
                        if (selected) {
                          HapticFeedback.selectionClick();
                          isCustomAmount.value = true;
                        }
                      },
                      selectedColor: AppColors.brand,
                      backgroundColor: AppColors.bgPage,
                      labelStyle: TextStyle(
                        color: isCustomAmount.value
                            ? Colors.black
                            : AppColors.textPrimary,
                        fontWeight: isCustomAmount.value
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isCustomAmount.value
                              ? AppColors.brand
                              : AppColors.bgDivider,
                        ),
                      ),
                    );
                  }),
                ],
              ),

              // Custom amount input field
              Obx(() {
                if (!isCustomAmount.value) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: TextField(
                    controller: customAmountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      prefixIcon: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '₹',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(),
                      hintText: 'Enter amount (min ₹10)',
                      hintStyle: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: AppColors.bgPage,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.bgDivider,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.brand,
                          width: 1.5,
                        ),
                      ),
                    ),
                    onChanged: (val) {
                      final parsed = double.tryParse(val);
                      if (parsed != null && parsed > 0) {
                        selectedAmount.value = parsed;
                      }
                    },
                  ),
                );
              }),
              const SizedBox(height: 20),

              // Summary Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.bgPage,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.bgDivider.withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Deposit Amount',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        Obx(() {
                          final amt = selectedAmount.value;
                          return Text(
                            '₹${amt.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Platform Top-Up Fee',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          '₹0.00 (Free)',
                          style: TextStyle(
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    if (Get.isRegistered<CurrencyLocalizationService>() &&
                        !CurrencyLocalizationService.to.isIndianUser) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Estimated USD',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          Obx(() {
                            final inr = selectedAmount.value;
                            final rate = CurrencyLocalizationService.to.rate;
                            final usd = inr / rate;
                            return Text(
                              '~\$${usd.toStringAsFixed(2)} USD',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            );
                          }),
                        ],
                      ),
                    ],
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(color: AppColors.bgDivider, height: 1),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Payable',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Obx(() {
                          final amt = selectedAmount.value;
                          return Text(
                            '₹${amt.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                            ),
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Supported Payments Badge
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.security_rounded,
                    color: Color(0xFF10B981),
                    size: 16,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Instant & Secure via Cashfree (UPI, GPay, Cards, NetBanking)',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Proceed to Pay Button (Strict Zero White-on-White: black text/icon on white button)
              Obx(() {
                final loading = isProcessing.value;
                final amt = selectedAmount.value;

                return SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: loading
                        ? null
                        : () async {
                            if (amt < 10.0) {
                              AppSnackbar.warning(
                                'Minimum deposit amount is ₹10.00.',
                              );
                              return;
                            }
                            if (amt > 50000.0) {
                              AppSnackbar.warning(
                                'Maximum deposit amount is ₹50,000.00.',
                              );
                              return;
                            }

                            isProcessing.value = true;
                            HapticFeedback.mediumImpact();

                            final success = await walletService
                                .topupUserWalletWithCashfree(
                              amountINR: amt,
                              userId: auth.uid,
                            );

                            isProcessing.value = false;

                            if (success) {
                              Get.back();
                              onTopupSuccess?.call();
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      elevation: 0,
                    ),
                    child: loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.black,
                            ),
                          )
                        : Text(
                            'Add ₹${amt.toStringAsFixed(2)} to Wallet',
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }
}
