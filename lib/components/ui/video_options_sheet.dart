import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/share_bottom_sheet.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/user_preferences_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/home/presentation/controllers/main_controller.dart';
import 'package:truthworld/features/playlist/presentation/views/playlist/show_dialog.dart';
import 'package:truthworld/features/search/presentation/controllers/search_controller.dart'
    as search_ctrl;
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/downloadcontroller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/widgets/video_analysis_bottom_sheet.dart';
import 'package:truthworld/theme/app_theme.dart';

class VideoOptionsSheet extends StatelessWidget {
  const VideoOptionsSheet({
    required this.video,
    super.key,
    this.onRemoveFromHistory,
    this.onRemoveFromWatchLater,
    this.onSaveToWatchLater,
    this.onSaveToPlaylist,
    this.onDownloadVideo,
    this.onDownloadAudio,
    this.onNotInterested,
    this.onBlockChannel,
    this.onReport,
  });
  final Video video;
  final VoidCallback? onRemoveFromHistory;
  final VoidCallback? onRemoveFromWatchLater;
  final VoidCallback? onSaveToWatchLater;
  final VoidCallback? onSaveToPlaylist;
  final VoidCallback? onDownloadVideo;
  final VoidCallback? onDownloadAudio;
  final VoidCallback? onNotInterested;
  final VoidCallback? onBlockChannel;
  final VoidCallback? onReport;

  static void show(
    BuildContext context,
    Video video, {
    VoidCallback? onRemoveFromHistory,
    VoidCallback? onRemoveFromWatchLater,
    VoidCallback? onSaveToWatchLater,
    VoidCallback? onSaveToPlaylist,
    VoidCallback? onDownloadVideo,
    VoidCallback? onDownloadAudio,
    VoidCallback? onNotInterested,
    VoidCallback? onBlockChannel,
    VoidCallback? onReport,
  }) {
    Get.bottomSheet(
      VideoOptionsSheet(
        video: video,
        onRemoveFromHistory: onRemoveFromHistory,
        onRemoveFromWatchLater: onRemoveFromWatchLater,
        onSaveToWatchLater: onSaveToWatchLater,
        onSaveToPlaylist: onSaveToPlaylist,
        onDownloadVideo: onDownloadVideo,
        onDownloadAudio: onDownloadAudio,
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
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                  if (onRemoveFromWatchLater != null)
                    _buildMenuItem(
                      context,
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.error,
                        size: 24,
                      ),
                      title: 'Remove from Watch Later',
                      onTap: () {
                        Get.back();
                        onRemoveFromWatchLater!();
                      },
                    ),
                  if (onRemoveFromWatchLater == null)
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
                      if (onDownloadVideo != null) {
                        onDownloadVideo!();
                        return;
                      }
                      await Future.delayed(const Duration(milliseconds: 100));
                      final downloadsCtrl =
                          Get.isRegistered<DownloadsController>()
                              ? Get.find<DownloadsController>()
                              : Get.put(DownloadsController());
                      downloadsCtrl.showDownloadQualityDialog(
                        null,
                        video,
                      );
                    },
                  ),
                  _buildMenuItem(
                    context,
                    icon: const Icon(
                      Icons.headphones_outlined,
                      color: AppColors.textPrimary,
                      size: 24,
                    ),
                    title: 'Download audio only',
                    onTap: () async {
                      Get.back();
                      if (onDownloadAudio != null) {
                        onDownloadAudio!();
                        return;
                      }
                      final downloadsCtrl =
                          Get.isRegistered<DownloadsController>()
                              ? Get.find<DownloadsController>()
                              : Get.put(DownloadsController());
                      await downloadsCtrl.downloadAudioOffline(
                        video: video,
                      );
                    },
                  ),
                  if (!video.isNonCredibilityCategory)
                    _buildMenuItem(
                      context,
                      icon: const Icon(
                        Icons.verified_outlined,
                        color: AppColors.textPrimary,
                        size: 24,
                      ),
                      title: video.hasAiCredibility
                          ? 'View Fact-Check analysis'
                          : 'Fact-Check this video',
                      onTap: () {
                        Get.back();
                        _handleFactCheckAction(context, video);
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
      'Copyright or Intellectual Property Infringement',
      'Non-consensual sexual content or deepfakes (24h Expedited Review)',
      'Hate speech, harassment, or cyberbullying',
      'Violence, graphic content, or dangerous acts',
      'Child safety or exploitation',
      'Impersonation, defamation, or privacy invasion',
      'Misinformation, scams, or fraud',
      'Threat to national security, sovereignty, or public order',
      'Sexual or explicit adult content',
      'Spam or misleading content',
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
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select the category that best describes the issue under our Community Guidelines & Intermediary Policy:',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...reasons.map((reason) {
                      return RadioListTile<String>(
                        title: Text(
                          reason,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
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
                        dense: true,
                      );
                    }),
                    if (selectedReason.value ==
                        'Copyright or Intellectual Property Infringement') ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Are you the copyright owner or authorized agent?',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'For formal statutory takedowns under DMCA and Indian Copyright Act, you can submit our official notice form.',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () {
                                Navigator.of(context).pop();
                                Get.toNamed('/copyright-complaint', arguments: {
                                  'videoId': video.id,
                                  'videoTitle': video.title,
                                });
                              },
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Open Official Copyright Takedown Form',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF3B82F6),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(
                                    Icons.arrow_forward,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
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
                            : Get.put(MainController(), permanent: true);
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

  static Future<void> _handleFactCheckAction(BuildContext context, Video video) async {
    if (video.isFactChecked || video.factCheckUrl.isNotEmpty) {
      Get.bottomSheet(
        VideoAnalysisBottomSheet(
          video: video,
        ),
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
      );
      return;
    }

    final auth = Get.isRegistered<AuthService>() ? AuthService.to : null;
    if (auth == null || !auth.isAuthenticated.value) {
      AppSnackbar.warning(
        'Please sign in to fact-check this video.',
        title: 'Sign In Required',
      );
      return;
    }

    if (!auth.hasFactCheckPremium) {
      Get.bottomSheet(
        Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: AppColors.bgPage,
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
                      color: AppColors.brand.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.verified_outlined, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      r'Fact-Checked Plan ($3)',
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
                r'On-demand AI video fact-checking is exclusive to the $3 TruthWorld Premium + Fact-Checked Plan. Upgrade to fact-check any video instantly with AI claim verification and truth scores.',
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text(
                    r'Upgrade to $3 Fact-Checked Plan',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        isScrollControlled: true,
      );
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.factCheckRequests)
          .add({
        'videoId': video.id,
        'videoTitle': video.title,
        'channelId': video.channelId,
        'channelName': video.channelName,
        'requestedBy': auth.user?.uid ?? 'anonymous',
        'requestedAt': FieldValue.serverTimestamp(),
        'status': 'queued',
        'priority': 'high',
      });
      AppSnackbar.success(
        'AI Fact-Checking initiated! Epistemic analysis and claim verification is in progress for this video.',
        title: 'Fact-Check Initiated',
      );
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'VideoOptionsSheet.handleFactCheckAction');
      AppSnackbar.error('Unable to queue fact-check request. Please try again.');
    }
  }
}
