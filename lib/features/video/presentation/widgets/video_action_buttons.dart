import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/features/channel/data/services/channel_memory_cache.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/home/presentation/controllers/main_controller.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_controller.dart';
import 'package:truthworld/features/playlist/presentation/views/playlist/show_dialog.dart';
import 'package:truthworld/features/video/presentation/controllers/downloadcontroller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/views/comments/premium_comment_input.dart';
import 'package:truthworld/features/video/presentation/views/widgets/animated_reaction_button.dart';
import 'package:truthworld/features/video/presentation/widgets/animated_credibility_button.dart';
import 'package:truthworld/features/video/presentation/widgets/video_analysis_bottom_sheet.dart';
import 'package:truthworld/features/video/presentation/widgets/video_channel_action_bar.dart';
import 'package:truthworld/features/video/presentation/widgets/video_channel_membership_modal.dart';
import 'package:truthworld/features/video/presentation/widgets/video_clip_dialog.dart';
import 'package:truthworld/features/video/presentation/widgets/video_comments_sheet.dart';
import 'package:truthworld/features/video/presentation/widgets/video_player_settings_sheet.dart';
import 'package:truthworld/features/video/presentation/widgets/video_report_bottom_sheet.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Interactive action bar (Mobile 2-row layout and Desktop unified layout)
/// providing likes, dislikes, shares, offline downloads, clipping, playlist bookmarking,
/// and AI claim analysis triggers.
class VideoActionButtons {
  static PlaylistController _getPlaylistController() {
    return Get.isRegistered<PlaylistController>()
        ? Get.find<PlaylistController>()
        : Get.put(PlaylistController());
  }

  static bool _isMobilePlatform(BuildContext context) {
    return MediaQuery.of(context).size.width < TWBreakpoints.desktop;
  }

  /// Evaluates whether the video's channel is verified and active for monetization features (Memberships & Super Thanks).
  static bool _isChannelMonetized({
    required VideoController controller,
    required ChannelController? channelController,
  }) {
    final video = controller.rxVideo.value;
    final effectiveChannelId = video.channelId.isNotEmpty
        ? video.channelId
        : (video.ownerId.isNotEmpty ? video.ownerId : '');

    final cachedChannel = ChannelMemoryCache.getReactive(effectiveChannelId) ??
        channelController?.selectedChannel.value ??
        controller.channelController.selectedChannel.value;

    if (cachedChannel != null) {
      return cachedChannel.isMonetizationActive;
    }
    return video.isMonetized;
  }
  static Widget build({
    required BuildContext context,
    required VideoController controller,
    required MainController mainController,
    required ChannelController? channelController,
    required VoidCallback onSignInPrompt,
    bool? isDesktop,
  }) {
    final mediaQuery = MediaQuery.of(context);
    final effectiveIsDesktop = isDesktop ?? (mediaQuery.size.width >= 900);

    if (!effectiveIsDesktop) {
      // Mobile Layout: Two separate rows for maximum readability and proper spacing
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ⚔️ COIN BATTLE LINKED VIDEO BANNER
          if (controller.video.coinBattlePairVideoId != null &&
              controller.video.coinBattlePairVideoId!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4A148C), Color(0xFF880E4F)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.swap_horiz_rounded, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.sports_kabaddi,
                                size: 14,
                                color: Colors.white,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'COIN BATTLE LINKED DEBATE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Stance: ${controller.video.coinBattleStance ?? "Opposing Viewpoint"}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        controller.videoPlayerController?.pause();
                        Get.toNamed(
                          '/video/${controller.video.coinBattlePairVideoId}',
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                      ),
                      child: const Text('View Debate'),
                    ),
                  ],
                ),
              ),
            ),

          // Row 1: Channel Info & Subscribe Button
          VideoChannelActionBar.buildMobile(
            context: context,
            controller: controller,
            channelController: channelController,
            onSignInPrompt: onSignInPrompt,
          ),
          const SizedBox(height: 12),
          // Row 2: Scrollable Action Buttons
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                // Like & Dislike Group
                _buildModernLikeDislikeGroup(
                  context: context,
                  controller: controller,
                  mainController: mainController,
                  onSignInPrompt: onSignInPrompt,
                ),
                const SizedBox(width: 8),

                // Comment (icon only)
                _buildModernCapsuleButton(
                  icon: Icons.comment_rounded,
                  label: '',
                  tooltip: 'Comments',
                  onTap: () {
                    VideoCommentsSheet.show(
                      context: context,
                      controller: controller,
                      mainController: mainController,
                      onSignInPrompt: onSignInPrompt,
                    );
                  },
                ),
                const SizedBox(width: 8),

                // AI Credibility Check
                Obx(() {
                  final video = controller.rxVideo.value;
                  final currentUid = AuthService.to.uid;
                  final userChannelId = AuthService.to.userChannel?.id;
                  final isOwner = currentUid.isNotEmpty &&
                      (video.ownerId == currentUid ||
                          video.userId == currentUid ||
                          (userChannelId != null &&
                              userChannelId.isNotEmpty &&
                              video.channelId == userChannelId));
                  final isAllowedToView =
                      video.canPublicViewFactCheck || isOwner;
                  final hasCredibility = isAllowedToView &&
                      (video.hasAiCredibility ||
                          controller.video.hasAiCredibility ||
                          controller.factCheckData.isNotEmpty);
                  if (!hasCredibility) return const SizedBox.shrink();
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedCredibilityButton(
                        onTap: () => _showAnalysisBottomSheet(context, controller),
                      ),
                      const SizedBox(width: 8),
                    ],
                  );
                }),

                // Share
                _buildModernCapsuleButton(
                  icon: Icons.share_rounded,
                  label: 'Share',
                  tooltip: 'Share Video',
                  onTap: () {
                    mainController.shareVideo(
                      controller.video.id,
                      controller.video.title,
                      thumbnailUrl: controller.video.thumbnailUrl,
                      channelName: controller.video.channelName,
                      durationMs: controller.video.durationValue.inMilliseconds,
                      currentPosition:
                          controller.videoPlayerController?.value.position,
                    );
                  },
                ),
                const SizedBox(width: 8),

                // Clip
                if (controller.video.allowClipping) ...[
                  _buildModernCapsuleButton(
                    icon: Icons.content_cut_rounded,
                    label: 'Clip',
                    tooltip: 'Clip Video',
                    onTap: () => VideoClipDialog.show(
                      context: context,
                      controller: controller,
                      onSignInPrompt: onSignInPrompt,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],

                // Save / Playlist / Watch Later
                Obx(() {
                  controller.rxVideo.value;
                  final playlistCtrl = _getPlaylistController();
                  playlistCtrl.playlists.length;
                  playlistCtrl.refreshTick.value;
                  final isInWatchLater =
                      playlistCtrl.isInWatchLater(
                        controller.video.id,
                      );
                  final isSavedInAny = isInWatchLater ||
                      playlistCtrl.playlists.any((p) => p.videoIds.contains(controller.video.id));
                  return _buildModernCapsuleButton(
                    icon: isSavedInAny
                        ? Icons.bookmark_added_rounded
                        : Icons.bookmark_outline_rounded,
                    label: isSavedInAny ? 'Saved' : 'Save',
                    tooltip: isSavedInAny ? 'Saved to Playlist' : 'Save to Playlist',
                    onTap: () {
                      if (!AuthService.to.isAuthenticated.value) {
                        return onSignInPrompt();
                      }
                      showModernizedPlaylistDialog(
                        context: context,
                        videoId: controller.video.id,
                      );
                    },
                  );
                }),
                const SizedBox(width: 8),

                // Save (Download)
                Obx(() {
                  final downloadsCtrl = Get.isRegistered<DownloadsController>()
                      ? Get.find<DownloadsController>()
                      : Get.put(DownloadsController());

                  final isDownloading = controller.isDownloading.value ||
                      downloadsCtrl.isVideoDownloading(controller.video.id);

                  if (isDownloading) {
                    final activeTask =
                        downloadsCtrl.activeDownloads[controller.video.id];
                    final mapProgress =
                        downloadsCtrl.downloadProgressMap[controller.video.id];
                    final progress = activeTask != null
                        ? (activeTask.progress.value * 100).toInt()
                        : (mapProgress != null
                            ? (mapProgress * 100).toInt()
                            : (controller.downloadProgress.value * 100).toInt());
                    return _buildDownloadingCapsule(
                      context: context,
                      controller: controller,
                      downloadsCtrl: downloadsCtrl,
                      progress: progress,
                    );
                  }

                  final isDownloaded =
                      downloadsCtrl.isVideoDownloaded(controller.video.id);

                  if (isDownloaded) {
                    return _buildModernCapsuleButton(
                      icon: Icons.download_done_rounded,
                      label: 'Downloaded',
                      tooltip: 'Downloaded Offline',
                      onTap: () =>
                          VideoPlayerSettingsSheet.showDownloadedOptionsSheet(
                        context: context,
                        controller: controller,
                        downloadsCtrl: downloadsCtrl,
                      ),
                    );
                  }

                  return _buildModernCapsuleButton(
                    icon: Icons.download_rounded,
                    label: 'Download',
                    tooltip: 'Download Offline',
                    onTap: () =>
                        VideoPlayerSettingsSheet.showDownloadQualityDialog(
                      context: context,
                      controller: controller,
                      isUserSignedIn: AuthService.to.isAuthenticated.value,
                      onSignInPrompt: onSignInPrompt,
                    ),
                  );
                }),
                const SizedBox(width: 8),

                // Super Thanks & Membership (Only for Monetized channels)
                Obx(() {
                  final isMonetized = _isChannelMonetized(
                    controller: controller,
                    channelController: channelController,
                  );
                  if (!isMonetized) return const SizedBox.shrink();

                  final effectiveChannelId = controller.video.channelId.isNotEmpty
                      ? controller.video.channelId
                      : controller.video.ownerId;

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Super Thanks
                      _buildModernCapsuleButton(
                        icon: Icons.favorite_outline,
                        label: 'Thanks',
                        tooltip: 'Send Super Thanks',
                        onTap: () {
                          if (!AuthService.to.isAuthenticated.value) {
                            return onSignInPrompt();
                          }
                          PremiumCommentInput.showSuperThanksModal(
                            context,
                            videoId: controller.video.id,
                            channelId: effectiveChannelId,
                            videoTitle: controller.video.title,
                            isChannelMonetized: isMonetized,
                          );
                        },
                      ),
                      const SizedBox(width: 8),

                      // Membership / Join
                      _buildModernCapsuleButton(
                        icon: Icons.workspace_premium_outlined,
                        label: 'Membership',
                        tooltip: 'Channel Membership',
                        onTap: () => VideoChannelMembershipModal.show(
                          context: context,
                          controller: controller,
                          isUserSignedIn: AuthService.to.isAuthenticated.value,
                          onSignInPrompt: onSignInPrompt,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  );
                }),

                // More
                _buildModernMoreButton(
                  context: context,
                  controller: controller,
                  mainController: mainController,
                  onSignInPrompt: onSignInPrompt,
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Desktop Layout: Single row with channel info on left and scrollable action buttons on right
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ⚔️ COIN BATTLE LINKED VIDEO BANNER
        if (controller.video.coinBattlePairVideoId != null &&
            controller.video.coinBattlePairVideoId!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4A148C), Color(0xFF880E4F)],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                children: [
                  const Icon(Icons.swap_horiz_rounded, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.sports_kabaddi,
                              size: 14,
                              color: Colors.white,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'COIN BATTLE LINKED DEBATE',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Stance: ${controller.video.coinBattleStance ?? "Opposing Viewpoint"}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      controller.videoPlayerController?.pause();
                      Get.toNamed(
                        '/video/${controller.video.coinBattlePairVideoId}',
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                    ),
                    child: const Text('View Debate'),
                  ),
                ],
              ),
            ),
          ),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Channel Section - on the left
            VideoChannelActionBar.buildDesktop(
              context: context,
              controller: controller,
              channelController: channelController,
              onSignInPrompt: onSignInPrompt,
            ),

            const SizedBox(width: 16),

            // Scrollable Action Buttons - on the right
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minWidth: constraints.maxWidth),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Like & Dislike Group
                          _buildModernLikeDislikeGroup(
                            context: context,
                            controller: controller,
                            mainController: mainController,
                            onSignInPrompt: onSignInPrompt,
                          ),
                          const SizedBox(width: 8),

                          // AI Credibility Check
                          Obx(() {
                            final video = controller.rxVideo.value;
                            final currentUid = AuthService.to.uid;
                            final userChannelId =
                                AuthService.to.userChannel?.id;
                            final isOwner = currentUid.isNotEmpty &&
                                (video.ownerId == currentUid ||
                                    video.userId == currentUid ||
                                    (userChannelId != null &&
                                        userChannelId.isNotEmpty &&
                                        video.channelId == userChannelId));
                            final isAllowedToView =
                                video.canPublicViewFactCheck || isOwner;
                            final hasCredibility = isAllowedToView &&
                                (video.hasAiCredibility ||
                                    controller.video.hasAiCredibility ||
                                    controller.factCheckData.isNotEmpty);
                            if (!hasCredibility) return const SizedBox.shrink();
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedCredibilityButton(
                                  onTap: () => _showAnalysisBottomSheet(context, controller),
                                ),
                                const SizedBox(width: 8),
                              ],
                            );
                          }),

                          // Share
                          _buildModernCapsuleButton(
                            icon: Icons.share_rounded,
                            label: 'Share',
                            tooltip: 'Share Video',
                            onTap: () {
                              mainController.shareVideo(
                                controller.video.id,
                                controller.video.title,
                                thumbnailUrl: controller.video.thumbnailUrl,
                                channelName: controller.video.channelName,
                                durationMs: controller
                                    .video.durationValue.inMilliseconds,
                                currentPosition: controller
                                    .videoPlayerController?.value.position,
                              );
                            },
                          ),
                          const SizedBox(width: 8),

                          // Clip
                          if (controller.video.allowClipping) ...[
                            _buildModernCapsuleButton(
                              icon: Icons.content_cut_rounded,
                              label: 'Clip',
                              tooltip: 'Clip Video',
                              onTap: () => VideoClipDialog.show(
                                context: context,
                                controller: controller,
                                onSignInPrompt: onSignInPrompt,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],

                          // Save / Playlist / Watch Later
                          Obx(() {
                            controller.rxVideo.value;
                            final playlistCtrl = _getPlaylistController();
                            playlistCtrl.playlists.length;
                            playlistCtrl.refreshTick.value;
                            final isInWatchLater =
                                playlistCtrl.isInWatchLater(
                                  controller.video.id,
                                );
                            final isSavedInAny = isInWatchLater ||
                                playlistCtrl.playlists.any((p) => p.videoIds.contains(controller.video.id));
                            return _buildModernCapsuleButton(
                              icon: isSavedInAny
                                  ? Icons.bookmark_added_rounded
                                  : Icons.bookmark_outline_rounded,
                              label: isSavedInAny ? 'Saved' : 'Save',
                              tooltip: isSavedInAny ? 'Saved to Playlist' : 'Save to Playlist',
                              onTap: () {
                                if (!AuthService.to.isAuthenticated.value) {
                                  return onSignInPrompt();
                                }
                                showModernizedPlaylistDialog(
                                  context: context,
                                  videoId: controller.video.id,
                                );
                              },
                            );
                          }),
                          const SizedBox(width: 8),

                          // Save (Download)
                          Obx(() {
                            final downloadsCtrl =
                                Get.isRegistered<DownloadsController>()
                                    ? Get.find<DownloadsController>()
                                    : Get.put(DownloadsController());

                            final isDownloading = controller.isDownloading.value ||
                                downloadsCtrl
                                    .isVideoDownloading(controller.video.id);

                            if (isDownloading) {
                              final activeTask = downloadsCtrl
                                  .activeDownloads[controller.video.id];
                              final mapProgress = downloadsCtrl
                                  .downloadProgressMap[controller.video.id];
                              final progress = activeTask != null
                                  ? (activeTask.progress.value * 100).toInt()
                                  : (mapProgress != null
                                      ? (mapProgress * 100).toInt()
                                      : (controller.downloadProgress.value * 100)
                                          .toInt());
                              return _buildDownloadingCapsule(
                                context: context,
                                controller: controller,
                                downloadsCtrl: downloadsCtrl,
                                progress: progress,
                              );
                            }

                            final isDownloaded = downloadsCtrl
                                .isVideoDownloaded(controller.video.id);

                            if (isDownloaded) {
                              return _buildModernCapsuleButton(
                                icon: Icons.download_done_rounded,
                                label: 'Downloaded',
                                tooltip: 'Downloaded Offline',
                                onTap: () => VideoPlayerSettingsSheet
                                    .showDownloadedOptionsSheet(
                                  context: context,
                                  controller: controller,
                                  downloadsCtrl: downloadsCtrl,
                                ),
                              );
                            }

                            return _buildModernCapsuleButton(
                              icon: Icons.download_rounded,
                              label: 'Download',
                              tooltip: 'Download Offline',
                              onTap: () => VideoPlayerSettingsSheet
                                  .showDownloadQualityDialog(
                                context: context,
                                controller: controller,
                                isUserSignedIn: AuthService.to.isAuthenticated.value,
                                onSignInPrompt: onSignInPrompt,
                              ),
                            );
                          }),
                          const SizedBox(width: 8),

                          // Super Thanks & Membership (Only for Monetized channels)
                          Obx(() {
                            final isMonetized = _isChannelMonetized(
                              controller: controller,
                              channelController: channelController,
                            );
                            if (!isMonetized) return const SizedBox.shrink();

                            final effectiveChannelId = controller.video.channelId.isNotEmpty
                                ? controller.video.channelId
                                : controller.video.ownerId;

                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Super Thanks
                                _buildModernCapsuleButton(
                                  icon: Icons.favorite_outline,
                                  label: 'Thanks',
                                  tooltip: 'Send Super Thanks',
                                  onTap: () {
                                    if (!AuthService.to.isAuthenticated.value) {
                                      return onSignInPrompt();
                                    }
                                    PremiumCommentInput.showSuperThanksModal(
                                      context,
                                      videoId: controller.video.id,
                                      channelId: effectiveChannelId,
                                      videoTitle: controller.video.title,
                                      isChannelMonetized: isMonetized,
                                    );
                                  },
                                ),
                                const SizedBox(width: 8),

                                // Membership / Join
                                _buildModernCapsuleButton(
                                  icon: Icons.workspace_premium_outlined,
                                  label: 'Membership',
                                  tooltip: 'Channel Membership',
                                  onTap: () => VideoChannelMembershipModal.show(
                                    context: context,
                                    controller: controller,
                                    isUserSignedIn: AuthService.to.isAuthenticated.value,
                                    onSignInPrompt: onSignInPrompt,
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                            );
                          }),

                          // More
                          _buildModernMoreButton(
                            context: context,
                            controller: controller,
                            mainController: mainController,
                            onSignInPrompt: onSignInPrompt,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }


  static Widget _buildModernLikeDislikeGroup({
    required BuildContext context,
    required VideoController controller,
    required MainController mainController,
    required VoidCallback onSignInPrompt,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Like Button
          Obx(() {
            final isLiked = controller.isLiked.value;
            final video = controller.rxVideo.value;
            final channelId = video.channelId.isNotEmpty
                ? video.channelId
                : video.ownerId;
            final channel = ChannelMemoryCache.getReactive(channelId);
            final effectiveShowLike = video.showLikeCount &&
                (channel == null || channel.showLikeCount);
            final countStr = effectiveShowLike && controller.likeCount > 0
                ? FormatUtils.formatCount(controller.likeCount)
                : '';
            return AnimatedReactionButton(
              icon: isLiked ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
              label: countStr,
              isActive: isLiked,
              activeColor: AppColors.textPrimary,
              inactiveColor: AppColors.textPrimary,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                bottomLeft: Radius.circular(24),
              ),
              onTap: () {
                if (!AuthService.to.isAuthenticated.value) return onSignInPrompt();
                controller.toggleLike();
              },
            );
          }),
          // Divider
          Container(
            height: 20,
            width: 1,
            color: Colors.white.withValues(alpha: 0.1),
          ),
          // Dislike Button
          Obx(() {
            final isDisliked = controller.isDisliked.value;
            final video = controller.rxVideo.value;
            final channelId = video.channelId.isNotEmpty
                ? video.channelId
                : video.ownerId;
            final channel = ChannelMemoryCache.getReactive(channelId);
            final effectiveShowDislike = video.showDislikeCount &&
                (channel == null || channel.showDislikeCount);
            final countStr = effectiveShowDislike && controller.dislikeCount > 0
                ? FormatUtils.formatCount(controller.dislikeCount)
                : '';
            return AnimatedReactionButton(
              icon: isDisliked
                  ? Icons.thumb_down_rounded
                  : Icons.thumb_down_outlined,
              label: countStr,
              isActive: isDisliked,
              activeColor: AppColors.textPrimary,
              inactiveColor: AppColors.textPrimary,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
              onTap: () {
                if (!AuthService.to.isAuthenticated.value) return onSignInPrompt();
                controller.toggleDislike();
              },
            );
          }),
        ],
      ),
    );
  }

  static Widget _buildModernCapsuleButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    final hasLabel = label.isNotEmpty;
    final button = Material(
      color: AppColors.bgSurface,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: hasLabel ? 16 : 12,
            vertical: 8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: AppColors.textPrimary),
              if (hasLabel) ...[
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (tooltip != null && tooltip.isNotEmpty) {
      return Tooltip(message: tooltip, child: button);
    }
    return button;
  }

  static void _showAnalysisBottomSheet(
    BuildContext context,
    VideoController controller, {
    int initialTabIndex = 0,
  }) {
    VideoAnalysisScreen.open(
      context,
      video: controller.video,
      controller: controller,
      initialTabIndex: initialTabIndex,
    );
  }

  static Widget _buildModernMoreButton({
    required BuildContext context,
    required VideoController controller,
    required MainController mainController,
    required VoidCallback onSignInPrompt,
  }) {
    return Material(
      color: AppColors.bgSurface,
      shape: const CircleBorder(),
      child: PopupMenuButton<String>(
        icon: const Icon(
          Icons.more_horiz_rounded,
          size: 20,
          color: AppColors.textPrimary,
        ),
        color: AppColors.bgSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onSelected: (value) {
          switch (value) {
            case 'clip':
              VideoClipDialog.show(
                context: context,
                controller: controller,
                onSignInPrompt: onSignInPrompt,
              );
            case 'report':
              VideoReportBottomSheet.show(
                context: context,
                controller: controller,
                mainController: mainController,
                onSignInPrompt: onSignInPrompt,
              );
          }
        },
        itemBuilder: (context) => [
          if (controller.video.allowClipping)
            PopupMenuItem(
              value: 'clip',
              child: Row(
                children: [
                  const Icon(
                    Icons.content_cut_rounded,
                    size: 20,
                    color: AppColors.textPrimary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Clip',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          PopupMenuItem(
            value: 'report',
            child: Row(
              children: [
                const Icon(
                  Icons.flag_rounded,
                  size: 20,
                  color: AppColors.textPrimary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Report',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildDownloadingCapsule({
    required BuildContext context,
    required VideoController controller,
    required DownloadsController downloadsCtrl,
    required int progress,
  }) {
    return Tooltip(
      message: 'Downloading ($progress%) • Tap to cancel',
      child: Material(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: () => _showCancelDownloadDialog(
            context: context,
            controller: controller,
            downloadsCtrl: downloadsCtrl,
          ),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.brand,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Saving $progress%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brand,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static void _showCancelDownloadDialog({
    required BuildContext context,
    required VideoController controller,
    required DownloadsController downloadsCtrl,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        title: Text(
          'Cancel Download?',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Do you want to stop and cancel downloading "${controller.video.title}"?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Keep', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              downloadsCtrl.cancelDownload(controller.video.id);
              controller.isDownloading.value = false;
            },
            child: const Text(
              'Cancel Download',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }
}
