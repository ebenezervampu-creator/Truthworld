import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/cashfree/cashfree_country_support.dart';
import 'package:truthworld/core/services/currency_localization_service.dart';
import 'package:truthworld/features/advertiser/presentation/controllers/advertiser_portal_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Modal dialog for topping up advertiser prepaid balance with country-aware currency and rails.
class BillingTopUpDialog extends StatelessWidget {
  const BillingTopUpDialog({required this.controller, super.key});
  final AdvertiserPortalController controller;

  static void show(BuildContext context, AdvertiserPortalController controller) {
    Get.dialog(BillingTopUpDialog(controller: controller));
  }

  @override
  Widget build(BuildContext context) {
    final isIndian = !Get.isRegistered<CurrencyLocalizationService>() ||
        CurrencyLocalizationService.to.isIndianUser;
    final currency = isIndian ? 'INR' : 'USD';
    final currencySymbol = isIndian ? '₹' : r'$';
    final presetAmounts = isIndian
        ? const [1000, 2000, 5000, 10000]
        : const [25, 50, 100, 250];

    final defaultAmt = isIndian ? 2000.0 : 50.0;
    final customAmountController = TextEditingController(text: defaultAmt.toInt().toString());
    final selectedAmount = defaultAmt.obs;

    return AlertDialog(
      backgroundColor: const Color(0xFF161618),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF27272A)),
      ),
      title: const Text(
        'Recharge Advertiser Balance',
        style: TextStyle(
          fontFamily: TWTypography.brandFamily,
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Prepaid credits are used directly to run video & banner campaigns.',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Select Amount ($currency)',
              style: const TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: presetAmounts.map((amt) {
                return Obx(() {
                  final isSel = selectedAmount.value == amt.toDouble();
                  return InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      selectedAmount.value = amt.toDouble();
                      customAmountController.text = amt.toString();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSel ? AppColors.brand : const Color(0xFF1C1C1F),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSel ? AppColors.brand : const Color(0xFF323238),
                        ),
                      ),
                      child: Text(
                        '$currencySymbol$amt',
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isSel ? Colors.black : Colors.white,
                        ),
                      ),
                    ),
                  );
                });
              }).toList(),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: customAmountController,
              keyboardType: TextInputType.number,
              maxLength: 8,
              buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(8),
              ],
              style: const TextStyle(color: Colors.white, fontFamily: TWTypography.uiFamily),
              onChanged: (val) {
                final parsed = double.tryParse(val);
                if (parsed != null) {
                  selectedAmount.value = parsed;
                }
              },
              decoration: InputDecoration(
                labelText: 'Custom Amount ($currencySymbol)',
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                prefixText: '$currencySymbol ',
                prefixStyle: const TextStyle(color: Colors.white),
                filled: true,
                fillColor: const Color(0xFF121214),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF27272A)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Obx(() {
              final amt = selectedAmount.value;
              final tax = isIndian ? (amt * 0.18) : 0.0;
              final total = amt + tax;
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF121214),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF27272A)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Wallet Credit:', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        Text('$currencySymbol${amt.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(isIndian ? 'GST (18%):' : 'Processing Fee (0%):', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        Text('$currencySymbol${tax.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                      ],
                    ),
                    const Divider(color: Color(0xFF27272A), height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Payable:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        Text('$currencySymbol${total.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.brand, fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline_rounded, size: 12, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Text(
                  'Secured by Cashfree • ${CashfreeCountrySupport.getPaymentMethodsSummary(currency == "INR" ? "IN" : "US")}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: Get.back,
          child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: () {
            final amt = selectedAmount.value;
            if (amt > 0) {
              final tax = isIndian ? double.parse((amt * 0.18).toStringAsFixed(2)) : 0.0;
              final total = double.parse((amt + tax).toStringAsFixed(2));
              controller.topUpWallet(total, netAmount: amt, taxAmount: tax);
              Get.back();
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.brand,
            foregroundColor: Colors.black,
          ),
          child: const Text(
            'Pay with Cashfree',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
