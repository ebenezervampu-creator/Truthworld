import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/cashfree/cashfree_country_support.dart';
import 'package:truthworld/core/services/channel_wallet_service.dart';
import 'package:truthworld/core/services/currency_localization_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/theme/app_colors.dart';
import 'package:truthworld/theme/tw_radius.dart';

/// Modal bottom sheet allowing creators to deposit money into their Channel Wallet.
class ChannelWalletTopupSheet {
  ChannelWalletTopupSheet._();

  static void show(
    BuildContext context, {
    required Channel channel,
    VoidCallback? onTopupSuccess,
  }) {
    final walletService = ChannelWalletService();
    final selectedAmount = 25.0.obs;
    final isCustomAmount = false.obs;
    final customAmountController = TextEditingController();
    final isProcessing = false.obs;

    final rate = Get.isRegistered<CurrencyLocalizationService>()
        ? CurrencyLocalizationService.to.rate
        : CurrencyLocalizationService.defaultRate;

    final presetAmounts = [5.0, 10.0, 25.0, 50.0, 100.0];

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
                          Icons.add_card_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Add Money to Channel Wallet',
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
              Text(
                'Channel: ${channel.name} • Current Wallet Balance: \$${channel.walletBalanceUSD.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),

              // Feature perks banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.bgInput,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.bgDivider),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.stars_rounded,
                      color: AppColors.warning,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        channel.channelType == ChannelType.custom
                            ? r'Custom Channel: At-cost pass-through Dubbing (from $0.10/lang) & Subtitles (from $0.025/lang) + Studio Voice Cloning.'
                            : r'Standard Channel: At-cost pass-through Dubbing (from $0.10/lang) & Subtitles (from $0.025/lang). 100% Free Fact-Checking.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Preset Amount Selection
              const Text(
                'Select Deposit Amount (USD)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Obx(() => Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: presetAmounts.map((amount) {
                      final isSelected = !isCustomAmount.value &&
                          selectedAmount.value == amount;
                      final inrEquiv = (amount * rate).round();

                      return InkWell(
                        onTap: () {
                          isCustomAmount.value = false;
                          selectedAmount.value = amount;
                          customAmountController.clear();
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.brand
                                : AppColors.bgInput,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.brand
                                  : AppColors.bgDivider,
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '\$${amount.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? Colors.black
                                      : AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '≈ ₹$inrEquiv',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isSelected
                                      ? Colors.black87
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  )),
              const SizedBox(height: 16),

              // Custom amount input
              const Text(
                'Or Enter Custom Amount',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: customAmountController,
                maxLength: 8,
                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                  LengthLimitingTextInputFormatter(8),
                ],
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  prefixText: r'$ ',
                  prefixStyle: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  hintText: r'Enter amount in USD (min $1.00)',
                  hintStyle: const TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.bgInput,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.bgDivider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.bgDivider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.brand),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                onChanged: (val) {
                  final parsed = double.tryParse(val);
                  if (parsed != null && parsed > 0) {
                    isCustomAmount.value = true;
                    selectedAmount.value = parsed;
                  }
                },
              ),
              const SizedBox(height: 16),

              // Summary and CTA
              Obx(() {
                final amt = selectedAmount.value;
                final inrAmt = (amt * rate).toStringAsFixed(2);

                final isIndian = !Get.isRegistered<CurrencyLocalizationService>() ||
                    CurrencyLocalizationService.to.isIndianUser;
                final displayCharge = isIndian
                    ? '₹$inrAmt (≈ \$${amt.toStringAsFixed(2)} USD)'
                    : '\$${amt.toStringAsFixed(2)} USD';

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurfaceHover,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.bgDivider),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Estimated Total to Charge:',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            displayCharge,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: isProcessing.value
                            ? null
                            : () async {
                                if (amt < 1.0) {
                                  AppSnackbar.warning(
                                    r'Minimum deposit amount is $1.00.',
                                  );
                                  return;
                                }

                                isProcessing.value = true;
                                final uid = AuthService.to.uid.isNotEmpty
                                    ? AuthService.to.uid
                                    : channel.ownerId;

                                final success = await walletService
                                    .topupChannelWalletWithCashfree(
                                  channel: channel,
                                  amountUSD: amt,
                                  userId: uid,
                                );

                                isProcessing.value = false;

                                if (success) {
                                  Get.back();
                                  AppSnackbar.success(
                                    'Successfully added \$${amt.toStringAsFixed(2)} to your channel wallet!',
                                  );
                                  onTopupSuccess?.call();
                                } else {
                                  AppSnackbar.warning(
                                    'Deposit was not completed. If funds were debited, they will be credited automatically upon gateway verification.',
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brand,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: TWRadius.mdBorderRadius,
                          ),
                        ),
                        icon: isProcessing.value
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.black,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.payment_rounded,
                                color: Colors.black,
                                size: 18,
                              ),
                        label: Text(
                          isProcessing.value ? 'Processing...' : 'Pay & Deposit',
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 12),
              Obx(() {
                final country = Get.isRegistered<CurrencyLocalizationService>()
                    ? CurrencyLocalizationService.to.userCountryCode.value
                    : 'IN';
                final methods = CashfreeCountrySupport.getPaymentMethodsSummary(country);
                return Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_outline_rounded, size: 13, color: AppColors.textTertiary),
                      const SizedBox(width: 5),
                      Text(
                        'Secured by Cashfree • $methods',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
