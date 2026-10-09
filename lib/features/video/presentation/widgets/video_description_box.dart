import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/core/ux/user_feedback_sanitizer.dart';
import 'package:truthworld/core/widgets/clickable_url_text.dart';
import 'package:truthworld/features/home/presentation/controllers/main_controller.dart';
import 'package:truthworld/features/video/data/services/video_media_service.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:truthworld/features/video/presentation/views/widgets/transcript_segment_tile.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Interactive expandable description container for video metadata, view counts,
/// timestamps, hashtags, AI bullet summaries, and searchable transcript segments.
class VideoDescriptionBox extends StatelessWidget {
  const VideoDescriptionBox({
    required this.controller,
    required this.mainController,
    super.key,
  });

  final VideoController controller;
  final MainController mainController;

  static String _formatViews(int views) {
    if (views >= 1000000) return '${(views / 1000000).toStringAsFixed(1)}M';
    if (views >= 1000) return '${(views / 1000).toStringAsFixed(1)}K';
    return views.toString();
  }

  @override
  Widget build(BuildContext context) {
    return _buildDescriptionBox(context);
  }
  Widget _buildDescriptionBox(BuildContext context) {
    return Obx(() {
      final expanded = controller.isExpanded.value;
      final showTranscript = controller.isTranscriptVisible.value;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => controller.isExpanded.value = !expanded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        '${FormatUtils.formatCount(mainController.videoLikes[controller.video.id] ?? controller.video.likeCount)} likes',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${FormatUtils.formatCount(mainController.videoDislikes[controller.video.id] ?? controller.video.dislikeCount)} dislikes',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_formatViews(controller.video.views)} views',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        timeago.format(controller.video.uploadedAt.toDate()),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClickableUrlText(
                    text: controller.video.description,
                    maxLines: expanded ? null : 2,
                    overflow: expanded
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                    style: GoogleFonts.roboto(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  if (!expanded && controller.video.description.length > 60)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '...more',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Action Buttons: AI Summary & Show Transcript
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // AI Summary button
                InkWell(
                  onTap: () {
                    final nextVisible = !controller.isSummaryVisible.value;
                    controller.isSummaryVisible.value = nextVisible;
                    if (nextVisible) {
                      controller.fetchSummary();
                    }
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: controller.isSummaryVisible.value
                          ? AppColors.brand.withValues(alpha: 0.25)
                          : Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: controller.isSummaryVisible.value
                            ? AppColors.brand.withValues(alpha: 0.5)
                            : Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          controller.isSummaryVisible.value
                              ? 'Hide Summary'
                              : 'AI Summary',
                          style: GoogleFonts.roboto(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          controller.isSummaryVisible.value
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: Colors.white70,
                        ),
                      ],
                    ),
                  ),
                ),

                // Show Transcript button
                InkWell(
                  onTap: () {
                    final nextVisible = !showTranscript;
                    controller.isTranscriptVisible.value = nextVisible;
                    if (nextVisible) {
                      final playerCtrl = TowerPlayerController.getForTagOrActive(controller.video.id);
                      playerCtrl?.startSubtitleSyncTimer();
                      final currentPos = playerCtrl?.videoPlayerController.value.position ??
                          controller.currentPosition;
                      controller.transcriptController.autoScrollEnabled.value = true;
                      controller.transcriptController.syncToCurrentPosition(
                        currentPos,
                        forceScroll: true,
                      );
                      controller.loadTranscriptForVideo();
                    }
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: showTranscript
                          ? AppColors.brand.withValues(alpha: 0.25)
                          : Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: showTranscript
                            ? AppColors.brand.withValues(alpha: 0.5)
                            : Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.description_outlined,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          showTranscript ? 'Hide Transcript' : 'Show Transcript',
                          style: GoogleFonts.roboto(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          showTranscript
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: Colors.white70,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (controller.isSummaryVisible.value) ...[
              const SizedBox(height: 12),
              _buildSummaryContent(context),
            ],
            if (showTranscript) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: _buildTranscriptContent(context),
              ),
            ],
          ],
        ),
      );
    });
  }

  Widget _buildSummaryContent(BuildContext context) {
    return Obx(() {
      if (controller.isLoadingSummary.value) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Fetching AI video summary...',
                style: GoogleFonts.roboto(
                  color: Colors.white70,
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        );
      }

      var summary = '';
      if (UserFeedbackSanitizer.isValidVideoSummary(controller.moderationSummary.value)) {
        summary = controller.moderationSummary.value;
      } else if (UserFeedbackSanitizer.isValidVideoSummary(controller.video.moderationSummary)) {
        summary = controller.video.moderationSummary;
      } else if (UserFeedbackSanitizer.isValidVideoSummary(VideoMediaService.credibilityCache[controller.video.id]?.summary)) {
        summary = VideoMediaService.credibilityCache[controller.video.id]!.summary;
      }

      if (summary.isEmpty) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: Colors.white70,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'No AI summary generated for this video yet.',
                  style: GoogleFonts.roboto(
                    color: Colors.white70,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        );
      }

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.brand.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.brand.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.auto_awesome,
                  size: 16,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  'AI SUMMARY',
                  style: GoogleFonts.roboto(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brand,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              summary,
              style: GoogleFonts.roboto(
                color: Colors.white,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildTranscriptContent(BuildContext context) {
    final playerCtrl = TowerPlayerController.getForTagOrActive(controller.video.id);

    if (controller.transcriptSegments.isEmpty &&
        (playerCtrl == null || playerCtrl.subtitleSegments.isEmpty) &&
        !controller.transcriptController.hasAttemptedTranscriptFetch.value &&
        !controller.isLoadingTranscript.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (controller.transcriptSegments.isEmpty &&
            !controller.transcriptController.hasAttemptedTranscriptFetch.value &&
            !controller.isLoadingTranscript.value) {
          controller.loadTranscriptForVideo();
        }
      });
    }

    return Obx(() {
      final segments = controller.transcriptSegments.isNotEmpty
          ? controller.transcriptSegments
          : (playerCtrl?.subtitleSegments ?? <SubtitleSegment>[]);
      final isLoading = controller.isLoadingTranscript.value ||
          (playerCtrl?.isLoadingSubtitles.value ?? false);

      if (segments.isEmpty) {
        if (isLoading) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Loading transcript...',
                  style: GoogleFonts.roboto(
                    color: Colors.white70,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: Colors.white70,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'No timestamped transcript available for this video.',
                  style: GoogleFonts.roboto(
                    color: Colors.white70,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              InkWell(
                onTap: () => controller.loadTranscriptForVideo(forceRefresh: true),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    'Retry',
                    style: GoogleFonts.roboto(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }

      // Ensure list jumps to active position after layout
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (controller.isTranscriptVisible.value &&
            controller.transcriptController.activeSegmentIndex.value != -1) {
          controller.transcriptController.scrollToSegmentIndex(
            controller.transcriptController.activeSegmentIndex.value,
          );
        }
      });

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TIMESTAMPED TRANSCRIPT',
                style: GoogleFonts.roboto(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white54,
                  letterSpacing: 1.0,
                ),
              ),
              Obx(() {
                final isAuto = controller.transcriptController.autoScrollEnabled.value;
                if (isAuto) return const SizedBox.shrink();
                return InkWell(
                  onTap: () {
                    controller.transcriptController.autoScrollEnabled.value = true;
                    final pos = playerCtrl?.videoPlayerController.value.position ??
                        controller.currentPosition;
                    controller.transcriptController.syncToCurrentPosition(pos, forceScroll: true);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.brand.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.brand.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.sync_rounded, size: 12, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          'Resume auto-scroll',
                          style: GoogleFonts.roboto(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 360,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: NotificationListener<UserScrollNotification>(
              onNotification: (notification) {
                if (notification.direction != ScrollDirection.idle) {
                  controller.transcriptController.autoScrollEnabled.value = false;
                }
                return false;
              },
              child: ListView.builder(
                controller: controller.transcriptController.transcriptScrollController,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                itemCount: segments.length,
                itemBuilder: (context, index) {
                  final seg = segments[index];
                  return TranscriptSegmentTile(
                    seg: seg,
                    playerCtrl: playerCtrl,
                    videoId: controller.video.id,
                    segmentIndex: index,
                    transcriptCtrl: controller.transcriptController,
                  );
                },
              ),
            ),
          ),
        ],
      );
    });
  }
}

