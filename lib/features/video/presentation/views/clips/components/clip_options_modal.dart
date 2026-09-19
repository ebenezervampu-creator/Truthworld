import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/share_bottom_sheet.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/video/data/models/video_clip.dart';
import 'package:truthworld/features/video/presentation/controllers/user_clips_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

class ClipOptionsModal {
  const ClipOptionsModal._();

  static void show(
    BuildContext context,
    VideoClip clip,
    UserClipsController controller,
  ) {
    final encodedTitle = Uri.encodeComponent(clip.title);
    final clipUrl =
        'https://www.truthworld.in/watch?v=${clip.videoId}&start=${clip.startTime.toInt()}&end=${clip.endTime.toInt()}&clipTitle=$encodedTitle';
    final durationSec = (clip.endTime - clip.startTime).toInt();

    Get.bottomSheet<void>(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: AppColors.textDisabled,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            _buildOptionItem(
              icon: Icons.play_arrow_rounded,
              label: 'Play Clip',
              onTap: () {
                Get.back<void>();
                controller.playClip(clip);
              },
            ),
            _buildOptionItem(
              icon: Icons.bookmark_added_rounded,
              label: 'Saved in your Clips',
              onTap: () {
                Get.back<void>();
                AppSnackbar.info(
                  'This clip is saved in your library',
                  title: 'Saved',
                );
              },
            ),
            _buildOptionItem(
              icon: Icons.share_rounded,
              label: 'Share clip with Truthworld Watermark',
              onTap: () {
                Get.back<void>();
                ShareBottomSheet.show(
                  title: clip.title,
                  url: clipUrl,
                  thumbnailUrl: clip.thumbnailUrl,
                  subtitle:
                      '🎬 Watch clip: "${clip.title}" [${clip.startTime.toInt()}s - ${clip.endTime.toInt()}s]\n'
                      '✨ Truthworld Watermark\n'
                      '👇 Tap to watch in Truthworld App:\n'
                      '$clipUrl',
                  channelName: clip.channelName,
                  durationMs: durationSec * 1000,
                  type: 'clip',
                  clipStartTime: clip.startTime,
                  clipEndTime: clip.endTime,
                  videoId: clip.videoId,
                  videoTitle: clip.videoTitle,
                );
              },
            ),
            _buildOptionItem(
              icon: Icons.delete_outline_rounded,
              label: 'Delete from clips',
              color: AppColors.error,
              onTap: () {
                Get.back<void>();
                _showDeleteConfirmation(context, clip, controller);
              },
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildOptionItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final textColor = color ?? AppColors.textPrimary;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (color ?? AppColors.brand).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  static void _showDeleteConfirmation(
    BuildContext context,
    VideoClip clip,
    UserClipsController controller,
  ) {
    Get.dialog<void>(
      AlertDialog(
        backgroundColor: AppColors.bgSurface,
        title: const Text(
          'Delete clip?',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${clip.title}" from your clips?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back<void>(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back<void>();
              controller.deleteClip(clip.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.black,
              elevation: 0,
            ),
            child: const Text('Delete'),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
