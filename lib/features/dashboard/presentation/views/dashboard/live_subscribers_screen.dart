import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/dashboard_screen.dart';
import 'package:truthworld/theme/app_colors.dart';

class LiveSubscribersScreen extends StatelessWidget {
  const LiveSubscribersScreen({required this.isDarkMode, super.key});
  final bool isDarkMode;

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
        backgroundColor: AppColors.bgPage,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Get.back<void>(),
        ),
        title: const Text(
          'Live Subscriber Count',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: controller == null
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.brand),
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.brand.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AppColors.brand.withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.sensors_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'LIVE COUNT',
                          style: TextStyle(
                            color: AppColors.brand,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),
                  Obx(() {
                    final rawSubs =
                        controller.channelStats['rawSubscribers'] ??
                        controller.currentChannel.value?.subscriberCount ??
                        0;
                    return Text(
                      '$rawSubs',
                      style: const TextStyle(
                        fontSize: 110,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        height: 1,
                        letterSpacing: -2,
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  const Text(
                    'Subscribers',
                    style: TextStyle(
                      fontSize: 22,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 48),
                  Obx(() {
                    final channelName =
                        controller.channelStats['name'] ??
                        controller.currentChannel.value?.channelName ??
                        'Your Channel';
                    return Text(
                      channelName.toString(),
                      style: const TextStyle(
                        fontSize: 18,
                        color: AppColors.brand,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}
