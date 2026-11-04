import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/video_card/video_card_avatar.dart';
import 'package:truthworld/components/ui/video_card/video_card_controller.dart';
import 'package:truthworld/components/ui/video_card/video_card_formatters.dart';
import 'package:truthworld/components/ui/video_options_sheet.dart';
import 'package:truthworld/core/services/deep_link_service.dart';
import 'package:truthworld/core/widgets/channel_verified_badge.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Info block for grid layout cards (channel avatar, title, views, timestamp, options).
class VideoCardGridInfo extends StatelessWidget {
  const VideoCardGridInfo({
    required this.video,
    required this.controller,
    this.isChannelContext = false,
    super.key,
  });

  final Video video;
  final VideoCardController controller;
  final bool isChannelContext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobileDevice = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    final isDesktop = !isMobileDevice && MediaQuery.sizeOf(context).width >= 1000;

    return Obx(() {
      final avatarUrl = controller.realChannelAvatarUrl.value;
      final channelName = controller.realChannelName.value.isNotEmpty
          ? controller.realChannelName.value
          : video.channelName;

      return Padding(
        padding: EdgeInsets.fromLTRB(16, isDesktop ? 16 : 14, 12, isDesktop ? 18 : 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            VideoCardAvatar(
              imageUrl: avatarUrl,
              radius: isDesktop ? 24 : 22,
              placeholderText: channelName.isEmpty ? '?' : channelName,
            ),
            SizedBox(width: isDesktop ? 16 : 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: isDesktop ? 46 : 40,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        video.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                          fontSize: isDesktop ? 16 : 15,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: isDesktop ? 6 : 6),
                  SizedBox(
                    height: isDesktop ? 20 : 18,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              channelName,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: const Color(0xFFAAAAAA),
                                fontSize: isDesktop ? 13 : 12.5,
                                fontWeight: FontWeight.normal,
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          () {
                            final bool isTrusted = controller.isChannelTrusted.value ||
                                video.showVerifiedBadge ||
                                (DeepLinkService.instance.getChannelFromCache(video.channelId)?.showVerifiedBadge ?? false) ||
                                (DeepLinkService.instance.getChannelFromCache(channelName)?.showVerifiedBadge ?? false);
                            if (isTrusted) {
                              return Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: ChannelVerifiedBadge(size: isDesktop ? 13 : 12),
                              );
                            }
                            return const SizedBox.shrink();
                          }(),
                          Text(
                            '  •  ',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: const Color(0xFFAAAAAA),
                              fontSize: isDesktop ? 13 : 12.5,
                              fontWeight: FontWeight.normal,
                              height: 1.2,
                            ),
                          ),
                          Flexible(
                            child: Text(
                              '${VideoCardFormatters.formatViews(video.views)} ${video.views == 1 ? 'view' : 'views'}  •  ${VideoCardFormatters.formatTimestamp(video.uploadedAt)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: const Color(0xFFAAAAAA),
                                fontSize: isDesktop ? 13 : 12.5,
                                fontWeight: FontWeight.normal,
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.more_vert,
                size: isDesktop ? 22 : 20,
                color: Colors.white,
              ),
              onPressed: () => VideoOptionsSheet.show(
                context,
                video,
                isChannelContext: isChannelContext,
              ),
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
    this.isCompact = false,
    this.isChannelContext = false,
    super.key,
  });

  final Video video;
  final VideoCardController controller;
  final bool isCompact;
  final bool isChannelContext;

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
                    maxLines: isCompact ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                      fontSize: isCompact ? 12 : 14,
                    ),
                  ),
                  SizedBox(height: isCompact ? 3 : 6),
                  Row(
                    children: [
                      VideoCardAvatar(
                        imageUrl: avatarUrl,
                        radius: isCompact ? 7 : 10,
                        placeholderText: channelName.isEmpty ? '?' : channelName,
                      ),
                      SizedBox(width: isCompact ? 4 : 6),
                      Expanded(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                channelName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                  fontSize: isCompact ? 10 : null,
                                ),
                              ),
                            ),
                            () {
                              final bool isTrusted = controller.isChannelTrusted.value ||
                                  video.showVerifiedBadge ||
                                  (DeepLinkService.instance.getChannelFromCache(video.channelId)?.showVerifiedBadge ?? false) ||
                                  (DeepLinkService.instance.getChannelFromCache(channelName)?.showVerifiedBadge ?? false);
                              if (isTrusted) {
                                return Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: ChannelVerifiedBadge(size: isCompact ? 10 : 12),
                                );
                              }
                              return const SizedBox.shrink();
                            }(),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isCompact ? 2 : 4),
                  Text(
                    '${VideoCardFormatters.formatViews(video.views)} ${video.views == 1 ? 'view' : 'views'} · ${VideoCardFormatters.formatTimestamp(video.uploadedAt)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: isCompact ? 9 : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (!isCompact)
              IconButton(
                icon: const Icon(
                  Icons.more_vert,
                  size: 18,
                  color: AppColors.textPrimary,
                ),
                onPressed: () => VideoOptionsSheet.show(
                  context,
                  video,
                  isChannelContext: isChannelContext,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
      );
    });
  }
}
