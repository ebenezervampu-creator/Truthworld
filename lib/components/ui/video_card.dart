import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:truthworld/components/ui/video_options_sheet.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/deep_link_service.dart';
import 'package:truthworld/core/services/user_preferences_service.dart';
import 'package:truthworld/core/services/video_visibility_policy.dart';
import 'package:truthworld/core/services/watch_history_service.dart';
import 'package:truthworld/core/utils/firestore_cache_extension.dart';
import 'package:truthworld/core/utils/storage_utils.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/core/widgets/mobile_friendly_video_player.dart';
import 'package:truthworld/features/miniplayer/presentation/controllers/miniplayer_controller.dart';
import 'package:truthworld/features/miniplayer/presentation/utils/miniplayer_utils.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_controller.dart';
import 'package:truthworld/features/playlist/presentation/views/playlist/show_diaglog.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_playback_handoff.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Reusable Modern Avatar Widget matching the homescreen design
class _ModernAvatar extends StatelessWidget {
  const _ModernAvatar({
    required this.radius,
    this.imageUrl,
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
  static final RxBool globalMute = false.obs;
  static _VideoCardState? _activeCardState;
  static _VideoCardState? _pendingCardState;

  // Centralized mobile visibility registry (cardState -> visibleFraction)
  static final Map<_VideoCardState, double> _mobileCardVisibilities = {};
  static Timer? _mobileVisibilityDebounce;

  /// Checks if any active main video playback on Homepage or VideoScreen is currently muted.
  static bool isMainVideoMuted() {
    // 1. Check all active TowerPlayerController instances (Watch Screen / Video Screen / Tower Player)
    for (final player in TowerPlayerController.activePlayers) {
      if (player.isMuted.value || player.volume.value == 0.0) {
        return true;
      }
    }
    if (Get.isRegistered<TowerPlayerController>()) {
      try {
        final tower = Get.find<TowerPlayerController>();
        if (tower.isMuted.value || tower.volume.value == 0.0) {
          return true;
        }
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'VideoCard.isMainVideoMuted.tower');
      }
    }

    // 2. Check MiniplayerController (Homepage / Persistent miniplayer)
    if (Get.isRegistered<MiniplayerController>(tag: 'miniplayer')) {
      try {
        final mini = Get.find<MiniplayerController>(tag: 'miniplayer');
        if (mini.isPlaying.value) {
          if (mini.isMuted.value ||
              (mini.videoPlayerController?.value.volume ?? 1.0) == 0.0) {
            return true;
          }
        }
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'VideoCard.isMainVideoMuted.miniplayer');
      }
    }

    return false;
  }

  /// Sets the currently active card and immediately deactivates any previously active card.
  static void setActiveCard(dynamic cardState) {
    if (cardState is! _VideoCardState) return;
    if (_activeCardState != null && _activeCardState != cardState) {
      _activeCardState!._handleHoverExit();
    }
    _activeCardState = cardState;
    _pendingCardState = null;
    if (!globalMute.value) {
      pauseAllMainPlayers();
    }
  }

  /// Clears the active or pending card if it matches.
  static void clearActiveCard(dynamic cardState) {
    if (_activeCardState == cardState) {
      _activeCardState = null;
    }
    if (_pendingCardState == cardState) {
      _pendingCardState = null;
    }
  }

  /// Completely unregisters a card when disposed or scrolled off-screen.
  static void unregisterCard(State cardState) {
    _mobileCardVisibilities.remove(cardState);
    if (_activeCardState == cardState) {
      _activeCardState = null;
    }
    if (_pendingCardState == cardState) {
      _pendingCardState = null;
    }
  }

  /// Reports visibleFraction (0.0 to 1.0) for a VideoCard on mobile feeds.
  /// Automatically determines the single card with the highest visibility and starts preview.
  static void reportMobileVisibility(
    State cardState,
    double visibleFraction,
  ) {
    if (cardState is! _VideoCardState) return;
    if (!cardState.mounted || cardState.widget.disableHoverPreview) {
      _mobileCardVisibilities.remove(cardState);
      return;
    }

    if (visibleFraction < 0.1) {
      _mobileCardVisibilities.remove(cardState);
      if (_activeCardState == cardState) {
        cardState._handleHoverExit();
        _activeCardState = null;
      }
      if (_pendingCardState == cardState) {
        cardState._handleHoverExit();
        _pendingCardState = null;
      }
    } else {
      _mobileCardVisibilities[cardState] = visibleFraction;
    }

    // Debounce visibility evaluation during active scrolling / flings
    _mobileVisibilityDebounce?.cancel();
    _mobileVisibilityDebounce = Timer(
      const Duration(milliseconds: 150),
      _evaluateMobileAutoplay,
    );
  }

  /// Evaluates which video card in the mobile feed should autoplay.
  static void _evaluateMobileAutoplay() {
    // 1. Clean up any unmounted cards
    _mobileCardVisibilities.removeWhere((card, _) => !card.mounted);

    if (_mobileCardVisibilities.isEmpty) {
      if (_activeCardState != null) {
        _activeCardState!._handleHoverExit();
        _activeCardState = null;
      }
      _pendingCardState = null;
      return;
    }

    // 2. Find the card with the highest visible fraction
    _VideoCardState? topCard;
    var maxFraction = 0.0;

    for (final entry in _mobileCardVisibilities.entries) {
      if (entry.value > maxFraction) {
        maxFraction = entry.value;
        topCard = entry.key;
      }
    }

    // 3. Minimum visibility threshold to qualify for autoplay preview (70%)
    const minVisibleThreshold = 0.70;

    if (topCard != null && maxFraction >= minVisibleThreshold) {
      // If the top card is already the active card, ensure all others are stopped
      if (_activeCardState == topCard) {
        for (final card in _mobileCardVisibilities.keys) {
          if (card != topCard &&
              (card._isHovered.value ||
                  card._videoPlayerController.value != null)) {
            card._handleHoverExit();
          }
        }
        return;
      }

      // If already pending initialization for topCard, wait for it
      if (_pendingCardState == topCard) {
        return;
      }

      // Stop any other active/pending card
      if (_activeCardState != null && _activeCardState != topCard) {
        _activeCardState!._handleHoverExit();
        _activeCardState = null;
      }
      if (_pendingCardState != null && _pendingCardState != topCard) {
        _pendingCardState!._handleHoverExit();
        _pendingCardState = null;
      }
      for (final card in _mobileCardVisibilities.keys) {
        if (card != topCard) {
          card._handleHoverExit();
        }
      }

      // Mark topCard as pending and start hover playback flow
      _pendingCardState = topCard;
      topCard._startHoverPlayback();
    } else {
      // No card is sufficiently visible
      if (_activeCardState != null) {
        _activeCardState!._handleHoverExit();
        _activeCardState = null;
      }
      if (_pendingCardState != null) {
        _pendingCardState!._handleHoverExit();
        _pendingCardState = null;
      }
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
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'VideoCard.pauseAllMainPlayers.miniplayer');
    }
    try {
      TowerPlayerController.pauseAllActivePlayers();
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'VideoCard.pauseAllMainPlayers.tower');
    }
  }
}

@immutable
class VideoCard extends StatefulWidget {
  const VideoCard({
    required this.video,
    super.key,
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
  final Rxn<VideoPlayerController> _videoPlayerController =
      Rxn<VideoPlayerController>();
  final RxBool _isControllerInitialized = false.obs;
  final RxBool _isLoadingVideo = false.obs;
  late final Worker _muteWorker;

  static final Map<String, Map<String, String>> _channelCache = {};
  final RxString _realChannelAvatarUrl = ''.obs;
  final RxString _realChannelName = ''.obs;

  @override
  void initState() {
    super.initState();
    _realChannelAvatarUrl.value = widget.video.channelAvatarUrl;
    _realChannelName.value = widget.video.channelName;
    _loadRealChannelData();
    _muteWorker = ever(HoverPreviewCoordinator.globalMute, (isMuted) {
      if (_videoPlayerController.value != null &&
          _isControllerInitialized.value) {
        if (isMuted) {
          _videoPlayerController.value!.setVolume(0.0);
        } else {
          HoverPreviewCoordinator.pauseAllMainPlayers();
          _videoPlayerController.value!.setVolume(1.0);
        }
      }
    });
  }

  Future<void> _loadRealChannelData() async {
    if (widget.video.channelId.isEmpty) return;
    // Only query Firestore if Video model lacks avatar or name
    if (_realChannelAvatarUrl.value.isNotEmpty &&
        _realChannelName.value.isNotEmpty) {
      return;
    }

    // Check in-memory cache first
    final cached = _channelCache[widget.video.channelId];
    if (cached != null) {
      if (cached['avatar']?.isNotEmpty ?? false) {
        _realChannelAvatarUrl.value = cached['avatar']!;
      }
      if (cached['name']?.isNotEmpty ?? false) {
        _realChannelName.value = cached['name']!;
      }
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection(FirestoreCollections.channels)
          .doc(widget.video.channelId)
          .getCacheFirst();
      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          final avatar = data['avatarUrl'] as String? ?? '';
          final name = data['name'] as String? ?? '';
          if (avatar.isNotEmpty) {
            _realChannelAvatarUrl.value = avatar;
          }
          if (name.isNotEmpty) {
            _realChannelName.value = name;
          }
          _channelCache[widget.video.channelId] = {
            'avatar': avatar,
            'name': name,
          };
        }
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'VideoCard._loadRealChannelData');
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
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'VideoCard._formatTimestamp');
      return 'some time ago';
    }
  }

  @override
  void dispose() {
    _muteWorker.dispose();
    _hoverTimer?.cancel();
    HoverPreviewCoordinator.unregisterCard(this);
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
        try {
          if (controller?.value.isInitialized ?? false) {
            controller?.pause();
          }
          controller?.dispose();
        } catch (e, s) {
          ErrorHandler.log(e, stackTrace: s, tag: 'VideoCard._disposePreviewPlayer');
        }
      });
    }
  }

  Future<void> _initializePreviewPlayer() async {
    if (_videoPlayerController.value != null || _isLoadingVideo.value) return;

    _isLoadingVideo.value = true;

    var previewUrl = '';

    // 1. Try animatedPreviewUrl if valid video
    if (widget.video.animatedPreviewUrl.isNotEmpty &&
        !widget.video.animatedPreviewUrl.startsWith('gs://') &&
        (!kIsWeb || !widget.video.animatedPreviewUrl.contains('.m3u8'))) {
      previewUrl = widget.video.animatedPreviewUrl;
    }

    // 2. Check adaptiveResolutions for valid video resolutions (must have height > 0 and not be an audio track or raw file)
    if (previewUrl.isEmpty && widget.video.adaptiveResolutions.isNotEmpty) {
      final videoResolutions = widget.video.adaptiveResolutions
          .where(
            (r) =>
                r.url.trim().isNotEmpty &&
                r.height > 0 &&
                !r.label.toLowerCase().contains('audio') &&
                !r.url.toLowerCase().contains('/audio') &&
                !r.url.toLowerCase().endsWith('original.mp4') &&
                !r.url.toLowerCase().contains('/original/') &&
                (!kIsWeb || !r.url.contains('.m3u8')),
          )
          .toList();
      if (videoResolutions.isNotEmpty) {
        // Pick lowest resolution for lightweight fast-buffering preview
        final lowest = videoResolutions.reduce(
          (a, b) => a.bitrate < b.bitrate ? a : b,
        );
        previewUrl = lowest.url;
      }
    }

    // 3. Fallback to hlsUrl (if not raw file)
    if (previewUrl.isEmpty &&
        widget.video.hlsUrl.isNotEmpty &&
        !widget.video.hlsUrl.endsWith('original.mp4') &&
        !widget.video.hlsUrl.contains('/original/')) {
      previewUrl = widget.video.hlsUrl;
    }

    if (previewUrl.isEmpty) {
      _isLoadingVideo.value = false;
      return;
    }

    // Resolve gs:// and raw storage.googleapis.com references to authenticated HTTPS download URLs
    previewUrl = await StorageUtils.resolveUrl(previewUrl);

    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(previewUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _videoPlayerController.value = controller;

      await controller.initialize();

      if (mounted &&
          _isHovered.value &&
          _videoPlayerController.value == controller) {
        // Enforce single active hover player across the app unconditionally (whether muted or not)
        HoverPreviewCoordinator.setActiveCard(this);
        final isMuted = HoverPreviewCoordinator.globalMute.value;
        if (!isMuted) {
          await controller.setVolume(1.0);
        } else {
          await controller.setVolume(0.0);
        }
        await controller.setLooping(true);
        await controller.play();
        _isControllerInitialized.value = true;
        _isLoadingVideo.value = false;
      } else {
        controller.dispose();
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'VideoCard._initializePreviewPlayer');
      if (mounted) {
        _isLoadingVideo.value = false;
      }
    }
  }

  void _startHoverPlayback() {
    if (!mounted || widget.disableHoverPreview) return;
    if (_isHovered.value && _videoPlayerController.value != null) return;
    _isHovered.value = true;
    _hoverTimer?.cancel();
    _hoverTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted && _isHovered.value) {
        _initializePreviewPlayer();
      }
    });
  }

  void _handleHoverEnter() {
    if (widget.disableHoverPreview) return;
    HoverPreviewCoordinator.setActiveCard(this);
    _startHoverPlayback();
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
    if (kIsWeb) return;
    final isMobile =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    if (!isMobile) return;

    HoverPreviewCoordinator.reportMobileVisibility(this, visibleFraction);
  }

  void _handleTap(BuildContext context) {
    DeepLinkService.instance.cacheVideo(widget.video);
    final controller = _videoPlayerController.value;
    Duration? resumePos;

    if (controller != null && _isControllerInitialized.value) {
      final pos = controller.value.position;
      if (pos > Duration.zero) {
        resumePos = pos;
        VideoPlaybackHandoff.registerResumePosition(widget.video.id, pos);
      }
      if (!kIsWeb) {
        VideoPlaybackHandoff.registerActiveController(
          widget.video.id,
          controller,
          position: pos,
        );
      } else {
        // On web, dispose local preview controller to free up DOM elements
        try {
          controller.dispose();
        } catch (e, s) {
          ErrorHandler.log(e, stackTrace: s, tag: 'VideoCard._handleTap.disposeWeb');
        }
      }
      _videoPlayerController.value = null;
      _isControllerInitialized.value = false;
      _isLoadingVideo.value = false;
    } else {
      VideoPlaybackHandoff.prewarmVideo(widget.video);
    }

    if (widget.onTap != null) {
      widget.onTap!();
    } else {
      MiniplayerNavigationHelper.navigateToVideoScreen(
        video: widget.video,
        resumePosition: resumePos,
        routeArguments: {
          'video': widget.video,
          'heroTag': '${widget.heroPrefix}_${widget.video.id}',
          'resumePosition': ?resumePos,
          'initialPosition': ?resumePos,
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!VideoVisibilityPolicy.isValidVideo(widget.video)) {
      return const SizedBox.shrink();
    }
    if (Get.isRegistered<UserPreferencesService>() &&
        UserPreferencesService.to.isVideoBlocked(widget.video)) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final hovered = _isHovered.value;

    final cardContent = MouseRegion(
      onEnter: (_) => _handleHoverEnter(),
      onExit: (_) => _handleHoverExit(),
      child: Semantics(
        button: true,
        enabled: true,
        label: 'Video: ${widget.video.title} by ${widget.video.channelName}',
        onTap: () => _handleTap(context),
        child: AnimatedScale(
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
                borderRadius: widget.isGrid
                    ? BorderRadius.circular(16)
                    : null,
                child: widget.isGrid
                    ? _buildGridContent(context, theme)
                    : _buildListContent(context, theme),
              ),
            ),
          ),
        ),
      ),
    );

    if (kIsWeb) {
      return cardContent;
    }

    return VisibilityDetector(
      key: Key('video_card_${widget.video.id}_${widget.heroPrefix}'),
      onVisibilityChanged: (info) {
        if (mounted) {
          _handleVisibilityChanged(info.visibleFraction);
        }
      },
      child: cardContent,
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
              child: _buildGridVideoThumbnail(
                context,
                theme,
                borderRadius: BorderRadius.circular(8),
              ),
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

  Widget _buildGridVideoThumbnail(
    BuildContext context,
    ThemeData theme, {
    BorderRadius? borderRadius,
  }) {
    final effectiveBorderRadius =
        borderRadius ?? const BorderRadius.vertical(top: Radius.circular(16));

    return Hero(
      tag: '${widget.heroPrefix}_${widget.video.id}',
      child: ClipRRect(
        borderRadius: effectiveBorderRadius,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Obx(() {
            final isInitialized = _isControllerInitialized.value;
            final controller = _videoPlayerController.value;
            final hovered = _isHovered.value;
            final isSaved = Get.isRegistered<PlaylistController>() &&
                Get.find<PlaylistController>().isInWatchLater(widget.video.id);

            return GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => _handleTap(context),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (isInitialized && controller != null)
                    IgnorePointer(
                      child: ClipRect(
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: controller.value.size.width > 0
                                ? controller.value.size.width
                                : 160,
                            height: controller.value.size.height > 0
                                ? controller.value.size.height
                                : 90,
                            child: MobileFriendlyVideoPlayer(
                              controller: controller,
                              looping: true,
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    CachedNetworkImage(
                      imageUrl: widget.video.thumbnailUrl,
                      fit: BoxFit.cover,
                      memCacheWidth: 720,
                      maxWidthDiskCache: 720,
                      placeholder: (context, url) =>
                          _buildThumbnailShimmer(theme),
                      errorWidget: (context, url, error) =>
                          _buildThumbnailError(theme),
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
                  if (widget.video.isFactChecked)
                    Positioned(
                      top: AppTheme.spacing.xs,
                      left: AppTheme.spacing.xs,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppTheme.spacing.xs * 1.5,
                          vertical: AppTheme.spacing.xs / 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF10B981,
                          ).withValues(alpha: 0.95), // Emerald green
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
                            ),
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
                  // Duration badge
                  if (!isInitialized)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
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
                  // Audio toggle button when hover preview is active
                  if (isInitialized)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Obx(() {
                        final isMuted = HoverPreviewCoordinator.globalMute.value;
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () async {
                            final newMute =
                                !HoverPreviewCoordinator.globalMute.value;
                            HoverPreviewCoordinator.globalMute.value = newMute;
                            if (newMute) {
                              await _videoPlayerController.value
                                  ?.setVolume(0.0);
                            } else {
                              HoverPreviewCoordinator.pauseAllMainPlayers();
                              await _videoPlayerController.value
                                  ?.setVolume(1.0);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.bgPage.withValues(alpha: 0.8),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.textPrimary
                                    .withValues(alpha: 0.2),
                                width: 0.5,
                              ),
                            ),
                            child: Icon(
                              isMuted
                                  ? Icons.volume_off_rounded
                                  : Icons.volume_up_rounded,
                              color: AppColors.textPrimary,
                              size: 16,
                            ),
                          ),
                        );
                      }),
                    ),
                  // Watch Later and Add to Queue overlay icons when hovered (Truthworld style)
                  if (hovered)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildHoverActionIconButton(
                            icon: isSaved
                                ? Icons.check_circle_rounded
                                : Icons.watch_later_outlined,
                            tooltip: isSaved
                                ? 'Saved to Watch Later'
                                : 'Watch later',
                            onTap: () {
                              showModernizedPlaylistDialog(
                                context: context,
                                videoId: widget.video.id,
                              );
                            },
                          ),
                          const SizedBox(height: 6),
                          _buildHoverActionIconButton(
                            icon: Icons.playlist_add_rounded,
                            tooltip: 'Add to queue',
                            onTap: () {
                              AppSnackbar.show(
                                'Added to queue',
                                "'${widget.video.title}' has been added to your play queue.",
                                snackPosition: SnackPosition.BOTTOM,
                                backgroundColor: AppColors.bgSurfaceHover,
                                colorText: AppColors.textPrimary,
                                margin: const EdgeInsets.all(20),
                                borderRadius: 16,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  // Watch progress bar (Truthworld style)
                  Obx(() {
                    final progress =
                        WatchHistoryService.to.getProgress(widget.video.id);
                    if (progress <= 0) return const SizedBox.shrink();
                    return Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
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
                      ),
                    );
                  }),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildGridVideoInfo(BuildContext context, ThemeData theme) {
    return Obx(() {
      final avatarUrl = _realChannelAvatarUrl.value;
      final channelName = _realChannelName.value;

      return Padding(
        padding: const EdgeInsets.only(left: 10, right: 10, top: 10, bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ModernAvatar(
              imageUrl: avatarUrl,
              radius: 16,
              placeholderText: channelName.isEmpty
                  ? '?'
                  : channelName.substring(0, 1).toUpperCase(),
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
                    '$channelName · ${_formatViews(widget.video.views)} views · ${_formatTimestamp(widget.video.uploadedAt)}',
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
              icon: const Icon(
                Icons.more_vert,
                size: 18,
                color: AppColors.textPrimary,
              ),
              onPressed: () => VideoOptionsSheet.show(context, widget.video),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildListVideoInfo(BuildContext context, ThemeData theme) {
    return Obx(() {
      final avatarUrl = _realChannelAvatarUrl.value;
      final channelName = _realChannelName.value;

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
                        imageUrl: avatarUrl,
                        radius: 10,
                        placeholderText: channelName.isEmpty
                            ? '?'
                            : channelName.substring(0, 1).toUpperCase(),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          channelName,
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
              icon: const Icon(
                Icons.more_vert,
                size: 18,
                color: AppColors.textPrimary,
              ),
              onPressed: () => VideoOptionsSheet.show(context, widget.video),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildThumbnailShimmer(ThemeData theme) {
    return Shimmer.fromColors(
      baseColor: theme.colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.3,
      ),
      highlightColor: theme.colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.1,
      ),
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
