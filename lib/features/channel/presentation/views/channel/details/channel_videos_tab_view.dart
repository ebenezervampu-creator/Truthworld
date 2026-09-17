import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/channel/presentation/views/channel/details/channel_details_theme.dart';
import 'package:truthworld/features/channel/presentation/views/channel/details/channel_video_grid.dart';

/// Videos tab view for Channel Details screen with sorting filter chips.
class ChannelVideosTabView extends GetView<ChannelController> {
  const ChannelVideosTabView({
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
              const ChannelFilterChips(),
              const SizedBox(height: 16),
              ChannelVideoGrid(
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
