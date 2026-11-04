import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:truthworld/components/ui/video_options_sheet.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/channel/presentation/views/channel/details/channel_details_state_widgets.dart';
import 'package:truthworld/features/channel/presentation/views/channel/details/channel_details_theme.dart';
import 'package:truthworld/features/channel/presentation/views/channel/details/channel_playlists_tab_view.dart';
import 'package:truthworld/features/channel/presentation/views/channel/details/channel_video_grid.dart';
import 'package:truthworld/features/miniplayer/presentation/utils/miniplayer_utils.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Clean reusable section title widget for channel tabs.
class ChannelSectionTitle extends StatelessWidget {
  const ChannelSectionTitle({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: ytTextPrimary,
      ),
    );
  }
}

/// Featured video hero card for the Channel Home tab.
class ChannelFeaturedVideoCard extends StatelessWidget {
  const ChannelFeaturedVideoCard({
    super.key,
    this.isDesktop = false,
    this.isTablet = false,
    this.controller,
  });

  final bool isDesktop;
  final bool isTablet;
  final ChannelController? controller;

  ChannelController get _controller =>
      controller ?? Get.find<ChannelController>();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final activeController = _controller;
      if (activeController.videos.isEmpty) return const SizedBox.shrink();

      final video = activeController.videos.first;
      final isWide = isDesktop || isTablet;

      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          MiniplayerNavigationHelper.navigateToVideoScreen(
            video: video,
            routeArguments: {'video': video},
          );
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: ytSurface,
          ),
          child: isWide
              ? _buildDesktopCard(context, video)
              : _buildMobileCard(context, video),
        ),
      );
    });
  }

  Widget _buildDesktopCard(BuildContext context, Video video) {
    final thumbWidth = isDesktop ? 424.0 : 280.0;
    final thumbHeight = thumbWidth * 9 / 16;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: video.thumbnailUrl,
                  width: thumbWidth,
                  height: thumbHeight,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: thumbWidth,
                    height: thumbHeight,
                    color: ytSurfaceLight,
                  ),
                  errorWidget: (context, url, error) => ColoredBox(
                    color: ytSurfaceLight,
                    child: SizedBox(
                      width: thumbWidth,
                      height: thumbHeight,
                      child: const Center(
                        child: Icon(
                          Icons.play_circle_outline,
                          color: ytTextSecondary,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (video.duration.isNotEmpty)
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.bgPage.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      video.duration,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        video.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: isDesktop ? 18 : 16,
                          fontWeight: FontWeight.w600,
                          color: ytTextPrimary,
                          height: 1.3,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.more_vert,
                        size: 20,
                        color: ytTextSecondary,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'More options',
                      onPressed: () => VideoOptionsSheet.show(
                        context,
                        video,
                        isChannelContext: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${ChannelDetailsStateWidgets.formatViews(video.views)} views • ${timeago.format(video.uploadedAt.toDate())}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: ytTextSecondary,
                  ),
                ),
                if (video.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    video.description.trim(),
                    maxLines: isDesktop ? 4 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: ytTextSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileCard(BuildContext context, Video video) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(12),
          ),
          child: Stack(
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: CachedNetworkImage(
                  imageUrl: video.thumbnailUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      Container(color: ytSurfaceLight),
                  errorWidget: (context, url, error) => const ColoredBox(
                    color: ytSurfaceLight,
                    child: Center(
                      child: Icon(
                        Icons.play_circle_outline,
                        color: ytTextSecondary,
                      ),
                    ),
                  ),
                ),
              ),
              if (video.duration.isNotEmpty)
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.bgPage.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      video.duration,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
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
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: ytTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${ChannelDetailsStateWidgets.formatViews(video.views)} views • ${timeago.format(video.uploadedAt.toDate())}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: ytTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.more_vert,
                  size: 18,
                  color: ytTextSecondary,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'More options',
                onPressed: () => VideoOptionsSheet.show(
                  context,
                  video,
                  isChannelContext: true,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Home tab view for Channel Details screen.
class ChannelHomeTabView extends GetView<ChannelController> {
  const ChannelHomeTabView({
    required this.channel,
    super.key,
    this.isDesktop = false,
    this.isTablet = false,
  });

  final Channel channel;
  final bool isDesktop;
  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = isDesktop ? 32.0 : (isTablet ? 24.0 : 16.0);

    return RefreshIndicator(
      onRefresh: () => controller.loadInitialVideos(),
      color: ytTextPrimary,
      backgroundColor: ytSurface,
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ChannelSectionTitle(title: 'For you'),
              const SizedBox(height: 16),
              ChannelFeaturedVideoCard(
                isDesktop: isDesktop,
                isTablet: isTablet,
                controller: controller,
              ),
              const SizedBox(height: 24),
              const ChannelSectionTitle(title: 'Recent uploads'),
              const SizedBox(height: 16),
              ChannelVideoGrid(
                isDesktop: isDesktop,
                isTablet: isTablet,
              ),
              const SizedBox(height: 24),
              ChannelPlaylistsSection(
                channel: channel,
                isDesktop: isDesktop,
                isTablet: isTablet,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
