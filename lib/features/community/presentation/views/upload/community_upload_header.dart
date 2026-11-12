import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/utils/route_redirect_middleware.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Top header for the Community Post Upload screen with back navigation.
class CommunityUploadHeader extends StatelessWidget {
  final bool isMobile;

  const CommunityUploadHeader({
    required this.isMobile,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            InkWell(
              onTap: () {
                if (Navigator.of(context).canPop()) {
                  Get.back();
                } else {
                  RouteStackObserver.navigateToStudio();
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF141414),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.colors.divider),
                ),
                child: const Icon(
                  Icons.arrow_back,
                  color: AppColors.textPrimary, // White icon only
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Create Community Post',
                style: context.twTypography.display.copyWith(
                  fontSize: isMobile ? 20 : 26,
                  fontWeight: FontWeight.bold,
                  color: context.colors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Share updates, thoughts, or important announcements with your community.',
          style: context.twTypography.body.copyWith(
            fontSize: 14,
            color: context.colors.textSecondary,
          ),
        ),
      ],
    );
  }
}
