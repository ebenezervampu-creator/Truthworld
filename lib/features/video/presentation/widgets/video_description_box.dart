import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/core/ux/user_feedback_sanitizer.dart';
import 'package:truthworld/core/widgets/clickable_url_text.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/channel/data/services/channel_memory_cache.dart';
import 'package:truthworld/features/home/presentation/controllers/main_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/services/video_media_service.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:truthworld/features/video/presentation/views/video_description_screen.dart';
import 'package:truthworld/features/video/presentation/views/widgets/transcript_segment_tile.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Interactive expandable description container for video metadata, view counts,
/// timestamps, hashtags, AI bullet summaries, and searchable transcript segments.
class VideoDescriptionBox extends StatelessWidget {
  const VideoDescriptionBox({
    required this.controller,
    required this.mainController,
    this.isDesktop,
    super.key,
  });

  final VideoController controller;
  final MainController mainController;
  final bool? isDesktop;

  /// Returns true if the current environment or viewport is mobile-sized (Web mobile, Android, iOS).
  static bool isMobileSized(BuildContext context, {bool? isDesktop}) {
    if (isDesktop == true) return false;
    final width = MediaQuery.sizeOf(context).width;
    if (width < 900) return true;
    final isMobileDevice = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    return isMobileDevice;
  }

  static String formatViews(int views) {
    if (views >= 1000000000) return '${(views / 1000000000).toStringAsFixed(1)}B';
    if (views >= 1000000) return '${(views / 1000000).toStringAsFixed(1)}M';
    if (views >= 1000) return '${(views / 1000).toStringAsFixed(1)}K';
    return views.toString();
  }

  static String _formatViews(int views) => formatViews(views);

  @override
  Widget build(BuildContext context) {
    return _buildDescriptionBox(context);
  }
  Widget _buildDescriptionBox(BuildContext context) {
    return Obx(() {
      final isMobile = isMobileSized(context, isDesktop: isDesktop);
      final expanded = !isMobile && controller.isExpanded.value;
      final showTranscript = !isMobile && controller.isTranscriptVisible.value;
      final showSummary = !isMobile && controller.isSummaryVisible.value;
      final video = controller.rxVideo.value;
      final videoId = video.id;
      final channelId = video.channelId.isNotEmpty
          ? video.channelId
          : video.ownerId;
      final channel = ChannelMemoryCache.getReactive(channelId);

      final effectiveShowLike = video.showLikeCount &&
          (channel == null || channel.showLikeCount);
      final effectiveShowDislike = video.showDislikeCount &&
          (channel == null || channel.showDislikeCount);

      final likesCount = mainController.videoLikes[videoId] ?? video.likeCount;
      final dislikesCount = mainController.videoDislikes[videoId] ?? video.dislikeCount;
      final viewsCount = mainController.videoViews[videoId] ?? video.views;
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
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (isMobile) {
                    VideoDescriptionScreen.open(
                      context,
                      video: video,
                      controller: controller,
                      mainController: mainController,
                    );
                  } else {
                    controller.isExpanded.value = !expanded;
                  }
                },
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (effectiveShowLike)
                        Text(
                          '${FormatUtils.formatCount(likesCount)} ${likesCount == 1 ? 'like' : 'likes'}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      if (effectiveShowDislike)
                        Text(
                          '${FormatUtils.formatCount(dislikesCount)} ${dislikesCount == 1 ? 'dislike' : 'dislikes'}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      Text(
                        '${formatViews(viewsCount)} ${viewsCount == 1 ? 'view' : 'views'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        timeago.format(video.uploadedAt.toDate()),
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
                    text: video.description,
                    maxLines: expanded ? null : 2,
                    overflow: expanded
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  if (!expanded && (video.description.length > 60 || isMobile))
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '...more',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (isMobile) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 10,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ],
                        ],
                      ),
                    ),
                  if (expanded && video.description.length > 60)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Show less',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (expanded) buildChannelLinksSection(channel, video),
                ],
              ),
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
                    if (isMobile) {
                      VideoDescriptionScreen.open(
                        context,
                        video: video,
                        controller: controller,
                        mainController: mainController,
                        initialSection: VideoDescriptionSection.summary,
                      );
                      return;
                    }
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
                      color: (!isMobile && controller.isSummaryVisible.value)
                          ? AppColors.brand.withValues(alpha: 0.25)
                          : Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: (!isMobile && controller.isSummaryVisible.value)
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
                          (!isMobile && controller.isSummaryVisible.value)
                              ? 'Hide Summary'
                              : 'AI Summary',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          (!isMobile && controller.isSummaryVisible.value)
                              ? Icons.keyboard_arrow_up_rounded
                              : (isMobile
                                  ? Icons.arrow_forward_ios_rounded
                                  : Icons.keyboard_arrow_down_rounded),
                          size: isMobile ? 12 : 18,
                          color: Colors.white70,
                        ),
                      ],
                    ),
                  ),
                ),

                // Show Transcript button
                InkWell(
                  onTap: () {
                    if (isMobile) {
                      VideoDescriptionScreen.open(
                        context,
                        video: video,
                        controller: controller,
                        mainController: mainController,
                        initialSection: VideoDescriptionSection.transcript,
                      );
                      return;
                    }
                    final nextVisible = !controller.isTranscriptVisible.value;
                    controller.isTranscriptVisible.value = nextVisible;
                    if (nextVisible) {
                      final playerCtrl = TowerPlayerController.getForTagOrActive(controller.video.id);
                      playerCtrl?.startSubtitleSyncTimer();
                      final currentPos = playerCtrl?.videoPlayerController.value.position ??
                          controller.currentPosition;
                      controller.transcriptController.resumeAutoScroll();
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
                      color: (!isMobile && controller.isTranscriptVisible.value)
                          ? AppColors.brand.withValues(alpha: 0.25)
                          : Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: (!isMobile && controller.isTranscriptVisible.value)
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
                          (!isMobile && controller.isTranscriptVisible.value)
                              ? 'Hide Transcript'
                              : 'Show Transcript',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          (!isMobile && controller.isTranscriptVisible.value)
                              ? Icons.keyboard_arrow_up_rounded
                              : (isMobile
                                  ? Icons.arrow_forward_ios_rounded
                                  : Icons.keyboard_arrow_down_rounded),
                          size: isMobile ? 12 : 18,
                          color: Colors.white70,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (showSummary) ...[
              const SizedBox(height: 12),
              buildSummaryContent(context, controller: controller),
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
                child: buildTranscriptContent(context, controller: controller),
              ),
            ],
          ],
        ),
      );
    });
  }

  Widget _buildSummaryContent(BuildContext context) =>
      buildSummaryContent(context, controller: controller);

  static Widget buildSummaryContent(
    BuildContext context, {
    required VideoController controller,
  }) {
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
                style: TextStyle(
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
      final segs = controller.transcriptController.transcriptSegments;
      if (UserFeedbackSanitizer.isValidVideoSummary(
        controller.moderationSummary.value,
        transcriptSegments: segs,
      )) {
        summary = controller.moderationSummary.value;
      } else if (UserFeedbackSanitizer.isValidVideoSummary(
        controller.video.moderationSummary,
        transcriptSegments: segs,
      )) {
        summary = controller.video.moderationSummary;
      } else if (UserFeedbackSanitizer.isValidVideoSummary(
        VideoMediaService.credibilityCache[controller.video.id]?.summary,
        transcriptSegments: segs,
      )) {
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
                  style: TextStyle(
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
                  style: TextStyle(
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
              style: TextStyle(
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

  Widget _buildTranscriptContent(BuildContext context) =>
      buildTranscriptContent(context, controller: controller);

  static Widget buildTranscriptContent(
    BuildContext context, {
    required VideoController controller,
  }) {
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
                  style: TextStyle(
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
                  style: TextStyle(
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
                    style: TextStyle(
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
            controller.transcriptController.autoScrollEnabled.value &&
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
                style: TextStyle(
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
                    controller.transcriptController.resumeAutoScroll();
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
                          style: TextStyle(
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
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is UserScrollNotification &&
                    notification.direction != ScrollDirection.idle) {
                  controller.transcriptController.onUserScrolled();
                } else if (notification is ScrollEndNotification) {
                  controller.transcriptController.onUserScrollEnded();
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
                    key: controller.transcriptController.getSegmentKey(index),
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

  Widget _buildChannelLinksSection(Channel? channel, Video video) =>
      buildChannelLinksSection(channel, video);

  static Widget buildChannelLinksSection(Channel? channel, Video video) {
    final links = <Map<String, dynamic>>[];

    if (channel != null) {
      if (channel.websiteUrl.isNotEmpty) {
        final uri = Uri.tryParse(channel.websiteUrl);
        final domain = uri?.host.replaceAll('www.', '') ?? channel.websiteUrl;
        links.add({
          'title': 'Website',
          'display': domain,
          'url': channel.websiteUrl,
          'icon': Icons.language_rounded,
        });
      }

      for (final item in channel.customLinks) {
        final title = (item['title'] ?? '').toString().trim();
        final url = (item['url'] ?? '').toString().trim();
        if (url.isNotEmpty) {
          final uri = Uri.tryParse(url);
          final domain = uri?.host.replaceAll('www.', '') ?? url;
          links.add({
            'title': title.isNotEmpty ? title : 'Link',
            'display': domain,
            'url': url,
            'icon': Icons.link_rounded,
          });
        }
      }

      if (channel.socialLinks != null) {
        final platformIcons = <String, IconData>{
          'twitter': Icons.alternate_email,
          'x': Icons.alternate_email,
          'instagram': Icons.camera_alt_outlined,
          'facebook': Icons.facebook,
          'linkedin': Icons.business,
          'tiktok': Icons.music_note,
          'youtube': Icons.play_circle_outline,
          'whatsapp': Icons.chat_outlined,
          'telegram': Icons.send_outlined,
          'discord': Icons.forum_outlined,
          'github': Icons.code,
          'twitch': Icons.live_tv,
          'reddit': Icons.chat_bubble_outline,
          'patreon': Icons.monetization_on_outlined,
          'threads': Icons.alternate_email_outlined,
        };

        for (final entry in channel.socialLinks!.entries) {
          if (entry.key == 'website' || entry.key == 'customLinks') continue;
          if (entry.value is String && (entry.value as String).trim().isNotEmpty) {
            final url = (entry.value as String).trim();
            final uri = Uri.tryParse(url);
            final domain = uri?.host.replaceAll('www.', '') ?? url;
            final key = entry.key.toLowerCase();
            links.add({
              'title': key.isNotEmpty ? (key[0].toUpperCase() + key.substring(1)) : 'Social',
              'display': domain,
              'url': url,
              'icon': platformIcons[key] ?? Icons.share_rounded,
            });
          }
        }
      }
    }

    final sources = video.sourceLinks ?? const [];

    if (links.isEmpty && sources.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const Divider(color: Colors.white12, height: 1),
        const SizedBox(height: 10),
        if (links.isNotEmpty) ...[
          Text(
            'LINKS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white70,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: links.map((link) {
              return InkWell(
                onTap: () => ClickableUrlText.launchUrlString(link['url'] as String),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(link['icon'] as IconData, size: 14, color: AppColors.brand),
                      const SizedBox(width: 5),
                      Text(
                        link['title'] as String,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '(${link['display']})',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
        if (sources.isNotEmpty) ...[
          if (links.isNotEmpty) const SizedBox(height: 10),
          Text(
            'SOURCE REFERENCES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white70,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: sources.map((src) {
              final uri = Uri.tryParse(src);
              final host = uri?.host.replaceAll('www.', '') ?? src;
              return InkWell(
                onTap: () => ClickableUrlText.launchUrlString(src),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.brand.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.brand.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_outlined, size: 13, color: AppColors.brand),
                      const SizedBox(width: 5),
                      Text(
                        host,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

