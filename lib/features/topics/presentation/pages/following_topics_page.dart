import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/presentation/controllers/following_topics_controller.dart';
import 'dart:ui';
import 'package:truthworld/features/topics/presentation/widgets/topic_card_widget.dart';

// PlaylistScreen identical visual constants
const kPrimaryDark = AppColors.brand; // Standardized brand highlight
const kSecondaryDark = Color(0xFF7B0A21); // Keep special crimson brand shade
const kDarkBackground = AppColors.bgPage;
const kDarkSurface = AppColors.bgSurface;
const kDarksurfaceContainerHighest = AppColors.bgSurfaceHover;

class FollowingTopicsPage extends StatefulWidget {
  final bool isDashboard;
  const FollowingTopicsPage({super.key, this.isDashboard = false});

  @override
  State<FollowingTopicsPage> createState() => _FollowingTopicsPageState();
}

class _FollowingTopicsPageState extends State<FollowingTopicsPage>
    with SingleTickerProviderStateMixin {
  final FollowingTopicsController controller =
      Get.isRegistered<FollowingTopicsController>()
      ? Get.find<FollowingTopicsController>()
      : Get.put(FollowingTopicsController());
  final TextEditingController _searchController = TextEditingController();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();

    _searchController.addListener(() {
      controller.updateSearchQuery(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _refreshFollowingTopics() async {
    await controller.fetchFollowingTopics();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1200;
    final isDesktop = screenWidth >= 1200;

    return Scaffold(
      backgroundColor: AppColors.bgPage, // Rich dark background
      body: Stack(
        children: [
          // Premium glowing background effects
          Positioned(
            top: -150,
            right: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.brand.withValues(alpha: 0.08),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            left: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kPrimaryDark.withValues(alpha: 0.08),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          FadeTransition(
            opacity: _fadeAnimation,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // 1. Header
                SliverToBoxAdapter(child: _buildHeader(isMobile)),

                // Tab Selector
                SliverToBoxAdapter(child: _buildTabSelector()),

                // 2. Category Chips
                SliverToBoxAdapter(child: _buildCategoryChips()),

                // 3. Following Topics Grid or List contents
                Obx(() {
                  if (!AuthService.to.isAuthenticated.value) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildAuthRequiredState(),
                    );
                  }

                  if (controller.isLoading.value) {
                    return SliverFillRemaining(
                      child: _buildLoadingState(isMobile, isTablet, isDesktop),
                    );
                  }

                  if (controller.errorMessage.isNotEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildErrorState(),
                    );
                  }

                  // Apply search & category filter rules locally
                  List<Topic> topics;
                  if (controller.activeTab.value == 'Favorites') {
                    topics = List<Topic>.from(controller.favoriteTopics);
                  } else {
                    topics = List<Topic>.from(controller.followedTopics);
                  }

                  // Search filter
                  if (controller.searchQuery.value.isNotEmpty) {
                    topics = topics.where((t) {
                      return t.title.toLowerCase().contains(
                        controller.searchQuery.value.toLowerCase(),
                      );
                    }).toList();
                  }

                  // Category filter
                  if (controller.selectedCategory.value != 'All') {
                    final catLower = controller.selectedCategory.value
                        .toLowerCase();
                    topics = topics.where((t) {
                      return t.category.toLowerCase() == catLower;
                    }).toList();
                  }

                  if (topics.isEmpty) {
                    if (controller.searchQuery.value.isNotEmpty) {
                      return SliverFillRemaining(
                        hasScrollBody: false,
                        child: _buildNoResultsWidget(),
                      );
                    }
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyStateWidget(context),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                    sliver: _buildSavedGrid(
                      topics,
                      widget.isDashboard,
                      isMobile,
                      isTablet,
                      isDesktop,
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 56, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Obx(
            () => controller.isSearchExpanded.value
                ? Expanded(
                    child: Container(
                      height: 48,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppColors.brand.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.brand.withValues(alpha: 0.1),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: TextField(
                            controller: _searchController,
                            style: AppTextStyles.inputText.copyWith(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search followed topics...',
                              hintStyle: AppTextStyles.inputHint.copyWith(
                                color: Colors.white.withValues(alpha: 0.4),
                              ),
                              prefixIcon: const Icon(
                                Icons.search,
                                color: AppColors.brand,
                                size: 22,
                              ),
                              suffixIcon: IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white70,
                                  size: 20,
                                ),
                                onPressed: () {
                                  controller.isSearchExpanded.value = false;
                                  _searchController.clear();
                                  controller.updateSearchQuery('');
                                },
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                : Row(
                    children: [
                      if (!widget.isDashboard) ...[
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Get.back(),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Following Topics',
                            style: AppTextStyles.displaySmall.copyWith(
                              fontSize: 36,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.5,
                              foreground: Paint()
                                ..shader = const LinearGradient(
                                  colors: [Colors.white, Color(0xFFE0E0E0)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ).createShader(const Rect.fromLTWH(0, 0, 200, 40)),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Your curated knowledge base',
                            style: AppTextStyles.labelLarge.copyWith(
                              color: AppColors.brand.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
          Row(
            children: [
              Obx(
                () => !controller.isSearchExpanded.value
                    ? Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.search, color: Colors.white),
                          onPressed: () =>
                              controller.isSearchExpanded.value = true,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  onPressed: _refreshFollowingTopics,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          _buildTabItem('Following', Icons.person_add_alt_1_rounded),
          _buildTabItem('Favorites', Icons.favorite_rounded),
        ],
      ),
    );
  }

  Widget _buildTabItem(String tabName, IconData icon) {
    return Obx(() {
      final isSelected = controller.activeTab.value == tabName;
      return Expanded(
        child: GestureDetector(
          onTap: () {
            controller.activeTab.value = tabName;
            controller.selectedCategory.value =
                'All'; // Reset category filter on tab switch
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.brand : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.brand.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isSelected ? Colors.white : Colors.white60,
                ),
                const SizedBox(width: 8),
                Text(
                  tabName,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: isSelected ? Colors.white : Colors.white60,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildCategoryChips() {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Obx(() {
        final List<String> categories = controller.derivedCategories;
        return ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final cat = categories[index];
            final isSelected = controller.selectedCategory.value == cat;
            return Container(
              margin: const EdgeInsets.only(right: 12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutQuart,
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [AppColors.brand, Color(0xFF00E5FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isSelected
                      ? null
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: isSelected
                        ? Colors.transparent
                        : Colors.white.withValues(alpha: 0.1),
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.brand.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => controller.setCategory(cat),
                    borderRadius: BorderRadius.circular(30),
                    splashColor: Colors.white.withValues(alpha: 0.2),
                    highlightColor: Colors.white.withValues(alpha: 0.1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      child: Text(
                        cat,
                        style: AppTextStyles.labelLarge.copyWith(
                          color: isSelected ? Colors.black : Colors.white70,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }

  Widget _buildSavedGrid(
    List<Topic> topics,
    bool isDashboard,
    bool isMobile,
    bool isTablet,
    bool isDesktop,
  ) {
    final int crossAxisCount = isMobile ? 1 : 2;
    final double childAspectRatio = 16 / 9;

    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: 16,
        mainAxisSpacing: 24,
      ),
      delegate: SliverChildBuilderDelegate((context, index) {
        final topic = topics[index];
        return TopicCardWidget(
          topic: topic,
          isDashboard: isDashboard,
          onFollowToggle: () => controller.toggleFollowTopic(topic),
        );
      }, childCount: topics.length),
    );
  }

  Widget _buildLoadingState(bool isMobile, bool isTablet, bool isDesktop) {
    final int crossAxisCount = isMobile ? 1 : 2;
    final double childAspectRatio = 16 / 9;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: childAspectRatio,
          crossAxisSpacing: 16,
          mainAxisSpacing: 24,
        ),
        itemCount: 6,
        itemBuilder: (context, index) =>
            const TopicCardWidget(topic: null, isHero: false),
      ),
    );
  }

  Widget _buildAuthRequiredState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.lock_person_rounded,
              color: Colors.white38,
              size: 80,
            ),
            const SizedBox(height: 16),
            Text(
              'Sign In Required',
              style: AppTextStyles.videoTitleLarge.copyWith(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please authenticate to follow topics and build interest graphs.',
              style: TextStyle(color: Colors.white38, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _refreshFollowingTopics,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.brand),
              child: const Text(
                'Try Again',
                style: TextStyle(color: Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyStateWidget(BuildContext context) {
    IconData icon = Icons.check_circle_outline_rounded;
    String title = "No followed topics yet";
    String description =
        "Follow dynamic semantic interest graphs and curated trends to personalize your platform feed.";
    String buttonText = "Explore Topics";
    String routeName = '/explore-topics';

    if (controller.activeTab.value == 'Favorites') {
      icon = Icons.favorite_border_rounded;
      title = "No favorite topics yet";
      description =
          "Love/like your favorite topics to automatically curate them here.";
      buttonText = "Discover Topics";
      routeName = '/explore-topics';
    } else if (controller.activeTab.value == 'Shared') {
      icon = Icons.share_rounded;
      title = "No shared topics yet";
      description =
          "Topics you share with your friends and community will be collected here.";
      buttonText = "Share a Topic";
      routeName = '/explore-topics';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.brand.withValues(alpha: 0.2),
                    kPrimaryDark.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(60),
              ),
              child: Icon(icon, size: 60, color: AppColors.brand),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: AppTextStyles.headlineSmall.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              description,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyLarge.copyWith(
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Get.toNamed(routeName),
              icon: Icon(
                icon == Icons.share_rounded ? Icons.explore_rounded : icon,
                color: Colors.black,
                size: 18,
              ),
              label: Text(
                buttonText,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: kDarksurfaceContainerHighest,
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 50,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "No topics found",
              style: AppTextStyles.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Try adjusting your search terms",
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
