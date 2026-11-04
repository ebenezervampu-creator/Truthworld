import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/channel/presentation/views/channel/widgets/channel_membership_join_sheet.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/downloads/download_resolution_manager.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Modal bottom sheet dialog allowing users to pick video resolution or audio-only offline format.
class DownloadQualityDialog {
  /// Determines if a resolution requires a premium subscription (> 720p).
  static bool isPremiumResolution(VideoResolutionV2 res) {
    final height = res.height > 0
        ? res.height
        : DownloadResolutionManager.inferHeightFromLabel(res.label);
    return height > 720;
  }

  /// Evaluates whether the current user has premium access for high-res downloads.
  static bool hasPremiumAccess(Video video) {
    try {
      if (Get.isRegistered<AuthService>() && AuthService.to.hasFullPremium) {
        return true;
      }
      if (Get.isRegistered<VideoController>(tag: video.id)) {
        final vc = Get.find<VideoController>(tag: video.id);
        if (vc.canStreamHighResolution) return true;
      } else if (Get.isRegistered<VideoController>()) {
        final vc = Get.find<VideoController>();
        if (vc.video.id == video.id && vc.canStreamHighResolution) {
          return true;
        }
      }
      if (video.channelId.isNotEmpty &&
          Get.isRegistered<ChannelController>(tag: video.channelId)) {
        final cc = Get.find<ChannelController>(tag: video.channelId);
        if (cc.subController.isChannelMember.value &&
            cc.selectedChannel.value?.noAdsForMembers == true) {
          return true;
        }
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'DownloadQualityDialog.hasPremiumAccess',
      );
    }
    return false;
  }

  /// Triggers upgrade workflow when non-premium user taps locked high-res option.
  static void showUpgradePrompt(BuildContext context, Video video) {
    try {
      if (Get.isRegistered<VideoController>(tag: video.id)) {
        final vc = Get.find<VideoController>(tag: video.id);
        final channel = vc.channelController.selectedChannel.value;
        if (channel != null && channel.noAdsForMembers) {
          Navigator.of(context).pop();
          ChannelMembershipJoinSheet.show(
            context,
            channelId: channel.channelId,
            channel: channel,
          );
          return;
        }
      } else if (video.channelId.isNotEmpty &&
          Get.isRegistered<ChannelController>(tag: video.channelId)) {
        final cc = Get.find<ChannelController>(tag: video.channelId);
        final channel = cc.selectedChannel.value;
        if (channel != null && channel.noAdsForMembers) {
          Navigator.of(context).pop();
          ChannelMembershipJoinSheet.show(
            context,
            channelId: channel.channelId,
            channel: channel,
          );
          return;
        }
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'DownloadQualityDialog.showUpgradePrompt',
      );
    }

    Navigator.of(context).pop();
    showUpgradeSheet(context, video);
  }

  /// Displays the upgrade bottom sheet for offline downloads in high resolution.
  static void showUpgradeSheet(BuildContext? context, Video video) {
    final targetContext = context ?? Get.overlayContext ?? Get.context;
    if (targetContext == null && Get.key.currentState == null) {
      return;
    }
    try {
      Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    color: AppColors.warning,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Premium Download Quality',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Downloading videos in resolutions higher than 720p (1080p, 2K, 4K) requires an active TruthWorld Premium subscription. Upgrade your subscription to unlock crystal clear offline downloads.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Get.back();
                  Get.toNamed('/premium');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text(
                  'Upgrade to Premium',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
      isScrollControlled: true,
    );
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'DownloadQualityDialog.showUpgradeSheet',
      );
    }
  }

  /// Displays the interactive quality & resolution selection bottom sheet.
  static void show(
    BuildContext? context,
    Video video, {
    required Future<List<VideoResolutionV2>> Function(Video video)
        getResolutions,
    required Function(VideoResolutionV2 resolution) onResolutionSelected,
    required VoidCallback onAudioSelected,
  }) {
    final targetContext = context ?? Get.overlayContext ?? Get.context;
    if (targetContext == null) return;

    showModalBottomSheet(
      context: targetContext,
      isScrollControlled: true,
      backgroundColor: AppColors.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: FutureBuilder<List<VideoResolutionV2>>(
            future: getResolutions(video),
            builder: (context, snapshot) {
              final resolutions = snapshot.data ?? [];
              final isLoading =
                  snapshot.connectionState == ConnectionState.waiting;
              final isPremium = hasPremiumAccess(video);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.download_for_offline,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Select Download Quality',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  video.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white10),

                    if (isLoading)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      )
                    else ...[
                      // Resolutions List
                      ...resolutions.map((res) {
                        final badgeText =
                            DownloadResolutionManager.getResolutionBadge(
                          res.label,
                          res.height,
                          fps: res.fps,
                        );
                        final isPremiumRes = isPremiumResolution(res);
                        final isLocked = isPremiumRes && !isPremium;
                        return ListTile(
                          leading: const Icon(
                            Icons.video_file_outlined,
                            color: Colors.white,
                            size: 24,
                          ),
                          title: Row(
                            children: [
                              Text(
                                res.label,
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              if (badgeText.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white12,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    badgeText,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            'Save video for offline viewing',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          trailing: isLocked
                              ? const Icon(
                                  Icons.lock_rounded,
                                  color: AppColors.warning,
                                  size: 18,
                                )
                              : null,
                          onTap: () {
                            if (isLocked) {
                              showUpgradePrompt(bottomSheetContext, video);
                            } else {
                              Navigator.pop(bottomSheetContext);
                              onResolutionSelected(res);
                            }
                          },
                        );
                      }),

                      // Audio Only Tile
                      ListTile(
                        leading: const Icon(
                          Icons.headphones_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                        title: Text(
                          'Audio only',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(
                          'Save audio for offline listening (saves storage & data)',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Audio only',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(bottomSheetContext);
                          onAudioSelected();
                        },
                      ),
                    ],
                    const SizedBox(height: 10),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
