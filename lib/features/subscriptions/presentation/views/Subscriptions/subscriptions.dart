import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:truthworld/features/subscriptions/presentation/controllers/subscription_controller.dart';
import 'package:truthworld/data/models/subscription_content.dart';
import 'package:truthworld/components/ui/video_card.dart';
import 'package:truthworld/components/ui/playlist_card.dart';
import 'package:truthworld/components/ui/community_post_card.dart';

class SubscriptionsPage extends StatelessWidget {
  final bool isDashboard;
  SubscriptionsPage({super.key, this.isDashboard = false});

  final SubscriptionController controller = Get.put(SubscriptionController());

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, deviceType) {
        final spacing = context.spacing;
        final isMobile = context.isMobile;

        return Scaffold(
          backgroundColor: AppColors.bgPage,
          body: RefreshIndicator(
            onRefresh: () => controller.refresh(),
            color: AppColors.brand,
            backgroundColor: AppColors.bgSurface,
            child: CustomScrollView(
              slivers: [
                // ── Dashboard Title (Desktop/Tablet Only) ──
                if (!isMobile || isDashboard)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(spacing, spacing, spacing, spacing / 2),
                      child: Text(
                        'Subscriptions',
                        style: GoogleFonts.robotoCondensed(
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
                    child: _buildFilterBar(context),
                  ),
                ),

                // ── Content Grid / List ──
                Obx(() {
                  if (controller.isLoading.value && controller.allContent.isEmpty) {
                    return _buildLoadingState();
                  }

                  if (controller.hasError.value && controller.allContent.isEmpty) {
                    return _buildErrorState();
                  }

                  if (controller.filteredContent.isEmpty) {
                    return _buildEmptyState();
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
        padding: EdgeInsets.symmetric(vertical: context.spacing / 2),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.bgDivider, width: 0.5)),
        ),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: context.spacing),
          itemCount: controller.subscribedChannels.length,
          itemBuilder: (context, index) {
            final channel = controller.subscribedChannels[index];
            return Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.bgSurface,
                    backgroundImage: channel.avatarUrl.isNotEmpty
                        ? CachedNetworkImageProvider(channel.avatarUrl)
                        : null,
                    child: channel.avatarUrl.isEmpty
                        ? Text(channel.name[0].toUpperCase(), style: const TextStyle(color: Colors.white))
                        : null,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 64,
                    child: Text(
                      channel.name,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.roboto(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
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
      padding: EdgeInsets.symmetric(horizontal: context.spacing, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildDropdown<ContentFilter>(
              label: 'Content',
              value: controller.selectedContentFilter.value,
              values: ContentFilter.values,
              onSelected: (val) => controller.setContentFilter(val.name),
            ),
            const SizedBox(width: 12),
            _buildDropdown<SortFilter>(
              label: 'Sort',
              value: controller.selectedSortFilter.value,
              values: SortFilter.values,
              onSelected: (val) => controller.setSortFilter(val.name),
            ),
            const SizedBox(width: 12),
            Obx(() {
              // Only show duration filter for videos
              if (controller.selectedContentFilter.value != ContentFilter.playlists.name &&
                  controller.selectedContentFilter.value != ContentFilter.communityPosts.name) {
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
            _buildDropdown<DateRangeFilter>(
              label: 'Upload Date',
              value: controller.selectedDateRangeFilter.value,
              values: DateRangeFilter.values,
              onSelected: (val) => controller.setDateRangeFilter(val.name),
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
            style: GoogleFonts.roboto(color: AppColors.textPrimary),
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
              style: GoogleFonts.roboto(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary, size: 18),
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
  Widget _buildLoadingState() {
    return const SliverFillRemaining(
      child: Center(child: CircularProgressIndicator(color: AppColors.brand)),
    );
  }

  Widget _buildErrorState() {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            Text(
              controller.errorMessage.value,
              style: GoogleFonts.roboto(color: AppColors.textSecondary),
            ),
            TextButton(
              onPressed: () => controller.refresh(),
              child: const Text('Try Again', style: TextStyle(color: AppColors.brand)),
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
            const Icon(Icons.subscriptions_outlined, size: 48, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            Text(
              'No content found for the selected filters',
              style: GoogleFonts.roboto(color: AppColors.textSecondary),
            ),
            TextButton(
              onPressed: () {
                controller.selectedContentFilter.value = ContentFilter.all.name;
                controller.selectedDurationFilter.value = DurationFilter.all.name;
                controller.selectedSortFilter.value = SortFilter.popular.name;
                controller.selectedDateRangeFilter.value = DateRangeFilter.all.name;
                controller.applyFilters();
              },
              child: const Text('Clear Filters', style: TextStyle(color: AppColors.brand)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Custom Persistent Header for Filter Bar ──
class _SliverFilterBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _SliverFilterBarDelegate({required this.child});

  @override
  double get minExtent => 60.0;
  @override
  double get maxExtent => 60.0;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(_SliverFilterBarDelegate oldDelegate) => true;
}
