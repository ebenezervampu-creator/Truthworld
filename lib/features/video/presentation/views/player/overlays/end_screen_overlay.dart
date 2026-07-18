import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class EndScreenOverlay extends StatelessWidget {
  final TowerPlayerController ctrl;
  const EndScreenOverlay({super.key, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!ctrl.showEndScreen.value) return const SizedBox.shrink();

      final bool isCountdownActive = ctrl.autoplayCountdown.value > 0;
      
      // Extract recommended/next video
      Video? nextVideo;
      List<Video> recommendations = [];
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

      return Positioned.fill(
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              color: Colors.black.withValues(alpha: 0.75),
              padding: const EdgeInsets.all(24),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                child: isCountdownActive && nextVideo != null
                    ? _buildAutoplayCountdown(context, nextVideo)
                    : _buildRecommendationsGrid(context, recommendations),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildAutoplayCountdown(BuildContext context, Video next) {
    return Column(
      key: const ValueKey('autoplay_countdown'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Up Next',
          style: GoogleFonts.outfit(
            color: Colors.white70,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          next.title,
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          next.channelName,
          style: GoogleFonts.roboto(
            color: Colors.white54,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 32),
        
        // Circular progress countdown
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: Obx(() {
                final double progress = ctrl.autoplayCountdown.value / 5.0;
                return CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 4,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.brand),
                );
              }),
            ),
            Obx(() => Text(
              '${ctrl.autoplayCountdown.value}',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            )),
          ],
        ),
        
        const SizedBox(height: 36),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Cancel Button
            OutlinedButton(
              onPressed: ctrl.cancelAutoplayCountdown,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white38),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: Text(
                'CANCEL',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Play Now Button
            ElevatedButton(
              onPressed: ctrl.playNextImmediately,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                elevation: 4,
                shadowColor: AppColors.brand.withValues(alpha: 0.4),
              ),
              child: Text(
                'PLAY NOW',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecommendationsGrid(BuildContext context, List<Video> videos) {
    // Filter out current video
    final list = videos.where((v) => v.id != ctrl.videoController?.video.id).take(3).toList();

    return Column(
      key: const ValueKey('recommendations_grid'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.replay_rounded, color: Colors.white, size: 28),
              onPressed: ctrl.replayVideo,
              tooltip: 'Replay Video',
            ),
            const SizedBox(width: 8),
            Text(
              'Replay',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (list.isNotEmpty)
              Text(
                'More Videos',
                style: GoogleFonts.outfit(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: list.isEmpty
              ? Center(
                  child: FloatingActionButton.large(
                    onPressed: ctrl.replayVideo,
                    backgroundColor: AppColors.brand,
                    child: const Icon(Icons.replay_rounded, color: Colors.white, size: 40),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final bool isCompact = constraints.maxWidth < 600;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isCompact ? 1 : list.length,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: isCompact ? 3.0 : 1.2,
                      ),
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final video = list[index];
                        return _buildRecommendationCard(context, video, isCompact);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRecommendationCard(BuildContext context, Video video, bool isCompact) {
    if (isCompact) {
      // Horizontal compact card
      return InkWell(
        onTap: () {
          ctrl.showEndScreen.value = false;
          if (ctrl.videoController != null) {
            ctrl.videoController!.loadVideo(video);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
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
                    placeholder: (_, __) => Container(color: Colors.black26),
                    errorWidget: (_, __, ___) => const Icon(Icons.video_library_outlined, color: Colors.white24),
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
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      video.channelName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.roboto(
                        color: Colors.white54,
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
    }

    // Vertical card
    return InkWell(
      onTap: () {
        ctrl.showEndScreen.value = false;
        if (ctrl.videoController != null) {
          ctrl.videoController!.loadVideo(video);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: video.thumbnailUrl.replaceAll(' ', '%20'),
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: Colors.black26),
                      errorWidget: (_, __, ___) => const Icon(Icons.video_library_outlined, color: Colors.white24),
                    ),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black85,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _formatDuration(video.durationValue),
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            video.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            video.channelName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.roboto(
              color: Colors.white54,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
