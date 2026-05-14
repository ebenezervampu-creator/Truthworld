import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:get_storage/get_storage.dart';

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
  static const String _kVideoCacheKey = 'home_videos_cache';

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

  // ========================================================================
  // AUTHENTICATION STATE
  // ========================================================================

  final sideNavSelectedIndex = indexHome.obs;
  final bottomNavSelectedIndex = 0.obs;
  final selectedCategory = 'All'.obs;

  // Special page data
  final selectedPlaylist = Rxn<dynamic>(); // Stores playlist data for detail view
  final selectedChannelForDetail = Rxn<Channel>(); // Stores channel data for detail view

  late TabController tabController;

  // ========================================================================
  // AUTHENTICATION STATE
  // ========================================================================

  final isLoadingAuth = false.obs;

  /// Compatibility getter: now linked to real AuthService
  Rxn<User> get currentUser => _authService.currentUser;

  /// Navigation state tracking
  final isNavigating = false.obs;

  // ========================================================================
  // ANIMATION CONTROLLERS AND ANIMATIONS
  // ========================================================================

  late AnimationController _fadeAnimationController;
  late AnimationController _slideAnimationController;
  late AnimationController _scaleAnimationController;

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

  final videos = <Video>[].obs;
  final isLoadingVideos = true.obs;
  final isLoadingMore = false.obs;
  final rxHasMore = true.obs;
  DocumentSnapshot? _lastDocument;

  static const int _pageSize = 24;
  static const int _loadMoreThreshold = 90; // Percentage of scroll position

  final scrollController = ScrollController();

  // ========================================================================
  // VIDEO STATE - CAROUSELS
  // ========================================================================

  final recommendedVideos = <Video>[].obs;
  final musicVideos = <Video>[].obs;
  final trendingVideos = <Video>[].obs;
  final isCarouselLoading = true.obs;

  // ========================================================================
  // SUBSCRIPTIONS STATE
  // ========================================================================
  final subscribedChannels = <String, dynamic>{}.obs; // Map for faster lookup
  final subscribedChannelList = <Map<String, dynamic>>[].obs;
  final isLoadingSubscriptions = false.obs;
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
  }

  void _setupConnectivityListener() {
    _connectivitySubscription = Get.find<ConnectivityService>()
        .onConnectivityChanged
        .listen((results) {
      final isConnected = results.any((r) => r != ConnectivityResult.none);
      // If we were showing an error or empty state due to offline, reload
      if (isConnected && (videos.isEmpty || trendingVideos.isEmpty)) {
        debugPrint('[HomeController] 🌐 Internet restored. Reloading feed...');
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
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );

    // Setup slide animation
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0.0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _slideAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );

    // Setup scale animation
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
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
      length: categories.length,
      vsync: this,
      initialIndex: 0,
    );

    tabController.addListener(_onTabChanged);
  }

  /// Bind scroll listener for infinite scroll
  void _bindScrollListener() {
    scrollController.addListener(_scrollListener);
  }

  /// Load initial data (videos and carousels)
  void _loadInitialData() {
    _loadCachedVideos();
    fetchInitialVideos();
    fetchCarouselVideos();
  }

  /// Load videos from local storage for instant perceived speed
  void _loadCachedVideos() {
    try {
      final cachedData = _storage.read<List>(_kVideoCacheKey);
      if (cachedData != null && videos.isEmpty) {
        final cachedVideos = cachedData
            .map((data) => Video.fromMap(Map<String, dynamic>.from(data)))
            .toList();
        videos.assignAll(cachedVideos);
        isLoadingVideos.value = false;
        debugPrint('HomeController: Loaded ${videos.length} videos from cache');
      }
    } catch (e) {
      debugPrint('HomeController: Cache load error: $e');
    }
  }

  /// Save videos to local storage
  void _saveVideosToCache() {
    try {
      final dataToCache = videos.take(20).map((v) => v.toMap()).toList();
      _storage.write(_kVideoCacheKey, dataToCache);
    } catch (e) {
      debugPrint('HomeController: Cache save error: $e');
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
        _fetchPublicVideos(limit: 10), // Recommended
        _fetchCategoryVideos('Music', limit: 10), // Music
        _fetchPublicVideos(limit: 10), // Trending
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
    await safeExecute(_fetchInitialVideosInternal, showLoading: true);
  }

  /// Internal implementation for initial video fetch
  Future<void> _fetchInitialVideosInternal() async {
    try {
      isLoadingVideos.value = true;

      _lastDocument = null;
      rxHasMore.value = true;
      videos.clear();


      // NORMAL QUERY PATH: Standard per-category fetching
      final results = await _buildCategoryQuery()
          .limit(_pageSize)
          .get();

      debugPrint('HomeController: Fetched ${results.docs.length} videos for category ${selectedCategory.value}');

      if (results.docs.isNotEmpty) {
        _lastDocument = results.docs.last;
        final newVideos = results.docs
            .map((doc) => Video.fromDocumentSnapshot(doc))
            .toList();

        videos.assignAll(newVideos);
        _saveVideosToCache();

        if (results.docs.length < _pageSize) {
          rxHasMore.value = false;
        }
      } else {
        rxHasMore.value = false;
      }

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
      Query query = _buildCategoryQuery();

      // Ã°Å¸â€™Â¡ Optimized Cursor: handles Aggregated feed loaded starts
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
            onTimeout: () => throw TimeoutException(
              message: 'Loading more videos',
              originalException: null,
            ),
          );

      if (results.docs.isNotEmpty) {
        _lastDocument = results.docs.last;
        final newVideos = results.docs
            .map((doc) => Video.fromDocumentSnapshot(doc))
            .toList();
        videos.addAll(newVideos);

        // Stop pagination if fewer items than page size
        if (results.docs.length < _pageSize) {
          rxHasMore.value = false;
        }
      } else {
        rxHasMore.value = false;
      }

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

  /// Build base query for current category
  Query _buildCategoryQuery() {
    Query query = _firestore.collection('videos')
        // Try Public/published first, but broaden if 0 results
        .orderBy('uploadedAt', descending: true);

    // Apply category filter if not "All"
    if (selectedCategory.value != 'All') {
      query = query.where('category', isEqualTo: selectedCategory.value);
    }

    return query;
  }

  /// Fetch public videos (helper for carousel)
  Future<List<Video>> _fetchPublicVideos({int limit = 10}) async {
    final results = await _firestore
        .collection('videos')
        // .where('visibility', isEqualTo: 'Public')
        // .where('status', isEqualTo: 'published')
        // .orderBy('uploadedAt', descending: true)
        .limit(limit)
        .get();

    return results.docs.map((doc) => Video.fromDocumentSnapshot(doc)).toList();
  }

  /// Fetch videos by category (helper for carousel)
  Future<List<Video>> _fetchCategoryVideos(
    String category, {
    int limit = 10,
  }) async {
    final results = await _firestore
        .collection('videos')
        //.where('visibility', isEqualTo: 'Public')
        //.where('status', isEqualTo: 'published')
        // .where('category', isEqualTo: category)
        .limit(limit)
        .get();

    return results.docs.map((doc) => Video.fromDocumentSnapshot(doc)).toList();
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
          .get();

      final List<String> channelIds = subsSnapshot.docs
          .map((doc) => doc['channelId'] as String)
          .toList();

      if (channelIds.isEmpty) {
        subscribedChannelList.clear();
        return;
      }

      final channelsSnapshot = await _firestore
          .collection('channels')
          .where(FieldPath.documentId, whereIn: channelIds)
          .get();

      final channelsData = channelsSnapshot.docs.map((doc) {
        final data = doc.data();
        String avatarUrl = data['avatarUrl']?.toString() ?? '';
        if (avatarUrl.isEmpty) {
          avatarUrl =
              'https://ui-avatars.com/api/?name=${Uri.encodeComponent(data['channelName'] ?? 'Channel')}&background=random';
        }
        return {
          'id': doc.id,
          'name': data['channelName'] ?? 'Unknown',
          'avatar': avatarUrl,
        };
      }).toList();

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
      await _authService.retryGoogleSignIn(maxRetries: 2);

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
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
        icon: const Icon(Icons.error, color: Colors.white),
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
      colorText: Colors.white,
      duration: const Duration(seconds: 7),
      icon: const Icon(Icons.error, color: Colors.white),
      mainButton: TextButton(
        onPressed: retryGoogleSignIn,
        child: const Text(
          'Retry',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
      if (categoryIndex >= 0 && categoryIndex < categories.length) {
        selectCategory(categories[categoryIndex]);
      }
    }
  }

  /// Change tab by index
  void onTabChanged(int index) {
    if (index >= 0 && index < categories.length) {
      tabController.animateTo(index);
    }
  }

  /// Handle side navigation selection
  void onSideNavItemSelect(int index) {
    sideNavSelectedIndex.value = index;
    _triggerSelectionAnimation();
  }

  /// Handle bottom navigation tap
  void onBottomNavItemTapped(int index) {
    bottomNavSelectedIndex.value = index;
    _triggerSelectionAnimation();

    final bool isAtHome =
        Get.currentRoute == '/' || Get.currentRoute == '/home';

    switch (index) {
      case 0:
        sideNavSelectedIndex.value = indexHome;
        if (!isAtHome) {
          Get.offAllNamed('/');
        } else if (scrollController.hasClients) {
          scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
          );
        }
        break;
      case 1:
        sideNavSelectedIndex.value = indexSubscriptions;
        if (!isAtHome) {
          Get.offAllNamed('/home');
        }
        break;
      case 2:
        sideNavSelectedIndex.value = indexLibrary;
        if (!isAtHome) {
          Get.offAllNamed('/home');
        }
        break;
      case 3:
        sideNavSelectedIndex.value = indexWatchLater;
        if (!isAtHome) {
          Get.offAllNamed('/home');
        }
        break;
      case 4:
        if (Get.currentRoute != '/history') {
          if (isAtHome) {
            Get.toNamed('/history');
          } else {
            Get.offNamed('/history');
          }
        }
        break;
    }
  }

  /// Select video category and reload videos
  void selectCategory(String category) {
    if (selectedCategory.value == category) {
      return; // Already on this category
    }

    selectedCategory.value = category;

    // Sync tab controller
    final categoryIndex = categories.indexOf(category);
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

    if (kDebugMode) {
      debugPrint('HomeController: Selected category $category');
    }
  }

  // ========================================================================
  // SCROLL & ANIMATION HELPERS
  // ========================================================================

  /// Listen for scroll events to implement infinite scroll
  void _scrollListener() {
    if (!scrollController.hasClients) return;

    final position = scrollController.position;
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
    _scaleAnimationController.reset();
    _scaleAnimationController.forward();
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

  /// Get current user email
  String? get userEmail => _authService.user?.email;

  /// Get current user display name
  String? get userName => _authService.user?.displayName;
}




