import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/topics/presentation/controllers/explore_topics_controller.dart';
import 'package:truthworld/features/topics/presentation/pages/explore/explore_topics_widgets.dart';
import 'package:truthworld/features/topics/presentation/widgets/comments/topic_comment_models_and_helpers.dart';
import 'package:truthworld/routes/app_routes.dart';
import 'package:truthworld/theme/app_colors.dart';

export 'explore/explore_topics_widgets.dart';

/// Explore Topics discovery screen coordinating topic browsing,
/// category deep-dives, and AI-assisted semantic exploration.
///
/// Transitions seamlessly between:
/// - Overview Mode (exact UI of first uploaded image):
///   Prominent header, AI search bar, Featured Topics with Discover/Trending/Newest/Popular pills
///   and 3 large photographic cards, and All Topics responsive 3-column grid.
/// - Selected Category Mode (exact UI of second uploaded image):
///   Circular back button, hero banner with photo fade,
///   category search bar, Trending/Newest/Popular filter pills, and 3-column subtopics grid.
class ExploreTopicsPage extends StatelessWidget {
  const ExploreTopicsPage({super.key, this.isDashboard = false});

  final bool isDashboard;

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<ExploreTopicsController>()
        ? Get.find<ExploreTopicsController>()
        : Get.put(ExploreTopicsController());

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= kTabletBreakpoint;
        final isTablet = constraints.maxWidth >= kMobileBreakpoint &&
            constraints.maxWidth < kTabletBreakpoint;
        final isMobile = constraints.maxWidth < kMobileBreakpoint;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            if (controller.selectedCategory.value.toLowerCase() != 'all') {
              controller.selectCategory('all');
            } else if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
          child: Scaffold(
            backgroundColor: bgColor,
            appBar: (!isDashboard && Navigator.canPop(context))
                ? _buildOverviewAppBar(context, isTablet: isTablet)
                : null,
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1440),
                  child: SingleChildScrollView(
                    controller: controller.scrollController,
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal:
                          isDesktop ? 32.0 : (isTablet ? 24.0 : 16.0),
                      vertical: 16.0,
                    ),
                    child: Obx(() {
                      final isAll =
                          controller.selectedCategory.value.toLowerCase() == 'all';
                      return isAll
                          ? _buildOverviewBody(
                              controller,
                              isDesktop: isDesktop,
                              isTablet: isTablet,
                              isMobile: isMobile,
                            )
                          : ExploreCategoryDetailView(
                              categoryName: controller.selectedCategory.value,
                              isDesktop: isDesktop,
                              isTablet: isTablet,
                              isMobile: isMobile,
                            );
                    }),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOverviewBody(
    ExploreTopicsController controller, {
    required bool isDesktop,
    required bool isTablet,
    required bool isMobile,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Header Section: Icon + Title + Subtitle + "+ Create Topic" action
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF222226),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.interests_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Explore Topics',
                      style: TextStyle(
                        fontSize: isDesktop ? 30 : (isTablet ? 24 : 20),
                        fontWeight: FontWeight.bold,
                        color: primaryText,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Discover meaningful content across topics that inspire, inform, and uplift.',
                      style: TextStyle(
                        fontSize: 13,
                        color: secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Propose / Create Topic Action Button
              Material(
                color: buttonBg,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    if (!AuthService.to.isAuthenticated.value) {
                      showTopicSignInPrompt('create a topic');
                      return;
                    }
                    Get.toNamed<void>(AppRoutes.createTopic);
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 12 : 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.textPrimary.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.add_rounded,
                          color: primaryText,
                          size: 18,
                        ),
                        if (!isMobile) ...[
                          const SizedBox(width: 6),
                          const Text(
                            'Create Topic',
                            style: TextStyle(
                              color: primaryText,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 2. Search Bar with AI Sparkle & Mic
        ExploreTopicsSearchBar(
          isMobile: isMobile,
          isTablet: isTablet,
          isDesktop: isDesktop,
        ),

        // Active AI Topic Query Banner (when AI semantic search is triggered)
        const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: ExploreTopicsAiBanner(),
        ),

        // 3. Conditional Content: Search Results Mode vs. Standard Overview Mode
        Obx(() {
          final isSearching = controller.searchQuery.value.trim().isNotEmpty;

          if (isSearching) {
            return ExploreTopicsSearchResults(
              isDesktop: isDesktop,
              isTablet: isTablet,
              isMobile: isMobile,
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Featured Topics Section
              ExploreTopicsFeaturedSection(
                isDesktop: isDesktop,
                isTablet: isTablet,
                isMobile: isMobile,
              ),
              const SizedBox(height: 32),

              // All Topics Section (Responsive 3-Column Grid)
              ExploreTopicsAllCategoriesGrid(
                isDesktop: isDesktop,
                isTablet: isTablet,
                isMobile: isMobile,
              ),
              const SizedBox(height: 24),

              // Active Direct Video Discovery Trays
              _buildVideoDiscoverySection(
                controller,
                isDesktop: isDesktop,
                isTablet: isTablet,
                isMobile: isMobile,
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildVideoDiscoverySection(
    ExploreTopicsController controller, {
    required bool isDesktop,
    required bool isTablet,
    required bool isMobile,
  }) {
    return Obx(() {
      final activeTopics = controller.activeTopicsForVideoTrays;
      if (activeTopics.isEmpty) return const SizedBox.shrink();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trending Discussions & Videos',
                  style: TextStyle(
                    fontSize: isDesktop ? 22 : (isTablet ? 20 : 18),
                    fontWeight: FontWeight.bold,
                    color: primaryText,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Watch videos from active community topics',
                  style: TextStyle(
                    fontSize: 13,
                    color: secondaryText,
                  ),
                ),
              ],
            ),
          ),
          for (final topic in activeTopics)
            ExploreTopicVideoSection(
              topic: topic,
              isMobile: isMobile,
              isTablet: isTablet,
              isDesktop: isDesktop,
            ),
          const SizedBox(height: 16),
        ],
      );
    });
  }

  PreferredSizeWidget _buildOverviewAppBar(
    BuildContext context, {
    bool isTablet = false,
  }) {
    return AppBar(
      backgroundColor: bgColor,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      leading: Container(
        margin: const EdgeInsets.only(left: 12, top: 8, bottom: 8),
        child: Material(
          color: buttonBg,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              Get.back<void>();
            },
            borderRadius: BorderRadius.circular(12),
            child: const Center(
              child: Icon(
                Icons.arrow_back_rounded,
                color: primaryText,
                size: 20,
              ),
            ),
          ),
        ),
      ),
      title: const Text(
        'Explore Topics',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: primaryText,
        ),
      ),
    );
  }
}
