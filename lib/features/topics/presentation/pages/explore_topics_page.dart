import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/topics/presentation/controllers/explore_topics_controller.dart';
import 'package:truthworld/features/topics/presentation/pages/explore/explore_topics_widgets.dart';

export 'explore/explore_topics_widgets.dart';

/// Explore Topics discovery screen coordinating topic browsing,
/// category deep-dives, and AI-assisted semantic exploration.
///
/// Transitions seamlessly between:
/// - Overview Mode (exact UI of first uploaded image):
///   Prominent header, AI search bar, Featured Topics with Discover/Trending/Newest/Popular pills
///   and 3 large photographic cards, and All Topics responsive 3-column grid.
/// - Selected Category Mode (exact UI of second uploaded image):
///   Circular back button, hero banner with photo fade, + Follow button,
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

        return Obx(() {
          final isAll =
              controller.selectedCategory.value.toLowerCase() == 'all';

          return PopScope(
            canPop: isAll,
            onPopInvokedWithResult: (didPop, result) {
              if (didPop) return;
              controller.selectCategory('all');
            },
            child: Scaffold(
              backgroundColor: bgColor,
              appBar: (!isDashboard && isAll && Navigator.canPop(context))
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
                      child: isAll
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
                            ),
                    ),
                  ),
                ),
              ),
            ),
          );
        });
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
        // 1. Header Section: Title + Subtitle
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Explore Topics',
                style: TextStyle(
                  fontSize: isDesktop ? 32 : (isTablet ? 26 : 22),
                  fontWeight: FontWeight.bold,
                  color: primaryText,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Discover meaningful content across topics that inspire, inform, and uplift.',
                style: TextStyle(
                  fontSize: 14,
                  color: secondaryText,
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

        // 3. Featured Topics Section
        ExploreTopicsFeaturedSection(
          isDesktop: isDesktop,
          isTablet: isTablet,
          isMobile: isMobile,
        ),
        const SizedBox(height: 32),

        // 4. All Topics Section (Responsive 3-Column Grid)
        ExploreTopicsAllCategoriesGrid(
          isDesktop: isDesktop,
          isTablet: isTablet,
          isMobile: isMobile,
        ),
        const SizedBox(height: 24),
      ],
    );
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
