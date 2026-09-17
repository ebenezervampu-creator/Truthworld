import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/ai/models/ai_search_intent.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/discover/presentation/controllers/discover_channels_controller.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/search/presentation/widgets/search_widgets.dart';
import 'package:truthworld/features/search/presentation/widgets/voice_search_dialog.dart';
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
              12,
            ),
            child: _buildSearchBar(context, isMobile: isMobile),
          ),
        ),


        // Active AI Query & Intent Banner (when AI search is active)
        SliverToBoxAdapter(
          child: Obx(() {
            if (_controller.activeAiIntent.value == null) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: EdgeInsets.fromLTRB(
                padding.left,
                0,
                padding.right,
                16,
              ),
              child: _buildActiveAiQueryBanner(context),
            );
          }),
        ),

        // Categories Header / Grid
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: padding.left),
          sliver: Obx(() {
            if (_controller.searchQuery.value.trim().isNotEmpty) {
              return const SliverToBoxAdapter(child: SizedBox.shrink());
            }
            return _controller.selectedCategory.value == 'All'
                ? _buildCategoryGrid(
                    context,
                    isDesktop: isDesktop,
                    isTablet: isTablet,
                  )
                : _buildSelectedCategoryHeader(context);
          }),
        ),

        // Channels List
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            padding.left,
            16,
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

            return SliverList(
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

  Widget _buildSearchBar(BuildContext context, {bool isMobile = false}) {
    return Container(
      decoration: BoxDecoration(
        color: buttonBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.12),
        ),
      ),
      child: TextField(
        controller: _controller.searchController,
        inputFormatters: [TruthworldTextInputFormatters.englishOnly],
        onChanged: _controller.onSearchChanged,
        style: const TextStyle(
          color: primaryText,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          hintText: isMobile
              ? 'Ask AI (e.g. "Top verified science", "AI robotics", "Investigative news")...'
              : 'Ask AI or search channels (e.g. "Top verified science educators", "Emerging AI & robotics creators")...',
          hintStyle: const TextStyle(
            color: secondaryText,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: const Icon(
            Icons.auto_awesome_rounded,
            color: AppColors.textPrimary,
            size: 20,
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.mic_rounded,
                  color: AppColors.textPrimary,
                  size: 20,
                ),
                tooltip: 'Voice Search',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Get.dialog(
                    VoiceSearchDialog(
                      onSearch: (query) {
                        _controller.searchController.text = query;
                        _controller.onSearchChanged(query);
                      },
                    ),
                  );
                },
              ),
              Obx(
                () => _controller.searchQuery.value.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear_rounded,
                          color: AppColors.textPrimary,
                          size: 18,
                        ),
                        tooltip: 'Clear',
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          _controller.clearAiSearch();
                        },
                      )
                    : const SizedBox.shrink(),
              ),
            ],
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


  Widget _buildActiveAiQueryBanner(BuildContext context) {
    final intent = _controller.activeAiIntent.value!;
    final matchCount = _controller.channels.length;
    final isBroadened = _controller.isBroadenedView.value;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.textPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.textPrimary,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isBroadened
                          ? 'Showing broadened Christian channels across languages'
                          : (intent.explanation.isNotEmpty
                              ? intent.explanation
                              : 'AI Search Active'),
                      style: const TextStyle(
                        color: primaryText,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$matchCount channels found • Mode: ${intent.resultMode == SearchResultMode.exhaustive ? "All Channels" : "Top Ranked"}',
                      style: const TextStyle(
                        color: secondaryText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppColors.textPrimary,
                  size: 18,
                ),
                tooltip: 'Clear AI Search',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _controller.clearAiSearch();
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (intent.detectedLanguage != null)
                _buildCriterionChip(
                  label: intent.detectedLanguage!,
                  icon: Icons.language_rounded,
                ),
              if (intent.detectedCategory != null)
                _buildCriterionChip(
                  label: intent.detectedCategory!,
                  icon: Icons.category_rounded,
                ),
              if (intent.cleanKeywords.isNotEmpty)
                ...intent.cleanKeywords.map(
                  (k) => _buildCriterionChip(
                    label: k,
                    icon: Icons.tag_rounded,
                  ),
                ),
              if (intent.resultMode == SearchResultMode.exhaustive)
                _buildCriterionChip(
                  label: 'Exhaustive / All',
                  icon: Icons.all_inclusive_rounded,
                ),
            ],
          ),
          // Fallback broadening suggestion when language-specific count is low
          if (_controller.broadenedChannels.isNotEmpty && !isBroadened) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: buttonBg.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.travel_explore_rounded,
                    color: AppColors.textPrimary,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Found only $matchCount ${intent.detectedLanguage} channels. Broaden search?',
                      style: const TextStyle(
                        color: secondaryText,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _controller.broadenSearch();
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Show All Christian Channels',
                      style: TextStyle(
                        color: primaryText,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCriterionChip({required String label, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: buttonBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.textPrimary, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: primaryText,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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
      child: Container(
        height: 110,
        margin: const EdgeInsets.only(bottom: 8),
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
    );
  }

  Widget _buildChannelCard(BuildContext context, Channel channel) {
    final subscriberCount = _controller.getSubscriberCount(channel);
    final handleText = channel.handle.isNotEmpty
        ? (channel.handle.startsWith('@')
            ? channel.handle
            : '@${channel.handle}')
        : '@${channel.name.toLowerCase().replaceAll(RegExp(r'\s+'), '')}';

    final screenWidth = MediaQuery.sizeOf(context).width;
    final avatarSize = screenWidth < 380 ? 56.0 : (screenWidth < 600 ? 68.0 : 80.0);
    final avatarGap = screenWidth < 380 ? 10.0 : 16.0;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
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
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            // Circular Avatar
            ClipOval(
              child: Container(
                width: avatarSize,
                height: avatarSize,
                color: AppColors.bgSurfaceHover,
                child: channel.avatarUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: channel.avatarUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) =>
                            Container(color: AppColors.bgDivider),
                        errorWidget: (context, url, error) => Icon(
                          Icons.account_circle,
                          size: avatarSize * 0.5,
                          color: AppColors.textTertiary,
                        ),
                      )
                    : Icon(
                        Icons.account_circle,
                        size: avatarSize * 0.5,
                        color: AppColors.textTertiary,
                      ),
              ),
            ),
            SizedBox(width: avatarGap),
            // Channel Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          channel.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: primaryText,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (channel.isVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified,
                          color: Colors.white,
                          size: 16,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$handleText • ${_formatCount(subscriberCount)} subscribers',
                    style: const TextStyle(
                      color: secondaryText,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    channel.description.isNotEmpty
                        ? channel.description
                        : 'Official channel. Explore and join.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Subscribe button
            SubscribeButton(
              channelId: channel.channelId,
              channelName: channel.name,
            ),
          ],
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
              Obx(() {
                final isCategorySelected =
                    _controller.selectedCategory.value != 'All';
                final catName = _controller.selectedCategory.value;

                return Column(
                  children: [
                    Text(
                      isCategorySelected
                          ? 'No $catName channels found'
                          : 'No channels found',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: primaryText,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isCategorySelected
                          ? 'There are currently no active channels in $catName. Check back soon or explore other categories.'
                          : 'Try adjusting your search query to discover new creators.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, color: secondaryText),
                    ),
                    const SizedBox(height: 28),
                    OutlinedButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _controller.clearSearch();
                        _controller.selectCategory('All');
                      },
                      icon: Icon(
                        isCategorySelected
                            ? Icons.explore_rounded
                            : Icons.refresh_rounded,
                        size: 18,
                        color: primaryText,
                      ),
                      label: Text(
                        isCategorySelected
                            ? 'Explore All Categories'
                            : 'Explore All Channels',
                        style: const TextStyle(
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
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  String _getCategoryImage(String category) {
    switch (category.toLowerCase().trim()) {
      case 'education':
        return 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?auto=format&fit=crop&w=400&q=75';
      case 'entertainment':
        return 'https://images.unsplash.com/photo-1607604276583-eef5d076aa5f?auto=format&fit=crop&w=400&q=75';
      case 'music':
        return 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?auto=format&fit=crop&w=400&q=75';
      case 'news':
        return 'https://images.unsplash.com/photo-1504711434969-e33886168f5c?auto=format&fit=crop&w=400&q=75';
      case 'geopolitics':
        return 'https://images.unsplash.com/photo-1529107386315-e1a2ed48a620?auto=format&fit=crop&w=400&q=75';
      case 'sports':
        return 'https://images.unsplash.com/photo-1476480862126-209bfaa8edc8?auto=format&fit=crop&w=400&q=75';
      case 'technology':
      case 'ai & tech':
        return 'https://images.unsplash.com/photo-1526374965328-7f61d4dc18c5?auto=format&fit=crop&w=400&q=75';
      case 'science':
      case 'deep research':
        return 'https://images.unsplash.com/photo-1507668077129-56e32842fceb?auto=format&fit=crop&w=400&q=75';
      case 'travel':
        return 'https://images.unsplash.com/photo-1488646953014-85cb44e25828?auto=format&fit=crop&w=400&q=75';
      case 'lifestyle':
        return 'https://images.unsplash.com/photo-1511556532299-8f662fc26c06?auto=format&fit=crop&w=400&q=75';
      case 'comedy':
        return 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?auto=format&fit=crop&w=400&q=75';
      case 'documentary':
        return 'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?auto=format&fit=crop&w=400&q=75';
      case 'movies':
        return 'https://images.unsplash.com/photo-1517604931442-7e0c8ed2963c?auto=format&fit=crop&w=400&q=75';
      case 'tv shows':
        return 'https://images.unsplash.com/photo-1593784991095-a205069470b6?auto=format&fit=crop&w=400&q=75';
      case 'vlogs':
        return 'https://images.unsplash.com/photo-1492691527719-9d1e07e534b4?auto=format&fit=crop&w=400&q=75';
      case 'diy & how-to':
      case 'diy':
        return 'https://images.unsplash.com/photo-1530124560676-10551fa77c2a?auto=format&fit=crop&w=400&q=75';
      case 'health & fitness':
      case 'fitness':
      case 'health':
        return 'https://images.unsplash.com/photo-1517838277536-f5f99be501cd?auto=format&fit=crop&w=400&q=75';
      case 'fashion':
      case 'fashion & beauty':
        return 'https://images.unsplash.com/photo-1490481651871-ab68de25d43d?auto=format&fit=crop&w=400&q=75';
      case 'food & cooking':
      case 'food':
        return 'https://images.unsplash.com/photo-1498837167922-ddd27525d352?auto=format&fit=crop&w=400&q=75';
      case 'business & finance':
      case 'business':
      case 'finance':
      case 'economics':
        return 'https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?auto=format&fit=crop&w=400&q=75';
      case 'gaming':
        return 'https://images.unsplash.com/photo-1538481199705-c710c4e965fc?auto=format&fit=crop&w=400&q=75';
      case 'art':
      case 'art & design':
        return 'https://images.unsplash.com/photo-1460661419201-fd4cecdf8a8b?auto=format&fit=crop&w=400&q=75';
      case 'automotive':
        return 'https://images.unsplash.com/photo-1503376780353-7e6692767b70?auto=format&fit=crop&w=400&q=75';
      case 'pets & animals':
      case 'pets':
        return 'https://images.unsplash.com/photo-1450778869180-41d0601e046e?auto=format&fit=crop&w=400&q=75';
      case 'nature':
      case 'nature & wildlife':
        return 'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?auto=format&fit=crop&w=400&q=75';
      case 'history':
        return 'https://images.unsplash.com/photo-1447069387593-a5de0862481e?auto=format&fit=crop&w=400&q=75';
      case 'beauty':
        return 'https://images.unsplash.com/photo-1522335789203-aabd1fc54bc9?auto=format&fit=crop&w=400&q=75';
      case 'spirituality':
        return 'https://images.unsplash.com/photo-1518241353330-0f7941c2d9b5?auto=format&fit=crop&w=400&q=75';
      case 'kids & family':
        return 'https://images.unsplash.com/photo-1536640712-4d4c36ff0e4e?auto=format&fit=crop&w=400&q=75';
      default:
        return 'https://images.unsplash.com/photo-1451187580459-43490279c0fa?auto=format&fit=crop&w=400&q=75';
    }
  }
}
