import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';
import 'package:truthworld/core/services/algorithm/diversity_config.dart';
import 'package:truthworld/core/services/algorithm/feed_algorithm_service.dart';
import 'package:truthworld/core/services/algorithm/flip_coin_service.dart';
import 'package:truthworld/core/services/algorithm/scored_video.dart';
import 'package:truthworld/core/services/algorithm/truthworld_algorithm.dart';
import 'package:truthworld/core/services/algorithm/user_interest_profile_service.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/core/services/video_sanitizer.dart';
import 'package:truthworld/core/services/video_visibility_policy.dart';
import 'package:truthworld/core/utils/firestore_cache_extension.dart';
import 'package:truthworld/core/utils/studio_launcher.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/community/data/models/community_post_model.dart';
import 'package:truthworld/features/home/data/services/feed_cache_manager.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_controller.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/services/video_query_builder.dart';
import 'package:truthworld/features/video/presentation/controllers/downloadcontroller.dart';
import 'package:truthworld/theme/app_theme.dart';

// ========================================================================
// COLOR CONSTANTS
// ========================================================================

final Color darkBackground = AppTheme.colors.background;
final Color darkSurface = AppTheme.colors.surface;
const Color darksurfaceContainerHighest = Color(0xFFFFB703);
final Color darkOnSurface = AppTheme.colors.textPrimary;
final Color darkonSurfaceVariant = AppTheme.colors.textSecondary;
final Color greenAccent = AppTheme.colors.success;
final Color greenSecondary = AppTheme.colors.successDark;
final Color greenTertiary = AppTheme.colors.success;
final Color errorColor = AppTheme.colors.error;

/// Home screen controller managing navigation, videos, and user authentication
class HomeController extends BaseController with GetTickerProviderStateMixin {
  final AuthService _authService = Get.find<AuthService>();
  final _storage = GetStorage();
  final FeedCacheManager _feedCacheManager = FeedCacheManager();
  static const String _kFeaturedTopicsCacheKey = 'featured_topics_cache';

  final RxList<Topic> featuredTopics = <Topic>[].obs;
  final RxBool isLoadingFeaturedTopics = true.obs;

  // ========================================================================
  // FIREBASE SERVICES
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // NAVIGATION STATE
  // ========================================================================

  static const List<String> categories = [
    'Education',
    'Entertainment',
    'Music',
    'News',
    'Sports',
    'Gaming',
    'Technology',
    'Science',
    'Travel',
    'Lifestyle',
    'Comedy',
    'Documentary',
    'Movies',
    'TV Shows',
    'Vlogs',
    'DIY & How-to',
    'Health & Fitness',
    'Fashion & Beauty',
    'Food & Cooking',
    'Business & Finance',
    'Animation',
    'Short Films',
    'Motivation',
    'History',
    'Art & Design',
    'Automotive',
    'Animals & Pets',
    'Spirituality',
    'Nature & Wildlife',
    'Kids & Family',
  ];

  // DASHBOARD PAGE INDICES (Industry Standard Order)
  // Section: Explore
  static const int indexHome = 0;
  static const int indexSubscriptions = 1;
  static const int indexTrending = 2;
  static const int indexDiscover = 3;

  // Section: You
  static const int indexLibrary = 4;
  static const int indexHistory = 5;
  static const int indexYourVideos = 6;
  static const int indexLikedVideos = 7;
  static const int indexDownloads = 8;
  static const int indexWatchLater = 9;
  static const int indexPlaylists = 10;
  static const int indexFollowingTopics = 18;
  static const int indexClips = 17;

  // Special Pages (Not shown in navigation, used for nested content)
  static const int indexPlaylistDetail = 99;
  static const int indexChannelDetail = 100;

  // Section: Utility
  static const int indexSettings = 11;
  static const int indexHelp = 12;
  static const int indexFeedback = 13;

  // Section: Legal
  static const int indexAbout = 14;
  static const int indexPrivacy = 15;
  static const int indexTerms = 16;
  static const int indexExploreTopics = 19;
  static const int indexCommunityGuidelines = 20;

  // ========================================================================
  // AUTHENTICATION STATE
  // ========================================================================

  static const List<String> primaryFilterBars = [
    'All',
    'Trending',
    'From watch history',
    'From Subscribed channels',
    'Topics',
    'Videos',
  ];

  final RxInt sideNavSelectedIndex = indexHome.obs;
  final RxInt bottomNavSelectedIndex = 0.obs;
  final RxString selectedCategory = 'All'.obs;
  final RxString activeFilterBar = 'All'.obs;
  final RxList<String> availableCategories = <String>['All'].obs;

  // Special page data
  final selectedPlaylist =
      Rxn<dynamic>(); // Stores playlist data for detail view
  final selectedChannelForDetail =
      Rxn<Channel>(); // Stores channel data for detail view

  late TabController tabController;

  // ========================================================================
  // AUTHENTICATION STATE
  // ========================================================================

  final RxBool isLoadingAuth = false.obs;

  /// Compatibility getter: now linked to real AuthService
  Rxn<User> get currentUser => _authService.currentUser;

  /// Navigation state tracking
  final RxBool isNavigating = false.obs;

  // ========================================================================
  // ANIMATION CONTROLLERS AND ANIMATIONS
  // ========================================================================

  late AnimationController _fadeAnimationController;
  late AnimationController _slideAnimationController;
  late AnimationController _scaleAnimationController;
  bool _isDisposed = false;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  // Animation getters
  Animation<double> get fadeAnimation => _fadeAnimation;
  Animation<Offset> get slideAnimation => _slideAnimation;
  Animation<double> get scaleAnimation => _scaleAnimation;

  // ========================================================================
  // VIDEO STATE - MAIN FEED
  // ========================================================================

  final RxList<Video> videos = <Video>[].obs;
  final RxList<CommunityPostModel> communityPosts = <CommunityPostModel>[].obs;
  final RxList<dynamic> homeFeedItems = <dynamic>[].obs;
  final RxBool isLoadingVideos = true.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool rxHasMore = true.obs;
  DocumentSnapshot? _lastDocument;

  static const int _pageSize = 24;
  static const int _loadMoreThreshold = 90; // Percentage of scroll position

  final scrollController = ScrollController();
  final RxBool showBottomNav = true.obs;
  double _lastScrollPosition = 0;
  static const double kScrollThreshold = 8;

  // ========================================================================
  // VIDEO STATE - CAROUSELS
  // ========================================================================

  final RxList<Video> recommendedVideos = <Video>[].obs;
  final RxList<Video> musicVideos = <Video>[].obs;
  final RxList<Video> trendingVideos = <Video>[].obs;
  final RxBool isCarouselLoading = true.obs;

  // USER LIBRARY SECTIONS STATE
  final RxBool hasWatchHistory = true.obs;
  final RxBool hasPlaylists = true.obs;
  final RxBool hasFollowedTopics = true.obs;
  final RxBool hasWatchLater = true.obs;
  final RxBool hasLikedVideos = true.obs;
  final RxBool hasUploadedVideos = true.obs;
  final RxBool hasClips = true.obs;
  final RxBool hasDownloads = true.obs;

  StreamSubscription? _historySub;
  StreamSubscription? _playlistsSub;
  StreamSubscription? _topicsSub;
  StreamSubscription? _watchLaterSub;
  StreamSubscription? _likedSub;
  StreamSubscription? _myVideosSub;
  StreamSubscription? _clipsSub;
  StreamSubscription? _downloadsListSub;

  // ========================================================================
  // SUBSCRIPTIONS STATE
  // ========================================================================
  final RxMap<String, dynamic> subscribedChannels = <String, dynamic>{}.obs; // Map for faster lookup
  final RxList<Map<String, dynamic>> subscribedChannelList = <Map<String, dynamic>>[].obs;
  final RxBool isLoadingSubscriptions = false.obs;
  StreamSubscription? _connectivitySubscription;

  // ========================================================================
  // LIFECYCLE
  // ========================================================================

  @override
  void onInit() {
    super.onInit();
    _initializeAnimations();
    _bindScrollListener();
    _loadInitialData();
    fetchSubscribedChannels();
    _setupConnectivityListener();
    _setupBottomNavSync();

    // Listen to authentication state changes
    ever(_authService.currentUser, (u) {
      if (u != null) {
        _checkUserLibraryData(u.uid);
        fetchSubscribedChannels();
      } else {
        _resetLibraryData();
        subscribedChannelList.clear();
      }
    });

    // Initial fetch if user is already authenticated
    final currentUid = _authService.user?.uid;
    if (currentUid != null && currentUid.isNotEmpty) {
      _checkUserLibraryData(currentUid);
    }
  }

  Future<void> _checkUserLibraryData(String userId) async {
    try {
      final results = await Future.wait([
        _firestore
            .collection('users')
            .doc(userId)
            .collection('watch_history')
            .limit(1)
            .getCacheFirst(),
        _firestore
            .collection('users')
            .doc(userId)
            .collection('playlists')
            .limit(1)
            .getCacheFirst(),
        _firestore
            .collection('users')
            .doc(userId)
            .collection('savedTopics')
            .limit(1)
            .getCacheFirst(),
        _firestore
            .collection('users')
            .doc(userId)
            .collection('watch_later')
            .limit(1)
            .getCacheFirst(),
        _firestore
            .collection('videos')
            .where('likedBy', arrayContains: userId)
            .limit(1)
            .getCacheFirst(),
        _firestore
            .collection('videos')
            .where('ownerId', isEqualTo: userId)
            .limit(1)
            .getCacheFirst(),
        _firestore
            .collection('users')
            .doc(userId)
            .collection('clips')
            .limit(1)
            .getCacheFirst(),
      ]);

      hasWatchHistory.value = results[0].docs.isNotEmpty;
      hasPlaylists.value = results[1].docs.isNotEmpty;
      hasFollowedTopics.value = results[2].docs.isNotEmpty;
      hasWatchLater.value = results[3].docs.isNotEmpty;
      hasLikedVideos.value = results[4].docs.isNotEmpty;
      hasUploadedVideos.value = results[5].docs.isNotEmpty;
      hasClips.value = results[6].docs.isNotEmpty;

      _setupDownloadsListener();
    } catch (e) {
      debugPrint('HomeController: Error checking user library data: $e');
    }
  }

  void _setupDownloadsListener() {
    if (!Get.isRegistered<DownloadsController>()) {
      Get.put(DownloadsController());
    }
    final downloadsCtrl = Get.find<DownloadsController>();
    hasDownloads.value = downloadsCtrl.videos.isNotEmpty;

    _downloadsListSub?.cancel();
    _downloadsListSub = downloadsCtrl.videos.listen((videosList) {
      hasDownloads.value = videosList.isNotEmpty;
    });
  }

  void _resetLibraryData() {
    _historySub?.cancel();
    _playlistsSub?.cancel();
    _topicsSub?.cancel();
    _watchLaterSub?.cancel();
    _likedSub?.cancel();
    _myVideosSub?.cancel();
    _clipsSub?.cancel();
    _downloadsListSub?.cancel();

    hasWatchHistory.value = false;
    hasPlaylists.value = false;
    hasFollowedTopics.value = false;
    hasWatchLater.value = false;
    hasLikedVideos.value = false;
    hasUploadedVideos.value = false;
    hasClips.value = false;
    hasDownloads.value = false;
  }

  void _setupBottomNavSync() {
    ever(sideNavSelectedIndex, (index) {
      // Reset bottom nav visibility when switching tabs
      showBottomNav.value = true;

      if (index == indexHome) {
        bottomNavSelectedIndex.value = 0;
      } else if (index == indexExploreTopics) {
        bottomNavSelectedIndex.value = 1;
      } else if (index == indexDiscover) {
        bottomNavSelectedIndex.value = 2;
      } else if (index == indexLibrary || index == indexFollowingTopics) {
        bottomNavSelectedIndex.value = 3;
      }
    });
  }

  void _setupConnectivityListener() {
    _connectivitySubscription = Get.find<ConnectivityService>()
        .onConnectivityChanged
        .listen((results) {
          final isConnected = results.any((r) => r != ConnectivityResult.none);
          // If we were showing an error or empty state due to offline, reload
          if (isConnected && (videos.isEmpty || trendingVideos.isEmpty)) {
            debugPrint(
              '[HomeController] 🌐 Internet restored. Reloading feed...',
            );
            _loadInitialData();
            fetchSubscribedChannels();
          }
        });
  }

  @override
  void onReady() {
    super.onReady();
    _initializeTabController();
  }

  @override
  void onClose() {
    _isDisposed = true;
    _resetLibraryData();
    _disposeAnimations();
    tabController.dispose();
    scrollController.removeListener(_scrollListener);
    scrollController.dispose();
    _connectivitySubscription?.cancel();
    super.onClose();
  }

  // ========================================================================
  // INITIALIZATION METHODS
  // ========================================================================

  /// Initialize all animation controllers
  void _initializeAnimations() {
    _isDisposed = false;
    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Setup fade animation
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _fadeAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );

    // Setup slide animation
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _slideAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );

    // Setup scale animation
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1).animate(
      CurvedAnimation(
        parent: _scaleAnimationController,
        curve: Curves.easeOutBack,
      ),
    );

    // Start animations
    _fadeAnimationController.forward();
    _slideAnimationController.forward();
    _scaleAnimationController.forward();
  }

  /// Dispose all animation controllers
  void _disposeAnimations() {
    _fadeAnimationController.dispose();
    _slideAnimationController.dispose();
    _scaleAnimationController.dispose();
  }

  /// Initialize tab controller with categories
  void _initializeTabController() {
    tabController = TabController(
      length: availableCategories.length,
      vsync: this,
    );

    tabController.addListener(_onTabChanged);
  }

  /// Reinitialize TabController when availableCategories updates
  void _reinitializeTabController() {
    try {
      final newLength = availableCategories.length;
      if (tabController.length != newLength) {
        final currentIndex = tabController.index.clamp(
          0,
          newLength > 0 ? newLength - 1 : 0,
        );
        tabController.dispose();
        tabController = TabController(
          length: newLength,
          initialIndex: currentIndex,
          vsync: this,
        );
        tabController.addListener(_onTabChanged);
      }
    } catch (e) {
      debugPrint('HomeController: Error reinitializing TabController: $e');
    }
  }

  /// Bind scroll listener for infinite scroll
  void _bindScrollListener() {
    scrollController.addListener(_scrollListener);
  }

  /// Load initial data (videos and carousels)
  void _loadInitialData() {
    _loadCachedVideos();
    _loadCachedFeaturedTopics();
    fetchInitialVideos();
    fetchCarouselVideos();
    fetchFeaturedTopics();
    fetchAvailableCategories();
  }

  /// Load videos from local storage using FeedCacheManager with TTL and VideoSanitizer
  void _loadCachedVideos() {
    try {
      final cachedVideos = _feedCacheManager.getValidCachedVideos(
        FeedCacheManager.keyHomeFeed,
      );
      if (cachedVideos != null && cachedVideos.isNotEmpty && videos.isEmpty) {
        videos.assignAll(cachedVideos);
        isLoadingVideos.value = false;
        debugPrint(
          'HomeController: Loaded ${videos.length} sanitized videos from cache',
        );
      }
    } catch (e) {
      debugPrint('HomeController: Cache load error: $e');
    }
  }

  /// Save videos to local storage using FeedCacheManager
  void _saveVideosToCache() {
    try {
      if (videos.isNotEmpty) {
        _feedCacheManager.saveFeedToCache(FeedCacheManager.keyHomeFeed, videos);
      }
    } catch (e) {
      debugPrint('HomeController: Cache save error: $e');
    }
  }

  /// Load featured topics from local storage for instant perceived speed
  void _loadCachedFeaturedTopics() {
    try {
      final cachedData = _storage.read<List>(_kFeaturedTopicsCacheKey);
      if (cachedData != null && featuredTopics.isEmpty) {
        final cachedTopics = cachedData
            .map((data) => Topic.fromMap(Map<String, dynamic>.from(data)))
            .toList();
        featuredTopics.assignAll(cachedTopics);
        isLoadingFeaturedTopics.value = false;
        debugPrint(
          'HomeController: Loaded ${featuredTopics.length} featured topics from cache',
        );
      }
    } catch (e) {
      debugPrint('HomeController: Cached topics load error: $e');
    }
  }

  /// Save featured topics to local storage
  void _saveFeaturedTopicsToCache() {
    try {
      final dataToCache = featuredTopics.map((t) => t.toCacheMap()).toList();
      _storage.write(_kFeaturedTopicsCacheKey, dataToCache);
    } catch (e) {
      debugPrint('HomeController: Cached topics save error: $e');
    }
  }

  /// Fetch featured topics from Firestore
  Future<void> fetchFeaturedTopics() async {
    try {
      if (featuredTopics.isEmpty) {
        isLoadingFeaturedTopics.value = true;
      }
      final snapshot = await _firestore
          .collection('topics')
          .where('isFeatured', isEqualTo: true)
          .limit(6)
          .get();

      var topicsList = <Topic>[];
      if (snapshot.docs.isNotEmpty) {
        topicsList = snapshot.docs.map(Topic.fromDocumentSnapshot).toList();
      }

      if (topicsList.isEmpty) {
        final fallbackSnapshot = await _firestore
            .collection('topics')
            .orderBy('videoCount', descending: true)
            .limit(6)
            .get();
        if (fallbackSnapshot.docs.isNotEmpty) {
          topicsList = fallbackSnapshot.docs
              .map(Topic.fromDocumentSnapshot)
              .toList();
        }
      }

      featuredTopics.assignAll(topicsList);
      _saveFeaturedTopicsToCache();
    } catch (e) {
      debugPrint('HomeController: Error fetching featured topics: $e');
    } finally {
      isLoadingFeaturedTopics.value = false;
    }
  }

  // ========================================================================
  // CAROUSEL LOADING
  // ========================================================================

  /// Fetch carousel videos (recommended, music, trending)
  Future<void> fetchCarouselVideos() async {
    await safeExecute(_fetchCarouselVideosInternal, showLoading: false);
  }

  /// Internal implementation for carousel fetching
  Future<void> _fetchCarouselVideosInternal() async {
    isCarouselLoading.value = true;

    try {
      // Parallel fetch all carousel categories in background
      // Use cache primarily for initial speed, then it naturally refreshes
      final results = await Future.wait([
        _fetchPublicVideos(), // Recommended
        _fetchCategoryVideos('Music'), // Music
        _fetchPublicVideos(), // Trending
      ]);

      // Fetch results
      recommendedVideos.assignAll(results[0]);
      musicVideos.assignAll(results[1]);
      trendingVideos.assignAll(results[2]);

      clearError();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error fetching carousel videos: $e');
      }
    } finally {
      isCarouselLoading.value = false;
    }
  }

  // ========================================================================
  // MAIN FEED LOADING (INFINITE SCROLL)
  // ========================================================================

  /// Fetch initial page of videos with current category filter
  Future<void> fetchInitialVideos() async {
    await safeExecute(_fetchInitialVideosInternal, showLoading: videos.isEmpty);
  }

  /// Internal implementation for initial video fetch
  Future<void> _fetchInitialVideosInternal() async {
    try {
      final isMainFeed = selectedCategory.value == 'All';
      if (!isMainFeed || videos.isEmpty) {
        isLoadingVideos.value = true;
        videos.clear();
      }

      _lastDocument = null;
      rxHasMore.value = true;

      // Try Server Feed first
      final currentUserId = _authService.user?.uid;
      final userProfile = Get.isRegistered<UserInterestProfileService>()
          ? Get.find<UserInterestProfileService>().profile.value
          : null;
      final feedAlgorithmService = Get.isRegistered<FeedAlgorithmService>()
          ? Get.find<FeedAlgorithmService>()
          : null;

      var fetchedFromServer = false;

      if (feedAlgorithmService != null &&
          feedAlgorithmService.isServerAvailable &&
          currentUserId != null &&
          currentUserId.isNotEmpty) {
        try {
          // 1. Try server-side ranked feed (primary)
          final serverVideos = await feedAlgorithmService.getPersonalizedFeed(
            userId: currentUserId,
            category: selectedCategory.value == 'All'
                ? null
                : selectedCategory.value,
          );

          // 2. Apply lightweight local adjustments only (NOT full rerank)
          final adjusted = feedAlgorithmService.applyLocalAdjustments(
            serverVideos,
            notInterestedVideoIds: userProfile?.notInterestedVideoIds,
            blockedChannelIds: userProfile?.blockedChannelIds,
            recentlyWatchedVideoIds: userProfile?.recentlyWatchedVideoIds,
          );

          // Handle flip coin
          final isFlipped =
              (selectedCategory.value == '🪙 Flip Coin') ||
              (Get.isRegistered<FlipCoinService>() &&
                  Get.find<FlipCoinService>().isHomeFlipped.value);

          if (isFlipped && Get.isRegistered<TruthworldAlgorithm>()) {
            final ranked = Get.find<TruthworldAlgorithm>().rankVideosOpposite(
              adjusted,
              RecommendationSurface.homeFeedAll,
              diversityConfig: DiversityConfig.homeFeed,
            );
            videos.assignAll(ranked.map((s) => s.video).toList());
          } else {
            videos.assignAll(adjusted);
          }

          if (isMainFeed) {
            _saveVideosToCache();
          }
          if (serverVideos.length < _pageSize) {
            rxHasMore.value = false;
          }
          fetchedFromServer = true;
        } catch (e) {
          // 3. Fallback: direct Firestore query + full client-side ranking
          debugPrint('Server feed unavailable, falling back to local: $e');
        }
      }

      if (!fetchedFromServer) {
        // NORMAL QUERY PATH: Standard per-category fetching
        final results = await _buildCategoryQuery().limit(_pageSize).get();

        debugPrint(
          'HomeController: Fetched ${results.docs.length} videos for category ${selectedCategory.value}',
        );

        if (results.docs.isNotEmpty) {
          _lastDocument = results.docs.last;
          final rawVideos = results.docs
              .map(Video.fromDocumentSnapshot)
              .toList()
              .sanitizeForFeed();

          final currentCat = selectedCategory.value;
          if (currentCat == '🔥 Trending' || currentCat == 'Trending') {
            rawVideos.sort((a, b) {
              final daysA = DateTime.now()
                  .difference(a.createdAt.toDate())
                  .inDays;
              final daysB = DateTime.now()
                  .difference(b.createdAt.toDate())
                  .inDays;
              final scoreA = (a.views + a.likes * 3) / (daysA + 1);
              final scoreB = (b.views + b.likes * 3) / (daysB + 1);
              return scoreB.compareTo(scoreA);
            });
            videos.assignAll(rawVideos);
          } else if (currentCat == '✨ New' || currentCat == 'New') {
            rawVideos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            videos.assignAll(rawVideos);
          } else if (currentCat == '⭐ Popular' || currentCat == 'Popular') {
            rawVideos.sort((a, b) => b.views.compareTo(a.views));
            videos.assignAll(rawVideos);
          } else if ((isMainFeed || selectedCategory.value == '🪙 Flip Coin') &&
              Get.isRegistered<TruthworldAlgorithm>()) {
            final algorithm = Get.find<TruthworldAlgorithm>();
            final isFlipped =
                (selectedCategory.value == '🪙 Flip Coin') ||
                (Get.isRegistered<FlipCoinService>() &&
                    Get.find<FlipCoinService>().isHomeFlipped.value);

            final ranked = isFlipped
                ? algorithm.rankVideosOpposite(
                    rawVideos,
                    RecommendationSurface.homeFeedAll,
                    diversityConfig: DiversityConfig.homeFeed,
                  )
                : algorithm.rankVideos(
                    rawVideos,
                    RecommendationSurface.homeFeedAll,
                    diversityConfig: DiversityConfig.homeFeed,
                  );
            final rankedVideos = ranked.map((s) => s.video).toList();
            videos.assignAll(
              rankedVideos.isNotEmpty ? rankedVideos : rawVideos,
            );
          } else {
            videos.assignAll(rawVideos);
          }

          if (isMainFeed) {
            _saveVideosToCache();
          }

          if (results.docs.length < _pageSize) {
            rxHasMore.value = false;
          }
        } else {
          // Fallback: Query videos collection directly if primary builder returns 0 docs
          try {
            final fallbackResults = await _firestore
                .collection('videos')
                .limit(_pageSize)
                .get();

            if (fallbackResults.docs.isNotEmpty) {
              _lastDocument = fallbackResults.docs.last;
              final fallbackVideos = fallbackResults.docs
                  .map(Video.fromDocumentSnapshot)
                  .where(VideoVisibilityPolicy.isVisibleForFeed)
                  .toList();

              if (fallbackVideos.isNotEmpty) {
                videos.assignAll(fallbackVideos);
              } else {
                videos.assignAll(
                  fallbackResults.docs
                      .map(Video.fromDocumentSnapshot)
                      .where((v) => v.status != VideoStatus.deleted)
                      .toList(),
                );
              }
            } else {
              videos.clear();
            }
          } catch (fbErr) {
            debugPrint('Fallback video query error: $fbErr');
            videos.clear();
          }
          rxHasMore.value = false;
        }
      } // End if (!fetchedFromServer)

      if (isMainFeed) {
        await fetchCommunityPosts();
      } else {
        communityPosts.clear();
      }
      mixHomeFeed();
      fetchAvailableCategories();

      clearError();
    } catch (e) {
      debugPrint('Error fetching initial videos: $e');
      setError('Failed to load videos: $e');
    } finally {
      isLoadingVideos.value = false;
    }
  }

  /// Fetch next page of videos for infinite scroll
  Future<void> fetchMoreVideos() async {
    if (isLoadingMore.value || !rxHasMore.value || _lastDocument == null) {
      return;
    }

    isLoadingMore.value = true;

    try {
      var query = _buildCategoryQuery();

      // Cursor: handles Aggregated feed loaded starts
      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      } else if (videos.isNotEmpty) {
        query = query.startAfter([videos.last.uploadedAt]);
      }

      final results = await query
          .limit(_pageSize)
          .get()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw const TimeoutException(
              message: 'Loading more videos',
            ),
          );

      if (results.docs.isNotEmpty) {
        _lastDocument = results.docs.last;
        final newVideos = results.docs.map(Video.fromDocumentSnapshot).toList();
        final combined = [...videos, ...newVideos].sanitizeForFeed();
        videos.assignAll(combined);

        // Stop pagination if fewer items than page size
        if (results.docs.length < _pageSize) {
          rxHasMore.value = false;
        }
      } else {
        rxHasMore.value = false;
      }

      mixHomeFeed();

      if (kDebugMode) {
        debugPrint(
          'HomeController: Loaded ${results.docs.length} more videos, total now: ${videos.length}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error fetching more videos: $e');
      }

      rxHasMore.value = false;
      // Don't show error on pagination failure, just stop
    } finally {
      isLoadingMore.value = false;
    }
  }

  // ========================================================================
  // HELPER METHODS - FIRESTORE QUERIES
  // ========================================================================

  /// Build base query for current category using VideoQueryBuilder
  Query _buildCategoryQuery() {
    return VideoQueryBuilder.publicVideos(
      _firestore,
      category: selectedCategory.value,
    );
  }

  /// Fetch public videos (helper for carousel)
  Future<List<Video>> _fetchPublicVideos({int limit = 10}) async {
    final results = await VideoQueryBuilder.publicVideos(
      _firestore,
      limit: limit,
    ).get();

    final rawList = results.docs.map(Video.fromDocumentSnapshot).toList();
    return rawList.sanitizeForRecommendation();
  }

  /// Fetch videos by category (helper for carousel)
  Future<List<Video>> _fetchCategoryVideos(
    String category, {
    int limit = 10,
  }) async {
    final results = await VideoQueryBuilder.publicVideos(
      _firestore,
      category: category,
      limit: limit,
    ).get();

    final rawList = results.docs.map(Video.fromDocumentSnapshot).toList();
    return rawList.sanitizeForRecommendation();
  }

  /// Fetch user's subscribed channels
  Future<void> fetchSubscribedChannels() async {
    final userId = _authService.user?.uid;
    if (userId == null) return;

    try {
      isLoadingSubscriptions.value = true;
      final subsSnapshot = await _firestore
          .collection('subscriptions')
          .where('userId', isEqualTo: userId)
          .getCacheFirst();

      final channelIds = subsSnapshot.docs
          .map((doc) => doc['channelId'] as String)
          .toList();

      if (channelIds.isEmpty) {
        subscribedChannelList.clear();
        return;
      }

      final channelsData = <Map<String, dynamic>>[];
      for (var i = 0; i < channelIds.length; i += 10) {
        final chunk = channelIds.sublist(
          i,
          i + 10 > channelIds.length ? channelIds.length : i + 10,
        );
        final channelsSnapshot = await _firestore
            .collection('channels')
            .where(FieldPath.documentId, whereIn: chunk)
            .getCacheFirst();

        for (final doc in channelsSnapshot.docs) {
          final data = doc.data();
          var avatarUrl = data['avatarUrl']?.toString() ?? '';
          if (avatarUrl.isEmpty) {
            avatarUrl =
                'https://ui-avatars.com/api/?name=${Uri.encodeComponent(data['channelName'] ?? 'Channel')}&background=random';
          }
          channelsData.add({
            'id': doc.id,
            'name': data['channelName'] ?? 'Unknown',
            'avatar': avatarUrl,
          });
        }
      }

      subscribedChannelList.assignAll(channelsData);
    } catch (e) {
      debugPrint('Error fetching subscribed channels: $e');
    } finally {
      isLoadingSubscriptions.value = false;
    }
  }

  // ========================================================================
  // AUTHENTICATION METHODS
  // ========================================================================

  /// Sign in with Google account
  /// Shows user-friendly error messages and handles retries
  Future<void> signInWithGoogle() async {
    try {
      isLoadingAuth.value = true;
      await _authService.signInWithGoogle();

      // No longer redirecting to dashboard directly after sign-in
      // If we are authenticated, just let the state reflecting on the home screen
      if (!_authService.isAuthenticated.value) {
        _showErrorWithRetry('Sign-in failed. Please try again.');
      }
    } on GoogleSignInException catch (e) {
      _handleGoogleSignInError(e);
    } catch (e) {
      _showErrorWithRetry('Sign-in failed. Please try again.');
    } finally {
      isLoadingAuth.value = false;
    }
  }

  /// Retry Google Sign-In with exponential backoff
  Future<void> retryGoogleSignIn() async {
    try {
      isLoadingAuth.value = true;
      await _authService.retryGoogleSignIn();

      if (!_authService.isAuthenticated.value) {
        _showErrorWithRetry('Sign-in failed. Please try again.');
      }
      // No redirection on success
    } catch (e) {
      _showErrorWithRetry('Sign-in failed after multiple attempts.');
    } finally {
      isLoadingAuth.value = false;
    }
  }

  /// Handle Google Sign-In specific errors
  void _handleGoogleSignInError(GoogleSignInException exception) {
    if (exception.code == 'user-cancelled' ||
        exception.code == 'popup-closed' ||
        exception.code == 'popup-closed-by-user') {
      if (kDebugMode) {
        debugPrint('ℹ️ Google Sign-In cancelled by user.');
      }
      return;
    }

    final displayMessage = exception.getDisplayMessage();

    if (exception.isRetryable) {
      // Show error with retry option
      _showErrorWithRetry(displayMessage);
    } else {
      // Show error without retry option
      Get.snackbar(
        'Sign-In Error',
        displayMessage,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFD32F2F),
        colorText: AppColors.textPrimary,
        duration: const Duration(seconds: 5),
        icon: const Icon(Icons.error, color: AppColors.textPrimary),
      );
    }

    if (kDebugMode) {
      debugPrint(
        'â Œ GoogleSignIn Error: ${exception.code} - ${exception.message}',
      );
    }
  }

  /// Show error message with retry button
  void _showErrorWithRetry(String message) {
    Get.snackbar(
      'Sign-In Error',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFFD32F2F),
      colorText: AppColors.textPrimary,
      duration: const Duration(seconds: 7),
      icon: const Icon(Icons.error, color: AppColors.textPrimary),
      mainButton: TextButton(
        onPressed: retryGoogleSignIn,
        child: const Text(
          'Retry',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Future<void> signOut() async {
    await _authService.logout();
  }

  Future<void> deleteAccount() async {}

  // ========================================================================
  // NAVIGATION METHODS
  // ========================================================================

  /// Handle tab change event
  void _onTabChanged() {
    if (tabController.indexIsChanging) {
      final categoryIndex = tabController.index;
      if (categoryIndex >= 0 && categoryIndex < availableCategories.length) {
        selectCategory(availableCategories[categoryIndex]);
      }
    }
  }

  /// Change tab by index
  void onTabChanged(int index) {
    if (index >= 0 && index < availableCategories.length) {
      tabController.animateTo(index);
    }
  }

  /// Handle side navigation selection
  void onSideNavItemSelect(int index) {
    sideNavSelectedIndex.value = index;
    _triggerSelectionAnimation();
  }

  /// Handle bottom navigation tap
  Future<void> onBottomNavItemTapped(int index) async {
    bottomNavSelectedIndex.value = index;
    _triggerSelectionAnimation();

    final isAtHome = Get.currentRoute == '/' || Get.currentRoute == '/home';

    switch (index) {
      case 0:
        sideNavSelectedIndex.value = indexHome;
        if (!isAtHome) {
          Get.offAllNamed<dynamic>('/');
        } else if (scrollController.hasClients) {
          scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
          );
        }
      case 1:
        sideNavSelectedIndex.value = indexExploreTopics;
        if (!isAtHome) {
          Get.offAllNamed<dynamic>('/');
        }
      case 2:
        sideNavSelectedIndex.value = indexDiscover;
        if (!isAtHome) {
          Get.offAllNamed<dynamic>('/');
        }
      case 3:
        if (!isAuthenticated) {
          await signInWithGoogle();
        }
        sideNavSelectedIndex.value = indexLibrary;
        if (!isAtHome) {
          Get.offAllNamed<dynamic>('/');
        }
    }
  }

  /// Select video category and reload videos
  void selectCategory(String category) {
    if (selectedCategory.value == category) {
      return; // Already on this category
    }

    selectedCategory.value = category;

    // Sync tab controller
    final categoryIndex = availableCategories.indexOf(category);
    if (categoryIndex != -1) {
      tabController.animateTo(categoryIndex);
    }

    // Reset pagination
    videos.clear();
    _lastDocument = null;
    rxHasMore.value = true;

    // Scroll to top
    if (scrollController.hasClients) {
      scrollController.jumpTo(0);
    }

    // Load new category
    fetchInitialVideos();
    _triggerSelectionAnimation();
  }

  // ========================================================================
  // CATEGORY FILTERING (AT LEAST 2 VIDEOS)
  // ========================================================================

  /// Match raw category string with standard category list or return Title Case
  String _capitalizeCategory(String cat) {
    if (cat.isEmpty) return cat;
    final trimmed = cat.trim();
    return categories.firstWhere(
      (c) => c.toLowerCase() == trimmed.toLowerCase(),
      orElse: () => trimmed[0].toUpperCase() + trimmed.substring(1),
    );
  }

  /// Fetch category counts and filter to categories with at least 2 videos
  Future<void> fetchAvailableCategories() async {
    try {
      final categoryCounts = <String, int>{};

      // 1. Count categories from locally loaded/cached feed videos
      for (final video in videos) {
        final cat = video.category.trim();
        if (cat.isNotEmpty && cat.toLowerCase() != 'all') {
          final normalized = _capitalizeCategory(cat);
          categoryCounts[normalized] = (categoryCounts[normalized] ?? 0) + 1;
        }
      }

      // 2. Query Firestore videos collection for broader category stats
      final snapshot = await _firestore
          .collection('videos')
          .where('status', isEqualTo: VideoVisibilityPolicy.publicStatus.name)
          .limit(500)
          .get();

      final firestoreCounts = <String, int>{};
      for (final doc in snapshot.docs) {
        final rawCat = (doc.data()['category'] as String?)?.trim();
        if (rawCat != null &&
            rawCat.isNotEmpty &&
            rawCat.toLowerCase() != 'all') {
          final normalized = _capitalizeCategory(rawCat);
          firestoreCounts[normalized] = (firestoreCounts[normalized] ?? 0) + 1;
        }
      }

      final mergedCounts = firestoreCounts.isNotEmpty
          ? firestoreCounts
          : categoryCounts;

      // Filter to categories that have AT LEAST 2 videos
      final qualifyingCategories = <String>[];
      for (final cat in categories) {
        if ((mergedCounts[cat] ?? 0) >= 2) {
          qualifyingCategories.add(cat);
        }
      }

      mergedCounts.forEach((cat, count) {
        if (count >= 2 && !qualifyingCategories.contains(cat) && cat != 'All') {
          qualifyingCategories.add(cat);
        }
      });

      availableCategories.assignAll(
        _personalizedSortCategories(qualifyingCategories),
      );
      _reinitializeTabController();
    } catch (e) {
      debugPrint('HomeController: Error fetching category counts: $e');
      _updateCategoriesFromLoadedVideos();
    }
  }

  List<String> _personalizedSortCategories(List<String> inputCategories) {
    final sorted = List<String>.from(inputCategories);

    final watchHistoryCategories = <String>[];
    if (Get.isRegistered<UserInterestProfileService>()) {
      final profile = Get.find<UserInterestProfileService>().profile.value;
      if (profile != null && profile.categoryAffinities.isNotEmpty) {
        final sortedEntries = profile.categoryAffinities.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        for (final entry in sortedEntries) {
          if (entry.value > 0) {
            final catName = _capitalizeCategory(entry.key);
            if (!watchHistoryCategories.contains(catName) &&
                catName.isNotEmpty) {
              watchHistoryCategories.add(catName);
            }
          }
        }

        sorted.sort((a, b) {
          final scoreA = profile.categoryAffinities[a] ?? 0.0;
          final scoreB = profile.categoryAffinities[b] ?? 0.0;
          return scoreB.compareTo(scoreA);
        });
      }
    }

    final fixedHead = [
      'All',
      'Subscriptions',
      '🔥 Trending',
      '✨ New',
      '⭐ Popular',
      'Posts',
      '🪙 Flip Coin',
    ];

    final result = <String>[...fixedHead];

    for (final cat in watchHistoryCategories) {
      if (!result.contains(cat) && sorted.contains(cat)) {
        result.add(cat);
      }
    }

    for (final cat in sorted) {
      if (!result.contains(cat)) {
        result.add(cat);
      }
    }

    return result;
  }

  void _updateCategoriesFromLoadedVideos() {
    final categoryCounts = <String, int>{};
    for (final video in videos) {
      final cat = video.category.trim();
      if (cat.isNotEmpty && cat.toLowerCase() != 'all') {
        final normalized = _capitalizeCategory(cat);
        categoryCounts[normalized] = (categoryCounts[normalized] ?? 0) + 1;
      }
    }
    final qualifyingCategories = <String>[];
    for (final cat in categories) {
      if ((categoryCounts[cat] ?? 0) >= 2) {
        qualifyingCategories.add(cat);
      }
    }
    categoryCounts.forEach((cat, count) {
      if (count >= 2 && !qualifyingCategories.contains(cat) && cat != 'All') {
        qualifyingCategories.add(cat);
      }
    });

    availableCategories.assignAll(
      _personalizedSortCategories(qualifyingCategories),
    );
    _reinitializeTabController();
  }

  // ========================================================================
  // SCROLL & ANIMATION HELPERS
  // ========================================================================

  /// Handle scroll notifications from any tab
  void onScrollNotification(ScrollUpdateNotification notification) {
    // Ignore horizontal scrolling
    if (notification.metrics.axis != Axis.vertical) {
      return;
    }

    // Ignore ballistic/inertial scrolling - only react to user drag
    if (notification.dragDetails == null) {
      return;
    }

    final delta = notification.scrollDelta ?? 0;

    // Ignore tiny scroll movements to prevent flickering
    if (delta.abs() < kScrollThreshold) return;

    // Always show at top
    if (notification.metrics.pixels <= 0) {
      if (!showBottomNav.value) {
        showBottomNav.value = true;
      }
      return;
    }

    // Hide on scroll down, show on scroll up
    if (delta > 0) {
      if (showBottomNav.value) {
        showBottomNav.value = false;
      }
    } else {
      if (!showBottomNav.value) {
        showBottomNav.value = true;
      }
    }
  }

  /// Listen for scroll events to implement infinite scroll
  void _scrollListener() {
    if (!scrollController.hasClients) return;

    final position = scrollController.position;

    // Show/Hide bottom nav based on scroll direction
    final currentScroll = position.pixels;
    if (currentScroll > _lastScrollPosition && currentScroll > 50) {
      // Scrolling down
      if (showBottomNav.value) showBottomNav.value = false;
    } else if (currentScroll < _lastScrollPosition) {
      // Scrolling up
      if (!showBottomNav.value) showBottomNav.value = true;
    }
    _lastScrollPosition = currentScroll;

    final scrollPercentage = (position.pixels / position.maxScrollExtent) * 100;

    // Trigger load more when 90% scrolled and not already loading
    if (scrollPercentage >= _loadMoreThreshold &&
        !isLoadingMore.value &&
        rxHasMore.value) {
      fetchMoreVideos();
    }
  }

  /// Trigger selection animation
  void _triggerSelectionAnimation() {
    if (_isDisposed) return;
    try {
      _scaleAnimationController.reset();
      _scaleAnimationController.forward();
    } catch (_) {}
  }

  // ========================================================================
  // GETTERS
  // ========================================================================

  /// Show sign-in required snackbar
  void showSignInSnackbar() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showWarning('Please sign in to continue');
    });
  }

  /// Check if main feed is loading
  RxBool get isLoadingFeed => isLoadingVideos;

  @override
  bool get isItemsEmpty => homeFeedItems.isEmpty && videos.isEmpty;

  /// Total video count in feed
  int get videoCount => videos.length;

  /// Check if user is authenticated
  bool get isAuthenticated => _authService.isAuthenticated.value;

  // ========================================================================
  // SPECIAL PAGE NAVIGATION
  // ========================================================================

  /// Navigate to playlist detail within home screen
  void navigateToPlaylistDetail(dynamic playlist) {
    selectedPlaylist.value = playlist;
    sideNavSelectedIndex.value = indexPlaylistDetail;
  }

  /// Navigate to channel detail within home screen
  void navigateToChannelDetail(Channel channel) {
    selectedChannelForDetail.value = channel;
    sideNavSelectedIndex.value = indexChannelDetail;
  }

  /// Go back from special page to previous index
  void goBackFromSpecialPage(int previousIndex) {
    selectedPlaylist.value = null;
    selectedChannelForDetail.value = null;
    sideNavSelectedIndex.value = previousIndex;
  }

  /// Navigate to user's channel or creation wizard
  void navigateToYourChannel() {
    if (!isAuthenticated) {
      showSignInSnackbar();
      return;
    }
    if (AuthService.to.hasChannel.value && AuthService.to.userChannel != null) {
      StudioLauncher.openStudio();
    } else {
      Get.toNamed('/channelscreen');
    }
  }

  /// Navigate to Watch Later playlist detail
  Future<void> navigateToWatchLater() async {
    if (!isAuthenticated) {
      showSignInSnackbar();
      return;
    }
    final playlistCtrl = Get.isRegistered<PlaylistController>()
        ? Get.find<PlaylistController>()
        : Get.put(PlaylistController());

    var watchLater = playlistCtrl.getWatchLaterPlaylist();
    watchLater ??= await playlistCtrl.createPlayList('Watch Later');
    if (watchLater != null) {
      navigateToPlaylistDetail(watchLater);
    }
  }

  /// Get current user email
  String? get userEmail => _authService.user?.email;

  /// Get current user display name
  String? get userName => _authService.user?.displayName;

  Future<void> fetchCommunityPosts() async {
    try {
      final snapshot = await _firestore
          .collection('Community')
          .where('visibility', isEqualTo: 'Public')
          .limit(50)
          .get();

      final posts = snapshot.docs
          .map((doc) => CommunityPostModel.fromMap(doc.data()))
          .toList();

      posts.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));

      communityPosts.assignAll(posts.take(10));
    } catch (e) {
      debugPrint('Error fetching community posts: $e');
    }
  }

  void mixHomeFeed() {
    final mixed = <dynamic>[];
    var videoIndex = 0;
    var postIndex = 0;

    // Limit community posts on home page to max 3 items
    final limitedPosts = communityPosts.take(3).toList();

    while (videoIndex < videos.length || postIndex < limitedPosts.length) {
      for (var i = 0; i < 6 && videoIndex < videos.length; i++) {
        mixed.add(videos[videoIndex++]);
      }
      if (postIndex < limitedPosts.length && videos.isNotEmpty) {
        mixed.add(limitedPosts[postIndex++]);
      } else if (videos.isEmpty && postIndex < 1) {
        mixed.add(limitedPosts[postIndex++]);
      }
    }

    homeFeedItems.assignAll(mixed);
  }

  /// Select filter bar from horizontal header
  Future<void> selectFilterBar(String bar) async {
    activeFilterBar.value = bar;
    if (bar == 'All') {
      selectedCategory.value = 'All';
      await _fetchInitialVideosInternal();
    } else if (bar == 'Trending') {
      selectedCategory.value = 'All';
      videos.assignAll(trendingVideos);
      mixHomeFeed();
    } else if (bar == 'Topics') {
      // Highlights topics in feed
      await fetchFeaturedTopics();
    } else if (bar == 'Videos') {
      communityPosts.clear();
      homeFeedItems.assignAll(videos);
    } else {
      // Bar is a specific category name or watch history filter
      await fetchCategoryContent(bar);
    }
  }

  /// Fetch videos, topics, and community posts for a selected category
  Future<void> fetchCategoryContent(String category) async {
    selectedCategory.value = category;
    activeFilterBar.value = category;
    isLoadingVideos.value = true;
    videos.clear();
    _lastDocument = null;
    rxHasMore.value = true;

    try {
      if (category == 'All') {
        await _fetchInitialVideosInternal();
        return;
      }

      // 1. Fetch videos for category
      final videoDocs = await VideoQueryBuilder.publicVideos(
        _firestore,
        category: category,
        limit: _pageSize,
      ).get();

      var catVideos = <Video>[];
      if (videoDocs.docs.isNotEmpty) {
        _lastDocument = videoDocs.docs.last;
        catVideos = videoDocs.docs
            .map(Video.fromDocumentSnapshot)
            .toList()
            .sanitizeForFeed();
      }

      if (catVideos.isEmpty) {
        final fallbackDocs = await _firestore
            .collection('videos')
            .where('category', isEqualTo: category)
            .limit(_pageSize)
            .get();
        catVideos = fallbackDocs.docs
            .map(Video.fromDocumentSnapshot)
            .where(VideoVisibilityPolicy.isVisibleForFeed)
            .toList();
      }

      if (Get.isRegistered<TruthworldAlgorithm>()) {
        final algorithm = Get.find<TruthworldAlgorithm>();
        final ranked = algorithm.rankVideos(
          catVideos,
          RecommendationSurface.homeFeedCategory,
        );
        final rankedCatVideos = ranked.map((s) => s.video).toList();
        videos.assignAll(
          rankedCatVideos.isNotEmpty ? rankedCatVideos : catVideos,
        );
      } else {
        videos.assignAll(catVideos);
      }

      // 2. Fetch topics for category
      try {
        final topicDocs = await _firestore
            .collection('topics')
            .where('category', isEqualTo: category)
            .limit(10)
            .get();
        if (topicDocs.docs.isNotEmpty) {
          final catTopics = topicDocs.docs
              .map(Topic.fromDocumentSnapshot)
              .toList();
          featuredTopics.assignAll(catTopics);
        }
      } catch (e) {
        debugPrint('Error fetching category topics: $e');
      }

      // 3. Fetch community posts for category
      try {
        final postDocs = await _firestore
            .collection('Community')
            .where('visibility', isEqualTo: 'Public')
            .limit(20)
            .get();
        final posts = postDocs.docs
            .map((doc) => CommunityPostModel.fromMap(doc.data()))
            .where((p) => p.selectedCategory == category || category == 'All')
            .toList();
        communityPosts.assignAll(posts.take(5));
      } catch (e) {
        debugPrint('Error fetching category community posts: $e');
      }

      mixHomeFeed();
    } catch (e) {
      debugPrint('Error fetching category content: $e');
    } finally {
      isLoadingVideos.value = false;
    }
  }

  /// Refresh feature exactly how YouTube handles it (fetch new topics, videos, & community posts)
  Future<void> refreshHomeFeed() async {
    try {
      if (selectedCategory.value != 'All') {
        await fetchCategoryContent(selectedCategory.value);
      } else {
        await _fetchInitialVideosInternal();
        await fetchFeaturedTopics();
      }
    } catch (e) {
      debugPrint('Error refreshing home feed: $e');
    }
  }
}
