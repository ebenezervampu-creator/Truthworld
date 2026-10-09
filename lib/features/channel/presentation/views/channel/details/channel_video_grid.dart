import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/channel/presentation/views/channel/details/channel_details_state_widgets.dart';
import 'package:truthworld/features/channel/presentation/views/channel/details/channel_details_theme.dart';
import 'package:truthworld/features/miniplayer/presentation/utils/miniplayer_utils.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Filter chips for sorting channel videos.
class ChannelFilterChips extends GetView<ChannelController> {
  const ChannelFilterChips({super.key});

  @override
  Widget build(BuildContext context) {
    final filters = ['Latest', 'Popular', 'Oldest'];

    return Obx(
      () => Wrap(
        spacing: 8,
        children: filters.map((filter) {
          final isSelected = controller.videoSortFilter.value == filter;
          return ChoiceChip(
            label: Text(filter),
            selected: isSelected,
            onSelected: (selected) {
              if (selected) controller.setVideoSortFilter(filter);
            },
            backgroundColor: ytSurface,
            selectedColor: ytTextPrimary,
            labelStyle: TextStyle(
              color: isSelected ? ytBackground : ytTextPrimary,
              fontSize: 14,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: isSelected ? ytTextPrimary : ytSurfaceLight,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// A single video card in the channel video list.
class ChannelVideoListCard extends StatelessWidget {
  const ChannelVideoListCard({
    required this.video,
    super.key,
    this.isDesktop = false,
  });

  final Video video;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final isMobileDevice = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    final thumbWidth = (!isMobileDevice && isDesktop) ? 360.0 : (isDesktop ? 280.0 : 160.0);
    final thumbHeight = thumbWidth * 9 / 16;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          MiniplayerNavigationHelper.navigateToVideoScreen(
            video: video,
            routeArguments: {'video': video},
          );
        },
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
                    placeholder: (context, url) =>
                        Container(color: ytSurfaceLight),
                    errorWidget: (context, url, error) => const ColoredBox(
                      color: ytSurfaceLight,
                      child: Icon(
                        Icons.play_circle_outline,
                        color: ytTextSecondary,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
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
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: ytTextPrimary,
                      fontSize: isDesktop ? 16 : 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${ChannelDetailsStateWidgets.formatViews(video.views)} views • ${timeago.format(video.uploadedAt.toDate())}',
                    style: const TextStyle(
                      color: ytTextSecondary,
                      fontSize: 12,
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

/// Reactive video grid/list for channel videos.
class ChannelVideoGrid extends GetView<ChannelController> {
  const ChannelVideoGrid({
    super.key,
    this.isDesktop = false,
    this.isTablet = false,
  });

  final bool isDesktop;
  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoadingVideos.value) {
        return ChannelDetailsStateWidgets.buildShimmerGrid(
          isDesktop: isDesktop,
          isTablet: isTablet,
        );
      }

      if (controller.videos.isEmpty) {
        return ChannelDetailsStateWidgets.buildEmptyTabState(
          icon: Icons.videocam_off,
          title: 'No videos yet',
          subtitle: "This channel hasn't uploaded any videos",
        );
      }

      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: controller.videos.length,
        itemBuilder: (context, index) {
          final video = controller.videos[index];
          return ChannelVideoListCard(
            video: video,
            isDesktop: isDesktop,
          );
        },
      );
    });
  }
}
