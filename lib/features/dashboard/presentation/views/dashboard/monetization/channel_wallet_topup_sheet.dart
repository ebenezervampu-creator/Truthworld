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
/// Powered by Cashfree Payment Gateway with 100% zero charm-pricing compliance.
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

    // Zero Charm Pricing compliant preset options (honest round numbers)
    final presetAmounts = [10.0, 25.0, 50.0, 100.0, 200.0];

    Get.bottomSheet<void>(
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
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
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.bgSurfaceHover,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.textPrimary.withValues(alpha: 0.1)),
                          ),
                          child: const Icon(
                            Icons.add_card_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Add Money to Channel Wallet',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
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
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        channel.channelType == ChannelType.custom
                            ? 'Pro Channel: At-cost pass-through Dubbing (ElevenLabs voice cloning) & Subtitles with 0% platform profit.'
                            : 'Standard Channel: Use wallet balance to instantly pay for AI Voice Dubbing (ElevenLabs) and Subtitles.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textPrimary,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Amount Selection Section
              const Text(
                'Select Top-Up Amount (USD)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),

              // Presets Grid
              Obx(() => Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ...presetAmounts.map((amt) {
                        final isSelected = !isCustomAmount.value &&
                            selectedAmount.value == amt;
                        final inrVal = (amt * rate).toStringAsFixed(0);

                        return InkWell(
                          onTap: () {
                            isCustomAmount.value = false;
                            selectedAmount.value = amt;
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.bgSurfaceHover,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.bgDivider,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '\$${amt.toInt()}',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? Colors.black
                                        : Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '≈ ₹$inrVal',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isSelected
                                        ? Colors.black87
                                        : AppColors.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),

                      // Custom Amount Option
                      InkWell(
                        onTap: () {
                          isCustomAmount.value = true;
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isCustomAmount.value
                                ? Colors.white
                                : AppColors.bgSurfaceHover,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isCustomAmount.value
                                  ? Colors.white
                                  : AppColors.bgDivider,
                              width: isCustomAmount.value ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Custom',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isCustomAmount.value
                                      ? Colors.black
                                      : Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Any USD',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isCustomAmount.value
                                      ? Colors.black87
                                      : AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )),
              const SizedBox(height: 14),

              // Custom Amount TextField
              Obx(() {
                if (!isCustomAmount.value) return const SizedBox.shrink();
                return Container(
                  margin: const EdgeInsets.only(top: 4, bottom: 8),
                  child: TextField(
                    controller: customAmountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      labelText: r'Enter Custom USD Amount (Min $5)',
                      labelStyle: const TextStyle(color: AppColors.textSecondary),
                      prefixText: r'$ ',
                      prefixStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      filled: true,
                      fillColor: AppColors.bgInput,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.bgDivider),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.white),
                      ),
                    ),
                    onChanged: (val) {
                      final parsed = double.tryParse(val) ?? 0.0;
                      selectedAmount.value = parsed;
                    },
                  ),
                );
              }),
              const SizedBox(height: 10),

              // Charge Breakdown & Final CTA
              Obx(() {
                final amt = selectedAmount.value;
                final inrAmount = (amt * rate).toStringAsFixed(2);
                final isValid = amt >= 5.0;

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.bgPage,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.bgDivider),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 420;

                      final chargeDetails = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Estimated Charge:',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '₹$inrAmount INR (≈ \$${amt.toStringAsFixed(2)} USD)',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Exchange Rate: 1 USD = ₹${rate.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      );

                      final depositButton = ElevatedButton.icon(
                        onPressed: (!isValid || isProcessing.value)
                            ? null
                            : () async {
                                if (amt < 5.0) {
                                  AppSnackbar.warning(
                                    r'Minimum deposit amount is $5.00 USD.',
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
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          disabledBackgroundColor: Colors.white38,
                          disabledForegroundColor: Colors.black54,
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
                      );

                      if (isNarrow) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            chargeDetails,
                            const SizedBox(height: 12),
                            depositButton,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: chargeDetails),
                          const SizedBox(width: 8),
                          depositButton,
                        ],
                      );
                    },
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
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock_outline_rounded, size: 13, color: AppColors.textTertiary),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          'Secured by Cashfree • $methods',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                            fontWeight: FontWeight.w500,
                          ),
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
