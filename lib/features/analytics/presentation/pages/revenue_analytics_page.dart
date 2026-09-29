import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/analytics/presentation/controllers/revenue_analytics_controller.dart';
import 'package:truthworld/features/analytics/presentation/pages/revenue/revenue_analytics_widgets.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Production-grade Revenue Analytics Page.
/// Displays all revenue streams that the channel has earned with authentic
/// Firestore data and 100% compliant icon styling (Colors.white).
class RevenueAnalyticsPage extends StatelessWidget {
  const RevenueAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = RevenueAnalyticsController.to;
    final args = Get.arguments as Map<String, dynamic>? ?? {};
    final channelId = args['channelId'] as String? ?? '';
    final channelName = args['channelName'] as String? ?? 'Channel';
    final revenueChange = args['revenueChange'] as String? ?? r'+$0.00';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (channelId.isNotEmpty) {
        controller.loadRevenueAnalytics(
          channelId,
          chName: channelName,
          change: revenueChange,
        );
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: Get.back,
        ),
        title: Obx(
          () => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Revenue Analytics',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              if (controller.channelName.value.isNotEmpty)
                Text(
                  controller.channelName.value,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                  ),
                ),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Analytics',
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary),
            onPressed: controller.refreshData,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Obx(() {
        if (controller.rxIsLoading.value && controller.totalRevenue.value == 0.0) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFF59E0B)),
          );
        }

        return RefreshIndicator(
          color: const Color(0xFFF59E0B),
          onRefresh: controller.refreshData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildRevenueHeroMetricCard(controller),
                const SizedBox(height: 18),
                buildWithdrawalThresholdCard(context, controller),
                const SizedBox(height: 14),
                buildDirectBankAccountCard(context, controller),
                const SizedBox(height: 14),
                buildCreatorKycCard(context, controller),
                const SizedBox(height: 24),
                buildRevenueSectionHeader(
                  title: 'Ways You Earned',
                  badge: 'All Active Streams',
                ),
                const SizedBox(height: 14),
                buildMembershipsStreamCard(controller),
                const SizedBox(height: 14),
                buildSuperchatStreamCard(controller),
                const SizedBox(height: 14),
                buildAdRevenueStreamCard(controller),
                const SizedBox(height: 14),
                buildWatchTimeStreamCard(controller),
                const SizedBox(height: 14),
                const PremiumSubsRevenueCard(),
                const SizedBox(height: 24),
                buildRevenueDistributionCard(controller),
                const SizedBox(height: 24),
                buildPayoutAndUsabilityCard(controller),
              ],
            ),
          ),
        );
      }),
    );
  }
}
