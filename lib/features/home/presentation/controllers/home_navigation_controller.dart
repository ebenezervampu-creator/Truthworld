import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/utils/studio_launcher.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/home/presentation/controllers/home_discovery_controller.dart';

class HomeNavigationController extends BaseController with GetTickerProviderStateMixin {
  final AuthService _authService = Get.find<AuthService>();

  static const int indexHome = 0;
  static const int indexSubscriptions = 1;
  static const int indexTrending = 2;
  static const int indexDiscover = 3;
  static const int indexLibrary = 4;
  static const int indexHistory = 5;
  static const int indexYourVideos = 6;
  static const int indexLikedVideos = 7;
  static const int indexDownloads = 8;
  static const int indexWatchLater = 9;
  static const int indexPlaylists = 10;
  static const int indexFollowingTopics = 18;
  static const int indexClips = 17;
  static const int indexPlaylistDetail = 99;
  static const int indexChannelDetail = 100;
  static const int indexSettings = 11;
  static const int indexFeedback = 13;
  static const int indexAbout = 14;
  static const int indexPrivacy = 15;
  static const int indexTerms = 16;
  static const int indexExploreTopics = 19;
  static const int indexCommunityGuidelines = 20;

  final RxInt sideNavSelectedIndex = indexHome.obs;
  final RxInt bottomNavSelectedIndex = 0.obs;
  final RxBool showBottomNav = true.obs;
  
  final selectedPlaylist = Rxn<dynamic>();
  final selectedChannelForDetail = Rxn<Channel>();
  
  TabController? _tabController;
  bool _isTabControllerDisposed = true;

  TabController get tabController {
    if ((_tabController == null || _isTabControllerDisposed) && !_isDisposed) {
      _initializeTabController();
    }
    if (_tabController == null) {
      _tabController = TabController(length: 1, vsync: this);
      _isTabControllerDisposed = false;
      _tabController!.addListener(_onTabChanged);
    }
    return _tabController!;
  }
  
  final RxBool isLoadingAuth = false.obs;
  final RxBool isNavigating = false.obs;
  
  late AnimationController _fadeAnimationController;
  late AnimationController _slideAnimationController;
  late AnimationController _scaleAnimationController;
  bool _isDisposed = false;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  Animation<double> get fadeAnimation => _fadeAnimation;
  Animation<Offset> get slideAnimation => _slideAnimation;
  Animation<double> get scaleAnimation => _scaleAnimation;

  @override
  void onInit() {
    super.onInit();
    _isDisposed = false;
    _initializeAnimations();
    _setupBottomNavSync();
    _initializeTabController();
  }

  @override
  void onReady() {
    super.onReady();
    if (_tabController == null || _isTabControllerDisposed) {
      _initializeTabController();
    }
  }

  @override
  void onClose() {
    _isDisposed = true;
    _disposeAnimations();
    _disposeTabController();
    super.onClose();
  }

  void _initializeAnimations() {
    _isDisposed = false;
    _fadeAnimationController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    _slideAnimationController = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    _scaleAnimationController = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _fadeAnimationController, curve: Curves.easeOutCubic));
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(CurvedAnimation(parent: _slideAnimationController, curve: Curves.easeOutCubic));
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1).animate(CurvedAnimation(parent: _scaleAnimationController, curve: Curves.easeOutBack));

    _fadeAnimationController.forward();
    _slideAnimationController.forward();
    _scaleAnimationController.forward();
  }

  void _disposeAnimations() {
    _fadeAnimationController.dispose();
    _slideAnimationController.dispose();
    _scaleAnimationController.dispose();
  }

  void _initializeTabController() {
    if (_isDisposed) return;
    try {
      var len = 1;
      if (Get.isRegistered<HomeDiscoveryController>()) {
        final availableCategories = Get.find<HomeDiscoveryController>().availableCategories;
        if (availableCategories.isNotEmpty) {
          len = availableCategories.length;
        }
      }
      _disposeTabController();
      _tabController = TabController(length: len, vsync: this);
      _isTabControllerDisposed = false;
      _tabController!.addListener(_onTabChanged);
    } catch (e, s) {
      _isTabControllerDisposed = true;
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'HomeNavigationController.initializeTabController',
      );
    }
  }

  void _disposeTabController() {
    if (_tabController != null && !_isTabControllerDisposed) {
      try {
        _tabController!.removeListener(_onTabChanged);
        _tabController!.dispose();
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'HomeNavigationController.disposeTabController',
        );
      } finally {
        _isTabControllerDisposed = true;
      }
    }
  }

  void reinitializeTabController() {
    if (_isDisposed) return;
    try {
      var newLength = 1;
      if (Get.isRegistered<HomeDiscoveryController>()) {
        final availableCategories = Get.find<HomeDiscoveryController>().availableCategories;
        if (availableCategories.isNotEmpty) {
          newLength = availableCategories.length;
        }
      }
      if (_tabController == null || _isTabControllerDisposed) {
        _initializeTabController();
        return;
      }
      if (_tabController!.length != newLength) {
        final currentIndex = _tabController!.index.clamp(0, newLength - 1);
        _disposeTabController();
        _tabController = TabController(length: newLength, initialIndex: currentIndex, vsync: this);
        _isTabControllerDisposed = false;
        _tabController!.addListener(_onTabChanged);
      }
    } catch (e, s) {
      _isTabControllerDisposed = true;
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'HomeNavigationController.reinitializeTabController',
      );
    }
  }

  void _setupBottomNavSync() {
    trackSubscription(sideNavSelectedIndex.listen((index) {
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
    }));
  }

  void _onTabChanged() {
    if (_isDisposed || _isTabControllerDisposed || _tabController == null) return;
    try {
      if (_tabController!.indexIsChanging && Get.isRegistered<HomeDiscoveryController>()) {
        final categoryIndex = _tabController!.index;
        final discovery = Get.find<HomeDiscoveryController>();
        if (categoryIndex >= 0 && categoryIndex < discovery.availableCategories.length) {
          discovery.selectCategory(discovery.availableCategories[categoryIndex]);
        }
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'HomeNavigationController._onTabChanged',
      );
    }
  }

  void onTabChanged(int index) {
    if (_isDisposed) return;
    if (!Get.isRegistered<HomeDiscoveryController>()) return;
    final discovery = Get.find<HomeDiscoveryController>();
    if (_tabController == null || _isTabControllerDisposed) {
      _initializeTabController();
    } else if (_tabController!.length != discovery.availableCategories.length) {
      reinitializeTabController();
    }
    if (_isDisposed || _isTabControllerDisposed || _tabController == null) return;
    if (index >= 0 && index < _tabController!.length) {
      try {
        _tabController!.animateTo(index);
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'HomeNavigationController.onTabChanged.animateTo',
        );
      }
    }
  }

  void syncTabToCategory(String category) {
    if (_isDisposed) return;
    if (!Get.isRegistered<HomeDiscoveryController>()) return;
    final discovery = Get.find<HomeDiscoveryController>();
    if (_tabController == null || _isTabControllerDisposed) {
      _initializeTabController();
    } else if (_tabController!.length != discovery.availableCategories.length) {
      reinitializeTabController();
    }
    if (_isDisposed || _isTabControllerDisposed || _tabController == null) return;
    final categoryIndex = discovery.availableCategories.indexOf(category);
    if (categoryIndex >= 0 && categoryIndex < _tabController!.length) {
      try {
        _tabController!.animateTo(categoryIndex);
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'HomeNavigationController.syncTabToCategory.animateTo',
        );
      }
    }
  }

  void onSideNavItemSelect(int index) {
    sideNavSelectedIndex.value = index;
    triggerSelectionAnimation();
  }

  Future<void> onBottomNavItemTapped(int index) async {
    bottomNavSelectedIndex.value = index;
    triggerSelectionAnimation();

    final isAtHome = Get.currentRoute == '/' || Get.currentRoute == '/home';

    switch (index) {
      case 0:
        sideNavSelectedIndex.value = indexHome;
        if (!isAtHome) Get.offAllNamed<dynamic>('/');
      case 1:
        sideNavSelectedIndex.value = indexExploreTopics;
        if (!isAtHome) Get.offAllNamed<dynamic>('/');
      case 2:
        sideNavSelectedIndex.value = indexDiscover;
        if (!isAtHome) Get.offAllNamed<dynamic>('/');
      case 3:
        if (!_authService.isAuthenticated.value) {
          _authService.signInWithGoogle();
        }
        sideNavSelectedIndex.value = indexLibrary;
        if (!isAtHome) Get.offAllNamed<dynamic>('/');
    }
  }

  void triggerSelectionAnimation() {
    if (_isDisposed) return;
    try {
      _scaleAnimationController.reset();
      _scaleAnimationController.forward();
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'HomeNavigationController.triggerSelectionAnimation',
      );
    }
  }

  void navigateToPlaylistDetail(dynamic playlist) {
    selectedPlaylist.value = playlist;
    sideNavSelectedIndex.value = indexPlaylistDetail;
  }

  void navigateToChannelDetail(Channel channel) {
    selectedChannelForDetail.value = channel;
    sideNavSelectedIndex.value = indexChannelDetail;
  }

  void goBackFromSpecialPage(int previousIndex) {
    selectedPlaylist.value = null;
    selectedChannelForDetail.value = null;
    sideNavSelectedIndex.value = previousIndex;
  }

  Future<void> navigateToYourChannel() async {
    if (!_authService.isAuthenticated.value) {
      showSignInSnackbar();
      return;
    }
    await StudioLauncher.openStudio();
  }

  Future<void> navigateToWatchLater() async {
    if (!_authService.isAuthenticated.value) {
      showSignInSnackbar();
      return;
    }
    sideNavSelectedIndex.value = indexWatchLater;
  }

  void showSignInSnackbar() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppSnackbar.info(
        'Please sign in to continue.',
        title: 'Sign-In Required',
      );
    });
  }
}
