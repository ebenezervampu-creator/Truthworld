import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/channel/presentation/views/channel/details/channel_details_state_widgets.dart';
import 'package:truthworld/features/channel/presentation/views/channel/details/channel_details_theme.dart';
import 'package:truthworld/features/channel/presentation/views/channel/details/channel_playlists_tab_view.dart';
import 'package:truthworld/features/channel/presentation/views/channel/details/channel_video_grid.dart';
import 'package:truthworld/features/miniplayer/presentation/utils/miniplayer_utils.dart';

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
class ChannelFeaturedVideoCard extends GetView<ChannelController> {
  const ChannelFeaturedVideoCard({super.key, this.isDesktop = false});

  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.videos.isEmpty) return const SizedBox.shrink();

      final video = controller.videos.first;
      return InkWell(
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: CachedNetworkImage(
                    imageUrl: video.thumbnailUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        Container(color: ytSurfaceLight),
                    errorWidget: (context, url, error) =>
                        const Icon(Icons.error, color: ytTextSecondary),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
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
            ],
          ),
        ),
      );
    });
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
              ChannelFeaturedVideoCard(isDesktop: isDesktop),
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
