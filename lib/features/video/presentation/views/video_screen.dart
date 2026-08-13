import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:truthworld/components/ui/community_post_card.dart';
import 'package:truthworld/components/ui/flip_coin_widget.dart';
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/components/ui/video_card.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/core/services/algorithm/flip_coin_service.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/core/widgets/ad_widgets.dart';
import 'package:truthworld/core/widgets/clickable_url_text.dart';
import 'package:truthworld/core/widgets/shimmer_skeletons.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/community/data/models/community_post_model.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/memberships_screen.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/home/presentation/controllers/main_controller.dart';
import 'package:truthworld/features/miniplayer/presentation/controllers/miniplayer_controller.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_controller.dart';
import 'package:truthworld/features/playlist/presentation/views/playlist/playlist_detail_screen.dart';
import 'package:truthworld/features/playlist/presentation/views/playlist/show_diaglog.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/presentation/widgets/topic_card_widget.dart';
import 'package:truthworld/features/video/data/models/comment.dart';
import 'package:truthworld/features/video/data/models/reply.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/services/video_media_service.dart';
import 'package:truthworld/features/video/presentation/controllers/clip_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/comments_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/views/comments/premium_comment_input.dart';
import 'package:truthworld/features/video/presentation/views/player/tower_custom_player.dart';
import 'package:truthworld/features/video/presentation/widgets/truth_index_badge.dart';
import 'package:truthworld/features/video/presentation/widgets/video_analysis_bottom_sheet.dart';
import 'package:truthworld/features/video/presentation/widgets/video_chapters_bottom_sheet.dart';
import 'package:truthworld/theme/app_theme.dart';

class VideoScreen extends GetView<VideoController> {
  const VideoScreen({super.key, this.videoTag});
  final String? videoTag;

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
    if (Get.arguments is Map<String, dynamic>) {
      ctrl.applyClipIfPresent(Get.arguments as Map<String, dynamic>?);
    }

    // Dismiss miniplayer once when screen first builds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Get.isRegistered<MiniplayerController>(tag: 'miniplayer')) {
        MiniplayerController.to.dismiss();
      }
    });

    return PopScope(
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
              ? ColoredBox(
                  color: Colors.black,
                  child: Center(
                    child: _buildVideoPlayer(),
                  ),
                )
              : SafeArea(
                  child: ResponsiveBuilder(
                    builder: (context, device) {
                      final isDesktop =
                          device.isDesktop ||
                          device.isLargeDesktop ||
                          device.isUltraWide;
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

  // Getters for other controllers with safe fallbacks
  ChannelController? get _channelController {
    try {
      if (tag != null && Get.isRegistered<ChannelController>(tag: tag)) {
        return Get.find<ChannelController>(tag: tag);
      }
      if (Get.isRegistered<ChannelController>()) {
        return Get.find<ChannelController>();
      }
    } catch (_) {}
    return null;
  }

  MainController get _mainController {
    if (Get.isRegistered<MainController>()) {
      return Get.find<MainController>();
    }
    return Get.put(MainController());
  }

  PlaylistController? get _playlistController {
    try {
      if (Get.isRegistered<PlaylistController>()) {
        return Get.find<PlaylistController>();
      }
    } catch (_) {}
    return null;
  }

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
    final isDesktop =
        context.isDesktop || context.isLargeDesktop || context.isUltraWide;
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
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.bgSurface.withValues(alpha: 0.7),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_back, size: 18, color: textPrimary),
        ),
        onPressed: Get.back,
        tooltip: 'Back',
      ),
    );
  }

  // Exact replica of home screen header
  Widget _buildHomeStyleHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          // Logo
          InkWell(
            onTap: () => Get.offAllNamed('/'),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.play_circle_fill_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Truthworld',
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
          const SizedBox(width: 40),
          // Search bar exactly like home screen
          Expanded(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 650),
                height: 44,
                child: Material(
                  borderRadius: BorderRadius.circular(22),
                  color: Colors.white.withValues(alpha: 0.05),
                  child: InkWell(
                    onTap: () => Get.offAndToNamed('/search'),
                    borderRadius: BorderRadius.circular(22),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search_rounded,
                            color: Colors.grey.shade400,
                            size: 22,
                          ),
                          const SizedBox(width: 16),
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
        icon: const Icon(Icons.notifications_outlined, color: Colors.white),
        onPressed: () {
          // Navigate to notifications
        },
      ),
      Obx(() {
        final isAuthenticated = AuthService.to.isAuthenticated.value;
        if (!isAuthenticated) {
          // Sign In button
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              icon: const Icon(
                Icons.account_circle_outlined,
                size: 18,
                color: Color(0xFF3B82F6),
              ),
              label: const Text(
                'Sign In',
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
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.6),
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
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
            padding: const EdgeInsets.only(right: 16, left: 8),
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
                  border: Border.all(color: Colors.grey.shade600),
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
        controller.video;
        controller.isFullScreen.value;
        controller.showThumbnail.value;
        final ratio = controller.video.isShort
            ? 9 / 16
            : controller.vpcAspectRatio;

        return LayoutBuilder(
          builder: (context, constraints) {
            final mediaQuery = MediaQuery.of(context);
            final screenHeight = mediaQuery.size.height;
            final maxWidth = constraints.maxWidth;

            // Calculate height for this aspect ratio
            final height = maxWidth / ratio;

            // Define max height constraints
            // On desktop, cap to 65% of screen height.
            // On mobile, cap to 55% of screen height to keep controls and comments visible.
            final isDesktop = mediaQuery.size.width > 1050;
            final maxHeight = isDesktop
                ? screenHeight * 0.65
                : screenHeight * 0.55;

            var finalHeight = height;
            var finalRatio = ratio;

            if (height > maxHeight) {
              finalHeight = maxHeight;
              finalRatio = maxWidth / finalHeight;
            }

            final finalWidth = finalHeight * finalRatio;

            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // YouTube Ambient Mode Glow (glow matches video thumbnail and is 30% wider)
                if (!controller.isFullScreen.value &&
                    controller.video.thumbnailUrl.isNotEmpty)
                  Positioned(
                    width: finalWidth * 1.3,
                    height: finalHeight,
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 1000),
                        opacity: controller.showThumbnail.value ? 0.08 : 0.18,
                        child: Container(
                          decoration: const BoxDecoration(),
                          child: ClipRect(
                            child: ImageFiltered(
                              imageFilter: ui.ImageFilter.blur(
                                sigmaX: 65,
                                sigmaY: 65,
                                tileMode: TileMode.decal,
                              ),
                              child: CachedNetworkImage(
                                imageUrl: controller.video.thumbnailUrl
                                    .replaceAll(' ', '%20'),
                                fit: BoxFit.cover,
                                errorWidget: (_, _, _) =>
                                    const SizedBox.shrink(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Video Player Container
                AspectRatio(
                  aspectRatio: finalRatio.isFinite && finalRatio > 0
                      ? finalRatio
                      : 16 / 9,
                  child: ColoredBox(
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
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildVideoTitle(),
            Obx(() {
              final banners = <Widget>[];
              if (ctrl.navigatedFromPlaylist.value &&
                  ctrl.currentPlaylist.value != null) {
                banners.add(
                  _buildPlaylistBanner(context, ctrl.currentPlaylist.value!),
                );
              }
              if (ctrl.navigatedFromTopic.value &&
                  ctrl.videoTopicsList.isNotEmpty) {
                banners.add(
                  _buildTopicBanner(context, ctrl.videoTopicsList.first),
                );
              }
              if (banners.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: banners,
              );
            }),
            const SizedBox(height: 12),
            if (ctrl.video.isFactChecked) const SizedBox.shrink(),
            _buildModernActionButtons(context),
            const SizedBox(height: 16),
            _buildDescriptionBox(context),
            if (!isDesktop &&
                ctrl.navigatedFromPlaylist.value &&
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

  Widget _buildPlaylistBanner(BuildContext context, PlaylistModel playlist) {
    return Obx(() {
      final isPlaying = controller.isPlayingRx.value;
      final currentIndex = controller.calculatedPlaylistIndex;
      final totalVideos = controller.playlistVideos.isNotEmpty
          ? controller.playlistVideos.length
          : (playlist.videoIds.isNotEmpty
                ? playlist.videoIds.length
                : (playlist.videoCount > 0 ? playlist.videoCount : 1));

      return Container(
        margin: const EdgeInsets.only(top: 12, bottom: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.brand.withValues(alpha: 0.25),
              AppColors.bgSurface,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.brand.withValues(alpha: 0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _navigateToPlaylistDetail(playlist),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Rotating Playlist Avatar
                  RotatingPlaylistAvatar(
                    playlist: playlist,
                    isPlaying: isPlaying,
                  ),
                  const SizedBox(width: 14),
                  // Playlist info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.brand,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'PLAYLIST',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                playlist.playlistName,
                                style: GoogleFonts.roboto(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            PlayingAudioWaveAnimation(
                              isPlaying: isPlaying,
                              height: 12,
                              barWidth: 2,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Playing video ${currentIndex + 1} of $totalVideos',
                              style: GoogleFonts.roboto(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Tap indicator arrow
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  void _navigateToPlaylistDetail(PlaylistModel playlist) {
    Get.to(() => PlaylistDetailScreen(playlist: playlist));
  }

  Widget _buildTopicBanner(BuildContext context, Topic topic) {
    return Obx(() {
      final isPlaying = controller.isPlayingRx.value;

      return Container(
        margin: const EdgeInsets.only(top: 12, bottom: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF3B82F6).withValues(alpha: 0.25),
              AppColors.bgSurface,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showTopicBottomSheet(context, topic),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Rotating Topic Avatar
                  RotatingTopicAvatar(
                    topic: topic,
                    isPlaying: isPlaying,
                  ),
                  const SizedBox(width: 14),
                  // Topic info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'TOPIC',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                topic.title,
                                style: GoogleFonts.roboto(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            PlayingAudioWaveAnimation(
                              isPlaying: isPlaying,
                              height: 12,
                              barWidth: 2,
                              color: const Color(0xFF3B82F6),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${topic.videoCount > 0 ? '${topic.videoCount} videos' : 'Topic Hub'} • Tap to view topic videos',
                              style: GoogleFonts.roboto(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Tap indicator arrow
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  void _showTopicBottomSheet(BuildContext context, Topic topic) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TopicVideosBottomSheet(topic: topic, videoTag: tag),
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
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with Rotating Playlist Avatar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Obx(
                  () => RotatingPlaylistAvatar(
                    playlist: controller.currentPlaylist.value!,
                    isPlaying: controller.isPlayingRx.value,
                    size: 46,
                    onTap: () => _navigateToPlaylistDetail(
                      controller.currentPlaylist.value!,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _navigateToPlaylistDetail(
                      controller.currentPlaylist.value!,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          controller.currentPlaylist.value!.playlistName,
                          style: GoogleFonts.roboto(
                            color: Colors.white,
                            fontSize: 16,
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
                        // Playing Audio Wave Animation or Index
                        SizedBox(
                          width: 24,
                          child: Center(
                            child: isActive
                                ? Obx(
                                    () => PlayingAudioWaveAnimation(
                                      isPlaying: controller.isPlayingRx.value,
                                      height: 16,
                                    ),
                                  )
                                : Text(
                                    '${index + 1}',
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
        Get.arguments?['heroTag'] ?? 'video_${controller.video.id}';
    final thumbnailWidget = ColoredBox(
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
        controller.isLoading;
        controller.videoError.value;
        controller.isSwitchingResolution.value;
        controller.isAutoSwitching.value;
        controller.isAudioOnly.value;
        controller.showThumbnail.value;
        if (controller.isLoading && !controller.isSwitchingResolution.value) {
          return thumbnailWidget;
        }

        if (controller.videoError.value) {
          return Stack(
            children: [
              thumbnailWidget,
              ColoredBox(
                color: Colors.black54,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
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
                            controller.errorMessage.isNotEmpty
                                ? controller.errorMessage
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
        final isVideoReady = controller.isVpcInitialized;
        final isPlaying = controller.isVpcPlaying;
        final isAudioOnly = controller.isAudioOnly.value;
        final showThumbnailOverlay =
            !isAutoSwitching &&
            (!isVideoReady ||
                (!isPlaying && controller.showThumbnail.value) ||
                isAudioOnly);

        final vpc = controller.videoPlayerController;
        if (controller.chewieController == null ||
            vpc == null ||
            !isVideoReady) {
          return thumbnailWidget;
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            // Only show thumbnail if video not ready yet
            if (showThumbnailOverlay) thumbnailWidget,
            // Video player
            TowerCustomPlayer(
              videoPlayerController: vpc,
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: primary.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.content_cut_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'CLIP: ${controller.activeClip.value!.title}',
                            style: GoogleFonts.roboto(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: primary.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.verified_rounded,
                                  color: Colors.white,
                                  size: 10,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'TRUTHWORLD WATERMARK',
                                  style: GoogleFonts.roboto(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () => controller.clearActiveClip(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: primary,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
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
            // Persistent Watermark on Clip Playback
            if (controller.activeClip.value != null)
              Positioned(
                bottom: 60,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.water_drop_rounded,
                        color: Colors.white,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Truthworld Watermark',
                        style: GoogleFonts.roboto(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }

  Widget _buildVideoTitle() {
    return ClickableUrlText(
      text: controller.video.title,
      style: const TextStyle(
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

    final selectedReason = RxnString();
    final currentStep =
        1.obs; // Step 1: select reason, Step 2: comment & timestamp
    final commentController = TextEditingController();

    // Get current playback time to suggest as timestamp
    final currentSeconds =
        controller.videoPlayerController?.value.position.inSeconds ?? 0;
    final minutes = currentSeconds ~/ 60;
    final seconds = currentSeconds % 60;
    final defaultTimestamp =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    final includeTimestamp = false.obs;
    final isSubmitting = false.obs;

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
                      icon: const Icon(
                        Icons.arrow_back,
                        color: AppColors.textPrimary,
                      ),
                      onPressed: () {
                        currentStep.value = 1;
                      },
                    ),
                  const Icon(Icons.flag_rounded, color: Colors.white, size: 28),
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
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        label,
                                        style: GoogleFonts.roboto(
                                          fontSize: 14,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
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
                      onPressed: Get.back,
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
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
                    style: GoogleFonts.roboto(
                      color: textSecondary,
                      fontSize: 11,
                    ),
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
                  style: const TextStyle(color: textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText:
                        'Provide additional details (e.g. description, background info)...',
                    hintStyle: const TextStyle(
                      color: textSecondary,
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: AppColors.bgInput,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    counterStyle: const TextStyle(
                      color: textSecondary,
                      fontSize: 11,
                    ),
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
                      onPressed: isSubmitting.value
                          ? null
                          : () {
                              isSubmitting.value = true;
                              Get.back();

                              // Build detailed comment including timestamp
                              final timestampPrefix = includeTimestamp.value
                                  ? '[Timestamp: $defaultTimestamp] '
                                  : '';
                              final finalComment =
                                  '$timestampPrefix${commentController.text.trim()}';

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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
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
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        decoration: const BoxDecoration(
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
                const Icon(
                  Icons.content_cut_rounded,
                  color: Colors.white,
                  size: 28,
                ),
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
                contentPadding: const EdgeInsets.symmetric(
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

            // --- Actions (Save & Share) ---
            Obx(
              () => Row(
                children: [
                  // --- Save Clip ---
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: clipController.isSaving.value
                            ? null
                            : clipController.saveClip,
                        icon: clipController.isSaving.value
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.bookmark_add_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                        label: Text(
                          'Save Clip',
                          style: GoogleFonts.roboto(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brand,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                          shadowColor: AppColors.brand.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // --- Share Clip ---
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            clipController.shareClipWithWatermark(context),
                        icon: const Icon(
                          Icons.share_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        label: Text(
                          'Share Clip',
                          style: GoogleFonts.roboto(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.bgSurface.withValues(
                            alpha: 0.8,
                          ),
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: AppColors.brand.withValues(alpha: 0.8),
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: Get.back,
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
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
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
            style: const TextStyle(color: primary, fontWeight: FontWeight.w500),
          ),
          const Icon(Icons.chevron_right_rounded),
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
                  const Icon(Icons.download_for_offline, color: Colors.white),
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
                padding: const EdgeInsets.all(20),
                child: Text(
                  'No download options available for this video.',
                  style: GoogleFonts.roboto(color: textSecondary),
                ),
              )
            else
              ...controller.availableResolutions.map(
                (res) => ListTile(
                  leading: const Icon(Icons.high_quality, color: textSecondary),
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
    final isUserSignedIn = FirebaseAuth.instance.currentUser != null;
    final mediaQuery = MediaQuery.of(context);
    final isDesktop = mediaQuery.size.width > 1050;

    if (!isDesktop) {
      // Mobile Layout: Two separate rows for maximum readability and proper spacing
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ⚔️ COIN BATTLE LINKED VIDEO BANNER
          if (controller.video.coinBattlePairVideoId != null &&
              controller.video.coinBattlePairVideoId!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4A148C), Color(0xFF880E4F)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.swap_horiz_rounded, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '⚔️ COIN BATTLE LINKED DEBATE',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            'Stance: ${controller.video.coinBattleStance ?? "Opposing Viewpoint"}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Get.toNamed(
                          '/video/${controller.video.coinBattlePairVideoId}',
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                      ),
                      child: const Text('View Debate'),
                    ),
                  ],
                ),
              ),
            ),

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

                // 🪙 FLIP COIN (THE OTHER SIDE / OPPOSITE PERSPECTIVE) BUTTON
                Builder(
                  builder: (context) {
                    final flipService = Get.find<FlipCoinService>();
                    return Obx(() {
                      final isFlipped = flipService.isVideoFlipped(
                        controller.video.id,
                      );
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FlipCoinWidget(
                          isFlipped: isFlipped,
                          showLabel: true,
                          onTap: () {
                            flipService.toggleVideoFlip(controller.video.id);
                            controller.reloadRecommendationsForFlip();
                          },
                        ),
                      );
                    });
                  },
                ),

                // Insights & Media details button (icon only, before comments)
                _buildModernCapsuleButton(
                  icon: Icons.verified_user_outlined,
                  label: '',
                  onTap: () => _showAnalysisBottomSheet(context),
                ),
                const SizedBox(width: 8),

                // Comment (icon only)
                if (_isMobilePlatform(context)) ...[
                  _buildModernCapsuleButton(
                    icon: Icons.comment_rounded,
                    label: '',
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
                      currentPosition:
                          controller.videoPlayerController?.value.position,
                    );
                  },
                ),
                const SizedBox(width: 8),

                // Rating / Watch Later
                Obx(() {
                  controller.rxVideo.value;
                  _playlistController?.playlists.length;
                  final isInWatchLater =
                      _playlistController?.isInWatchLater(
                        controller.video.id,
                      ) ??
                      false;
                  return _buildModernCapsuleButton(
                    icon: isInWatchLater
                        ? Icons.watch_later
                        : Icons.watch_later_outlined,
                    label: 'Watch Later',
                    onTap: () {
                      if (!isUserSignedIn) return _showSignInPrompt();
                      showModernizedPlaylistDialog(
                        context: context,
                        videoId: controller.video.id,
                      );
                    },
                  );
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

                // Membership / Join
                _buildModernCapsuleButton(
                  icon: Icons.workspace_premium_outlined,
                  label: 'Membership',
                  onTap: () =>
                      _showChannelMembershipModal(context, isUserSignedIn),
                ),
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

                // Insights & Media details button (icon only, before comments)
                _buildModernCapsuleButton(
                  icon: Icons.verified_user_outlined,
                  label: '',
                  onTap: () => _showAnalysisBottomSheet(context),
                ),
                const SizedBox(width: 8),

                // Comment (icon only)
                if (_isMobilePlatform(context)) ...[
                  _buildModernCapsuleButton(
                    icon: Icons.comment_rounded,
                    label: '',
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
                      currentPosition:
                          controller.videoPlayerController?.value.position,
                    );
                  },
                ),
                const SizedBox(width: 8),

                // Rating / Watch Later
                Obx(() {
                  controller.rxVideo.value;
                  _playlistController?.playlists.length;
                  final isInWatchLater =
                      _playlistController?.isInWatchLater(
                        controller.video.id,
                      ) ??
                      false;
                  return _buildModernCapsuleButton(
                    icon: isInWatchLater
                        ? Icons.watch_later
                        : Icons.watch_later_outlined,
                    label: 'Watch Later',
                    onTap: () {
                      if (!isUserSignedIn) return _showSignInPrompt();
                      showModernizedPlaylistDialog(
                        context: context,
                        videoId: controller.video.id,
                      );
                    },
                  );
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

                // Membership / Join
                _buildModernCapsuleButton(
                  icon: Icons.workspace_premium_outlined,
                  label: 'Membership',
                  onTap: () =>
                      _showChannelMembershipModal(context, isUserSignedIn),
                ),
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
    final isUserSignedIn = FirebaseAuth.instance.currentUser != null;

    if (controller.video.channelId.isEmpty) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(FirestoreCollections.channels)
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
                final isSubbed =
                    _channelController?.isSubscribed.value ?? false;
                final notificationsEnabled =
                    _channelController?.notificationsEnabled.value ?? true;
                final notificationOption =
                    _channelController?.notificationOption.value ?? 'all';

                IconData bellIcon;
                if (!notificationsEnabled || notificationOption == 'none') {
                  bellIcon = Icons.notifications_off_outlined;
                } else if (notificationOption == 'personalized') {
                  bellIcon = Icons.notifications_outlined;
                } else {
                  bellIcon = Icons.notifications_active_outlined;
                }

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () {
                        if (!isUserSignedIn) return _showSignInPrompt();
                        _channelController?.toggleSubscription(
                          controller.video.channelId,
                        );
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
                        onTap: () => _showVideoPageNotificationsDialog(
                          context,
                          controller.video.channelId,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            bellIcon,
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
    final isUserSignedIn = FirebaseAuth.instance.currentUser != null;

    if (controller.video.channelId.isEmpty) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(FirestoreCollections.channels)
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
                final isSubscribed =
                    _channelController?.isSubscribed.value ?? false;
                final notificationsEnabled =
                    _channelController?.notificationsEnabled.value ?? true;
                final notificationOption =
                    _channelController?.notificationOption.value ?? 'all';

                IconData bellIcon;
                if (!notificationsEnabled || notificationOption == 'none') {
                  bellIcon = Icons.notifications_off;
                } else if (notificationOption == 'personalized') {
                  bellIcon = Icons.notifications_outlined;
                } else {
                  bellIcon = Icons.notifications_active;
                }

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        if (!isUserSignedIn) return _showSignInPrompt();
                        _channelController?.toggleSubscription(
                          controller.video.channelId,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSubscribed
                            ? Colors.grey.shade800
                            : Colors.white,
                        foregroundColor: isSubscribed
                            ? Colors.white
                            : Colors.black,
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
                        onPressed: () => _showVideoPageNotificationsDialog(
                          context,
                          controller.video.channelId,
                        ),
                        icon: Icon(
                          bellIcon,
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

  void _showVideoPageNotificationsDialog(
    BuildContext context,
    String channelId,
  ) {
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
              final option =
                  _channelController?.notificationOption.value ?? 'all';
              final notificationsEnabled =
                  _channelController?.notificationsEnabled.value ?? true;
              final isAll = notificationsEnabled && option == 'all';
              final isPersonalized =
                  notificationsEnabled && option == 'personalized';
              final isNone = !notificationsEnabled || option == 'none';

              return Column(
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.notifications_active,
                      color: isAll ? primary : textPrimary,
                    ),
                    title: Text(
                      'All',
                      style: GoogleFonts.roboto(
                        color: isAll ? primary : textPrimary,
                        fontWeight: isAll ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      "You'll get all notifications",
                      style: GoogleFonts.roboto(
                        fontSize: 12,
                        color: textSecondary,
                      ),
                    ),
                    trailing: isAll
                        ? const Icon(Icons.check, color: AppColors.textPrimary)
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      _channelController?.updateNotificationPreference(
                        channelId,
                        'all',
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.notifications_outlined,
                      color: isPersonalized ? primary : textPrimary,
                    ),
                    title: Text(
                      'Personalized',
                      style: GoogleFonts.roboto(
                        color: isPersonalized ? primary : textPrimary,
                        fontWeight: isPersonalized
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      "You'll get personalized notifications",
                      style: GoogleFonts.roboto(
                        fontSize: 12,
                        color: textSecondary,
                      ),
                    ),
                    trailing: isPersonalized
                        ? const Icon(Icons.check, color: AppColors.textPrimary)
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      _channelController?.updateNotificationPreference(
                        channelId,
                        'personalized',
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.notifications_off_outlined,
                      color: isNone ? primary : textPrimary,
                    ),
                    title: Text(
                      'None',
                      style: GoogleFonts.roboto(
                        color: isNone ? primary : textPrimary,
                        fontWeight: isNone
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      'Turn off all notifications',
                      style: GoogleFonts.roboto(
                        fontSize: 12,
                        color: textSecondary,
                      ),
                    ),
                    trailing: isNone
                        ? const Icon(Icons.check, color: AppColors.textPrimary)
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      _channelController?.updateNotificationPreference(
                        channelId,
                        'none',
                      );
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

  void _showChannelMembershipModal(BuildContext context, bool isUserSignedIn) {
    if (!isUserSignedIn) {
      _showSignInPrompt();
      return;
    }

    final channelId = controller.video.channelId;
    final channelName = controller.video.channelName.isNotEmpty
        ? controller.video.channelName
        : 'Channel';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.bgDivider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.workspace_premium_outlined,
                          color: AppColors.textPrimary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Join $channelName Membership',
                              style: AppTextStyles.titleLarge.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Unlock exclusive badges, perks & support the creator',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: AppColors.textPrimary,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: AppColors.bgDivider),
                  const SizedBox(height: 16),

                  // Tiers Stream
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection(FirestoreCollections.channels)
                          .doc(channelId)
                          .collection('membership_tiers')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.brand,
                            ),
                          );
                        }

                        var tiers = <ChannelMembershipTier>[];
                        if (snapshot.hasData &&
                            snapshot.data!.docs.isNotEmpty) {
                          tiers = snapshot.data!.docs
                              .map(
                                (doc) => ChannelMembershipTier.fromMap(
                                  doc.data()! as Map<String, dynamic>,
                                  doc.id,
                                ),
                              )
                              .where((t) => t.isEnabled)
                              .toList();
                        }

                        // Default fallback tiers if creator hasn't set custom ones
                        if (tiers.isEmpty) {
                          tiers = [
                            ChannelMembershipTier(
                              id: 'default_bronze',
                              name: 'Bronze Supporter',
                              price: 2.0,
                              perks: [
                                'Exclusive channel loyalty badge next to your name',
                                'Custom channel emojis in live chat & comments',
                                'Early access to newly uploaded videos',
                              ],
                            ),
                            ChannelMembershipTier(
                              id: 'default_silver',
                              name: 'Silver Supporter',
                              price: 5.0,
                              perks: [
                                'All Bronze perks included',
                                'Priority reply to your comments from creator',
                                'Access to members-only community polls & posts',
                                'Downloadable exclusive wallpaper & assets',
                              ],
                            ),
                            ChannelMembershipTier(
                              id: 'default_gold',
                              name: 'Gold VIP',
                              price: 10.0,
                              perks: [
                                'All Silver & Bronze perks included',
                                'Exclusive behind-the-scenes video updates',
                                'Direct Q&A live chat with creator',
                                'Special credit shoutout in future video descriptions',
                              ],
                            ),
                          ];
                        }

                        return ListView.separated(
                          controller: scrollController,
                          itemCount: tiers.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            final tier = tiers[index];
                            return _buildMembershipTierCard(
                              context,
                              tier,
                              channelId,
                              channelName,
                            );
                          },
                        );
                      },
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

  Widget _buildMembershipTierCard(
    BuildContext context,
    ChannelMembershipTier tier,
    String channelId,
    String channelName,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgInput,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgDivider),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.stars_rounded,
                    color: AppColors.textPrimary,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    tier.name,
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.brand.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  '\$${tier.price.toStringAsFixed(2)} / mo',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.brand,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.bgDivider),
          const SizedBox(height: 12),
          Text(
            'PERKS & BENEFITS:',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          ...tier.perks.map(
            (perk) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.check_circle_outline,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      perk,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () =>
                  _joinMembershipTier(context, tier, channelId, channelName),
              child: Text(
                'Join ${tier.name}',
                style: AppTextStyles.buttonText.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _joinMembershipTier(
    BuildContext context,
    ChannelMembershipTier tier,
    String channelId,
    String channelName,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    Navigator.pop(context);
    try {
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(uid)
          .collection('channelMemberships')
          .doc(channelId)
          .set({
            'channelId': channelId,
            'channelName': channelName,
            'tierId': tier.id,
            'tierName': tier.name,
            'price': tier.price,
            'perks': tier.perks,
            'joinedAt': FieldValue.serverTimestamp(),
            'status': 'active',
          });

      Get.snackbar(
        'Welcome to ${tier.name}!',
        'You are now a member of $channelName. Enjoy your exclusive perks!',
        backgroundColor: AppColors.bgSurface,
        colorText: AppColors.textPrimary,
        duration: const Duration(seconds: 4),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to join membership: $e',
        backgroundColor: AppColors.bgSurface,
        colorText: AppColors.error,
      );
    }
  }

  Widget _buildModernLikeDislikeGroup() {
    final isUserSignedIn = FirebaseAuth.instance.currentUser != null;

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
            final isLiked = controller.isLiked.value;
            final showLikeCount = controller.video.showLikeCount;
            final countStr = showLikeCount && controller.likeCount > 0
                ? FormatUtils.formatCount(controller.likeCount)
                : '';
            return _AnimatedReactionButton(
              icon: isLiked ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
              label: countStr,
              isActive: isLiked,
              activeColor: textPrimary,
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
            final isDisliked = controller.isDisliked.value;
            final showDislikeCount = controller.video.showDislikeCount;
            final countStr = showDislikeCount && controller.dislikeCount > 0
                ? FormatUtils.formatCount(controller.dislikeCount)
                : '';
            return _AnimatedReactionButton(
              icon: isDisliked
                  ? Icons.thumb_down_rounded
                  : Icons.thumb_down_outlined,
              label: countStr,
              isActive: isDisliked,
              activeColor: textPrimary,
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
    final hasLabel = label.isNotEmpty;
    return Material(
      color: AppColors.bgSurface,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: hasLabel ? 16 : 12,
            vertical: 8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: textPrimary),
              if (hasLabel) ...[
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
            ],
          ),
        ),
      ),
    );
  }

  void _showAnalysisBottomSheet(
    BuildContext context, {
    int initialTabIndex = 0,
  }) {
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
            case 'report':
              _showReportBottomSheet(context);
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

      final playerCtrl = Get.isRegistered<TowerPlayerController>(tag: tag)
          ? Get.find<TowerPlayerController>(tag: tag)
          : (Get.isRegistered<TowerPlayerController>()
                ? Get.find<TowerPlayerController>()
                : null);

      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border.withValues(alpha: 0.5)),
        ),
        child: ExpansionTile(
          iconColor: Colors.white,
          collapsedIconColor: Colors.white,
          title: InkWell(
            onTap: () => VideoChaptersBottomSheet.show(
              Get.context!,
              video: controller.video,
              videoTag: tag,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.bookmarks_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'Chapters',
                  style: GoogleFonts.roboto(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF162A45),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    chapters.length.toString(),
                    style: const TextStyle(
                      color: Color(0xFF3EA6FF),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          subtitle: Obx(() {
            final _ = controller.video.id;
            final current = playerCtrl?.currentChapter.value;
            if (current == null) return const SizedBox.shrink();
            return Text(
              'Current: ${current.title}',
              style: const TextStyle(color: textSecondary, fontSize: 13),
            );
          }),
          shape: const RoundedRectangleBorder(),
          collapsedShape: const RoundedRectangleBorder(),
          childrenPadding: EdgeInsets.zero,
          children: [
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: chapters.length,
              padding: const EdgeInsets.only(bottom: 8),
              itemBuilder: (context, index) {
                final chapter = chapters[index];
                return ChapterTile(
                  chapter: chapter,
                  video: controller.video,
                  playerCtrl: playerCtrl,
                );
              },
            ),
          ],
        ),
      );
    });
  }

  Widget _buildRecommendationHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Recommended',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          Row(
            children: [
              const Text(
                'Autoplay',
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
    final commentsController = Get.isRegistered<CommentsController>(tag: tag)
        ? Get.find<CommentsController>(tag: tag)
        : Get.put(CommentsController(video: controller.video), tag: tag);
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
                    onSelected: commentsController.sortComments,
                    offset: const Offset(0, 30),
                    itemBuilder: (context) =>
                        <PopupMenuEntry<bool>>[
                          PopupMenuItem<bool>(
                            value: false,
                            child: Obx(() {
                              final isSelected =
                                  !commentsController.isSortNewest.value;
                              return Row(
                                children: [
                                  Icon(
                                    Icons.check,
                                    size: 18,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.transparent,
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
                              final isSelected =
                                  commentsController.isSortNewest.value;
                              return Row(
                                children: [
                                  Icon(
                                    Icons.check,
                                    size: 18,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.transparent,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('Newest first'),
                                ],
                              );
                            }),
                          ),
                        ],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 8,
                      ),
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
              if (currentUser != null)
                PremiumCommentInput(
                  key: ValueKey('main_comment_input_${controller.video.id}'),
                  videoId: controller.video.id,
                  onSubmit: (text, postAsChannel, channelId) async {
                    try {
                      final authService = AuthService.to;
                      final hasChannel = authService.hasChannel.value;
                      final channel = authService.userChannel;

                      final shouldPostAsChannel = postAsChannel || hasChannel;
                      final targetChannelId = shouldPostAsChannel
                          ? (channelId ?? channel?.id)
                          : null;
                      final targetChannelName = shouldPostAsChannel
                          ? (channel?.handle.isNotEmpty ?? false
                                ? channel?.handle
                                : channel?.name)
                          : null;
                      final targetChannelAvatar = shouldPostAsChannel
                          ? channel?.avatarUrl
                          : null;
                      final targetUserAvatar = AuthService.to.activePhotoUrl;

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
              else
                Container(
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
      SliverToBoxAdapter(
        child: Obx(() {
          if (!Get.isRegistered<AdService>() || !AdService.to.showAds.value) {
            return const SizedBox.shrink();
          }
          final sponsorAd = AdService.to.getSponsorAdForVideo(controller.video.id);
          if (sponsorAd == null) return const SizedBox.shrink();
          return PinnedSponsorCommentCard(ad: sponsorAd, videoId: controller.video.id);
        }),
      ),

      Obx(() {
        if (commentsController.commentsError.value != null) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                'Error: ${commentsController.commentsError.value}',
                style: const TextStyle(color: textSecondary),
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
                  const Icon(
                    Icons.chat_bubble_outline,
                    color: textSecondary,
                    size: 48,
                  ),
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
    final commentsController = Get.isRegistered<CommentsController>(tag: tag)
        ? Get.find<CommentsController>(tag: tag)
        : Get.put(CommentsController(video: controller.video), tag: tag);
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Obx(() {
                          final count = commentsController.comments.length;
                          final isFlipped =
                              commentsController.isCounterArgumentFlipped.value;
                          return Row(
                            children: [
                              Text(
                                isFlipped
                                    ? 'Counter-Arguments ($count)'
                                    : 'Comments ($count)',
                                style: GoogleFonts.roboto(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              FlipCoinWidget(
                                isFlipped: isFlipped,
                                size: 28,
                                tooltip:
                                    'Flip to see Verified Counter-Arguments',
                                onTap: commentsController.toggleCounterArgumentSort,
                              ),
                            ],
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
                          child: CircularProgressIndicator(color: AppColors.brand),
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
                      final sponsorAd = Get.isRegistered<AdService>() && AdService.to.showAds.value
                          ? AdService.to.getSponsorAdForVideo(controller.video.id)
                          : null;
                      if (commentsController.comments.isEmpty) {
                        return ListView(
                          controller: scrollController,
                          children: [
                            if (sponsorAd != null) PinnedSponsorCommentCard(ad: sponsorAd, videoId: controller.video.id),
                            const SizedBox(height: 40),
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.chat_bubble_outline,
                                    color: textSecondary,
                                    size: 48,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No comments yet',
                                    style: GoogleFonts.roboto(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }
                      return ListView.builder(
                        controller: scrollController,
                        itemCount: commentsController.comments.length + (sponsorAd != null ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (sponsorAd != null && index == 0) {
                            return PinnedSponsorCommentCard(ad: sponsorAd, videoId: controller.video.id);
                          }
                          final commentIndex = sponsorAd != null ? index - 1 : index;
                          final comment = commentsController.comments[commentIndex];
                          return _buildCommentItem(
                            comment,
                            controller.video.id,
                          );
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
                            key: ValueKey(
                              'popup_comment_input_${controller.video.id}',
                            ),
                            videoId: controller.video.id,
                            onSubmit: (text, postAsChannel, channelId) async {
                              try {
                                final authService = AuthService.to;
                                final hasChannel = authService.hasChannel.value;
                                final channel = authService.userChannel;

                                final shouldPostAsChannel =
                                    postAsChannel || hasChannel;
                                final targetChannelId = shouldPostAsChannel
                                    ? (channelId ?? channel?.id)
                                    : null;
                                final targetChannelName = shouldPostAsChannel
                                    ? (channel?.handle.isNotEmpty ?? false
                                          ? channel?.handle
                                          : channel?.name)
                                    : null;
                                final targetChannelAvatar = shouldPostAsChannel
                                    ? channel?.avatarUrl
                                    : null;
                                final targetUserAvatar =
                                    AuthService.to.activePhotoUrl;

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
      final expanded = controller.isExpanded.value;
      final showTranscript = controller.isTranscriptVisible.value;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => controller.isExpanded.value = !expanded,
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
                  ClickableUrlText(
                    text: controller.video.description,
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
            const SizedBox(height: 12),
            // Show Transcript button
            InkWell(
              onTap: () {
                final nextVisible = !showTranscript;
                controller.isTranscriptVisible.value = nextVisible;
                if (nextVisible) {
                  TowerPlayerController? playerCtrl;
                  final tag = controller.video.id;
                  if (Get.isRegistered<TowerPlayerController>(tag: tag)) {
                    playerCtrl = Get.find<TowerPlayerController>(tag: tag);
                  } else if (Get.isRegistered<TowerPlayerController>()) {
                    playerCtrl = Get.find<TowerPlayerController>();
                  }
                  if (playerCtrl != null && playerCtrl.subtitleSegments.isEmpty) {
                    final subUrl = controller.availableSubtitles.firstOrNull?.url ??
                        controller.video.mediaSubtitles['en'] ??
                        controller.video.transcriptionUrl;
                    if (subUrl.isNotEmpty) {
                      playerCtrl.fetchAndParseSubtitles(subUrl);
                    }
                  }
                }
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.description_outlined,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      showTranscript ? 'Hide Transcript' : 'Show Transcript',
                      style: GoogleFonts.roboto(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      showTranscript
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: Colors.white70,
                    ),
                  ],
                ),
              ),
            ),
            if (showTranscript) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: _buildTranscriptContent(context),
              ),
            ],
          ],
        ),
      );
    });
  }

  Widget _buildTranscriptContent(BuildContext context) {
    TowerPlayerController? playerCtrl;
    final tag = controller.video.id;
    if (Get.isRegistered<TowerPlayerController>(tag: tag)) {
      playerCtrl = Get.find<TowerPlayerController>(tag: tag);
    } else if (Get.isRegistered<TowerPlayerController>()) {
      playerCtrl = Get.find<TowerPlayerController>();
    }

    final segments = playerCtrl?.subtitleSegments ?? [];
    final credibility = VideoMediaService.credibilityCache[controller.video.id];
    final summaryText = (credibility?.summary.isNotEmpty == true)
        ? credibility!.summary
        : ((credibility?.uiReport?.narrative.isNotEmpty == true)
            ? credibility!.uiReport!.narrative
            : '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (summaryText.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.brand.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, size: 16, color: AppColors.textPrimary),
                    const SizedBox(width: 6),
                    Text(
                      'AI EXECUTIVE SUMMARY',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.brand,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  summaryText,
                  style: GoogleFonts.roboto(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 16),
        ],
        if (segments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No timestamped transcript lines available for this video.',
              style: GoogleFonts.roboto(
                color: Colors.white70,
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else ...[
          Text(
            'TIMESTAMPED TRANSCRIPT',
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white54,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: segments.length,
            itemBuilder: (context, index) {
              final seg = segments[index];
              final pos = playerCtrl?.vv.position ?? Duration.zero;
              final isActive = pos >= seg.start && pos <= seg.end;
              return InkWell(
                onTap: () {
                  playerCtrl?.seekTo(seg.start);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatTranscriptDuration(seg.start),
                        style: GoogleFonts.roboto(
                          color: isActive ? primary : Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          seg.text,
                          style: GoogleFonts.roboto(
                            color: isActive ? Colors.white : Colors.white70,
                            fontSize: 13,
                            fontWeight: isActive
                                ? FontWeight.bold
                                : FontWeight.normal,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  String _formatTranscriptDuration(Duration d) {
    final mins = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$mins:$secs';
    }
    return '$mins:$secs';
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
  const _AnimatedReactionButton({
    required this.icon,
    required this.isActive,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
    required this.borderRadius,
    this.label,
  });
  final IconData icon;
  final String? label;
  final bool isActive;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;
  final BorderRadius borderRadius;

  @override
  State<_AnimatedReactionButton> createState() =>
      _AnimatedReactionButtonState();
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
        tween: Tween<double>(
          begin: 1,
          end: 1.4,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.4,
          end: 1,
        ).chain(CurveTween(curve: Curves.bounceOut)),
        weight: 60,
      ),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(covariant _AnimatedReactionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive && widget.isActive) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasLabel = widget.label != null && widget.label!.isNotEmpty;
    return InkWell(
      onTap: widget.onTap,
      borderRadius: widget.borderRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 8,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _scaleAnimation,
              child: Icon(
                widget.icon,
                size: 20,
                color: widget.isActive
                    ? widget.activeColor
                    : widget.inactiveColor,
              ),
            ),
            if (hasLabel) ...[
              const SizedBox(width: 6),
              Text(
                widget.label!,
                style: TextStyle(
                  color: widget.isActive
                      ? widget.activeColor
                      : widget.inactiveColor,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ==========================================================================
// COMMENT ITEM WIDGET WITH LIKE/DISLIKE/REPLY
// ==========================================================================

class _CommentItemWidget extends StatefulWidget {
  const _CommentItemWidget({
    required this.comment,
    required this.videoId,
    required this.channelAvatarUrl,
    required this.mainController,
    required this.textSecondary,
  });
  final Comment comment;
  final String videoId;
  final String channelAvatarUrl;
  final MainController mainController;
  final Color textSecondary;

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

  Future<void> _submitReply() async {
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
      final commentsController = Get.isRegistered<CommentsController>(tag: tag)
          ? Get.find<CommentsController>(tag: tag)
          : Get.put(CommentsController(), tag: tag);

      final authService = AuthService.to;
      final hasChannel = authService.hasChannel.value;
      final channel = authService.userChannel;

      final targetChannelId = hasChannel ? channel?.id : null;
      final targetChannelName = hasChannel
          ? (channel?.handle.isNotEmpty ?? false
                ? channel?.handle
                : channel?.name)
          : null;
      final targetChannelAvatar = AuthService.to.activePhotoUrl.isNotEmpty
          ? AuthService.to.activePhotoUrl
          : null;
      final targetUserAvatar = AuthService.to.activePhotoUrl;

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

  Future<void> _toggleSaveVideoComment(Comment comment, String videoId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Get.snackbar(
        'Authentication Required',
        'Please sign in to save comments.',
      );
      return;
    }
    final docRef = FirebaseFirestore.instance
        .collection(FirestoreCollections.users)
        .doc(user.uid)
        .collection('savedComments')
        .doc(comment.id);

    try {
      final docSnap = await docRef.get();
      if (docSnap.exists) {
        await docRef.delete();
        Get.snackbar('Removed', 'Comment removed from Saved Comments');
      } else {
        await docRef.set({
          'text': comment.text,
          'userName': comment.displayName,
          'userImage': comment.avatarUrl,
          'sourceType': 'video',
          'sourceId': videoId,
          'sourceTitle': 'Video',
          'savedAt': FieldValue.serverTimestamp(),
        });

        Get.snackbar(
          'Saved',
          'Comment saved to Saved Comments',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.bgSurface,
          colorText: AppColors.textPrimary,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
          mainButton: TextButton(
            onPressed: () => Get.toNamed('/saved-comments'),
            child: const Text(
              'VIEW',
              style: TextStyle(
                color: AppColors.brand,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to save comment: $e');
    }
  }

  void _copyCommentText(String text) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    Get.snackbar(
      'Copied',
      'Comment text copied to clipboard',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.grey.shade900,
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      duration: const Duration(seconds: 2),
      icon: const Icon(Icons.content_copy_rounded, color: Colors.white),
    );
  }

  Future<void> _toggleSaveReply(Reply reply, String videoId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Get.snackbar(
        'Authentication Required',
        'Please sign in to save comments.',
      );
      return;
    }
    final docRef = FirebaseFirestore.instance
        .collection(FirestoreCollections.users)
        .doc(user.uid)
        .collection('savedComments')
        .doc(reply.id);

    try {
      final docSnap = await docRef.get();
      if (docSnap.exists) {
        await docRef.delete();
        Get.snackbar('Removed', 'Reply removed from Saved Comments');
      } else {
        await docRef.set({
          'text': reply.text,
          'userName': reply.displayName,
          'userImage': reply.avatarUrl,
          'sourceType': 'video',
          'sourceId': videoId,
          'sourceTitle': 'Video',
          'savedAt': FieldValue.serverTimestamp(),
        });

        Get.snackbar(
          'Saved',
          'Reply saved to Saved Comments',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.bgSurface,
          colorText: AppColors.textPrimary,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
          mainButton: TextButton(
            onPressed: () => Get.toNamed('/saved-comments'),
            child: const Text(
              'VIEW',
              style: TextStyle(
                color: AppColors.brand,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to save reply: $e');
    }
  }

  void _showCommentOptions(
    BuildContext context,
    Comment comment,
    CommentsController commentsController,
  ) {
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
              ListTile(
                leading: const Icon(
                  Icons.content_copy_rounded,
                  color: Colors.white,
                ),
                title: const Text(
                  'Copy text',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _copyCommentText(comment.text);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.bookmark_outline_rounded,
                  color: Colors.white,
                ),
                title: const Text(
                  'Save comment',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _toggleSaveVideoComment(
                    comment,
                    commentsController.video?.id ?? '',
                  );
                },
              ),
              if (isOwner)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    commentsController.deleteComment(comment.id);
                  },
                )
              else
                ListTile(
                  leading: const Icon(Icons.flag_outlined, color: Colors.white),
                  title: const Text(
                    'Report',
                    style: TextStyle(color: Colors.white),
                  ),
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

  Future<void> _navigateToChannel(String? channelId) async {
    if (channelId == null || channelId.isEmpty) return;
    try {
      Get.dialog(
        const Center(
          child: CircularProgressIndicator(color: AppColors.brand),
        ),
        barrierDismissible: false,
      );
      final doc = await FirebaseFirestore.instance
          .collection(FirestoreCollections.channels)
          .doc(channelId)
          .get();
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
      if (doc.exists) {
        final channel = Channel.fromDocumentSnapshot(doc);
        Get.offAndToNamed(
          channel.channelRoute,
          arguments: {'channel': channel},
        );
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

  void _showReplyOptions(
    BuildContext context,
    Reply reply,
    String commentId,
    CommentsController commentsController,
  ) {
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
              ListTile(
                leading: const Icon(
                  Icons.content_copy_rounded,
                  color: Colors.white,
                ),
                title: const Text(
                  'Copy text',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _copyCommentText(reply.text);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.bookmark_outline_rounded,
                  color: Colors.white,
                ),
                title: const Text(
                  'Save comment',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _toggleSaveReply(reply, commentsController.video?.id ?? '');
                },
              ),
              if (isOwner)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    commentsController.deleteReply(commentId, reply.id);
                  },
                )
              else
                ListTile(
                  leading: const Icon(Icons.flag_outlined, color: Colors.white),
                  title: const Text(
                    'Report',
                    style: TextStyle(color: Colors.white),
                  ),
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
    final userName = comment.displayName;
    final formattedUserName = userName.startsWith('@')
        ? userName
        : '@$userName';
    final text = comment.text;
    final createdAt = comment.createdAt;
    final userProfilePicUrl = comment.avatarUrl;
    final likeCount = comment.likeCount;
    final commentId = comment.id;

    final tag = 'video_${widget.videoId}';
    final commentsController = Get.isRegistered<CommentsController>(tag: tag)
        ? Get.find<CommentsController>(tag: tag)
        : Get.put(CommentsController(), tag: tag);

    return Obx(() {
      final isLiked = commentsController.isCommentLikedByUser(comment);
      final isDisliked = commentsController.isCommentDislikedByUser(comment);

      final isTarget =
          commentsController.targetCommentId.value == comment.id &&
          commentsController.targetReplyId.value == null;

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
                    width: 3,
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
                              child:
                                  comment.channelId.isNotEmpty &&
                                      comment.channelId ==
                                          commentsController.video?.channelId
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.15,
                                        ),
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
                                  isLiked
                                      ? Icons.thumb_up
                                      : Icons.thumb_up_outlined,
                                  size: 16,
                                  color: isLiked
                                      ? Colors.white
                                      : Colors.grey.shade400,
                                ),
                                const SizedBox(width: 6),
                                if (likeCount > 0)
                                  Text(
                                    '$likeCount',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isLiked
                                          ? Colors.white
                                          : Colors.grey.shade400,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          InkWell(
                            onTap: () =>
                                commentsController.toggleCommentDislike(
                                  commentId: commentId,
                                  dislikeAsChannel: false,
                                ),
                            child: Icon(
                              isDisliked
                                  ? Icons.thumb_down
                                  : Icons.thumb_down_outlined,
                              size: 16,
                              color: isDisliked
                                  ? Colors.white
                                  : Colors.grey.shade400,
                            ),
                          ),
                          if (comment.isHeartedByCreator) ...[
                            const SizedBox(width: 8),
                            Tooltip(
                              message:
                                  'Hearted by ${comment.creatorHeartName ?? 'Creator'}',
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
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (mounted &&
                                      replyFocusNode.canRequestFocus) {
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
                  icon: Icon(
                    Icons.more_vert,
                    color: Colors.grey.shade400,
                    size: 18,
                  ),
                  onPressed: () =>
                      _showCommentOptions(context, comment, commentsController),
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
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 8,
                          ),
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                        ),
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
                      icon: Obx(
                        () => Icon(
                          Icons.send,
                          size: 20,
                          color: replyText.value.isNotEmpty
                              ? Colors.blue
                              : Colors.grey,
                        ),
                      ),
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
    final commentsController = Get.isRegistered<CommentsController>(tag: tag)
        ? Get.find<CommentsController>(tag: tag)
        : Get.put(CommentsController(), tag: tag);

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
                      branchY: 18,
                    ),
                  ),
                  UserAvatar(
                    radius: 10,
                    photoUrl: firstReply.avatarUrl,
                    displayName: firstReply.displayName,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    replies.length == 1
                        ? '• 1 reply'
                        : '• ${replies.length} replies',
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
                final isReplyLiked = commentsController.isReplyLikedByUser(
                  reply.id,
                );
                final isReplyDisliked = commentsController
                    .isReplyDislikedByUser(reply.id);

                final isReplyTarget =
                    commentsController.targetReplyId.value == reply.id;

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
                          branchY: 20,
                        ),
                      ),
                      Expanded(
                        child: Container(
                          decoration: isReplyTarget
                              ? BoxDecoration(
                                  color: AppColors.brand.withValues(
                                    alpha: 0.08,
                                  ),
                                  border: const Border(
                                    left: BorderSide(
                                      color: AppColors.brand,
                                      width: 3,
                                    ),
                                  ),
                                )
                              : null,
                          padding: const EdgeInsets.only(
                            top: 8,
                            bottom: 8,
                            right: 16,
                            left: 8,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: () =>
                                    _navigateToChannel(reply.channelId),
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
                                          onTap: () => _navigateToChannel(
                                            reply.channelId,
                                          ),
                                          child: MouseRegion(
                                            cursor: SystemMouseCursors.click,
                                            child:
                                                reply.channelId.isNotEmpty &&
                                                    reply.channelId ==
                                                        commentsController
                                                            .video
                                                            ?.channelId
                                                ? Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 1.5,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white
                                                          .withValues(
                                                            alpha: 0.15,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          reply.displayName
                                                                  .startsWith(
                                                                    '@',
                                                                  )
                                                              ? reply
                                                                    .displayName
                                                              : '@${reply.displayName}',
                                                          style:
                                                              const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 11,
                                                                color: Colors
                                                                    .white,
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                          width: 3,
                                                        ),
                                                        const Icon(
                                                          Icons.check,
                                                          size: 11,
                                                          color: Colors.white70,
                                                        ),
                                                      ],
                                                    ),
                                                  )
                                                : Text(
                                                    reply.displayName
                                                            .startsWith('@')
                                                        ? reply.displayName
                                                        : '@${reply.displayName}',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 12,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          timeago.format(
                                            reply.createdAt.toDate(),
                                          ),
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
                                          onTap: () => commentsController
                                              .toggleReplyLike(
                                                commentId: commentId,
                                                replyId: reply.id,
                                                likeAsChannel: false,
                                                replyAuthorId: reply.userId,
                                                replyText: reply.text,
                                              ),
                                          child: Icon(
                                            isReplyLiked
                                                ? Icons.thumb_up
                                                : Icons.thumb_up_outlined,
                                            size: 14,
                                            color: isReplyLiked
                                                ? Colors.white
                                                : Colors.grey.shade400,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        if (reply.likeCount > 0)
                                          Text(
                                            '${reply.likeCount}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isReplyLiked
                                                  ? Colors.white
                                                  : Colors.grey.shade400,
                                            ),
                                          ),
                                        const SizedBox(width: 16),
                                        InkWell(
                                          onTap: () => commentsController
                                              .toggleReplyDislike(
                                                commentId: commentId,
                                                replyId: reply.id,
                                                dislikeAsChannel: false,
                                              ),
                                          child: Icon(
                                            isReplyDisliked
                                                ? Icons.thumb_down
                                                : Icons.thumb_down_outlined,
                                            size: 14,
                                            color: isReplyDisliked
                                                ? Colors.white
                                                : Colors.grey.shade400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.more_vert,
                                  color: Colors.grey.shade400,
                                  size: 16,
                                ),
                                onPressed: () => _showReplyOptions(
                                  context,
                                  reply,
                                  commentId,
                                  commentsController,
                                ),
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
                        branchY: 18,
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
  ReplyThreadLinePainter({
    required this.color,
    required this.isLast,
    required this.branchY,
  });
  final Color color;
  final bool isLast;
  final double branchY;

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
  const RecommendationFeed({
    required this.video,
    super.key,
    this.videoTag,
    this.shrinkWrap = false,
    this.physics,
    this.videos,
    this.isGrid = false,
  });
  final Video video;
  final String? videoTag;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final List<Video>? videos;
  final bool isGrid;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<VideoController>(tag: videoTag);

    return Obx(() {
      if (controller.isLoadingRecommendations.value) {
        return isGrid
            ? buildShimmerVideoGrid(count: 4)
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: isSelected
                        ? null
                        : Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                            width: 0.5,
                          ),
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

      final isAllTab = selectedFilter == 'All' && videos == null;
      final displayItems = isAllTab ? controller.recommendedItems : displayVideos;

      final videoList = isGrid
          ? LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                var crossAxisCount = 1;
                var aspectRatio = 1.2;

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
                  itemCount: displayItems.length,
                  itemBuilder: (context, index) {
                    final item = displayItems[index];
                    if (item is Topic) {
                      return TopicCardWidget(
                        topic: item,
                      );
                    }
                    if (item is CommunityPostModel) {
                      return CommunityPostCard(
                        post: item,
                        isFullWidth: false,
                      );
                    }
                    if (item is Video) {
                      return VideoCard(
                        video: item,
                        isGrid: true,
                        heroPrefix: 'rec_grid_${videoTag ?? 'global'}',
                        disableHoverPreview: true,
                      );
                    }
                    return const SizedBox.shrink();
                  },
                );
              },
            )
          : ListView.builder(
              shrinkWrap: shrinkWrap,
              physics: physics,
              padding: const EdgeInsets.all(16),
              itemCount: displayItems.length,
              itemBuilder: (context, index) {
                final item = displayItems[index];
                if (item is Topic) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: TopicCardWidget(
                      topic: item,
                    ),
                  );
                }
                if (item is CommunityPostModel) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: CommunityPostCard(
                      post: item,
                      isFullWidth: false,
                    ),
                  );
                }
                if (item is Video) {
                  return VideoCard(
                    video: item,
                    heroPrefix: 'rec_list_${videoTag ?? 'global'}',
                    disableHoverPreview: true,
                  );
                }
                return const SizedBox.shrink();
              },
            );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          pillsBar,
          // Render Scroll Ad before recommended videos
          if (Get.isRegistered<AdService>() && AdService.to.showAds.value)
            Obx(() {
              final scrollAds = AdService.to.getAdsForType('scroll');
              final sponsorAd = AdService.to.getSponsorAdForVideo(controller.video.id);
              final displayAd = scrollAds.isNotEmpty ? scrollAds.first : sponsorAd;
              if (displayAd == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 8),
                child: ScrollAdCard(ad: displayAd),
              );
            }),
          if (displayItems.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No recommendations found',
                  style: TextStyle(color: Colors.white24),
                ),
              ),
            )
          else
            shrinkWrap ? videoList : Expanded(child: videoList),
        ],
      );
    });
  }
}

class _ResponsiveAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ResponsiveAppBar({
    required this.controller,
    required this.appBarBuilder,
  });
  final VideoController controller;
  final PreferredSizeWidget Function() appBarBuilder;

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

// ==========================================================================
// ROTATING PLAYLIST AVATAR WIDGET
// ==========================================================================
class RotatingPlaylistAvatar extends StatefulWidget {
  final PlaylistModel playlist;
  final bool isPlaying;
  final VoidCallback? onTap;
  final double size;

  const RotatingPlaylistAvatar({
    required this.playlist, super.key,
    this.isPlaying = true,
    this.onTap,
    this.size = 52.0,
  });

  @override
  State<RotatingPlaylistAvatar> createState() => _RotatingPlaylistAvatarState();
}

class _RotatingPlaylistAvatarState extends State<RotatingPlaylistAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );
    if (widget.isPlaying) {
      _rotationController.repeat();
    }
  }

  @override
  void didUpdateWidget(RotatingPlaylistAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _rotationController.repeat();
      } else {
        _rotationController.stop();
      }
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final avatar = Stack(
      clipBehavior: Clip.none,
      children: [
        // Rotating vinyl disc / circular avatar
        RotationTransition(
          turns: _rotationController,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const SweepGradient(
                colors: [
                  Color(0xFF1F2937),
                  Color(0xFF111827),
                  Color(0xFF374151),
                  Color(0xFF111827),
                  Color(0xFF1F2937),
                ],
              ),
              border: Border.all(
                color: AppColors.brand.withValues(alpha: 0.8),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.brand.withValues(alpha: 0.35),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(3.0),
              child: ClipOval(
                child: widget.playlist.thumbnailUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: widget.playlist.thumbnailUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => _buildFallback(),
                        errorWidget: (_, _, _) => _buildFallback(),
                      )
                    : _buildFallback(),
              ),
            ),
          ),
        ),
        // Center spindle dot for vinyl record styling
        Positioned.fill(
          child: Center(
            child: Container(
              width: widget.size * 0.22,
              height: widget.size * 0.22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.85),
                border: Border.all(color: Colors.white60),
              ),
            ),
          ),
        ),
        // Playing equalizer badge at bottom right corner
        Positioned(
          bottom: -2,
          right: -2,
          child: Container(
            padding: const EdgeInsets.all(3.5),
            decoration: const BoxDecoration(
              color: AppColors.brand,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 4,
                ),
              ],
            ),
            child: PlayingAudioWaveAnimation(
              isPlaying: widget.isPlaying,
              height: 10,
              barWidth: 2,
            ),
          ),
        ),
      ],
    );

    if (widget.onTap != null) {
      return GestureDetector(
        onTap: widget.onTap,
        child: avatar,
      );
    }
    return avatar;
  }

  Widget _buildFallback() {
    return Container(
      color: Colors.grey[900],
      child: const Icon(
        Icons.playlist_play_rounded,
        color: Colors.white70,
        size: 24,
      ),
    );
  }
}

// ==========================================================================
// PLAYING AUDIO WAVE ANIMATION WIDGET
// ==========================================================================
class PlayingAudioWaveAnimation extends StatefulWidget {
  final bool isPlaying;
  final double height;
  final double barWidth;
  final Color color;

  const PlayingAudioWaveAnimation({
    super.key,
    this.isPlaying = true,
    this.height = 14,
    this.barWidth = 2.5,
    this.color = AppColors.brand,
  });

  @override
  State<PlayingAudioWaveAnimation> createState() =>
      _PlayingAudioWaveAnimationState();
}

class _PlayingAudioWaveAnimationState extends State<PlayingAudioWaveAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    if (widget.isPlaying) {
      _animController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(PlayingAudioWaveAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _animController.repeat(reverse: true);
      } else {
        _animController.stop();
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, _) {
        final t = _animController.value;
        final h1 = widget.height * (0.3 + 0.7 * (0.5 + 0.5 * (t * 3.14).abs()));
        final h2 =
            widget.height * (0.4 + 0.6 * (0.5 + 0.5 * ((1 - t) * 3.14).abs()));
        final h3 =
            widget.height *
            (0.2 + 0.8 * (0.5 + 0.5 * ((t + 0.5) * 3.14).abs()));

        return SizedBox(
          height: widget.height,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildBar(widget.isPlaying ? h1 : widget.height * 0.4),
              SizedBox(width: widget.barWidth),
              _buildBar(widget.isPlaying ? h2 : widget.height * 0.7),
              SizedBox(width: widget.barWidth),
              _buildBar(widget.isPlaying ? h3 : widget.height * 0.3),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBar(double barHeight) {
    return Container(
      width: widget.barWidth,
      height: barHeight.clamp(2.0, widget.height),
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}

// ==========================================================================
// ROTATING TOPIC AVATAR WIDGET
// ==========================================================================
class RotatingTopicAvatar extends StatefulWidget {
  final Topic topic;
  final bool isPlaying;
  final VoidCallback? onTap;
  final double size;

  const RotatingTopicAvatar({
    required this.topic, super.key,
    this.isPlaying = true,
    this.onTap,
    this.size = 52.0,
  });

  @override
  State<RotatingTopicAvatar> createState() => _RotatingTopicAvatarState();
}

class _RotatingTopicAvatarState extends State<RotatingTopicAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );
    if (widget.isPlaying) {
      _rotationController.repeat();
    }
  }

  @override
  void didUpdateWidget(RotatingTopicAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _rotationController.repeat();
      } else {
        _rotationController.stop();
      }
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.topic.thumbnailUrl ?? widget.topic.coverImage ?? '';

    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Rotating vinyl disc / circular avatar
          RotationTransition(
            turns: _rotationController,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const SweepGradient(
                  colors: [
                    Color(0xFF3B82F6),
                    Color(0xFF1D4ED8),
                    Color(0xFF8B5CF6),
                    Color(0xFF1D4ED8),
                    Color(0xFF3B82F6),
                  ],
                ),
                border: Border.all(
                  color: const Color(0xFF60A5FA),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(3.0),
                child: ClipOval(
                  child: imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => _buildFallback(),
                          errorWidget: (_, _, _) => _buildFallback(),
                        )
                      : _buildFallback(),
                ),
              ),
            ),
          ),
          // Center spindle dot for vinyl record styling
          Positioned.fill(
            child: Center(
              child: Container(
                width: widget.size * 0.22,
                height: widget.size * 0.22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.85),
                  border: Border.all(color: Colors.white60),
                ),
              ),
            ),
          ),
          // Playing equalizer badge at bottom right corner
          Positioned(
            bottom: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.all(3.5),
              decoration: const BoxDecoration(
                color: Color(0xFF3B82F6),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 4,
                  ),
                ],
              ),
              child: PlayingAudioWaveAnimation(
                isPlaying: widget.isPlaying,
                height: 10,
                barWidth: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallback() {
    return Container(
      color: Colors.grey[900],
      child: const Center(
        child: Text(
          '#',
          style: TextStyle(
            color: Color(0xFF60A5FA),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
    );
  }
}

// ==========================================================================
// TOPIC VIDEOS BOTTOM SHEET / POPUP
// ==========================================================================
class TopicVideosBottomSheet extends StatefulWidget {
  final Topic topic;
  final String? videoTag;

  const TopicVideosBottomSheet({
    required this.topic,
    super.key,
    this.videoTag,
  });

  @override
  State<TopicVideosBottomSheet> createState() => _TopicVideosBottomSheetState();
}

class _TopicVideosBottomSheetState extends State<TopicVideosBottomSheet> {
  final RxString _selectedFilter = 'All'.obs;
  final RxList<Video> _allVideos = <Video>[].obs;
  final RxBool _isLoading = true.obs;

  final List<String> _filters = [
    'All',
    'From subscribed channels',
    'New',
    'Trending',
    'Popular',
    'Fact checked',
  ];

  VideoController? get _videoController {
    try {
      if (widget.videoTag != null &&
          Get.isRegistered<VideoController>(tag: widget.videoTag)) {
        return Get.find<VideoController>(tag: widget.videoTag);
      }
      if (Get.isRegistered<VideoController>()) {
        return Get.find<VideoController>();
      }
    } catch (_) {}
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadTopicVideos();
  }

  Future<void> _loadTopicVideos() async {
    try {
      final slug = widget.topic.slug;
      final topicId = widget.topic.id;

      // 1. Query by topic slug
      final snap = await FirebaseFirestore.instance
          .collection(FirestoreCollections.videos)
          .where('topics', arrayContains: slug.isNotEmpty ? slug : topicId)
          .limit(30)
          .get();

      var fetched = snap.docs.map(Video.fromDocumentSnapshot).toList();

      // 2. If empty and featuredVideoIds present, fetch by IDs
      if (fetched.isEmpty && widget.topic.featuredVideoIds.isNotEmpty) {
        final ids = widget.topic.featuredVideoIds.take(10).toList();
        final snapIds = await FirebaseFirestore.instance
            .collection(FirestoreCollections.videos)
            .where(FieldPath.documentId, whereIn: ids)
            .get();
        fetched = snapIds.docs.map(Video.fromDocumentSnapshot).toList();
      }

      // 3. Fallback to broad query
      if (fetched.isEmpty) {
        final snapFallback = await FirebaseFirestore.instance
            .collection(FirestoreCollections.videos)
            .limit(30)
            .get();
        fetched = snapFallback.docs
            .map(Video.fromDocumentSnapshot)
            .where(
              (v) =>
                  v.topics.any((t) => t.toLowerCase() == slug.toLowerCase()) ||
                  v.tags.any(
                    (t) => t.toLowerCase() == widget.topic.title.toLowerCase(),
                  ) ||
                  v.category.toLowerCase() == widget.topic.title.toLowerCase(),
            )
            .toList();
        if (fetched.isEmpty && snapFallback.docs.isNotEmpty) {
          fetched = snapFallback.docs.map(Video.fromDocumentSnapshot).toList();
        }
      }

      if (mounted) {
        _allVideos.assignAll(fetched);
        _isLoading.value = false;
      }
    } catch (e) {
      if (mounted) {
        _isLoading.value = false;
      }
    }
  }

  List<Video> get _filteredVideos {
    final videoController = _videoController;
    final currentVideo = videoController?.video;
    final filter = _selectedFilter.value;
    final all = _allVideos;

    switch (filter) {
      case 'From subscribed channels':
        if (videoController == null || currentVideo == null) return all;
        return all.where((v) {
          return videoController.channelController.isSubscribed.value &&
              v.channelId == currentVideo.channelId;
        }).toList();
      case 'New':
        final list = List<Video>.from(_allVideos);
        list.sort(
          (a, b) =>
              _getDateTime(b.createdAt).compareTo(_getDateTime(a.createdAt)),
        );
        return list;
      case 'Trending':
        final list = List<Video>.from(_allVideos);
        list.sort((a, b) => b.views.compareTo(a.views));
        return list;
      case 'Popular':
        final list = List<Video>.from(_allVideos);
        list.sort((a, b) => b.likes.compareTo(a.likes));
        return list;
      case 'Fact checked':
        final factChecked = _allVideos
            .where((v) => v.isFactChecked)
            .toList();
        return factChecked.isNotEmpty ? factChecked : _allVideos;
      case 'All':
      default:
        return _allVideos;
    }
  }

  DateTime _getDateTime(dynamic date) {
    if (date is DateTime) return date;
    if (date is Timestamp) return date.toDate();
    return DateTime(2000);
  }

  String _formatViews(int views) {
    if (views >= 1000000) return '${(views / 1000000).toStringAsFixed(1)}M';
    if (views >= 1000) return '${(views / 1000).toStringAsFixed(1)}K';
    return '$views';
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';
    DateTime? dt;
    if (date is DateTime) {
      dt = date;
    } else if (date is Timestamp) {
      dt = date.toDate();
    }
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inDays >= 365) return '${(diff.inDays / 365).floor()} years ago';
    if (diff.inDays >= 30) return '${(diff.inDays / 30).floor()} months ago';
    if (diff.inDays >= 7) return '${(diff.inDays / 7).floor()} weeks ago';
    if (diff.inDays >= 1) return '${diff.inDays} days ago';
    if (diff.inHours >= 1) return '${diff.inHours} hours ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes} mins ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          // Drag indicator handle
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white30,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Sheet Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.topic.title,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Obx(() => Text(
                        '${_allVideos.length} topic videos',
                        style: GoogleFonts.roboto(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      )),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white10, height: 1),

          // Filter pills bar
          Obx(() {
            final activeFilter = _selectedFilter.value;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: _filters.map((filter) {
                  final isSelected = activeFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(
                        filter,
                        style: GoogleFonts.roboto(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          _selectedFilter.value = filter;
                        }
                      },
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      selectedColor: const Color(0xFF3B82F6),
                      checkmarkColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected
                              ? const Color(0xFF3B82F6)
                              : Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      showCheckmark: false,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          }),

          const Divider(color: Colors.white10, height: 1),

          // Video list
          Expanded(
            child: Obx(() {
              final loading = _isLoading.value;
              final filtered = _filteredVideos;
              final activeFilter = _selectedFilter.value;
              final controller = _videoController;
              final currentVideoId = controller?.video.id;
              final isPlaying = controller?.isPlayingRx.value ?? false;

              if (loading) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF3B82F6),
                  ),
                );
              }
              if (filtered.isEmpty) {
                return Center(
                  child: Text(
                    'No videos found for "$activeFilter"',
                    style: GoogleFonts.roboto(
                      color: Colors.white54,
                      fontSize: 14,
                    ),
                  ),
                );
              }
              return ListView.builder(
                itemCount: filtered.length,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemBuilder: (context, index) {
                  final video = filtered[index];
                  final isCurrent = video.id == currentVideoId;

                  return Material(
                    color: isCurrent
                        ? const Color(0xFF3B82F6).withValues(alpha: 0.15)
                        : Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).pop();
                        Get.offNamed(
                          '/watch?v=${video.id}',
                          arguments: {
                            'video': video,
                            'topic': widget.topic,
                            'fromTopic': true,
                          },
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Stack(
                                children: [
                                  Image.network(
                                    video.thumbnailUrl,
                                    width: 120,
                                    height: 68,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Container(
                                      width: 120,
                                      height: 68,
                                      color: Colors.grey[900],
                                      child: const Icon(
                                        Icons.play_circle_fill_rounded,
                                        color: Colors.white38,
                                      ),
                                    ),
                                  ),
                                  if (video.duration.isNotEmpty)
                                    Positioned(
                                      bottom: 4,
                                      right: 4,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(
                                            alpha: 0.8,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          video.duration,
                                          style: GoogleFonts.roboto(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          video.title,
                                          style: GoogleFonts.roboto(
                                            color: isCurrent
                                                ? const Color(0xFF3B82F6)
                                                : Colors.white,
                                            fontSize: 13,
                                            fontWeight: isCurrent
                                                ? FontWeight.bold
                                                : FontWeight.w500,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isCurrent) ...[
                                        const SizedBox(width: 6),
                                        PlayingAudioWaveAnimation(
                                          isPlaying: isPlaying,
                                          height: 12,
                                          barWidth: 2,
                                          color: const Color(0xFF3B82F6),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${video.channelName} • ${_formatViews(video.views)} views • ${_formatDate(video.createdAt)}',
                                    style: GoogleFonts.roboto(
                                      color: Colors.white60,
                                      fontSize: 11,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}
