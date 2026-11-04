import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/home/presentation/controllers/main_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/views/widgets/video_recommendation_feed.dart';
import 'package:truthworld/features/video/presentation/views/widgets/video_screen/video_claims_section.dart';
import 'package:truthworld/features/video/presentation/views/widgets/video_screen/video_info_section.dart';
import 'package:truthworld/features/video/presentation/views/widgets/video_screen/video_player_stage.dart';
import 'package:truthworld/features/video/presentation/widgets/video_comments_sheet.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Recommendation header with autoplay toggle switch.
class VideoScreenRecommendationHeader extends StatelessWidget {
  const VideoScreenRecommendationHeader({
    required this.controller,
    super.key,
  });

  final VideoController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Expanded(
            child: Text(
              'Recommended',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Autoplay',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(width: 4),
              Obx(
                () => Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: controller.isAutoplay.value,
                    onChanged: (v) {
                      controller.isAutoplay.value = v;
                      controller.towerPlayerController?.isAutoplay.value = v;
                    },
                    activeThumbColor: AppColors.brand,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Mobile layout for video screen with single vertical scroll feed.
class VideoScreenMobileLayout extends StatelessWidget {
  const VideoScreenMobileLayout({
    required this.controller,
    required this.mainController,
    required this.onSignInPrompt,
    this.channelController,
    this.videoTag,
    super.key,
  });

  final VideoController controller;
  final MainController mainController;
  final ChannelController? channelController;
  final VoidCallback onSignInPrompt;
  final String? videoTag;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      primary: true,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        VideoPlayerStage(controller: controller, videoTag: videoTag),
        VideoInfoHeader(
          controller: controller,
          mainController: mainController,
          channelController: channelController,
          onSignInPrompt: onSignInPrompt,
          videoTag: videoTag,
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: VideoClaimsChaptersSection(
              controller: controller,
              videoTag: videoTag,
            ),
          ),
        ),
        RecommendationFeed(
          video: controller.video,
          videoTag: videoTag,
        ),
      ],
    );
  }
}

/// Desktop layout for video screen with 2-column widescreen feed.
class VideoScreenDesktopLayout extends StatelessWidget {
  const VideoScreenDesktopLayout({
    required this.controller,
    required this.mainController,
    required this.onSignInPrompt,
    this.channelController,
    this.videoTag,
    super.key,
  });

  final VideoController controller;
  final MainController mainController;
  final ChannelController? channelController;
  final VoidCallback onSignInPrompt;
  final String? videoTag;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column (Video, Description, Comments)
        Expanded(
          flex: 7,
          child: CustomScrollView(
            primary: true,
            slivers: [
              VideoPlayerStage(controller: controller, videoTag: videoTag),
              VideoInfoHeader(
                controller: controller,
                mainController: mainController,
                channelController: channelController,
                onSignInPrompt: onSignInPrompt,
                isDesktop: true,
                videoTag: videoTag,
              ),
              ...VideoCommentsSheet.buildCommentsSlivers(
                context: context,
                controller: controller,
                mainController: mainController,
              ),
            ],
          ),
        ),
        // Divider
        Container(
          width: 1,
          color: AppColors.bgDivider.withValues(alpha: 0.5),
        ),
        // Right Column (Recommendations Sidebar)
        Expanded(
          flex: 3,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    children: [
                      VideoClaimsChaptersSection(
                        controller: controller,
                        videoTag: videoTag,
                      ),
                      const SizedBox(height: 16),
                      VideoScreenRecommendationHeader(controller: controller),
                    ],
                  ),
                ),
              ),
              RecommendationFeed(
                video: controller.video,
                videoTag: videoTag,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Body container switching between fullscreen view and responsive normal layout.
class VideoScreenLoadedBody extends StatelessWidget {
  const VideoScreenLoadedBody({
    required this.controller,
    required this.mainController,
    required this.onSignInPrompt,
    this.channelController,
    this.videoTag,
    super.key,
  });

  final VideoController controller;
  final MainController mainController;
  final ChannelController? channelController;
  final VoidCallback onSignInPrompt;
  final String? videoTag;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isFs = controller.isFullScreen.value;
      if (isFs) {
        return ColoredBox(
          color: Colors.black,
          child: Center(
            child: VideoPlayerView(
              controller: controller,
              videoTag: videoTag,
            ),
          ),
        );
      }
      return SafeArea(
        child: ResponsiveBuilder(
          builder: (context, device) {
            final isDesktop = device.isDesktop ||
                device.isLargeDesktop ||
                device.isUltraWide ||
                (device.isTablet &&
                    MediaQuery.of(context).orientation ==
                        Orientation.landscape &&
                    MediaQuery.sizeOf(context).shortestSide >=
                        TWBreakpoints.tablet);
            return isDesktop
                ? VideoScreenDesktopLayout(
                    controller: controller,
                    mainController: mainController,
                    channelController: channelController,
                    onSignInPrompt: onSignInPrompt,
                    videoTag: videoTag,
                  )
                : VideoScreenMobileLayout(
                    controller: controller,
                    mainController: mainController,
                    channelController: channelController,
                    onSignInPrompt: onSignInPrompt,
                    videoTag: videoTag,
                  );
          },
        ),
      );
    });
  }
}
