import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/analytics/presentation/controllers/revenue_analytics_controller.dart';
import 'package:truthworld/features/analytics/presentation/widgets/manage_bank_account_dialog.dart';
import 'package:truthworld/theme/app_theme.dart';

Widget buildDirectBankAccountCard(
  BuildContext context,
  RevenueAnalyticsController controller,
) {
  return Obx(() {
    final bank = controller.savedBankAccount.value;
    final isLinked = bank != null && bank.accountNumber.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E), // Exact Library cardColor
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 360;

              final iconWidget = Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.bgSurfaceHover,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.textPrimary.withValues(alpha: 0.1)),
                ),
                child: const Icon(
                  Icons.account_balance_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              );

              final textContent = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Direct Bank Account Arrangement',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    isLinked
                        ? 'Ready for instant NEFT / IMPS revenue credit'
                        : 'Set up your bank account for direct revenue withdrawals',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              );

              final badgeWidget = Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.bgSurfaceHover,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppColors.textPrimary.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  isLinked ? 'Ready for Payout' : 'Setup Required',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        iconWidget,
                        const SizedBox(width: 10),
                        Expanded(child: textContent),
                      ],
                    ),
                    const SizedBox(height: 8),
                    badgeWidget,
                  ],
                );
              }

              return Row(
                children: [
                  iconWidget,
                  const SizedBox(width: 12),
                  Expanded(child: textContent),
                  const SizedBox(width: 8),
                  badgeWidget,
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          if (isLinked) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bgPage,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.bgDivider),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bank.bankName,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${bank.maskedAccountNumber} • ${bank.accountHolderName} (${bank.accountType})',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'IFSC: ${bank.formattedIfsc}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => ManageBankAccountDialog.show(context),
                    icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 14),
                    label: const Text('Update'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.bgDivider),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.bgSurfaceHover,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.bgDivider),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.bgPage,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.autorenew_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Automatic Monthly Bank Deposit',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          controller.autoPayoutEnabled.value
                              ? 'Active: Cleared revenue (min ₹100) auto-deposits on the 1st of every month.'
                              : 'Manual: Earnings stay in your channel wallet until you request a withdrawal.',
                          style: TextStyle(
                            color: controller.autoPayoutEnabled.value
                                ? const Color(0xFF81C784)
                                : AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Transform.scale(
                    scale: 0.85,
                    child: Switch.adaptive(
                      value: controller.autoPayoutEnabled.value,
                      activeColor: Colors.white,
                      activeTrackColor: const Color(0xFF2E7D32),
                      inactiveThumbColor: Colors.grey.shade400,
                      inactiveTrackColor: Colors.grey.shade800,
                      onChanged: controller.isUpdatingAutoPayout.value
                          ? null
                          : (val) => controller.toggleAutoPayout(val),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => ManageBankAccountDialog.show(context),
                icon: const Icon(Icons.add_rounded, color: Colors.white, size: 16),
                label: const Text('Add Bank Account for Direct Payouts'),
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppColors.bgSurfaceHover,
                  foregroundColor: Colors.white,
                  side: BorderSide(color: AppColors.textPrimary.withValues(alpha: 0.2)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  });
}
