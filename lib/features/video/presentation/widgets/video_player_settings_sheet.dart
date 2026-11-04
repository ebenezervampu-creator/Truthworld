import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/downloadcontroller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/routes/app_routes.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Modal bottom sheets and quality dialogs for video playback speed, quality,
/// loop toggles, and offline download settings.
class VideoPlayerSettingsSheet {
  static void showSettings({
    required BuildContext context,
    required VideoController controller,
  }) {
    Get.bottomSheet(
      Material(
        color: AppColors.bgSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Player Settings',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 24),
              _settingsTile(
                Icons.speed_rounded,
                'Playback Speed',
                '${controller.videoPlayerController?.value.playbackSpeed ?? 1.0}x',
                () {},
              ),
              _settingsTile(Icons.high_quality_rounded, 'Quality', 'Auto', () {}),
              _settingsTile(
                Icons.loop_rounded,
                'Loop Video',
                (controller.videoPlayerController?.value.isLooping ?? false)
                    ? 'On'
                    : 'Off',
                () {},
              ),
            ],
          ),
        ),
      ),
      backgroundColor: Colors.transparent,
    );
  }

  static Widget _settingsTile(
    IconData icon,
    String title,
    String value,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(color: AppColors.brand, fontWeight: FontWeight.w500),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: Colors.white,
          ),
        ],
      ),
      onTap: onTap,
    );
  }

  static void showDownloadQualityDialog({
    required BuildContext context,
    required VideoController controller,
    required bool isUserSignedIn,
    required VoidCallback onSignInPrompt,
  }) {
    if (!isUserSignedIn) return onSignInPrompt();

    final downloadsCtrl = Get.isRegistered<DownloadsController>()
        ? Get.find<DownloadsController>()
        : Get.put(DownloadsController());

    downloadsCtrl.showDownloadQualityDialog(
      context,
      controller.video,
      onResolutionSelected: (res) => controller.saveVideoOffline(res),
      onAudioSelected: () => controller.saveAudioOffline(),
    );
  }

  /// Displays the interactive "Downloaded Video Options" sheet when a user taps "Downloaded"
  /// Providing options to:
  /// 1. Delete from downloads
  /// 2. Download in other resolutions / change download quality
  /// 3. View in downloads
  static void showDownloadedOptionsSheet({
    BuildContext? context,
    Video? video,
    VideoController? controller,
    DownloadsController? downloadsCtrl,
  }) {
    final v = video ?? controller?.video;
    if (v == null) return;

    final DownloadsController dlCtrl = downloadsCtrl ??
        (Get.isRegistered<DownloadsController>()
            ? Get.find<DownloadsController>()
            : Get.put(DownloadsController()));

    final offlineVideo =
        dlCtrl.videos.firstWhereOrNull((item) => item.id == v.id);
    final currentQuality = offlineVideo?.quality ?? '';

    Get.bottomSheet(
      SafeArea(
        child: Material(
          color: AppColors.bgSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textTertiary.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Video info header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          width: 56,
                          height: 34,
                          child: v.thumbnailUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: v.thumbnailUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) =>
                                      Container(color: AppColors.bgSurfaceHigh),
                                  errorWidget: (_, __, ___) => Container(
                                    color: AppColors.bgSurfaceHigh,
                                    child: const Icon(
                                      Icons.video_library,
                                      size: 18,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                )
                              : Container(
                                  color: AppColors.bgSurfaceHigh,
                                  child: const Icon(
                                    Icons.video_library,
                                    size: 18,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              v.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Icon(
                                  Icons.check_circle_rounded,
                                  size: 14,
                                  color: AppColors.success,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Downloaded',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.success,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (currentQuality.isNotEmpty) ...[
                                  Text(
                                    ' • $currentQuality',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),
                const Divider(color: AppColors.bgDivider, height: 1),
                const SizedBox(height: 8),

                // Option 1: Other resolutions / Change quality
                ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.bgSurfaceHigh,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.tune_rounded,
                      color: AppColors.textPrimary,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Download in other resolutions',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: const Text(
                    'Switch or upgrade video resolution',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  onTap: () {
                    Get.back();
                    dlCtrl.showDownloadQualityDialog(
                      context ?? Get.context,
                      v,
                      onResolutionSelected: (res) {
                        if (controller != null) {
                          controller.saveVideoOffline(res);
                        } else {
                          dlCtrl.downloadVideoOffline(video: v, resolution: res);
                        }
                      },
                      onAudioSelected: () {
                        if (controller != null) {
                          controller.saveAudioOffline();
                        } else {
                          dlCtrl.downloadAudioOffline(video: v);
                        }
                      },
                    );
                  },
                ),

                // Option 2: Delete from downloads
                ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.errorContainer,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.error,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Delete from downloads',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.error,
                    ),
                  ),
                  subtitle: const Text(
                    'Remove this video from offline storage',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  onTap: () async {
                    Get.back();
                    await dlCtrl.deleteVideoItem(v.id);
                  },
                ),

                // Option 3: View in downloads
                ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.bgSurfaceHigh,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.folder_outlined,
                      color: AppColors.textPrimary,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'View in downloads',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  onTap: () {
                    Get.back();
                    Get.toNamed(AppRoutes.downloads);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }


}
