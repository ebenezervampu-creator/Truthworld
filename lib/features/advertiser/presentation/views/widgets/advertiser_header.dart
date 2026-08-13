import 'package:flutter/material.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/advertiser/presentation/controllers/advertiser_portal_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Modular header widget for Advertiser Portal desktop view.
class AdvertiserHeader extends StatelessWidget {
  const AdvertiserHeader({
    required this.controller,
    super.key,
  });

  final AdvertiserPortalController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Color(0xFF141414),
        border: Border(
          bottom: BorderSide(color: AppColors.bgDivider),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            controller.tabTitles[controller.selectedIndex.value],
            style: AppTextStyles.pageTitle.copyWith(
              fontSize: 20,
              color: AppColors.textPrimary,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded, color: Colors.white),
                onPressed: () {},
                tooltip: 'Notifications',
              ),
              const SizedBox(width: 12),
              _buildUserChip(context),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserChip(BuildContext context) {
    final user = AuthService.to.currentUser.value;
    final displayName = user?.displayName ?? 'Advertiser';
    final email = user?.email ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.bgSurfaceHover,
            child: Text(
              displayName.isNotEmpty ? displayName[0].toUpperCase() : 'A',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (email.isNotEmpty)
                Text(
                  email,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
