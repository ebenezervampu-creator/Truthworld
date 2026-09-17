import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/core/utils/firestore_cache_extension.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/community/data/models/community_post_model.dart';
import 'package:truthworld/features/home/presentation/controllers/home_discovery_controller.dart';
import 'package:truthworld/features/home/presentation/controllers/home_feed_controller.dart';
import 'package:truthworld/features/home/presentation/controllers/home_navigation_controller.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/video/data/models/video.dart';
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

class HomeController extends BaseController {
  final AuthService _authService = Get.find<AuthService>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sub-controllers
  late final HomeFeedController feed;
  late final HomeNavigationController nav;
  late final HomeDiscoveryController discovery;

  // Static constants
  static const int indexHome = HomeNavigationController.indexHome;
  static const int indexSubscriptions = HomeNavigationController.indexSubscriptions;
  static const int indexTrending = HomeNavigationController.indexTrending;
  static const int indexDiscover = HomeNavigationController.indexDiscover;
  static const int indexLibrary = HomeNavigationController.indexLibrary;
  static const int indexHistory = HomeNavigationController.indexHistory;
  static const int indexYourVideos = HomeNavigationController.indexYourVideos;
  static const int indexLikedVideos = HomeNavigationController.indexLikedVideos;
  static const int indexDownloads = HomeNavigationController.indexDownloads;
  static const int indexWatchLater = HomeNavigationController.indexWatchLater;
  static const int indexPlaylists = HomeNavigationController.indexPlaylists;
  static const int indexFollowingTopics = HomeNavigationController.indexFollowingTopics;
  static const int indexClips = HomeNavigationController.indexClips;
  static const int indexPlaylistDetail = HomeNavigationController.indexPlaylistDetail;
  static const int indexChannelDetail = HomeNavigationController.indexChannelDetail;
  static const int indexSettings = HomeNavigationController.indexSettings;
  static const int indexFeedback = HomeNavigationController.indexFeedback;
  static const int indexAbout = HomeNavigationController.indexAbout;
  static const int indexPrivacy = HomeNavigationController.indexPrivacy;
  static const int indexTerms = HomeNavigationController.indexTerms;
  static const int indexExploreTopics = HomeNavigationController.indexExploreTopics;
  static const int indexCommunityGuidelines = HomeNavigationController.indexCommunityGuidelines;

  static const List<String> categories = HomeDiscoveryController.categories;
  static const List<String> primaryFilterBars = HomeDiscoveryController.primaryFilterBars;

  // Library state
  final RxBool hasWatchHistory = true.obs;
  final RxBool hasPlaylists = true.obs;
  final RxBool hasFollowedTopics = true.obs;
  final RxBool hasWatchLater = true.obs;
  final RxBool hasLikedVideos = true.obs;
  final RxBool hasUploadedVideos = true.obs;
  final RxBool hasClips = true.obs;
  final RxBool hasDownloads = true.obs;

  final RxBool isLoadingAuth = false.obs;
  StreamSubscription? _connectivitySubscription;
  StreamSubscription? _downloadsListSub;

  @override
  void onInit() {
    super.onInit();
    discovery = Get.put(HomeDiscoveryController());
    nav = Get.put(HomeNavigationController());
    feed = Get.put(HomeFeedController());

    _setupConnectivityListener();

    trackSubscription(_authService.currentUser.listen((u) {
      if (u != null && !u.isAnonymous) {
        _checkUserLibraryData(u.uid);
        discovery.fetchSubscribedChannels();
      } else {
        _resetLibraryData();
        discovery.subscribedChannelList.clear();
      }
    }, onError: (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'HomeController.currentUser');
    }));

    final currentUid = _authService.user?.uid;
    if (currentUid != null &&
        currentUid.isNotEmpty &&
        !(_authService.user?.isAnonymous ?? true)) {
      _checkUserLibraryData(currentUid);
    }
  }

  @override
  void onClose() {
    _connectivitySubscription?.cancel();
    _downloadsListSub?.cancel();
    _resetLibraryData();
    if (Get.isRegistered<HomeDiscoveryController>()) {
      Get.delete<HomeDiscoveryController>(force: true);
    }
    if (Get.isRegistered<HomeNavigationController>()) {
      Get.delete<HomeNavigationController>(force: true);
    }
    if (Get.isRegistered<HomeFeedController>()) {
      Get.delete<HomeFeedController>(force: true);
    }
    super.onClose();
  }

  Future<void> fetchInitialVideos() => feed.fetchInitialVideos();

  void _setupConnectivityListener() {
    _connectivitySubscription = Get.find<ConnectivityService>().onConnectivityChanged.listen((results) {
      final isConnected = results.any((r) => r != ConnectivityResult.none);
      if (isConnected && (feed.videos.isEmpty || feed.trendingVideos.isEmpty)) {
        debugPrint('[HomeController] 🌐 Internet restored. Reloading feed...');
        feed.refreshHomeFeed();
        discovery.fetchFeaturedTopics();
        discovery.fetchSubscribedChannels();
      }
    }, onError: (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'HomeController.onConnectivityChanged');
    });
    trackSubscription(_connectivitySubscription!);
  }

  Future<void> _checkUserLibraryData(String userId) async {
    try {
      final results = await Future.wait([
        _firestore.collection('users').doc(userId).collection('watch_history').limit(1).getCacheFirst(),
        _firestore.collection('users').doc(userId).collection('playlists').limit(1).getCacheFirst(),
        _firestore.collection('users').doc(userId).collection('savedTopics').limit(1).getCacheFirst(),
        _firestore.collection('users').doc(userId).collection('watch_later').limit(1).getCacheFirst(),
        _firestore.collection('videos').where('likedBy', arrayContains: userId).limit(1).getCacheFirst(),
        _firestore.collection('videos').where('ownerId', isEqualTo: userId).limit(1).getCacheFirst(),
        _firestore.collection('users').doc(userId).collection('clips').limit(1).getCacheFirst(),
      ]);

      hasWatchHistory.value = results[0].docs.isNotEmpty;
      hasPlaylists.value = results[1].docs.isNotEmpty;
      hasFollowedTopics.value = results[2].docs.isNotEmpty;
      hasWatchLater.value = results[3].docs.isNotEmpty;
      hasLikedVideos.value = results[4].docs.isNotEmpty;
      hasUploadedVideos.value = results[5].docs.isNotEmpty;
      hasClips.value = results[6].docs.isNotEmpty;

      _setupDownloadsListener();
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'HomeController._checkUserLibraryData');
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
    }, onError: (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'HomeController.downloadsListener');
    });
    trackSubscription(_downloadsListSub!);
  }

  void _resetLibraryData() {
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

  // Auth Facade
  Rxn<User> get currentUser => _authService.currentUser;
  bool get isAuthenticated => _authService.isAuthenticated.value;
  String? get userEmail => _authService.user?.email;
  String? get userName => _authService.user?.displayName;
  
  Future<void> signInWithGoogle() async {
    try {
      isLoadingAuth.value = true;
      await _authService.signInWithGoogle();
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
  
  Future<void> retryGoogleSignIn() async {
    try {
      isLoadingAuth.value = true;
      await _authService.retryGoogleSignIn();
      if (!_authService.isAuthenticated.value) {
        _showErrorWithRetry('Sign-in failed. Please try again.');
      }
    } catch (e) {
      _showErrorWithRetry('Sign-in failed after multiple attempts.');
    } finally {
      isLoadingAuth.value = false;
    }
  }

  void _handleGoogleSignInError(GoogleSignInException exception) {
    if (exception.code == 'user-cancelled' || exception.code == 'popup-closed' || exception.code == 'popup-closed-by-user') return;
    final displayMessage = exception.getDisplayMessage();
    if (exception.isRetryable) {
      _showErrorWithRetry(displayMessage);
    } else {
      AppSnackbar.error(displayMessage, title: 'Sign-In Failed');
    }
  }

  void _showErrorWithRetry(String message) {
    AppSnackbar.error(
      message,
      title: 'Sign-In Failed',
      actionLabel: 'Retry',
      onAction: retryGoogleSignIn,
      duration: const Duration(seconds: 7),
    );
  }

  Future<void> signOut() => _authService.logout();
  Future<void> deleteAccount() async {}

  // Discovery Facade
  RxList<Topic> get featuredTopics => discovery.featuredTopics;
  RxBool get isLoadingFeaturedTopics => discovery.isLoadingFeaturedTopics;
  RxList<Topic> get forYouTopics => discovery.forYouTopics;
  RxBool get isLoadingForYouTopics => discovery.isLoadingForYouTopics;
  RxString get selectedCategory => discovery.selectedCategory;
  RxString get activeFilterBar => discovery.activeFilterBar;
  RxList<String> get availableCategories => discovery.availableCategories;
  RxMap<String, dynamic> get subscribedChannels => discovery.subscribedChannels;
  RxList<Map<String, dynamic>> get subscribedChannelList => discovery.subscribedChannelList;
  RxBool get isLoadingSubscriptions => discovery.isLoadingSubscriptions;
  
  void selectCategory(String cat) => discovery.selectCategory(cat);
  Future<void> selectFilterBar(String bar) => discovery.selectFilterBar(bar);

  // Feed Facade
  RxList<Video> get videos => feed.videos;
  RxList<CommunityPostModel> get communityPosts => feed.communityPosts;
  RxList<dynamic> get homeFeedItems => feed.homeFeedItems;
  RxBool get isLoadingVideos => feed.isLoadingVideos;
  RxBool get isLoadingMore => feed.isLoadingMore;
  RxBool get rxHasMore => feed.rxHasMore;
  ScrollController get scrollController => feed.scrollController;
  RxList<Video> get recommendedVideos => feed.recommendedVideos;
  RxList<Video> get musicVideos => feed.musicVideos;
  RxList<Video> get trendingVideos => feed.trendingVideos;
  RxBool get isCarouselLoading => feed.isCarouselLoading;
  RxBool get isLoadingFeed => feed.isLoadingVideos;
  
  @override
  bool get isItemsEmpty => feed.homeFeedItems.isEmpty && feed.videos.isEmpty;
  int get videoCount => feed.videos.length;

  Future<void> fetchMoreVideos() => feed.fetchMoreVideos();
  Future<void> refreshHomeFeed() => feed.refreshHomeFeed();
  void onScrollNotification(ScrollUpdateNotification n) => feed.onScrollNotification(n);

  // Navigation Facade
  RxInt get sideNavSelectedIndex => nav.sideNavSelectedIndex;
  RxInt get bottomNavSelectedIndex => nav.bottomNavSelectedIndex;
  RxBool get showBottomNav => nav.showBottomNav;
  RxBool get isNavigating => nav.isNavigating;
  Rxn<dynamic> get selectedPlaylist => nav.selectedPlaylist;
  Rxn<Channel> get selectedChannelForDetail => nav.selectedChannelForDetail;
  TabController get tabController => nav.tabController;

  Animation<double> get fadeAnimation => nav.fadeAnimation;
  Animation<Offset> get slideAnimation => nav.slideAnimation;
  Animation<double> get scaleAnimation => nav.scaleAnimation;

  void onTabChanged(int index) => nav.onTabChanged(index);
  void onSideNavItemSelect(int index) => nav.onSideNavItemSelect(index);
  Future<void> onBottomNavItemTapped(int index) => nav.onBottomNavItemTapped(index);
  void navigateToPlaylistDetail(dynamic playlist) => nav.navigateToPlaylistDetail(playlist);
  void navigateToChannelDetail(Channel channel) => nav.navigateToChannelDetail(channel);
  void goBackFromSpecialPage(int previousIndex) => nav.goBackFromSpecialPage(previousIndex);
  void navigateToYourChannel() => nav.navigateToYourChannel();
  Future<void> navigateToWatchLater() => nav.navigateToWatchLater();
  void showSignInSnackbar() => nav.showSignInSnackbar();
}
