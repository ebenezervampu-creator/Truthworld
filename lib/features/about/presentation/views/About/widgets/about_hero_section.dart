import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/widgets/app_logo.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Hero header section introducing TruthWorld's mission and verified publishing proposition.
class AboutHeroSection extends StatelessWidget {
  const AboutHeroSection({
    required this.isDesktop,
    required this.isTablet,
    required this.isMobile,
    super.key,
  });

  final bool isDesktop;
  final bool isTablet;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = isDesktop ? 80.0 : (isTablet ? 32.0 : 20.0);
    final verticalPadding = isDesktop ? 72.0 : (isTablet ? 48.0 : 36.0);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: verticalPadding,
        horizontal: horizontalPadding,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgPage,
        border: Border(
          bottom: BorderSide(
            color: AppColors.textPrimary.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: Column(
        children: [
          const AppLogo(
            size: 64,
            borderRadius: 16,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.bgSurfaceHover,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.textPrimary.withValues(alpha: 0.1),
              ),
            ),
            child: const Text(
              'TRUTH-FIRST VIDEO PLATFORM • VERIFIED MEDIA INFRASTRUCTURE',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'The Next Generation of\nTrusted Video Publishing',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isDesktop ? 44 : (isTablet ? 34 : 26),
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              letterSpacing: -1.0,
              height: 1.18,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            constraints: const BoxConstraints(maxWidth: 820),
            child: const Text(
              'Truthworld is an enterprise-grade verified video streaming platform built to eliminate misinformation and empower authentic digital creators. By combining automated claim verification, creator-backed source attribution, and global multilingual AI dubbing, Truthworld delivers transparent, accountable, and rewarding video experiences across more than 70 languages.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
                height: 1.65,
              ),
            ),
          ),
          const SizedBox(height: 36),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              Obx(() {
                if (AuthService.to.hasChannel.value) {
                  return const SizedBox.shrink();
                }
                return ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Get.toNamed('/channelscreen');
                  },
                  icon: const Icon(
                    Icons.rocket_launch_rounded,
                    color: AppColors.bgPage,
                    size: 18,
                  ),
                  label: const Text('Start Creating'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.textPrimary,
                    foregroundColor: AppColors.bgPage,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }),
              OutlinedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Get.toNamed('/upload');
                },
                icon: const Icon(
                  Icons.fact_check_outlined,
                  color: AppColors.textPrimary,
                  size: 18,
                ),
                label: const Text('Upload Verified Video'),
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppColors.bgSurfaceHover,
                  foregroundColor: AppColors.textPrimary,
                  side: BorderSide(
                    color: AppColors.textPrimary.withValues(alpha: 0.1),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
