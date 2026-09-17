import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/core/widgets/app_logo.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/topic_management_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/analytics/analytics_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audience_page.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks_page.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/category_insights_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/chapters_page.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/content_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/copyright_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/creator_intelligence_page.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/customization_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/dashboard_comments_page.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/drafts_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/memberships_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/monetization_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/playlists_management_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/sections/sections.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/studio_settings_page.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/subtitles_page.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/topic_management_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/trash_restore_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification_dashboard_page.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/video_management.dart';
import 'package:truthworld/features/topics/presentation/widgets/create_topic_dialog.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

export 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  DashboardController? _controller;
  DashboardController get controller {
    if (_controller != null) return _controller!;
    if (Get.isRegistered<DashboardController>()) {
      _controller = Get.find<DashboardController>();
      return _controller!;
    }
    _controller = Get.put(DashboardController());
    return _controller!;
  }

  set controller(DashboardController value) {
    _controller = value;
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();

  Worker? _authWorker;
  Worker? _channelWorker;

  // Get channel from arguments, controller, or AuthService
  dynamic get channel {
    final args = Get.arguments;
    if (args is Map && args['channel'] != null) {
      final ch = args['channel'];
      if (ch is Channel) return ch;
      if (ch is Map) {
        return Channel.fromMap(
          Map<String, dynamic>.from(ch),
          (ch['id'] ?? '').toString(),
        );
      }
      return ch;
    }
    if (Get.isRegistered<DashboardController>()) {
      final activeCtrl = Get.find<DashboardController>();
      if (activeCtrl.currentChannel.value != null) {
        return activeCtrl.currentChannel.value;
      }
    }
    if (AuthService.to.userChannel != null) {
      return AuthService.to.userChannel;
    }
    return null;
  }

  String _getChannelId(dynamic ch) {
    if (ch == null) return '';
    if (ch is Channel) return ch.id;
    if (ch is Map) return (ch['id'] ?? '').toString();
    if (ch is DocumentSnapshot) return ch.id;
    return '';
  }

  String _getOwnerId(dynamic ch) {
    if (ch == null) return '';
    if (ch is Channel) return ch.ownerId;
    if (ch is Map) return (ch['ownerId'] ?? ch['userId'] ?? '').toString();
    if (ch is DocumentSnapshot) {
      final data = ch.data() as Map<String, dynamic>?;
      return (data?['ownerId'] ?? data?['userId'] ?? '').toString();
    }
    return '';
  }

  String _getChannelName(dynamic ch) {
    if (ch == null) return 'Unknown Channel';
    if (ch is Channel) return ch.name.isNotEmpty ? ch.name : 'Unknown Channel';
    if (ch is Map) {
      final val = ch['channelName'] ?? ch['name'];
      return (val != null && val.toString().isNotEmpty)
          ? val.toString()
          : 'Unknown Channel';
    }
    if (ch is DocumentSnapshot) {
      final data = ch.data() as Map<String, dynamic>?;
      final val = data?['channelName'] ?? data?['name'];
      return (val != null && val.toString().isNotEmpty)
          ? val.toString()
          : 'Unknown Channel';
    }
    return 'Unknown Channel';
  }

  final RxBool isSelectingDefault = true.obs;

  @override
  void initState() {
    super.initState();
    _initializeAnimations(); // Initialize early to avoid LateInitializationError in dispose
    final initChannelId = _getChannelId(channel);
    controller = Get.isRegistered<DashboardController>()
        ? Get.find<DashboardController>()
        : Get.put(DashboardController(channelId: initChannelId));
    unawaited(_resolveChannelAndInit());

    _authWorker = ever(AuthService.to.isAuthenticated, (isAuth) {
      if (isAuth && !isSelectingDefault.value && channel == null) {
        unawaited(_resolveChannelAndInit());
      }
    });

    _channelWorker = ever(AuthService.to.rxUserChannel, (ch) {
      if (ch != null) {
        if (Get.isRegistered<DashboardController>()) {
          controller.currentChannel.value = ch;
        }
      }
    });
  }

  Future<void> _resolveChannelAndInit() async {
    isSelectingDefault.value = true;
    try {
      final authService = AuthService.to;
      var user = FirebaseAuth.instance.currentUser;

      // Allow brief moment for auth token restoration on cold start / new tab
      if (user == null && !authService.isAuthenticated.value) {
        await Future.delayed(const Duration(milliseconds: 300));
        user = FirebaseAuth.instance.currentUser;
      }

      if (user == null && !authService.isAuthenticated.value) {
        isSelectingDefault.value = false;
        return;
      }

      dynamic resolvedChannel = channel;

      // 1. If channel not in args, check AuthService.to.userChannel
      resolvedChannel ??= authService.userChannel;

      // 2. Authoritative async channel resolution via ensureChannelLoaded
      resolvedChannel ??= await authService.ensureChannelLoaded();

      // 3. Fallback direct Firestore lookup if still unresolved
      if (resolvedChannel == null && user != null) {
        try {
          var snapshot = await FirebaseFirestore.instance
              .collection(FirestoreCollections.channels)
              .where('ownerId', isEqualTo: user.uid)
              .limit(1)
              .get();

          if (snapshot.docs.isEmpty) {
            snapshot = await FirebaseFirestore.instance
                .collection(FirestoreCollections.channels)
                .where('userId', isEqualTo: user.uid)
                .limit(1)
                .get();
          }

          if (snapshot.docs.isNotEmpty) {
            final activeDocs = snapshot.docs
                .map(Channel.fromDocumentSnapshot)
                .where((c) => c.status != ChannelStatus.deleted)
                .toList();
            if (activeDocs.isNotEmpty) {
              resolvedChannel = activeDocs.first;
              authService.setUserChannel(resolvedChannel);
            }
          }

          // Check user document for channelId reference
          if (resolvedChannel == null) {
            final userDoc = await FirebaseFirestore.instance
                .collection(FirestoreCollections.users)
                .doc(user.uid)
                .get();
            final chId = userDoc.data()?['channelId'] as String?;
            if (chId != null && chId.isNotEmpty) {
              final chDoc = await FirebaseFirestore.instance
                  .collection(FirestoreCollections.channels)
                  .doc(chId)
                  .get();
              if (chDoc.exists && chDoc.data() != null) {
                final ch = Channel.fromDocumentSnapshot(chDoc);
                if (ch.status != ChannelStatus.deleted) {
                  resolvedChannel = ch;
                  authService.setUserChannel(resolvedChannel);
                }
              }
            }
          }
        } on Object catch (e, stackTrace) {
          ErrorHandler.log(
            e,
            stackTrace: stackTrace,
            tag: 'DashboardScreen.resolveChannelAndInit.fetchChannel',
          );
        }
      }

      // 4. Ensure AuthService has this channel tracked
      if (resolvedChannel != null && authService.userChannel == null) {
        if (resolvedChannel is Channel) {
          authService.setUserChannel(resolvedChannel);
        } else if (resolvedChannel is Map) {
          authService.setUserChannel(
            Channel.fromMap(
              Map<String, dynamic>.from(resolvedChannel),
              (resolvedChannel['id'] ?? '').toString(),
            ),
          );
        }
      }

      // 5. Only redirect to channel creation if confirmed authenticated with 0 channels
      if (resolvedChannel == null &&
          !authService.hasChannel.value &&
          authService.isAuthenticated.value) {
        isSelectingDefault.value = false;
        await Get.offAllNamed<dynamic>('/channelscreen');
        return;
      }

      // 4. Resolve DashboardController with channelId
      final channelId = _getChannelId(resolvedChannel);
      if (Get.isRegistered<DashboardController>()) {
        controller = Get.find<DashboardController>();
        if (channelId.isNotEmpty && controller.channelId != channelId) {
          controller.updateChannelId(channelId);
        }
      } else {
        controller = Get.put(DashboardController(channelId: channelId));
      }

      if (controller.currentChannel.value == null) {
        if (resolvedChannel is Channel) {
          controller.currentChannel.value = resolvedChannel;
        } else if (resolvedChannel is Map) {
          controller.currentChannel.value = Channel.fromMap(
            Map<String, dynamic>.from(resolvedChannel),
            (resolvedChannel['id'] ?? channelId).toString(),
          );
        }
      }

      final args = Get.arguments;
      final tabIndex = args is Map ? args['tab'] as int? : null;
      if (tabIndex != null) {
        controller.selectedIndex.value = tabIndex;
      } else {
        final currentRoute = Get.currentRoute.toLowerCase();
        final tabParam = (Get.parameters['tab'] ?? '').toLowerCase();
        if (currentRoute.contains('/chapters') ||
            tabParam == 'chapters' ||
            tabParam == '11') {
          controller.selectedIndex.value = 11;
        } else if (currentRoute.contains('/trash') ||
            tabParam == 'trash' ||
            tabParam == '13') {
          controller.selectedIndex.value = 13;
        } else if (currentRoute.contains('/drafts') ||
            tabParam == 'drafts' ||
            tabParam == '20') {
          controller.selectedIndex.value = 20;
        }
      }

      if (!Get.isRegistered<VideoManagementController>()) {
        Get.put(VideoManagementController());
      }
    } on Object catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'DashboardScreen.resolveChannelAndInit',
      );
      if (!Get.isRegistered<DashboardController>()) {
        controller = Get.put(DashboardController());
      } else {
        controller = Get.find<DashboardController>();
      }
      if (!Get.isRegistered<VideoManagementController>()) {
        Get.put(VideoManagementController());
      }
    } finally {
      isSelectingDefault.value = false;
      _startAnimations();
    }
  }

  // Animation Controllers
  late AnimationController _staggeredAnimationController;
  late AnimationController _drawerAnimationController;
  late AnimationController _statsAnimationController;
  late AnimationController _chartAnimationController;
  Timer? _statsTimer;
  Timer? _chartTimer;

  // Animations
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _drawerAnimation;
  late Animation<double> _statsAnimation;
  late Animation<double> _chartAnimation;

  void _initializeAnimations() {
    _staggeredAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _drawerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _statsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _chartAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _staggeredAnimationController,
        curve: const Interval(0, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _staggeredAnimationController,
            curve: const Interval(0.2, 0.8, curve: Curves.easeOutBack),
          ),
        );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(
        parent: _staggeredAnimationController,
        curve: const Interval(0.4, 1, curve: Curves.elasticOut),
      ),
    );

    _drawerAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _drawerAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _statsAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _statsAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _chartAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _chartAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  void _startAnimations() {
    if (!mounted) return;
    _staggeredAnimationController.forward();
    _drawerAnimationController.forward();

    _statsTimer?.cancel();
    _statsTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        _statsAnimationController.forward();
      }
    });

    _chartTimer?.cancel();
    _chartTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) {
        _chartAnimationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _statsTimer?.cancel();
    _chartTimer?.cancel();
    _authWorker?.dispose();
    _channelWorker?.dispose();
    _searchController.dispose();
    _staggeredAnimationController.dispose();
    _drawerAnimationController.dispose();
    _statsAnimationController.dispose();
    _chartAnimationController.dispose();
    if (Get.isRegistered<DashboardController>()) {
      Get.delete<DashboardController>();
    }
    super.dispose();
  }

  // Responsive breakpoints
  bool get isMobile => MediaQuery.of(context).size.width < 600;
  bool get isTablet =>
      MediaQuery.of(context).size.width >= 600 &&
      MediaQuery.of(context).size.width < 1024;
  bool get isDesktop => MediaQuery.of(context).size.width >= 1024;

  double get horizontalPadding {
    if (isDesktop) return 32;
    if (isTablet) return 24;
    return 16;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!AuthService.to.isAuthenticated.value) {
        return _buildFallbackLoginScreen();
      }

      if (isSelectingDefault.value) {
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                Color(0xFF6366F1),
              ),
            ),
          ),
        );
      }

      final isDarkMode = Theme.of(context).brightness == Brightness.dark;

      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: isDarkMode ? AppColors.bgPage : AppColors.bgPage,
        appBar: _buildCreatorAppBar(
          isDarkMode: isDarkMode,
          isDesktop: isDesktop,
          isMobile: isMobile,
          scaffoldKey: _scaffoldKey,
        ),
        drawer: isDesktop ? null : _buildMobileDrawer(isDarkMode),
        body: Row(
          children: [
            if (isDesktop) _buildDesktopSidebar(isDarkMode),
            Expanded(child: _buildMainContent(isDarkMode)),
          ],
        ),
      );
    });
  }

  AppBar _buildCreatorAppBar({
    required bool isDarkMode,
    required bool isDesktop,
    required bool isMobile,
    required GlobalKey<ScaffoldState> scaffoldKey,
  }) {
    return AppBar(
      backgroundColor: isDarkMode ? AppColors.bgInput : AppColors.textPrimary,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      toolbarHeight: 64,
      centerTitle: false,
      titleSpacing: isMobile ? 4 : null,
      leading: isDesktop
          ? null
          : IconButton(
              icon: Icon(
                Icons.menu_rounded,
                color: isDarkMode
                    ? AppColors.textPrimary
                    : Colors.black,
              ),
              onPressed: () => scaffoldKey.currentState?.openDrawer(),
              tooltip: 'Menu',
            ),
      title: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back,
              size: 20,
              color: isDarkMode
                  ? AppColors.textSecondary
                  : Colors.black,
            ),
            onPressed: () => Get.offAllNamed('/home'),
            tooltip: 'Back to Home',
          ),
          if (!isMobile) ...[
            const AppLogo(
              size: 34,
              borderRadius: 8,
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              isMobile ? 'Studio' : 'Creator Studio',
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(
                fontSize: isMobile ? 18 : 20,
                fontWeight: FontWeight.w700,
                color: isDarkMode
                    ? AppColors.textPrimary
                    : Colors.black,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
      actions: [
        // Search field for desktop
        if (isDesktop) ...[
          _buildSearchField(isDarkMode),
          const SizedBox(width: 16),
        ],

        // Notifications
        _buildActionButton(
          icon: Icons.notifications_none_rounded,
          onPressed: () => controller.setSelectedIndex(16),
          isDarkMode: isDarkMode,
          tooltip: 'Creator Intelligence',
        ),

        SizedBox(width: isMobile ? 4 : 8),

        // Upload Video Button
        _buildActionButton(
          icon: Icons.video_call_rounded,
          label: isDesktop ? 'Upload' : '',
          onPressed: () => Get.toNamed('/upload'),
          isDarkMode: isDarkMode,
          isPrimary: true,
          tooltip: 'Upload Video',
        ),

        SizedBox(width: isMobile ? 4 : 8),

        // Google Account Selector
        _buildGoogleAccountSelector(isDarkMode),

        SizedBox(width: isMobile ? 8 : 16),
      ],
    );
  }

  // Search Field Widget
  Widget _buildSearchField(bool isDarkMode) {
    return DashboardSearchField(
      searchController: _searchController,
      isDarkMode: isDarkMode,
      onChanged: controller.setSearchQuery,
      onClear: () => controller.setSearchQuery(''),
    );
  }

  // Action Button Widget
  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onPressed,
    required bool isDarkMode,
    String label = '',
    bool isPrimary = false,
    String? tooltip,
  }) {
    return DashboardActionButton(
      icon: icon,
      onPressed: onPressed,
      isDarkMode: isDarkMode,
      label: label,
      isPrimary: isPrimary,
      tooltip: tooltip,
    );
  }

  // Google Account Selector Widget
  Widget _buildGoogleAccountSelector(bool isDarkMode) {
    return DashboardGoogleAccountSelector(
      isDarkMode: isDarkMode,
      onSignIn: () {
        HapticFeedback.lightImpact();
        _handleGoogleSignIn();
      },
    );
  }

  // Handle Google Sign In
  Future<void> _handleGoogleSignIn() async {
    try {
      await AuthService.to.signInWithGoogle();
      if (!mounted) return;

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        AppSnackbar.success(
          'Signed in as ${user.email}',
        );
        await _resolveChannelAndInit();
      } else {
        isSelectingDefault.value = false;
      }
    } catch (e) {
      isSelectingDefault.value = false;
      if (e is GoogleSignInUserCancelledException ||
          (e is AuthException && e.code == 'user-cancelled')) {
        return;
      }
      var message = 'Failed to sign in';
      if (e is GoogleSignInException) {
        message = e.getDisplayMessage();
      }

      AppSnackbar.error(
        message,
      );
    }
  }

  // Handle Sign Out
  Future<void> _handleSignOut() async {
    try {
      await AuthService.to.signOut();
      AppSnackbar.success(
        'You have been successfully signed out.',
      );
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error(
        'Unable to sign out. Please try again.',
      );
    }
  }

  // Sidebar Widgets
  Widget _buildDesktopSidebar(bool isDarkMode) {
    return DashboardDesktopSidebar(
      controller: controller,
      isDarkMode: isDarkMode,
      drawerAnimation: _drawerAnimation,
      onSignOut: _handleSignOut,
    );
  }

  Widget _buildSidebarHeader(bool isDarkMode) {
    return DashboardSidebarHeader(
      controller: controller,
      isDarkMode: isDarkMode,
    );
  }

  Widget _buildSidebarMenu(bool isDarkMode) {
    return DashboardSidebarMenu(
      controller: controller,
      isDarkMode: isDarkMode,
      onSignOut: _handleSignOut,
    );
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required String label,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDarkMode,
  }) {
    return DashboardSidebarItem(
      icon: icon,
      label: label,
      color: color,
      isSelected: isSelected,
      onTap: onTap,
      isDarkMode: isDarkMode,
      isDrawerExpanded: controller.isDrawerExpanded.value,
    );
  }

  Widget _buildMobileDrawer(bool isDarkMode) {
    return DashboardMobileDrawer(
      controller: controller,
      isDarkMode: isDarkMode,
      onSignOut: _handleSignOut,
    );
  }

  Widget _buildMainContent(bool isDarkMode) {
    final currentChannel = channel;
    final channelId = _getChannelId(currentChannel);
    if (channelId.isEmpty) {
      if (isSelectingDefault.value) {
        return const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
          ),
        );
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            !AuthService.to.hasChannel.value &&
            AuthService.to.userChannel == null) {
          Get.offAllNamed<dynamic>('/channelscreen');
        }
      });
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Obx(() {
            switch (controller.selectedIndex.value) {
              case 1:
                return _buildDashboardContent(isDarkMode);
              case 2:
                return ContentScreen(
                  channelId: channelId,
                  isDarkMode: isDarkMode,
                  searchQuery: controller.searchQuery.value,
                );
              case 3:
                return AnalyticsScreen(
                  isDarkMode: isDarkMode,
                  channelId: channelId,
                );
              case 4:
                return const DashboardCommentsPage();
              case 5:
                return MonetizationScreen(isDarkMode: isDarkMode);
              case 6:
                final ownerId = _getOwnerId(currentChannel);
                return ChannelCustomizationPage(
                  channelId: channelId,
                  ownerId: ownerId,
                );
              case 7:
                return AudioTracksPage(
                  channelId: channelId,
                  isDarkMode: isDarkMode,
                );
              case 8:
                return const StudioSettingsPage();
              case 9:
                return CopyrightScreen(channelId: channelId);
              case 10:
                return SubtitlesPage(
                  channelId: channelId,
                  isDarkMode: isDarkMode,
                );
              case 11:
                return ChaptersPage(
                  channelId: channelId,
                  isDarkMode: isDarkMode,
                );
              case 12:
                return AudiencePage(
                  channelId: channelId,
                  isDarkMode: isDarkMode,
                );
              case 13:
                return TrashRestoreScreen(
                  channelId: channelId,
                  isDarkMode: isDarkMode,
                );
              case 14:
                return TopicManagementScreen(
                  channelId: channelId,
                  isDarkMode: isDarkMode,
                  searchQuery: controller.searchQuery.value,
                );
              case 15:
                return TruthVerificationDashboardPage(
                  channelId: channelId,
                  isDarkMode: isDarkMode,
                );
              case 16:
                final ownerId = _getOwnerId(currentChannel);
                return CreatorIntelligencePage(
                  channelId: channelId,
                  creatorId: ownerId,
                );
              case 17:
                return PlaylistsManagementScreen(
                  channelId: channelId,
                  isDarkMode: isDarkMode,
                  searchQuery: controller.searchQuery.value,
                );
              case 18:
                return MembershipsScreen(
                  channelId: channelId,
                  isDarkMode: isDarkMode,
                );
              case 19:
                return CategoryInsightsScreen(
                  channelId: channelId,
                  isDarkMode: isDarkMode,
                );
              case 20:
                return DraftsScreen(
                  channelId: channelId,
                  isDarkMode: isDarkMode,
                );
              default:
                return _buildDashboardContent(isDarkMode);
            }
          }),
        ),
      ),
    );
  }

  Widget _buildDashboardContent(bool isDarkMode) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(horizontalPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDashboardHeader(isDarkMode),
          Obx(() {
            final ch = controller.currentChannel.value;
            if (ch == null) return const SizedBox.shrink();
            if (ch.status == ChannelStatus.active || ch.geminiApproved == true) {
              if (controller.showApprovalBanner.value) {
                return _buildApprovalBanner(isDarkMode);
              }
            }
            return const SizedBox.shrink();
          }),
          Obx(() {
            final ch = controller.currentChannel.value;
            if (ch == null) return const SizedBox.shrink();
            return Column(
              children: [
                _buildTruthworldIssuesDashboardNotice(isDarkMode, ch),
                _buildModerationStatusBanner(isDarkMode, ch),
                _buildImageVerificationBanner(isDarkMode, ch),
              ],
            );
          }),
          _buildChannelStatsGrid(isDarkMode),
          const SizedBox(height: 32),
          _buildRecentPerformanceSection(isDarkMode),
          const SizedBox(height: 32),
          _buildRecommendationsSection(isDarkMode),
          const SizedBox(height: 32),
          _buildLatestContentSection(isDarkMode),
          const SizedBox(height: 32),
          _buildQuickActionsSection(isDarkMode),
        ],
      ),
    );
  }

  Widget _buildTruthworldIssuesDashboardNotice(
      bool isDarkMode, Channel channel) {
    return DashboardTruthworldIssuesNotice(
      isDarkMode: isDarkMode,
      channel: channel,
      copyrightClaimsCount: controller.copyrightClaimsCount.value,
      onOpenIntelligence: () => controller.setSelectedIndex(16),
    );
  }

  Widget _buildImageVerificationBanner(bool isDarkMode, Channel channel) {
    return DashboardImageVerificationBanner(
      isDarkMode: isDarkMode,
      channel: channel,
      onOpenCustomization: () => controller.setSelectedIndex(6),
    );
  }

  Widget _buildVerificationAlertCard({
    required bool isDarkMode,
    required String title,
    required String subtitle,
    required Color color,
    required IconData icon,
    bool isPending = false,
    bool showCustomizationButton = false,
    VoidCallback? onBypassPressed,
    VoidCallback? onRequestManualReviewPressed,
  }) {
    return DashboardVerificationAlertCard(
      isDarkMode: isDarkMode,
      title: title,
      subtitle: subtitle,
      color: color,
      icon: icon,
      isPending: isPending,
      showCustomizationButton: showCustomizationButton,
      onBypassPressed: onBypassPressed,
      onRequestManualReviewPressed: onRequestManualReviewPressed,
      onOpenCustomization: () => controller.setSelectedIndex(6),
    );
  }

  Widget _buildChannelViolationsCard(bool isDarkMode) {
    return DashboardChannelViolationsCard(
      isDarkMode: isDarkMode,
      copyrightClaimsCount: controller.copyrightClaimsCount.value,
      onViewDetails: () => controller.setSelectedIndex(9),
    );
  }

  Widget _buildDashboardHeader(bool isDarkMode) {
    final currentCh = controller.currentChannel.value ?? channel;
    return DashboardHeader(
      isDarkMode: isDarkMode,
      isMobile: isMobile,
      channel: currentCh,
      channelName: _getChannelName(currentCh),
      searchController: _searchController,
      onSearchChanged: controller.setSearchQuery,
      onSearchClear: () => controller.setSearchQuery(''),
    );
  }

  Widget _buildModerationStatusBanner(bool isDarkMode, Channel channel) {
    return DashboardModerationStatusBanner(
      isDarkMode: isDarkMode,
      channel: channel,
    );
  }

  Widget _buildApprovalBanner(bool isDarkMode) {
    return DashboardApprovalBanner(
      isDarkMode: isDarkMode,
      onDismiss: controller.dismissApprovalBanner,
    );
  }

  Widget _buildMobileSearchField(bool isDarkMode) {
    return DashboardMobileSearchField(
      isDarkMode: isDarkMode,
      searchController: _searchController,
      onSearchChanged: controller.setSearchQuery,
      onSearchClear: () => controller.setSearchQuery(''),
    );
  }

  Widget _buildChannelStatsGrid(bool isDarkMode) {
    return Obx(
      () => DashboardChannelStatsGrid(
        isDarkMode: isDarkMode,
        isMobile: isMobile,
        isDesktop: isDesktop,
        isTablet: isTablet,
        channel: controller.currentChannel.value ?? channel,
        channelStats: controller.channelStats,
        isLoading: controller.rxIsLoading.value,
        statsAnimation: _statsAnimation,
      ),
    );
  }

  Widget _buildStatsLoadingGrid(bool isDarkMode) {
    return DashboardStatsLoadingGrid(
      isDarkMode: isDarkMode,
      isMobile: isMobile,
      isDesktop: isDesktop,
      isTablet: isTablet,
    );
  }

  Widget _buildStatCardSkeleton(bool isDarkMode) {
    return DashboardStatCardSkeleton(isDarkMode: isDarkMode);
  }

  Widget _buildStatCard(
    String title,
    String value,
    String change,
    IconData icon,
    Color color,
    bool isDarkMode, {
    VoidCallback? onTap,
  }) {
    return DashboardStatCard(
      title: title,
      value: value,
      change: change,
      icon: icon,
      color: color,
      isDarkMode: isDarkMode,
      isMobile: isMobile,
      onTap: onTap,
    );
  }

  Widget _buildRecentPerformanceSection(bool isDarkMode) {
    return Obx(
      () => DashboardRecentPerformanceSection(
        isDarkMode: isDarkMode,
        isMobile: isMobile,
        chartAnimation: _chartAnimation,
        analyticsData: controller.analyticsData.toList(),
      ),
    );
  }

  Widget _buildPerformanceChart(bool isDarkMode) {
    return Obx(
      () => DashboardPerformanceChart(
        isDarkMode: isDarkMode,
        analyticsData: controller.analyticsData.toList(),
      ),
    );
  }

  Widget _buildRecommendationsSection(bool isDarkMode) {
    return Obx(
      () => DashboardRecommendationsSection(
        isDarkMode: isDarkMode,
        isMobile: isMobile,
        isDesktop: isDesktop,
        isTablet: isTablet,
        channel: controller.currentChannel.value,
        videos: controller.recentVideos.toList(),
        stats: controller.channelStats,
        controller: controller,
      ),
    );
  }

  Widget _buildRecommendationCard(
    Map<String, dynamic> recommendation,
    bool isDarkMode,
  ) {
    return DashboardRecommendationCard(
      recommendation: recommendation,
      isDarkMode: isDarkMode,
    );
  }

  Widget _buildLatestContentSection(bool isDarkMode) {
    return Obx(
      () => DashboardLatestContentSection(
        isDarkMode: isDarkMode,
        isMobile: isMobile,
        videos: controller.filteredVideos,
        searchQuery: controller.searchQuery.value,
        onViewAll: () => controller.setSelectedIndex(2),
      ),
    );
  }

  Widget _buildContentCard(Video video, bool isDarkMode) {
    return DashboardContentCard(
      video: video,
      isDarkMode: isDarkMode,
      isMobile: isMobile,
    );
  }

  void _openCreateTopicDialogFromQuickActions(bool isDarkMode) {
    final topicCtrl = Get.isRegistered<TopicManagementController>()
        ? Get.find<TopicManagementController>()
        : Get.put(TopicManagementController());
    final channelId = _getChannelId(channel);
    CreateTopicDialog.show(
      context: context,
      isDarkMode: isDarkMode,
      channelVideosFuture: topicCtrl.fetchChannelVideos(channelId),
      onCreateTopicSubmitted: (createCtrl) async {
        String? finalThumbnailUrl;
        if (createCtrl.thumbnailSource.value == 'custom' &&
            createCtrl.pickedCustomImageBytes.value != null) {
          finalThumbnailUrl = await topicCtrl.uploadTopicThumbnail(
            createCtrl.pickedCustomImageBytes.value!,
            createCtrl.pickedCustomImageName.value ?? 'custom_topic_thumb.jpg',
          );
        } else if (createCtrl.thumbnailSource.value == 'video') {
          finalThumbnailUrl = createCtrl.chosenVideoThumbnailUrl.value;
        }

        await topicCtrl.createTopic(
          channelId: channelId,
          title: createCtrl.titleController.text,
          handle: createCtrl.handleController.text,
          description: createCtrl.descriptionController.text,
          category: createCtrl.categoryController.text.isEmpty
              ? 'General'
              : createCtrl.categoryController.text,
          thumbnailUrl: finalThumbnailUrl,
          selectedVideoIds: createCtrl.selectedVideoIds.toList(),
        );
      },
    );
  }

  Widget _buildQuickActionsSection(bool isDarkMode) {
    return DashboardQuickActionsSection(
      isDarkMode: isDarkMode,
      isMobile: isMobile,
      isDesktop: isDesktop,
      isTablet: isTablet,
      onCreateTopic: () => _openCreateTopicDialogFromQuickActions(isDarkMode),
      onViewAnalytics: () => controller.setSelectedIndex(3),
    );
  }

  Widget _buildQuickActionCard(Map<String, dynamic> action, bool isDarkMode) {
    return DashboardQuickActionCard(
      action: action,
      isDarkMode: isDarkMode,
    );
  }

  Widget _buildFallbackLoginScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0014),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.dashboard_rounded,
                color: Colors.white,
                size: 80,
              ),
              const SizedBox(height: 24),
              const Text(
                'Creator Studio',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Please sign in to access your Creator Studio dashboard.',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  isSelectingDefault.value = true;
                  _handleGoogleSignIn();
                },
                icon: const Icon(Icons.login_rounded),
                label: const Text('Sign In with Google'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: AppColors.textPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
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
      ),
    );
  }
}
