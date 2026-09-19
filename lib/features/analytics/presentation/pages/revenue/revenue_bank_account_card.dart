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
          color: const Color(0xFF121218),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isLinked
                ? const Color(0xFF10B981).withValues(alpha: 0.4)
                : const Color(0xFF27272A),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isLinked ? const Color(0xFF10B981) : const Color(0xFF3B82F6))
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.account_balance_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Direct Bank Account Arrangement',
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
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (isLinked ? const Color(0xFF10B981) : const Color(0xFF3B82F6))
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: (isLinked ? const Color(0xFF10B981) : const Color(0xFF3B82F6))
                          .withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    isLinked ? 'Ready for Payout' : 'Setup Required',
                    style: TextStyle(
                      color: isLinked ? const Color(0xFF10B981) : const Color(0xFF60A5FA),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (isLinked) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF09090B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF27272A)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bank.bankName,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${bank.maskedAccountNumber} • ${bank.accountHolderName} (${bank.accountType})',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'IFSC: ${bank.formattedIfsc}',
                          style: const TextStyle(
                            color: Color(0xFF71717A),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    OutlinedButton.icon(
                      onPressed: () => ManageBankAccountDialog.show(context),
                      icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 14),
                      label: const Text('Update'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: Color(0xFF3F3F46)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        textStyle: const TextStyle(fontSize: 12),
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
                    foregroundColor: const Color(0xFF10B981),
                    side: BorderSide(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
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


