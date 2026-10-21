import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:truthworld/components/ui/auth/auth_bottom_sheet.dart';
import 'package:truthworld/components/ui/community_post_card.dart';
import 'package:truthworld/components/ui/playlist_card.dart';
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/components/ui/video_card.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/data/models/subscription_content.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/subscriptions/presentation/controllers/subscription_controller.dart';
import 'package:truthworld/features/topics/presentation/widgets/topic_card_widget.dart';
import 'package:truthworld/theme/app_theme.dart';

class SubscriptionsPage extends GetView<SubscriptionController> {
  const SubscriptionsPage({super.key, this.isDashboard = false});
  final bool isDashboard;

  @override
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
                      return _buildErrorState(context);
                    }

                    if (controller.filteredContent.isEmpty) {
                      return _buildEmptyState();
                    }

                    final isMobile = context.isMobile;
                    final isTablet = ResponsiveContext(context).isTablet;
                    final isMobileDevice = defaultTargetPlatform == TargetPlatform.android ||
                        defaultTargetPlatform == TargetPlatform.iOS;
                    final screenWidth = MediaQuery.of(context).size.width;
                    final crossAxisCount = isMobile
                        ? 1
                        : (isTablet || isMobileDevice
                            ? 2
                            : (screenWidth >= 2400
                                ? 5
                                : (screenWidth >= 1700
                                    ? 4
                                    : (screenWidth >= 1100 ? 3 : 2))));

                    return SliverPadding(
                      padding: EdgeInsets.symmetric(horizontal: spacing),
                      sliver: SliverMasonryGrid.count(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childCount: controller.filteredContent.length,
                        itemBuilder: (context, index) {
                          final item = controller.filteredContent[index];
                          if (index + 2 < controller.filteredContent.length) {
                            final nextItem =
                                controller.filteredContent[index + 2];
                            if (nextItem.type == ContentType.video &&
                                nextItem.video != null &&
                                nextItem.video!.thumbnailUrl.isNotEmpty) {
                              precacheImage(
                                CachedNetworkImageProvider(
                                  nextItem.video!.thumbnailUrl,
                                ),
                                context,
                              );
                            }
                          }
                          return _buildContentCard(item);
                        },
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
          isChannelContext: true,
        );
      case ContentType.playlist:
        return PlaylistCard(
          playlist: content.playlist!,
        );
      case ContentType.communityPost:
        return CommunityPostCard(
          post: content.communityPost!,
          isChannelContext: true,
        );
      case ContentType.topic:
        return TopicCardWidget(
          topic: content.topic,
          isDashboard: true,
        );
    }
  }

  // ── States: Loading, Error, Empty ──
  Widget _buildLoadingState(BuildContext context) {
    final isMobile = context.isMobile;
    final isTablet = ResponsiveContext(context).isTablet;
    final isMobileDevice = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = isMobile
        ? 1
        : (isTablet || isMobileDevice
            ? 2
            : (screenWidth >= 2400
                ? 5
                : (screenWidth >= 1700
                    ? 4
                    : (screenWidth >= 1100 ? 3 : 2))));

    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: context.layoutSpacing),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: isMobile ? 1.2 : (!isMobileDevice && screenWidth >= 1000 ? 1.15 : 0.8),
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => Shimmer.fromColors(
            baseColor: AppColors.bgInput.withValues(alpha: 0.3),
            highlightColor: AppColors.bgInput.withValues(alpha: 0.1),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.bgInput,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          childCount: 6,
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final isUnauthenticated = controller.currentUserId == null ||
        !AuthService.to.isAuthenticated.value;

    return SliverFillRemaining(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.subscriptions_outlined,
                size: 56,
                color: Colors.white,
              ),
              const SizedBox(height: 16),
              Text(
                isUnauthenticated
                    ? "Don't miss new videos"
                    : (controller.errorMessage.isNotEmpty
                        ? controller.errorMessage
                        : 'Something went wrong'),
                textAlign: TextAlign.center,
                style: GoogleFonts.roboto(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isUnauthenticated
                    ? 'Sign in to see updates from your favorite channels'
                    : 'Please try again later',
                textAlign: TextAlign.center,
                style: GoogleFonts.roboto(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              if (isUnauthenticated)
                ElevatedButton.icon(
                  onPressed: () => AuthBottomSheet.show(context),
                  icon: const Icon(Icons.account_circle_outlined, color: Colors.black),
                  label: Text(
                    'Sign in',
                    style: GoogleFonts.roboto(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                )
              else
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
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasNoSubs = controller.subscribedChannels.isEmpty;

    return SliverFillRemaining(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.subscriptions_outlined,
                size: 56,
                color: Colors.white,
              ),
              const SizedBox(height: 16),
              Text(
                hasNoSubs ? 'No subscriptions yet' : 'No content found',
                textAlign: TextAlign.center,
                style: GoogleFonts.roboto(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                hasNoSubs
                    ? 'Channels you subscribe to will show up here'
                    : 'Try changing your filter settings to see more content',
                textAlign: TextAlign.center,
                style: GoogleFonts.roboto(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              if (hasNoSubs)
                ElevatedButton(
                  onPressed: () {
                    if (Get.isRegistered<HomeController>()) {
                      final homeController = Get.find<HomeController>();
                      homeController.selectedCategory.value = 'All';
                      homeController.onBottomNavItemTapped(2);
                    } else {
                      Get.toNamed('/discover');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  child: Text(
                    'Discover Channels',
                    style: GoogleFonts.roboto(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                )
              else
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
