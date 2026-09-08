import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/video_card.dart';
import 'package:truthworld/core/utils/storage_utils.dart';
import 'package:truthworld/core/widgets/mobile_friendly_video_player.dart';
import 'package:truthworld/features/miniplayer/presentation/utils/miniplayer_utils.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/video_playback_handoff.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:video_player/video_player.dart';

/// A premium, Truthworld-style hover-to-play video preview card.
///
/// Features:
/// - 600ms hover debounce to optimize bandwidth and maintain sub-150ms scrolling.
/// - Loop-playback muted, perfectly fitted (cover fit) within the thumbnail area.
/// - Truthworld-style muted volume indicator overlay.
/// - Seamless zero-latency warm-handover on tap.
class HoverVideoPlayer extends StatefulWidget {
  // Previews start muted by default

  const HoverVideoPlayer({
    required this.video,
    required this.thumbnail,
    required this.borderRadius,
    this.onTap,
    super.key,
  });
  final Video video;
  final Widget thumbnail;
  final BorderRadius borderRadius;
  final VoidCallback? onTap;

  static bool isGlobalMuted = true;

  @override
  State<HoverVideoPlayer> createState() => _HoverVideoPlayerState();
}

class _HoverVideoPlayerState extends State<HoverVideoPlayer> {
  final _controller = Rxn<VideoPlayerController>();
  Timer? _hoverTimer;
  final RxBool _isHovered = false.obs;
  final RxBool _isLoading = false.obs;
  final RxBool _isInitialized = false.obs;
  final RxBool _isMuted = HoverVideoPlayer.isGlobalMuted.obs;
  final _position = Rx<Duration>(Duration.zero);
  final _duration = Rx<Duration>(Duration.zero);

  @override
  void dispose() {
    _hoverTimer?.cancel();

    // warm handover: only dispose if the controller has NOT been handed over
    // to the Watch Screen already (i.e. it is still active/registered in the handoff)
    if (_controller.value != null) {
      final videoId = widget.video.id;
      if (VideoPlaybackHandoff.isActive(videoId)) {
        VideoPlaybackHandoff.clear(videoId);
      }
    }
    super.dispose();
  }

  void _onEnter() {
    if (widget.video.isScheduled) {
      return; // Do not hover play scheduled premieres
    }
    if (HoverPreviewCoordinator.isMainVideoMuted()) {
      return; // Suppress hover preview if active video is muted
    }

    _isHovered.value = true;

    _hoverTimer?.cancel();
    _hoverTimer = Timer(const Duration(milliseconds: 600), () {
      if (_isHovered.value) {
        if (HoverPreviewCoordinator.isMainVideoMuted()) {
          _isHovered.value = false;
          return;
        }
        _initializePlayer();
      }
    });
  }

  void _onExit() {
    _hoverTimer?.cancel();

    final videoId = widget.video.id;
    if (_controller.value != null) {
      final oldController = _controller.value;
      if (VideoPlaybackHandoff.isActive(videoId)) {
        VideoPlaybackHandoff.clear(videoId);
      } else {
        try {
          oldController?.pause();
          oldController?.dispose();
        } catch (e) {
          debugPrint('[HoverVideoPlayer] Error disposing player on exit: $e');
        }
      }
    }

    _isHovered.value = false;
    _isLoading.value = false;
    _controller.value = null;
    _isInitialized.value = false;
    _position.value = Duration.zero;
    _duration.value = Duration.zero;
  }

  Future<void> _initializePlayer() async {
    if (HoverPreviewCoordinator.isMainVideoMuted()) {
      _isLoading.value = false;
      _isHovered.value = false;
      return;
    }

    var playUrl = '';

    // 1. Pick from adaptiveResolutions
    if (widget.video.adaptiveResolutions.isNotEmpty) {
      final validResolutions = widget.video.adaptiveResolutions.where((r) {
        final u = r.url.trim().toLowerCase();
        final l = r.label.toLowerCase();
        return u.isNotEmpty &&
            !l.contains('audio') &&
            !u.contains('/audio') &&
            !u.endsWith('original.mp4') &&
            !u.contains('/original/') &&
            (!kIsWeb || !u.contains('.m3u8'));
      }).toList();

      if (validResolutions.isNotEmpty) {
        final lowest = validResolutions.reduce(
          (a, b) => a.bitrate < b.bitrate ? a : b,
        );
        playUrl = lowest.url;
      }
    }

    // 2. Fallback to hlsUrl (if non-web or supported)
    if (playUrl.isEmpty &&
        widget.video.hlsUrl.isNotEmpty &&
        !widget.video.hlsUrl.endsWith('original.mp4') &&
        !widget.video.hlsUrl.contains('/original/')) {
      playUrl = widget.video.hlsUrl;
    }

    if (playUrl.isEmpty) {
      _isLoading.value = false;
      _isHovered.value = false;
      return;
    }

    _isLoading.value = true;
    _isMuted.value = true;

    try {
      await _attemptInitWithUrl(playUrl);
    } catch (e) {
      debugPrint(
        '[HoverVideoPlayer] Error initializing preview player with primary URL ($playUrl): $e',
      );
      _isLoading.value = false;
      _isInitialized.value = false;
    }
  }

  Future<void> _attemptInitWithUrl(String url) async {
    final resolvedUrl = await StorageUtils.resolveUrl(url);
    if (resolvedUrl.isEmpty) throw Exception('Empty URL');

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(resolvedUrl),
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: true, // Allow other audio to play
      ),
    );

    await controller.initialize();
    await controller.setVolume(0.0);
    await controller.setLooping(true);

    if (_isHovered.value && !HoverPreviewCoordinator.isMainVideoMuted()) {
      _controller.value = controller;
      _isInitialized.value = true;
      _isLoading.value = false;
      _duration.value = controller.value.duration;
      _position.value = controller.value.position;

      controller.addListener(() {
        if (_controller.value == controller) {
          _position.value = controller.value.position;
        }
      });

      // Register this controller globally for warm handover on tap (native only)
      if (!kIsWeb) {
        VideoPlaybackHandoff.registerActiveController(
          widget.video.id,
          controller,
        );
      }

      await controller.play();
    } else {
      // User exited hover while initializing, clean up
      await controller.dispose();
      _isLoading.value = false;
    }
  }

  Future<void> _toggleMute() async {
    final nextMute = !_isMuted.value;
    _isMuted.value = nextMute;
    HoverVideoPlayer.isGlobalMuted = nextMute;
    if (nextMute) {
      await _controller.value?.setVolume(0.0);
    } else {
      HoverPreviewCoordinator.pauseAllMainPlayers();
      await _controller.value?.setVolume(1.0);
    }
  }

  void _handleTap() {
    final controller = _controller.value;
    Duration? resumePos;

    if (controller != null && _isInitialized.value) {
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
        } catch (_) {}
      }
      _controller.value = null;
      _isInitialized.value = false;
      _isLoading.value = false;
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
          'heroTag': 'hover_${widget.video.id}',
          if (resumePos != null) 'resumePosition': resumePos,
          if (resumePos != null) 'initialPosition': resumePos,
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // If the controller has been retrieved or cleared elsewhere (e.g., warm handover completed),
    // we must immediately release our local reference to avoid any memory leaks or disposed access.
    if (_controller.value != null &&
        !VideoPlaybackHandoff.isActive(widget.video.id)) {
      _controller.value = null;
      _isInitialized.value = false;
      _isLoading.value = false;
    }

    return Obx(
      () => MouseRegion(
        onEnter: (_) => _onEnter(),
        onExit: (_) => _onExit(),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _handleTap,
          child: ClipRRect(
            borderRadius: widget.borderRadius,
            child: Stack(
              children: [
                // Always show/render the thumbnail under the video player so transitions are flawless
                widget.thumbnail,

                // Buffering Shimmer overlay
                if (_isLoading.value)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Colors.black45,
                      child: Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Muted video preview player
                if (_isInitialized.value && _controller.value != null)
                  Positioned.fill(
                    child: ColoredBox(
                      color: AppColors.bgPage,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          IgnorePointer(
                            child: FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: _controller.value!.value.size.width > 0
                                    ? _controller.value!.value.size.width
                                    : 160,
                                height: _controller.value!.value.size.height > 0
                                    ? _controller.value!.value.size.height
                                    : 90,
                                child: MobileFriendlyVideoPlayer(
                                  controller: _controller.value!,
                                  looping: true,
                                ),
                              ),
                            ),
                          ),

                          // Brain / AI icon overlay in top left
                          Positioned(
                            top: 12,
                            left: 12,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF0B1428,
                                ), // Premium dark blue
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.textDisabled,
                              ),
                            ),
                            child: const Icon(
                              Icons.psychology_rounded,
                              color: AppColors.textPrimary,
                              size: 16,
                            ),
                          ),
                        ),

                        // Premium interactive controls overlay in top right (Mute & CC stacked vertically)
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: _toggleMute,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.bgPage.withValues(
                                      alpha: 0.75,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: AppColors.bgDivider,
                                      width: 0.5,
                                    ),
                                  ),
                                  child: Obx(
                                    () => Icon(
                                      _isMuted.value
                                          ? Icons.volume_off_rounded
                                          : Icons.volume_up_rounded,
                                      color: AppColors.textPrimary,
                                      size: 14,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.bgPage.withValues(
                                    alpha: 0.75,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: AppColors.bgDivider,
                                    width: 0.5,
                                  ),
                                ),
                                child: const Text(
                                  'CC',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Current playback time display in bottom left
                        Positioned(
                          bottom: 16,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.bgPage54,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Obx(() {
                              final elapsed = _formatDuration(_position.value);
                              return Text(
                                elapsed,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            }),
                          ),
                        ),

                        // Progress Bar at the very bottom
                        Positioned(
                          bottom: 4,
                          left: 8,
                          right: 8,
                          child: _buildProgressBar(),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
  }

  Widget _buildProgressBar() {
    return Obx(() {
      final pos = _position.value.inMilliseconds;
      final dur = _duration.value.inMilliseconds;
      if (dur == 0) return const SizedBox.shrink();
      final factor = (pos / dur).clamp(0.0, 1.0);

      return LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final thumbPosition = factor * width;

          void seekToPosition(Offset localPosition) {
            if (width <= 0 || _controller.value == null) return;
            final targetRatio = (localPosition.dx / width).clamp(0.0, 1.0);
            final targetMs = (targetRatio * dur).round();
            _controller.value!.seekTo(Duration(milliseconds: targetMs));
            _position.value = Duration(milliseconds: targetMs);
          }

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) => seekToPosition(details.localPosition),
            onHorizontalDragStart: (details) =>
                seekToPosition(details.localPosition),
            onHorizontalDragUpdate: (details) =>
                seekToPosition(details.localPosition),
            child: SizedBox(
              height: 24,
              width: double.infinity,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.centerLeft,
                children: [
                  // Track Background
                  Container(
                    height: 4,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.textDisabled.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Active Progress
                  Container(
                    height: 4,
                    width: thumbPosition,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF0000),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Thumb Dot
                  Positioned(
                    left: (thumbPosition - 6).clamp(0.0, width - 12),
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF0000),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black38,
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    });
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString();
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
