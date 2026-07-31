import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/utils/studio_launcher.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_controller.dart';
import 'package:truthworld/features/watchhistory/presentation/controllers/watch_history_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

// ==========================================================================
// YOUTUBE-STYLE THEME COLORS
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
// MODERNIZED LIBRARY SCREEN
// ==========================================================================

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, this.isDashboard = false});
  final bool isDashboard;

  @override
  State<LibraryScreen> createState() => LibraryScreenState();
}

class LibraryScreenState extends State<LibraryScreen>
    with TickerProviderStateMixin {
  final int previewItemCount = 4;
  final _playlistController = Get.find<PlaylistController>();
  final _watchHistoryController = Get.put(WatchHistoryController());

  late AnimationController _fadeAnimationController;
  late AnimationController _slideAnimationController;
  late AnimationController _scaleAnimationController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
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
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _slideAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );

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
        // final bool isMobile = constraints.maxWidth < kMobileBreakpoint; // isMobile is the else case

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
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return _buildUnauthenticatedState(context, isDesktop: true);
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Row(
          children: [
            // Main Content
            Expanded(
              flex: 7,
              child: _buildMainContent(context, userId, isDesktop: true),
            ),
            // Sidebar with Quick Actions
            if (!widget.isDashboard)
              Expanded(flex: 3, child: _buildSidebar(context, userId)),
          ],
        ),
      ),
    );
  }

  Widget _buildTabletLayout(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return _buildUnauthenticatedState(context, isTablet: true);
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: !widget.isDashboard
          ? _buildModernAppBar(context, isTablet: true)
          : null,
      body: SafeArea(child: _buildMainContent(context, userId, isTablet: true)),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return _buildUnauthenticatedState(context);
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(child: _buildMainContent(context, userId)),
    );
  }

  PreferredSizeWidget _buildModernAppBar(
    BuildContext context, {
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
              Icons.video_library_rounded,
              color: AppColors.textPrimary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Your Library',
            style: TextStyle(
              fontSize: isTablet ? 24 : 22,
              fontWeight: FontWeight.bold,
              color: primaryText,
            ),
          ),
        ],
      ),
      actions: [
        _buildAppBarAction(
          icon: Icons.search_rounded,
          onPressed: () => _showSearchDialog(context),
          tooltip: 'Search Library',
        ),
        _buildAppBarAction(
          icon: Icons.more_vert_rounded,
          onPressed: () => _showMoreOptions(context),
          tooltip: 'More Options',
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
        color: buttonBg.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: secondaryText, size: 22),
          ),
        ),
      ),
    );
  }

  Widget _buildUnauthenticatedState(
    BuildContext context, {
    bool isDesktop = false,
    bool isTablet = false,
  }) {
    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: EdgeInsets.all(isDesktop ? 40 : 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildUnauthenticatedIcon(),
              const SizedBox(height: 32),
              _buildUnauthenticatedTitle(),
              const SizedBox(height: 16),
              _buildUnauthenticatedSubtitle(),
              const SizedBox(height: 40),
              _buildSignInButton(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnauthenticatedIcon() {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 800),
      tween: Tween(begin: 0, end: 1),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            width: 120,
            height: 120,
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
                Icons.lock_outline_rounded,
                color: primaryText,
                size: 60,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildUnauthenticatedTitle() {
    return const Text(
      'Access Your Personal Video Library',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: primaryText,
      ),
    );
  }

  Widget _buildUnauthenticatedSubtitle() {
    return const Text(
      'Sign in to view your saved videos, watch history, and custom playlists. Your content is waiting!',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 16, color: secondaryText),
    );
  }

  Widget _buildSignInButton(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () {
        HapticFeedback.lightImpact();
        Get.toNamed('/auth');
      },
      icon: const Icon(Icons.login_rounded, color: AppColors.bgPage),
      label: const Text(
        'Sign In to Continue',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.bgPage,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.textPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        elevation: 5,
      ),
    );
  }

  Widget _buildMainContent(
    BuildContext context,
    String userId, {
    bool isDesktop = false,
    bool isTablet = false,
  }) {
    return SafeArea(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 1. Profile Header
          SliverToBoxAdapter(
            child: _buildProfileHeader(userId),
          ),

          Obx(() {
            final homeController = Get.isRegistered<HomeController>()
                ? Get.find<HomeController>()
                : Get.put(HomeController());
            final authService = AuthService.to;
            final hasChannel = authService.hasChannel.value;

            final isLibraryEmpty =
                !homeController.hasWatchHistory.value &&
                !homeController.hasPlaylists.value &&
                !homeController.hasFollowedTopics.value &&
                !homeController.hasLikedVideos.value &&
                !homeController.hasClips.value &&
                !homeController.hasUploadedVideos.value;

            final items = <Widget>[];

            // If library is empty, show "Your library is empty" with Settings and Create Channel buttons
            if (isLibraryEmpty) {
              items.add(
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 32,
                    horizontal: 20,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.folder_open_outlined,
                        size: 64,
                        color: secondaryText,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Your library is empty',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        hasChannel
                            ? 'Configure your settings to get started.'
                            : 'Configure your settings or create a channel to get started.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: secondaryText,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                Get.toNamed('/settings');
                              },
                              icon: const Icon(
                                Icons.settings_outlined,
                                size: 18,
                                color: primaryText,
                              ),
                              label: const Text(
                                'Settings',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: primaryText,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: buttonBg,
                                side: BorderSide(
                                  color: AppColors.textPrimary.withValues(
                                    alpha: 0.1,
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                          ),
                          if (!hasChannel) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  Get.toNamed('/channelscreen');
                                },
                                icon: const Icon(
                                  Icons.add_circle_outline,
                                  size: 18,
                                  color: primaryText,
                                ),
                                label: const Text(
                                  'Create Channel',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: primaryText,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: buttonBg,
                                  side: BorderSide(
                                    color: AppColors.textPrimary.withValues(
                                      alpha: 0.1,
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              );
              items.add(const Divider());
            }

            // Always display the Text and icon for every Tab
            items.addAll([
              _buildLibraryListTile(
                icon: Icons.history_rounded,
                title: 'History',
                onTap: () => Get.toNamed('/history'),
              ),
              _buildLibraryListTile(
                icon: Icons.playlist_play_rounded,
                title: 'Playlists',
                onTap: () => Get.toNamed('/playlistscreen'),
              ),
              _buildLibraryListTile(
                icon: Icons.people_outline_rounded,
                title: 'Following Topics',
                onTap: () => Get.toNamed('/following-topics'),
              ),
              _buildLibraryListTile(
                icon: Icons.thumb_up_outlined,
                title: 'Liked videos',
                onTap: () => Get.toNamed('/likedvideos'),
              ),
              _buildLibraryListTile(
                icon: Icons.bookmark_outline_rounded,
                title: 'Saved posts',
                onTap: () => Get.toNamed('/saved-community-posts'),
              ),
              _buildLibraryListTile(
                icon: Icons.comment_outlined,
                title: 'Saved comments',
                onTap: () => Get.toNamed('/saved-comments'),
              ),
              _buildLibraryListTile(
                icon: Icons.content_cut_rounded,
                title: 'Clips',
                onTap: () => Get.toNamed('/clips'),
              ),
              _buildLibraryListTile(
                icon: Icons.file_download_outlined,
                title: 'Downloads',
                trailing: const Icon(
                  Icons.check_circle,
                  color: AppColors.textPrimary,
                  size: 20,
                ),
                onTap: () {
                  if (Get.isRegistered<HomeController>()) {
                    Get.find<HomeController>().onSideNavItemSelect(
                      HomeController.indexDownloads,
                    );
                  } else {
                    Get.toNamed('/downloads');
                  }
                },
              ),
              _buildLibraryListTile(
                icon: Icons.settings_outlined,
                title: 'Settings',
                onTap: () {
                  if (Get.isRegistered<HomeController>()) {
                    Get.find<HomeController>().onSideNavItemSelect(
                      HomeController.indexSettings,
                    );
                  } else {
                    Get.toNamed('/settings');
                  }
                },
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(color: AppColors.bgDivider, height: 1),
              ),
              _buildLibraryListTile(
                icon: Icons.workspace_premium_outlined,
                title: 'Get Premium',
                onTap: () => Get.toNamed('/premium'),
              ),
              if (!hasChannel)
                _buildLibraryListTile(
                  icon: Icons.add_circle_outline,
                  title: 'Create Channel to upload videos',
                  onTap: () => Get.toNamed('/channelscreen'),
                ),
            ]);

            return SliverList(
              delegate: SliverChildListDelegate(items),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(String userId) {
    return Obx(() {
      final authService = AuthService.to;
      final hasChannel = authService.hasChannel.value;
      final channel = authService.userChannel;

      final displayName = authService.activeDisplayName;
      final handle = authService.activeHandle;
      final avatarUrl = authService.activePhotoUrl;

      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: (hasChannel && channel != null)
                  ? () => StudioLauncher.openStudio()
                  : null,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    UserAvatar(
                      radius: 40,
                      photoUrl: avatarUrl,
                      displayName: displayName,
                      backgroundColor: buttonBg,
                      textColor: primaryText,
                      fontSize: 32,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: primaryText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            handle,
                            style: const TextStyle(
                              fontSize: 14,
                              color: secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildLibraryListTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Icon(
                icon,
                color: AppColors.textPrimary,
                size: 24,
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }

  // Dialog Methods (Preserved and enhanced)
  void _showSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Search Library',
          style: TextStyle(
            color: primaryText,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          style: const TextStyle(color: primaryText),
          decoration: InputDecoration(
            hintText: 'Search videos, playlists...',
            hintStyle: const TextStyle(color: secondaryText),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: buttonBg),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.textPrimary),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: secondaryText),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.textPrimary,
            ),
            child: const Text(
              'Search',
              style: TextStyle(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    final controller = TextEditingController();
    var isPublic = false;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Create Playlist',
            style: TextStyle(
              color: primaryText,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                style: const TextStyle(color: primaryText),
                decoration: InputDecoration(
                  hintText: 'Playlist name',
                  hintStyle: const TextStyle(color: secondaryText),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: buttonBg),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.textPrimary),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text(
                    'Privacy: ',
                    style: TextStyle(color: secondaryText, fontSize: 14),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Private'),
                    selected: !isPublic,
                    onSelected: (val) {
                      if (val) setDialogState(() => isPublic = false);
                    },
                    selectedColor: buttonBg,
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Public'),
                    selected: isPublic,
                    onSelected: (val) {
                      if (val) setDialogState(() => isPublic = true);
                    },
                    selectedColor: buttonBg,
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: secondaryText),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (controller.text.isNotEmpty) {
                  await _playlistController.createPlayList(
                    controller.text,
                    isPublic: isPublic,
                  );
                  if (context.mounted) Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryText,
                foregroundColor: bgColor,
              ),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: secondaryText,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            _buildMoreOption(
              icon: Icons.settings_rounded,
              title: 'Library Settings',
              onTap: () => Navigator.pop(context),
            ),
            _buildMoreOption(
              icon: Icons.download_rounded,
              title: 'Downloads',
              onTap: () => Navigator.pop(context),
            ),
            _buildMoreOption(
              icon: Icons.history_rounded,
              title: 'Clear All History',
              onTap: () {
                Navigator.pop(context);
                _showClearHistoryDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: secondaryText),
      title: Text(
        title,
        style: const TextStyle(
          color: primaryText,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  void _showClearHistoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Clear History',
          style: TextStyle(
            color: primaryText,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Are you sure you want to clear your watch history? This action cannot be undone.',
          style: TextStyle(color: secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: secondaryText),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await _watchHistoryController.clearAllHistory();
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.textPrimary,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context, String userId) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(
          left: BorderSide(
            color: AppColors.textPrimary.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSidebarHeader(),
          const SizedBox(height: 32),
          _buildSidebarSearch(),
          const SizedBox(height: 40),
          _buildSidebarQuickActions(),
          const SizedBox(height: 40),
          Expanded(child: _buildSidebarPlaylists(userId)),
        ],
      ),
    );
  }

  Widget _buildSidebarHeader() {
    final authService = AuthService.to;
    final displayName = authService.activeDisplayName;
    final handleOrEmail =
        authService.hasChannel.value && authService.userChannel != null
        ? authService.activeHandle
        : (authService.user?.email ?? '');

    return Row(
      children: [
        InkWell(
          onTap: () {
            if (authService.hasChannel.value) {
              StudioLauncher.openStudio();
            } else {
              Get.toNamed('/channelscreen');
            }
          },
          child: UserAvatar(
            radius: 24,
            photoUrl: authService.activePhotoUrl,
            displayName: displayName,
            backgroundColor: buttonBg,
            textColor: AppColors.textPrimary,
            fontSize: 18,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: primaryText,
                ),
              ),
              if (handleOrEmail.isNotEmpty)
                Text(
                  handleOrEmail,
                  style: const TextStyle(
                    fontSize: 12,
                    color: secondaryText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSidebarSearch() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: buttonBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const TextField(
        style: TextStyle(color: primaryText, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search in library...',
          hintStyle: TextStyle(color: secondaryText),
          border: InputBorder.none,
          icon: Icon(Icons.search_rounded, color: secondaryText, size: 20),
          contentPadding: EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildSidebarQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: secondaryText,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        _buildSidebarAction(
          icon: Icons.add_box_rounded,
          title: 'New Playlist',
          onTap: () => _showCreatePlaylistDialog(context),
        ),
        _buildSidebarAction(
          icon: Icons.history_rounded,
          title: 'Watch History',
          onTap: () => Get.toNamed('/watchhistory'),
        ),
        _buildSidebarAction(
          icon: Icons.thumb_up_rounded,
          title: 'Liked Videos',
          onTap: () => Get.toNamed('/likedvideos'),
        ),
        _buildSidebarAction(
          icon: Icons.settings_rounded,
          title: 'Settings',
          onTap: () => Get.toNamed('/settings'),
        ),
      ],
    );
  }

  Widget _buildSidebarAction({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            children: [
              Icon(icon, color: primaryText, size: 20),
              const SizedBox(width: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: primaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarPlaylists(String userId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PLAYLISTS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: secondaryText,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .collection('playlists')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Text(
                  'No playlists yet',
                  style: TextStyle(color: secondaryText, fontSize: 13),
                );
              }

              final playlists = snapshot.data!.docs
                  .map(PlaylistModel.fromDocumentSnapshot)
                  .where((p) => p.thumbnailUrl.trim().isNotEmpty)
                  .toList();

              if (playlists.isEmpty) {
                return const Text(
                  'No playlists yet',
                  style: TextStyle(color: secondaryText, fontSize: 13),
                );
              }

              return ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: playlists.length,
                itemBuilder: (context, index) {
                  final playlist = playlists[index];
                  return _buildSidebarPlaylistTile(playlist);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSidebarPlaylistTile(PlaylistModel playlist) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: buttonBg,
          borderRadius: BorderRadius.circular(6),
          image: playlist.thumbnailUrl.isNotEmpty
              ? DecorationImage(
                  image: CachedNetworkImageProvider(playlist.thumbnailUrl),
                  fit: BoxFit.cover,
                  onError: (exception, stackTrace) {},
                )
              : null,
        ),
        child: playlist.thumbnailUrl.isEmpty
            ? const Icon(
                Icons.playlist_play,
                color: AppColors.textPrimary,
                size: 16,
              )
            : null,
      ),
      title: Text(
        playlist.playlistName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 14,
          color: primaryText,
        ),
      ),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
