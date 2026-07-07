import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/components/ui/video_card.dart' as app_video_card;

// ==========================================================================
// ENHANCED THEME COLORS FOR CATEGORY PAGE
// ==========================================================================
// Using global AppTheme tokens

// Category-specific accent colors
final Color musicColor = AppColors.brand; // Pink for Music
final Color entertainmentColor = Color(0xFF8B5CF6); // Purple for Entertainment
final Color educationColor = AppTokens.colors.info; // Blue for Education
final Color sportsColor = Color(0xFFF59E0B); // Orange for Sports
final Color newsColor = AppColors.textTertiary; // Blue Grey for News
final Color gamingColor = AppTokens.colors.success; // Green for Gaming

// ==========================================================================
// RESPONSIVE BREAKPOINTS
// ==========================================================================

const double kMobileBreakpoint = 600.0;
const double kTabletBreakpoint = 1000.0;
const double kDesktopBreakpoint = 1200.0;

// ==========================================================================
// CATEGORY CONTROLLER USING GETX
// ==========================================================================

class CategoryController extends GetxController {
  RxString selectedGenre = 'All'.obs;
  RxString selectedSort = 'Popularity'.obs;
  RxString selectedView = 'Grid'.obs;
  RxBool isSearchVisible = false.obs;
  RxString searchQuery = ''.obs;
  RxString debouncedSearchQuery = ''.obs;
  RxList<String> genres = <String>[].obs;
  RxBool isSearching = false.obs;

  late String category;
  Timer? _searchDebounceTimer;

  final Map<String, List<String>> _categoryToGenres = {
    'education': [
      'All',
      'Tutorials',
      'Lectures',
      'Language Learning',
      'Math & Logic',
      'Professional Development',
      'Study Tips',
      'Career Advice',
      'Science Experiments',
      'History Lessons',
      'Exam Prep',
    ],
    'entertainment': [
      'All',
      'Movies',
      'TV Shows',
      'Comedy Skits',
      'Talk Shows',
      'Celebrity News',
      'Pop Culture',
      'Behind the Scenes',
      'Fan Theories',
      'Interviews',
    ],
    'music': [
      'All',
      'Song Covers',
      'Instrument Tutorials',
      'Music Reviews',
      'Concerts',
      'Playlists',
      'Music Production',
      'Remixes',
      'Live Sessions',
      'Artist Spotlights',
    ],
    'news': [
      'All',
      'Breaking News',
      'Politics',
      'World News',
      'Business News',
      'Tech News',
      'Health News',
      'Investigative Journalism',
      'Opinion Pieces',
      'Local News',
    ],
    'sports': [
      'All',
      'Highlights',
      'Analysis',
      'Interviews',
      'Training',
      'Extreme Sports',
      'Team Sports',
      'Player Profiles',
      'Match Previews',
      'Post-Game Reviews',
    ],
    'gaming': [
      'All',
      'Walkthroughs',
      'Reviews',
      'eSports',
      'Let\'s Plays',
      'Speedruns',
      'Mods',
      'Game Development',
      'Hardware Tips',
      'Community Challenges',
    ],
    'technology': [
      'All',
      'Gadget Reviews',
      'Software Tutorials',
      'AI & Tech News',
      'Coding',
      'Web Design',
      'Engineering',
      'Cybersecurity',
      'App Development',
      'Future Tech',
    ],
    'science': [
      'All',
      'Experiments',
      'Discoveries',
      'Space',
      'Biology',
      'Physics',
      'Chemistry',
      'Environment',
      'Neuroscience',
      'Quantum Mechanics',
      'Astronomy',
    ],
    'travel': [
      'All',
      'Vlogs',
      'Guides',
      'Budget Travel',
      'Luxury',
      'Adventure',
      'Cultural',
      'Food Tours',
      'Hidden Gems',
      'Solo Travel',
    ],
    'lifestyle': [
      'All',
      'Daily Routines',
      'Advice',
      'Relationships',
      'Home & Garden',
      'Personal Development',
      'Minimalism',
      'Productivity Hacks',
      'Wellness Tips',
    ],
    'comedy': [
      'All',
      'Sketches',
      'Stand-up',
      'Pranks',
      'Parodies',
      'Satire',
      'Roasts',
      'Improv',
      'Viral Clips',
      'Reaction Videos',
    ],
    'documentary': [
      'All',
      'History',
      'Nature',
      'True Crime',
      'Biographies',
      'Social Issues',
      'Environmental',
      'Cultural',
      'War Stories',
      'Innovation',
    ],
    'movies': [
      'All',
      'Action',
      'Drama',
      'Comedy',
      'Horror',
      'Sci-Fi',
      'Romance',
      'Reviews',
      'Trailers',
      'Behind the Scenes',
      'Film Analysis',
    ],
    'tv shows': [
      'All',
      'Drama Series',
      'Reality TV',
      'Sitcoms',
      'Documentaries',
      'Talk Shows',
      'Reviews',
      'Recaps',
      'Binge Guides',
      'Casting News',
    ],
    'vlogs': [
      'All',
      'Daily Vlogs',
      'Travel Vlogs',
      'Food Vlogs',
      'Family Vlogs',
      'Challenge Vlogs',
      'Behind the Scenes',
      'Q&A Sessions',
      'Life Updates',
    ],
    'diy & how-to': [
      'All',
      'Crafts',
      'Home Improvement',
      'Cooking Hacks',
      'Tech Fixes',
      'Beauty DIY',
      'Gardening',
      'Upcycling',
      'Budget Builds',
    ],
    'health & fitness': [
      'All',
      'Workouts',
      'Yoga',
      'Nutrition',
      'Mental Health',
      'Weight Loss',
      'Cardio Routines',
      'Strength Training',
      'Recovery Tips',
    ],
    'fashion & beauty': [
      'All',
      'Makeup Tutorials',
      'Hauls',
      'Style Tips',
      'Skincare',
      'Trends',
      'Hair Styling',
      'Outfit Ideas',
      'Sustainable Fashion',
    ],
    'food & cooking': [
      'All',
      'Recipes',
      'Baking',
      'Meal Prep',
      'Reviews',
      'Culinary Travel',
      'Vegan Dishes',
      'Desserts',
      'Street Food',
    ],
    'business & finance': [
      'All',
      'Entrepreneurship',
      'Investing',
      'Money Management',
      'Marketing',
      'Case Studies',
      'Startups',
      'Crypto',
      'Real Estate',
    ],
    'animation': [
      'All',
      '2D Animation',
      '3D Animation',
      'Stop Motion',
      'Character Design',
      'Short Films',
      'Storyboarding',
      'Voice Acting',
      'Animation Tutorials',
    ],
    'short films': [
      'All',
      'Drama',
      'Comedy',
      'Horror',
      'Sci-Fi',
      'Experimental',
      'Thriller',
      'Romance',
      'Festival Winners',
    ],
    'motivation': [
      'All',
      'Speeches',
      'Success Stories',
      'Mindset',
      'Goal Setting',
      'Inspirational Quotes',
      'Overcoming Obstacles',
      'Daily Affirmations',
    ],
    'history': [
      'All',
      'Ancient History',
      'Modern History',
      'Biographies',
      'Wars',
      'Cultures',
      'Archaeology',
      'Historical Mysteries',
      'Timelines',
    ],
    'art & design': [
      'All',
      'Drawing',
      'Painting',
      'Digital Art',
      'Graphic Design',
      'Sculpture',
      'Photography',
      'Interior Design',
      'Fashion Design',
    ],
    'automotive': [
      'All',
      'Car Reviews',
      'Mods',
      'Racing',
      'Maintenance',
      'Classic Cars',
      'Electric Vehicles',
      'Auto Shows',
      'Driving Tips',
    ],
    'animals & pets': [
      'All',
      'Pet Care',
      'Training',
      'Funny Videos',
      'Rescue Stories',
      'Wildlife',
      'Exotic Pets',
      'Animal Behavior',
    ],
    'spirituality': [
      'All',
      'Meditation',
      'Yoga Philosophy',
      'Astrology',
      'Religious Teachings',
      'Self-Reflection',
      'Tarot Readings',
      'Energy Healing',
    ],
    'nature & wildlife': [
      'All',
      'Documentaries',
      'Adventures',
      'Conservation',
      'Photography',
      'Animals',
      'Hiking Guides',
      'Eco Tourism',
    ],
    'kids & family': [
      'All',
      'Stories',
      'Educational',
      'Crafts',
      'Toys',
      'Family Vlogs',
      'Parenting Tips',
      'Holiday Activities',
      'Bedtime Routines',
    ],
  };

  List<String> _getGenresForCategory(String cat) {
    return _categoryToGenres[cat.toLowerCase()] ?? ['All'];
  }

  String get sortField {
    switch (selectedSort.value) {
      case 'Popularity':
      case 'Views':
        return 'views';
      case 'Release Date':
        return 'uploadedAt';
      case 'Title':
        return 'title';
      case 'Trending':
        return 'views'; // Fallback
      default:
        return 'views';
    }
  }

  Stream<QuerySnapshot> get featuredStream {
    Query query = FirebaseFirestore.instance
        .collection('videos')
        .where('category', isEqualTo: category)
        .where('visibility', isEqualTo: 'Public');
    if (selectedGenre.value != 'All') {
      query = query.where('genre', isEqualTo: selectedGenre.value);
    }
    return query.orderBy('views', descending: true).limit(6).snapshots();
  }

  Stream<QuerySnapshot> get newReleasesStream {
    Query query = FirebaseFirestore.instance
        .collection('videos')
        .where('category', isEqualTo: category)
        .where('visibility', isEqualTo: 'Public');
    if (selectedGenre.value != 'All') {
      query = query.where('genre', isEqualTo: selectedGenre.value);
    }
    return query.orderBy('uploadedAt', descending: true).limit(12).snapshots();
  }

  Stream<QuerySnapshot> get topContentStream {
    Query query = FirebaseFirestore.instance
        .collection('videos')
        .where('category', isEqualTo: category)
        .where('visibility', isEqualTo: 'Public');
    if (selectedGenre.value != 'All') {
      query = query.where('genre', isEqualTo: selectedGenre.value);
    }
    return query.orderBy(sortField, descending: true).limit(12).snapshots();
  }

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args != null && args is Map && args.containsKey('category')) {
      category = args['category'];
    } else {
      category = 'All';
    }
    genres.value = _getGenresForCategory(category);
    selectedGenre.value = genres[0];

    // Setup debounce listener for search
    ever(searchQuery, (value) {
      isSearching.value = true;
      _searchDebounceTimer?.cancel();
      _searchDebounceTimer = Timer(Duration(milliseconds: 500), () {
        debouncedSearchQuery.value = value.toString().trim().toLowerCase();
        isSearching.value = false;
      });
    });
  }

  @override
  void onClose() {
    _searchDebounceTimer?.cancel();
    super.onClose();
  }

  void clearSearch() {
    searchQuery.value = '';
    debouncedSearchQuery.value = '';
  }
}

// ==========================================================================
// MODERNIZED CATEGORY PAGE
// ==========================================================================

class CategoryPage extends StatefulWidget {
  final bool isDashboard;
  const CategoryPage({super.key, this.isDashboard = false});

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage>
    with TickerProviderStateMixin {
  late CategoryController controller;

  late AnimationController _fadeAnimationController;
  late AnimationController _slideAnimationController;
  late AnimationController _scaleAnimationController;
  late AnimationController _heroAnimationController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _heroAnimation;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<String> sortOptions = [
    'Popularity',
    'Release Date',
    'Views',
    'Trending',
    'Duration',
    'Title',
  ];

  final List<String> viewOptions = ['Grid', 'List'];

  @override
  void initState() {
    super.initState();
    controller = Get.put(CategoryController());
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

    _heroAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0.0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _slideAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _scaleAnimationController,
        curve: Curves.easeOutBack,
      ),
    );

    _heroAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _heroAnimationController,
        curve: Curves.easeOutExpo,
      ),
    );

    // Start animations with staggered timing
    _heroAnimationController.forward();
    Future.delayed(Duration(milliseconds: 200), () {
      _fadeAnimationController.forward();
    });
    Future.delayed(Duration(milliseconds: 400), () {
      _slideAnimationController.forward();
    });
    Future.delayed(Duration(milliseconds: 600), () {
      _scaleAnimationController.forward();
    });
  }

  @override
  void dispose() {
    _fadeAnimationController.dispose();
    _slideAnimationController.dispose();
    _scaleAnimationController.dispose();
    _heroAnimationController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Color _getCategoryColor() {
    switch (controller.category.toLowerCase()) {
      case 'music':
        return musicColor;
      case 'entertainment':
        return entertainmentColor;
      case 'education':
        return educationColor;
      case 'sports':
        return sportsColor;
      case 'news':
        return newsColor;
      case 'gaming':
        return gamingColor;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  IconData _getCategoryIcon() {
    switch (controller.category.toLowerCase()) {
      case 'education':
        return Icons.school;
      case 'entertainment':
        return Icons.theater_comedy;
      case 'music':
        return Icons.music_note;
      case 'news':
        return Icons.newspaper;
      case 'sports':
        return Icons.sports_soccer;
      case 'gaming':
        return Icons.videogame_asset;
      case 'technology':
        return Icons.computer;
      case 'science':
        return Icons.science;
      case 'travel':
        return Icons.travel_explore;
      case 'lifestyle':
        return Icons.home;
      case 'comedy':
        return Icons.sentiment_very_satisfied;
      case 'documentary':
        return Icons.video_label;
      case 'movies':
        return Icons.movie;
      case 'tv shows':
        return Icons.tv;
      case 'vlogs':
        return Icons.videocam;
      case 'diy & how-to':
        return Icons.build;
      case 'health & fitness':
        return Icons.fitness_center;
      case 'fashion & beauty':
        return Icons.brush;
      case 'food & cooking':
        return Icons.restaurant;
      case 'business & finance':
        return Icons.business;
      case 'animation':
        return Icons.animation;
      case 'short films':
        return Icons.flip_camera_ios;
      case 'motivation':
        return Icons.psychology;
      case 'history':
        return Icons.history;
      case 'art & design':
        return Icons.palette;
      case 'automotive':
        return Icons.directions_car;
      case 'animals & pets':
        return Icons.pets;
      case 'spirituality':
        return Icons.self_improvement;
      case 'nature & wildlife':
        return Icons.eco;
      case 'kids & family':
        return Icons.family_restroom;
      default:
        return Icons.category;
    }
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
        final bool isDesktop = constraints.maxWidth >= kDesktopBreakpoint;
        final bool isTablet =
            constraints.maxWidth >= kMobileBreakpoint &&
            constraints.maxWidth < kDesktopBreakpoint;
        final bool isMobile = constraints.maxWidth < kMobileBreakpoint;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: widget.isDashboard ? null : null, // Handle appbar separately if needed, but for now we use sliver app bar
          body: SafeArea(
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                if (!widget.isDashboard)
                  _buildModernAppBar(
                    context,
                    isDesktop: isDesktop,
                    isTablet: isTablet,
                  ),
                SliverToBoxAdapter(
                  child: _buildMainContent(
                    context,
                    isDesktop: isDesktop,
                    isTablet: isTablet,
                    isMobile: isMobile,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModernAppBar(
    BuildContext context, {
    bool isDesktop = false,
    bool isTablet = false,
  }) {
    return SliverAppBar(
      expandedHeight: isDesktop ? 300.0 : (isTablet ? 250.0 : 200.0),
      floating: false,
      pinned: true,
      backgroundColor: Theme.of(
        context,
      ).colorScheme.surface.withValues(alpha: 0.95),
      systemOverlayStyle: SystemUiOverlayStyle.light,
      leading: Container(
        margin: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.bgSurfaceContainerHighest.withValues(
            alpha: 0.8,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => Get.back(),
        ),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getCategoryIcon(),
            size: 20,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              controller.category,
              style: GoogleFonts.roboto(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: isDesktop ? 24 : 20,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        Obx(
          () => _buildAppBarAction(
            icon: controller.isSearchVisible.value
                ? Icons.close_rounded
                : Icons.search_rounded,
            onPressed: () {
              controller.isSearchVisible.value =
                  !controller.isSearchVisible.value;
              if (!controller.isSearchVisible.value) {
                _searchController.clear();
                controller.clearSearch();
              }
            },
            tooltip: controller.isSearchVisible.value
                ? 'Close Search'
                : 'Search',
          ),
        ),
        Obx(
          () => _buildAppBarAction(
            icon: controller.selectedView.value == 'Grid'
                ? Icons.view_list_rounded
                : Icons.grid_view_rounded,
            onPressed: () {
              controller.selectedView.value =
                  controller.selectedView.value == 'Grid' ? 'List' : 'Grid';
              HapticFeedback.lightImpact();
            },
            tooltip: 'Toggle View',
          ),
        ),
        _buildAppBarAction(
          icon: Icons.filter_list_rounded,
          onPressed: () => _showFilterDialog(context),
          tooltip: 'Filter & Sort',
        ),
        SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: AnimatedBuilder(
          animation: _heroAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: 0.8 + (0.2 * _heroAnimation.value),
              child: Opacity(
                opacity: _heroAnimation.value,
                child: _buildHeroSection(
                  context,
                  isDesktop: isDesktop,
                  isTablet: isTablet,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAppBarAction({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Container(
      margin: EdgeInsets.only(right: 8),
      child: Material(
        color: AppColors.bgSurfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.all(10),
            child: Icon(
              icon,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection(
    BuildContext context, {
    bool isDesktop = false,
    bool isTablet = false,
  }) {
    final categoryColor = _getCategoryColor();

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            categoryColor.withValues(alpha: 0.8),
            categoryColor.withValues(alpha: 0.4),
            Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
          ],
          stops: [0.0, 0.6, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Background Pattern
          Positioned.fill(
            child: CustomPaint(painter: _CategoryPatternPainter(categoryColor)),
          ),
          // Content
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: categoryColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    'CATEGORY',
                    style: GoogleFonts.roboto(
                      color: categoryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                SizedBox(height: 12),
                Icon(
                  _getCategoryIcon(),
                  color: categoryColor,
                  size: isDesktop ? 48 : (isTablet ? 44 : 40),
                ),
                SizedBox(height: 12),
                Text(
                  controller.category,
                  style: GoogleFonts.roboto(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: isDesktop ? 36 : (isTablet ? 32 : 28),
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Discover the best ${controller.category.toLowerCase()} content',
                  style: GoogleFonts.roboto(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: isDesktop ? 18 : (isTablet ? 16 : 14),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(
    BuildContext context, {
    bool isDesktop = false,
    bool isTablet = false,
    bool isMobile = false,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: _getResponsiveHorizontalPadding(context),
        vertical: AppTokens.spacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Bar (if visible)
          Obx(
            () => controller.isSearchVisible.value
                ? Column(
                    children: [
                      _buildSearchBar(
                        context,
                        isDesktop: isDesktop,
                        isTablet: isTablet,
                      ),
                      SizedBox(height: AppTokens.spacing.md),
                    ],
                  )
                : SizedBox.shrink(),
          ),

          // Filter Chips
          _buildFilterChips(context, isDesktop: isDesktop, isTablet: isTablet),
          SizedBox(height: AppTokens.spacing.md),

          // Featured Content
          _buildFeaturedSection(
            context,
            isDesktop: isDesktop,
            isTablet: isTablet,
            isMobile: isMobile,
          ),
          SizedBox(height: AppTokens.spacing.md),

          // New Releases
          _buildNewReleases(
            context,
            isDesktop: isDesktop,
            isTablet: isTablet,
            isMobile: isMobile,
          ),
          SizedBox(height: AppTokens.spacing.md),

          // Top Content
          _buildTopContent(
            context,
            isDesktop: isDesktop,
            isTablet: isTablet,
            isMobile: isMobile,
          ),
          SizedBox(height: AppTokens.spacing.md),
        ],
      ),
    );
  }

  /// Get responsive horizontal padding based on screen size
  double _getResponsiveHorizontalPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= kDesktopBreakpoint) return AppTokens.spacing.lg; // 32px
    if (width >= kMobileBreakpoint) return AppTokens.spacing.md; // 24px
    return AppTokens.spacing.sm; // 16px
  }

  Widget _buildSearchBar(
    BuildContext context, {
    bool isDesktop = false,
    bool isTablet = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppTokens.radius.lg),
        border: Border.all(
          color: AppColors.bgSurfaceContainerHighest,
          width: 1,
        ),
      ),
      child: Obx(() => TextField(
        controller: _searchController,
        style: GoogleFonts.roboto(
          color: Theme.of(context).colorScheme.onSurface,
          textStyle: AppTokens.typography.body,
        ),
        onChanged: (value) {
          controller.searchQuery.value = value;
        },
        decoration: InputDecoration(
          hintText: 'Search ${controller.category.toLowerCase()} content...',
          hintStyle: GoogleFonts.roboto(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            textStyle: AppTokens.typography.body,
          ),
          prefixIcon: controller.isSearching.value
              ? Container(
                  width: 20,
                  height: 20,
                  margin: EdgeInsets.all(12),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _getCategoryColor(),
                  ),
                )
              : Icon(
                  Icons.search_rounded,
                  color: _getCategoryColor(),
                  size: AppTokens.sizes.iconMd,
                ),
          suffixIcon: controller.searchQuery.value.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear_rounded,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    controller.clearSearch();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      )),
    );
  }

  Widget _buildFilterChips(
    BuildContext context, {
    bool isDesktop = false,
    bool isTablet = false,
  }) {
    return Obx(
      () => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Genre Chips
            ...controller.genres.map(
              (genre) => Container(
                margin: EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(
                    genre,
                    style: GoogleFonts.roboto(
                      fontSize: isDesktop ? 14 : 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  selected: controller.selectedGenre.value == genre,
                  onSelected: (_) {
                    controller.selectedGenre.value = genre;
                    HapticFeedback.lightImpact();
                  },
                  backgroundColor: AppColors.bgSurfaceContainerHighest
                      .withValues(alpha: 0.3),
                  selectedColor: _getCategoryColor().withValues(alpha: 0.2),
                  checkmarkColor: _getCategoryColor(),
                  labelStyle: TextStyle(
                    color: controller.selectedGenre.value == genre
                        ? _getCategoryColor()
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  side: BorderSide(
                    color: controller.selectedGenre.value == genre
                        ? _getCategoryColor()
                        : AppColors.bgSurfaceContainerHighest,
                    width: 1,
                  ),
                ),
              ),
            ),

            // Sort Chip
            Container(
              margin: EdgeInsets.only(left: 8),
              child: ActionChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.sort_rounded,
                      size: 16,
                      color: _getCategoryColor(),
                    ),
                    SizedBox(width: 4),
                    Text(
                      controller.selectedSort.value,
                      style: GoogleFonts.roboto(
                        fontSize: isDesktop ? 14 : 13,
                        fontWeight: FontWeight.w500,
                        color: _getCategoryColor(),
                      ),
                    ),
                  ],
                ),
                onPressed: () => _showSortDialog(context),
                backgroundColor: _getCategoryColor().withValues(alpha: 0.1),
                side: BorderSide(
                  color: _getCategoryColor().withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedSection(
    BuildContext context, {
    bool isDesktop = false,
    bool isTablet = false,
    bool isMobile = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Featured Content',
          isDesktop: isDesktop,
          isTablet: isTablet,
        ),
        SizedBox(height: AppTokens.spacing.sm),
        SizedBox(
          height: isDesktop ? 200 : (isTablet ? 180 : 160),
          child: Obx(
            () => StreamBuilder<QuerySnapshot>(
              stream: controller.featuredStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildHorizontalShimmer(
                    isDesktop: isDesktop,
                    isTablet: isTablet,
                  );
                }
                if (snapshot.hasError) {
                  return _buildErrorWidget('Error loading featured content');
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyWidget('No featured content available');
                }

                List<Video> videos = snapshot.data!.docs
                    .map((doc) => Video.fromDocumentSnapshot(doc))
                    .where(
                      (video) =>
                          controller.debouncedSearchQuery.value.isEmpty ||
                          video.title.toLowerCase().contains(
                            controller.debouncedSearchQuery.value,
                          ) ||
                          video.channelName.toLowerCase().contains(
                            controller.debouncedSearchQuery.value,
                          ),
                    )
                    .toList();

                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: videos.length,
                  itemBuilder: (context, index) {
                    return _buildFeaturedCard(
                      videos[index],
                      isDesktop: isDesktop,
                      isTablet: isTablet,
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturedCard(
    Video video, {
    bool isDesktop = false,
    bool isTablet = false,
  }) {
    final cardWidth = isDesktop ? 280.0 : (isTablet ? 240.0 : 200.0);

    return Container(
      width: cardWidth,
      margin: EdgeInsets.only(right: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            Get.toNamed('/watch?v=${video.id}', arguments: {'video': video});
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.bgPage.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  // Background Image
                  CachedNetworkImage(
                    imageUrl: video.thumbnailUrl,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: AppColors.bgSurfaceContainerHighest,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: _getCategoryColor(),
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: AppColors.bgSurfaceContainerHighest,
                      child: Icon(
                        Icons.video_library_rounded,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        size: 40,
                      ),
                    ),
                  ),

                  // Gradient Overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          AppColors.bgPage.withValues(alpha: 0.7),
                        ],
                        stops: [0.5, 1.0],
                      ),
                    ),
                  ),

                  // Content Info
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          video.title,
                          style: GoogleFonts.roboto(
                            color: AppColors.textPrimary,
                            fontSize: isDesktop ? 16 : 14,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Text(
                          video.channelName,
                          style: GoogleFonts.roboto(
                            color: AppColors.textPrimary.withValues(
                              alpha: 0.8,
                            ),
                            fontSize: isDesktop ? 14 : 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Text(
                          '${_formatViews(video.views)} views',
                          style: GoogleFonts.roboto(
                            color: AppColors.textPrimary.withValues(
                              alpha: 0.7,
                            ),
                            fontSize: isDesktop ? 12 : 11,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Duration Badge
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.bgPage.withValues(
                          alpha: 0.8,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        video.duration,
                        style: GoogleFonts.roboto(
                          color: AppColors.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNewReleases(
    BuildContext context, {
    bool isDesktop = false,
    bool isTablet = false,
    bool isMobile = false,
  }) {
    final int gridLimit = isDesktop ? 8 : (isTablet ? 6 : 4);
    final int listLimit = 10;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'New Releases',
          isDesktop: isDesktop,
          isTablet: isTablet,
        ),
        SizedBox(height: AppTokens.spacing.sm),
        Obx(
          () => StreamBuilder<QuerySnapshot>(
            stream: controller.newReleasesStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return controller.selectedView.value == 'Grid'
                    ? _buildVideoGridShimmer(
                        isDesktop: isDesktop,
                        isTablet: isTablet,
                        isMobile: isMobile,
                      )
                    : _buildVideoListShimmer();
              }
              if (snapshot.hasError) {
                return _buildErrorWidget(
                  'Error loading new releases: ${snapshot.error}',
                );
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _buildEmptyWidget('No new releases found');
              }

              List<Video> videos = snapshot.data!.docs
                  .map((doc) => Video.fromDocumentSnapshot(doc))
                  .where(
                    (video) =>
                        controller.debouncedSearchQuery.value.isEmpty ||
                        video.title.toLowerCase().contains(
                          controller.debouncedSearchQuery.value,
                        ) ||
                        video.channelName.toLowerCase().contains(
                          controller.debouncedSearchQuery.value,
                        ),
                  )
                  .toList();

              final int takeLimit = controller.selectedView.value == 'Grid'
                  ? gridLimit
                  : listLimit;
              videos = videos.take(takeLimit).toList();

              return controller.selectedView.value == 'Grid'
                  ? _buildVideoGridWithCard(
                      videos,
                      isDesktop: isDesktop,
                      isTablet: isTablet,
                      isMobile: isMobile,
                    )
                  : _buildVideoListWithCard(
                      videos,
                      isDesktop: isDesktop,
                      isTablet: isTablet,
                    );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTopContent(
    BuildContext context, {
    bool isDesktop = false,
    bool isTablet = false,
    bool isMobile = false,
  }) {
    final int gridLimit = isDesktop ? 8 : (isTablet ? 6 : 4);
    final int listLimit = 10;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Top ${controller.category}',
          isDesktop: isDesktop,
          isTablet: isTablet,
        ),
        SizedBox(height: AppTokens.spacing.sm),
        Obx(
          () => StreamBuilder<QuerySnapshot>(
            stream: controller.topContentStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return controller.selectedView.value == 'Grid'
                    ? _buildVideoGridShimmer(
                        isDesktop: isDesktop,
                        isTablet: isTablet,
                        isMobile: isMobile,
                      )
                    : _buildVideoListShimmer();
              }
              if (snapshot.hasError) {
                return _buildErrorWidget(
                  'Error loading top content: ${snapshot.error}',
                );
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _buildEmptyWidget('No top content found');
              }

              List<Video> videos = snapshot.data!.docs
                  .map((doc) => Video.fromDocumentSnapshot(doc))
                  .where(
                    (video) =>
                        controller.debouncedSearchQuery.value.isEmpty ||
                        video.title.toLowerCase().contains(
                          controller.debouncedSearchQuery.value,
                        ) ||
                        video.channelName.toLowerCase().contains(
                          controller.debouncedSearchQuery.value,
                        ),
                  )
                  .toList();

              final int takeLimit = controller.selectedView.value == 'Grid'
                  ? gridLimit
                  : listLimit;
              videos = videos.take(takeLimit).toList();

              return controller.selectedView.value == 'Grid'
                  ? _buildVideoGridWithCard(
                      videos,
                      isDesktop: isDesktop,
                      isTablet: isTablet,
                      isMobile: isMobile,
                    )
                  : _buildVideoListWithCard(
                      videos,
                      isDesktop: isDesktop,
                      isTablet: isTablet,
                    );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVideoGridWithCard(
    List<Video> videos, {
    bool isDesktop = false,
    bool isTablet = false,
    bool isMobile = false,
  }) {
    int crossAxisCount = isDesktop ? 4 : (isTablet ? 3 : 2);
    // Higher aspect ratio = shorter cards (more compact)
    double childAspectRatio = isDesktop ? 1.1 : (isTablet ? 1.0 : 0.95);

    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16, // Reduced spacing
        childAspectRatio: childAspectRatio,
      ),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        return app_video_card.VideoCard(
          video: videos[index],
          isGrid: true,
          heroPrefix: 'category_grid',
        );
      },
    );
  }

  Widget _buildVideoListWithCard(
    List<Video> videos, {
    bool isDesktop = false,
    bool isTablet = false,
  }) {
    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        return app_video_card.VideoCard(
          video: videos[index],
          isGrid: false,
          heroPrefix: 'category_list',
        );
      },
    );
  }

  Widget _buildSectionHeader(
    String title, {
    bool isDesktop = false,
    bool isTablet = false,
  }) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: _getCategoryColor(),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: 12),
        Text(
          title,
          style: GoogleFonts.roboto(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: isDesktop ? 24 : (isTablet ? 22 : 20),
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // Shimmer Loading States
  Widget _buildVideoGridShimmer({
    bool isDesktop = false,
    bool isTablet = false,
    bool isMobile = false,
  }) {
    int crossAxisCount = isDesktop ? 4 : (isTablet ? 3 : 2);
    double childAspectRatio = isDesktop ? 1.1 : (isTablet ? 1.0 : 0.95);

    return Shimmer.fromColors(
      baseColor: AppColors.bgSurfaceContainerHighest.withValues(
        alpha: 0.3,
      ),
      highlightColor: AppColors.bgSurfaceContainerHighest.withValues(
        alpha: 0.1,
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: childAspectRatio,
        ),
        itemCount: 8,
        itemBuilder: (context, index) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              SizedBox(height: 8),
              Container(
                height: 16,
                width: double.infinity,
                color: AppColors.textPrimary,
              ),
              SizedBox(height: 4),
              Container(
                height: 14,
                width: 100,
                color: AppColors.textPrimary,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildVideoListShimmer() {
    return Shimmer.fromColors(
      baseColor: AppColors.bgSurfaceContainerHighest.withValues(
        alpha: 0.3,
      ),
      highlightColor: AppColors.bgSurfaceContainerHighest.withValues(
        alpha: 0.1,
      ),
      child: ListView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        itemCount: 5,
        itemBuilder: (context, index) {
          return Container(
            margin: EdgeInsets.only(bottom: 16),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.textPrimary,
              borderRadius: BorderRadius.circular(16),
            ),
            height: 100,
          );
        },
      ),
    );
  }

  Widget _buildHorizontalShimmer({
    bool isDesktop = false,
    bool isTablet = false,
  }) {
    return Shimmer.fromColors(
      baseColor: AppColors.bgSurfaceContainerHighest.withValues(
        alpha: 0.3,
      ),
      highlightColor: AppColors.bgSurfaceContainerHighest.withValues(
        alpha: 0.1,
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 4,
        itemBuilder: (context, index) {
          return Container(
            width: isDesktop ? 280 : (isTablet ? 240 : 200),
            margin: EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: AppColors.textPrimary,
              borderRadius: BorderRadius.circular(16),
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorWidget(String message) {
    return Container(
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 64,
            color: AppColors.brand.withValues(alpha: 0.7),
          ),
          SizedBox(height: 16),
          Text(
            'Something went wrong',
            style: GoogleFonts.roboto(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            message,
            style: GoogleFonts.roboto(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget(String message) {
    return Container(
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.video_library_outlined,
            size: 64,
            color: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          SizedBox(height: 16),
          Text(
            'No content found',
            style: GoogleFonts.roboto(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            message,
            style: GoogleFonts.roboto(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Dialog Methods
  void _showFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Filter & Sort',
          style: GoogleFonts.roboto(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Genre',
              style: GoogleFonts.roboto(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: controller.genres
                  .map(
                    (genre) => FilterChip(
                      label: Text(genre),
                      selected: controller.selectedGenre.value == genre,
                      onSelected: (_) {
                        controller.selectedGenre.value = genre;
                      },
                      backgroundColor: AppColors.bgSurfaceContainerHighest
                          .withValues(alpha: 0.3),
                      selectedColor: _getCategoryColor().withValues(alpha: 0.2),
                      checkmarkColor: _getCategoryColor(),
                      labelStyle: TextStyle(
                        color: controller.selectedGenre.value == genre
                            ? _getCategoryColor()
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                  .toList(),
            ),
            SizedBox(height: 16),
            Text(
              'Sort by',
              style: GoogleFonts.roboto(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            ...sortOptions.map(
              (option) => RadioMenuButton<String>(
                value: option,
                groupValue: controller.selectedSort.value,
                onChanged: (value) {
                  controller.selectedSort.value = value!;
                },
                child: Text(
                  option,
                  style: GoogleFonts.roboto(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: _getCategoryColor(),
            ),
            child: Text(
              'Apply',
              style: TextStyle(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  void _showSortDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Sort by',
          style: GoogleFonts.roboto(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: sortOptions
              .map(
                (option) => RadioMenuButton<String>(
                  value: option,
                  groupValue: controller.selectedSort.value,
                  onChanged: (value) {
                    controller.selectedSort.value = value!;
                    Navigator.pop(context);
                  },
                  child: Text(
                    option,
                    style: GoogleFonts.roboto(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  // Utility Methods
  String _formatViews(int views) {
    if (views >= 1000000) {
      return '${(views / 1000000).toStringAsFixed(1)}M';
    } else if (views >= 1000) {
      return '${(views / 1000).toStringAsFixed(1)}K';
    } else {
      return views.toString();
    }
  }
}

// ==========================================================================
// CUSTOM PAINTER FOR CATEGORY PATTERN
// ==========================================================================

class _CategoryPatternPainter extends CustomPainter {
  final Color color;

  _CategoryPatternPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    // Draw geometric pattern
    for (int i = 0; i < 10; i++) {
      for (int j = 0; j < 10; j++) {
        final x = (size.width / 10) * i;
        final y = (size.height / 10) * j;

        if ((i + j) % 2 == 0) {
          canvas.drawCircle(Offset(x + 20, y + 20), 8, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}






