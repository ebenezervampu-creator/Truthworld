import 'package:truthworld/core/constants/firestore_collections.dart';
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

// ========================================================================
// COLOR CONSTANTS
// ========================================================================

const Color darkBackground = AppColors.bgPage;
const Color darkSurface = AppColors.bgInput;
const Color darksurfaceContainerHighest = AppColors.bgSurface;
const Color darkOnSurface = Color(0xFFE8E8E8);
const Color darkonSurfaceVariant = Color(0xFFB8B8B8);
const Color greenAccent = Color(0xFF1DB954);
const Color greenSecondary = Color(0xFF1ED760);
const Color greenTertiary = Color(0xFF00D84A);
const Color errorColor = Color(0xFFFF6B6B);

/// Home screen controller managing navigation, videos, and user authentication
class HomeController extends BaseController with GetTickerProviderStateMixin {
  // ========================================================================
  // FIREBASE SERVICES
  // ========================================================================

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ========================================================================
  // NAVIGATION STATE
  // ========================================================================

  final sideNavSelectedIndex = 0.obs;
  final bottomNavSelectedIndex = 0.obs;
  final selectedCategory = 'All'.obs;

  late TabController tabController;

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

  // ========================================================================
  // AUTHENTICATION STATE
  // ========================================================================

  final currentUser = Rxn<User>();
  final isLoadingAuth = false.obs;

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

  static const int _pageSize = 10;
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
  // LIFECYCLE
  // ========================================================================

  @override
  void onInit() {
    super.onInit();
    _initializeAnimations();
    _setupAuthListener();
    _bindScrollListener();
    _loadInitialData();
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
      length: categories.length,
      vsync: this,
    );

    tabController.addListener(_onTabChanged);
  }

  /// Setup authentication state listener
  void _setupAuthListener() {
    _auth.authStateChanges().listen((user) {
      currentUser.value = user;
      isLoadingAuth.value = false;
    });
  }

  /// Bind scroll listener for infinite scroll
  void _bindScrollListener() {
    scrollController.addListener(_scrollListener);
  }

  /// Load initial data (videos and carousels)
  void _loadInitialData() {
    fetchInitialVideos();
    fetchCarouselVideos();
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
    try {
      isCarouselLoading.value = true;

      // Parallel fetch all carousel categories
      final results = await Future.wait([
        _fetchPublicVideos(), // Recommended
        _fetchCategoryVideos('Music'), // Music
        _fetchPublicVideos(), // Trending
      ]);

      recommendedVideos.assignAll(results[0]);
      musicVideos.assignAll(results[1]);
      trendingVideos.assignAll(results[2]);

      clearError();

      if (kDebugMode) {
        debugPrint(
          'HomeController: Loaded carousels - recommended: ${results[0].length}, music: ${results[1].length}, trending: ${results[2].length}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error fetching carousel videos: $e');
      }

      handleError(
        FirestoreException(
          message: 'Failed to load carousel videos',
          originalException: e,
        ),
      );
    } finally {
      isCarouselLoading.value = false;
    }
  }

  // ========================================================================
  // MAIN FEED LOADING (INFINITE SCROLL)
  // ========================================================================

  /// Fetch initial page of videos with current category filter
  Future<void> fetchInitialVideos() async {
    await safeExecute(_fetchInitialVideosInternal);
  }

  /// Internal implementation for initial video fetch
  Future<void> _fetchInitialVideosInternal() async {
    try {
      videos.clear();
      _lastDocument = null;
      rxHasMore.value = true;

      final results = await _buildCategoryQuery()
          .limit(_pageSize)
          .get()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw const TimeoutException(
              message: 'Loading videos',
            ),
          );

      if (results.docs.isNotEmpty) {
        _lastDocument = results.docs.last;
        final newVideos = results.docs.map(Video.fromDocumentSnapshot).toList();
        videos.assignAll(newVideos);

        // Check if we got fewer items than page size (no more pages)
        if (results.docs.length < _pageSize) {
          rxHasMore.value = false;
        }
      } else {
        rxHasMore.value = false;
      }

      clearError();

      if (kDebugMode) {
        debugPrint(
          'HomeController: Loaded ${videos.length} initial videos for category ${selectedCategory.value}',
        );
      }
    } on TimeoutException {
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error fetching initial videos: $e');
      }

      handleError(
        FirestoreException(
          message: 'Failed to load videos',
          originalException: e,
        ),
      );

      rxHasMore.value = false;
    }
  }

  /// Fetch next page of videos for infinite scroll
  Future<void> fetchMoreVideos() async {
    if (isLoadingMore.value || !rxHasMore.value || _lastDocument == null) {
      return;
    }

    isLoadingMore.value = true;

    try {
      final results = await _buildCategoryQuery()
          .startAfterDocument(_lastDocument!)
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
    Query query = _firestore
        .collection(FirestoreCollections.videos)
        .where('visibility', isEqualTo: 'Public')
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
        .collection(FirestoreCollections.videos)
        .where('visibility', isEqualTo: 'Public')
        .orderBy('uploadedAt', descending: true)
        .limit(limit)
        .get();

    return results.docs.map(Video.fromDocumentSnapshot).toList();
  }

  /// Fetch videos by category (helper for carousel)
  Future<List<Video>> _fetchCategoryVideos(
    String category, {
    int limit = 10,
  }) async {
    final results = await _firestore
        .collection(FirestoreCollections.videos)
        .where('visibility', isEqualTo: 'Public')
        .where('category', isEqualTo: category)
        .limit(limit)
        .get();

    return results.docs.map(Video.fromDocumentSnapshot).toList();
  }

  /// Sign out current user
  Future<void> signOut() async {
    await safeExecute(_signOutInternal, showLoading: false);
  }

  /// Internal sign-out implementation
  Future<void> _signOutInternal() async {
    try {
      await _auth.signOut();
      showSuccess('Signed out successfully');

      if (kDebugMode) {
        debugPrint('HomeController: User signed out');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error signing out: $e');
      }

      throw AuthException(message: 'Failed to sign out', originalException: e);
    }
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

    switch (index) {
      case 0:
        if (Get.currentRoute != '/home') {
          Get.toNamed('/home');
        }
      case 1:
        if (currentUser.value == null) {
          showWarning('Please sign in to access subscriptions');
        } else if (Get.currentRoute != '/subscriptions') {
          Get.toNamed('/subscriptions');
        }
      case 2:
        if (currentUser.value == null) {
          showWarning('Please sign in to access library');
        } else if (Get.currentRoute != '/library') {
          Get.toNamed('/library');
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
  bool get isAuthenticated => currentUser.value != null;

  /// Get current user email
  String? get userEmail => currentUser.value?.email;

  /// Get current user display name
  String? get userName => currentUser.value?.displayName;
}
