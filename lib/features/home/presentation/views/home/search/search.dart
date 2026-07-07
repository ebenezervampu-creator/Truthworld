import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'filter_panel.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:algolia_helper_flutter/algolia_helper_flutter.dart';
import 'package:truthworld/theme/app_theme.dart';

// Constants
const kPrimaryColor = Color(0xFF1DB954);
const kPrimaryDark = Color(0xFF106E3A);
const kSecondaryDark = Color(0xFF0B532B);
const kBorderRadius = 16.0;
const kSmallPadding = 8.0;
const kMediumPadding = 16.0;
const kLargePadding = 24.0;
const kDarkBackground = AppColors.bgInput;
const kDarkSurface = Color(0xFF1A1A1A);
const kDarksurfaceContainerHighest = Color(0xFF242424);

// Assuming your constants are defined elsewhere:
// kDarkBackground, kDarksurfaceContainerHighest, kMediumPadding, kBorderRadius, kPrimaryColor

class CustomSearchDelegate extends SearchDelegate {
  // 1. INITIALIZE ALGOLIA
  // Define the searcher for the 'videos' index
  final _hitsSearcher = HitsSearcher(
    applicationID: 'X6BUL0J7AH',
    apiKey: '341a8bb8add2c2619962b52da16e5475',
    indexName: 'videos', // <--- Your specific index
  );

  @override
  ThemeData appBarTheme(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    // Your existing theme code...
    return theme.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: kDarkBackground,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: kDarksurfaceContainerHighest,
        contentPadding: EdgeInsets.all(kMediumPadding),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kBorderRadius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kBorderRadius),
          borderSide: BorderSide(color: kPrimaryColor, width: 2),
        ),
      ),
      textTheme: theme.textTheme.copyWith(
        titleLarge: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear, color: Colors.white),
        onPressed: () {
          query = '';
          // Optional: Reset search results when cleared
          _hitsSearcher.query('');
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back, color: Colors.white),
      onPressed: () {
        close(context, null); // Close the search
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    // When user presses "Enter", we show the results.
    // We can reuse the suggestion logic for consistency.
    return _buildAlgoliaResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    // As the user types, this runs.
    // 2. TRIGGER ALGOLIA QUERY
    _hitsSearcher.query(query);

    return _buildAlgoliaResults();
  }

  // Helper widget to avoid code duplication
  Widget _buildAlgoliaResults() {
    return Container(
      color: kDarkBackground,
      child: StreamBuilder<SearchResponse>(
        stream: _hitsSearcher.responses,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Error: ${snapshot.error}",
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final hits = snapshot.data!.hits;

          if (hits.isEmpty) {
            return Center(
              child: Text(
                query.isEmpty
                    ? "Start typing to search videos..."
                    : "No videos found.",
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            itemCount: hits.length,
            itemBuilder: (context, index) {
              final item = hits[index] as Map<String, dynamic>;
              final title = item['title'] ?? 'Untitled';
              final thumbnail = item['thumbnailUrl'];
              final channelName = item['channelName'] ?? 'Unknown';

              return ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CachedNetworkImage(
                    imageUrl: thumbnail ?? '',
                    width: 100,
                    fit: BoxFit.cover,
                    placeholder: (_, _) =>
                        Container(width: 100, color: Colors.grey[800]),
                  ),
                ),
                title: Text(title, style: TextStyle(color: Colors.white)),
                subtitle: Text(
                  channelName,
                  style: TextStyle(color: Colors.grey),
                ),

                onTap: () async {
                  final doc = await FirebaseFirestore.instance
                      .collection('videos')
                      .doc(item['objectID'])
                      .get();

                  final videoModel = Video.fromDocumentSnapshot(doc);

                  if (!context.mounted) return;
                  close(context, videoModel);
                  Get.toNamed('/watch?v=${videoModel.id}', arguments: {'video': videoModel});
                },
              );
            },
          );
        },
      ),
    );
  }

  // Optional: Dispose isn't standard in SearchDelegate,
  // but the searcher is lightweight.
}

class SearchPageWrapper extends StatelessWidget {
  final String searchQuery;

  const SearchPageWrapper({super.key, required this.searchQuery});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ModernSearchController());
    controller.searchQuery.value = searchQuery;
    controller.mainSearchController.text = searchQuery;

    return ModernSearchPage();
  }
}

// ==========================================================================
// MODERN SEARCH CONTROLLER
// ==========================================================================
class ModernSearchController extends GetxController
    with GetTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Controllers
  final searchController = TextEditingController();
  final mainSearchController = TextEditingController();

  // Animation Controllers
  late AnimationController fadeAnimationController;
  late AnimationController searchAnimationController;
  late AnimationController filterAnimationController;

  // Animations
  late Animation<double> fadeAnimation;
  late Animation<double> searchAnimation;
  late Animation<double> filterAnimation;

  // Observables
  final searchQuery = ''.obs;
  final selectedTabIndex = 0.obs;
  final selectedDateFilter = ''.obs;
  final selectedViewsFilter = ''.obs;
  final selectedDurationFilter = ''.obs;
  final selectedTypeFilter = ''.obs;
  final isSearchFocused = false.obs;
  final videos = <Video>[].obs;
  final channels = <Channel>[].obs;
  final playlists = <PlaylistModel>[].obs;
  final isLoadingVideos = false.obs;
  final isLoadingChannels = false.obs;
  final isLoadingPlaylists = false.obs;
  final errorVideos = ''.obs;
  final errorChannels = ''.obs;
  final errorPlaylists = ''.obs;
  final isInitialLoading = true.obs;
  final showFilters = false.obs;
  final isGridView = true.obs;
  var hasLoadedChannels = false.obs;

  final trendingSearches = [
    'Funny Cats',
    'Tech Reviews',
    'Cooking Tutorials',
    'Fitness Workouts',
    'Travel Vlogs',
    'Gaming Highlights',
    'Music Covers',
    'DIY Crafts',
  ];

  final categoryGradients = [
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1DB954), Color(0xFF106E3A)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF8400E7), Color(0xFF5A00A3)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFD70171), Color(0xFF9F003F)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1E3264), Color(0xFF0D1832)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFE81123), Color(0xFF740911)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1D75DE), Color(0xFF0E3A6F)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF59B23), Color(0xFF7A4D11)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFB02897), Color(0xFF58144B)],
    ),
  ];

  @override
  void onInit() {
    super.onInit();
    _initializeAnimations();
    _setupListeners();
    _loadAllData();
    debounce(
      searchQuery,
      (_) => searchContent(),
      time: const Duration(milliseconds: 300),
    );
  }

  void _initializeAnimations() {
    fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    searchAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    filterAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: fadeAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );
    searchAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: searchAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    filterAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: filterAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    fadeAnimationController.forward();
  }

  @override
  void onClose() {
    fadeAnimationController.dispose();
    searchAnimationController.dispose();
    filterAnimationController.dispose();
    searchController.dispose();
    mainSearchController.dispose();
    super.onClose();
  }

  void _setupListeners() {
    searchController.addListener(
      () => searchQuery.value = searchController.text.trim(),
    );
    mainSearchController.addListener(
      () => searchQuery.value = mainSearchController.text.trim(),
    );
  }

  Future<void> _loadAllData() async {
    isInitialLoading.value = true;
    errorVideos.value = '';
    errorChannels.value = '';
    errorPlaylists.value = '';
    await Future.wait([fetchVideos(), fetchChannels(), fetchPlaylists()]);
    isInitialLoading.value = false;
  }

  void onSearchFocused() {
    isSearchFocused.value = true;
    searchAnimationController.forward();
  }

  void onSearchUnfocused() {
    isSearchFocused.value = false;
    if (searchQuery.value.isEmpty) {
      searchAnimationController.reverse();
    }
  }

  void toggleFilters() {
    showFilters.value = !showFilters.value;
    showFilters.value
        ? filterAnimationController.forward()
        : filterAnimationController.reverse();
  }

  void toggleViewMode() {
    isGridView.value = !isGridView.value;
  }

  Future<void> fetchVideos({String? query}) async {
    isLoadingVideos.value = true;
    errorVideos.value = '';
    try {
      Query videosQuery = _firestore
          .collection('videos')
          .where('visibility', isEqualTo: 'Public')
          .orderBy('uploadedAt', descending: true);

      DateTime now = DateTime.now();
      DateTime? startDate;

      if (selectedDateFilter.value.isNotEmpty) {
        switch (selectedDateFilter.value) {
          case 'Last Hour':
            startDate = now.subtract(const Duration(hours: 1));
            break;
          case 'Today':
            startDate = DateTime(now.year, now.month, now.day);
            break;
          case 'Last 7 Days':
            startDate = now.subtract(const Duration(days: 7));
            break;
          case 'Last 30 Days':
            startDate = now.subtract(const Duration(days: 30));
            break;
          case 'Last 365 Days':
            startDate = now.subtract(const Duration(days: 365));
            break;
        }
        if (startDate != null) {
          videosQuery = videosQuery.where(
            'uploadedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
          );
        }
      }

      if (selectedViewsFilter.value.isNotEmpty) {
        switch (selectedViewsFilter.value) {
          case 'Under 1K':
            videosQuery = videosQuery
                .where('views', isGreaterThanOrEqualTo: 0)
                .where('views', isLessThan: 1000);
            break;
          case '1K-10K':
            videosQuery = videosQuery
                .where('views', isGreaterThanOrEqualTo: 1000)
                .where('views', isLessThan: 10000);
            break;
          case '10K-100K':
            videosQuery = videosQuery
                .where('views', isGreaterThanOrEqualTo: 10000)
                .where('views', isLessThan: 100000);
            break;
          case '100K-1M':
            videosQuery = videosQuery
                .where('views', isGreaterThanOrEqualTo: 100000)
                .where('views', isLessThan: 1000000);
            break;
          case 'Over 1M':
            videosQuery = videosQuery.where(
              'views',
              isGreaterThanOrEqualTo: 1000000,
            );
            break;
        }
      }

      if (selectedDurationFilter.value.isNotEmpty) {
        switch (selectedDurationFilter.value) {
          case 'Short':
            videosQuery = videosQuery.where('duration', isLessThan: 240);
            break;
          case 'Medium':
            videosQuery = videosQuery
                .where('duration', isGreaterThanOrEqualTo: 240)
                .where('duration', isLessThan: 1200);
            break;
          case 'Long':
            videosQuery = videosQuery.where('duration', isGreaterThan: 1200);
            break;
        }
      }

      videosQuery = videosQuery.orderBy('title');

      if (query != null && query.isNotEmpty) {
        videosQuery = videosQuery.startAt([query]).endAt(['$query\uf8ff']);
      }

      videosQuery = videosQuery.limit(50);

      final snapshot = await videosQuery.get().timeout(
        const Duration(seconds: 15),
      );
      videos.value = snapshot.docs
          .map((doc) => Video.fromDocumentSnapshot(doc))
          .toList();
    } catch (e) {
      errorVideos.value = e.toString();
    } finally {
      isLoadingVideos.value = false;
    }
  }

  Future<void> fetchChannels({String? query}) async {
    isLoadingChannels.value = true;
    errorChannels.value = '';
    try {
      Query channelsQuery = _firestore.collection('channels');
      if (query != null && query.isNotEmpty) {
        channelsQuery = channelsQuery
            .orderBy('channelName')
            .startAt([query])
            .endAt(['$query\uf8ff']);
      } else {
        channelsQuery = channelsQuery.orderBy('channelName');
      }

      channelsQuery = channelsQuery.limit(50);
      final snapshot = await channelsQuery.get().timeout(
        const Duration(seconds: 15),
      );
      channels.value = snapshot.docs
          .map((doc) => Channel.fromDocumentSnapshot(doc))
          .toList();
      hasLoadedChannels.value = true;
    } catch (e) {
      errorChannels.value = e.toString();
    } finally {
      isLoadingChannels.value = false;
    }
  }

  Future<void> fetchPlaylists({String? query}) async {
    isLoadingPlaylists.value = true;
    errorPlaylists.value = '';
    try {
      Query playlistQuery = _firestore
          .collection('public_playlists')
          .where('isPublic', isEqualTo: true);
      if (query != null && query.isNotEmpty) {
        playlistQuery = playlistQuery
            .orderBy('playlistName')
            .startAt([query])
            .endAt(['$query\uf8ff']);
      } else {
        playlistQuery = playlistQuery.orderBy('playlistName');
      }
      playlistQuery = playlistQuery.limit(50);
      final snapshot = await playlistQuery.get().timeout(
        const Duration(seconds: 15),
      );
      playlists.value = snapshot.docs
          .map((doc) => PlaylistModel.fromDocumentSnapshot(doc))
          .toList();
    } catch (e) {
      errorPlaylists.value = e.toString();
    } finally {
      isLoadingPlaylists.value = false;
    }
  }

  void searchContent() {
    final query = searchQuery.value.trim();
    if (selectedTypeFilter.value.isNotEmpty) {
      switch (selectedTypeFilter.value) {
        case 'Video':
          selectedTabIndex.value = 1;
          break;
        case 'Channel':
          selectedTabIndex.value = 2;
          break;
        case 'Playlist':
          selectedTabIndex.value = 3;
          break;
      }
    }

    if (query.isEmpty &&
        selectedDateFilter.value.isEmpty &&
        selectedViewsFilter.value.isEmpty &&
        selectedDurationFilter.value.isEmpty &&
        selectedTypeFilter.value.isEmpty) {
      _loadAllData();
      return;
    }

    switch (selectedTabIndex.value) {
      case 1:
        fetchVideos(query: query);
        break;
      case 2:
        fetchChannels(query: query);
        break;
      case 3:
        fetchPlaylists(query: query);
        break;
      default:
        fetchVideos(query: query);
        fetchChannels(query: query);
        fetchPlaylists(query: query);
        break;
    }
  }

  void selectTab(int index) {
    selectedTabIndex.value = index;
    selectedTypeFilter.value = '';
    searchContent();
  }

  void clearSearch() {
    searchController.clear();
    mainSearchController.clear();
    searchQuery.value = '';
    selectedDateFilter.value = '';
    selectedViewsFilter.value = '';
    selectedDurationFilter.value = '';
    selectedTypeFilter.value = '';
    selectedTabIndex.value = 0;
    isSearchFocused.value = false;
    searchAnimationController.reverse();
    _loadAllData();
  }

  String formatViews(int views) {
    if (views >= 1000000) {
      return '${(views / 1000000).toStringAsFixed(1)}M views';
    }
    if (views >= 1000) return '${(views / 1000).toStringAsFixed(1)}K views';
    return '$views views';
  }

  String formatSubscribers(int subscribers) {
    if (subscribers >= 1000000) {
      return '${(subscribers / 1000000).toStringAsFixed(1)}M subscribers';
    }
    if (subscribers >= 1000) {
      return '${(subscribers / 1000).toStringAsFixed(1)}K subscribers';
    }
    return '$subscribers subscribers';
  }

  String formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final h = duration.inHours;
    final m = duration.inMinutes.remainder(60);
    final s = duration.inSeconds.remainder(60);
    return h > 0
        ? '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
        : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

// ==========================================================================
// MODERN SEARCH PAGE UI
// ==========================================================================
class ModernSearchPage extends StatefulWidget {
  const ModernSearchPage({super.key});

  @override
  State<ModernSearchPage> createState() => _ModernSearchPageState();
}

class _ModernSearchPageState extends State<ModernSearchPage>
    with TickerProviderStateMixin {
  late ModernSearchController controller;
  late ScrollController scrollController;

  @override
  void initState() {
    super.initState();
    controller = Get.find<ModernSearchController>();
    scrollController = ScrollController();
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme.copyWith(
      surface: kDarkBackground,
      surfaceContainerHighest: kDarksurfaceContainerHighest,
    );

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: _buildResponsiveLayout(colorScheme),
    );
  }

  Widget _buildResponsiveLayout(ColorScheme colorScheme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return NestedScrollView(
          controller: scrollController,
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [_buildAdaptiveAppBar(colorScheme, constraints)];
          },
          body: AnimatedBuilder(
            animation: controller.fadeAnimation,
            builder: (context, child) {
              return FadeTransition(
                opacity: controller.fadeAnimation,
                child: _buildMainContent(colorScheme, constraints),
              );
            },
          ),
        );
      },
    );
  }

  SliverAppBar _buildAdaptiveAppBar(
    ColorScheme colorScheme,
    BoxConstraints constraints,
  ) {
    final isMobile = constraints.maxWidth < 600;

    return SliverAppBar(
      expandedHeight: isMobile ? 100.0 : 120.0,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      leading: Text(""),
      actions: _buildAppBarActions(colorScheme, isMobile),
      flexibleSpace: FlexibleSpaceBar(
        background: _buildAppBarBackground(colorScheme),
        titlePadding: EdgeInsets.only(
          left: isMobile ? kMediumPadding : kLargePadding,
          right: isMobile ? kMediumPadding : kLargePadding,
          bottom: isMobile ? kMediumPadding : 20,
        ),
      ),
    );
  }

  Widget _buildAppBarBackground(ColorScheme colorScheme) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.bgInput, Color(0xFF000000)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: FadeTransition(
              opacity: controller.fadeAnimation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.3),
                  end: Offset.zero,
                ).animate(controller.fadeAnimation),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Search",
                      style: GoogleFonts.roboto(
                        fontSize: MediaQuery.of(context).size.width < 600
                            ? 28
                            : 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: kSmallPadding),
                    Text(
                      "Find videos, channels, and playlists",
                      style: GoogleFonts.roboto(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildAppBarActions(ColorScheme colorScheme, bool isMobile) {
    return [
      FadeTransition(
        opacity: controller.fadeAnimation,
        child: Container(
          margin: EdgeInsets.only(
            right: isMobile ? kSmallPadding : kMediumPadding,
          ),
          decoration: BoxDecoration(
            color: AppTheme.colors.surfaceContainerHighest.withValues(
              alpha: 0.6,
            ),
            borderRadius: BorderRadius.circular(kBorderRadius),
          ),
          child: Obx(
            () => IconButton(
              icon: AnimatedRotation(
                turns: controller.showFilters.value ? 0.5 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Icon(
                  Icons.tune_rounded,
                  size: isMobile ? 20 : 24,
                  color: controller.showFilters.value
                      ? kPrimaryColor
                      : colorScheme.onSurface,
                ),
              ),
              onPressed: controller.toggleFilters,
              tooltip: 'Toggle Filters',
            ),
          ),
        ),
      ),
      FadeTransition(
        opacity: controller.fadeAnimation,
        child: Container(
          margin: EdgeInsets.only(right: isMobile ? kMediumPadding : 20),
          decoration: BoxDecoration(
            color: AppTheme.colors.surfaceContainerHighest.withValues(
              alpha: 0.6,
            ),
            borderRadius: BorderRadius.circular(kBorderRadius),
          ),
          child: Obx(
            () => IconButton(
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  controller.isGridView.value
                      ? Icons.view_list_rounded
                      : Icons.grid_view_rounded,
                  key: ValueKey(controller.isGridView.value),
                  size: isMobile ? 20 : 24,
                  color: colorScheme.onSurface,
                ),
              ),
              onPressed: controller.toggleViewMode,
              tooltip: controller.isGridView.value
                  ? 'Switch to List View'
                  : 'Switch to Grid View',
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildMainContent(
    ColorScheme colorScheme,
    BoxConstraints constraints,
  ) {
    final isMobile = constraints.maxWidth < 600;
    final padding = isMobile ? kMediumPadding : kLargePadding;

    return Obx(() {
      if (controller.isInitialLoading.value) {
        return _buildLoadingState(colorScheme, constraints);
      }
      return Stack(
        children: [
          SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(padding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTabSection(colorScheme, constraints),
                const SizedBox(height: kLargePadding),
                _buildContentSection(colorScheme, constraints),
              ],
            ),
          ),
          FilterPanel(
            colorScheme: colorScheme,
            constraints: constraints,
            controller: controller,
          ),
        ],
      );
    });
  }

  Widget _buildTabSection(ColorScheme colorScheme, BoxConstraints constraints) {
    final isMobile = constraints.maxWidth < 600;
    final tabs = ['All', 'Videos', 'Channels', 'Playlists'];

    return Container(
      height: isMobile ? 48 : 56,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(kBorderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Obx(
        () => Row(
          children: tabs.asMap().entries.map((entry) {
            final index = entry.key;
            final tab = entry.value;
            final isSelected = controller.selectedTabIndex.value == index;
            return Expanded(
              child: InkWell(
                onTap: () => controller.selectTab(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(colors: [kPrimaryColor, kPrimaryDark])
                        : null,
                    borderRadius: BorderRadius.circular(kBorderRadius - 4),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: kPrimaryColor.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      tab,
                      style: GoogleFonts.roboto(
                        color: isSelected
                            ? Colors.white
                            : colorScheme.onSurface,
                        fontSize: isMobile ? 14 : 16,
                        fontWeight: isSelected
                            ? FontWeight.w500
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildContentSection(
    ColorScheme colorScheme,
    BoxConstraints constraints,
  ) {
    return Obx(() {
      switch (controller.selectedTabIndex.value) {
        case 0:
          return _buildAllContent(colorScheme, constraints);
        case 1:
          return _buildVideosContent(colorScheme, constraints);
        case 2:
          return _buildChannelsContent(colorScheme, constraints);
        case 3:
          return _buildPlaylistsContent(colorScheme, constraints);
        default:
          return const SizedBox.shrink();
      }
    });
  }

  Widget _buildAllContent(ColorScheme colorScheme, BoxConstraints constraints) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (controller.searchQuery.value.isEmpty) ...[
          _buildSectionHeader('Browse all', colorScheme, constraints),
          const SizedBox(height: kMediumPadding),
          _buildTrendingGrid(colorScheme, constraints),
          const SizedBox(height: 32),
        ],
        if (controller.videos.isNotEmpty) ...[
          _buildSectionHeader('Videos', colorScheme, constraints),
          const SizedBox(height: kMediumPadding),
          _buildVideosGrid(
            controller.videos.take(4).toList(),
            colorScheme,
            constraints,
          ),
          const SizedBox(height: 32),
        ],
        if (controller.channels.isNotEmpty) ...[
          _buildSectionHeader('Channels', colorScheme, constraints),
          const SizedBox(height: kMediumPadding),
          _buildChannelsList(
            controller.channels.take(2).toList(),
            colorScheme,
            constraints,
          ),
          const SizedBox(height: 32),
        ],
        if (controller.playlists.isNotEmpty) ...[
          _buildSectionHeader('Playlists', colorScheme, constraints),
          const SizedBox(height: kMediumPadding),
          _buildPlaylistsList(
            controller.playlists.take(2).toList(),
            colorScheme,
            constraints,
          ),
        ],
      ],
    );
  }

  Widget _buildTrendingGrid(
    ColorScheme colorScheme,
    BoxConstraints constraints,
  ) {
    final isMobile = constraints.maxWidth < 600;
    final crossAxisCount = isMobile ? 2 : 4;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: kMediumPadding,
        mainAxisSpacing: kMediumPadding,
        childAspectRatio: 1.5,
      ),
      itemCount: controller.trendingSearches.length,
      itemBuilder: (context, index) {
        final search = controller.trendingSearches[index];
        final gradient = controller
            .categoryGradients[index % controller.categoryGradients.length];
        return InkWell(
          onTap: () {
            controller.searchQuery.value = search;
            controller.mainSearchController.text = search;
            controller.searchContent();
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(kBorderRadius),
              gradient: gradient,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.5),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(kMediumPadding),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Text(
                      search,
                      style: GoogleFonts.roboto(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(
    String title,
    ColorScheme colorScheme,
    BoxConstraints constraints,
  ) {
    final isMobile = constraints.maxWidth < 600;
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.roboto(
            color: Colors.white,
            fontSize: isMobile ? 20 : 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        if (title != 'Browse all')
          TextButton.icon(
            onPressed: () {
              switch (title) {
                case 'Videos':
                  controller.selectTab(1);
                  break;
                case 'Channels':
                  controller.selectTab(2);
                  break;
                case 'Playlists':
                  controller.selectTab(3);
                  break;
              }
            },
            icon: Icon(
              Icons.arrow_forward_rounded,
              size: isMobile ? 16 : 18,
              color: kPrimaryColor,
            ),
            label: Text(
              'See all',
              style: GoogleFonts.roboto(
                color: kPrimaryColor,
                fontSize: isMobile ? 14 : 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVideosContent(
    ColorScheme colorScheme,
    BoxConstraints constraints,
  ) {
    if (controller.isLoadingVideos.value) {
      return _buildContentSkeleton(colorScheme, constraints);
    }
    if (controller.errorVideos.isNotEmpty) {
      return _buildErrorState(
        'Failed to load videos',
        controller.errorVideos.value,
        Icons.error_outline_rounded,
        colorScheme,
        constraints,
        retry: () {
          controller.fetchVideos(query: controller.searchQuery.value);
        },
      );
    }
    if (controller.videos.isEmpty) {
      return _buildEmptyState(
        'No videos found',
        'Try adjusting your search or filters',
        Icons.video_library_outlined,
        colorScheme,
        constraints,
      );
    }
    return _buildVideosGrid(controller.videos, colorScheme, constraints);
  }

  Widget _buildChannelsContent(
    ColorScheme colorScheme,
    BoxConstraints constraints,
  ) {
    if (controller.isLoadingChannels.value &&
        !controller.hasLoadedChannels.value) {
      // Show skeleton only the very first time
      return _buildContentSkeleton(colorScheme, constraints);
    }

    if (controller.errorChannels.isNotEmpty) {
      return _buildErrorState(
        'Failed to load channels',
        controller.errorChannels.value,
        Icons.error_outline_rounded,
        colorScheme,
        constraints,
        retry: () =>
            controller.fetchChannels(query: controller.searchQuery.value),
      );
    }

    if (controller.channels.isEmpty) {
      return _buildEmptyState(
        'No channels found',
        'Try adjusting your search or filters',
        Icons.account_circle_outlined,
        colorScheme,
        constraints,
      );
    }

    return _buildChannelsList(controller.channels, colorScheme, constraints);
  }

  Widget _buildPlaylistsContent(
    ColorScheme colorScheme,
    BoxConstraints constraints,
  ) {
    if (controller.isLoadingPlaylists.value) {
      return _buildContentSkeleton(colorScheme, constraints);
    }
    if (controller.errorPlaylists.isNotEmpty) {
      return _buildErrorState(
        'Failed to load playlists',
        controller.errorPlaylists.value,
        Icons.error_outline_rounded,
        colorScheme,
        constraints,
        retry: () =>
            controller.fetchPlaylists(query: controller.searchQuery.value),
      );
    }
    if (controller.playlists.isEmpty) {
      return _buildEmptyState(
        'No playlists found',
        'Try adjusting your search or filters',
        Icons.playlist_play_outlined,
        colorScheme,
        constraints,
      );
    }
    return _buildPlaylistsList(controller.playlists, colorScheme, constraints);
  }

  Widget _buildLoadingState(
    ColorScheme colorScheme,
    BoxConstraints constraints,
  ) {
    final isMobile = constraints.maxWidth < 600;
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? kMediumPadding : kLargePadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTabSkeleton(colorScheme, isMobile),
          const SizedBox(height: kLargePadding),
          _buildContentSkeleton(colorScheme, constraints),
        ],
      ),
    );
  }

  Widget _buildTabSkeleton(ColorScheme colorScheme, bool isMobile) {
    return Container(
      height: isMobile ? 48 : 56,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(kBorderRadius),
      ),
      child: Shimmer.fromColors(
        baseColor: AppTheme.colors.surfaceContainerHighest,
        highlightColor: colorScheme.surface,
        child: Row(
          children: List.generate(
            4,
            (index) => Expanded(
              child: Container(
                margin: EdgeInsets.all(kSmallPadding),
                decoration: BoxDecoration(
                  color: AppTheme.colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(kBorderRadius - 4),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContentSkeleton(
    ColorScheme colorScheme,
    BoxConstraints constraints,
  ) {
    final isMobile = constraints.maxWidth < 600;
    final crossAxisCount = isMobile
        ? 1
        : constraints.maxWidth > 1200
        ? 3
        : 2;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: isMobile ? 12 : kMediumPadding,
        mainAxisSpacing: isMobile ? 12 : kMediumPadding,
        childAspectRatio: isMobile ? 1.5 : 1.3,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: AppTheme.colors.surfaceContainerHighest,
          highlightColor: colorScheme.surface,
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(kBorderRadius),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(
    String title,
    String subtitle,
    IconData icon,
    ColorScheme colorScheme,
    BoxConstraints constraints,
  ) {
    final isMobile = constraints.maxWidth < 600;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 40 : 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: isMobile ? 100 : 120,
              height: isMobile ? 100 : 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    kPrimaryColor.withValues(alpha: 0.2),
                    kPrimaryDark.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(60),
              ),
              child: Icon(icon, size: isMobile ? 50 : 60, color: kPrimaryColor),
            ),
            const SizedBox(height: kLargePadding),
            Text(
              title,
              style: GoogleFonts.roboto(
                fontSize: isMobile ? 20 : 24,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: kMediumPadding),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.roboto(
                fontSize: isMobile ? 14 : 16,
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(
    String title,
    String subtitle,
    IconData icon,
    ColorScheme colorScheme,
    BoxConstraints constraints, {
    required VoidCallback retry,
  }) {
    final isMobile = constraints.maxWidth < 600;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 40 : 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: isMobile ? 100 : 120,
              height: isMobile ? 100 : 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.colors.error.withValues(alpha: 0.2),
                    AppTheme.colors.error.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(60),
              ),
              child: Icon(
                icon,
                size: isMobile ? 50 : 60,
                color: AppTheme.colors.error,
              ),
            ),
            const SizedBox(height: kLargePadding),
            Text(
              title,
              style: GoogleFonts.roboto(
                fontSize: isMobile ? 20 : 24,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: kMediumPadding),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.roboto(
                fontSize: isMobile ? 14 : 16,
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: kLargePadding),
            ElevatedButton.icon(
              onPressed: retry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(kBorderRadius),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: kLargePadding,
                  vertical: kMediumPadding,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideosGrid(
    List<Video> videos,
    ColorScheme colorScheme,
    BoxConstraints constraints,
  ) {
    final isMobile = constraints.maxWidth < 600;
    final isTablet = constraints.maxWidth >= 600 && constraints.maxWidth < 1200;
    final crossAxisCount = isMobile
        ? 1
        : isTablet
        ? 2
        : constraints.maxWidth > 1400
        ? 4
        : 3;

    return Obx(
      () => AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: controller.isGridView.value
            ? GridView.builder(
                key: const ValueKey('grid'),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: isMobile ? 12 : kMediumPadding,
                  mainAxisSpacing: isMobile ? 12 : kMediumPadding,
                  childAspectRatio: isMobile
                      ? 1.5
                      : isTablet
                      ? 1.3
                      : 1.2,
                ),
                itemCount: videos.length,
                itemBuilder: (context, index) {
                  return FadeTransition(
                    opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                      CurvedAnimation(
                        parent: controller.fadeAnimationController,
                        curve: Interval(
                          (index * 0.1).clamp(0.0, 1.0),
                          ((index * 0.1) + 0.3).clamp(0.0, 1.0),
                          curve: Curves.easeOut,
                        ),
                      ),
                    ),
                    child: SlideTransition(
                      position:
                          Tween<Offset>(
                            begin: const Offset(0, 0.3),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: controller.fadeAnimationController,
                              curve: Interval(
                                (index * 0.1).clamp(0.0, 1.0),
                                ((index * 0.1) + 0.3).clamp(0.0, 1.0),
                                curve: Curves.easeOutCubic,
                              ),
                            ),
                          ),
                      child: VideoCard(
                        video: videos[index],
                        colorScheme: colorScheme,
                        isGridView: true,
                        constraints: constraints,
                      ),
                    ),
                  );
                },
              )
            : ListView.builder(
                key: const ValueKey('list'),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: videos.length,
                itemBuilder: (context, index) {
                  return FadeTransition(
                    opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                      CurvedAnimation(
                        parent: controller.fadeAnimationController,
                        curve: Interval(
                          (index * 0.1).clamp(0.0, 1.0),
                          ((index * 0.1) + 0.3).clamp(0.0, 1.0),
                          curve: Curves.easeOut,
                        ),
                      ),
                    ),
                    child: SlideTransition(
                      position:
                          Tween<Offset>(
                            begin: const Offset(0, 0.3),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: controller.fadeAnimationController,
                              curve: Interval(
                                (index * 0.1).clamp(0.0, 1.0),
                                ((index * 0.1) + 0.3).clamp(0.0, 1.0),
                                curve: Curves.easeOutCubic,
                              ),
                            ),
                          ),
                      child: Padding(
                        padding: EdgeInsets.only(
                          bottom: isMobile ? kMediumPadding : 20,
                        ),
                        child: VideoCard(
                          video: videos[index],
                          colorScheme: colorScheme,
                          isGridView: false,
                          constraints: constraints,
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildChannelsList(
    List<Channel> channels,
    ColorScheme colorScheme,
    BoxConstraints constraints,
  ) {
    final isMobile = constraints.maxWidth < 600;
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: channels.length,
      itemBuilder: (context, index) {
        return FadeTransition(
          opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
              parent: controller.fadeAnimationController,
              curve: Interval(
                (index * 0.1).clamp(0.0, 1.0),
                ((index * 0.1) + 0.3).clamp(0.0, 1.0),
                curve: Curves.easeOut,
              ),
            ),
          ),
          child: SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(0, 0.3),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: controller.fadeAnimationController,
                    curve: Interval(
                      (index * 0.1).clamp(0.0, 1.0),
                      ((index * 0.1) + 0.3).clamp(0.0, 1.0),
                      curve: Curves.easeOutCubic,
                    ),
                  ),
                ),
            child: Padding(
              padding: EdgeInsets.only(bottom: isMobile ? 12 : kMediumPadding),
              child: ChannelCard(
                channel: channels[index],
                colorScheme: colorScheme,
                constraints: constraints,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaylistsList(
    List<PlaylistModel> playlists,
    ColorScheme colorScheme,
    BoxConstraints constraints,
  ) {
    final isMobile = constraints.maxWidth < 600;
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: playlists.length,
      itemBuilder: (context, index) {
        return FadeTransition(
          opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
              parent: controller.fadeAnimationController,
              curve: Interval(
                (index * 0.1).clamp(0.0, 1.0),
                ((index * 0.1) + 0.3).clamp(0.0, 1.0),
                curve: Curves.easeOut,
              ),
            ),
          ),
          child: SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(0, 0.3),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: controller.fadeAnimationController,
                    curve: Interval(
                      (index * 0.1).clamp(0.0, 1.0),
                      ((index * 0.1) + 0.3).clamp(0.0, 1.0),
                      curve: Curves.easeOutCubic,
                    ),
                  ),
                ),
            child: Padding(
              padding: EdgeInsets.only(bottom: isMobile ? 12 : kMediumPadding),
              child: PlaylistCard(
                playlist: playlists[index],
                colorScheme: colorScheme,
                constraints: constraints,
              ),
            ),
          ),
        );
      },
    );
  }
}

// Reusable VideoCard with hover/tap animation
class VideoCard extends StatelessWidget {
  final Video video;
  final ColorScheme colorScheme;
  final bool isGridView;
  final BoxConstraints constraints;

  VideoCard({
    super.key,
    required this.video,
    required this.colorScheme,
    required this.isGridView,
    required this.constraints,
  });

  final RxBool _isHovered = false.obs;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ModernSearchController>();
    final isMobile = constraints.maxWidth < 600;
    return MouseRegion(
      onEnter: (_) => _isHovered.value = true,
      onExit: (_) => _isHovered.value = false,
      child: InkWell(
        onTap: () =>
            Get.toNamed('/watch?v=${video.id}', arguments: {'video': video}),
        child: Obx(() => AnimatedScale(
          scale: _isHovered.value ? 1.02 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(kBorderRadius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: isGridView
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: _buildVideoThumbnail(
                          controller,
                          video,
                          colorScheme,
                          true,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Padding(
                          padding: EdgeInsets.all(
                            isMobile ? 12 : kMediumPadding,
                          ),
                          child: _buildVideoInfo(
                            controller,
                            video,
                            colorScheme,
                            isMobile,
                            true,
                          ),
                        ),
                      ),
                    ],
                  )
                : Padding(
                    padding: EdgeInsets.all(isMobile ? 12 : kMediumPadding),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: isMobile ? 120 : 160,
                          height: isMobile ? 90 : 120,
                          child: _buildVideoThumbnail(
                            controller,
                            video,
                            colorScheme,
                            false,
                          ),
                        ),
                        const SizedBox(width: kMediumPadding),
                        Expanded(
                          child: _buildVideoInfo(
                            controller,
                            video,
                            colorScheme,
                            isMobile,
                            false,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    ),
  );
}

  Widget _buildVideoThumbnail(
    ModernSearchController controller,
    Video video,
    ColorScheme colorScheme,
    bool isGridView,
  ) {
    return Hero(
      tag: 'video_${video.id}',
      child: ClipRRect(
        borderRadius: isGridView
            ? const BorderRadius.vertical(top: Radius.circular(kBorderRadius))
            : BorderRadius.circular(kBorderRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: video.thumbnailUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Shimmer.fromColors(
                baseColor: AppTheme.colors.surfaceContainerHighest,
                highlightColor: colorScheme.surface,
                child: Container(
                  color: AppTheme.colors.surfaceContainerHighest,
                ),
              ),
              errorWidget: (context, url, error) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [kPrimaryColor, kPrimaryDark],
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.play_circle_outline_rounded,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.3),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: kSmallPadding,
              right: kSmallPadding,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: kSmallPadding,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  video.duration,
                  style: GoogleFonts.roboto(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoInfo(
    ModernSearchController controller,
    Video video,
    ColorScheme colorScheme,
    bool isMobile,
    bool isGridView,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          video.title,
          maxLines: isGridView ? 2 : 3,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.roboto(
            fontWeight: FontWeight.bold,
            fontSize: isMobile
                ? (isGridView ? 14 : 16)
                : (isGridView ? 16 : 18),
            color: colorScheme.onSurface,
            height: 1.3,
          ),
        ),
        const SizedBox(height: kSmallPadding),
        Row(
          children: [
            CircleAvatar(
              backgroundImage: CachedNetworkImageProvider(video.channelImage),
              radius: isMobile ? 12 : 14,
              backgroundColor: AppTheme.colors.surfaceContainerHighest,
            ),
            const SizedBox(width: kSmallPadding),
            Expanded(
              child: Text(
                video.channelName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.roboto(
                  fontSize: isMobile ? 13 : 15,
                  fontWeight: FontWeight.w500,
                  color: kPrimaryColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: kSmallPadding,
          runSpacing: 6,
          children: [
            _buildStatChip(
              Icons.visibility_rounded,
              controller.formatViews(video.views),
              colorScheme,
              isMobile,
            ),
            _buildStatChip(
              Icons.access_time_rounded,
              _formatTimeAgo(video.uploadedAt.toDate()),
              colorScheme,
              isMobile,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatChip(
    IconData icon,
    String text,
    ColorScheme colorScheme,
    bool isMobile,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 6 : kSmallPadding,
        vertical: isMobile ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: kPrimaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(kSmallPadding),
        border: Border.all(color: kPrimaryColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: isMobile ? 10 : 12, color: kPrimaryColor),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: GoogleFonts.roboto(
                fontSize: isMobile ? 9 : 11,
                fontWeight: FontWeight.w500,
                color: kPrimaryColor,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} year${(difference.inDays / 365).floor() == 1 ? '' : 's'} ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} month${(difference.inDays / 30).floor() == 1 ? '' : 's'} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }
}

// Reusable ChannelCard
class ChannelCard extends StatelessWidget {
  final Channel channel;
  final ColorScheme colorScheme;
  final BoxConstraints constraints;

  ChannelCard({
    super.key,
    required this.channel,
    required this.colorScheme,
    required this.constraints,
  });

  final RxBool _isHovered = false.obs;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ModernSearchController>();
    final isMobile = constraints.maxWidth < 600;
    return MouseRegion(
      onEnter: (_) => _isHovered.value = true,
      onExit: (_) => _isHovered.value = false,
      child: InkWell(
        onTap: () async {
          final subscriberCount = await FirebaseFirestore.instance
              .collection("subscriptions")
              .where('channelId', isEqualTo: channel.channelId)
              .count()
              .get()
              .then((res) => res.count);
          Get.toNamed(
            "/channel-details",
            arguments: {
              "channel": channel,
              'subscribercount': subscriberCount,
            },
          );
        },
        child: Obx(
          () => AnimatedScale(
            scale: _isHovered.value ? 1.02 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(kBorderRadius),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection("subscriptions")
                    .where('channelId', isEqualTo: channel.channelId)
                    .snapshots(),
                builder: (context, subscriptionSnapshot) {
                  if (subscriptionSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return _buildChannelSkeleton(colorScheme, isMobile);
                  }
                  if (subscriptionSnapshot.hasError) {
                    return _buildChannelError(colorScheme, isMobile);
                  }
                  final subscriberCount = subscriptionSnapshot.data?.size ?? 0;
                  return Padding(
                    padding: EdgeInsets.all(isMobile ? kMediumPadding : 20),
                    child: Row(
                      children: [
                        Hero(
                          tag: 'channel_${channel.channelId}',
                          child: CircleAvatar(
                            radius: isMobile ? 24 : 28,
                            backgroundColor:
                                AppTheme.colors.surfaceContainerHighest,
                            backgroundImage: CachedNetworkImageProvider(
                              channel.bannerImageUrl,
                            ),
                          ),
                        ),
                        const SizedBox(width: kMediumPadding),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                channel.channelName,
                                style: GoogleFonts.roboto(
                                  fontSize: isMobile ? 16 : 18,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                channel.description,
                                style: GoogleFonts.roboto(
                                  fontSize: isMobile ? 13 : 14,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                              const SizedBox(height: kSmallPadding),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: kSmallPadding,
                                  vertical: isMobile ? 4 : 5,
                                ),
                                decoration: BoxDecoration(
                                  color: kPrimaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: kPrimaryColor.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Text(
                                  controller.formatSubscribers(subscriberCount),
                                  style: GoogleFonts.roboto(
                                    fontSize: isMobile ? 11 : 12,
                                    fontWeight: FontWeight.w500,
                                    color: kPrimaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: isMobile ? 16 : 18,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChannelSkeleton(ColorScheme colorScheme, bool isMobile) {
    return Padding(
      padding: EdgeInsets.all(isMobile ? kMediumPadding : 20),
      child: Shimmer.fromColors(
        baseColor: AppTheme.colors.surfaceContainerHighest,
        highlightColor: colorScheme.surface,
        child: Row(
          children: [
            CircleAvatar(
              radius: isMobile ? 24 : 28,
              backgroundColor: AppTheme.colors.surfaceContainerHighest,
            ),
            const SizedBox(width: kMediumPadding),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 16,
                    width: double.infinity,
                    color: AppTheme.colors.surfaceContainerHighest,
                  ),
                  const SizedBox(height: kSmallPadding),
                  Container(
                    height: 12,
                    width: 100,
                    color: AppTheme.colors.surfaceContainerHighest,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelError(ColorScheme colorScheme, bool isMobile) {
    return Padding(
      padding: EdgeInsets.all(isMobile ? kMediumPadding : 20),
      child: Row(
        children: [
          CircleAvatar(
            radius: isMobile ? 24 : 28,
            backgroundColor: AppTheme.colors.surfaceContainerHighest,
          ),
          const SizedBox(width: kMediumPadding),
          Expanded(
            child: Text(
              'Failed to load subscriber count',
              style: GoogleFonts.roboto(
                fontSize: isMobile ? 13 : 14,
                color: colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Reusable PlaylistCard
class PlaylistCard extends StatelessWidget {
  final PlaylistModel playlist;
  final ColorScheme colorScheme;
  final BoxConstraints constraints;

  PlaylistCard({
    super.key,
    required this.playlist,
    required this.colorScheme,
    required this.constraints,
  });

  final RxBool _isHovered = false.obs;

  @override
  Widget build(BuildContext context) {
    final isMobile = constraints.maxWidth < 600;
    return MouseRegion(
      onEnter: (_) => _isHovered.value = true,
      onExit: (_) => _isHovered.value = false,
      child: InkWell(
        onTap: () {
          // Check if HomeController is available (we're in home screen context)
          if (Get.isRegistered<HomeController>()) {
            final homeController = Get.find<HomeController>();
            homeController.navigateToPlaylistDetail(playlist);
          } else {
            // Navigate to home first, then show playlist detail
            Get.toNamed('/', arguments: {'openPlaylist': playlist});
          }
        },
        child: Obx(
          () => AnimatedScale(
            scale: _isHovered.value ? 1.02 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(kBorderRadius),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(isMobile ? kMediumPadding : 20),
                child: Row(
                  children: [
                    SizedBox(
                      width: isMobile ? 80 : 100,
                      height: isMobile ? 60 : 75,
                      child: playlist.thumbnailUrl.isNotEmpty
                          ? Hero(
                              tag: 'playlist_${playlist.id}',
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    CachedNetworkImage(
                                      imageUrl: playlist.thumbnailUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) =>
                                          Shimmer.fromColors(
                                            baseColor: AppTheme
                                                .colors
                                                .surfaceContainerHighest,
                                            highlightColor:
                                                colorScheme.surface,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: AppTheme
                                                    .colors
                                                    .surfaceContainerHighest,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                          ),
                                      errorWidget: (context, url, error) =>
                                          _buildPlaceholder(colorScheme),
                                    ),
                                    Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.transparent,
                                            Colors.black.withValues(alpha: 0.5),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 4,
                                      right: 4,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(
                                            alpha: 0.8,
                                          ),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '${playlist.videoIds.length}',
                                          style: GoogleFonts.roboto(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : _buildPlaceholder(colorScheme),
                    ),
                    const SizedBox(width: kMediumPadding),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            playlist.playlistName,
                            style: GoogleFonts.roboto(
                              fontSize: isMobile ? 16 : 18,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                          const SizedBox(height: kSmallPadding),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: kSmallPadding,
                              vertical: isMobile ? 4 : 5,
                            ),
                            decoration: BoxDecoration(
                              color: kPrimaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: kPrimaryColor.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.playlist_play_rounded,
                                  size: isMobile ? 12 : 14,
                                  color: kPrimaryColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${playlist.videoIds.length} videos',
                                  style: GoogleFonts.roboto(
                                    fontSize: isMobile ? 11 : 12,
                                    fontWeight: FontWeight.w500,
                                    color: kPrimaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: isMobile ? 16 : 18,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(ColorScheme colorScheme) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kPrimaryColor, kPrimaryDark],
        ),
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: const Center(
        child: Icon(Icons.playlist_play_rounded, size: 32, color: Colors.white),
      ),
    );
  }
}





