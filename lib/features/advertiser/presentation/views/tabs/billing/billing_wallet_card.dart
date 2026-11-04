import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/advertiser/presentation/controllers/advertiser_portal_controller.dart';
import 'package:truthworld/features/advertiser/presentation/views/tabs/billing/billing_topup_dialog.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Card displaying prepaid advertiser balance, quick reload chips, and auto-reload configuration.
class BillingWalletCard extends StatelessWidget {
  const BillingWalletCard({required this.controller, super.key});
  final AdvertiserPortalController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final balance = controller.walletBalance.value;
      final autoReload = controller.autoReloadEnabled.value;
      final threshold = controller.autoReloadThreshold.value;
      final reloadAmount = controller.autoReloadAmount.value;

      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.appBarSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.bgSurface),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.bgSurface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Prepaid Advertiser Balance',
                          style: TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '₹${balance.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontFamily: TWTypography.brandFamily,
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => BillingTopUpDialog.show(context, controller),
                  icon: const Icon(
                    Icons.add_circle_outline_rounded,
                    color: Colors.black,
                    size: 18,
                  ),
                  label: const Text(
                    'Add Funds',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(color: AppColors.bgSurface, height: 1),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text(
                  'Quick Top-Up:',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [1000, 2500, 5000, 10000].map((amt) {
                    return InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        controller.topUpWallet(amt.toDouble());
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.bgSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.bgElevated),
                        ),
                        child: Text(
                          '+₹$amt',
                          style: const TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bgInput,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.bgSurface),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.bolt_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Auto-Reload on Low Balance',
                          style: TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          autoReload
                              ? 'Automatically charges your default card ₹${reloadAmount.toStringAsFixed(0)} when balance falls under ₹${threshold.toStringAsFixed(0)}.'
                              : 'Auto-reload is turned off. Your campaigns may pause if balance reaches zero.',
                          style: const TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: autoReload,
                    activeColor: AppColors.brand,
                    onChanged: (val) {
                      controller.autoReloadEnabled.value = val;
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}
