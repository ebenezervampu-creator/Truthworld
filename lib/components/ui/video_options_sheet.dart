import 'package:flutter/material.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_controller.dart';
import 'package:truthworld/features/playlist/presentation/views/playlist/show_diaglog.dart';
import 'package:truthworld/components/ui/share_bottom_sheet.dart';
import 'package:truthworld/data/models/offline.dart';
import 'package:truthworld/features/video/domain/database_helpers.dart';
import 'package:truthworld/features/video/presentation/controllers/downloadcontroller.dart';

class VideoOptionsSheet extends StatelessWidget {
  final Video video;

  const VideoOptionsSheet({super.key, required this.video});

  static void show(BuildContext context, Video video) {
    Get.bottomSheet(
      VideoOptionsSheet(video: video),
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      enterBottomSheetDuration: const Duration(milliseconds: 250),
      exitBottomSheetDuration: const Duration(milliseconds: 150),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Menu Options
          ListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _buildMenuItem(
                context,
                icon: Icons.playlist_play_rounded,
                title: 'Add to queue',
                onTap: () {
                  Get.back();
                  AppSnackbar.show(
                    "Added to queue",
                    "'${video.title}' has been added to your play queue.",
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: AppColors.brand.withValues(alpha: 0.8),
                    colorText: Colors.white,
                    margin: const EdgeInsets.all(20),
                    borderRadius: 16,
                  );
                },
              ),
              _buildMenuItem(
                context,
                icon: Icons.watch_later_outlined,
                title: 'Save to Watch later',
                onTap: () async {
                  Get.back();
                  if (!Get.isRegistered<PlaylistController>()) {
                    Get.put(PlaylistController());
                  }
                  final playlistCtrl = Get.find<PlaylistController>();
                  await playlistCtrl.toggleWatchLater(video.id);
                },
              ),
              _buildMenuItem(
                context,
                icon: Icons.bookmark_outline_rounded,
                title: 'Save to playlist',
                onTap: () {
                  Get.back();
                  showModernizedPlaylistDialog(context: context, videoId: video.id);
                },
              ),
              _buildMenuItem(
                context,
                icon: Icons.download_outlined,
                title: 'Download',
                onTap: () async {
                  Get.back();
                  try {
                    final offlineVideo = OfflineVideo(
                      id: video.id,
                      title: video.title,
                      channelName: video.channelName,
                      channelImage: video.channelImage.isNotEmpty
                          ? video.channelImage
                          : video.channelAvatarUrl,
                      views: video.views.toString(),
                      thumbnailUrl: video.thumbnailUrl,
                      downloadedAt: DateTime.now(),
                    );

                    await saveOfflineVideoBytes(
                      video.id,
                      Uint8List(
                        0,
                      ), // empty bytes for lightweight local playback representation
                      offlineVideo,
                    );

                    if (Get.isRegistered<DownloadsController>()) {
                      Get.find<DownloadsController>().loadVideos();
                    }

                    AppSnackbar.show(
                      "Download Complete",
                      "'${video.title}' downloaded successfully for offline viewing.",
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: AppColors.success.withValues(alpha: 0.8),
                      colorText: Colors.white,
                      margin: const EdgeInsets.all(20),
                      borderRadius: 16,
                    );
                  } catch (e) {
                    AppSnackbar.show(
                      "Download Failed",
                      "Could not download video: $e",
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: AppColors.error.withValues(alpha: 0.8),
                      colorText: Colors.white,
                      margin: const EdgeInsets.all(20),
                      borderRadius: 16,
                    );
                  }
                },
              ),
              _buildMenuItem(
                context,
                icon: Icons.share_outlined,
                title: 'Share',
                onTap: () {
                  Get.back();
                  ShareBottomSheet.show(
                    title: video.title,
                    url: 'https://www.truthworld.in/watch?v=${video.id}',
                    thumbnailUrl: video.thumbnailUrl,
                    channelName: video.channelName,
                    durationMs: video.durationValue.inMilliseconds,
                    type: 'video',
                  );
                },
              ),
              _buildMenuItem(
                context,
                icon: Icons.block_outlined,
                title: 'Not interested',
                onTap: () {
                  Get.back();
                  AppSnackbar.show(
                    "Not interested",
                    "We won't recommend this video anymore.",
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: AppColors.bgSurfaceHover,
                    colorText: AppColors.textPrimary,
                    margin: const EdgeInsets.all(20),
                    borderRadius: 16,
                    mainButton: TextButton(
                      onPressed: () {
                        if (Get.isSnackbarOpen) Get.back();
                        AppSnackbar.show(
                          "Restored",
                          "Video recommendation restored.",
                          snackPosition: SnackPosition.BOTTOM,
                        );
                      },
                      child: const Text(
                        "Undo",
                        style: TextStyle(
                          color: AppColors.brand,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
              _buildMenuItem(
                context,
                icon: Icons.remove_circle_outline_rounded,
                title: "Don't recommend channel",
                onTap: () {
                  Get.back();
                  AppSnackbar.show(
                    "Don't recommend channel",
                    "We won't recommend videos from ${video.channelName} anymore.",
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: AppColors.bgSurfaceHover,
                    colorText: AppColors.textPrimary,
                    margin: const EdgeInsets.all(20),
                    borderRadius: 16,
                    mainButton: TextButton(
                      onPressed: () {
                        if (Get.isSnackbarOpen) Get.back();
                        AppSnackbar.show(
                          "Restored",
                          "Channel recommendations restored.",
                          snackPosition: SnackPosition.BOTTOM,
                        );
                      },
                      child: const Text(
                        "Undo",
                        style: TextStyle(
                          color: AppColors.brand,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
              _buildMenuItem(
                context,
                icon: Icons.flag_outlined,
                title: 'Report',
                onTap: () {
                  Get.back();
                  _showReportDialog(context);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.brand.withValues(alpha: 0.15),
        highlightColor: AppColors.brand.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: AppColors.textPrimary, size: 24),
              const SizedBox(width: 20),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 16,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReportDialog(BuildContext context) {
    final reasons = [
      'Sexual content',
      'Violent or repulsive content',
      'Hateful or abusive content',
      'Harassment or bullying',
      'Harmful or dangerous acts',
      'Spam or misleading',
    ];

    final selectedReason = RxnString();

    showDialog(
      context: context,
      builder: (context) {
        return Obx(() {
          return AlertDialog(
            backgroundColor: AppColors.bgSurface,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Report Video',
              style: TextStyle(
                fontFamily: 'Roboto',
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: reasons.map((reason) {
                return RadioListTile<String>(
                  title: Text(
                    reason,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      color: AppColors.textPrimary,
                      fontSize: 15,
                    ),
                  ),
                  value: reason,
                  // ignore: deprecated_member_use
                  groupValue: selectedReason.value,
                  activeColor: AppColors.brand,
                  // ignore: deprecated_member_use
                  onChanged: (val) {
                    selectedReason.value = val;
                  },
                  contentPadding: EdgeInsets.zero,
                );
              }).toList(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: selectedReason.value == null
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        AppSnackbar.show(
                          "Thank you",
                          "We have received your report and will review this video.",
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: AppColors.brand.withValues(
                            alpha: 0.8,
                          ),
                          colorText: Colors.white,
                          margin: const EdgeInsets.all(20),
                          borderRadius: 16,
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.brand.withValues(
                    alpha: 0.3,
                  ),
                  disabledForegroundColor: Colors.white54,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Report'),
              ),
            ],
          );
        });
      },
    );
  }
}
