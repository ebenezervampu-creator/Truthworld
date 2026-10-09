import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/currency_localization_service.dart';
import 'package:truthworld/features/advertiser/presentation/controllers/advertiser_portal_controller.dart';
import 'package:truthworld/features/advertiser/presentation/views/tabs/billing/billing_topup_dialog.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Card presenting Cashfree RBI-tokenized gateway security details and recharge action.
class BillingPaymentGatewayCard extends StatelessWidget {
  const BillingPaymentGatewayCard({required this.controller, super.key});
  final AdvertiserPortalController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Payment Gateway & Security',
                style: TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => BillingTopUpDialog.show(context, controller),
                icon: const Icon(
                  Icons.add_circle_outline_rounded,
                  color: Colors.white,
                  size: 16,
                ),
                label: const Text(
                  'Recharge Balance',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontSize: 13,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF3F3F46)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1F),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2E2E33)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.brand.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.security_rounded,
                    color: AppColors.textPrimary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Obx(() {
                    final isIndian = !Get.isRegistered<CurrencyLocalizationService>() ||
                        CurrencyLocalizationService.to.isIndianUser;
                    final title = isIndian
                        ? 'Cashfree Payment Gateway (RBI Tokenized)'
                        : 'Cashfree Global Payment Gateway (PCI-DSS Level 1)';
                    final desc = Get.isRegistered<CurrencyLocalizationService>()
                        ? CurrencyLocalizationService.to.paymentMethodsDescription
                        : 'Supports Instant UPI, Netbanking, Debit/Credit Cards with 256-bit SSL encryption.';

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          desc,
                          style: const TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
