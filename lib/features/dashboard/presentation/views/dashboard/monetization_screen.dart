import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/monetization/monetization_components.dart';
import 'package:truthworld/theme/app_colors.dart';

export 'monetization/monetization_components.dart';

/// Screen showcasing channel monetization tiers, partner eligibility status,
/// revenue breakdown, per-video watch time thresholds, and balance utilization.
class MonetizationScreen extends StatelessWidget {
  const MonetizationScreen({required this.isDarkMode, super.key});

  final bool isDarkMode;

  /// Target watch time in hours required for cash withdrawal on standard channels.
  static const double cashOutWatchHoursThreshold = 10;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final controller = Get.isRegistered<DashboardController>()
        ? Get.find<DashboardController>()
        : (uid.isNotEmpty
            ? Get.put(DashboardController(channelId: uid))
            : null);

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        title: const Text(
          'Earnings & Monetization',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: AppColors.bgPage,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Get.back<void>(),
        ),
      ),
      body: controller == null
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.brand),
            )
          : Obx(() {
              final channel = controller.currentChannel.value;
              final isCustom = channel?.channelType == ChannelType.custom;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MonetizationHeaderSection(channel: channel),
                    const SizedBox(height: 20),
                    if (channel != null) ...[
                      ChannelWalletCard(channel: channel, controller: controller),
                      const SizedBox(height: 24),
                    ],
                    ChannelTypeCard(channel: channel),
                    const SizedBox(height: 24),
                    PolicyNoticeCard(isCustom: isCustom),
                    const SizedBox(height: 24),
                    PartnerEligibilitySection(isCustom: isCustom),
                    const SizedBox(height: 24),
                    RevenueWithdrawalSummaryCard(controller: controller),
                    const SizedBox(height: 24),
                    PerVideoWithdrawalSection(controller: controller),
                  ],
                ),
              );
            }),
    );
  }
}
