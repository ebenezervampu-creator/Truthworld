import 'package:flutter/material.dart';
import 'package:truthworld/components/ui/back_symbol.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:truthworld/features/topics/data/models/topic_categories.dart';
import 'package:truthworld/features/topics/presentation/controllers/explore_topics_controller.dart';
import 'package:truthworld/features/topics/presentation/widgets/topic_card_widget.dart';

class ExploreTopicsPage extends StatefulWidget {
  final bool isDashboard;
  const ExploreTopicsPage({super.key, this.isDashboard = false});

  @override
  State<ExploreTopicsPage> createState() => _ExploreTopicsPageState();
}

class _ExploreTopicsPageState extends State<ExploreTopicsPage> {
  final ExploreTopicsController controller =
      Get.isRegistered<ExploreTopicsController>()
      ? Get.find<ExploreTopicsController>()
      : Get.put(ExploreTopicsController());
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 400) {
        controller.loadMoreTopics();
      }
    });

    // Synchronize text changes
    _searchController.addListener(() {
      controller.updateSearchQuery(_searchController.text);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final bool isDesktop = size.width >= 1024;
    final bool isTablet = size.width >= 600 && size.width < 1024;

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 1. App Bar
          _buildSliverAppBar(isDesktop),

          // 2. Search & Headers
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildExploreHeader(),
                  const SizedBox(height: 16),
                  _buildSearchBar(),
                ],
              ),
            ),
          ),

          // 3. Categories Scroller (2-row horizontal picker)
          SliverToBoxAdapter(child: _buildCategoriesScroller(isTablet)),

          // 6. Topics Grid
          Obx(() {
            if (controller.isLoading.value && controller.topics.isEmpty) {
              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: _buildShimmerGrid(isDesktop, isTablet),
              );
            }

            if (controller.errorMessage.isNotEmpty &&
                controller.topics.isEmpty) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: _buildErrorState(),
              );
            }

            if (controller.topics.isEmpty) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(),
              );
            }

            return SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              sliver: _buildTopicsGrid(isDesktop, isTablet),
            );
          }),

          Obx(() {
            if (controller.isLoadingMore.value) {
              final bool isMobile = !isDesktop && !isTablet;
              final int crossAxisCount = isMobile ? 1 : 2;
              final double childAspectRatio = isMobile ? 1.4 : (isTablet ? 1.6 : 1.8);
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: childAspectRatio,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => const _TopicShimmerWidget(),
                    childCount: crossAxisCount,
                  ),
                ),
              );
            }
            return const SliverToBoxAdapter(child: SizedBox.shrink());
          }),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(bool isDesktop) {
    return SliverAppBar(
      backgroundColor: AppColors.bgPage,
      elevation: 0,
      floating: true,
      pinned: false,
      snap: true,
      leading: widget.isDashboard
          ? null
          : IconButton(
              icon: const BackSymbol(color: Colors.white),
              onPressed: () => Get.back(),
            ),
      title: null,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          onPressed: () => controller.initialFetch(),
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildExploreHeader() {
    return Text(
      'Explore Topics',
      style: AppTextStyles.displaySmall.copyWith(
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.searchBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: TextField(
        controller: _searchController,
        style: AppTextStyles.inputText.copyWith(color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search dynamic topics...',
          hintStyle: AppTextStyles.inputHint.copyWith(
            color: AppColors.textTertiary,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.iconDefault,
            size: 22,
          ),
          suffixIcon: Obx(() {
            if (controller.searchQuery.value.isEmpty) {
              return const SizedBox.shrink();
            }
            return IconButton(
              icon: const Icon(
                Icons.clear_rounded,
                color: AppColors.iconDefault,
                size: 20,
              ),
              onPressed: () {
                _searchController.clear();
                controller.clearSearch();
              },
            );
          }),
        ),
      ),
    );
  }

  Widget _buildCategoriesScroller(bool isTablet) {
    final spacing = context.layoutSpacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(spacing, 24, spacing, 8),
          child: Row(
            children: [
              Icon(Icons.grid_view_rounded, color: AppColors.brand, size: 20),
              const SizedBox(width: 8),
              Text(
                'Browse Categories',
                style: AppTextStyles.titleMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Container(
          height: 340,
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: GridView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: spacing),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
              childAspectRatio: 0.52,
            ),
            itemCount: TopicCategoriesConfig.categories.length,
            itemBuilder: (context, index) {
              final category = TopicCategoriesConfig.categories[index];
              return Obx(() {
                final isSelected =
                    controller.selectedCategory.value.toLowerCase() ==
                    category.title.toLowerCase();
                return _CategoryCardWidget(
                  category: category,
                  isSelected: isSelected,
                  onTap: () => controller.selectCategory(category.title),
                );
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTopicsGrid(bool isDesktop, bool isTablet) {
    final bool isMobile = !isDesktop && !isTablet;
    final int crossAxisCount = isMobile ? 1 : 2;
    final double childAspectRatio = 16 / 9;
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: childAspectRatio,
      ),
      delegate: SliverChildBuilderDelegate((context, index) {
        final topic = controller.topics[index];
        return TopicCardWidget(topic: topic, isDashboard: widget.isDashboard);
      }, childCount: controller.topics.length),
    );
  }

  Widget _buildShimmerGrid(bool isDesktop, bool isTablet) {
    final bool isMobile = !isDesktop && !isTablet;
    final int crossAxisCount = isMobile ? 1 : 2;
    final double childAspectRatio = 16 / 9;
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: childAspectRatio,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) => const _TopicShimmerWidget(),
        childCount: 8,
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.redAccent,
              size: 60,
            ),
            const SizedBox(height: 16),
            Text(
              controller.errorMessage.value,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => controller.initialFetch(),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.brand),
              child: Text(
                'Try Again',
                style: AppTextStyles.buttonText.copyWith(color: Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final bool isSearch = controller.searchQuery.value.isNotEmpty;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSearch ? Icons.search_off_rounded : Icons.hub_outlined,
            color: Colors.white38,
            size: 80,
          ),
          const SizedBox(height: 16),
          Text(
            isSearch
                ? 'No topics match "${controller.searchQuery.value}"'
                : 'No topics available under this Category',
            style: AppTextStyles.titleMedium.copyWith(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try switching explore modes or explore different categories.',
            style: AppTextStyles.bodySmall.copyWith(color: Colors.white38),
          ),
        ],
      ),
    );
  }
}


class _CategoryCardWidget extends StatelessWidget {
  final TopicCategory category;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryCardWidget({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ObxValue<RxBool>(
      (isHovered) => MouseRegion(
        onEnter: (_) => isHovered.value = true,
        onExit: (_) => isHovered.value = false,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedScale(
            scale: isHovered.value ? 1.03 : 1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF00E5FF)
                      : (isHovered.value ? Colors.white38 : Colors.transparent),
                  width: 2.5,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ]
                    : (isHovered.value
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    category.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, err, stack) =>
                        Container(color: AppColors.bgSurface),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.15),
                          Colors.black.withValues(alpha: 0.85),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    bottom: 16,
                    right: 16,
                    child: Text(
                      category.title,
                      style: AppTextStyles.videoTitleMedium.copyWith(
                        color: isSelected
                            ? const Color(0xFF00E5FF)
                            : Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.8),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      false.obs,
    );
  }
}

class _TopicShimmerWidget extends StatelessWidget {
  const _TopicShimmerWidget();

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final bool isMobile = size.width < 600;
    final double padding = isMobile ? 12.0 : 16.0;
    final double buttonHeight = isMobile ? 32.0 : 36.0;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Shimmer.fromColors(
        baseColor: const Color(0xFF1F1F1F),
        highlightColor: const Color(0xFF2F2F2F),
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: isMobile ? 60 : 80,
                    height: isMobile ? 16 : 20,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  Container(
                    width: isMobile ? 80 : 100,
                    height: isMobile ? 16 : 20,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                width: 150,
                height: isMobile ? 20 : 24,
                color: Colors.white,
              ),
              SizedBox(height: isMobile ? 4 : 8),
              Container(
                width: 120,
                height: isMobile ? 12 : 16,
                color: Colors.white,
              ),
              SizedBox(height: isMobile ? 4 : 8),
              Container(
                width: 250,
                height: isMobile ? 11 : 14,
                color: Colors.white,
              ),
              SizedBox(height: isMobile ? 10 : 16),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: buttonHeight,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                  SizedBox(width: isMobile ? 6 : 8),
                  Expanded(
                    child: Container(
                      height: buttonHeight,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
