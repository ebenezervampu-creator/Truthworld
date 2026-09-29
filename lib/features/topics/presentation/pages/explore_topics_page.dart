import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/topics/presentation/controllers/explore_topics_controller.dart';
import 'package:truthworld/features/topics/presentation/pages/explore/explore_topics_widgets.dart';
import 'package:truthworld/theme/app_colors.dart';

export 'explore/explore_topics_widgets.dart';

/// Explore Topics discovery screen coordinating category browsing,
/// AI semantic intent querying, and interactive topic video strips.
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
        final isDesktop = constraints.maxWidth >= kDesktopBreakpoint;
        final isTablet =
            constraints.maxWidth >= kMobileBreakpoint &&
            constraints.maxWidth < kDesktopBreakpoint;
        final isMobile = constraints.maxWidth < kMobileBreakpoint;

        return Scaffold(
          backgroundColor: bgColor,
          appBar: (!isDashboard)
              ? _buildModernAppBar(
                  context,
                  isTablet: isTablet,
                  isDesktop: isDesktop,
                )
              : null,
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 32.0 : (isTablet ? 24.0 : 16.0),
                vertical: 16.0,
              ),
              child: CustomScrollView(
                controller: controller.scrollController,
                physics: const BouncingScrollPhysics(),
                slivers: [
                  if (isDashboard)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Row(
                          children: [
                            Text(
                              'Explore Topics',
                              style: TextStyle(
                                fontSize: isDesktop ? 32 : (isTablet ? 26 : 22),
                                fontWeight: FontWeight.bold,
                                color: primaryText,
                              ),
                            ),
                            const Spacer(),
                          ],
                        ),
                      ),
                    ),

                  // Search Bar
                  SliverToBoxAdapter(
                    child: ExploreTopicsSearchBar(isMobile: isMobile),
                  ),

                  // Active AI Topic Query Banner (when AI search is active)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: ExploreTopicsAiBanner(),
                    ),
                  ),

                  // Categories (Grid when 'all', selected header otherwise)
                  Obx(
                    () =>
                        controller.selectedCategory.value.toLowerCase() == 'all'
                            ? ExploreTopicsCategoryGrid(
                                isDesktop: isDesktop,
                                isTablet: isTablet,
                                isMobile: isMobile,
                              )
                            : ExploreTopicsSelectedCategoryHeader(
                                isTablet: isTablet,
                              ),
                  ),

                  // Filters Bar
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: ExploreTopicsFilterBar(),
                    ),
                  ),

                  // Topics feed
                  Obx(() {
                    if (controller.isLoading && controller.topics.isEmpty) {
                      return SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              HorizontalVideoSkeleton(
                                isMobile: isMobile,
                                isTablet: isTablet,
                                isDesktop: isDesktop,
                              ),
                              const SizedBox(height: 24),
                              HorizontalVideoSkeleton(
                                isMobile: isMobile,
                                isTablet: isTablet,
                                isDesktop: isDesktop,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    if (controller.errorMessage.isNotEmpty &&
                        controller.topics.isEmpty) {
                      return const SliverToBoxAdapter(
                        child: SizedBox(
                          height: 300,
                          child: ExploreTopicsErrorState(),
                        ),
                      );
                    }

                    if (controller.topics.isEmpty) {
                      return const SliverToBoxAdapter(
                        child: SizedBox(
                          height: 300,
                          child: ExploreTopicsEmptyState(),
                        ),
                      );
                    }

                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final topic = controller.topics[index];
                          return ExploreTopicVideoSection(
                            topic: topic,
                            isMobile: isMobile,
                            isTablet: isTablet,
                            isDesktop: isDesktop,
                          );
                        },
                        childCount: controller.topics.length,
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

  PreferredSizeWidget _buildModernAppBar(
    BuildContext context, {
    bool isTablet = false,
    bool isDesktop = false,
  }) {
    return AppBar(
      backgroundColor: surfaceColor.withValues(alpha: 0.95),
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      leading: Navigator.canPop(context)
          ? Container(
              margin: const EdgeInsets.only(left: 8),
              child: Material(
                color: buttonBg.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Get.back();
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    child: const Icon(
                      Icons.arrow_back_rounded,
                      color: AppColors.textPrimary,
                      size: 22,
                    ),
                  ),
                ),
              ),
            )
          : null,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.textPrimary,
                  AppColors.textPrimary.withValues(alpha: 0.5),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.explore_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Explore Topics',
            style: TextStyle(
              fontSize: isDesktop ? 26 : (isTablet ? 24 : 20),
              fontWeight: FontWeight.bold,
              color: primaryText,
            ),
          ),
        ],
      ),
      actions: const [
        SizedBox(width: 8),
      ],
    );
  }
}
