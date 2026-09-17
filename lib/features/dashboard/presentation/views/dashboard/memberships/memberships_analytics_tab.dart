import 'package:flutter/material.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/memberships_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Tab 3: Fan Funding & Revenue Projections Analytics.
class MembershipsAnalyticsTab extends StatelessWidget {
  const MembershipsAnalyticsTab({
    required this.controller,
    this.isDarkMode = true,
    super.key,
  });

  final MembershipsController controller;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fan Funding & Revenue Projections',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? AppColors.textPrimary : Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Industry benchmarks and instant recurring earnings breakdown.',
          style: TextStyle(
            fontSize: 12,
            color: isDarkMode ? AppColors.textSecondary : Colors.black54,
          ),
        ),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDarkMode ? AppColors.bgSurface : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDarkMode ? AppColors.bgDivider : Colors.grey.shade200,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Creator Payout Terms',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode
                          ? AppColors.textPrimary
                          : Colors.black87,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      '100% TO CREATOR',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AnalyticsFeatureRow(
                label: 'Platform Cut / Commission',
                value: '0.0% (Zero platform fees)',
                isDarkMode: isDarkMode,
              ),
              AnalyticsFeatureRow(
                label: 'Payout Frequency',
                value: 'Monthly Automatic Transfer',
                isDarkMode: isDarkMode,
              ),
              AnalyticsFeatureRow(
                label: 'Billing Cycle',
                value: '30-Day Recurring Fan Subscription',
                isDarkMode: isDarkMode,
              ),
              AnalyticsFeatureRow(
                label: 'Payment Protection',
                value: 'Encrypted Bank & Wallet Processing',
                isDarkMode: isDarkMode,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Helper Feature Row for Creator Terms & Analytics.
class AnalyticsFeatureRow extends StatelessWidget {
  const AnalyticsFeatureRow({
    required this.label,
    required this.value,
    this.isDarkMode = true,
    super.key,
  });

  final String label;
  final String value;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDarkMode ? AppColors.textSecondary : Colors.black54,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? AppColors.textPrimary : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
