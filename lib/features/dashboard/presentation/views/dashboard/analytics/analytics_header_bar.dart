import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/analytics/presentation/pages/creator_analytics_dashboard.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/analytics/analytics_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Top header bar for Studio Channel Analytics inspired by ChannelWizardTopHeader:
/// Features branded title typography, real-time live viewer badge, refresh action,
/// and full dashboard navigation button.
class AnalyticsHeaderBar extends StatelessWidget {
  const AnalyticsHeaderBar({
    required this.controller,
    required this.channelId,
    required this.isDesktop,
    required this.isMobile,
    super.key,
  });

  final AnalyticsController controller;
  final String channelId;
  final bool isDesktop;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.bgPage,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.bgSurface),
                ),
                child: const Icon(
                  Icons.analytics_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Channel Analytics',
                  style: TextStyle(
                    fontFamily: TWTypography.brandFamily,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Real-time overview of channel performance and content insights',
            style: TextStyle(
              fontFamily: TWTypography.uiFamily,
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildLiveViewerBadge(),
              _buildFullDashboardButton(),
            ],
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.bgPage,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.bgSurface),
                ),
                child: const Icon(
                  Icons.analytics_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Channel Analytics',
                      style: TextStyle(
                        fontFamily: TWTypography.brandFamily,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Real-time overview of channel performance and content insights',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLiveViewerBadge(),
            const SizedBox(width: 10),
            IconButton(
              icon: Obx(
                () => controller.rxIsRefreshing.value
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
              ),
              tooltip: 'Refresh Analytics',
              onPressed: controller.refreshAll,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.bgPage,
                side: const BorderSide(color: AppColors.bgSurface),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _buildFullDashboardButton(),
          ],
        ),
      ],
    );
  }

  Widget _buildLiveViewerBadge() {
    return Obx(() {
      final viewers = controller.liveViewerCount;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.bgPage,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.bgSurface),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              viewers > 0 ? '$viewers live now' : 'Real-time active',
              style: const TextStyle(
                fontFamily: TWTypography.uiFamily,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildFullDashboardButton() {
    return InkWell(
      onTap: () {
        Get.to<dynamic>(
          () => const CreatorAnalyticsDashboard(),
          arguments: {
            'channelId': channelId,
            'channelName': 'My Channel',
          },
        );
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.brand,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(
              Icons.analytics_rounded,
              color: Colors.black,
              size: 16,
            ),
            SizedBox(width: 8),
            Text(
              'Full Dashboard',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            SizedBox(width: 4),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.black,
              size: 11,
            ),
          ],
        ),
      ),
    );
  }
}
