import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/components/ui/community_post_card.dart';
import 'package:truthworld/components/ui/playlist_card.dart';
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/components/ui/video_card.dart';
import 'package:truthworld/core/widgets/shimmer_skeletons.dart';
import 'package:truthworld/data/models/subscription_content.dart';
import 'package:truthworld/features/subscriptions/presentation/controllers/subscription_controller.dart';
import 'package:truthworld/features/topics/presentation/widgets/topic_card_widget.dart';
import 'package:truthworld/theme/app_theme.dart';

class SubscriptionsPage extends StatelessWidget {
  const SubscriptionsPage({super.key, this.isDashboard = false});
  final bool isDashboard;

  SubscriptionController get controller =>
      Get.isRegistered<SubscriptionController>()
          ? Get.find<SubscriptionController>()
          : Get.put(SubscriptionController());

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, deviceType) {
        final spacing = context.layoutSpacing;
        final isMobile = context.isMobile;

        return Scaffold(
          backgroundColor: AppColors.bgPage,
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: controller.refresh,
              color: AppColors.brand,
              backgroundColor: AppColors.bgSurface,
              child: CustomScrollView(
                slivers: [
                  // ── Dashboard Title (Desktop/Tablet Only) ──
                  if (!isMobile || isDashboard)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          spacing,
                          spacing,
                          spacing,
                          spacing / 2,
                        ),
                        child: Text(
                          'Subscriptions',
                          style: GoogleFonts.roboto(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),

                  // ── Subscribed Channels Horizontal Bar ──
                  SliverToBoxAdapter(
                    child: _buildChannelAvatars(context),
                  ),

                  // ── Industry Standard Filters Bar ──
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _SliverFilterBarDelegate(
                      builder: _buildFilterBar,
                    ),
                  ),

                  // ── Content Grid / List ──
                  Obx(() {
                    if (controller.isLoading &&
                        controller.allContent.isEmpty) {
                      return _buildLoadingState(context);
                    }

                    if (controller.hasError.value &&
                        controller.allContent.isEmpty) {
                      return _buildErrorState();
                    }

                    if (controller.filteredContent.isEmpty) {
                      return _buildEmptyState();
                    }

                    final isMobile = context.isMobile;
                    if (isMobile) {
                      return SliverPadding(
                        padding: EdgeInsets.symmetric(horizontal: spacing),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final item = controller.filteredContent[index];
                              if (item.type == ContentType.communityPost) {
                                return CommunityPostCard(
                                  post: item.communityPost!,
                                );
                              } else if (item.type == ContentType.video) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: VideoCard(
                                    video: item.video!,
                                    heroPrefix: 'subs',
                                  ),
                                );
                              }
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: _buildContentCard(item),
                              );
                            },
                            childCount: controller.filteredContent.length,
                          ),
                        ),
                      );
                    }

                    return SliverPadding(
                      padding: EdgeInsets.all(spacing),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: _getCrossAxisCount(context),
                          childAspectRatio: _getChildAspectRatio(context),
                          crossAxisSpacing: spacing,
                          mainAxisSpacing: spacing,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final item = controller.filteredContent[index];
                            return _buildContentCard(item);
                          },
                          childCount: controller.filteredContent.length,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Helper: Channel Avatars ──
  Widget _buildChannelAvatars(BuildContext context) {
    return Obx(() {
      if (controller.subscribedChannels.isEmpty) return const SizedBox.shrink();

      return Container(
        height: 110,
        padding: EdgeInsets.symmetric(vertical: context.layoutSpacing / 2),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.bgDivider, width: 0.5),
          ),
        ),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: context.layoutSpacing),
          itemCount: controller.subscribedChannels.length,
          itemBuilder: (context, index) {
            final channel = controller.subscribedChannels[index];
            return Padding(
              padding: const EdgeInsets.only(right: 20),
              child: GestureDetector(
                onTap: () {
                  Get.toNamed(
                    channel.channelRoute,
                    arguments: {'channel': channel},
                  );
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Column(
                    children: [
                      UserAvatar(
                        radius: 30,
                        photoUrl: channel.avatarUrl,
                        displayName: channel.name,
                        backgroundColor: AppColors.bgSurface,
                        textColor: AppColors.textPrimary,
                        fontSize: 24,
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 64,
                        child: Text(
                          channel.name,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    });
  }

  // ── Helper: Filter Bar ──
  Widget _buildFilterBar(BuildContext context) {
    return Container(
      color: AppColors.bgPage,
      padding: EdgeInsets.symmetric(
        horizontal: context.layoutSpacing,
        vertical: 12,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Obx(
              () => _buildDropdown<ContentFilter>(
                label: 'Content',
                value: controller.selectedContentFilter.value,
                values: ContentFilter.values,
                onSelected: (val) => controller.setContentFilter(val.name),
              ),
            ),
            const SizedBox(width: 12),
            Obx(
              () => _buildDropdown<SortFilter>(
                label: 'Sort',
                value: controller.selectedSortFilter.value,
                values: SortFilter.values,
                onSelected: (val) => controller.setSortFilter(val.name),
              ),
            ),
            const SizedBox(width: 12),
            Obx(() {
              // Only show duration filter for videos
              if (controller.selectedContentFilter.value !=
                      ContentFilter.playlists.name &&
                  controller.selectedContentFilter.value !=
                      ContentFilter.communityPosts.name) {
                return _buildDropdown<DurationFilter>(
                  label: 'Duration',
                  value: controller.selectedDurationFilter.value,
                  values: DurationFilter.values,
                  onSelected: (val) => controller.setDurationFilter(val.name),
                );
              }
              return const SizedBox.shrink();
            }),
            const SizedBox(width: 12),
            Obx(
              () => _buildDropdown<DateRangeFilter>(
                label: 'Upload Date',
                value: controller.selectedDateRangeFilter.value,
                values: DateRangeFilter.values,
                onSelected: (val) => controller.setDateRangeFilter(val.name),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown<T extends Enum>({
    required String label,
    required String value,
    required List<T> values,
    required Function(T) onSelected,
  }) {
    return PopupMenuButton<T>(
      onSelected: onSelected,
      color: AppColors.bgSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      itemBuilder: (context) => values.map((e) {
        return PopupMenuItem<T>(
          value: e,
          child: Text(
            e.name.capitalizeFirst!,
            style: const TextStyle(color: AppColors.textPrimary),
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.bgDivider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$label: ${value.capitalizeFirst}',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Icon(
              Icons.arrow_drop_down,
              color: AppColors.textPrimary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  // ── Helper: Content Card Mapping ──
  Widget _buildContentCard(SubscriptionContent content) {
    switch (content.type) {
      case ContentType.video:
        return VideoCard(
          video: content.video!,
          isGrid: true,
          heroPrefix: 'subs',
        );
      case ContentType.playlist:
        return PlaylistCard(
          playlist: content.playlist!,
        );
      case ContentType.communityPost:
        return CommunityPostCard(
          post: content.communityPost!,
          isFullWidth: false,
        );
      case ContentType.topic:
        return TopicCardWidget(
          topic: content.topic,
          isDashboard: true,
        );
    }
  }

  // ── Helper: Grid Parameters ──
  int _getCrossAxisCount(BuildContext context) {
    if (context.isMobile) return 1;
    if (ResponsiveContext(context).isTablet) return 2;
    return 3;
  }

  double _getChildAspectRatio(BuildContext context) {
    if (context.isMobile) return 0.85;
    return 0.8;
  }

  // ── States: Loading, Error, Empty ──
  Widget _buildLoadingState(BuildContext context) {
    return SliverPadding(
      padding: EdgeInsets.all(context.layoutSpacing),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _getCrossAxisCount(context),
          childAspectRatio: _getChildAspectRatio(context),
          crossAxisSpacing: context.layoutSpacing,
          mainAxisSpacing: context.layoutSpacing,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => const ShimmerVideoGridCard(),
          childCount: 6,
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: AppColors.textPrimary,
            ),
            const SizedBox(height: 16),
            Text(
              controller.errorMessage,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            TextButton(
              onPressed: controller.refresh,
              child: const Text(
                'Try Again',
                style: TextStyle(color: AppColors.brand),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.subscriptions_outlined,
              size: 48,
              color: AppColors.textPrimary,
            ),
            const SizedBox(height: 16),
            const Text(
              'No content found for the selected filters',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            TextButton(
              onPressed: () {
                controller.selectedContentFilter.value = ContentFilter.all.name;
                controller.selectedDurationFilter.value =
                    DurationFilter.all.name;
                controller.selectedSortFilter.value = SortFilter.trending.name;
                controller.selectedDateRangeFilter.value =
                    DateRangeFilter.all.name;
                controller.applyFilters();
              },
              child: const Text(
                'Clear Filters',
                style: TextStyle(color: AppColors.brand),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Custom Persistent Header for Filter Bar ──
class _SliverFilterBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverFilterBarDelegate({required this.builder});
  final Widget Function(BuildContext context) builder;

  @override
  double get minExtent => 60;
  @override
  double get maxExtent => 60;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return builder(context);
  }

  @override
  bool shouldRebuild(_SliverFilterBarDelegate oldDelegate) => true;
}
