import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

class EndScreenOverlay extends StatelessWidget {
  const EndScreenOverlay({required this.ctrl, super.key});
  final TowerPlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!ctrl.showEndScreen.value) return const SizedBox.shrink();

      final isCountdownActive = ctrl.autoplayCountdown.value > 0;

      // Extract recommended/next video
      Video? nextVideo;
      var recommendations = <Video>[];
      try {
        if (Get.isRegistered<VideoController>(tag: ctrl.tag)) {
          final vc = Get.find<VideoController>(tag: ctrl.tag);
          recommendations = vc.recommendedVideos;
          final idx = recommendations.indexWhere((v) => v.id == vc.video.id);
          if (idx >= 0 && idx < recommendations.length - 1) {
            nextVideo = recommendations[idx + 1];
          } else if (recommendations.isNotEmpty) {
            nextVideo = recommendations.first;
          }
        }
      } catch (_) {}

      // If autoplay countdown is running and next video is available
      final showAutoplayBanner = isCountdownActive && nextVideo != null;
      final isHidden = ctrl.isEndScreenOverlayHidden.value;

      return Stack(
        fit: StackFit.expand,
        children: [
          // 1. Dimming background & cards layout (Only if NOT hidden)
          if (!isHidden)
            Positioned.fill(
              child: ColoredBox(
                color: AppColors.bgPage.withValues(alpha: 0.25),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final height = constraints.maxHeight;
                    final isCompact = width < 600 || height < 320;

                    if (isCompact) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 60, bottom: 60),
                        child: _buildCompactLayout(context, recommendations),
                      );
                    }

                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        // Left Column: Square card (top) + circular logo (bottom)
                        Positioned(
                          left: 40,
                          top: 40,
                          bottom: 40,
                          width: 180,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Left top card
                              if (recommendations.length >= 3)
                                _buildSquareCard(context, recommendations[2])
                              else if (recommendations.isNotEmpty)
                                _buildSquareCard(context, recommendations.first)
                              else
                                const SizedBox.shrink(),

                              // Left bottom circular logo
                              _buildChannelLogo(context),
                            ],
                          ),
                        ),

                        // Right Column: Two vertical 16:9 cards
                        Positioned(
                          right: 40,
                          top: 40,
                          bottom: 40,
                          width: 320,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (recommendations.isNotEmpty)
                                _buildRightCard(context, recommendations[0]),
                              if (recommendations.length >= 2) ...[
                                const SizedBox(height: 16),
                                _buildRightCard(context, recommendations[1]),
                              ],
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),

          // 2. Hide/Show Toggle Button (Always visible at top-right, clickable)
          Positioned(
            top: 16,
            right: 16,
            child: _buildHideShowButton(),
          ),

          // 3. Autoplay Countdown Banner
          if (showAutoplayBanner)
            _buildAutoplayCountdownBanner(context, nextVideo),
        ],
      );
    });
  }

  Widget _buildHideShowButton() {
    return GestureDetector(
      onTap: ctrl.isEndScreenOverlayHidden.toggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.textPrimary,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              ctrl.isEndScreenOverlayHidden.value
                  ? Icons.visibility
                  : Icons.visibility_off,
              color: AppColors.bgPage,
              size: 15,
            ),
            const SizedBox(width: 6),
            Text(
              ctrl.isEndScreenOverlayHidden.value ? 'Show' : 'Hide',
              style: const TextStyle(
                color: AppColors.bgPage,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSquareCard(BuildContext context, Video video) {
    return AspectRatio(
      aspectRatio: 1.15,
      child: InkWell(
        onTap: () {
          ctrl.showEndScreen.value = false;
          ctrl.isEndScreenOverlayHidden.value = false;
          ctrl.navigateToVideo(video);
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.textPrimary.withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.bgPage.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6.5),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: video.thumbnailUrl.replaceAll(' ', '%20'),
                  fit: BoxFit.cover,
                  placeholder: (_, _) => Container(color: AppColors.bgPage54),
                  errorWidget: (_, _, _) => const ColoredBox(
                    color: AppColors.bgPage54,
                    child: Icon(
                      Icons.link,
                      color: AppColors.textTertiary,
                      size: 30,
                    ),
                  ),
                ),
                // Open in new badge at bottom right
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.bgPage.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(
                      Icons.open_in_new,
                      color: AppColors.textPrimary,
                      size: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChannelLogo(BuildContext context) {
    final vc = ctrl.videoController;
    final avatarUrl =
        vc?.video.channelAvatarUrl ?? vc?.video.channelImage ?? '';
    final channelName = vc?.video.channelName ?? '';

    return GestureDetector(
      onTap: () {
        if (vc != null && vc.video.channelId.isNotEmpty) {
          ctrl.showEndScreen.value = false;
          ctrl.isEndScreenOverlayHidden.value = false;
          Get.toNamed('/channel/${vc.video.channelId}');
        }
      },
      child: Container(
        width: 130,
        height: 130,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.bgPage.withValues(alpha: 0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipOval(
          child: avatarUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: avatarUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => ColoredBox(
                    color: AppColors.textPrimary.withValues(alpha: 0.1),
                    child: Center(
                      child: Text(
                        channelName.isNotEmpty
                            ? channelName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  errorWidget: (_, _, _) => ColoredBox(
                    color: AppColors.textPrimary.withValues(alpha: 0.1),
                    child: Center(
                      child: Text(
                        channelName.isNotEmpty
                            ? channelName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                )
              : ColoredBox(
                  color: AppColors.textPrimary.withValues(alpha: 0.1),
                  child: Center(
                    child: Text(
                      channelName.isNotEmpty
                          ? channelName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildRightCard(BuildContext context, Video video) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: InkWell(
        onTap: () {
          ctrl.showEndScreen.value = false;
          ctrl.isEndScreenOverlayHidden.value = false;
          ctrl.navigateToVideo(video);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.textPrimary.withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.bgPage.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10.5),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: video.thumbnailUrl.replaceAll(' ', '%20'),
                  fit: BoxFit.cover,
                  placeholder: (_, _) => Container(color: AppColors.bgPage54),
                  errorWidget: (_, _, _) => const ColoredBox(
                    color: AppColors.bgPage54,
                    child: Icon(
                      Icons.video_library_outlined,
                      color: AppColors.textTertiary,
                      size: 40,
                    ),
                  ),
                ),
                // Scrim
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.bgPage.withValues(alpha: 0.65),
                        Colors.transparent,
                        Colors.transparent,
                        AppColors.bgPage.withValues(alpha: 0.65),
                      ],
                      stops: const [0.0, 0.35, 0.65, 1.0],
                    ),
                  ),
                ),
                // Title (top left)
                Positioned(
                  top: 10,
                  left: 10,
                  right: 10,
                  child: Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                      shadows: [
                        Shadow(
                          color: AppColors.bgPage.withValues(alpha: 0.8),
                          offset: const Offset(1, 1),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
                // Channel Name (bottom left)
                Positioned(
                  bottom: 10,
                  left: 10,
                  right: 60,
                  child: Text(
                    video.channelName.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textPrimary.withValues(alpha: 0.9),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                      shadows: [
                        Shadow(
                          color: AppColors.bgPage.withValues(alpha: 0.8),
                          offset: const Offset(1, 1),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
                // Duration Badge (bottom right)
                Positioned(
                  bottom: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.bgPage.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _formatDuration(video.durationValue),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactLayout(BuildContext context, List<Video> videos) {
    final list = videos
        .where((v) => v.id != ctrl.videoController?.video.id)
        .take(3)
        .toList();
    if (list.isEmpty) {
      return Center(
        child: FloatingActionButton(
          onPressed: ctrl.replayVideo,
          backgroundColor: AppColors.brand,
          child: const Icon(Icons.replay_rounded, color: AppColors.textPrimary),
        ),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(
                Icons.replay_rounded,
                color: AppColors.textPrimary,
                size: 24,
              ),
              onPressed: ctrl.replayVideo,
            ),
            const Text(
              'Replay',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final video = list[index];
              return InkWell(
                onTap: () {
                  ctrl.showEndScreen.value = false;
                  ctrl.isEndScreenOverlayHidden.value = false;
                  ctrl.navigateToVideo(video);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.bgDivider),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: CachedNetworkImage(
                            imageUrl: video.thumbnailUrl.replaceAll(' ', '%20'),
                            fit: BoxFit.cover,
                            placeholder: (_, _) =>
                                Container(color: Colors.black26),
                            errorWidget: (_, _, _) => const Icon(
                              Icons.video_library_outlined,
                              color: AppColors.textDisabled,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              video.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              video.channelName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAutoplayCountdownBanner(BuildContext context, Video nextVideo) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.bgPage.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppColors.bgDivider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Up Next: ',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200),
              child: Text(
                nextVideo.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'in ${ctrl.autoplayCountdown.value}s',
              style: const TextStyle(
                color: AppColors.brand,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: ctrl.cancelAutoplayCountdown,
              child: const Text(
                'CANCEL',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: ctrl.playNextImmediately,
              child: const Text(
                'PLAY NOW',
                style: TextStyle(
                  color: AppColors.brand,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
