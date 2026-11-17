import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audio_tracks_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks/audio_tracks_dialogs.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks/multilingual_studio_video_player.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Production Fullscreen Video Player for Creator Studio.
///
/// Features:
///   • 100% immersive black viewport adapting to video aspect ratio.
///   • Floating language switcher pills for seamless in-player audio switching.
///   • Auto-hiding high-contrast top bar (title, back, exit) and bottom bar (scrubber,
///     play/pause, live timestamps, volume, resolutions, + Audio, Download, fullscreen toggle).
///   • Full desktop and web keyboard navigation (Space, K, J, L, M, F, Escape).
///   • Zero white-on-white accessibility compliance.
///   • Zero setState declarative GetX architecture.
class MultilingualStudioFullscreenView extends StatelessWidget {
  const MultilingualStudioFullscreenView({
    required this.video,
    required this.playerCtrl,
    required this.tracksController,
    required this.isDarkMode,
    this.onAddDubTrack,
    super.key,
  });

  final Video video;
  final MultilingualStudioPlayerController playerCtrl;
  final AudioTracksController tracksController;
  final bool isDarkMode;
  final VoidCallback? onAddDubTrack;

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    final sStr = s < 10 ? '0$s' : '$s';
    return '$m:$sStr';
  }

  KeyEventResult _handleKeyEvent(BuildContext context, FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.keyF ||
        event.logicalKey == LogicalKeyboardKey.escape) {
      playerCtrl.exitFullscreen(context);
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.space ||
        event.logicalKey == LogicalKeyboardKey.keyK) {
      playerCtrl.flashControls();
      if (playerCtrl.isPlaying.value) {
        playerCtrl.pause();
      } else {
        playerCtrl.play();
      }
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.keyJ ||
        event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      playerCtrl.flashControls();
      final newPos = playerCtrl.position.value - const Duration(seconds: 5);
      playerCtrl.seekTo(newPos < Duration.zero ? Duration.zero : newPos);
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.keyL ||
        event.logicalKey == LogicalKeyboardKey.arrowRight) {
      playerCtrl.flashControls();
      final dur = playerCtrl.duration.value;
      final newPos = playerCtrl.position.value + const Duration(seconds: 5);
      playerCtrl.seekTo(newPos > dur ? dur : newPos);
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.keyM) {
      playerCtrl.flashControls();
      playerCtrl.toggleMute();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final videoVal = playerCtrl.videoController?.value;
    final isInitialized = videoVal != null && videoVal.isInitialized;
    final rawRatio = (isInitialized && (videoVal.aspectRatio > 0))
        ? videoVal.aspectRatio
        : 16 / 9;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        playerCtrl.exitFullscreen(context, popRoute: false);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Focus(
          autofocus: true,
          onKeyEvent: (node, event) => _handleKeyEvent(context, node, event),
          child: MouseRegion(
            onHover: (_) => playerCtrl.flashControls(),
            child: GestureDetector(
              onTap: playerCtrl.flashControls,
              behavior: HitTestBehavior.opaque,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // ── 1. Centered Video Surface ─────────────────────────────
                  Center(
                    child: AspectRatio(
                      aspectRatio: rawRatio,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Chewie video player
                          if (playerCtrl.chewieController != null)
                            GestureDetector(
                              onTap: () {
                                playerCtrl.flashControls();
                                if (playerCtrl.isPlaying.value) {
                                  playerCtrl.pause();
                                } else {
                                  playerCtrl.play();
                                }
                              },
                              onDoubleTap: () => playerCtrl.exitFullscreen(context),
                              child: Chewie(controller: playerCtrl.chewieController!),
                            )
                          else
                            const ColoredBox(
                              color: Colors.black,
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                            ),

                          // Track / resolution switching overlay spinner
                          Obx(() {
                            final isChanging = playerCtrl.isChangingTrack.value ||
                                playerCtrl.isSwitchingResolution.value;
                            if (!isChanging) return const SizedBox.shrink();

                            return const ColoredBox(
                              color: Colors.black54,
                              child: Center(
                                child: SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                              ),
                            );
                          }),

                          // Floating Multi-Language Switcher Pills
                          Positioned(
                            bottom: 12,
                            left: 12,
                            right: 12,
                            child: Center(
                              child: Obx(() {
                                tracksController.generatingDubLanguages.length;
                                tracksController.dubbingProgress.length;
                                tracksController.isUploading.value;
                                tracksController.uploadingLanguageCode.value;
                                tracksController.uploadProgress.value;

                                final availableTracks =
                                    MultilingualStudioPlayerController.buildTrackOptions(
                                  video: video,
                                  tracksController: tracksController,
                                );
                                final activeLangCode = tracksController.selectedLanguage.value;
                                final activeTrack = playerCtrl.selectedTrack.value;

                                if (availableTracks.isEmpty) {
                                  return const SizedBox.shrink();
                                }

                                return SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      for (int i = 0; i < availableTracks.length; i++) ...[
                                        if (i > 0) const SizedBox(width: 8),
                                        MultilingualStudioVideoPlayer.buildLanguagePillWidget(
                                          controller: tracksController,
                                          track: availableTracks[i],
                                          isActive: (activeTrack?.code == availableTracks[i].code) ||
                                              (activeTrack == null &&
                                                  availableTracks[i].code == activeLangCode),
                                          onTap: () {
                                            if (tracksController.generatingDubLanguages.contains(availableTracks[i].code.trim().toLowerCase())) {
                                              AudioTracksDialogs.showDubbingProgressModal(
                                                context: context,
                                                controller: tracksController,
                                                langCode: availableTracks[i].code,
                                                isDarkMode: isDarkMode,
                                              );
                                            } else {
                                              playerCtrl.switchTrack(availableTracks[i]).then((_) {
                                                if (playerCtrl.selectedTrack.value != null) {
                                                  tracksController.selectedLanguage.value =
                                                      playerCtrl.selectedTrack.value!.code;
                                                }
                                              });
                                            }
                                          },
                                        ),
                                      ],
                                      if (onAddDubTrack != null) ...[
                                        const SizedBox(width: 8),
                                        MultilingualStudioVideoPlayer.buildAddLanguagePillWidget(
                                          onTap: onAddDubTrack!,
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              }),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── 2. Top Bar Overlay (Title & Exit Fullscreen) ────────────
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Obx(() {
                      final visible = playerCtrl.showControls.value ||
                          !playerCtrl.isPlaying.value;

                      return AnimatedOpacity(
                        opacity: visible ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: IgnorePointer(
                          ignoring: !visible,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.black87, Colors.transparent],
                              ),
                            ),
                            child: SafeArea(
                              bottom: false,
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.arrow_back_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                    tooltip: 'Exit fullscreen',
                                    onPressed: () => playerCtrl.exitFullscreen(context),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      video.title.isNotEmpty
                                          ? video.title
                                          : 'Video Preview',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.fullscreen_exit_rounded,
                                      color: Colors.white,
                                      size: 26,
                                    ),
                                    tooltip: 'Exit fullscreen (f)',
                                    onPressed: () => playerCtrl.exitFullscreen(context),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),

                  // ── 3. Bottom Bar Overlay (Controls, Resolutions & Actions) ──
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Obx(() {
                      final visible = playerCtrl.showControls.value ||
                          !playerCtrl.isPlaying.value;

                      return AnimatedOpacity(
                        opacity: visible ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: IgnorePointer(
                          ignoring: !visible,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [Colors.black87, Colors.transparent],
                              ),
                            ),
                            child: SafeArea(
                              top: false,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Scrubber Slider
                                  _buildScrubberBar(context),

                                  const SizedBox(height: 8),

                                  // Actions Row: Play/Pause, Timestamps, Volume, Resolutions, + Audio, Download, Fullscreen Exit
                                  _buildBottomActionsRow(context),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SCRUBBER BAR
  // ---------------------------------------------------------------------------
  Widget _buildScrubberBar(BuildContext context) {
    return Obx(() {
      final pos = playerCtrl.position.value;
      final dur = playerCtrl.duration.value > Duration.zero
          ? playerCtrl.duration.value
          : (video.durationValue > Duration.zero
              ? video.durationValue
              : const Duration(seconds: 15));

      final maxMs = dur.inMilliseconds > 0 ? dur.inMilliseconds.toDouble() : 1.0;
      final currentMs = pos.inMilliseconds.clamp(0, maxMs.toInt()).toDouble();

      return SliderTheme(
        data: SliderTheme.of(context).copyWith(
          thumbColor: Colors.white,
          activeTrackColor: Colors.white,
          inactiveTrackColor: Colors.white24,
          trackHeight: 3.5,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        ),
        child: Slider(
          value: currentMs.clamp(0.0, maxMs),
          max: maxMs,
          onChanged: (val) {
            playerCtrl.flashControls();
            playerCtrl.seekTo(Duration(milliseconds: val.toInt()));
          },
        ),
      );
    });
  }

  // ---------------------------------------------------------------------------
  // BOTTOM CONTROLS & ACTIONS ROW
  // ---------------------------------------------------------------------------
  Widget _buildBottomActionsRow(BuildContext context) {
    return Obx(() {
      final isPlaying = playerCtrl.isPlaying.value;
      final pos = playerCtrl.position.value;
      final isMuted = playerCtrl.isMuted.value;
      final dur = playerCtrl.duration.value > Duration.zero
          ? playerCtrl.duration.value
          : (video.durationValue > Duration.zero
              ? video.durationValue
              : const Duration(seconds: 15));
      final resList = playerCtrl.availableResolutions;
      final currentRes = playerCtrl.currentResolution.value;
      final isDownloading = playerCtrl.isDownloading.value;

      return Row(
        children: [
          // Play / Pause toggle
          IconButton(
            icon: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 28,
            ),
            onPressed: () {
              playerCtrl.flashControls();
              if (isPlaying) {
                playerCtrl.pause();
              } else {
                playerCtrl.play();
              }
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),

          const SizedBox(width: 6),

          // Duration / Timestamp Display
          Text(
            _formatDuration(pos) == '0:00'
                ? _formatDuration(dur)
                : '${_formatDuration(pos)} / ${_formatDuration(dur)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(width: 8),

          // Volume / Mute
          IconButton(
            icon: Icon(
              isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              color: Colors.white,
              size: 22,
            ),
            onPressed: () {
              playerCtrl.flashControls();
              playerCtrl.toggleMute();
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
          ),

          const Spacer(),

          // Resolutions Chips
          if (resList.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: resList.map((res) {
                  final isSelected =
                      currentRes?.label == res.label || currentRes?.url == res.url;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: InkWell(
                      onTap: () {
                        playerCtrl.flashControls();
                        playerCtrl.switchResolution(res);
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          res.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? Colors.black : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(width: 10),
          ],

          // + Audio action button
          if (onAddDubTrack != null) ...[
            ElevatedButton.icon(
              onPressed: () {
                playerCtrl.flashControls();
                onAddDubTrack!();
              },
              icon: const Icon(
                Icons.add_rounded,
                size: 16,
                color: Colors.black,
              ),
              label: const Text(
                'Audio',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Download action button
          ElevatedButton.icon(
            onPressed: isDownloading
                ? null
                : () {
                    playerCtrl.flashControls();
                    playerCtrl.downloadVideoWithWantedTrack(
                      context: context,
                      video: video,
                      tracksController: tracksController,
                    );
                  },
            icon: isDownloading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                    ),
                  )
                : const Icon(
                    Icons.download_rounded,
                    size: 16,
                    color: Colors.black,
                  ),
            label: Text(
              isDownloading ? 'Downloading...' : 'Download',
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Exit Fullscreen Button
          IconButton(
            icon: const Icon(
              Icons.fullscreen_exit_rounded,
              color: Colors.white,
              size: 26,
            ),
            tooltip: 'Exit fullscreen (f)',
            onPressed: () => playerCtrl.exitFullscreen(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      );
    });
  }
}
