import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/community_post_card.dart';
import 'package:truthworld/components/ui/video_card.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/core/services/algorithm/flip_coin_service.dart';
import 'package:truthworld/core/widgets/ad_widgets.dart';
import 'package:truthworld/core/widgets/shimmer_skeletons.dart';
import 'package:truthworld/features/community/data/models/community_post_model.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/presentation/widgets/topic_card_widget.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';

class RecommendationFeed extends StatelessWidget {
  const RecommendationFeed({
    required this.video,
    super.key,
    this.videoTag,
    this.shrinkWrap = false,
    this.physics,
    this.videos,
    this.isGrid = false,
  });

  final Video video;
  final String? videoTag;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final List<Video>? videos;
  final bool isGrid;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<VideoController>(tag: videoTag);

    return Obx(() {
      if (controller.isLoadingRecommendations.value) {
        return isGrid
            ? buildShimmerVideoGrid(count: 4)
            : buildShimmerVideoList(count: 4);
      }

      final displayVideos = videos ?? controller.filteredRecommendedVideos;
      final filters = controller.recommendationFilters;
      final selectedFilter = controller.selectedRecommendationFilter.value;

      final Widget pillsBar = Container(
        height: 50,
        margin: const EdgeInsets.only(bottom: 8),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: filters.length,
          itemBuilder: (context, index) {
            final filter = filters[index];
            final isSelected = filter == selectedFilter;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  if (filter == 'Flip Coin') {
                    if (Get.isRegistered<FlipCoinService>()) {
                      final flipService = Get.find<FlipCoinService>();
                      if (!flipService.isVideoFlipped(controller.video.id)) {
                        flipService.toggleVideoFlip(controller.video.id);
                      }
                    }
                    controller.selectedRecommendationFilter.value = 'Flip Coin';
                    controller.reloadRecommendationsForFlip();
                  } else {
                    if (Get.isRegistered<FlipCoinService>()) {
                      final flipService = Get.find<FlipCoinService>();
                      if (flipService.isVideoFlipped(controller.video.id)) {
                        flipService.toggleVideoFlip(controller.video.id);
                        controller.reloadRecommendationsForFlip();
                      }
                    }
                    controller.selectedRecommendationFilter.value = filter;
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: isSelected
                        ? null
                        : Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                            width: 0.5,
                          ),
                  ),
                  child: Center(
                    child: Text(
                      filter,
                      style: TextStyle(
                        color: isSelected ? Colors.black : Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );

      final isAllTab =
          (selectedFilter == 'All' || selectedFilter == 'Flip Coin') &&
              videos == null;
      final displayItems = isAllTab ? controller.recommendedItems : displayVideos;

      final videoList = isGrid
          ? LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final isMobileDevice = defaultTargetPlatform == TargetPlatform.android ||
                    defaultTargetPlatform == TargetPlatform.iOS;
                var crossAxisCount = 1;
                var aspectRatio = 1.2;

                if (!isMobileDevice && width >= 1000) {
                  if (width >= 2100) {
                    crossAxisCount = 4;
                    aspectRatio = 1.25;
                  } else if (width >= 1600) {
                    crossAxisCount = 3;
                    aspectRatio = 1.25;
                  } else {
                    crossAxisCount = 2;
                    aspectRatio = 1.25;
                  }
                } else {
                  if (width > 1200) {
                    crossAxisCount = 4;
                    aspectRatio = 1.1;
                  } else if (width > 900) {
                    crossAxisCount = 3;
                    aspectRatio = 1.1;
                  } else if (width > 600) {
                    crossAxisCount = 2;
                    aspectRatio = 1.2;
                  }
                }

                return GridView.builder(
                  shrinkWrap: shrinkWrap,
                  physics: physics,
                  padding: const EdgeInsets.all(16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: aspectRatio,
                  ),
                  itemCount: displayItems.length,
                  itemBuilder: (context, index) {
                    final item = displayItems[index];
                    if (item is Topic) {
                      return TopicCardWidget(
                        topic: item,
                      );
                    }
                    if (item is CommunityPostModel) {
                      return CommunityPostCard(
                        post: item,
                      );
                    }
                    if (item is Video) {
                      return VideoCard(
                        video: item,
                        isGrid: true,
                        heroPrefix: 'rec_grid_${videoTag ?? 'global'}',
                      );
                    }
                    if (item is AdItem) {
                      if (item.adType == 'homepage') {
                        return const SizedBox.shrink();
                      }
                      return HomepageAdCard(
                        ad: item,
                      );
                    }
                    return const SizedBox.shrink();
                  },
                );
              },
            )
          : ListView.builder(
              shrinkWrap: shrinkWrap,
              physics: physics,
              padding: const EdgeInsets.all(16),
              itemCount: displayItems.length,
              itemBuilder: (context, index) {
                final item = displayItems[index];
                if (item is Topic) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: TopicCardWidget(
                      topic: item,
                    ),
                  );
                }
                if (item is CommunityPostModel) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: CommunityPostCard(
                      post: item,
                    ),
                  );
                }
                if (item is Video) {
                  return VideoCard(
                    video: item,
                    heroPrefix: 'rec_list_${videoTag ?? 'global'}',
                  );
                }
                if (item is AdItem) {
                  if (item.adType == 'homepage') {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: ScrollAdCard(
                      ad: item,
                      contextChannelId: video.channelId,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          pillsBar,
          // Render Scroll Ad before recommended videos
          if (Get.isRegistered<AdService>() && AdService.to.showAds.value)
            Obx(() {
              final scrollAds = AdService.to.getAdsForType('scroll');
              final sponsorAd = AdService.to.getSponsorAdForVideo(controller.video.id);
              final displayAd = scrollAds.isNotEmpty ? scrollAds.first : sponsorAd;
              if (displayAd == null || displayAd.adType == 'homepage') return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 8),
                child: ScrollAdCard(
                  ad: displayAd,
                  contextChannelId: controller.video.channelId,
                ),
              );
            }),
          if (displayItems.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No recommendations found',
                  style: TextStyle(color: Colors.white24),
                ),
              ),
            )
          else
            shrinkWrap ? videoList : Expanded(child: videoList),
        ],
      );
    });
  }
}
