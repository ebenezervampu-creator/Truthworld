import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_transcript_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:video_player/video_player.dart';

/// 🎬 ClaimMediaStage
///
/// Desktop Command Center stage pairing the video playback anchor with
/// synchronized live transcript dialogue for the active empirical claim:
/// - Video player preview with interactive seek to claim timestamp
/// - Spoken dialogue timeline highlighting the exact moment of the claim
/// - One-tap timestamp seeking and speech inspection
class ClaimMediaStage extends StatelessWidget {
  final Video video;
  final VideoController? controller;
  final double? startSec;
  final String timestampText;
  final String claimText;
  final VoidCallback onSeekToClaim;

  const ClaimMediaStage({
    required this.video,
    required this.startSec,
    required this.timestampText,
    required this.claimText,
    required this.onSeekToClaim,
    this.controller,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgDivider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Upper Stage: Video Player and Live Transcript side-by-side or stacked
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 680;
              if (isWide) {
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Video Player (Left 60%)
                      Expanded(
                        flex: 6,
                        child: _buildVideoPlayerSection(context),
                      ),
                      Container(
                        width: 1,
                        color: AppColors.bgDivider,
                      ),
                      // Live Transcript (Right 40%)
                      Expanded(
                        flex: 4,
                        child: _buildTranscriptSection(context),
                      ),
                    ],
                  ),
                );
              }

              // Stacked for tighter containers
              return Column(
                children: [
                  _buildVideoPlayerSection(context),
                  const Divider(height: 1, color: AppColors.bgDivider),
                  _buildTranscriptSection(context, maxHeight: 180),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayerSection(BuildContext context) {
    final vpc = controller?.videoPlayerController;
    final isInitialized = vpc != null && vpc.value.isInitialized;

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Player or Thumbnail
          if (isInitialized)
            ColoredBox(
              color: Colors.black,
              child: Center(
                child: AspectRatio(
                  aspectRatio: vpc.value.aspectRatio > 0 ? vpc.value.aspectRatio : 16 / 9,
                  child: VideoPlayer(vpc),
                ),
              ),
            )
          else if (video.thumbnailUrl.isNotEmpty)
            CachedNetworkImage(
              imageUrl: video.thumbnailUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => const ColoredBox(color: Colors.black),
              errorWidget: (_, __, ___) => const ColoredBox(color: Colors.black),
            )
          else
            const ColoredBox(color: Colors.black),

          // 2. Gradient Overlay for readability
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.25),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.75),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),

          // 3. Top Status Row
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: isInitialized ? AppColors.success : Colors.white70,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isInitialized ? 'LIVE SYNC' : 'VIDEO ANCHOR',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (video.duration.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      video.duration,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 4. Center Play / Seek Action
          Center(
            child: isInitialized
                ? InkWell(
                    onTap: () {
                      if (vpc.value.isPlaying) {
                        vpc.pause();
                      } else {
                        vpc.play();
                      }
                    },
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        vpc.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
                  )
                : InkWell(
                    onTap: onSeekToClaim,
                    borderRadius: BorderRadius.circular(32),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.play_circle_fill_rounded,
                            size: 22,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Jump to $timestampText',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),

          // 5. Bottom Seek to Claim Pill
          Positioned(
            bottom: 12,
            left: 12,
            right: 12,
            child: Row(
              children: [
                InkWell(
                  onTap: onSeekToClaim,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 0.6,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.fast_forward_rounded,
                          size: 15,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Seek $timestampText',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                if (isInitialized)
                  Text(
                    FormatUtils.formatDuration(controller?.currentPosition ?? (vpc.value.position)),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptSection(BuildContext context, {double? maxHeight}) {
    final transcriptCtrl = controller?.transcriptController;
    final segments = transcriptCtrl?.transcriptSegments ?? <SubtitleSegment>[];

    // Proactively fetch transcript if empty
    if (segments.isEmpty && transcriptCtrl != null && !transcriptCtrl.hasAttemptedTranscriptFetch.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        transcriptCtrl.loadTranscriptForVideo(video);
      });
    }

    return Container(
      color: Colors.black.withValues(alpha: 0.3),
      padding: const EdgeInsets.all(14),
      constraints: maxHeight != null ? BoxConstraints(maxHeight: maxHeight) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(
                Icons.subtitles_rounded,
                size: 16,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              const Text(
                'LIVE TRANSCRIPT',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  timestampText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(
            height: 1,
            color: Colors.white.withValues(alpha: 0.08),
          ),
          const SizedBox(height: 10),

          // Transcript Content
          Expanded(
            child: transcriptCtrl == null
                ? _buildSpokenStatementFallback()
                : Obx(() {
                    final isLoading = transcriptCtrl.isLoadingTranscript.value;
                    final segs = transcriptCtrl.transcriptSegments;

                    if (isLoading && segs.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white70,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Aligning speech transcript…',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    if (segs.isEmpty) {
                      return _buildSpokenStatementFallback();
                    }

                    // Segment List
                    final targetSec = startSec ?? 0.0;
                    return ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: segs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, idx) {
                        final seg = segs[idx];
                        final segStartSec = seg.start.inMilliseconds / 1000.0;
                        final segEndSec = seg.end.inMilliseconds / 1000.0;
                        final isMatchingClaim = (targetSec >= segStartSec - 1.5 && targetSec <= segEndSec + 1.5);
                        final segTime = FormatUtils.formatDuration(seg.start);

                        return InkWell(
                          onTap: () {
                            final target = seg.start;
                            controller?.videoPlayerController?.seekTo(target);
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: isMatchingClaim
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: isMatchingClaim
                                  ? Border.all(
                                      color: const Color(0xFF2DD4BF).withValues(alpha: 0.5),
                                      width: 0.8,
                                    )
                                  : null,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  segTime,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: isMatchingClaim ? const Color(0xFF2DD4BF) : AppColors.textTertiary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    seg.text,
                                    style: TextStyle(
                                      fontSize: 12,
                                      height: 1.35,
                                      fontWeight: isMatchingClaim ? FontWeight.w600 : FontWeight.w400,
                                      color: isMatchingClaim ? Colors.white : AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  }),
          ),
        ],
      ),
    );
  }

  Widget _buildSpokenStatementFallback() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.record_voice_over_rounded,
                  size: 15,
                  color: Color(0xFF2DD4BF),
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'SPOKEN STATEMENT',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.6,
                      color: Color(0xFF2DD4BF),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  timestampText,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '"$claimText"',
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                fontStyle: FontStyle.italic,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
