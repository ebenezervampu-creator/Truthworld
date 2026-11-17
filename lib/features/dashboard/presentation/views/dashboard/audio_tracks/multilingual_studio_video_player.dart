import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audio_tracks_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/multi_audio_player_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks/audio_tracks_dialogs.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks/dubbing_segment_editor_page.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Studio Multi-Language Video Player & Dubbing Coordinator Card.
/// Enables creators to preview multiple dubbed languages in real time in a synchronized
/// video player, switch languages via floating overlay pills, scrub seamlessly, and
/// download the video with the desired language audio track.
class MultilingualStudioVideoPlayer extends StatelessWidget {
  const MultilingualStudioVideoPlayer({
    required this.video,
    required this.controller,
    required this.isDarkMode,
    this.surfaceColor,
    this.borderColor,
    this.onAddDubTrack,
    super.key,
  });

  final Video video;
  final AudioTracksController controller;
  final bool isDarkMode;
  final Color? surfaceColor;
  final Color? borderColor;
  final VoidCallback? onAddDubTrack;

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    final sStr = s < 10 ? '0$s' : '$s';
    return '$m:$sStr';
  }

  @override
  Widget build(BuildContext context) {
    final tag = 'studio_multilingual_${video.id}';
    final playerCtrl = Get.isRegistered<MultilingualStudioPlayerController>(tag: tag)
        ? Get.find<MultilingualStudioPlayerController>(tag: tag)
        : Get.put(MultilingualStudioPlayerController(), tag: tag);

    // Sync in post-frame callback to avoid mutating observables during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!playerCtrl.isClosed) {
        playerCtrl.syncWithVideoAndTracks(
          video: video,
          tracksController: controller,
        );
      }
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: EdgeInsets.all(isNarrow ? 12 : 16),
          decoration: BoxDecoration(
            color: surfaceColor ?? AppColors.appBarSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor ?? AppColors.bgSurface),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. Centered Video Viewport with Floating Language Pills ──
              _buildVideoViewport(context, playerCtrl, isNarrow),

              const SizedBox(height: 6),

              // ── Scrubber & Live Timestamp Bar ──
              _buildScrubberBar(context, playerCtrl),

              const SizedBox(height: 8),

              // ── 2. Resolution Selection Ladder Bar (Processed Non-Raw Streams Only) ──
              _buildResolutionBar(context, playerCtrl),

              const SizedBox(height: 12),

              // ── 3. High-Contrast Actions Row (+ Audio before Download) ──
              _buildActionRow(context, playerCtrl, isNarrow),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // VIDEO VIEWPORT WITH FLOATING LANGUAGE PILLS
  // ---------------------------------------------------------------------------
  Widget _buildVideoViewport(
    BuildContext context,
    MultilingualStudioPlayerController playerCtrl,
    bool isNarrow,
  ) {
    final videoVal = playerCtrl.videoController?.value;
    final isInitialized = videoVal != null && videoVal.isInitialized;
    final rawRatio = (isInitialized && (videoVal.aspectRatio > 0))
        ? videoVal.aspectRatio
        : 16 / 9;
    final isPortrait = rawRatio < 0.95;
    final effectiveRatio = isPortrait
        ? rawRatio.clamp(9 / 16, 4 / 5)
        : rawRatio.clamp(4 / 3, 16 / 9);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        color: Colors.black,
        width: double.infinity,
        constraints: BoxConstraints(
          maxHeight: isPortrait
              ? (isNarrow ? 360 : 420)
              : (isNarrow ? 240 : 340),
          minHeight: isPortrait
              ? (isNarrow ? 220 : 260)
              : (isNarrow ? 180 : 220),
        ),
        child: Center(
          child: AspectRatio(
            aspectRatio: effectiveRatio,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 1. Video Player Surface / Thumbnail Fallback
                  Obx(() {
                    if (playerCtrl.isFullscreen.value) {
                      return const ColoredBox(
                        color: Colors.black,
                        child: Center(
                          child: Icon(
                            Icons.fullscreen_rounded,
                            color: Colors.white24,
                            size: 48,
                          ),
                        ),
                      );
                    }

                    final hasError = playerCtrl.hasError.value;
                    final isInit = playerCtrl.isInitializing.value;
                    final hasVideo = playerCtrl.videoController != null &&
                        playerCtrl.chewieController != null &&
                        !hasError &&
                        !isInit;

                    if (hasVideo) {
                      return GestureDetector(
                        onTap: () {
                          if (playerCtrl.isPlaying.value) {
                            playerCtrl.pause();
                          } else {
                            playerCtrl.play();
                          }
                        },
                        onDoubleTap: () => playerCtrl.toggleFullscreen(
                          context,
                          video: video,
                          tracksController: controller,
                          onAddDubTrack: onAddDubTrack,
                        ),
                        child: Chewie(controller: playerCtrl.chewieController!),
                      );
                    }

                    if (hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.video_settings_rounded,
                                color: Colors.white70,
                                size: 36,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                playerCtrl.rxErrorMessage.value.isNotEmpty
                                    ? playerCtrl.rxErrorMessage.value
                                    : 'No processed video resolutions found. Transcoding in progress.',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: () => playerCtrl.syncWithVideoAndTracks(
                                  video: video,
                                  tracksController: controller,
                                  forceRefresh: true,
                                ),
                                icon: const Icon(Icons.refresh_rounded, color: Colors.black, size: 16),
                                label: const Text(
                                  'Retry',
                                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    // Placeholder / Thumbnail when initializing or in preview mode
                    if (video.thumbnailUrl.isNotEmpty) {
                      return GestureDetector(
                        onTap: () => playerCtrl.play(),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CachedNetworkImage(
                              imageUrl: video.thumbnailUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, _) => const ColoredBox(color: Colors.black),
                              errorWidget: (_, _, _) => const ColoredBox(color: Colors.black),
                            ),
                            const ColoredBox(color: Colors.black38),
                          ],
                        ),
                      );
                    }

                    return GestureDetector(
                      onTap: () => playerCtrl.play(),
                      child: const ColoredBox(
                        color: Colors.black,
                        child: Center(
                          child: Icon(
                            Icons.movie_creation_outlined,
                            color: Colors.white24,
                            size: 48,
                          ),
                        ),
                      ),
                    );
                  }),

                  // 2. Full Video Stream Changing Overlay Spinner (Resolutions or pre-rendered video MP4s only)
                  Obx(() {
                    final isChanging = playerCtrl.isSwitchingResolution.value ||
                        (playerCtrl.isChangingTrack.value &&
                            playerCtrl.selectedTrack.value?.videoUrl != null &&
                            playerCtrl.selectedTrack.value!.videoUrl!.isNotEmpty);
                    if (!isChanging) return const SizedBox.shrink();

                    return const ColoredBox(
                      color: Colors.black54,
                      child: Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      ),
                    );
                  }),

                  // 3. Floating Multi-Language Switcher Pills (Horizontal single-row)
                  Positioned(
                    bottom: 10,
                    left: 8,
                    right: 8,
                    child: Center(
                      child: Obx(() {
                        // Register reactive listeners for generating & uploading progress
                        controller.generatingDubLanguages.length;
                        controller.dubbingProgress.length;
                        controller.isUploading.value;
                        controller.uploadingLanguageCode.value;
                        controller.uploadProgress.value;

                        final availableTracks = MultilingualStudioPlayerController.buildTrackOptions(
                          video: video,
                          tracksController: controller,
                        );
                        final activeLangCode = controller.selectedLanguage.value;
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
                                if (i > 0) const SizedBox(width: 6),
                                _buildLanguagePill(
                                  track: availableTracks[i],
                                  isActive: (activeTrack?.code == availableTracks[i].code) ||
                                      (activeTrack == null && availableTracks[i].code == activeLangCode),
                                  onTap: () {
                                    if (controller.generatingDubLanguages.contains(availableTracks[i].code.trim().toLowerCase())) {
                                      AudioTracksDialogs.showDubbingProgressModal(
                                        context: context,
                                        controller: controller,
                                        langCode: availableTracks[i].code,
                                        isDarkMode: isDarkMode,
                                      );
                                    } else {
                                      playerCtrl.switchTrack(availableTracks[i]).then((_) {
                                        if (playerCtrl.selectedTrack.value != null) {
                                          controller.selectedLanguage.value = playerCtrl.selectedTrack.value!.code;
                                        }
                                      });
                                    }
                                  },
                                ),
                              ],
                              if (onAddDubTrack != null) ...[
                                const SizedBox(width: 6),
                                _buildAddLanguagePill(onTap: onAddDubTrack!),
                              ],
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                  // 4. Top-Right Fullscreen Overlay Button
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.black54,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => playerCtrl.toggleFullscreen(
                          context,
                          video: video,
                          tracksController: controller,
                          onAddDubTrack: onAddDubTrack,
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(
                            Icons.fullscreen_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
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

  // ---------------------------------------------------------------------------
  // LANGUAGE PILL (Active = Solid White + Black text, Inactive = Dark + White text)
  // Shows clean progress percentage only on generating / uploading languages
  // ---------------------------------------------------------------------------
  Widget _buildLanguagePill({
    required AudioTrackOption track,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return buildLanguagePillWidget(
      controller: controller,
      track: track,
      isActive: isActive,
      onTap: onTap,
    );
  }

  Widget _buildAddLanguagePill({required VoidCallback onTap}) {
    return buildAddLanguagePillWidget(onTap: onTap);
  }

  static Widget buildLanguagePillWidget({
    required AudioTracksController controller,
    required AudioTrackOption track,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final code = track.code.trim().toLowerCase();
    final isGenerating = controller.generatingDubLanguages.contains(code);
    final dubProgress = controller.dubbingProgress[code];
    final isUploading = controller.isUploading.value &&
        controller.uploadingLanguageCode.value.trim().toLowerCase() == code;

    final isInProgress = isGenerating || isUploading;
    int? percent;
    if (isGenerating) {
      percent = dubProgress?.progress ?? 15;
    } else if (isUploading) {
      percent = (controller.uploadProgress.value * 100).toInt().clamp(0, 100);
    }

    final playerCtrl = Get.isRegistered<MultilingualStudioPlayerController>()
        ? Get.find<MultilingualStudioPlayerController>()
        : null;
    final isAudioSyncing = isActive && (playerCtrl?.isChangingTrack.value ?? false);
    final showActiveSpinner = isInProgress || isAudioSyncing;

    final displayText = isInProgress
        ? '${track.label} $percent%'
        : '${track.label}\u200B';

    if (isActive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showActiveSpinner) ...[
              const SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              displayText,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.65),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isInProgress) ...[
              const SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              displayText,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget buildAddLanguagePillWidget({required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, color: Colors.white, size: 14),
            SizedBox(width: 4),
            Text(
              'Language',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // RESOLUTION SELECTION LADDER BAR (Processed Non-Raw Streams Only)
  // ---------------------------------------------------------------------------
  Widget _buildResolutionBar(
    BuildContext context,
    MultilingualStudioPlayerController playerCtrl,
  ) {
    return Obx(() {
      final resList = playerCtrl.availableResolutions;
      if (resList.isEmpty) return const SizedBox.shrink();

      final current = playerCtrl.currentResolution.value;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.bgPage,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.bgSurface),
        ),
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.tune_rounded,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                SizedBox(width: 6),
                Text(
                  'Resolutions:',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            ...resList.map((res) {
              final isSelected = current?.label == res.label || current?.url == res.url;
              return InkWell(
                onTap: () => playerCtrl.switchResolution(res),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : AppColors.bgSurface,
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
              );
            }),
          ],
        ),
      );
    });
  }

  // ---------------------------------------------------------------------------
  // TIMELINE SCRUBBER & LIVE TIMESTAMP BAR
  // ---------------------------------------------------------------------------
  Widget _buildScrubberBar(
    BuildContext context,
    MultilingualStudioPlayerController playerCtrl,
  ) {
    return Obx(() {
      final isPlaying = playerCtrl.isPlaying.value;
      final pos = playerCtrl.position.value;
      final isMuted = playerCtrl.isMuted.value;
      final dur = playerCtrl.duration.value > Duration.zero
          ? playerCtrl.duration.value
          : (video.durationValue > Duration.zero
              ? video.durationValue
              : const Duration(seconds: 15));

      final maxMs = dur.inMilliseconds > 0 ? dur.inMilliseconds.toDouble() : 1.0;
      final currentMs = pos.inMilliseconds.clamp(0, maxMs.toInt()).toDouble();

      return Row(
        children: [
          // Play / Pause toggle
          IconButton(
            icon: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 26,
            ),
            onPressed: () {
              if (isPlaying) {
                playerCtrl.pause();
              } else {
                playerCtrl.play();
              }
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),

          const SizedBox(width: 4),

          // Scrubber Slider
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                thumbColor: Colors.white,
                activeTrackColor: Colors.white,
                inactiveTrackColor: AppColors.bgElevated,
                trackHeight: 3.0,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                value: currentMs.clamp(0.0, maxMs),
                max: maxMs,
                onChanged: (val) {
                  playerCtrl.seekTo(Duration(milliseconds: val.toInt()));
                },
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Duration / Timestamp Display e.g. 0:15
          Text(
            _formatDuration(pos) == '0:00'
                ? _formatDuration(dur)
                : '${_formatDuration(pos)} / ${_formatDuration(dur)}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(width: 4),

          // Volume / Mute
          IconButton(
            icon: Icon(
              isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              color: Colors.white,
              size: 20,
            ),
            onPressed: playerCtrl.toggleMute,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),

          const SizedBox(width: 4),

          // Fullscreen Toggle Button
          IconButton(
            tooltip: playerCtrl.isFullscreen.value
                ? 'Exit fullscreen (f)'
                : 'Fullscreen (f)',
            icon: Icon(
              playerCtrl.isFullscreen.value
                  ? Icons.fullscreen_exit_rounded
                  : Icons.fullscreen_rounded,
              color: Colors.white,
              size: 24,
            ),
            onPressed: () => playerCtrl.toggleFullscreen(
              context,
              video: video,
              tracksController: controller,
              onAddDubTrack: onAddDubTrack,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      );
    });
  }

  // ---------------------------------------------------------------------------
  // ACTIONS ROW (+ Audio button placed before Download button)
  // ---------------------------------------------------------------------------
  Widget _buildActionRow(
    BuildContext context,
    MultilingualStudioPlayerController playerCtrl,
    bool isNarrow,
  ) {
    return Align(
      alignment: Alignment.centerRight,
      child: Obx(() {
        final isDownloading = playerCtrl.isDownloading.value;
        final selectedTrack = playerCtrl.selectedTrack.value;
        final allTracks = MultilingualStudioPlayerController.buildTrackOptions(
          video: video,
          tracksController: controller,
        );
        final dubbedTracks = allTracks
            .where((t) =>
                !t.isEmbedded && t.code != 'original' && t.code != 'en')
            .toList();
        final editableTrack = (selectedTrack != null &&
                !selectedTrack.isEmbedded &&
                selectedTrack.code != 'original' &&
                selectedTrack.code != 'en')
            ? selectedTrack
            : (dubbedTracks.isNotEmpty ? dubbedTracks.first : null);

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (editableTrack != null)
              ElevatedButton.icon(
                onPressed: () {
                  DubbingSegmentEditorPage.openAsDrawer(
                    context,
                    videoId: video.id,
                    languageCode: editableTrack.code,
                    languageName: editableTrack.label,
                    isDarkMode: isDarkMode,
                    onRemastered: () =>
                        controller.refreshVideoLocalization(video.id),
                  );
                },
                icon: const Icon(
                  Icons.edit_note_rounded,
                  size: 16,
                  color: Colors.black,
                ),
                label: Text(
                  isNarrow ? 'Timeline' : 'Edit Timeline',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(
                    horizontal: isNarrow ? 12 : 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            if (onAddDubTrack != null)
              ElevatedButton.icon(
                onPressed: onAddDubTrack,
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
                    fontSize: 13,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(
                    horizontal: isNarrow ? 14 : 18,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ElevatedButton.icon(
              onPressed: isDownloading
                  ? null
                  : () => _handleDownload(context, playerCtrl),
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
                  fontSize: 13,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                elevation: 0,
                padding: EdgeInsets.symmetric(
                  horizontal: isNarrow ? 14 : 18,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  // ---------------------------------------------------------------------------
  // DOWNLOAD ACTION HANDLER
  // ---------------------------------------------------------------------------
  void _handleDownload(
    BuildContext context,
    MultilingualStudioPlayerController playerCtrl,
  ) {
    final activeTrack = playerCtrl.selectedTrack.value;
    final langCode = activeTrack?.code ?? controller.selectedLanguage.value;
    final langLabel = activeTrack?.label ?? controller.getLanguageName(langCode);

    final rawTitle = video.title.isNotEmpty ? video.title : 'video';
    final cleanTitle = rawTitle
        .replaceAll(RegExp(r'[^\w\s\-]'), '')
        .trim()
        .replaceAll(' ', '_');

    final cachedLoc = controller.selectedVideo.value != null
        ? controller.selectedVideo.value!.dubbedVideos
        : const <String, String>{};
    final dubbedVideoUrl = video.dubbedVideos[langCode] ?? cachedLoc[langCode] ?? '';
    final audioUrl = video.audioTracks[langCode] ?? activeTrack?.audioUrl ?? '';
    final isBaseTrack = activeTrack?.isEmbedded == true ||
        langCode == video.language ||
        langCode == '__original__';

    final allTracks = MultilingualStudioPlayerController.buildTrackOptions(
      video: video,
      tracksController: controller,
    );

    AudioTracksDialogs.showDubbedVideoDownloadModal(
      context: context,
      video: video,
      track: activeTrack,
      langLabel: langLabel,
      cleanTitle: cleanTitle,
      isBaseTrack: isBaseTrack,
      dubbedVideoUrl: dubbedVideoUrl,
      audioUrl: audioUrl,
      tracksController: controller,
      availableTracks: allTracks,
    );
  }
}
