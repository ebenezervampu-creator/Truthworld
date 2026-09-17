import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/core/widgets/app_logo.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Top Navigation Bar for Desktop Studio
class CreateContentDesktopHeader extends StatelessWidget {
  const CreateContentDesktopHeader({
    required this.uploadController,
    super.key,
  });

  final UploadController uploadController;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final selectedChannel = uploadController.selectedChannel.value;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: context.colors.background,
          border: Border(
            bottom: BorderSide(
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
        ),
        child: Row(
          children: [
            Row(
              children: [
                const AppLogo(
                  size: 26,
                  borderRadius: 6,
                ),
                const SizedBox(width: 8),
                Text(
                  'TRUTHWORLD',
                  style: context.themeTypography.logo.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (selectedChannel != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF161618),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Row(
                  children: [
                    UserAvatar(
                      photoUrl: selectedChannel.avatarUrl,
                      displayName: selectedChannel.channelName,
                      radius: 12,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      selectedChannel.channelName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    });
  }
}
