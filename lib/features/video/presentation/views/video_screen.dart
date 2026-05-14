import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:chewie/chewie.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:truthworld/features/video/presentation/views/comments/premium_comment_input.dart';
import 'package:truthworld/features/video/presentation/controllers/comments_controller_v2.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/features/video/data/models/reply.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/home/presentation/controllers/main_controller.dart';
import 'package:truthworld/features/miniplayer/presentation/controllers/miniplayer_controller.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_controller.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/video/presentation/widgets/sliver_tab_bar_delegate.dart';
import 'package:truthworld/theme/app_theme.dart';
import '../controllers/video_controller.dart';
import '../controllers/custom_play.dart';
import '../../../channel/presentation/controllers/channel_controller_unified.dart';
import '../widgets/truth_index_badge.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/video/presentation/controllers/clip_controller.dart';
import 'package:truthworld/components/ui/video_card.dart';

class VideoScreen extends GetView<VideoController> {
  final String? videoTag;
  const VideoScreen({super.key, this.videoTag});

  @override
  String? get tag => videoTag;

  // Theme Shortcuts
  static const Color primary = AppColors.brand;
  static const Color background = AppColors.bgPage;
  static const Color cardBackground = AppColors.bgSurface;
  static const Color textPrimary = AppColors.textPrimary;
  static const Color textSecondary = AppColors.textSecondary;
  static const Color divider = AppColors.bgDivider;
  static const Color border = AppColors.bgDivider;
  static const Color accent = AppColors.brand;

  @override
  Widget build(BuildContext context) {
    // Controller is handled by GetX Binding in AppPages
    // Ensure controller is fully instantiated/found BEFORE entering any Obx block
    final ctrl = controller;

    final bool isMobilePlatform =
        !kIsWeb &&
        (Theme.of(context).platform == TargetPlatform.iOS ||
            Theme.of(context).platform == TargetPlatform.android);

    // Dismiss miniplayer once when screen first builds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Get.isRegistered<MiniplayerController>(tag: 'miniplayer')) {
        MiniplayerController.to.dismiss();
      }
    });

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _handleBackToMiniplayer();
        }
      },
      child: Obx(() {
        if (ctrl.video.id.isEmpty) {
          return const Scaffold(
            backgroundColor: background,
            body: Center(
              child: CircularProgressIndicator(
                color: AppColors.brand,
                strokeWidth: 3,
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: background,
          extendBodyBehindAppBar: true,
          // Hide appbar in fullscreen mode
          appBar: !ctrl.isFullScreen.value ? _buildAppBar(context) : null,
          body: SafeArea(
            top: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bool isDesktop = constraints.maxWidth > 1050;
                return Obx(() {
                  return isDesktop
                      ? _buildDesktopLayout(context)
                      : _buildMobileLayout(context);
                });
              },
            ),
          ),
          // Hide bottom nav in fullscreen
          bottomNavigationBar: (isMobilePlatform && !ctrl.isFullScreen.value)
              ? _buildBottomNavigationBar(context)
              : null,
        );
      }),
    );
  }

  // Getters for other controllers
  ChannelController get _channelController =>
      Get.find<ChannelController>(tag: tag);
  MainController get _mainController => Get.find<MainController>();
  PlaylistController get _playlistController => Get.find<PlaylistController>();

  void _handleBackToMiniplayer() {
    try {
      // Check if controllers are still registered
      if (!Get.isRegistered<VideoController>(tag: tag)) {
        debugPrint(
          '[VideoScreen] VideoController not registered, skipping miniplayer',
        );
        return;
      }
      if (!Get.isRegistered<MiniplayerController>(tag: 'miniplayer')) {
        debugPrint(
          '[VideoScreen] MiniplayerController not registered, skipping miniplayer',
        );
        return;
      }

      final videoController = controller;
      final pos =
          videoController.videoPlayerController?.value.position ??
          Duration.zero;

      // Only show miniplayer if we have valid video data
      if (videoController.video.id.isNotEmpty) {
        MiniplayerController.to.showWithVideo(
          videoController.video,
          resumeFromPosition: pos,
          overrideUrl: videoController.currentResolution.value?.url,
        );
      }
    } catch (e) {
      debugPrint('[VideoScreen] Error starting miniplayer on pop: $e');
    }
  }

  // ==========================================================================
  // RESPONSIVE LAYOUTS
  // ==========================================================================

  Widget _buildMobileLayout(BuildContext context) {
    // Normal mode - show full UI with tabs
    return CustomScrollView(
      controller: controller.scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        _buildVideoPlayerSection(),
        _buildVideoInfoSection(context),
        SliverPersistentHeader(
          pinned: true,
          delegate: SliverTabBarDelegate(
            TabBar(
              controller: controller.mobileTabController,
              labelColor: primary,
              unselectedLabelColor: textSecondary,
              indicatorColor: primary,
              indicatorWeight: 2.5,
              indicatorSize: TabBarIndicatorSize.label,
              tabs: const [
                Tab(text: 'More From Channel'),
                Tab(text: 'Comments'),
              ],
              onTap: (index) {
                controller.mobileTabIndex.value = index;
              },
            ),
            backgroundColor: background,
          ),
        ),
        ..._buildMobileTabContent(context),
      ],
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column (Video, Description, Comments)
        Expanded(
          flex: 7,
          child: CustomScrollView(
            controller: controller.scrollController,
            slivers: [
              _buildVideoPlayerSection(),
              _buildVideoInfoSection(context, isDesktop: true),
              SliverPersistentHeader(
                pinned: true,
                delegate: SliverTabBarDelegate(
                  TabBar(
                    controller: controller.desktopTabController,
                    labelColor: primary,
                    unselectedLabelColor: textSecondary,
                    indicatorColor: primary,
                    indicatorWeight: 2.5,
                    indicatorSize: TabBarIndicatorSize.label,
                    tabs: const [
                      Tab(text: 'More From Channel'),
                      Tab(text: 'Comments'),
                    ],
                    onTap: (index) {
                      controller.desktopTabIndex.value = index;
                    },
                  ),
                  backgroundColor: background,
                ),
              ),
              ..._buildDesktopTabContent(context),
            ],
          ),
        ),
        // Divider
        Container(width: 1, color: divider.withValues(alpha: 0.5)),
        // Right Column (Recommendations Sidebar)
        Expanded(
          flex: 3,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    children: [
                      _buildPlaylistSidebarSection(context),
                      _buildChapters(),
                      const SizedBox(height: 16),
                      _buildRecommendationHeader(),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.only(bottom: 24),
                sliver: SliverToBoxAdapter(
                  child: RecommendationFeed(
                    video: controller.video,
                    videoTag: videoTag,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    isGrid: false,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // TAB CONTENT BUILDERS
  // ==========================================================================

  List<Widget> _buildMobileTabContent(BuildContext context) {
    switch (controller.mobileTabIndex.value) {
      case 0:
        return [
          _buildUpNext(
            currentVideo: controller.video,
            videoId: controller.video.id,
          ),
        ];
      case 1:
        return _buildCommentsSlivers(context);
      default:
        return [];
    }
  }

  List<Widget> _buildDesktopTabContent(BuildContext context) {
    switch (controller.desktopTabIndex.value) {
      case 0:
        return [
          _buildUpNext(
            currentVideo: controller.video,
            videoId: controller.video.id,
          ),
        ];
      case 1:
        return _buildCommentsSlivers(context);
      default:
        return [];
    }
  }

  // ==========================================================================
  // SHARED WIDGETS
  // ==========================================================================

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    // Check if user came from home screen
    final previousRoute = Get.previousRoute;
    final isFromHome =
        previousRoute.contains('home') ||
        previousRoute.isEmpty ||
        previousRoute == '/';

    if (isFromHome) {
      // Exact replica of home screen app bar
      return AppBar(
        backgroundColor: AppColors.bgPage,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: _buildHomeStyleHeader(context),
        actions: _buildHomeStyleActions(context),
      );
    }

    // Default minimal app bar for other sources
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.bgSurface.withValues(alpha: 0.7),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.arrow_back_ios_new, size: 18, color: textPrimary),
        ),
        onPressed: () => Get.back(),
        tooltip: 'Back',
      ),
    );
  }

  // Exact replica of home screen header
  Widget _buildHomeStyleHeader(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: Row(
        children: [
          // Logo
          InkWell(
            onTap: () => Get.offAllNamed("/home"),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.play_circle_fill_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    "Truthworld",
                    style: GoogleFonts.roboto(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 40),
          // Search bar exactly like home screen
          Expanded(
            child: Center(
              child: Container(
                constraints: BoxConstraints(maxWidth: 650),
                height: 44,
                child: Material(
                  borderRadius: BorderRadius.circular(22),
                  color: Colors.white.withValues(alpha: 0.05),
                  child: InkWell(
                    onTap: () => Get.toNamed('/search'),
                    borderRadius: BorderRadius.circular(22),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.0),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search_rounded,
                            color: Colors.grey.shade400,
                            size: 22,
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'Search videos...',
                              style: GoogleFonts.roboto(
                                color: Colors.grey.shade400,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Exact copy of home screen actions
  List<Widget> _buildHomeStyleActions(BuildContext context) {
    // Use AuthService observable instead of FirebaseAuth directly
    return [
      // Notification bell like home screen
      IconButton(
        icon: Icon(Icons.notifications_outlined, color: Colors.white),
        onPressed: () {
          // Navigate to notifications
        },
      ),
      Obx(() {
        final isAuthenticated = AuthService.to.isAuthenticated.value;
        if (!isAuthenticated) {
          // Sign In button
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: OutlinedButton.icon(
              icon: Icon(
                Icons.account_circle_outlined,
                size: 18,
                color: Color(0xFF3B82F6),
              ),
              label: Text(
                "Sign In",
                style: TextStyle(
                  color: Color(0xFF3B82F6),
                  fontWeight: FontWeight.w500,
                ),
              ),
              onPressed: () {
                final homeController = Get.find<HomeController>();
                if (!homeController.isLoadingAuth.value) {
                  homeController.signInWithGoogle();
                }
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: Color(0xFF3B82F6).withValues(alpha: 0.6),
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          );
        } else {
          // User is signed in - show CircleAvatar with user initial (like home screen)
          final user = AuthService.to.user;
          final initial =
              user?.email?.substring(0, 1).toUpperCase() ??
              user?.displayName?.substring(0, 1).toUpperCase() ??
              'U';
          return Padding(
            padding: const EdgeInsets.only(right: 16.0, left: 8.0),
            child: InkWell(
              onTap: () {
                // Show user menu
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.grey.shade800,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade600, width: 1),
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: GoogleFonts.roboto(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          );
        }
      }),
    ];
  }

  Widget _buildVideoPlayerSection() {
    // When fullscreen, show ONLY a black placeholder in the background.
    // This is CRITICAL for Web/Desktop to avoid rendering the video player twice,
    // which causes the "audio-only" or "black screen" bug in the fullscreen route.
    if (controller.isFullScreen.value) {
      return SliverToBoxAdapter(
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(color: Colors.black),
        ),
      );
    }
    // Normal mode - show video with aspect ratio
    return SliverToBoxAdapter(
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(color: background, child: _buildVideoPlayer()),
      ),
    );
  }

  Widget _buildVideoInfoSection(
    BuildContext context, {
    bool isDesktop = false,
  }) {
    final ctrl = controller;
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildVideoTitle(),
            const SizedBox(height: 12),
            if (ctrl.video.videoRating > 0)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: _buildTruthIndexBadge(),
              ),
            _buildModernActionButtons(context),
            const SizedBox(height: 16),
            _buildDescriptionBox(context),
            if (!isDesktop &&
                ctrl.currentPlaylist.value != null &&
                ctrl.playlistVideos.isNotEmpty &&
                ctrl.showPlaylistDrawer.value)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: _buildPlaylistDrawer(context),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTruthIndexBadge() {
    return TruthIndexBadge(video: controller.video);
  }

  Widget _buildPlaylistDrawer(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        controller.currentPlaylist.value!.playlistName,
                        style: GoogleFonts.roboto(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${controller.video.channelName.isNotEmpty ? '${controller.video.channelName} - ' : ''}${controller.currentPlaylistIndex.value + 1} / ${controller.playlistVideos.length}",
                        style: GoogleFonts.roboto(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => controller.showPlaylistDrawer.value = false,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Controls
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Obx(
                  () => IconButton(
                    icon: Icon(
                      Icons.repeat,
                      color: controller.isPlaylistLooping.value
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.5),
                    ),
                    onPressed: () => controller.isPlaylistLooping.value =
                        !controller.isPlaylistLooping.value,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
                const SizedBox(width: 16),
                Obx(
                  () => IconButton(
                    icon: Icon(
                      Icons.shuffle,
                      color: controller.isPlaylistShuffled.value
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.5),
                    ),
                    onPressed: () {
                      controller.isPlaylistShuffled.value =
                          !controller.isPlaylistShuffled.value;
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.more_vert,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  onPressed: () {
                    // Optional: open a bottom sheet with playlist options
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Videos List
          Container(
            constraints: const BoxConstraints(maxHeight: 300),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: controller.playlistVideos.length,
              itemBuilder: (context, index) {
                final video = controller.playlistVideos[index];
                final isActive = index == controller.currentPlaylistIndex.value;

                return InkWell(
                  onTap: () => controller.playPlaylistVideoAtIndex(index),
                  child: Container(
                    color: isActive
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Play Icon or Index
                        SizedBox(
                          width: 24,
                          child: Center(
                            child: isActive
                                ? const Icon(
                                    Icons.play_arrow,
                                    color: Colors.white,
                                    size: 20,
                                  )
                                : Text(
                                    "${index + 1}",
                                    style: GoogleFonts.roboto(
                                      color: Colors.white.withValues(
                                        alpha: 0.7,
                                      ),
                                      fontSize: 12,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Thumbnail
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: video.thumbnailUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: video.thumbnailUrl,
                                  width: 100,
                                  height: 56,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  width: 100,
                                  height: 56,
                                  color: Colors.grey[800],
                                ),
                        ),
                        const SizedBox(width: 12),
                        // Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                video.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.roboto(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: isActive
                                      ? FontWeight.w500
                                      : FontWeight.normal,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                video.channelName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.roboto(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer() {
    final String heroTag =
        Get.arguments?["heroTag"] ?? "video_${controller.video.id}";
    final thumbnailWidget = Container(
      color: Colors.black,
      child: Center(
        child: controller.video.thumbnailUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: controller.video.thumbnailUrl.replaceAll(' ', '%20'),
                fit: BoxFit.contain,
                placeholder: (context, url) => const SizedBox.shrink(),
                errorWidget: (context, url, error) => const SizedBox.shrink(),
              )
            : Icon(
                Icons.video_library_outlined,
                color: textSecondary.withValues(alpha: 0.3),
                size: 48,
              ),
      ),
    );

    return Hero(
      tag: heroTag,
      child: Obx(() {
        if (controller.isLoading.value &&
            !controller.isSwitchingResolution.value) {
          return thumbnailWidget;
        }

        if (controller.videoError.value) {
          return Stack(
            children: [
              thumbnailWidget,
              Container(
                color: Colors.black54,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.white,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          controller.errorMessage.value.isNotEmpty
                              ? controller.errorMessage.value
                              : 'This video is currently unavailable',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.roboto(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () => controller.initializeVideoPlayer(),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brand,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        final isAutoSwitching = controller.isAutoSwitching.value;

        // Show thumbnail until video is initialized and playing
        final isVideoReady =
            controller.videoPlayerController?.value.isInitialized == true;
        final isPlaying =
            controller.videoPlayerController?.value.isPlaying == true;
        final bool isAudioOnly = controller.isAudioOnly.value;
        final showThumbnailOverlay =
            !isAutoSwitching &&
            (!isVideoReady ||
                (!isPlaying && controller.showThumbnail.value) ||
                isAudioOnly);

        if (controller.chewieController == null) {
          return thumbnailWidget;
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            // Only show thumbnail if video not ready yet
            if (showThumbnailOverlay) thumbnailWidget,
            // Video player
            Chewie(controller: controller.chewieController!),

            // --- Clip Mode Overlay ---
            if (controller.activeClip.value != null)
              Positioned(
                top: 40,
                left: 16,
                right: 16,
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: primary.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.content_cut_rounded,
                            color: primary,
                            size: 14,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'CLIP: ${controller.activeClip.value!.title}',
                            style: GoogleFonts.roboto(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () => controller.clearActiveClip(),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: primary,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          'WATCH FULL',
                          style: GoogleFonts.roboto(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      }),
    );
  }

  Widget _buildVideoTitle() {
    return Text(
      controller.video.title,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 20,
        color: textPrimary,
        height: 1.2,
      ),
    );
  }

  void _showClipDialog(BuildContext context) {
    if (!AuthService.to.isAuthenticated.value) {
      _showSignInPrompt();
      return;
    }

    final clipController = Get.put(ClipController(video: controller.video));

    // Attempt to get video duration for slider
    final totalDuration =
        controller.videoPlayerController?.value.duration.inSeconds.toDouble() ??
        300.0;
    clipController.endSeconds.value = (clipController.startSeconds.value + 15.0)
        .clamp(0, totalDuration);

    Get.bottomSheet(
      Container(
        padding: EdgeInsets.fromLTRB(24, 12, 24, 24),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Icon(Icons.content_cut_rounded, color: primary, size: 28),
                const SizedBox(width: 16),
                Text(
                  'Create Clip',
                  style: GoogleFonts.roboto(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // --- Title Input ---
            TextField(
              onChanged: (v) => clipController.clipTitle.value = v,
              style: GoogleFonts.roboto(color: textPrimary),
              decoration: InputDecoration(
                hintText: 'Add a title...',
                hintStyle: GoogleFonts.roboto(color: textSecondary),
                filled: true,
                fillColor: AppColors.bgSurface.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
            // --- Clip Range Selector ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'SELECT SEGMENT',
                  style: GoogleFonts.roboto(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brand,
                    letterSpacing: 1.2,
                  ),
                ),
                Obx(() {
                  final duration =
                      clipController.endSeconds.value -
                      clipController.startSeconds.value;
                  return Text(
                    '${duration.toInt()}s',
                    style: GoogleFonts.roboto(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 24),

            Obx(
              () => Column(
                children: [
                  RangeSlider(
                    values: RangeValues(
                      clipController.startSeconds.value,
                      clipController.endSeconds.value,
                    ),
                    min: 0,
                    max: totalDuration,
                    activeColor: AppColors.brand,
                    inactiveColor: AppColors.bgDivider.withValues(alpha: 0.1),
                    labels: RangeLabels(
                      FormatUtils.formatDuration(
                        Duration(
                          seconds: clipController.startSeconds.value.toInt(),
                        ),
                      ),
                      FormatUtils.formatDuration(
                        Duration(
                          seconds: clipController.endSeconds.value.toInt(),
                        ),
                      ),
                    ),
                    onChanged: (values) {
                      // Enforce max 60s
                      if (values.end - values.start <= 60.0) {
                        clipController.updateStart(values.start);
                        clipController.updateEnd(values.end);
                        // Preview the start
                        controller.videoPlayerController?.seekTo(
                          Duration(seconds: values.start.toInt()),
                        );
                      }
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          FormatUtils.formatDuration(
                            Duration(
                              seconds: clipController.startSeconds.value
                                  .toInt(),
                            ),
                          ),
                          style: GoogleFonts.robotoMono(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          FormatUtils.formatDuration(
                            Duration(
                              seconds: clipController.endSeconds.value.toInt(),
                            ),
                          ),
                          style: GoogleFonts.robotoMono(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 48),

            // --- Actions ---
            Obx(
              () => SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: clipController.isSaving.value
                      ? null
                      : clipController.saveClip,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 8,
                    shadowColor: AppColors.brand.withValues(alpha: 0.4),
                  ),
                  child: clipController.isSaving.value
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          'Share Clip',
                          style: GoogleFonts.roboto(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Get.back(),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.roboto(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      barrierColor: Colors.black.withValues(alpha: 0.7),
      isScrollControlled: true,
    );
  }

  void _showPlayerSettings(BuildContext context) {
    Get.bottomSheet(
      Container(
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Player Settings',
              style: GoogleFonts.roboto(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            _settingsTile(
              Icons.speed_rounded,
              'Playback Speed',
              '${controller.videoPlayerController?.value.playbackSpeed ?? 1.0}x',
              () {},
            ),
            _settingsTile(Icons.high_quality_rounded, 'Quality', 'Auto', () {}),
            _settingsTile(
              Icons.loop_rounded,
              'Loop Video',
              controller.chewieController?.looping ?? false ? 'On' : 'Off',
              () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingsTile(
    IconData icon,
    String title,
    String value,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(icon, color: textSecondary),
      title: Text(
        title,
        style: GoogleFonts.roboto(fontWeight: FontWeight.w500),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(color: primary, fontWeight: FontWeight.w500),
          ),
          Icon(Icons.chevron_right_rounded),
        ],
      ),
      onTap: onTap,
    );
  }

  void _showDownloadQualityDialog(BuildContext context, bool isUserSignedIn) {
    if (!isUserSignedIn) return _showSignInPrompt();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.download_for_offline, color: primary),
                  const SizedBox(width: 12),
                  Text(
                    'Select Download Quality',
                    style: GoogleFonts.roboto(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white10),
            if (controller.availableResolutions.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  'No download options available for this video.',
                  style: GoogleFonts.roboto(color: textSecondary),
                ),
              )
            else
              ...controller.availableResolutions.map(
                (res) => ListTile(
                  leading: Icon(Icons.high_quality, color: textSecondary),
                  title: Text(
                    res.label,
                    style: GoogleFonts.roboto(color: textPrimary),
                  ),
                  subtitle: Text(
                    'Save to in-app library',
                    style: GoogleFonts.roboto(
                      color: textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    controller.saveVideoOffline(res);
                  },
                ),
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildModernActionButtons(BuildContext context) {
    final bool isUserSignedIn = FirebaseAuth.instance.currentUser != null;

    return Row(
      children: [
        // Scrollable Action Buttons (left side)
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                // Like & Dislike Group
                _buildModernLikeDislikeGroup(),
                const SizedBox(width: 8),

                // Share
                _buildModernCapsuleButton(
                  icon: Icons.share_rounded,
                  label: 'Share',
                  onTap: () {
                    _mainController.shareVideo(
                      controller.video.id,
                      controller.video.title,
                      thumbnailUrl: controller.video.thumbnailUrl,
                    );
                  },
                ),
                const SizedBox(width: 8),

                // Rating / Watch Later
                Obx(() {
                  final double rating = controller.video.videoRating;
                  if (rating > 0) {
                    return _buildModernCapsuleButton(
                      icon: Icons.auto_awesome_rounded,
                      label: '${rating.toInt()} Rating',
                      onTap: () => controller.fetchFullDisclosure(),
                    );
                  } else {
                    // Ensure reactivity to watch later playlist changes
                    _playlistController.playlists.length;
                    final isInWatchLater = _playlistController.isInWatchLater(
                      controller.video.id,
                    );
                    return _buildModernCapsuleButton(
                      icon: isInWatchLater
                          ? Icons.watch_later
                          : Icons.watch_later_outlined,
                      label: 'Watch Later',
                      onTap: () {
                        if (!isUserSignedIn) return _showSignInPrompt();
                        _playlistController.toggleWatchLater(
                          controller.video.id,
                        );
                      },
                    );
                  }
                }),
                const SizedBox(width: 8),

                // Save
                Obx(() {
                  if (controller.isDownloading.value) {
                    final progress = (controller.downloadProgress.value * 100)
                        .toInt();
                    return Material(
                      color: AppColors.bgSurface,
                      borderRadius: BorderRadius.circular(24),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Saving $progress%',
                              style: GoogleFonts.roboto(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return _buildModernCapsuleButton(
                    icon: Icons.bookmark_border_rounded,
                    label: 'Save',
                    onTap: () =>
                        _showDownloadQualityDialog(context, isUserSignedIn),
                  );
                }),
                const SizedBox(width: 8),

                // More
                _buildModernMoreButton(context),
              ],
            ),
          ),
        ),

        // Channel Section - fixed at the right corner
        _buildChannelSectionForActionRow(),
      ],
    );
  }

  Widget _buildChannelSectionForActionRow() {
    final bool isUserSignedIn = FirebaseAuth.instance.currentUser != null;

    if (controller.video.channelId.isEmpty) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('channels')
          .doc(controller.video.channelId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final channel = Channel.fromDocumentSnapshot(snapshot.data!);

        return Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Channel Avatar + Info - Tappable to navigate to channel
              InkWell(
                onTap: () => Get.toNamed('/channel/${channel.id}'),
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Channel Avatar - 40px circular
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.grey.shade800,
                      child: ClipOval(
                        child:
                            (channel.avatarUrl.isNotEmpty ||
                                channel.bannerImageUrl.isNotEmpty)
                            ? CachedNetworkImage(
                                imageUrl:
                                    (channel.avatarUrl.isNotEmpty
                                            ? channel.avatarUrl
                                            : channel.bannerImageUrl)
                                        .replaceAll(' ', '%20'),
                                placeholder: (context, url) => const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) =>
                                    const Icon(
                                      Icons.person,
                                      size: 20,
                                      color: Colors.white70,
                                    ),
                                fit: BoxFit.cover,
                                width: 40,
                                height: 40,
                              )
                            : const Icon(
                                Icons.person,
                                size: 20,
                                color: Colors.white70,
                              ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Channel Info (name + subscribers)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Channel Name with Verified Badge
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              channel.channelName,
                              style: GoogleFonts.roboto(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                            if (channel.isVerified) ...[
                              const SizedBox(width: 4),
                              // Grey/white checkmark badge matching image
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade400,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check,
                                  size: 10,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 1),
                        // Subscriber count in grey
                        Text(
                          '${FormatUtils.formatCount(channel.subscriberCount)} subscribers',
                          style: GoogleFonts.roboto(
                            color: Colors.grey.shade400,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Subscribe Button - White pill
              Obx(() {
                final isSubscribed = _channelController.isSubscribed.value;
                return ElevatedButton(
                  onPressed: () {
                    if (!isUserSignedIn) return _showSignInPrompt();
                    _channelController.toggleSubscription(
                      controller.video.channelId,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSubscribed
                        ? Colors.grey.shade800
                        : Colors.white,
                    foregroundColor: isSubscribed ? Colors.white : Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    elevation: 0,
                  ),
                  child: Text(
                    isSubscribed ? 'Subscribed' : 'Subscribe',
                    style: GoogleFonts.roboto(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModernLikeDislikeGroup() {
    final bool isUserSignedIn = FirebaseAuth.instance.currentUser != null;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Like Button
          Obx(() {
            final bool isLiked = controller.isLiked.value;
            return InkWell(
              onTap: () {
                if (!isUserSignedIn) return _showSignInPrompt();
                controller.toggleLike();
              },
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                bottomLeft: Radius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(
                      isLiked
                          ? Icons.thumb_up_rounded
                          : Icons.thumb_up_outlined,
                      size: 20,
                      color: isLiked ? primary : textPrimary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      FormatUtils.formatCount(
                        _mainController.videoLikes[controller.video.id] ??
                            controller.video.likes,
                      ),
                      style: GoogleFonts.roboto(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          // Divider
          Container(
            height: 20,
            width: 1,
            color: Colors.white.withValues(alpha: 0.1),
          ),
          // Dislike Button
          Obx(() {
            final bool isDisliked = controller.isDisliked.value;
            return InkWell(
              onTap: () {
                if (!isUserSignedIn) return _showSignInPrompt();
                controller.toggleDislike();
              },
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Icon(
                  isDisliked
                      ? Icons.thumb_down_rounded
                      : Icons.thumb_down_outlined,
                  size: 20,
                  color: isDisliked ? primary : textPrimary,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildModernCapsuleButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.bgSurface,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: textPrimary),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.roboto(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernMoreButton(BuildContext context) {
    return Material(
      color: AppColors.bgSurface,
      shape: const CircleBorder(),
      child: PopupMenuButton<String>(
        icon: const Icon(Icons.more_horiz_rounded, size: 20),
        color: AppColors.bgSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onSelected: (value) {
          switch (value) {
            case 'clip':
              _showClipDialog(context);
              break;
            case 'settings':
              _showPlayerSettings(context);
              break;
            case 'report':
              // Logic for report (usually requires sign in)
              if (FirebaseAuth.instance.currentUser == null) {
                _showSignInPrompt();
              } else {
                _mainController.reportVideo(
                  context: context,
                  videoId: controller.video.id,
                  channelId: controller.video.channelId,
                  reason: 'User reported',
                  comment: '',
                );
              }
              break;
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'clip',
            child: Row(
              children: [
                Icon(Icons.content_cut_rounded, size: 20),
                SizedBox(width: 12),
                Text('Clip'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'settings',
            child: Row(
              children: [
                Icon(Icons.settings_rounded, size: 20),
                SizedBox(width: 12),
                Text('Settings'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'report',
            child: Row(
              children: [
                Icon(Icons.flag_rounded, size: 20),
                SizedBox(width: 12),
                Text('Report'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistSidebarSection(BuildContext context) {
    return Obx(() {
      if (controller.currentPlaylist.value != null &&
          controller.playlistVideos.isNotEmpty &&
          controller.showPlaylistDrawer.value) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildPlaylistDrawer(context),
        );
      }
      return const SizedBox.shrink();
    });
  }

  Widget _buildChapters() {
    return Obx(() {
      final chapters = controller.video.chapters;
      if (chapters.isEmpty) return const SizedBox.shrink();

      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border.withValues(alpha: 0.5)),
        ),
        child: ExpansionTile(
          title: Row(
            children: [
              Icon(Icons.bookmarks_rounded, color: primary, size: 20),
              const SizedBox(width: 12),
              Text(
                "Chapters",
                style: GoogleFonts.roboto(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  chapters.length.toString(),
                  style: TextStyle(
                    color: primary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Obx(() {
            // Subscribe to VideoController to ensure Obx is never empty
            final _ = controller.video.id;
            final current = Get.isRegistered<TowerPlayerController>(tag: tag)
                ? Get.find<TowerPlayerController>(tag: tag).currentChapter.value
                : null;
            if (current == null) return const SizedBox.shrink();
            return Text(
              "Current: ${current.title}",
              style: TextStyle(color: textSecondary, fontSize: 13),
            );
          }),
          shape: const RoundedRectangleBorder(side: BorderSide.none),
          collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
          childrenPadding: EdgeInsets.zero,
          children: [
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: chapters.length,
              padding: const EdgeInsets.only(bottom: 8),
              itemBuilder: (context, index) {
                final chapter = chapters[index];
                return Obx(() {
                  // Subscribe to VideoController to ensure Obx is never empty
                  final _ = controller.video.id;
                  final isCurrent =
                      Get.isRegistered<TowerPlayerController>(tag: tag) &&
                      Get.find<TowerPlayerController>(
                            tag: tag,
                          ).currentChapter.value ==
                          chapter;

                  return InkWell(
                    onTap: () {
                      if (Get.isRegistered<TowerPlayerController>(tag: tag)) {
                        Get.find<TowerPlayerController>(
                          tag: tag,
                        ).seekTo(chapter.startTime);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      color: isCurrent ? primary.withValues(alpha: 0.05) : null,
                      child: Row(
                        children: [
                          Container(
                            width: 80,
                            height: 45,
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(8),
                              image: chapter.thumbnailUrl != null
                                  ? DecorationImage(
                                      image: CachedNetworkImageProvider(
                                        chapter.thumbnailUrl!,
                                      ),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                chapter.formattedStartTime,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  chapter.title,
                                  style: GoogleFonts.roboto(
                                    fontSize: 14,
                                    fontWeight: isCurrent
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: isCurrent ? primary : textPrimary,
                                  ),
                                ),
                                if (isCurrent)
                                  Text(
                                    "Now Playing",
                                    style: TextStyle(
                                      color: primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (isCurrent)
                            Icon(
                              Icons.play_circle_fill,
                              color: primary,
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  );
                });
              },
            ),
          ],
        ),
      );
    });
  }

  Widget _buildRecommendationHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            "Recommended",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          Row(
            children: [
              const Text(
                "Autoplay",
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              Switch(
                value: controller.isAutoplay.value,
                onChanged: (v) => controller.isAutoplay.value = v,
                activeThumbColor: primary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCommentsSlivers(BuildContext context) {
    final tag = 'video_${controller.video.id}';
    final commentsController = Get.find<CommentsControllerV2>(tag: tag);
    final currentUser = FirebaseAuth.instance.currentUser;

    // Real comments list based on reactive state
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: currentUser != null
              ? PremiumCommentInput(
                  key: ValueKey('main_comment_input_${controller.video.id}'),
                  videoId: controller.video.id,
                  onSubmit: (text, postAsChannel, channelId) async {
                    try {
                      await commentsController.submitComment(
                        text: text,
                        channelId: postAsChannel ? channelId : null,
                        channelName: postAsChannel ? 'Current Channel' : null,
                        channelProfilePicUrl: null,
                        userProfilePicUrl: currentUser.photoURL ?? '',
                      );
                      if (Get.context != null) {
                        Get.snackbar(
                          'Success',
                          'Comment posted',
                          snackPosition: SnackPosition.BOTTOM,
                          duration: const Duration(seconds: 2),
                        );
                      }
                    } catch (e) {
                      if (Get.context != null) {
                        Get.snackbar(
                          'Error',
                          'Failed to post comment: $e',
                          snackPosition: SnackPosition.BOTTOM,
                        );
                      }
                    }
                  },
                  onCancel: () {},
                )
              : Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Sign in to comment',
                    style: GoogleFonts.roboto(color: textSecondary),
                  ),
                ),
        ),
      ),

      if (commentsController.commentsError.value != null)
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Text(
              'Error: ${commentsController.commentsError.value}',
              style: TextStyle(color: textSecondary),
            ),
          ),
        )
      else if (commentsController.isLoadingComments.value &&
          commentsController.comments.isEmpty)
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        )
      else if (commentsController.comments.isEmpty)
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline, color: textSecondary, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'No comments yet',
                  style: TextStyle(color: textSecondary, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'Be the first to comment!',
                  style: TextStyle(
                    color: textSecondary.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        )
      else
        SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final comment = commentsController.comments[index];
            final data = {
              'id': comment.id,
              'userName': comment.userName,
              'text': comment.text,
              'createdAt': comment.createdAt,
              'userProfilePicUrl': comment.userProfilePicUrl,
              'likeCount': comment.likeCount,
              'dislikeCount': comment.dislikeCount,
            };
            return _buildCommentItem(data, controller.video.id);
          }, childCount: commentsController.comments.length),
        ),
    ];
  }

  Widget _buildCommentItem(Map<String, dynamic> data, String videoId) {
    return _CommentItemWidget(
      data: data,
      videoId: videoId,
      mainController: Get.find<MainController>(),
      textSecondary: textSecondary,
    );
  }

  Widget _buildDescriptionBox(BuildContext context) {
    return Obx(() {
      final bool expanded = controller.isExpanded.value;
      return InkWell(
        onTap: () => controller.isExpanded.value = !expanded,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${_formatViews(controller.video.views)} views',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    timeago.format(controller.video.uploadedAt.toDate()),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                controller.video.description,
                maxLines: expanded ? null : 2,
                overflow: expanded
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
                style: GoogleFonts.roboto(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              if (!expanded && controller.video.description.length > 60)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '...more',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    return BottomNavigationBar(
      backgroundColor: AppColors.bgSurface,
      selectedItemColor: primary,
      unselectedItemColor: textSecondary,
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(
          icon: Icon(Icons.smart_display),
          label: 'Shorts',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.add_circle), label: 'Create'),
        BottomNavigationBarItem(
          icon: Icon(Icons.subscriptions),
          label: 'Subscriptions',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.video_library),
          label: 'Library',
        ),
      ],
      onTap: (index) {},
    );
  }

  void _showSignInPrompt() {
    Get.snackbar('Sign in required', 'Please sign in to proceed');
  }

  String _formatViews(int views) {
    if (views >= 1000000) return '${(views / 1000000).toStringAsFixed(1)}M';
    if (views >= 1000) return '${(views / 1000).toStringAsFixed(1)}K';
    return views.toString();
  }

  Widget _buildUpNext({required Video currentVideo, required String videoId}) {
    return SliverToBoxAdapter(
      child: RecommendationFeed(
        videos: controller.moreFromChannel,
        video: currentVideo,
        videoTag: videoId,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        isGrid: true,
      ),
    );
  }
}

// ==========================================================================
// COMMENT ITEM WIDGET WITH LIKE/DISLIKE/REPLY
// ==========================================================================

class _CommentItemWidget extends StatefulWidget {
  final Map<String, dynamic> data;
  final String videoId;
  final MainController mainController;
  final Color textSecondary;

  const _CommentItemWidget({
    required this.data,
    required this.videoId,
    required this.mainController,
    required this.textSecondary,
  });

  @override
  State<_CommentItemWidget> createState() => _CommentItemWidgetState();
}

class _CommentItemWidgetState extends State<_CommentItemWidget> {
  bool isReplying = false;
  bool isLiked = false;
  bool isDisliked = false;
  bool _isRepliesExpanded = false;
  final TextEditingController replyController = TextEditingController();
  final FocusNode replyFocusNode = FocusNode();

  @override
  void dispose() {
    replyController.dispose();
    replyFocusNode.dispose();
    super.dispose();
  }

  void _submitReply() async {
    final text = replyController.text.trim();
    if (text.isEmpty) return;

    final commentId = widget.data['id'] ?? '';
    if (commentId.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Get.snackbar('Sign in required', 'Please sign in to reply');
      return;
    }

    try {
      await widget.mainController.addReply(
        videoId: widget.videoId,
        commentId: commentId,
        userId: user.uid,
        userName: user.displayName ?? 'Anonymous User',
        userProfilePicUrl: user.photoURL ?? '',
        text: text,
      );

      replyController.clear();
      setState(() {
        isReplying = false;
      });

      Get.snackbar('Success', 'Reply posted');
    } catch (e) {
      debugPrint('Error posting reply: $e');
      Get.snackbar('Error', 'Failed to post reply');
    }
  }

  @override
  Widget build(BuildContext context) {
    final String userName = widget.data['userName'] ?? 'Anonymous';
    final String text = widget.data['text'] ?? '';
    final Timestamp? createdAt = widget.data['createdAt'] as Timestamp?;
    final String? userProfilePicUrl =
        widget.data['userProfilePicUrl'] as String?;
    final int likeCount = widget.data['likeCount'] ?? 0;
    final int dislikeCount = widget.data['dislikeCount'] ?? 0;
    final String commentId = widget.data['id'] ?? '';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UserAvatar(
                radius: 20,
                photoUrl: userProfilePicUrl,
                displayName: userName,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          userName,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (createdAt != null)
                          Text(
                            timeago.format(createdAt.toDate()),
                            style: TextStyle(
                              color: widget.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(text, style: TextStyle(fontSize: 14, height: 1.4)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Like button
                        InkWell(
                          onTap: () {
                            final tag = 'video_${widget.videoId}';
                            final commentsController =
                                Get.find<CommentsControllerV2>(tag: tag);
                            commentsController.toggleCommentLike(
                              commentId: commentId,
                              likeAsChannel: false,
                            );
                          },
                          child: Row(
                            children: [
                              Icon(
                                isLiked
                                    ? Icons.thumb_up
                                    : Icons.thumb_up_outlined,
                                size: 16,
                                color: isLiked
                                    ? Colors.red
                                    : widget.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$likeCount',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isLiked
                                      ? Colors.red
                                      : widget.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Dislike button with count
                        InkWell(
                          onTap: () {
                            final tag = 'video_${widget.videoId}';
                            final commentsController =
                                Get.find<CommentsControllerV2>(tag: tag);
                            commentsController.toggleCommentDislike(
                              commentId: commentId,
                              dislikeAsChannel: false,
                            );
                          },
                          child: Row(
                            children: [
                              Icon(
                                isDisliked
                                    ? Icons.thumb_down
                                    : Icons.thumb_down_outlined,
                                size: 16,
                                color: isDisliked
                                    ? Colors.red
                                    : widget.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              if (dislikeCount > 0)
                                Text(
                                  '$dislikeCount',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDisliked
                                        ? Colors.red
                                        : widget.textSecondary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Reply button
                        InkWell(
                          onTap: () {
                            setState(() {
                              isReplying = !isReplying;
                            });
                            if (isReplying) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted && replyFocusNode.canRequestFocus) {
                                  FocusScope.of(
                                    context,
                                  ).requestFocus(replyFocusNode);
                                }
                              });
                            }
                          },
                          child: Text(
                            'Reply',
                            style: TextStyle(
                              fontSize: 12,
                              color: isReplying
                                  ? Colors.red
                                  : widget.textSecondary,
                              fontWeight: isReplying
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Inline reply input field
          if (isReplying)
            Padding(
              key: ValueKey('reply_box_${widget.data['id']}'),
              padding: EdgeInsets.only(left: 52, top: 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: replyController,
                      focusNode: replyFocusNode,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Add a reply...',
                        hintStyle: TextStyle(
                          color: widget.textSecondary.withValues(alpha: 0.7),
                          fontSize: 14,
                        ),
                        filled: true,
                        fillColor: AppColors.bgSurface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      style: TextStyle(fontSize: 14),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _submitReply(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Cancel button
                  IconButton(
                    onPressed: () {
                      setState(() {
                        isReplying = false;
                        replyController.clear();
                      });
                    },
                    icon: Icon(
                      Icons.close,
                      size: 20,
                      color: widget.textSecondary,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                  // Submit button
                  IconButton(
                    onPressed: _submitReply,
                    icon: Icon(
                      Icons.send,
                      size: 20,
                      color: replyController.text.isNotEmpty
                          ? Colors.red
                          : widget.textSecondary,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),
          // Replies list
          if (commentId.isNotEmpty) _buildRepliesList(commentId),
        ],
      ),
    );
  }

  Widget _buildRepliesList(String commentId) {
    return StreamBuilder<List<Reply>>(
      stream: widget.mainController.getRepliesStream(widget.videoId, commentId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.only(left: 52, top: 8),
            child: SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final replies = snapshot.data ?? [];
        if (replies.isEmpty) {
          return const SizedBox.shrink();
        }

        // Show all replies if 2 or less, otherwise show expand/collapse
        final hasMultipleReplies = replies.length > 2;

        return Padding(
          padding: EdgeInsets.only(left: 52, top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Show first 2 replies always, or all if expanded
              if (!hasMultipleReplies || _isRepliesExpanded)
                ...replies.map((reply) => _buildReplyItem(reply))
              else ...[
                // Show only first 2 replies when collapsed
                _buildReplyItem(replies[0]),
                _buildReplyItem(replies[1]),
                // Show "Show all X replies" button
                _buildShowAllRepliesButton(replies.length),
              ],
              // Show "Hide replies" button when expanded with multiple replies
              if (hasMultipleReplies && _isRepliesExpanded)
                _buildHideRepliesButton(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShowAllRepliesButton(int totalCount) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: () {
          setState(() {
            _isRepliesExpanded = true;
          });
        },
        child: Row(
          children: [
            Icon(Icons.expand_more, size: 18, color: Colors.red),
            const SizedBox(width: 4),
            Text(
              'Show all $totalCount replies',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHideRepliesButton() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: () {
          setState(() {
            _isRepliesExpanded = false;
          });
        },
        child: Row(
          children: [
            Icon(Icons.expand_less, size: 18, color: widget.textSecondary),
            const SizedBox(width: 4),
            Text(
              'Hide replies',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: widget.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyItem(Reply reply) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(
            radius: 16,
            photoUrl: reply.userProfilePicUrl,
            displayName: reply.userName,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      reply.userName,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      timeago.format(reply.createdAt.toDate()),
                      style: TextStyle(
                        color: widget.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(reply.text, style: TextStyle(fontSize: 13, height: 1.4)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    // Reply Like
                    InkWell(
                      onTap: () {
                        final tag = 'video_${widget.videoId}';
                        final commentsController =
                            Get.find<CommentsControllerV2>(tag: tag);
                        commentsController.toggleReplyLike(
                          commentId: reply.commentId,
                          replyId: reply.id,
                          likeAsChannel: false,
                        );
                      },
                      child: Row(
                        children: [
                          Icon(
                            Icons.thumb_up_outlined,
                            size: 14,
                            color: widget.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${reply.likeCount}',
                            style: TextStyle(
                              fontSize: 11,
                              color: widget.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Reply Dislike
                    InkWell(
                      onTap: () {
                        final tag = 'video_${widget.videoId}';
                        final commentsController =
                            Get.find<CommentsControllerV2>(tag: tag);
                        commentsController.toggleReplyDislike(
                          commentId: reply.commentId,
                          replyId: reply.id,
                          dislikeAsChannel: false,
                        );
                      },
                      child: Row(
                        children: [
                          Icon(
                            Icons.thumb_down_outlined,
                            size: 14,
                            color: widget.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${reply.dislikeCount}',
                            style: TextStyle(
                              fontSize: 11,
                              color: widget.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================================================
// RECOMMENDATION FEED WIDGETS
// ==========================================================================

class RecommendationFeed extends StatelessWidget {
  final Video video;
  final String? videoTag;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final List<Video>? videos;
  final bool isGrid;

  const RecommendationFeed({
    super.key,
    required this.video,
    this.videoTag,
    this.shrinkWrap = false,
    this.physics,
    this.videos,
    this.isGrid = false,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<VideoController>(tag: videoTag);

    return Obx(() {
      if (controller.isLoadingRecommendations.value) {
        return const Center(child: CircularProgressIndicator());
      }

      final displayVideos = videos ?? controller.recommendedVideos;

      if (displayVideos.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(32.0),
            child: Text(
              "No recommendations found",
              style: TextStyle(color: Colors.white24),
            ),
          ),
        );
      }

      if (isGrid) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final double width = constraints.maxWidth;
            int crossAxisCount = 1;
            double aspectRatio = 1.2;

            if (width > 1200) {
              crossAxisCount = 4;
              aspectRatio = 1.1;
            } else if (width > 900) {
              crossAxisCount = 3;
              aspectRatio = 1.1;
            } else if (width > 600) {
              crossAxisCount = 2;
              aspectRatio = 1.2;
            }

            return GridView.builder(
              shrinkWrap: shrinkWrap,
              physics: physics,
              padding: const EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: aspectRatio,
              ),
              itemCount: displayVideos.length,
              itemBuilder: (context, index) => VideoCard(
                video: displayVideos[index],
                isGrid: true,
                heroPrefix: 'rec_grid_${videoTag ?? 'global'}',
              ),
            );
          },
        );
      }

      return ListView.builder(
        shrinkWrap: shrinkWrap,
        physics: physics,
        padding: const EdgeInsets.all(16),
        itemCount: displayVideos.length,
        itemBuilder: (context, index) => VideoCard(
          video: displayVideos[index],
          isGrid: false,
          heroPrefix: 'rec_list_${videoTag ?? 'global'}',
        ),
      );
    });
  }
}
