import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/dashboard_screen.dart';
import 'package:truthworld/theme/app_theme.dart';

class LiveSubscribersScreen extends StatelessWidget {

  const LiveSubscribersScreen({required this.isDarkMode, super.key});
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<DashboardController>();

    return Scaffold(
      backgroundColor: isDarkMode
          ? AppTheme.colors.background
          : AppTheme.colors.textPrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDarkMode ? AppColors.textPrimary : AppColors.bgPage,
          ),
          onPressed: Get.back,
        ),
        title: Text(
          'Live Subscriber Count',
          style: TextStyle(
            
            color: isDarkMode ? AppColors.textPrimary : AppColors.bgPage,
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
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, color: AppColors.error, size: 12),
                  SizedBox(width: 8),
                  Text(
                    'LIVE',
                    style: TextStyle(
                      
                      color: AppColors.error,
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
                  
                  fontSize: 120,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? AppColors.textPrimary : AppColors.bgPage,
                  height: 1,
                  letterSpacing: -2,
                ),
              );
            }),
            const SizedBox(height: 16),
            Text(
              'Subscribers',
              style: TextStyle(
                
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
                  
                  fontSize: 20,
                  color: isDarkMode ? AppColors.textSecondary : AppColors.bgPage,
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
