import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/widgets/deferred_widget.dart';
import 'package:truthworld/features/community/data/models/community_post_model.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart'
    hide darkSurface;
import 'package:truthworld/features/home/presentation/controllers/home_discovery_controller.dart';
import 'package:truthworld/features/home/presentation/views/home/widgets/home_featured_banner.dart';
import 'package:truthworld/features/home/presentation/views/home/widgets/home_playlists_section.dart';
import 'package:truthworld/features/home/presentation/views/home/widgets/home_shimmer_placeholders.dart';
import 'package:truthworld/features/home/presentation/views/home/widgets/home_video_grid_section.dart';
import 'package:truthworld/features/subscriptions/presentation/views/subscriptions/subscriptions.dart'
    deferred as subscriptions;
import 'package:truthworld/features/topics/presentation/pages/explore_topics_page.dart'
    deferred as explore_topics;
import 'package:truthworld/theme/app_theme.dart';

/// Main scrollable feed content coordinator for Home view.
class HomeMainContent extends StatelessWidget {
  const HomeMainContent({
    required this.isMobile,
    required this.isTablet,
    required this.isDesktop,
    required this.homeController,
    required this.appBarActionsBuilder,
    super.key,
  });

  final bool isMobile;
  final bool isTablet;
  final bool isDesktop;
  final HomeController homeController;
  final List<Widget> Function(BuildContext) appBarActionsBuilder;

  String _formatViews(int views) {
    if (views < 1000) return views.toString();
    if (views < 1000000) {
      return '${(views / 1000).toStringAsFixed(views % 1000 == 0 ? 0 : (views < 100000 ? 1 : 0))}K';
    }
    if (views < 1000000000) {
      return '${(views / 1000000).toStringAsFixed(views % 1000000 == 0 ? 0 : (views < 100000000 ? 1 : 0))}M';
    }
    return '${(views / 1000000000).toStringAsFixed(views % 1000000000 == 0 ? 0 : (views < 100000000000 ? 1 : 0))}B';
  }

  String _formatTimestamp(Timestamp timestamp) {
    try {
      return timeago.format(timestamp.toDate());
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'HomeMainContent._formatTimestamp',
      );
      return 'some time ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = isMobile ? 16.0 : (isTablet ? 24.0 : 32.0);
    final featuredBannerSection = SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FeaturedVideoBanner(horizontalPadding: horizontalPadding),
          const SizedBox(height: 32),
          PersonalizedPlaylistsSection(
            horizontalPadding: horizontalPadding,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            modernDarkProfessionalTheme.scaffoldBackgroundColor,
            modernDarkProfessionalTheme.scaffoldBackgroundColor.withValues(
              alpha: 0.95,
            ),
          ],
        ),
      ),
      child: Obx(() {
        final isPostsTab =
            homeController.selectedCategory.value == 'Posts';
        final isSubscriptionsTab =
            homeController.selectedCategory.value == 'Subscriptions';
        final isTopicsTab =
            homeController.selectedCategory.value == 'Topics' ||
            homeController.selectedCategory.value == 'Explore Topics';

        return RefreshIndicator(
          color: Colors.white,
          backgroundColor: darkSurface,
          onRefresh: homeController.refreshHomeFeed,
          child: CustomScrollView(
            controller: homeController.scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (homeController.sideNavSelectedIndex.value ==
                  HomeController.indexHome)
                _buildMobileCategoryBar(
                  context,
                  homeController.availableCategories,
                ),
              if (isSubscriptionsTab)
                SliverFillRemaining(
                  child: DeferredWidget(
                    key: const PageStorageKey('subscriptions_category_view'),
                    loader: subscriptions.loadLibrary,
                    placeholder: const SubscriptionsShimmerPlaceholder(),
                    builder: () =>
                        subscriptions.SubscriptionsPage(isDashboard: true),
                  ),
                )
              else if (isTopicsTab)
                SliverFillRemaining(
                  child: DeferredWidget(
                    key: const PageStorageKey('topics_category_view'),
                    loader: explore_topics.loadLibrary,
                    placeholder: const TopicsShimmerPlaceholder(),
                    builder: () =>
                        explore_topics.ExploreTopicsPage(isDashboard: true),
                  ),
                )
              else ...[
                if (homeController.selectedCategory.value == 'All')
                  featuredBannerSection
                else
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 16),
                  ),
                if (homeController.isLoadingVideos.value)
                  HomeVideoGridSection(
                    isMobile: isMobile,
                    isTablet: isTablet,
                    isDesktop: isDesktop,
                    videos: const [],
                    heroPrefix: 'grid_loading',
                    isLoading: true,
                    isPosts: isPostsTab,
                    horizontalPadding: horizontalPadding,
                    formatViews: _formatViews,
                    formatTimestamp: _formatTimestamp,
                  )
                else
                  HomeVideoGridSection(
                    isMobile: isMobile,
                    isTablet: isTablet,
                    isDesktop: isDesktop,
                    videos: isDesktop && !isPostsTab
                        ? homeController.homeFeedItems
                            .where((item) => item is! CommunityPostModel)
                            .toList()
                        : homeController.homeFeedItems,
                    heroPrefix: 'main_grid',
                    isLoading: false,
                    isPosts: isPostsTab,
                    horizontalPadding: horizontalPadding,
                    formatViews: _formatViews,
                    formatTimestamp: _formatTimestamp,
                  ),
                if (homeController.isLoadingMore.value)
                  const SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(color: primaryAccent),
                      ),
                    ),
                  )
                else
                  const SliverToBoxAdapter(child: SizedBox.shrink()),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: isMobile || isTablet ? kBottomNavBarHeight + 16 : 16,
                  ),
                ),
              ],
            ],
          ),
        );
      }),
    );
  }

  Widget _buildMobileCategoryBar(
    BuildContext context,
    List<String> categories,
  ) {
    return SliverAppBar(
      floating: true,
      pinned: true,
      snap: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 0,
      backgroundColor: modernDarkProfessionalTheme.appBarTheme.backgroundColor,
      surfaceTintColor:
          modernDarkProfessionalTheme.appBarTheme.surfaceTintColor,
      bottom: _buildCategoryChipsBar(context, categories),
    );
  }

  PreferredSize _buildCategoryChipsBar(
    BuildContext context,
    List<String> categories,
  ) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(48),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: modernDarkProfessionalTheme.appBarTheme.backgroundColor,
          border: Border(
            bottom: BorderSide(
              color: modernDarkProfessionalTheme.dividerColor,
              width: 0.5,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            // All Categories Popup Button
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 8),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  _showAllCategoriesPopup(context, HomeDiscoveryController.categories);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF272727),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.grid_view_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(right: 16),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final category = categories[index];
                  return Obx(() {
                    final isSelected =
                        homeController.selectedCategory.value == category;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          homeController.selectCategory(category);
                          HapticFeedback.selectionClick();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF272727),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            category,
                            style: GoogleFonts.roboto(
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isSelected ? Colors.black : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    );
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAllCategoriesPopup(BuildContext context, List<String> categories) {
    final searchQuery = ''.obs;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Obx(() {
          final query = searchQuery.value.toLowerCase();
          final filtered = categories
              .where(
                (c) => c.toLowerCase().contains(query),
              )
              .toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: BoxDecoration(
              color: modernDarkProfessionalTheme.scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(
                top: BorderSide(
                  color: modernDarkProfessionalTheme.dividerColor,
                  width: 0.5,
                ),
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.grid_view_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'All Categories',
                      style: GoogleFonts.roboto(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  inputFormatters: [TruthworldTextInputFormatters.englishOnly],
                  style: GoogleFonts.roboto(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search categories...',
                    hintStyle: GoogleFonts.roboto(
                      color: AppColors.textTertiary,
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Colors.white,
                      size: 20,
                    ),
                    filled: true,
                    fillColor: const Color(0xFF272727),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (val) => searchQuery.value = val,
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 2.8,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                    itemCount: filtered.length,
                    itemBuilder: (context, idx) {
                      final cat = filtered[idx];
                      final isSelected =
                          homeController.selectedCategory.value == cat;
                      return InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          homeController.selectCategory(cat);
                          Navigator.pop(context);
                        },
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF272727),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.transparent,
                            ),
                          ),
                          child: Text(
                            cat,
                            style: GoogleFonts.roboto(
                              color: isSelected
                                  ? Colors.black
                                  : Colors.white,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }
}
