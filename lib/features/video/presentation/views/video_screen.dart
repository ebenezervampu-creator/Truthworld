import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:truthworld/core/widgets/shimmer_skeletons.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:truthworld/features/video/presentation/views/comments/premium_comment_input.dart';
import 'package:truthworld/features/video/presentation/controllers/comments_controller.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/features/video/data/models/comment.dart';
import 'package:truthworld/features/video/data/models/reply.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/home/presentation/controllers/main_controller.dart';
import 'package:truthworld/features/miniplayer/presentation/controllers/miniplayer_controller.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_controller.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/theme/app_theme.dart';
import '../controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/tower_custom_player.dart';
import '../../../channel/presentation/controllers/channel_controller_unified.dart';
import '../widgets/truth_index_badge.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/video/presentation/controllers/clip_controller.dart';
import 'package:truthworld/components/ui/video_card.dart';
import 'package:truthworld/features/video/presentation/widgets/video_analysis_bottom_sheet.dart';

class VideoScreen extends GetView<VideoController> {
  final String? videoTag;
  const VideoScreen({super.key, this.videoTag});

  @override
  String? get tag => videoTag;

  bool _isMobilePlatform(BuildContext context) {
    return defaultTargetPlatform == TargetPlatform.android ||
           defaultTargetPlatform == TargetPlatform.iOS;
  }

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

    // Dismiss miniplayer once when screen first builds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Get.isRegistered<MiniplayerController>(tag: 'miniplayer')) {
        MiniplayerController.to.dismiss();
      }
    });

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        // Handled by VideoController onClose to ensure unified exit logic
      },
      child: Obx(() {
        if (ctrl.video.id.isEmpty) {
          return const ShimmerVideoScreen();
        }

        final isFs = ctrl.isFullScreen.value;
        return Scaffold(
          backgroundColor: background,
          extendBodyBehindAppBar: true,
          // Hide appbar in fullscreen mode cleanly with local rebuild only
          appBar: _ResponsiveAppBar(
            controller: ctrl,
            appBarBuilder: () => _buildAppBar(context),
          ),
          body: isFs
              ? Container(
                  color: Colors.black,
                  child: Center(
                    child: _buildVideoPlayer(),
                  ),
                )
              : SafeArea(
                  top: true,
                  child: ResponsiveBuilder(
                    builder: (context, device) {
                      final bool isDesktop = device.isDesktop || device.isLargeDesktop || device.isUltraWide;
                      return isDesktop
                          ? _buildDesktopLayout(context)
                          : _buildMobileLayout(context);
                    },
                  ),
                ),
        );
      }),
    );
  }

  // Getters for other controllers
  ChannelController get _channelController =>
      Get.find<ChannelController>(tag: tag);
  MainController get _mainController => Get.find<MainController>();
  PlaylistController get _playlistController => Get.find<PlaylistController>();


  // ==========================================================================
  // RESPONSIVE LAYOUTS
  // ==========================================================================

  Widget _buildMobileLayout(BuildContext context) {
    return CustomScrollView(
      controller: controller.scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        _buildVideoPlayerSection(),
        _buildVideoInfoSection(context),
        if (_isMobilePlatform(context))
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
          )
        else
          ..._buildCommentsSlivers(context),
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
              if (_isMobilePlatform(context))
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
                )
              else
                ..._buildCommentsSlivers(context),
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
  // SHARED WIDGETS
  // ==========================================================================

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final bool isDesktop = context.isDesktop || context.isLargeDesktop || context.isUltraWide;
    // Check if user came from home screen
    final previousRoute = Get.previousRoute;
    final isFromHome =
        previousRoute.contains('home') ||
        previousRoute.isEmpty ||
        previousRoute == '/';

    if (isFromHome && isDesktop) {
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
          child: Icon(Icons.arrow_back, size: 18, color: textPrimary),
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
            onTap: () => Get.offAllNamed("/"),
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
                    onTap: () => Get.offAndToNamed('/search'),
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
    // Normal mode - show video with aspect ratio. Always keep the video player
    // mounted in the widget tree so Chewie can transition to and from fullscreen smoothly.
    return SliverToBoxAdapter(
      child: Obx(() {
        final vpc = controller.videoPlayerController;
        double ratio = controller.video.isShort ? 9 / 16 : 16 / 9;
        if (vpc != null && vpc.value.isInitialized) {
          ratio = vpc.value.aspectRatio;
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final mediaQuery = MediaQuery.of(context);
            final screenHeight = mediaQuery.size.height;
            final maxWidth = constraints.maxWidth;
            
            // Calculate height for this aspect ratio
            double height = maxWidth / ratio;
            
            // Define max height constraints
            // On desktop, cap to 65% of screen height.
            // On mobile, cap to 55% of screen height to keep controls and comments visible.
            final bool isDesktop = mediaQuery.size.width > 1050;
            final double maxHeight = isDesktop 
                ? screenHeight * 0.65 
                : screenHeight * 0.55;
            
            double finalHeight = height;
            double finalRatio = ratio;
            
            if (height > maxHeight) {
              finalHeight = maxHeight;
              finalRatio = maxWidth / finalHeight;
            }
            
            final double finalWidth = finalHeight * finalRatio;

            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // YouTube Ambient Mode Glow (glow matches video thumbnail and is 30% wider)
                if (!controller.isFullScreen.value && controller.video.thumbnailUrl.isNotEmpty)
                  Positioned(
                    width: finalWidth * 1.3,
                    height: finalHeight,
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 1000),
                        opacity: controller.showThumbnail.value ? 0.08 : 0.18,
                        child: Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.rectangle,
                          ),
                          child: ClipRect(
                            child: ImageFiltered(
                              imageFilter: ui.ImageFilter.blur(
                                sigmaX: 65,
                                sigmaY: 65,
                                tileMode: TileMode.decal,
                              ),
                              child: CachedNetworkImage(
                                imageUrl: controller.video.thumbnailUrl.replaceAll(' ', '%20'),
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => const SizedBox.shrink(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Video Player Container
                AspectRatio(
                  aspectRatio: finalRatio.isFinite && finalRatio > 0 ? finalRatio : 16 / 9,
                  child: Container(
                    color: Colors.black,
                    child: _buildVideoPlayer(),
                  ),
                ),
              ],
            );
          },
        );
      }),
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
                    padding: const EdgeInsets.all(16.0),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.white,
                            size: 40,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            controller.errorMessage.value.isNotEmpty
                                ? controller.errorMessage.value
                                : 'This video is currently unavailable',
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.roboto(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 16),
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
            TowerCustomPlayer(
              videoPlayerController: controller.videoPlayerController!,
              tag: controller.video.id,
            ),

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

  void _showReportBottomSheet(BuildContext context) {
    if (!AuthService.to.isAuthenticated.value) {
      _showSignInPrompt();
      return;
    }

    final reasons = [
      {
        'label': 'Sexual content',
        'description': 'Nudity, sexually explicit content, or pornography',
      },
      {
        'label': 'Violent or repulsive content',
        'description': 'Fight clips, self-harm, gore, or animal abuse',
      },
      {
        'label': 'Hateful or abusive content',
        'description': 'Promoting violence or hatred against protected groups',
      },
      {
        'label': 'Harassment or bullying',
        'description': 'Cyberbullying or personal abuse',
      },
      {
        'label': 'Harmful or dangerous acts',
        'description': 'Dangerous challenges, stunts, or drug promotion',
      },
      {
        'label': 'Child abuse',
        'description': 'Endangerment, exploitation, or sexualization of minors',
      },
      {
        'label': 'Promotes terrorism',
        'description': 'Incitement to violence or terrorist recruitment',
      },
      {
        'label': 'Spam or misleading',
        'description': 'Scams, clickbait, or deceptive metadata',
      },
      {
        'label': 'Infringement of my rights',
        'description': 'Copyright violation or privacy invasion',
      },
    ];

    final RxnString selectedReason = RxnString();
    final RxInt currentStep = 1.obs; // Step 1: select reason, Step 2: comment & timestamp
    final commentController = TextEditingController();
    
    // Get current playback time to suggest as timestamp
    final currentSeconds = controller.videoPlayerController?.value.position.inSeconds ?? 0;
    final minutes = currentSeconds ~/ 60;
    final seconds = currentSeconds % 60;
    final defaultTimestamp = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    final RxBool includeTimestamp = false.obs;

    Get.bottomSheet(
      Obx(() {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          decoration: const BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              const SizedBox(height: 20),
              
              // Header
              Row(
                children: [
                  if (currentStep.value == 2)
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                      onPressed: () {
                        currentStep.value = 1;
                      },
                    ),
                  Icon(Icons.flag_rounded, color: primary, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    currentStep.value == 1 ? 'Report video' : 'Provide details',
                    style: GoogleFonts.roboto(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (currentStep.value == 1) ...[
                // Info note
                Text(
                  'Flagged videos are reviewed by staff 24/7 to determine whether they violate Community Guidelines. Severe violations may result in immediate video removal or account termination.',
                  style: GoogleFonts.roboto(
                    color: textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Reasons List
                Flexible(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 350),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: reasons.length,
                      itemBuilder: (context, index) {
                        final r = reasons[index];
                        final label = r['label']!;
                        final desc = r['description']!;
                        final isSelected = selectedReason.value == label;

                        return InkWell(
                          onTap: () {
                            selectedReason.value = label;
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Radio<String>(
                                  value: label,
                                  groupValue: selectedReason.value,
                                  activeColor: primary,
                                  onChanged: (val) {
                                    selectedReason.value = val;
                                  },
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        label,
                                        style: GoogleFonts.roboto(
                                          fontSize: 14,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          color: textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        desc,
                                        style: GoogleFonts.roboto(
                                          fontSize: 11,
                                          color: textSecondary,
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
                ),
                const SizedBox(height: 24),
                
                // Next / Cancel
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Get.back(),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.roboto(color: textSecondary),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: selectedReason.value == null
                          ? null
                          : () {
                              currentStep.value = 2;
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: primary.withValues(alpha: 0.3),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        'Next',
                        style: GoogleFonts.roboto(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // Step 2: Timestamp & comments
                Text(
                  'Selected Reason: ${selectedReason.value}',
                  style: GoogleFonts.roboto(
                    color: textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Timestamp checkbox
                CheckboxListTile(
                  value: includeTimestamp.value,
                  activeColor: primary,
                  title: Text(
                    'Include timestamp at $defaultTimestamp',
                    style: GoogleFonts.roboto(color: textPrimary, fontSize: 13),
                  ),
                  subtitle: Text(
                    'Helps reviewers locate the issue quickly',
                    style: GoogleFonts.roboto(color: textSecondary, fontSize: 11),
                  ),
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) {
                    includeTimestamp.value = val ?? false;
                  },
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: commentController,
                  maxLines: 4,
                  maxLength: 500,
                  style: TextStyle(color: textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Provide additional details (e.g. description, background info)...',
                    hintStyle: TextStyle(color: textSecondary, fontSize: 13),
                    filled: true,
                    fillColor: AppColors.bgInput,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    counterStyle: TextStyle(color: textSecondary, fontSize: 11),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Submit / Back
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        currentStep.value = 1;
                      },
                      child: Text(
                        'Back',
                        style: GoogleFonts.roboto(color: textSecondary),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () {
                        Get.back();
                        
                        // Build detailed comment including timestamp
                        final timestampPrefix = includeTimestamp.value ? '[Timestamp: $defaultTimestamp] ' : '';
                        final finalComment = '$timestampPrefix${commentController.text.trim()}';

                        _mainController.reportVideo(
                          context: context,
                          videoId: controller.video.id,
                          channelId: controller.video.channelId,
                          reason: selectedReason.value!,
                          comment: finalComment,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        'Submit',
                        style: GoogleFonts.roboto(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      }),
      isScrollControlled: true,
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
    final mediaQuery = MediaQuery.of(context);
    final bool isDesktop = mediaQuery.size.width > 1050;

    if (!isDesktop) {
      // Mobile Layout: Two separate rows for maximum readability and proper spacing
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Row 1: Channel Info & Subscribe Button
          _buildChannelSectionForActionRowMobile(),
          const SizedBox(height: 12),
          // Row 2: Scrollable Action Buttons
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                // Like & Dislike Group
                _buildModernLikeDislikeGroup(),
                const SizedBox(width: 8),

                // Comment
                if (_isMobilePlatform(context)) ...[
                  _buildModernCapsuleButton(
                    icon: Icons.comment_rounded,
                    label: 'Comment',
                    onTap: () {
                      _showCommentsBottomSheet(context);
                    },
                  ),
                  const SizedBox(width: 8),
                ],

                // Share
                _buildModernCapsuleButton(
                  icon: Icons.share_rounded,
                  label: 'Share',
                  onTap: () {
                    _mainController.shareVideo(
                      controller.video.id,
                      controller.video.title,
                      thumbnailUrl: controller.video.thumbnailUrl,
                      channelName: controller.video.channelName,
                      durationMs: controller.video.durationValue.inMilliseconds,
                      currentPosition: controller.videoPlayerController?.value.position,
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
                      onTap: () => _showAnalysisBottomSheet(context, initialTabIndex: 0),
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

                // Insights & Media details button (Always available)
                _buildModernCapsuleButton(
                  icon: Icons.verified_user_outlined,
                  label: 'Insights & Media',
                  onTap: () => _showAnalysisBottomSheet(context, initialTabIndex: 0),
                ),
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
        ],
      );
    }

    // Desktop Layout: Single row with scrollable action buttons on left and channel info on right
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

                // Comment
                if (_isMobilePlatform(context)) ...[
                  _buildModernCapsuleButton(
                    icon: Icons.comment_rounded,
                    label: 'Comment',
                    onTap: () {
                      _showCommentsBottomSheet(context);
                    },
                  ),
                  const SizedBox(width: 8),
                ],

                // Share
                _buildModernCapsuleButton(
                  icon: Icons.share_rounded,
                  label: 'Share',
                  onTap: () {
                    _mainController.shareVideo(
                      controller.video.id,
                      controller.video.title,
                      thumbnailUrl: controller.video.thumbnailUrl,
                      channelName: controller.video.channelName,
                      durationMs: controller.video.durationValue.inMilliseconds,
                      currentPosition: controller.videoPlayerController?.value.position,
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
                      onTap: () => _showAnalysisBottomSheet(context, initialTabIndex: 0),
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

                // Insights & Media details button (Always available)
                _buildModernCapsuleButton(
                  icon: Icons.verified_user_outlined,
                  label: 'Insights & Media',
                  onTap: () => _showAnalysisBottomSheet(context, initialTabIndex: 0),
                ),
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

  Widget _buildChannelSectionForActionRowMobile() {
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
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: const BoxDecoration(
            color: Colors.transparent,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left: Channel Avatar + Info
              Expanded(
                child: InkWell(
                  onTap: () => Get.offAndToNamed(
                    channel.channelRoute,
                    arguments: {'channel': channel},
                  ),
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    children: [
                      // Channel Avatar
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.grey.shade800,
                        child: ClipOval(
                          child: (channel.avatarUrl.isNotEmpty ||
                                  channel.bannerImageUrl.isNotEmpty)
                              ? CachedNetworkImage(
                                  imageUrl: (channel.avatarUrl.isNotEmpty
                                          ? channel.avatarUrl
                                          : channel.bannerImageUrl)
                                      .replaceAll(' ', '%20'),
                                  placeholder: (context, url) => const Center(
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      const Icon(
                                        Icons.person,
                                        size: 16,
                                        color: Colors.white70,
                                      ),
                                  fit: BoxFit.cover,
                                  width: 36,
                                  height: 36,
                                )
                              : const Icon(
                                  Icons.person,
                                  size: 16,
                                  color: Colors.white70,
                                ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Channel Info
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    channel.channelName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.roboto(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                if (channel.isVerified) ...[
                                  const SizedBox(width: 4),
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
                            Text(
                              '${FormatUtils.formatCount(channel.subscriberCount)} subscribers',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.roboto(
                                color: Colors.grey.shade400,
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Right: Subscribe Button + Notification bell if subbed
              Obx(() {
                final isSubbed = _channelController.isSubscribed.value;
                final notificationsEnabled = _channelController.notificationsEnabled.value;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () {
                        if (!isUserSignedIn) return _showSignInPrompt();
                        _channelController.toggleSubscription(controller.video.channelId);
                      },
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isSubbed
                              ? Colors.white.withValues(alpha: 0.15)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          isSubbed ? 'Subscribed' : 'Subscribe',
                          style: GoogleFonts.roboto(
                            color: isSubbed ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    if (isSubbed) ...[
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _showVideoPageNotificationsDialog(context, controller.video.channelId),
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            notificationsEnabled ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              }),
            ],
          ),
        );
      },
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
                onTap: () => Get.offAndToNamed(
                  channel.channelRoute,
                  arguments: {'channel': channel},
                ),
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
                final notificationsEnabled = _channelController.notificationsEnabled.value;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
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
                    ),
                    if (isSubscribed) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => _showVideoPageNotificationsDialog(context, controller.video.channelId),
                        icon: Icon(
                          notificationsEnabled ? Icons.notifications_active : Icons.notifications_off,
                          color: Colors.white,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.grey.shade800,
                          padding: const EdgeInsets.all(8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ],
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showVideoPageNotificationsDialog(BuildContext context, String channelId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: textSecondary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Notification settings',
              style: GoogleFonts.roboto(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Obx(() {
              final isAll = _channelController.notificationsEnabled.value;
              return Column(
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.notifications_active,
                      color: isAll ? primary : textPrimary,
                    ),
                    title: Text(
                      'All notifications',
                      style: GoogleFonts.roboto(
                        color: isAll ? primary : textPrimary,
                        fontWeight: isAll ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    trailing: isAll ? const Icon(Icons.check, color: primary) : null,
                    onTap: () {
                      Navigator.pop(context);
                      _channelController.updateNotificationPreference(channelId, true);
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.notifications_off,
                      color: !isAll ? primary : textPrimary,
                    ),
                    title: Text(
                      'None',
                      style: GoogleFonts.roboto(
                        color: !isAll ? primary : textPrimary,
                        fontWeight: !isAll ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    trailing: !isAll ? const Icon(Icons.check, color: primary) : null,
                    onTap: () {
                      Navigator.pop(context);
                      _channelController.updateNotificationPreference(channelId, false);
                    },
                  ),
                ],
              );
            }),
          ],
        ),
      ),
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
            return _AnimatedReactionButton(
              icon: isLiked ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
              isActive: isLiked,
              activeColor: primary,
              inactiveColor: textPrimary,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                bottomLeft: Radius.circular(24),
              ),
              onTap: () {
                if (!isUserSignedIn) return _showSignInPrompt();
                controller.toggleLike();
              },
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
            return _AnimatedReactionButton(
              icon: isDisliked ? Icons.thumb_down_rounded : Icons.thumb_down_outlined,
              isActive: isDisliked,
              activeColor: primary,
              inactiveColor: textPrimary,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
              onTap: () {
                if (!isUserSignedIn) return _showSignInPrompt();
                controller.toggleDislike();
              },
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

  void _showAnalysisBottomSheet(BuildContext context, {int initialTabIndex = 0}) {
    Get.bottomSheet(
      VideoAnalysisBottomSheet(
        video: controller.video,
        initialTabIndex: initialTabIndex,
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
              _showReportBottomSheet(context);
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
                                      onError: (exception, stackTrace) {},
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
    final commentsController = Get.find<CommentsController>(tag: tag);
    final currentUser = FirebaseAuth.instance.currentUser;

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Obx(() {
                    final count = commentsController.comments.length;
                    return Text(
                      '$count Comments',
                      style: GoogleFonts.roboto(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }),
                  const SizedBox(width: 24),
                  PopupMenuButton<bool>(
                    onSelected: (bool newest) {
                      commentsController.sortComments(newest);
                    },
                    offset: const Offset(0, 30),
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<bool>>[
                      PopupMenuItem<bool>(
                        value: false,
                        child: Obx(() {
                          final isSelected = !commentsController.isSortNewest.value;
                          return Row(
                            children: [
                              Icon(
                                Icons.check, 
                                size: 18, 
                                color: isSelected ? Colors.white : Colors.transparent,
                              ),
                              const SizedBox(width: 8),
                              const Text('Top comments'),
                            ],
                          );
                        }),
                      ),
                      PopupMenuItem<bool>(
                        value: true,
                        child: Obx(() {
                          final isSelected = commentsController.isSortNewest.value;
                          return Row(
                            children: [
                              Icon(
                                Icons.check, 
                                size: 18, 
                                color: isSelected ? Colors.white : Colors.transparent,
                              ),
                              const SizedBox(width: 8),
                              const Text('Newest first'),
                            ],
                          );
                        }),
                      ),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.sort_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Sort by',
                            style: GoogleFonts.roboto(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              currentUser != null
                  ? PremiumCommentInput(
                      key: ValueKey('main_comment_input_${controller.video.id}'),
                      videoId: controller.video.id,
                      onSubmit: (text, postAsChannel, channelId) async {
                        try {
                          final authService = AuthService.to;
                          final hasChannel = authService.hasChannel.value;
                          final channel = authService.userChannel;

                          final bool shouldPostAsChannel = postAsChannel || hasChannel;
                          final String? targetChannelId = shouldPostAsChannel ? (channelId ?? channel?.id) : null;
                          final String? targetChannelName = shouldPostAsChannel ? (channel?.handle.isNotEmpty == true ? channel?.handle : channel?.name) : null;
                          final String? targetChannelAvatar = shouldPostAsChannel ? channel?.avatarUrl : null;
                          final String targetUserAvatar = AuthService.to.activePhotoUrl;

                          await commentsController.submitComment(
                            text: text,
                            channelId: targetChannelId,
                            channelName: targetChannelName,
                            channelProfilePicUrl: targetChannelAvatar,
                            userProfilePicUrl: targetUserAvatar,
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
            ],
          ),
        ),
      ),

      Obx(() {
        if (commentsController.commentsError.value != null) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                'Error: ${commentsController.commentsError.value}',
                style: TextStyle(color: textSecondary),
              ),
            ),
          );
        } else if (commentsController.isLoadingComments.value &&
            commentsController.comments.isEmpty) {
          return SliverToBoxAdapter(
            child: buildShimmerCommentList(count: 3),
          );
        } else if (commentsController.comments.isEmpty) {
          return SliverFillRemaining(
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
          );
        } else {
          return SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final comment = commentsController.comments[index];
              return _buildCommentItem(comment, controller.video.id);
            }, childCount: commentsController.comments.length),
          );
        }
      }),
    ];
  }

  Widget _buildCommentItem(Comment comment, String videoId) {
    return _CommentItemWidget(
      comment: comment,
      videoId: videoId,
      channelAvatarUrl: controller.video.channelAvatarUrl,
      mainController: Get.find<MainController>(),
      textSecondary: textSecondary,
    );
  }

  void _showCommentsBottomSheet(BuildContext context) {
    final tag = 'video_${controller.video.id}';
    final commentsController = Get.find<CommentsController>(tag: tag);
    final currentUser = FirebaseAuth.instance.currentUser;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF0F0F0F),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Obx(() {
                          final count = commentsController.comments.length;
                          return Text(
                            'Comments ($count)',
                            style: GoogleFonts.roboto(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          );
                        }),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white12),
                  Expanded(
                    child: Obx(() {
                      if (commentsController.isLoadingComments.value &&
                          commentsController.comments.isEmpty) {
                        return const Center(
                          child: CircularProgressIndicator(color: primary),
                        );
                      }
                      if (commentsController.commentsError.value != null) {
                        return Center(
                          child: Text(
                            'Error: ${commentsController.commentsError.value}',
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                        );
                      }
                      if (commentsController.comments.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat_bubble_outline, color: textSecondary, size: 48),
                              const SizedBox(height: 16),
                              const Text(
                                'No comments yet',
                                style: TextStyle(color: Colors.white, fontSize: 16),
                              ),
                            ],
                          ),
                        );
                      }
                      return ListView.builder(
                        controller: scrollController,
                        itemCount: commentsController.comments.length,
                        itemBuilder: (context, index) {
                          final comment = commentsController.comments[index];
                          return _buildCommentItem(comment, controller.video.id);
                        },
                      );
                    }),
                  ),
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom,
                    ),
                    child: currentUser != null
                        ? PremiumCommentInput(
                            key: ValueKey('popup_comment_input_${controller.video.id}'),
                            videoId: controller.video.id,
                            onSubmit: (text, postAsChannel, channelId) async {
                              try {
                                final authService = AuthService.to;
                                final hasChannel = authService.hasChannel.value;
                                final channel = authService.userChannel;

                                final bool shouldPostAsChannel = postAsChannel || hasChannel;
                                final String? targetChannelId = shouldPostAsChannel ? (channelId ?? channel?.id) : null;
                                final String? targetChannelName = shouldPostAsChannel ? (channel?.handle.isNotEmpty == true ? channel?.handle : channel?.name) : null;
                                final String? targetChannelAvatar = shouldPostAsChannel ? channel?.avatarUrl : null;
                                final String targetUserAvatar = AuthService.to.activePhotoUrl;

                                await commentsController.submitComment(
                                  text: text,
                                  channelId: targetChannelId,
                                  channelName: targetChannelName,
                                  channelProfilePicUrl: targetChannelAvatar,
                                  userProfilePicUrl: targetUserAvatar,
                                );
                              } catch (e) {
                                debugPrint('Failed to submit comment: $e');
                              }
                            },
                            onCancel: () {},
                          )
                        : Container(
                            padding: const EdgeInsets.all(16),
                            width: double.infinity,
                            color: Colors.black26,
                            child: Text(
                              'Sign in to comment',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.roboto(color: textSecondary),
                            ),
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
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
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    '${FormatUtils.formatCount(_mainController.videoLikes[controller.video.id] ?? controller.video.likeCount)} likes',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${FormatUtils.formatCount(_mainController.videoDislikes[controller.video.id] ?? controller.video.dislikeCount)} dislikes',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${_formatViews(controller.video.views)} views',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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


  void _showSignInPrompt() {
    Get.snackbar('Sign in required', 'Please sign in to proceed');
  }

  String _formatViews(int views) {
    if (views >= 1000000) return '${(views / 1000000).toStringAsFixed(1)}M';
    if (views >= 1000) return '${(views / 1000).toStringAsFixed(1)}K';
    return views.toString();
  }

}

class _AnimatedReactionButton extends StatefulWidget {
  final IconData icon;
  final bool isActive;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;
  final BorderRadius borderRadius;

  const _AnimatedReactionButton({
    required this.icon,
    required this.isActive,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
    required this.borderRadius,
  });

  @override
  State<_AnimatedReactionButton> createState() => _AnimatedReactionButtonState();
}

class _AnimatedReactionButtonState extends State<_AnimatedReactionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.4)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.4, end: 1.0)
            .chain(CurveTween(curve: Curves.bounceOut)),
        weight: 60.0,
      ),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(covariant _AnimatedReactionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive && widget.isActive) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      borderRadius: widget.borderRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Icon(
            widget.icon,
            size: 20,
            color: widget.isActive ? widget.activeColor : widget.inactiveColor,
          ),
        ),
      ),
    );
  }
}

// ==========================================================================
// COMMENT ITEM WIDGET WITH LIKE/DISLIKE/REPLY
// ==========================================================================

class _CommentItemWidget extends StatefulWidget {
  final Comment comment;
  final String videoId;
  final String channelAvatarUrl;
  final MainController mainController;
  final Color textSecondary;

  const _CommentItemWidget({
    required this.comment,
    required this.videoId,
    required this.channelAvatarUrl,
    required this.mainController,
    required this.textSecondary,
  });

  @override
  State<_CommentItemWidget> createState() => _CommentItemWidgetState();
}

class _CommentItemWidgetState extends State<_CommentItemWidget> {
  final RxBool isReplying = false.obs;
  final RxBool _isRepliesExpanded = false.obs;
  final RxString replyText = ''.obs;
  final TextEditingController replyController = TextEditingController();
  final FocusNode replyFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    replyController.addListener(() {
      replyText.value = replyController.text;
    });
  }

  @override
  void dispose() {
    replyController.dispose();
    replyFocusNode.dispose();
    super.dispose();
  }

  void _submitReply() async {
    final text = replyController.text.trim();
    if (text.isEmpty) return;

    final commentId = widget.comment.id;
    if (commentId.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Get.snackbar('Sign in required', 'Please sign in to reply');
      return;
    }

    try {
      final tag = 'video_${widget.videoId}';
      final commentsController = Get.find<CommentsController>(tag: tag);

      final authService = AuthService.to;
      final hasChannel = authService.hasChannel.value;
      final channel = authService.userChannel;

      final String? targetChannelId = hasChannel ? channel?.id : null;
      final String? targetChannelName = hasChannel ? (channel?.handle.isNotEmpty == true ? channel?.handle : channel?.name) : null;
      final String? targetChannelAvatar = AuthService.to.activePhotoUrl.isNotEmpty ? AuthService.to.activePhotoUrl : null;
      final String targetUserAvatar = AuthService.to.activePhotoUrl;

      await commentsController.submitReply(
        commentId: commentId,
        text: text,
        channelId: targetChannelId,
        channelName: targetChannelName,
        channelProfilePicUrl: targetChannelAvatar,
        userProfilePicUrl: targetUserAvatar,
        commentAuthorId: widget.comment.userId,
      );

      replyController.clear();
      isReplying.value = false;

      Get.snackbar('Success', 'Reply posted');
    } catch (e) {
      debugPrint('Error posting reply: $e');
      Get.snackbar('Error', 'Failed to post reply');
    }
  }

  void _showCommentOptions(BuildContext context, Comment comment, CommentsController commentsController) {
    final user = FirebaseAuth.instance.currentUser;
    final isOwner = user != null && user.uid == comment.userId;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey.shade900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isOwner)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Delete', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    commentsController.deleteComment(comment.id);
                  },
                )
              else
                ListTile(
                  leading: const Icon(Icons.flag_outlined, color: Colors.white),
                  title: const Text('Report', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    Get.snackbar('Reported', 'Thank you for your report.');
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _navigateToChannel(String? channelId) async {
    if (channelId == null || channelId.isEmpty) return;
    try {
      Get.dialog(
        const Center(
          child: CircularProgressIndicator(color: AppColors.brand),
        ),
        barrierDismissible: false,
      );
      final doc = await FirebaseFirestore.instance
          .collection('channels')
          .doc(channelId)
          .get();
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
      if (doc.exists) {
        final channel = Channel.fromDocumentSnapshot(doc);
        Get.offAndToNamed(channel.channelRoute, arguments: {'channel': channel});
      } else {
        Get.snackbar('Error', 'Channel not found');
      }
    } catch (e) {
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
      debugPrint('Error navigating to channel: $e');
    }
  }

  void _showReplyOptions(BuildContext context, Reply reply, String commentId, CommentsController commentsController) {
    final user = FirebaseAuth.instance.currentUser;
    final isOwner = user != null && user.uid == reply.userId;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey.shade900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isOwner)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Delete', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    commentsController.deleteReply(commentId, reply.id);
                  },
                )
              else
                ListTile(
                  leading: const Icon(Icons.flag_outlined, color: Colors.white),
                  title: const Text('Report', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    Get.snackbar('Reported', 'Thank you for your report.');
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final comment = widget.comment;
    final String userName = comment.displayName;
    final String formattedUserName = userName.startsWith('@') ? userName : '@$userName';
    final String text = comment.text;
    final Timestamp createdAt = comment.createdAt;
    final String userProfilePicUrl = comment.avatarUrl;
    final int likeCount = comment.likeCount;
    final String commentId = comment.id;

    final tag = 'video_${widget.videoId}';
    final commentsController = Get.find<CommentsController>(tag: tag);

    return Obx(() {
      final isLiked = commentsController.isCommentLikedByUser(comment);
      final isDisliked = commentsController.isCommentDislikedByUser(comment);

      final isTarget = commentsController.targetCommentId.value == comment.id && commentsController.targetReplyId.value == null;

      // Automatically trigger scroll exactly once if it's the target comment
      if (isTarget && !commentsController.hasScrolledToTarget) {
        commentsController.hasScrolledToTarget = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Scrollable.ensureVisible(
              context,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
            );
          }
        });
      }

      return Container(
        decoration: isTarget
            ? BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.08),
                border: const Border(
                  left: BorderSide(
                    color: AppColors.brand,
                    width: 3.0,
                  ),
                ),
              )
            : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => _navigateToChannel(comment.channelId),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: UserAvatar(
                      radius: 20,
                      photoUrl: userProfilePicUrl,
                      displayName: userName,
                      backgroundColor: Colors.blue,
                      textColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => _navigateToChannel(comment.channelId),
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: comment.channelId.isNotEmpty && comment.channelId == commentsController.video?.channelId
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            formattedUserName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(
                                            Icons.check,
                                            size: 12,
                                            color: Colors.white70,
                                          ),
                                        ],
                                      ),
                                    )
                                  : Text(
                                      formattedUserName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            timeago.format(createdAt.toDate()),
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        text,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.3,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          InkWell(
                            onTap: () => commentsController.toggleCommentLike(
                              commentId: commentId,
                              likeAsChannel: false,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                                  size: 16,
                                  color: isLiked ? Colors.white : Colors.grey.shade400,
                                ),
                                const SizedBox(width: 6),
                                if (likeCount > 0)
                                  Text(
                                    '$likeCount',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isLiked ? Colors.white : Colors.grey.shade400,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          InkWell(
                            onTap: () => commentsController.toggleCommentDislike(
                              commentId: commentId,
                              dislikeAsChannel: false,
                            ),
                            child: Icon(
                              isDisliked ? Icons.thumb_down : Icons.thumb_down_outlined,
                              size: 16,
                              color: isDisliked ? Colors.white : Colors.grey.shade400,
                            ),
                          ),
                          if (comment.isHeartedByCreator) ...[
                            const SizedBox(width: 8),
                            Tooltip(
                              message: 'Hearted by ${comment.creatorHeartName ?? 'Creator'}',
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      UserAvatar(
                                        radius: 8,
                                        photoUrl: widget.channelAvatarUrl,
                                        displayName: 'Creator',
                                        fontSize: 8,
                                      ),
                                      const Positioned(
                                        bottom: -3,
                                        right: -3,
                                        child: Icon(
                                          Icons.favorite,
                                          color: Colors.red,
                                          size: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          const SizedBox(width: 16),
                          InkWell(
                            onTap: () {
                              isReplying.value = !isReplying.value;
                              if (isReplying.value) {
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (mounted && replyFocusNode.canRequestFocus) {
                                    FocusScope.of(context).requestFocus(replyFocusNode);
                                  }
                                });
                              }
                            },
                            child: Text(
                              'Reply',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade400,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.more_vert, color: Colors.grey.shade400, size: 18),
                  onPressed: () => _showCommentOptions(context, comment, commentsController),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            if (isReplying.value)
              Padding(
                key: ValueKey('reply_box_$commentId'),
                padding: const EdgeInsets.only(left: 52, top: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: replyController,
                        focusNode: replyFocusNode,
                        decoration: InputDecoration(
                          hintText: 'Add a reply...',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 14,
                          ),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.grey.shade800,
                              width: 1.0,
                            ),
                          ),
                          focusedBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.white,
                              width: 1.5,
                            ),
                          ),
                          border: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.grey.shade800,
                              width: 1.0,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        style: const TextStyle(fontSize: 14, color: Colors.white),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _submitReply(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        isReplying.value = false;
                        replyController.clear();
                      },
                      icon: const Icon(
                        Icons.close,
                        size: 20,
                        color: Colors.white70,
                      ),
                    ),
                    IconButton(
                      onPressed: _submitReply,
                      icon: Obx(() => Icon(
                            Icons.send,
                            size: 20,
                            color: replyText.value.isNotEmpty ? Colors.blue : Colors.grey,
                          )),
                    ),
                  ],
                ),
              ),
            if (commentId.isNotEmpty) _buildRepliesList(commentId, comment),
          ],
        ),
      );
    });
  }

  Widget _buildRepliesList(String commentId, Comment parentComment) {
    final tag = 'video_${widget.videoId}';
    final commentsController = Get.find<CommentsController>(tag: tag);

    return StreamBuilder<List<Reply>>(
      stream: widget.mainController.getRepliesStream(widget.videoId, commentId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        final replies = snapshot.data ?? [];
        if (replies.isEmpty) {
          return const SizedBox.shrink();
        }

        // Auto-expand replies if this comment contains the target reply
        final targetReplyId = commentsController.targetReplyId.value;
        if (targetReplyId != null && targetReplyId.isNotEmpty) {
          final hasTargetReply = replies.any((r) => r.id == targetReplyId);
          if (hasTargetReply && !_isRepliesExpanded.value) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _isRepliesExpanded.value = true;
            });
          }
        }

        return Obx(() {
          final isExpanded = _isRepliesExpanded.value;

          if (!isExpanded) {
            final firstReply = replies.first;
            return InkWell(
              onTap: () => _isRepliesExpanded.value = true,
              child: Row(
                children: [
                  CustomPaint(
                    size: const Size(40, 36),
                    painter: ReplyThreadLinePainter(
                      color: Colors.white24,
                      isLast: true,
                      branchY: 18.0,
                    ),
                  ),
                  UserAvatar(
                    radius: 10,
                    photoUrl: firstReply.avatarUrl,
                    displayName: firstReply.displayName,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    replies.length == 1 ? '• 1 reply' : '• ${replies.length} replies',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.expand_more,
                    color: Colors.blue,
                    size: 16,
                  ),
                ],
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...List.generate(replies.length, (index) {
                final reply = replies[index];
                final isLastReply = index == replies.length - 1;
                final isReplyLiked = commentsController.isReplyLikedByUser(reply.id);
                final isReplyDisliked = commentsController.isReplyDislikedByUser(reply.id);

                final isReplyTarget = commentsController.targetReplyId.value == reply.id;

                // Automatically trigger scroll exactly once if it's the target reply
                if (isReplyTarget && !commentsController.hasScrolledToTarget) {
                  commentsController.hasScrolledToTarget = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      Scrollable.ensureVisible(
                        context,
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeInOut,
                      );
                    }
                  });
                }

                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomPaint(
                        size: const Size(40, double.infinity),
                        painter: ReplyThreadLinePainter(
                          color: Colors.white24,
                          isLast: isLastReply,
                          branchY: 20.0,
                        ),
                      ),
                      Expanded(
                        child: Container(
                          decoration: isReplyTarget
                              ? BoxDecoration(
                                  color: AppColors.brand.withValues(alpha: 0.08),
                                  border: const Border(
                                    left: BorderSide(
                                      color: AppColors.brand,
                                      width: 3.0,
                                    ),
                                  ),
                                )
                              : null,
                          padding: const EdgeInsets.only(top: 8, bottom: 8, right: 16, left: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: () => _navigateToChannel(reply.channelId),
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: UserAvatar(
                                    radius: 12,
                                    photoUrl: reply.avatarUrl,
                                    displayName: reply.displayName,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        GestureDetector(
                                          onTap: () => _navigateToChannel(reply.channelId),
                                          child: MouseRegion(
                                            cursor: SystemMouseCursors.click,
                                            child: reply.channelId.isNotEmpty && reply.channelId == commentsController.video?.channelId
                                                ? Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white.withValues(alpha: 0.15),
                                                      borderRadius: BorderRadius.circular(10),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          reply.displayName.startsWith('@') ? reply.displayName : '@${reply.displayName}',
                                                          style: const TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 11,
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                        const SizedBox(width: 3),
                                                        const Icon(
                                                          Icons.check,
                                                          size: 11,
                                                          color: Colors.white70,
                                                        ),
                                                      ],
                                                    ),
                                                  )
                                                : Text(
                                                    reply.displayName.startsWith('@') ? reply.displayName : '@${reply.displayName}',
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 12,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          timeago.format(reply.createdAt.toDate()),
                                          style: TextStyle(
                                            color: Colors.grey.shade500,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      reply.text,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        height: 1.3,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        InkWell(
                                          onTap: () => commentsController.toggleReplyLike(
                                            commentId: commentId,
                                            replyId: reply.id,
                                            likeAsChannel: false,
                                            replyAuthorId: reply.userId,
                                            replyText: reply.text,
                                          ),
                                          child: Icon(
                                            isReplyLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                                            size: 14,
                                            color: isReplyLiked ? Colors.white : Colors.grey.shade400,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        if (reply.likeCount > 0)
                                          Text(
                                            '${reply.likeCount}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isReplyLiked ? Colors.white : Colors.grey.shade400,
                                            ),
                                          ),
                                        const SizedBox(width: 16),
                                        InkWell(
                                          onTap: () => commentsController.toggleReplyDislike(
                                            commentId: commentId,
                                            replyId: reply.id,
                                            dislikeAsChannel: false,
                                          ),
                                          child: Icon(
                                            isReplyDisliked ? Icons.thumb_down : Icons.thumb_down_outlined,
                                            size: 14,
                                            color: isReplyDisliked ? Colors.white : Colors.grey.shade400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.more_vert, color: Colors.grey.shade400, size: 16),
                                onPressed: () => _showReplyOptions(context, reply, commentId, commentsController),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              InkWell(
                onTap: () => _isRepliesExpanded.value = false,
                child: Row(
                  children: [
                    CustomPaint(
                      size: const Size(40, 36),
                      painter: ReplyThreadLinePainter(
                        color: Colors.white24,
                        isLast: true,
                        branchY: 18.0,
                      ),
                    ),
                    const Text(
                      'Hide replies',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.expand_less,
                      color: Colors.blue,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ],
          );
        });
      },
    );
  }
}

class ReplyThreadLinePainter extends CustomPainter {
  final Color color;
  final bool isLast;
  final double branchY;

  ReplyThreadLinePainter({
    required this.color,
    required this.isLast,
    required this.branchY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path();
    if (isLast) {
      path.moveTo(20, 0);
      path.lineTo(20, branchY - 8);
      path.quadraticBezierTo(20, branchY, 28, branchY);
      path.lineTo(size.width, branchY);
    } else {
      path.moveTo(20, 0);
      path.lineTo(20, size.height);
      path.moveTo(20, branchY);
      path.lineTo(size.width, branchY);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant ReplyThreadLinePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.isLast != isLast ||
        oldDelegate.branchY != branchY;
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
        return isGrid
            ? buildShimmerVideoGrid(crossAxisCount: 2, count: 4)
            : buildShimmerVideoList(count: 4);
      }

      final displayVideos = videos ?? controller.filteredRecommendedVideos;
      final filters = controller.recommendationFilters;
      final selectedFilter = controller.selectedRecommendationFilter.value;

      final Widget pillsBar = Container(
        height: 50,
        margin: const EdgeInsets.only(bottom: 8),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: filters.length,
          itemBuilder: (context, index) {
            final filter = filters[index];
            final isSelected = filter == selectedFilter;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  controller.selectedRecommendationFilter.value = filter;
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: isSelected
                        ? null
                        : Border.all(color: Colors.white.withValues(alpha: 0.15), width: 0.5),
                  ),
                  child: Center(
                    child: Text(
                      filter,
                      style: TextStyle(
                        color: isSelected ? Colors.black : Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );

      final Widget videoList = isGrid
          ? LayoutBuilder(
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
                    disableHoverPreview: true,
                  ),
                );
              },
            )
          : ListView.builder(
              shrinkWrap: shrinkWrap,
              physics: physics,
              padding: const EdgeInsets.all(16),
              itemCount: displayVideos.length,
              itemBuilder: (context, index) => VideoCard(
                video: displayVideos[index],
                isGrid: false,
                heroPrefix: 'rec_list_${videoTag ?? 'global'}',
                disableHoverPreview: true,
              ),
            );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          pillsBar,
          if (displayVideos.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text(
                  "No recommendations found",
                  style: TextStyle(color: Colors.white24),
                ),
              ),
            )
          else
            shrinkWrap 
                ? videoList 
                : Expanded(child: videoList),
        ],
      );
    });
  }
}

class _ResponsiveAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VideoController controller;
  final PreferredSizeWidget Function() appBarBuilder;

  const _ResponsiveAppBar({
    required this.controller,
    required this.appBarBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return !controller.isFullScreen.value
          ? appBarBuilder()
          : const SizedBox.shrink();
    });
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
