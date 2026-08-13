import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:truthworld/components/ui/share_bottom_sheet.dart';
import 'package:truthworld/core/services/user_preferences_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/offline.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/home/presentation/controllers/main_controller.dart';
import 'package:truthworld/features/playlist/presentation/views/playlist/show_diaglog.dart';
import 'package:truthworld/features/search/presentation/controllers/search_controller.dart'
    as search_ctrl;
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/domain/database_helpers.dart';
import 'package:truthworld/features/video/presentation/controllers/downloadcontroller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

class VideoOptionsSheet extends StatelessWidget {
  const VideoOptionsSheet({
    required this.video,
    super.key,
    this.onRemoveFromHistory,
    this.onSaveToWatchLater,
    this.onSaveToPlaylist,
    this.onDownloadVideo,
    this.onNotInterested,
    this.onBlockChannel,
    this.onReport,
  });
  final Video video;
  final VoidCallback? onRemoveFromHistory;
  final VoidCallback? onSaveToWatchLater;
  final VoidCallback? onSaveToPlaylist;
  final VoidCallback? onDownloadVideo;
  final VoidCallback? onNotInterested;
  final VoidCallback? onBlockChannel;
  final VoidCallback? onReport;

  static void show(
    BuildContext context,
    Video video, {
    VoidCallback? onRemoveFromHistory,
    VoidCallback? onSaveToWatchLater,
    VoidCallback? onSaveToPlaylist,
    VoidCallback? onDownloadVideo,
    VoidCallback? onNotInterested,
    VoidCallback? onBlockChannel,
    VoidCallback? onReport,
  }) {
    Get.bottomSheet(
      VideoOptionsSheet(
        video: video,
        onRemoveFromHistory: onRemoveFromHistory,
        onSaveToWatchLater: onSaveToWatchLater,
        onSaveToPlaylist: onSaveToPlaylist,
        onDownloadVideo: onDownloadVideo,
        onNotInterested: onNotInterested,
        onBlockChannel: onBlockChannel,
        onReport: onReport,
      ),
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      enterBottomSheetDuration: const Duration(milliseconds: 250),
      exitBottomSheetDuration: const Duration(milliseconds: 150),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Material(
          color: const Color(
            0xFF1E1E1E,
          ), // Premium dark theme matching screenshot
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  if (onRemoveFromHistory != null)
                    _buildMenuItem(
                      context,
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.error,
                        size: 24,
                      ),
                      title: 'Remove from watch history',
                      onTap: () {
                        Get.back();
                        onRemoveFromHistory!();
                      },
                    ),
                  _buildMenuItem(
                    context,
                    icon: const Icon(
                      Icons.watch_later_outlined,
                      color: AppColors.textPrimary,
                      size: 24,
                    ),
                    title: 'Save to Watch later',
                    onTap: () {
                      Get.back();
                      showModernizedPlaylistDialog(
                        context: context,
                        videoId: video.id,
                      );
                    },
                  ),
                  _buildMenuItem(
                    context,
                    icon: const Icon(
                      Icons.bookmark_outline_rounded,
                      color: AppColors.textPrimary,
                      size: 24,
                    ),
                    title: 'Save to playlist',
                    onTap: () {
                      Get.back();
                      showModernizedPlaylistDialog(
                        context: context,
                        videoId: video.id,
                      );
                    },
                  ),
                  _buildMenuItem(
                    context,
                    icon: const Icon(
                      Icons.download_outlined,
                      color: AppColors.textPrimary,
                      size: 24,
                    ),
                    title: 'Download video',
                    onTap: () async {
                      Get.back();
                      if (Get.isRegistered<VideoController>() &&
                          Get.find<VideoController>().video.id == video.id) {
                        final vc = Get.find<VideoController>();
                        if (vc.currentResolution.value != null) {
                          await vc.saveVideoOffline(
                            vc.currentResolution.value!,
                          );
                          if (Get.isRegistered<DownloadsController>()) {
                            Get.find<DownloadsController>().loadVideos();
                          }
                          return;
                        }
                      }
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

                        var videoBytes = Uint8List(0);
                        final targetUrl = video.originalUrl.isNotEmpty
                            ? video.originalUrl
                            : video.videoUrl;
                        if (targetUrl.isNotEmpty &&
                            targetUrl.startsWith('http')) {
                          final res = await http.get(Uri.parse(targetUrl));
                          if (res.statusCode == 200) {
                            videoBytes = res.bodyBytes;
                          }
                        }

                        await saveOfflineVideoBytes(
                          video.id,
                          videoBytes,
                          offlineVideo,
                        );

                        if (Get.isRegistered<DownloadsController>()) {
                          Get.find<DownloadsController>().loadVideos();
                        }

                        if (!context.mounted) return;
                        AppSnackbar.show(
                          'Download Complete',
                          "'${video.title}' downloaded successfully for offline viewing.",
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: AppColors.success.withValues(
                            alpha: 0.8,
                          ),
                          colorText: AppColors.textPrimary,
                          margin: const EdgeInsets.all(20),
                          borderRadius: 16,
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        AppSnackbar.show(
                          'Download Failed',
                          'Could not download video: $e',
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: AppColors.error.withValues(
                            alpha: 0.8,
                          ),
                          colorText: AppColors.textPrimary,
                          margin: const EdgeInsets.all(20),
                          borderRadius: 16,
                        );
                      }
                    },
                  ),
                  _buildMenuItem(
                    context,
                    icon: Transform.flip(
                      flipX: true,
                      child: const Icon(
                        Icons.reply_outlined,
                        color: AppColors.textPrimary,
                        size: 24,
                      ),
                    ),
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
                    icon: const Icon(
                      Icons.block_outlined,
                      color: AppColors.textPrimary,
                      size: 24,
                    ),
                    title: 'Not interested',
                    onTap: () {
                      Get.back();
                      UserPreferencesService.to.hideVideo(video.id);
                      _removeVideoFromControllers(video.id);
                      AppSnackbar.show(
                        'Not interested',
                        "We won't recommend this video anymore.",
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: AppColors.bgSurfaceHover,
                        colorText: AppColors.textPrimary,
                        margin: const EdgeInsets.all(20),
                        borderRadius: 16,
                        mainButton: TextButton(
                          onPressed: () {
                            if (Get.isSnackbarOpen) Get.back();
                            UserPreferencesService.to.unhideVideo(video.id);
                            if (Get.isRegistered<HomeController>()) {
                              Get.find<HomeController>().fetchInitialVideos();
                            }
                            AppSnackbar.show(
                              'Restored',
                              'Video recommendation restored.',
                              snackPosition: SnackPosition.BOTTOM,
                            );
                          },
                          child: const Text(
                            'Undo',
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
                    icon: const Icon(
                      Icons.no_accounts_outlined,
                      color: AppColors.textPrimary,
                      size: 24,
                    ),
                    title: "Don't recommend channel",
                    onTap: () {
                      Get.back();
                      UserPreferencesService.to.blockChannel(
                        video.channelId,
                        channelName: video.channelName,
                      );
                      _removeChannelFromControllers(
                        video.channelId,
                        video.channelName,
                      );
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
                            UserPreferencesService.to.unblockChannel(
                              video.channelId,
                              channelName: video.channelName,
                            );
                            if (Get.isRegistered<HomeController>()) {
                              Get.find<HomeController>().fetchInitialVideos();
                            }
                            AppSnackbar.show(
                              'Restored',
                              'Channel recommendations restored.',
                              snackPosition: SnackPosition.BOTTOM,
                            );
                          },
                          child: const Text(
                            'Undo',
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
                    icon: const Icon(
                      Icons.flag_outlined,
                      color: AppColors.textPrimary,
                      size: 24,
                    ),
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
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required Widget icon,
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              icon,
              const SizedBox(width: 20),
              Text(
                title,
                style: const TextStyle(
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
    final isSubmitting = false.obs;

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
            title: const Text(
              'Report Video',
              style: TextStyle(
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
                    style: const TextStyle(
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
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: (selectedReason.value == null || isSubmitting.value)
                    ? null
                    : () {
                        isSubmitting.value = true;
                        final reason = selectedReason.value!;
                        Navigator.of(context).pop();
                        final mainController = Get.isRegistered<MainController>()
                            ? Get.find<MainController>()
                            : Get.put(MainController());
                        mainController.reportVideo(
                          context: context,
                          videoId: video.id,
                          channelId: video.channelId,
                          reason: reason,
                          comment: '',
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: AppColors.brand.withValues(
                    alpha: 0.3,
                  ),
                  disabledForegroundColor: Colors.black54,
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

  static void _removeVideoFromControllers(String videoId) {
    if (Get.isRegistered<HomeController>()) {
      final hc = Get.find<HomeController>();
      hc.videos.removeWhere((v) => v.id == videoId);
      hc.recommendedVideos.removeWhere((v) => v.id == videoId);
      hc.trendingVideos.removeWhere((v) => v.id == videoId);
      hc.musicVideos.removeWhere((v) => v.id == videoId);
    }
    if (Get.isRegistered<VideoController>()) {
      final vc = Get.find<VideoController>();
      vc.recommendedVideos.removeWhere((v) => v.id == videoId);
    }
    if (Get.isRegistered<search_ctrl.SearchController>()) {
      final sc = Get.find<search_ctrl.SearchController>();
      sc.searchResults.removeWhere((v) => v.id == videoId);
    }
  }

  static void _removeChannelFromControllers(
    String channelId,
    String channelName,
  ) {
    bool matches(Video v) {
      if (channelId.isNotEmpty && v.channelId == channelId) return true;
      if (channelName.isNotEmpty && v.channelName == channelName) return true;
      return false;
    }

    if (Get.isRegistered<HomeController>()) {
      final hc = Get.find<HomeController>();
      hc.videos.removeWhere(matches);
      hc.recommendedVideos.removeWhere(matches);
      hc.trendingVideos.removeWhere(matches);
      hc.musicVideos.removeWhere(matches);
    }
    if (Get.isRegistered<VideoController>()) {
      final vc = Get.find<VideoController>();
      vc.recommendedVideos.removeWhere(matches);
    }
    if (Get.isRegistered<search_ctrl.SearchController>()) {
      final sc = Get.find<search_ctrl.SearchController>();
      sc.searchResults.removeWhere(
        (res) => channelName.isNotEmpty && res.channelName == channelName,
      );
    }
  }
}
