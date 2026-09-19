import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/video_card/video_card_avatar.dart';
import 'package:truthworld/components/ui/video_card/video_card_controller.dart';
import 'package:truthworld/components/ui/video_card/video_card_formatters.dart';
import 'package:truthworld/components/ui/video_options_sheet.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Info block for grid layout cards (channel avatar, title, views, timestamp, options).
class VideoCardGridInfo extends StatelessWidget {
  const VideoCardGridInfo({
    required this.video,
    required this.controller,
    super.key,
  });

  final Video video;
  final VideoCardController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Obx(() {
      final avatarUrl = controller.realChannelAvatarUrl.value;
      final channelName = controller.realChannelName.value;

      return Padding(
        padding: const EdgeInsets.only(
          left: 10,
          right: 10,
          top: 10,
          bottom: 12,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            VideoCardAvatar(
              imageUrl: avatarUrl,
              radius: 16,
              placeholderText: channelName.isEmpty
                  ? '?'
                  : channelName.substring(0, 1).toUpperCase(),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      height: 1.25,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$channelName · ${VideoCardFormatters.formatViews(video.views)} views · ${VideoCardFormatters.formatTimestamp(video.uploadedAt)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.more_vert,
                size: 18,
                color: AppColors.textPrimary,
              ),
              onPressed: () => VideoOptionsSheet.show(context, video),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      );
    });
  }
}

/// Info block for horizontal list layout cards.
class VideoCardListInfo extends StatelessWidget {
  const VideoCardListInfo({
    required this.video,
    required this.controller,
    super.key,
  });

  final Video video;
  final VideoCardController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Obx(() {
      final avatarUrl = controller.realChannelAvatarUrl.value;
      final channelName = controller.realChannelName.value;

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      VideoCardAvatar(
                        imageUrl: avatarUrl,
                        radius: 10,
                        placeholderText: channelName.isEmpty
                            ? '?'
                            : channelName.substring(0, 1).toUpperCase(),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          channelName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${VideoCardFormatters.formatViews(video.views)} views · ${VideoCardFormatters.formatTimestamp(video.uploadedAt)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.more_vert,
                size: 18,
                color: AppColors.textPrimary,
              ),
              onPressed: () => VideoOptionsSheet.show(context, video),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      );
    });
  }
}
