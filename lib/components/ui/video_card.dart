import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:truthworld/features/miniplayer/presentation/utils/miniplayer_utils.dart';
import 'package:truthworld/core/services/watch_history_service.dart';
import 'dart:async';
import 'package:video_player/video_player.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_controller.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/components/ui/video_options_sheet.dart';

/// Reusable Modern Avatar Widget matching the homescreen design
class _ModernAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final String? placeholderText;

  const _ModernAvatar({
    this.imageUrl,
    required this.radius,
    this.placeholderText,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
          width: 1,
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
          color: Colors.white,
          fontSize: radius * 0.8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

@immutable
class VideoCard extends StatefulWidget {
  final Video video;
  final bool isGrid;
  final String heroPrefix;
  final VoidCallback? onTap;

  const VideoCard({
    super.key,
    required this.video,
    this.isGrid = false,
    this.heroPrefix = 'video_card',
    this.onTap,
  });

  @override
  State<VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<VideoCard> {
  final RxBool _isHovered = false.obs;
  Timer? _hoverTimer;
  final Rxn<VideoPlayerController> _videoPlayerController = Rxn<VideoPlayerController>();
  final RxBool _isControllerInitialized = false.obs;
  final RxBool _isMuted = true.obs;
  final RxBool _isLoadingVideo = false.obs;

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
      debugPrint("Error formatting timestamp: $e");
      return "some time ago";
    }
  }

  @override
  void dispose() {
    _hoverTimer?.cancel();
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

    String previewUrl = widget.video.animatedPreviewUrl;
    if (previewUrl.isEmpty || previewUrl.startsWith('gs://')) {
      if (widget.video.adaptiveResolutions.isNotEmpty) {
        // Cost-effective: find lowest bitrate resolution with a playable URL
        final playable = widget.video.adaptiveResolutions
            .where((r) => r.url.isNotEmpty && !r.url.startsWith('gs://'))
            .toList();
        if (playable.isNotEmpty) {
          final lowest = playable.reduce(
            (a, b) => a.bitrate < b.bitrate ? a : b,
          );
          previewUrl = lowest.url;
        }
      }
      // Skip gs:// originalUrl — it's a storage reference, not a playable URL
      if ((previewUrl.isEmpty || previewUrl.startsWith('gs://')) &&
          widget.video.originalUrl.isNotEmpty &&
          !widget.video.originalUrl.startsWith('gs://')) {
        previewUrl = widget.video.originalUrl;
      }
    }

    if (previewUrl.isEmpty || previewUrl.startsWith('gs://')) {
      _isLoadingVideo.value = false;
      return;
    }

    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(previewUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _videoPlayerController.value = controller;

      await controller.initialize();

      if (mounted && _isHovered.value && _videoPlayerController.value == controller) {
        await controller.setVolume(_isMuted.value ? 0.0 : 1.0);
        await controller.setLooping(true);
        await controller.play();
        _isControllerInitialized.value = true;
        _isLoadingVideo.value = false;
      } else {
        controller.dispose();
      }
    } catch (e) {
      debugPrint("Error initializing hover video player: $e");
      if (mounted) {
        _isLoadingVideo.value = false;
      }
    }
  }

  void _handleHoverEnter() {
    _isHovered.value = true;
    _hoverTimer?.cancel();
    _hoverTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted && _isHovered.value) {
        _initializePreviewPlayer();
      }
    });
  }

  void _handleHoverExit() {
    _hoverTimer?.cancel();
    _hoverTimer = null;
    _isHovered.value = false;
    _disposePreviewPlayer();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MouseRegion(
      onEnter: (_) => _handleHoverEnter(),
      onExit: (_) => _handleHoverExit(),
      child: Semantics(
        button: true,
        enabled: true,
        label: 'Video: ${widget.video.title} by ${widget.video.channelName}',
        onTap: widget.onTap ??
            () => MiniplayerNavigationHelper.navigateToVideoScreen(
                  video: widget.video,
                  routeArguments: {
                    'video': widget.video,
                    'heroTag': '${widget.heroPrefix}_${widget.video.id}',
                  },
                ),
        child: Obx(() {
          final hovered = _isHovered.value;
          return AnimatedScale(
            scale: hovered ? 1.04 : 1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: widget.isGrid
                  ? EdgeInsets.zero
                  : EdgeInsets.only(bottom: AppTheme.spacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.1),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: hovered ? 0.25 : 0.1),
                    blurRadius: hovered ? 16 : 8,
                    offset: Offset(0, hovered ? 8 : 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: widget.onTap ??
                      () => MiniplayerNavigationHelper.navigateToVideoScreen(
                            video: widget.video,
                            routeArguments: {
                              'video': widget.video,
                              'heroTag': '${widget.heroPrefix}_${widget.video.id}',
                            },
                          ),
                  borderRadius: BorderRadius.circular(16),
                  child: widget.isGrid
                      ? _buildGridContent(context, theme)
                      : _buildListContent(context, theme),
                ),
              ),
            ),
          );
        }),
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
              child: _buildGridVideoThumbnail(context, theme, isTopRoundedOnly: false),
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
    Color iconColor = Colors.white,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
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

  Widget _buildGridVideoThumbnail(BuildContext context, ThemeData theme, {bool isTopRoundedOnly = true}) {
    final borderRadius = isTopRoundedOnly
        ? const BorderRadius.vertical(top: Radius.circular(16))
        : BorderRadius.circular(12);

    return Hero(
      tag: '${widget.heroPrefix}_${widget.video.id}',
      child: ClipRRect(
        borderRadius: borderRadius,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Obx(() {
            final isInitialized = _isControllerInitialized.value;
            final controller = _videoPlayerController.value;
            final isMutedVal = _isMuted.value;
            final hovered = _isHovered.value;

            return Stack(
              fit: StackFit.expand,
              children: [
                isInitialized && controller != null
                    ? ClipRect(
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
                      )
                    : CachedNetworkImage(
                        imageUrl: widget.video.thumbnailUrl,
                        fit: BoxFit.cover,
                        memCacheWidth: AppTheme.sizes.imageCacheMediumWidth,
                        memCacheHeight: AppTheme.sizes.imageCacheMediumHeight,
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
                          Colors.black.withValues(alpha: 0.3),
                        ],
                      ),
                    ),
                  ),
                // Fact Checked badge
                if (widget.video.videoRating > 0 || widget.video.factCheckUrl.isNotEmpty)
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
                          color: Colors.white.withValues(alpha: 0.15),
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.verified_rounded,
                            color: Colors.white,
                            size: 11,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Fact Checked',
                            style: GoogleFonts.roboto(
                              color: Colors.white,
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        widget.video.duration,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
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
                      onTap: () async {
                        final currentController = _videoPlayerController.value;
                        if (currentController != null) {
                          final newMute = !isMutedVal;
                          await currentController.setVolume(newMute ? 0.0 : 1.0);
                          _isMuted.value = newMute;
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isMutedVal ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                          color: Colors.white,
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
                              iconColor: isSaved ? theme.colorScheme.primary : Colors.white,
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
                              "Added to queue",
                              "'${widget.video.title}' has been added to your play queue.",
                              snackPosition: SnackPosition.BOTTOM,
                              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.8),
                              colorText: Colors.white,
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
                        color: Colors.white.withValues(alpha: 0.2),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: (progress / 100).clamp(0.0, 1.0),
                            child: Container(
                              color: Colors.red,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ModernAvatar(
            imageUrl: widget.video.channelImage,
            radius: 18,
            placeholderText: widget.video.channelName.isEmpty
                ? '?'
                : widget.video.channelName.substring(0, 1).toUpperCase(),
          ),
          const SizedBox(width: 12),
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
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.video.channelName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_formatViews(widget.video.views)} views • ${_formatTimestamp(widget.video.uploadedAt)}',
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
                      imageUrl: widget.video.channelImage,
                      radius: 10,
                      placeholderText: widget.video.channelName.isEmpty
                          ? '?'
                          : widget.video.channelName.substring(0, 1).toUpperCase(),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.video.channelName,
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
                  '${_formatViews(widget.video.views)} views • ${_formatTimestamp(widget.video.uploadedAt)}',
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
          color: Colors.white,
        ),
      ),
    );
  }
}
