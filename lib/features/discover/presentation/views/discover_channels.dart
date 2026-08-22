import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/discover/presentation/controllers/discover_channels_controller.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

// ==========================================================================
// YOUTUBE-STYLE THEME COLORS (Exact Library Screen Palette)
// ==========================================================================

const Color bgColor = AppColors.bgPage;
const Color surfaceColor = AppColors.bgPage;
const Color cardColor = Color(0xFF1E1E1E);
const Color primaryText = AppColors.textPrimary;
const Color secondaryText = AppColors.textSecondary;
const Color accentColor = AppColors.textPrimary;
const Color buttonBg = AppColors.bgSurfaceHover;

// ==========================================================================
// RESPONSIVE BREAKPOINTS
// ==========================================================================

const double kMobileBreakpoint = 600;
const double kTabletBreakpoint = 1000;
const double kDesktopBreakpoint = 1200;

// ==========================================================================
// MODERNIZED DISCOVER CHANNELS PAGE
// ==========================================================================

class DiscoverChannelsPage extends StatefulWidget {
  const DiscoverChannelsPage({super.key, this.isDashboard = false});
  final bool isDashboard;

  @override
  State<DiscoverChannelsPage> createState() => _DiscoverChannelsPageState();
}

class _DiscoverChannelsPageState extends State<DiscoverChannelsPage>
    with TickerProviderStateMixin {
  late final DiscoverChannelsController _controller;

  late AnimationController _fadeAnimationController;
  late AnimationController _slideAnimationController;
  late AnimationController _scaleAnimationController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = Get.isRegistered<DiscoverChannelsController>()
        ? Get.find<DiscoverChannelsController>()
        : Get.put(DiscoverChannelsController());

    _initializeAnimations();
  }

  void _initializeAnimations() {
    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _fadeAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _slideAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _scaleAnimation = Tween<double>(begin: 0.98, end: 1).animate(
      CurvedAnimation(
        parent: _scaleAnimationController,
        curve: Curves.easeOutBack,
      ),
    );

    _fadeAnimationController.forward();
    _slideAnimationController.forward();
    _scaleAnimationController.forward();
  }

  @override
  void dispose() {
    _fadeAnimationController.dispose();
    _slideAnimationController.dispose();
    _scaleAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: _buildResponsiveLayout(context),
            ),
          ),
        );
      },
    );
  }

  Widget _buildResponsiveLayout(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= kDesktopBreakpoint;
        final isTablet =
            constraints.maxWidth >= kMobileBreakpoint &&
            constraints.maxWidth < kDesktopBreakpoint;

        if (isDesktop) {
          return _buildDesktopLayout(context);
        } else if (isTablet) {
          return _buildTabletLayout(context);
        } else {
          return _buildMobileLayout(context);
        }
      },
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: !widget.isDashboard
          ? _buildModernAppBar(context, isDesktop: true)
          : null,
      body: SafeArea(
        child: _buildMainContent(
          context,
          isDesktop: true,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        ),
      ),
    );
  }

  Widget _buildTabletLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: !widget.isDashboard
          ? _buildModernAppBar(context, isTablet: true)
          : null,
      body: SafeArea(
        child: _buildMainContent(
          context,
          isTablet: true,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: !widget.isDashboard ? _buildModernAppBar(context) : null,
      body: SafeArea(
        child: _buildMainContent(
          context,
          isMobile: true,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildModernAppBar(
    BuildContext context, {
    bool isDesktop = false,
    bool isTablet = false,
  }) {
    return AppBar(
      backgroundColor: surfaceColor.withValues(alpha: 0.95),
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
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
              color: AppColors.textPrimary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Discover Channels',
            style: TextStyle(
              fontSize: (isDesktop || isTablet) ? 24 : 20,
              fontWeight: FontWeight.bold,
              color: primaryText,
            ),
          ),
        ],
      ),
      actions: [
        _buildAppBarAction(
          icon: Icons.refresh_rounded,
          onPressed: () {
            HapticFeedback.lightImpact();
            _controller.loadChannels();
          },
          tooltip: 'Refresh Channels',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildAppBarAction({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Material(
        color: buttonBg.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: AppColors.textPrimary, size: 22),
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent(
    BuildContext context, {
    required EdgeInsets padding,
    bool isDesktop = false,
    bool isTablet = false,
    bool isMobile = false,
  }) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Top Header in Dashboard Mode
        if (widget.isDashboard)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                padding.left,
                16,
                padding.right,
                20,
              ),
              child: Row(
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
                      color: AppColors.textPrimary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Discover Channels',
                    style: TextStyle(
                      fontSize: (isDesktop || isTablet) ? 26 : 22,
                      fontWeight: FontWeight.bold,
                      color: primaryText,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Search Bar
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              padding.left,
              widget.isDashboard ? 0 : 8,
              padding.right,
              16,
            ),
            child: _buildSearchBar(context),
          ),
        ),

        // Categories Header / Grid
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: padding.left),
          sliver: Obx(
            () => _controller.selectedCategory.value == 'All'
                ? _buildCategoryGrid(
                    context,
                    isDesktop: isDesktop,
                    isTablet: isTablet,
                  )
                : _buildSelectedCategoryHeader(context),
          ),
        ),

        // Filter Bar (Sort, Topics, Languages)
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              padding.left,
              16,
              padding.right,
              16,
            ),
            child: _buildFilterBar(context),
          ),
        ),

        // Channels List / Grid
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            padding.left,
            0,
            padding.right,
            32,
          ),
          sliver: Obx(() {
            if (_controller.isLoading) {
              return const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(
                    color: primaryText,
                  ),
                ),
              );
            }

            if (_controller.channels.isEmpty) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(context),
              );
            }

            final crossAxisCount = _getCrossAxisCount(
              isDesktop: isDesktop,
              isTablet: isTablet,
            );
            final childAspectRatio = isMobile
                ? 0.72
                : (isTablet ? 0.76 : 0.80);

            return SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: childAspectRatio,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final channel = _controller.channels[index];
                  return _buildChannelCard(context, channel);
                },
                childCount: _controller.channels.length,
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: buttonBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.08),
        ),
      ),
      child: TextField(
        controller: _controller.searchController,
        onChanged: _controller.onSearchChanged,
        style: const TextStyle(
          color: primaryText,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          hintText: 'Search channels by name, topic, or keyword...',
          hintStyle: const TextStyle(
            color: secondaryText,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: secondaryText,
            size: 20,
          ),
          suffixIcon: Obx(
            () => _controller.searchQuery.value.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      Icons.clear_rounded,
                      color: secondaryText,
                      size: 18,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _controller.clearSearch();
                    },
                  )
                : const SizedBox.shrink(),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryGrid(
    BuildContext context, {
    bool isDesktop = false,
    bool isTablet = false,
  }) {
    final crossAxisCount = isDesktop ? 4 : (isTablet ? 3 : 2);

    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 1.6,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final category = _controller.categories[index + 1]; // Skip 'All'
          return _buildCategoryCard(context, category);
        },
        childCount: _controller.categories.length - 1,
      ),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context,
    Map<String, dynamic> category,
  ) {
    final catName = category['name'] as String;
    final imageUrl = _getCategoryImage(catName);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.08),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            _controller.selectCategory(catName);
          },
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(color: buttonBg),
                errorWidget: (context, url, error) =>
                    Container(color: buttonBg),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      AppColors.bgPage.withValues(alpha: 0.85),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    catName,
                    style: const TextStyle(
                      color: primaryText,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Colors.black87,
                          offset: Offset(0, 1),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedCategoryHeader(BuildContext context) {
    final selectedCat = _controller.selectedCategory.value;
    final catImage = _getCategoryImage(selectedCat);

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner
          Container(
            height: 110,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.textPrimary.withValues(alpha: 0.08),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: catImage,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(color: buttonBg),
                  errorWidget: (context, url, error) =>
                      Container(color: buttonBg),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.bgPage.withValues(alpha: 0.9),
                        AppColors.bgPage.withValues(alpha: 0.45),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Material(
                        color: buttonBg.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _controller.selectCategory('All');
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            child: const Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selectedCat,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: primaryText,
                                shadows: [
                                  Shadow(
                                    color: Colors.black87,
                                    offset: Offset(0, 1),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Exploring $selectedCat channels',
                              style: const TextStyle(
                                fontSize: 13,
                                color: secondaryText,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Category pill selector
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: _controller.categories.map((cat) {
                  final catName = cat['name'] as String;
                  final isSelected =
                      selectedCat.toLowerCase() == catName.toLowerCase();
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildChip(
                      label: catName,
                      isSelected: isSelected,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _controller.selectCategory(catName);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Widget? prefix,
  }) {
    return Material(
      color: isSelected ? primaryText : buttonBg,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: isSelected
                ? null
                : Border.all(
                    color: AppColors.textPrimary.withValues(alpha: 0.08),
                  ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (prefix != null) ...[
                prefix,
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? bgColor : secondaryText,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          // Sort / Status Filters
          ..._controller.filters.map((filter) {
            return Obx(() {
              final isSelected = _controller.selectedFilter.value == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _buildChip(
                  label: filter,
                  isSelected: isSelected,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _controller.selectFilter(filter);
                  },
                ),
              );
            });
          }),

          // Divider 1
          Container(
            height: 20,
            width: 1,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: AppColors.bgDivider,
          ),

          // Topic Hashtags
          ..._controller.nicheTopics.map((topicItem) {
            final topicName = topicItem['name']!;
            final displayLabel =
                topicName == 'All Topics' ? 'All Topics' : '#$topicName';

            return Obx(() {
              final isSelected = _controller.selectedTopic.value == topicName;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _buildChip(
                  label: displayLabel,
                  isSelected: isSelected,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _controller.selectTopic(topicName);
                  },
                ),
              );
            });
          }),

          // Divider 2
          Container(
            height: 20,
            width: 1,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: AppColors.bgDivider,
          ),

          // Language Chips
          ..._controller.languages.map((lang) {
            return Obx(() {
              final isSelected = _controller.selectedLanguage.value == lang;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _buildChip(
                  label: lang,
                  isSelected: isSelected,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _controller.selectLanguage(lang);
                  },
                ),
              );
            });
          }),
        ],
      ),
    );
  }

  Widget _buildChannelCard(BuildContext context, Channel channel) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            if (widget.isDashboard && Get.isRegistered<HomeController>()) {
              Get.find<HomeController>().navigateToChannelDetail(channel);
            } else {
              Get.toNamed(
                channel.channelRoute,
                arguments: {'channel': channel},
              );
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Banner & Stacked Avatar
              SizedBox(
                height: 96,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: [
                    // Banner Header
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 64,
                      child: channel.bannerUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: channel.bannerUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) =>
                                  Container(color: buttonBg),
                              errorWidget: (context, url, error) => Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.bgSurface,
                                      AppColors.bgSurfaceHover,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.bgSurface,
                                    AppColors.bgSurfaceHover,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                            ),
                    ),
                    // Stacked Avatar
                    Positioned(
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: cardColor,
                          shape: BoxShape.circle,
                        ),
                        child: UserAvatar(
                          radius: 28,
                          photoUrl: channel.avatarUrl,
                          displayName: channel.name,
                          backgroundColor: buttonBg,
                          textColor: primaryText,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Channel Info & Action Button
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              channel.name,
                              style: const TextStyle(
                                color: primaryText,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (channel.isVerified)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(
                                Icons.verified,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        channel.handle.isNotEmpty
                            ? channel.handle
                            : '@${channel.name.toLowerCase().replaceAll(RegExp(r'\s+'), '')}',
                        style: const TextStyle(
                          color: secondaryText,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Obx(() {
                        final subscriberCount =
                            _controller.getSubscriberCount(channel);
                        return Text(
                          '${_formatCount(subscriberCount)} subscribers',
                          style: const TextStyle(
                            color: secondaryText,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      }),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        height: 36,
                        child: Obx(() {
                          final isSubscribed =
                              _controller.isSubscribed(channel.channelId);

                          return ElevatedButton(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              _controller.toggleSubscription(channel);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  isSubscribed ? buttonBg : primaryText,
                              foregroundColor:
                                  isSubscribed ? secondaryText : bgColor,
                              elevation: 0,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                                side: isSubscribed
                                    ? BorderSide(
                                        color: AppColors.textPrimary
                                            .withValues(alpha: 0.15),
                                      )
                                    : BorderSide.none,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (isSubscribed) ...[
                                  const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 15,
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                Text(
                                  isSubscribed ? 'Subscribed' : 'Subscribe',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSubscribed
                                        ? FontWeight.w600
                                        : FontWeight.bold,
                                    color: isSubscribed
                                        ? secondaryText
                                        : bgColor,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 450),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: buttonBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.textPrimary.withValues(alpha: 0.1),
                    width: 2,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.explore_off_outlined,
                    color: primaryText,
                    size: 50,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'No channels found',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: primaryText,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Try adjusting your search query or reset your filters to discover new creators.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: secondaryText),
              ),
              const SizedBox(height: 28),
              OutlinedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _controller.clearSearch();
                  _controller.selectCategory('All');
                  _controller.selectTopic('All Topics');
                  _controller.selectLanguage('All Languages');
                  _controller.selectFilter('Top Channels');
                },
                icon: const Icon(
                  Icons.refresh_rounded,
                  size: 18,
                  color: primaryText,
                ),
                label: const Text(
                  'Reset Filters',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: primaryText,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: buttonBg,
                  side: BorderSide(
                    color: AppColors.textPrimary.withValues(alpha: 0.1),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _getCrossAxisCount({bool isDesktop = false, bool isTablet = false}) {
    if (isDesktop) return 4;
    if (isTablet) return 3;
    return 2;
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  String _getCategoryImage(String category) {
    switch (category.toLowerCase().trim()) {
      case 'education':
        return 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?q=80&w=1000&auto=format&fit=crop';
      case 'entertainment':
        return 'https://images.unsplash.com/photo-1607604276583-eef5d076aa5f?q=80&w=1000&auto=format&fit=crop';
      case 'music':
        return 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?q=80&w=1000&auto=format&fit=crop';
      case 'news':
        return 'https://images.unsplash.com/photo-1504711434969-e33886168f5c?q=80&w=1000&auto=format&fit=crop';
      case 'geopolitics':
        return 'https://images.unsplash.com/photo-1529107386315-e1a2ed48a620?q=80&w=1000&auto=format&fit=crop';
      case 'sports':
        return 'https://images.unsplash.com/photo-1476480862126-209bfaa8edc8?q=80&w=1000&auto=format&fit=crop';
      case 'technology':
      case 'ai & tech':
        return 'https://images.unsplash.com/photo-1526374965328-7f61d4dc18c5?q=80&w=1000&auto=format&fit=crop';
      case 'science':
      case 'deep research':
        return 'https://images.unsplash.com/photo-1507668077129-56e32842fceb?q=80&w=1000&auto=format&fit=crop';
      case 'travel':
        return 'https://images.unsplash.com/photo-1488646953014-85cb44e25828?q=80&w=1000&auto=format&fit=crop';
      case 'lifestyle':
        return 'https://images.unsplash.com/photo-1511556532299-8f662fc26c06?q=80&w=1000&auto=format&fit=crop';
      case 'comedy':
        return 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?q=80&w=1000&auto=format&fit=crop';
      case 'documentary':
        return 'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?q=80&w=1000&auto=format&fit=crop';
      case 'movies':
        return 'https://images.unsplash.com/photo-1517604931442-7e0c8ed2963c?q=80&w=1000&auto=format&fit=crop';
      case 'tv shows':
        return 'https://images.unsplash.com/photo-1593784991095-a205069470b6?q=80&w=1000&auto=format&fit=crop';
      case 'vlogs':
        return 'https://images.unsplash.com/photo-1492691527719-9d1e07e534b4?q=80&w=1000&auto=format&fit=crop';
      case 'diy & how-to':
      case 'diy':
        return 'https://images.unsplash.com/photo-1530124560676-10551fa77c2a?q=80&w=1000&auto=format&fit=crop';
      case 'health & fitness':
      case 'fitness':
      case 'health':
        return 'https://images.unsplash.com/photo-1517838277536-f5f99be501cd?q=80&w=1000&auto=format&fit=crop';
      case 'fashion':
      case 'fashion & beauty':
        return 'https://images.unsplash.com/photo-1490481651871-ab68de25d43d?q=80&w=1000&auto=format&fit=crop';
      case 'food & cooking':
      case 'food':
        return 'https://images.unsplash.com/photo-1498837167922-ddd27525d352?q=80&w=1000&auto=format&fit=crop';
      case 'business & finance':
      case 'business':
      case 'finance':
      case 'economics':
        return 'https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?q=80&w=1000&auto=format&fit=crop';
      case 'gaming':
        return 'https://images.unsplash.com/photo-1538481199705-c710c4e965fc?q=80&w=1000&auto=format&fit=crop';
      case 'art':
      case 'art & design':
        return 'https://images.unsplash.com/photo-1460661419201-fd4cecdf8a8b?q=80&w=1000&auto=format&fit=crop';
      case 'automotive':
        return 'https://images.unsplash.com/photo-1503376780353-7e6692767b70?q=80&w=1000&auto=format&fit=crop';
      case 'pets & animals':
      case 'pets':
        return 'https://images.unsplash.com/photo-1450778869180-41d0601e046e?q=80&w=1000&auto=format&fit=crop';
      case 'nature':
      case 'nature & wildlife':
        return 'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?q=80&w=1000&auto=format&fit=crop';
      case 'history':
        return 'https://images.unsplash.com/photo-1447069387593-a5de0862481e?q=80&w=1000&auto=format&fit=crop';
      case 'beauty':
        return 'https://images.unsplash.com/photo-1522335789203-aabd1fc54bc9?q=80&w=1000&auto=format&fit=crop';
      case 'spirituality':
        return 'https://images.unsplash.com/photo-1518241353330-0f7941c2d9b5?q=80&w=1000&auto=format&fit=crop';
      case 'kids & family':
        return 'https://images.unsplash.com/photo-1536640712-4d4c36ff0e4e?q=80&w=1000&auto=format&fit=crop';
      default:
        return 'https://images.unsplash.com/photo-1451187580459-43490279c0fa?q=80&w=1000&auto=format&fit=crop';
    }
  }
}
