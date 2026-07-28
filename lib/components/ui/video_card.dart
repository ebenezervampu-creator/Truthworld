import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:truthworld/components/ui/video_options_sheet.dart';
import 'package:truthworld/core/services/user_preferences_service.dart';
import 'package:truthworld/core/services/watch_history_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/miniplayer/presentation/controllers/miniplayer_controller.dart';
import 'package:truthworld/features/miniplayer/presentation/utils/miniplayer_utils.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_playback_handoff.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Reusable Modern Avatar Widget matching the homescreen design
class _ModernAvatar extends StatelessWidget {

  const _ModernAvatar({
    required this.radius, this.imageUrl,
    this.placeholderText,
  });
  final String? imageUrl;
  final double radius;
  final String? placeholderText;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        child: ClipOval(
          child: hasImage
              ? CachedNetworkImage(
                  imageUrl: imageUrl!,
                  width: radius * 2,
                  height: radius * 2,
                  fit: BoxFit.cover,
                  memCacheWidth:
                      (radius * 2 * MediaQuery.of(context).devicePixelRatio)
                          .toInt(),
                  placeholder: (context, url) => _buildPlaceholder(),
                  errorWidget: (context, url, error) => _buildPlaceholder(),
                )
              : _buildPlaceholder(),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Text(
        placeholderText ?? '?',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: radius * 0.8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class HoverPreviewCoordinator {
  static final RxBool globalMute = true.obs;
  static _VideoCardState? _activeCardState;
  static bool _hasInitializedListener = false;

  static void setActiveCard(dynamic cardState) {
    if (cardState is! _VideoCardState) return;
    if (!_hasInitializedListener) {
      _hasInitializedListener = true;
      ever(globalMute, (bool isMuted) {
        if (!isMuted) {
          pauseAllMainPlayers();
        }
      });
    }
    if (_activeCardState != null && _activeCardState != cardState) {
      _activeCardState!._handleHoverExit();
    }
    _activeCardState = cardState;
  }

  static void clearActiveCard(dynamic cardState) {
    if (_activeCardState == cardState) {
      _activeCardState = null;
    }
  }

  static void pauseAllMainPlayers() {
    try {
      if (Get.isRegistered<MiniplayerController>(tag: 'miniplayer')) {
        final mini = Get.find<MiniplayerController>(tag: 'miniplayer');
        if (mini.isPlaying.value) {
          mini.videoPlayerController?.pause();
          mini.isPlaying.value = false;
        }
      }
    } catch (e) {
      debugPrint('[HoverPreviewCoordinator] Error pausing miniplayer: $e');
    }
    try {
      TowerPlayerController.pauseAllActivePlayers();
    } catch (e) {
      debugPrint('[HoverPreviewCoordinator] Error pausing active tower players: $e');
    }
  }
}

@immutable
class VideoCard extends StatefulWidget {

  const VideoCard({
    required this.video, super.key,
    this.isGrid = false,
    this.heroPrefix = 'video_card',
    this.onTap,
    this.disableHoverPreview = false,
  });
  final Video video;
  final bool isGrid;
  final String heroPrefix;
  final VoidCallback? onTap;
  final bool disableHoverPreview;

  @override
  State<VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<VideoCard> {
  final RxBool _isHovered = false.obs;
  Timer? _hoverTimer;
  final Rxn<VideoPlayerController> _videoPlayerController = Rxn<VideoPlayerController>();
  final RxBool _isControllerInitialized = false.obs;
  final RxBool _isLoadingVideo = false.obs;
  late final Worker _muteWorker;

  final RxString _realChannelAvatarUrl = ''.obs;
  final RxString _realChannelName = ''.obs;

  @override
  void initState() {
    super.initState();
    _realChannelAvatarUrl.value = widget.video.channelAvatarUrl;
    _realChannelName.value = widget.video.channelName;
    _loadRealChannelData();
    _muteWorker = ever(HoverPreviewCoordinator.globalMute, (bool isMuted) {
      if (_videoPlayerController.value != null && _isControllerInitialized.value) {
        _videoPlayerController.value!.setVolume(isMuted ? 0.0 : 1.0);
      }
    });
  }

  Future<void> _loadRealChannelData() async {
    if (widget.video.channelId.isEmpty) return;
    // Only query Firestore if Video model lacks avatar or name
    if (_realChannelAvatarUrl.value.isNotEmpty && _realChannelName.value.isNotEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('channels')
          .doc(widget.video.channelId)
          .get();
      if (doc.exists && mounted) {
        final data = doc.data();
        if (data != null) {
          final avatar = data['avatarUrl'] as String?;
          final name = data['name'] as String?;
          if (avatar != null && avatar.isNotEmpty) {
            _realChannelAvatarUrl.value = avatar;
          }
          if (name != null && name.isNotEmpty) {
            _realChannelName.value = name;
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading real channel data for video card: $e');
    }
  }

  String _formatViews(int views) {
    if (views < 1000) return views.toString();
    if (views < 1000000) {
      return '${(views / 1000).toStringAsFixed(views % 1000 == 0 ? 0 : (views < 100000 ? 1 : 0))}K';
    }
    if (views < 1000000000) {
      return '${(views / 1000000).toStringAsFixed(views % 1000000 == 0 ? 0 : (views < 100000000 ? 1 : 0))}M';
    }
    return '${(views / 1000000000).toStringAsFixed(views % 1000000000 == 0 ? 0 : (views < 100000000000 ? 1 : 0))}B';
  }

  String _formatTimestamp(Timestamp timestamp) {
    try {
      return timeago.format(timestamp.toDate());
    } catch (e) {
      debugPrint('Error formatting timestamp: $e');
      return 'some time ago';
    }
  }

  @override
  void dispose() {
    _muteWorker.dispose();
    _hoverTimer?.cancel();
    HoverPreviewCoordinator.clearActiveCard(this);
    _disposePreviewPlayer();
    super.dispose();
  }

  void _disposePreviewPlayer() {
    if (_videoPlayerController.value != null) {
      final controller = _videoPlayerController.value;
      _videoPlayerController.value = null;
      _isControllerInitialized.value = false;
      _isLoadingVideo.value = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller?.dispose();
      });
    }
  }

  Future<void> _initializePreviewPlayer() async {
    if (_videoPlayerController.value != null || _isLoadingVideo.value) return;

    _isLoadingVideo.value = true;

    var previewUrl = widget.video.animatedPreviewUrl;
    if (previewUrl.isEmpty || previewUrl.startsWith('gs://')) {
      if (widget.video.adaptiveResolutions.isNotEmpty) {
        // Cost-effective: find lowest bitrate resolution
        final playable = widget.video.adaptiveResolutions
            .where((r) => r.url.isNotEmpty)
            .toList();
        if (playable.isNotEmpty) {
          final lowest = playable.reduce(
            (a, b) => a.bitrate < b.bitrate ? a : b,
          );
          previewUrl = lowest.url;
        }
      }
      if (previewUrl.isEmpty || previewUrl.startsWith('gs://')) {
        if (widget.video.originalUrl.isNotEmpty) {
          previewUrl = widget.video.originalUrl;
        }
      }
    }

    if (previewUrl.isEmpty) {
      _isLoadingVideo.value = false;
      return;
    }

    // Resolve gs:// storage references to HTTPS download URLs
    if (previewUrl.startsWith('gs://')) {
      try {
        previewUrl = await FirebaseStorage.instance
            .refFromURL(previewUrl)
            .getDownloadURL();
      } catch (e) {
        debugPrint('Error resolving gs:// preview URL: $e');
        if (mounted) {
          _isLoadingVideo.value = false;
        }
        return;
      }
    }

    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(previewUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _videoPlayerController.value = controller;

      await controller.initialize();

      if (mounted && _isHovered.value && _videoPlayerController.value == controller) {
        HoverPreviewCoordinator.setActiveCard(this);
        await controller.setVolume(HoverPreviewCoordinator.globalMute.value ? 0.0 : 1.0);
        await controller.setLooping(true);
        await controller.play();
        _isControllerInitialized.value = true;
        _isLoadingVideo.value = false;
      } else {
        controller.dispose();
      }
    } catch (e) {
      debugPrint('Error initializing hover video player: $e');
      if (mounted) {
        _isLoadingVideo.value = false;
      }
    }
  }

  void _handleHoverEnter() {
    if (widget.disableHoverPreview) return;
    _isHovered.value = true;
    _hoverTimer?.cancel();
    _hoverTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted && _isHovered.value) {
        _initializePreviewPlayer();
      }
    });
  }

  void _handleHoverExit() {
    if (widget.disableHoverPreview) return;
    _hoverTimer?.cancel();
    _hoverTimer = null;
    _isHovered.value = false;
    HoverPreviewCoordinator.clearActiveCard(this);
    _disposePreviewPlayer();
  }

  void _handleVisibilityChanged(double visibleFraction) {
    if (!mounted || widget.disableHoverPreview) return;
    // Only apply visibility-based preview on mobile platforms (Android/iOS)
    final isMobile = defaultTargetPlatform == TargetPlatform.android ||
                     defaultTargetPlatform == TargetPlatform.iOS;
    if (!isMobile || !mounted) return;

    if (visibleFraction >= 0.8) {
      if (!_isHovered.value) {
        _handleHoverEnter();
      }
    } else {
      if (_isHovered.value) {
        _handleHoverExit();
      }
    }
  }

  void _handleTap(BuildContext context) {
    // Register controller in handoff if initialized to prevent re-buffering
    final controller = _videoPlayerController.value;
    if (controller != null && _isControllerInitialized.value) {
      VideoPlaybackHandoff.registerActiveController(widget.video.id, controller);
      // Clear references to prevent disposal on exit
      _videoPlayerController.value = null;
      _isControllerInitialized.value = false;
      _isLoadingVideo.value = false;
    }

    if (widget.onTap != null) {
      widget.onTap!();
    } else {
      MiniplayerNavigationHelper.navigateToVideoScreen(
        video: widget.video,
        routeArguments: {
          'video': widget.video,
          'heroTag': '${widget.heroPrefix}_${widget.video.id}',
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return VisibilityDetector(
      key: Key('video_card_${widget.video.id}_${widget.heroPrefix}'),
      onVisibilityChanged: (info) {
        if (mounted) {
          _handleVisibilityChanged(info.visibleFraction);
        }
      },
      child: MouseRegion(
        onEnter: (_) => _handleHoverEnter(),
        onExit: (_) => _handleHoverExit(),
        child: Semantics(
          button: true,
          enabled: true,
          label: 'Video: ${widget.video.title} by ${widget.video.channelName}',
          onTap: () => _handleTap(context),
          child: Obx(() {
            if (Get.isRegistered<UserPreferencesService>() &&
                UserPreferencesService.to.isVideoBlocked(widget.video)) {
              return const SizedBox.shrink();
            }
            final hovered = _isHovered.value;
            return AnimatedScale(
              scale: hovered ? 1.02 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: widget.isGrid
                    ? EdgeInsets.zero
                    : EdgeInsets.only(bottom: AppTheme.spacing.md),
                decoration: widget.isGrid
                    ? BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(
                            alpha: 0.1,
                          ),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.bgPage.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      )
                    : const BoxDecoration(
                        color: Colors.transparent,
                      ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _handleTap(context),
                    borderRadius: widget.isGrid ? BorderRadius.circular(16) : null,
                    child: widget.isGrid
                        ? _buildGridContent(context, theme)
                        : _buildListContent(context, theme),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildGridContent(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildGridVideoThumbnail(context, theme),
        _buildGridVideoInfo(context, theme),
      ],
    );
  }

  Widget _buildListContent(BuildContext context, ThemeData theme) {
    return Padding(
      padding: EdgeInsets.all(AppTheme.spacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: AppTheme.sizes.thumbnailMediumWidth,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: _buildGridVideoThumbnail(context, theme, borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: _buildListVideoInfo(context, theme)),
        ],
      ),
    );
  }

  Widget _buildHoverActionIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color iconColor = AppColors.textPrimary,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.bgPage.withValues(alpha: 0.7),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildGridVideoThumbnail(BuildContext context, ThemeData theme, {BorderRadius? borderRadius}) {
    final effectiveBorderRadius = borderRadius ?? const BorderRadius.vertical(top: Radius.circular(16));

    return Hero(
      tag: '${widget.heroPrefix}_${widget.video.id}',
      child: ClipRRect(
        borderRadius: effectiveBorderRadius,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Obx(() {
            final isInitialized = _isControllerInitialized.value;
            final controller = _videoPlayerController.value;
            final isMutedVal = HoverPreviewCoordinator.globalMute.value;
            final hovered = _isHovered.value;

            return Stack(
              fit: StackFit.expand,
              children: [
                if (isInitialized && controller != null) ClipRect(
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: controller.value.size.width > 0
                                ? controller.value.size.width
                                : 160,
                            height: controller.value.size.height > 0
                                ? controller.value.size.height
                                : 90,
                            child: VideoPlayer(controller),
                          ),
                        ),
                      ) else CachedNetworkImage(
                        imageUrl: widget.video.thumbnailUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => _buildThumbnailShimmer(theme),
                        errorWidget: (context, url, error) => _buildThumbnailError(theme),
                      ),
                if (!isInitialized)
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          AppColors.bgPage.withValues(alpha: 0.3),
                        ],
                      ),
                    ),
                  ),
                // Fact Checked badge
                if (widget.video.factCheckUrl.isNotEmpty)
                  Positioned(
                    top: AppTheme.spacing.xs,
                    left: AppTheme.spacing.xs,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppTheme.spacing.xs * 1.5,
                        vertical: AppTheme.spacing.xs / 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.95), // Emerald green
                        borderRadius: AppTheme.radius.circularMd,
                        border: Border.all(
                          color: AppColors.textPrimary.withValues(alpha: 0.15),
                          width: 0.5,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          )
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified_rounded,
                            color: AppColors.textPrimary,
                            size: 11,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Fact Checked',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 9,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Duration badge / mute indicator
                if (!isInitialized)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.bgPage.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        widget.video.duration,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                // Sound / Mute toggle overlay button (YouTube style)
                if (isInitialized)
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: GestureDetector(
                      onTap: () {
                        HoverPreviewCoordinator.globalMute.value = !isMutedVal;
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.bgPage.withValues(alpha: 0.7),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isMutedVal ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                          color: AppColors.textPrimary,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                // Watch Later and Add to Queue overlay icons when hovered (YouTube style)
                if (hovered)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Builder(builder: (context) {
                          final playlistCtrl = Get.isRegistered<PlaylistController>()
                              ? Get.find<PlaylistController>()
                              : Get.put(PlaylistController());
                          return Obx(() {
                            final isSaved = playlistCtrl.isInWatchLater(widget.video.id);
                            return _buildHoverActionIconButton(
                              icon: isSaved ? Icons.check_circle_rounded : Icons.watch_later_outlined,
                              iconColor: isSaved ? theme.colorScheme.primary : AppColors.textPrimary,
                              tooltip: isSaved ? 'Saved to Watch Later' : 'Watch later',
                              onTap: () async {
                                await playlistCtrl.toggleWatchLater(widget.video.id);
                              },
                            );
                          });
                        }),
                        const SizedBox(height: 6),
                        _buildHoverActionIconButton(
                          icon: Icons.playlist_add_rounded,
                          tooltip: 'Add to queue',
                          onTap: () {
                            AppSnackbar.show(
                              'Added to queue',
                              "'${widget.video.title}' has been added to your play queue.",
                              snackPosition: SnackPosition.BOTTOM,
                              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.8),
                              colorText: AppColors.textPrimary,
                              margin: const EdgeInsets.all(20),
                              borderRadius: 16,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                // Watch progress bar (YouTube style)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Builder(builder: (context) {
                    return Obx(() {
                      final progress = WatchHistoryService.to.getProgress(widget.video.id);
                      if (progress <= 0) return const SizedBox.shrink();

                      return Container(
                        height: 3,
                        width: double.infinity,
                        color: AppColors.textPrimary.withValues(alpha: 0.2),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: (progress / 100).clamp(0.0, 1.0),
                            child: Container(
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      );
                    });
                  }),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildGridVideoInfo(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 10, right: 10, top: 10, bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ModernAvatar(
            imageUrl: _realChannelAvatarUrl.value,
            radius: 16,
            placeholderText: _realChannelName.value.isEmpty
                ? '?'
                : _realChannelName.value.substring(0, 1).toUpperCase(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.video.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    height: 1.25,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_realChannelName.value} · ${_formatViews(widget.video.views)} views · ${_formatTimestamp(widget.video.uploadedAt)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.more_vert,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            onPressed: () => VideoOptionsSheet.show(context, widget.video),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
 
  Widget _buildListVideoInfo(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.video.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _ModernAvatar(
                      imageUrl: _realChannelAvatarUrl.value,
                      radius: 10,
                      placeholderText: _realChannelName.value.isEmpty
                          ? '?'
                          : _realChannelName.value.substring(0, 1).toUpperCase(),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _realChannelName.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatViews(widget.video.views)} views · ${_formatTimestamp(widget.video.uploadedAt)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.more_vert,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            onPressed: () => VideoOptionsSheet.show(context, widget.video),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnailShimmer(ThemeData theme) {
    return Shimmer.fromColors(
      baseColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      highlightColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
      child: Container(
        color: theme.colorScheme.surfaceContainerHighest,
      ),
    );
  }

  Widget _buildThumbnailError(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.3),
            theme.colorScheme.secondary.withValues(alpha: 0.2),
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.play_circle_outline_rounded,
          size: 48,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
