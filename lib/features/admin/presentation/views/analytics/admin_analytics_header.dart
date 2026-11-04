import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Header for the Platform Safety & Moderation Analytics tab with time range selector and refresh.
class AdminAnalyticsHeader extends StatelessWidget {
  const AdminAnalyticsHeader({
    required this.controller,
    super.key,
  });

  final AdminController controller;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Platform Safety & Moderation Analytics',
              style: TextStyle(
                fontFamily: TWTypography.brandFamily,
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Obx(() {
              final lastUpdated = controller.analyticsData['lastUpdated'];
              final formattedTime = (lastUpdated is DateTime)
                  ? DateFormat('hh:mm a').format(lastUpdated)
                  : 'Live';
              return Text(
                'Live aggregate insights from Firestore · Last updated: $formattedTime',
                style: const TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              );
            }),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Time Range Selector
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.bgPage,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Obx(
                () => DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: controller.analyticsTimeRange.value,
                    dropdownColor: AppColors.bgSurface,
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    style: const TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    items: const [
                      DropdownMenuItem(value: '7d', child: Text('Last 7 Days')),
                      DropdownMenuItem(value: '30d', child: Text('Last 30 Days')),
                      DropdownMenuItem(value: '90d', child: Text('Last 90 Days')),
                      DropdownMenuItem(value: 'all', child: Text('All Time')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        controller.analyticsTimeRange.value = value;
                        controller.fetchAnalytics();
                      }
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Refresh Button
            Obx(() {
              final isFetching = controller.isLoadingAnalytics.value;
              return Tooltip(
                message: 'Refresh Analytics',
                child: InkWell(
                  onTap: isFetching ? null : controller.fetchAnalytics,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.bgPage,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: isFetching
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(
                            Icons.refresh_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                  ),
                ),
              );
            }),
          ],
        ),
      ],
    );
  }
}
