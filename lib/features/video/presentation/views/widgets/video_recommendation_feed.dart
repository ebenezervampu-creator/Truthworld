import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/community_post_card.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/core/services/algorithm/flip_coin_service.dart';
import 'package:truthworld/core/widgets/ad_widgets.dart';
import 'package:truthworld/core/widgets/shimmer_skeletons.dart';
import 'package:truthworld/features/community/data/models/community_post_model.dart';
import 'package:truthworld/features/miniplayer/presentation/utils/miniplayer_utils.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/presentation/widgets/topic_card_widget.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/views/widgets/video_interactive_avatars.dart';
import 'package:truthworld/features/video/presentation/views/widgets/video_recommendation_card.dart';
import 'package:truthworld/theme/app_theme.dart';

export 'package:truthworld/features/video/presentation/views/widgets/video_recommendation_card.dart';

/// High-performance video recommendation feed using true sliver virtualization.
/// Participates directly in CustomScrollView sliver layout without expensive shrinkWrapping.
class RecommendationFeed extends StatelessWidget {
  const RecommendationFeed({
    required this.video,
    super.key,
    this.videoTag,
    this.shrinkWrap = false,
    this.physics,
    this.videos,
    this.isGrid = false,
    this.asSliver,
  });

  final Video video;
  final String? videoTag;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final List<Video>? videos;
  final bool isGrid;
  final bool? asSliver;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<VideoController>(tag: videoTag);
    final effectiveAsSliver = asSliver ?? !shrinkWrap;

    return Obx(() {
      Widget buildSliverLoadingSkeletons(bool isGrid) {
        if (isGrid) {
          return SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.15,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => const ShimmerVideoGridCard(),
                childCount: 4,
              ),
            ),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          sliver: SliverList.separated(
            itemCount: 4,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) => const ShimmerVideoGridCard(),
          ),
        );
      }

      if (controller.isLoadingRecommendations.value) {
        final loadingGroup = SliverMainAxisGroup(
          slivers: [
            buildSliverLoadingSkeletons(isGrid),
          ],
        );
        if (!effectiveAsSliver) {
          return CustomScrollView(
            shrinkWrap: shrinkWrap,
            physics: physics ?? const NeverScrollableScrollPhysics(),
            slivers: [loadingGroup],
          );
        }
        return loadingGroup;
      }

      final displayVideos = videos ?? controller.filteredRecommendedVideos;
      final filters = controller.recommendationFilters;
      final selectedFilter = controller.selectedRecommendationFilter.value;
      final currentPlaylist = controller.currentPlaylist.value;
      final isPlaylistTab = currentPlaylist != null &&
          (selectedFilter == currentPlaylist.playlistName.trim() ||
           selectedFilter == 'Playlist: ${currentPlaylist.playlistName.trim()}');

      final currentTopic = controller.currentTopic.value;
      final isTopicTab = (controller.navigatedFromTopic.value || currentTopic != null) &&
          ((currentTopic != null &&
                  (selectedFilter == currentTopic.title.trim() ||
                      selectedFilter == 'Topic: ${currentTopic.title.trim()}')) ||
              (currentTopic == null &&
                  controller.videoTopicsList.any((t) =>
                      selectedFilter == t.title.trim() ||
                      selectedFilter == 'Topic: ${t.title.trim()}')));

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
                    controller.ensureFilterVideosLoaded(filter);
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

      final Widget playlistHeader = isPlaylistTab
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${currentPlaylist.playlistName} • ${controller.calculatedPlaylistIndex + 1} / ${controller.playlistVideos.isNotEmpty ? controller.playlistVideos.length : (currentPlaylist.videoIds.isNotEmpty ? currentPlaylist.videoIds.length : 1)}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Obx(
                    () => IconButton(
                      icon: Icon(
                        Icons.repeat,
                        size: 20,
                        color: controller.isPlaylistLooping.value
                            ? Colors.white
                            : Colors.white38,
                      ),
                      onPressed: () => controller.isPlaylistLooping.value =
                          !controller.isPlaylistLooping.value,
                      tooltip: 'Loop playlist',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Obx(
                    () => IconButton(
                      icon: Icon(
                        Icons.shuffle,
                        size: 20,
                        color: controller.isPlaylistShuffled.value
                            ? Colors.white
                            : Colors.white38,
                      ),
                      onPressed: () => controller.isPlaylistShuffled.value =
                          !controller.isPlaylistShuffled.value,
                      tooltip: 'Shuffle playlist',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink();

      final resolvedTopicTitle = currentTopic?.title ??
          controller.videoTopicsList
              .firstWhereOrNull((t) =>
                  t.title.trim() == selectedFilter ||
                  'Topic: ${t.title.trim()}' == selectedFilter)
              ?.title ??
          selectedFilter;

      final Widget topicHeader = isTopicTab
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$resolvedTopicTitle • ${displayVideos.length} ${displayVideos.length == 1 ? 'video' : 'videos'}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink();

      final isAllTab =
          (selectedFilter == 'All' || selectedFilter == 'Flip Coin') &&
              videos == null;
      final rawDisplayItems = isAllTab ? controller.recommendedItems : displayVideos;
      final seenItemIds = <String>{};
      final displayItems = <dynamic>[];
      for (final item in rawDisplayItems) {
        if (item is Video) {
          if (item.id.isNotEmpty && seenItemIds.add(item.id)) {
            displayItems.add(item);
          }
        } else {
          displayItems.add(item);
        }
      }

      Widget buildVideoItem(Video item, {required bool isGridItem}) {
        final isCurrentVideo = item.id == controller.video.id;

        void onVideoTap() {
          if (isPlaylistTab) {
            if (isCurrentVideo) return;
            MiniplayerNavigationHelper.navigateToVideoScreen(
              video: item,
              routeArguments: {
                'video': item,
                'playlist': currentPlaylist,
                'fromPlaylist': true,
              },
            );
          } else if (isTopicTab) {
            if (isCurrentVideo) return;
            final activeTopic = currentTopic ??
                controller.videoTopicsList.firstWhereOrNull((t) =>
                    t.name.trim() == selectedFilter ||
                    'Topic: ${t.name.trim()}' == selectedFilter);
            MiniplayerNavigationHelper.navigateToVideoScreen(
              video: item,
              routeArguments: {
                'video': item,
                'topic': activeTopic,
                'fromTopic': true,
                'topicVideos': displayVideos,
              },
            );
          } else {
            MiniplayerNavigationHelper.navigateToVideoScreen(
              video: item,
            );
          }
        }

        final card = RecommendationVideoCard(
          video: item,
          heroPrefix: isGridItem
              ? 'rec_grid_${videoTag ?? 'global'}'
              : 'rec_list_${videoTag ?? 'global'}',
          onTap: onVideoTap,
        );

        if ((isPlaylistTab || isTopicTab) && isCurrentVideo) {
          if (isGridItem) {
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.brand.withValues(alpha: 0.6),
                  width: 2,
                ),
              ),
              child: card,
            );
          } else {
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.brand.withValues(alpha: 0.6),
                  width: 1.5,
                ),
                color: AppColors.brand.withValues(alpha: 0.08),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: Row(
                      children: [
                        Obx(
                          () => PlayingAudioWaveAnimation(
                            isPlaying: controller.isPlayingRx.value,
                            height: 12,
                            barWidth: 2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'NOW PLAYING',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  card,
                ],
              ),
            );
          }
        }
        return card;
      }

      Widget buildSliverVideoList(
        BuildContext context,
        List<dynamic> items, {
        required bool isGrid,
      }) {
        if (isGrid) {
          return SliverLayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.crossAxisExtent;
              final isMobileDevice = defaultTargetPlatform == TargetPlatform.android ||
                  defaultTargetPlatform == TargetPlatform.iOS;
              var crossAxisCount = 1;
              var aspectRatio = 1.2;

              if (!isMobileDevice && width >= 1000) {
                if (width >= 2400) {
                  crossAxisCount = 5;
                  aspectRatio = 1.15;
                } else if (width >= 1700) {
                  crossAxisCount = 4;
                  aspectRatio = 1.15;
                } else if (width >= 1100) {
                  crossAxisCount = 3;
                  aspectRatio = 1.15;
                } else {
                  crossAxisCount = 2;
                  aspectRatio = 1.15;
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

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: aspectRatio,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = items[index];
                      if (item is Topic) {
                        return TopicCardWidget(topic: item);
                      }
                      if (item is CommunityPostModel) {
                        return CommunityPostCard(post: item);
                      }
                      if (item is Video) {
                        return buildVideoItem(item, isGridItem: true);
                      }
                      if (item is AdItem) {
                        if (item.adType == 'homepage') {
                          return const SizedBox.shrink();
                        }
                        return HomepageAdCard(ad: item);
                      }
                      return const SizedBox.shrink();
                    },
                    childCount: items.length,
                  ),
                ),
              );
            },
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          sliver: SliverList.separated(
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final item = items[index];
              if (item is Topic) {
                return TopicCardWidget(topic: item);
              }
              if (item is CommunityPostModel) {
                return CommunityPostCard(post: item);
              }
              if (item is Video) {
                return buildVideoItem(item, isGridItem: false);
              }
              if (item is AdItem) {
                if (item.adType == 'homepage') {
                  return const SizedBox.shrink();
                }
                return ScrollAdCard(
                  ad: item,
                  contextChannelId: video.channelId,
                );
              }
              return const SizedBox.shrink();
            },
          ),
        );
      }

      Widget? scrollAdSliver;
      if (Get.isRegistered<AdService>() && AdService.to.showAds.value) {
        final scrollAds = AdService.to.getAdsForType('scroll');
        final sponsorAd = AdService.to.getSponsorAdForVideo(controller.video.id);
        final displayAd = scrollAds.isNotEmpty ? scrollAds.first : sponsorAd;
        if (displayAd != null && displayAd.adType != 'homepage') {
          scrollAdSliver = SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 8),
              child: ScrollAdCard(
                ad: displayAd,
                contextChannelId: controller.video.channelId,
              ),
            ),
          );
        }
      }

      final slivers = <Widget>[
        SliverToBoxAdapter(child: pillsBar),
        if (isPlaylistTab) SliverToBoxAdapter(child: playlistHeader),
        if (isTopicTab) SliverToBoxAdapter(child: topicHeader),
        if (scrollAdSliver != null) scrollAdSliver,
        if (controller.isTabLoading.value)
          buildSliverLoadingSkeletons(isGrid)
        else if (displayItems.isEmpty)
          SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  selectedFilter.startsWith('From ')
                      ? 'No other videos from this channel'
                      : 'No recommendations found',
                  style: const TextStyle(color: Colors.white24),
                ),
              ),
            ),
          )
        else
          buildSliverVideoList(context, displayItems, isGrid: isGrid),
      ];

      final sliverGroup = SliverMainAxisGroup(slivers: slivers);

      if (!effectiveAsSliver) {
        return CustomScrollView(
          shrinkWrap: shrinkWrap,
          physics: physics ?? const NeverScrollableScrollPhysics(),
          slivers: [sliverGroup],
        );
      }

      return sliverGroup;
    });
  }
}
