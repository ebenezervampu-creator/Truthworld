import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/multi_audio_player_controller.dart';
import 'package:truthworld/theme/app_colors.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Drop-in YouTube-style video player with multi-language dubbed audio support.
///
/// Example:
/// ```dart
/// VideoPlayerWithAudioTracks(
///   videoUrl: video.videoUrl,
///   tracks: [
///     AudioTrackOption(code: 'en', label: 'English', isEmbedded: true),
///     AudioTrackOption(code: 'hi', label: 'Hindi', audioUrl: video.audioTracks['hi']),
///     AudioTrackOption(code: 'te', label: 'Telugu', audioUrl: video.audioTracks['te']),
///   ],
/// )
/// ```
class VideoPlayerWithAudioTracks extends StatefulWidget {

  const VideoPlayerWithAudioTracks({
    required this.videoUrl, required this.tracks, super.key,
    this.preferredTrackCode,
    this.autoPlay = true,
    this.aspectRatio = 16 / 9,
  });
  final String videoUrl;
  final List<AudioTrackOption> tracks;
  final String? preferredTrackCode;
  final bool autoPlay;
  final double aspectRatio;

  @override
  State<VideoPlayerWithAudioTracks> createState() =>
      _VideoPlayerWithAudioTracksState();
}

class _VideoPlayerWithAudioTracksState
    extends State<VideoPlayerWithAudioTracks> {
  late final MultiAudioPlayerController _ctrl;
  final _controlsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _ctrl = Get.put(
      MultiAudioPlayerController(),
      tag: widget.videoUrl.hashCode.toString(),
    );
    _ctrl.initialize(
      widget.videoUrl,
      tracks: widget.tracks,
      preferredTrackCode: widget.preferredTrackCode,
    );
  }

  @override
  void dispose() {
    Get.delete<MultiAudioPlayerController>(
      tag: widget.videoUrl.hashCode.toString(),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (_ctrl.isInitializing.value) {
        return AspectRatio(
          aspectRatio: widget.aspectRatio,
          child: const ColoredBox(
            color: AppColors.bgPage,
            child: Center(
              child: CircularProgressIndicator(color: AppColors.textPrimary),
            ),
          ),
        );
      }

      if (_ctrl.hasError.value) {
        return AspectRatio(
          aspectRatio: widget.aspectRatio,
          child: const ColoredBox(
            color: AppColors.bgPage,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: AppColors.textSecondary,
                    size: 48,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Could not load video',
                    style: TextStyle(
                      
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      return AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: Stack(
          children: [
            // ── Video layer ──────────────────────────────────────────────────
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  _ctrl.flashControls();
                  if (_ctrl.isPlaying.value) {
                    _ctrl.pause();
                  } else {
                    _ctrl.play();
                  }
                },
                child:
                    _ctrl.videoController != null &&
                        _ctrl.chewieController != null
                    ? Chewie(controller: _ctrl.chewieController!)
                    : const SizedBox.shrink(),
              ),
            ),

            // ── Track-changing overlay ───────────────────────────────────────
            if (_ctrl.isChangingTrack.value)
              const Positioned.fill(
                child: ColoredBox(
                  color: AppColors.bgPage54,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: AppColors.textPrimary),
                        SizedBox(height: 12),
                        Text(
                          'Switching audio track…',
                          style: TextStyle(
                            
                            color: AppColors.textPrimary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // ── Controls overlay ─────────────────────────────────────────────
            Obx(() {
              if (!_ctrl.showControls.value && _ctrl.isPlaying.value) {
                return const SizedBox.shrink();
              }
              return Positioned.fill(
                child: _PlayerControls(key: _controlsKey, ctrl: _ctrl),
              );
            }),
          ],
        ),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Controls layer
// ─────────────────────────────────────────────────────────────────────────────
class _PlayerControls extends StatelessWidget {

  const _PlayerControls({required this.ctrl, super.key});
  final MultiAudioPlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0x88000000),
            Color(0x00000000),
            Color(0x00000000),
            Color(0xCC000000),
          ],
          stops: [0, 0.2, 0.6, 1],
        ),
      ),
      child: Column(
        children: [
          // ── Top bar: audio track selector ──────────────────────────────────
          _TopBar(ctrl: ctrl),
          const Spacer(),
          // ── Centre: play/pause ─────────────────────────────────────────────
          _CentrePlayButton(ctrl: ctrl),
          const Spacer(),
          // ── Bottom bar: scrubber + time + volume ───────────────────────────
          _BottomBar(ctrl: ctrl),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.ctrl});
  final MultiAudioPlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Audio track pill button
          Obx(() {
            final track = ctrl.selectedTrack.value;
            if (track == null || ctrl.availableTracks.length <= 1) {
              return const SizedBox.shrink();
            }
            return GestureDetector(
              onTap: () => _showAudioSheet(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.spatial_audio_rounded,
                      size: 14,
                      color: AppColors.textPrimary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      track.label,
                      style: const TextStyle(
                        
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_drop_down,
                      size: 14,
                      color: AppColors.textPrimary,
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(width: 8),
          // Speed button
          Obx(() {
            final speed = ctrl.playbackSpeed.value;
            return GestureDetector(
              onTap: () => _showSpeedSheet(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.bgPage54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${speed == 1.0 ? '1' : speed}x',
                  style: const TextStyle(
                    
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showAudioSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AudioTrackSheet(ctrl: ctrl),
    );
  }

  void _showSpeedSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SpeedSheet(ctrl: ctrl),
    );
  }
}

class _CentrePlayButton extends StatelessWidget {
  const _CentrePlayButton({required this.ctrl});
  final MultiAudioPlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => GestureDetector(
        onTap: () {
          if (ctrl.isPlaying.value) {
            ctrl.pause();
          } else {
            ctrl.play();
          }
        },
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.black45,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.textTertiary),
          ),
          child: Icon(
            ctrl.isPlaying.value ? Icons.pause : Icons.play_arrow,
            color: AppColors.textPrimary,
            size: 30,
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.ctrl});
  final MultiAudioPlayerController ctrl;

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    if (h > 0) return '${h.toString().padLeft(2, '0')}:$m:$s';
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress bar
          Obx(() {
            final pos = ctrl.position.value;
            final dur = ctrl.duration.value;
            final progress = dur.inMilliseconds == 0
                ? 0.0
                : pos.inMilliseconds / dur.inMilliseconds;

            return SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                thumbColor: AppColors.brand,
                activeTrackColor: AppColors.brand,
                inactiveTrackColor: AppColors.textTertiary,
                overlayColor: AppColors.brand.withValues(alpha: 0.2),
              ),
              child: Slider(
                value: progress.clamp(0.0, 1.0),
                onChangeStart: (_) => ctrl.pause(),
                onChanged: (v) {
                  final target = Duration(
                    milliseconds: (v * dur.inMilliseconds).round(),
                  );
                  ctrl.seekTo(target);
                },
                onChangeEnd: (_) => ctrl.play(),
              ),
            );
          }),
          const SizedBox(height: 2),
          // Time + volume + fullscreen row
          Obx(
            () => Row(
              children: [
                Text(
                  _formatDuration(ctrl.position.value),
                  style: const TextStyle(
                    
                    fontSize: 12,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  ' / ${_formatDuration(ctrl.duration.value)}',
                  style: const TextStyle(
                    
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                // Volume
                IconButton(
                  iconSize: 20,
                  color: AppColors.textPrimary,
                  icon: Icon(
                    ctrl.isMuted.value
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                  ),
                  onPressed: ctrl.toggleMute,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                // Active track badge
                if (ctrl.availableTracks.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.bgDivider,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.audiotrack_rounded,
                            size: 10,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            ctrl.selectedTrack.value?.label ?? '',
                            style: const TextStyle(
                              
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Audio Track selection bottom sheet
// ─────────────────────────────────────────────────────────────────────────────
class _AudioTrackSheet extends StatelessWidget {
  const _AudioTrackSheet({required this.ctrl});
  final MultiAudioPlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E1E1E) : AppColors.textPrimary;
    final textColor = isDark ? AppColors.textPrimary : AppColors.bgPage;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? AppColors.textDisabled : Colors.black26,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.brand.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.spatial_audio_rounded,
                    color: AppColors.brand,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Audio Track',
                      style: TextStyle(
                        
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    Text(
                      'Select dubbed language for playback',
                      style: TextStyle(
                        
                        fontSize: 12,
                        color: isDark ? AppColors.textSecondary : Colors.black45,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Tracks list
          Obx(
            () => ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: ctrl.availableTracks.length,
              itemBuilder: (context, i) {
                final track = ctrl.availableTracks[i];
                final isSelected = ctrl.selectedTrack.value?.code == track.code;
                return InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    ctrl.switchTrack(track);
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 3,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.brand.withValues(alpha: 0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(
                              color: AppColors.brand.withValues(alpha: 0.3),
                            )
                          : null,
                    ),
                    child: Row(
                      children: [
                        // Language icon
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.brand
                                : (isDark
                                      ? const Color(0xFF2A2A2A)
                                      : const Color(0xFFF1F5F9)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              track.code.length >= 2
                                  ? track.code.substring(0, 2).toUpperCase()
                                  : track.code.toUpperCase(),
                              style: TextStyle(
                                
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? AppColors.textPrimary
                                    : (isDark
                                          ? AppColors.textSecondary
                                          : AppColors.bgPage54),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Label and type
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                track.label,
                                style: TextStyle(
                                  
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? AppColors.brand
                                      : textColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                track.isEmbedded
                                    ? 'Original audio track'
                                    : 'Dubbed audio track',
                                style: TextStyle(
                                  
                                  fontSize: 11,
                                  color: isDark
                                      ? AppColors.textTertiary
                                      : Colors.black38,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Checkmark
                        if (isSelected)
                          Container(
                            width: 22,
                            height: 22,
                            decoration: const BoxDecoration(
                              color: AppColors.brand,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              size: 14,
                              color: AppColors.textPrimary,
                            ),
                          )
                        else
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark ? AppColors.textDisabled : Colors.black26,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Playback speed sheet
// ─────────────────────────────────────────────────────────────────────────────
class _SpeedSheet extends StatelessWidget {
  const _SpeedSheet({required this.ctrl});
  final MultiAudioPlayerController ctrl;

  static const _speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E1E1E) : AppColors.textPrimary;
    final textColor = isDark ? AppColors.textPrimary : AppColors.bgPage;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? AppColors.textDisabled : Colors.black26,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                const Icon(Icons.speed_rounded, color: AppColors.brand),
                const SizedBox(width: 12),
                Text(
                  'Playback Speed',
                  style: TextStyle(
                    
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Obx(
            () => Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _speeds.map((speed) {
                  final isSelected = ctrl.playbackSpeed.value == speed;
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      ctrl.setPlaybackSpeed(speed);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.brand
                            : (isDark
                                  ? const Color(0xFF2A2A2A)
                                  : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Text(
                        speed == 1.0 ? 'Normal' : '${speed}x',
                        style: TextStyle(
                          
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? AppColors.textPrimary
                              : (isDark ? AppColors.textSecondary : AppColors.bgPage54),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
