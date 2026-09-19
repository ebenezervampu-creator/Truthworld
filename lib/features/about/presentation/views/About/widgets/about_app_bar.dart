import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/widgets/app_logo.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Modern top app bar for the About screen adhering to TruthWorld theme and responsive styles.
class AboutModernAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AboutModernAppBar({
    this.isTablet = false,
    super.key,
  });

  final bool isTablet;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.bgPage.withValues(alpha: 0.95),
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      title: Row(
        children: [
          const AppLogo(
            size: 28,
            borderRadius: 6,
          ),
          const SizedBox(width: 12),
          Text(
            'About Truthworld',
            style: TextStyle(
              fontSize: isTablet ? 22 : 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Get.toNamed('/terms'),
          style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
          child: const Text(
            'Terms',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Get.toNamed('/privacy'),
          style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
          child: const Text(
            'Privacy',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Obx(() {
          if (AuthService.to.hasChannel.value) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ElevatedButton(
              onPressed: () => Get.toNamed('/channelscreen'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.textPrimary,
                foregroundColor: AppColors.bgPage,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Get Started',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        }),
        const SizedBox(width: 16),
      ],
    );
  }
}
