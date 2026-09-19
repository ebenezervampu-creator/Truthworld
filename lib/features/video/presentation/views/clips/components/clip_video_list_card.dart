import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/features/video/data/models/video_clip.dart';
import 'package:truthworld/features/video/presentation/controllers/user_clips_controller.dart';
import 'package:truthworld/features/video/presentation/views/clips/components/clip_options_modal.dart';
import 'package:truthworld/theme/app_theme.dart';

class ClipVideoListCard extends StatelessWidget {
  const ClipVideoListCard({
    required this.clip,
    required this.controller,
    super.key,
  });

  final VideoClip clip;
  final UserClipsController controller;

  @override
  Widget build(BuildContext context) {
    final durationSeconds = (clip.endTime - clip.startTime).toInt();
    final durationText = FormatUtils.formatDuration(
      Duration(seconds: durationSeconds),
    );

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 360;
    final thumbWidth = isCompact ? 120.0 : 160.0;
    final thumbHeight = isCompact ? 68.0 : 90.0;

    return InkWell(
      onTap: () => controller.playClip(clip),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: clip.thumbnailUrl,
                    width: thumbWidth,
                    height: thumbHeight,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        Container(color: AppTheme.secondaryBackground),
                    errorWidget: (context, url, error) =>
                        Container(color: AppTheme.secondaryBackground),
                  ),
                ),
                // Clip Duration badge
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.bgPage.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.content_cut,
                          color: AppColors.textPrimary,
                          size: 10,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          durationText,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          clip.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.more_vert,
                          color: AppColors.textPrimary,
                          size: 20,
                        ),
                        onPressed: () => ClipOptionsModal.show(
                          context,
                          clip,
                          controller,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    clip.channelName.isNotEmpty
                        ? '${clip.channelName} • ${clip.videoTitle}'
                        : clip.videoTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Clip ($durationText) • Created ${controller.formatTimeAgo(clip.createdAt)}',
                    style: const TextStyle(
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
    );
  }
}
