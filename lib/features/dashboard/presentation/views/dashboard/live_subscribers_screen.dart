import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/dashboard_screen.dart';

class LiveSubscribersScreen extends StatelessWidget {
  final bool isDarkMode;

  const LiveSubscribersScreen({super.key, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    final DashboardController controller = Get.find<DashboardController>();

    return Scaffold(
      backgroundColor: isDarkMode
          ? AppTheme.colors.background
          : AppTheme.colors.textPrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Live Subscriber Count',
          style: TextStyle(
            fontFamily: 'Roboto',
            color: isDarkMode ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.circle, color: Colors.red, size: 12),
                  const SizedBox(width: 8),
                  Text(
                    'LIVE',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
            Obx(() {
              final rawSubs = controller.channelStats['rawSubscribers'] ?? 0;
              return Text(
                '$rawSubs',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 120,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.black,
                  height: 1.0,
                  letterSpacing: -2,
                ),
              );
            }),
            const SizedBox(height: 16),
            Text(
              'Subscribers',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 24,
                color: isDarkMode
                    ? AppTheme.colors.textSecondary
                    : AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 64),
            Obx(() {
              final channelName =
                  controller.channelStats['name'] ?? 'Your Channel';
              // Fallback to name if not available
              return Text(
                channelName,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 20,
                  color: isDarkMode ? Colors.white70 : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
