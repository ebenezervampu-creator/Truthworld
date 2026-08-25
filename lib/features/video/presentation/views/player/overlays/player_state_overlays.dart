import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import 'package:truthworld/features/video/data/models/credibility_report.dart';
import 'package:truthworld/features/video/presentation/controllers/adaptive_birate_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/audio_only_service.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/controls/player_controls.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:truthworld/theme/app_theme.dart';

class SwitchingResolutionOverlay extends StatelessWidget {
  const SwitchingResolutionOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.bgPage.withValues(alpha: 0.4),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              decoration: BoxDecoration(
                color: AppColors.textPrimary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.textPrimary.withValues(alpha: 0.1),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: Shimmer.fromColors(
                      baseColor: PT.primary.withValues(alpha: 0.3),
                      highlightColor: PT.primary,
                      child: const Icon(
                        Icons.settings_backup_restore_rounded,
                        color: AppColors.textPrimary,
                        size: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Optimizing Quality...',
                    style: TS.title.copyWith(letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Switching to a better resolution',
                    style: TS.bodySm,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AUDIO-ONLY OVERLAY
// ─────────────────────────────────────────────────────────────────────────────
class AudioOnlyOverlay extends StatelessWidget {
  const AudioOnlyOverlay({required this.ctrl, super.key});
  final TowerPlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.bgPage,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: PT.primary.withValues(alpha: 0.4),
                    blurRadius: 50,
                    spreadRadius: 10,
                  ),
                ],
                border: Border.all(
                  color: PT.primary.withValues(alpha: 0.4),
                  width: 2,
                ),
              ),
              child: const ClipOval(
                child: Icon(
                  Icons.music_note_rounded,
                  size: 60,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Audio Only Mode',
              style: TS.title.copyWith(fontSize: 20, letterSpacing: 1.5),
            ),
            const SizedBox(height: 8),
            Obx(() {
              ctrl.isAudioOnly.value; // reactive touch
              final svc = Get.isRegistered<AudioOnlyService>()
                  ? Get.find<AudioOnlyService>()
                  : null;
              return Text(
                svc?.currentTrackTitle.value ?? '',
                style: TS.bodySm,
                textAlign: TextAlign.center,
              );
            }),
            const SizedBox(height: 24),
            const AudioWaveform(),
          ],
        ),
      ),
    );
  }
}

class AudioWaveform extends StatefulWidget {
  const AudioWaveform({super.key});
  @override
  State<AudioWaveform> createState() => _AudioWaveformState();
}

class _AudioWaveformState extends State<AudioWaveform>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      width: 120,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(7, (i) {
              final h =
                  8 + 18 * ((sin(i * 0.4 + _anim.value * 2 * pi) + 1) / 2);
              return Container(
                width: 4,
                height: h,
                decoration: BoxDecoration(
                  color: PT.primary.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATE OVERLAY
// ─────────────────────────────────────────────────────────────────────────────
class StateOverlay extends StatelessWidget {
  const StateOverlay({required this.ctrl, super.key});
  final TowerPlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      ctrl.isAudioOnly.value; // Guarantee Rx access for Obx
      final state = ctrl.abr.playbackState.value;
      final buffering = ctrl.isBuffering.value;
      final hasError = ctrl.hasError.value;

      // Suppress spinner for transparent auto-quality switches
      var isAutoSwitch = false;
      try {
        final vc = ctrl.videoController;
        if (vc != null) {
          isAutoSwitch = vc.isAutoSwitching.value;
        }
      } catch (_) {}
      if (isAutoSwitch) return const SizedBox.shrink();

      if (hasError) return _buildError();
      if (state == PlaybackState.stalled) return _buildStall();
      if (buffering || state == PlaybackState.buffering) {
        return _buildSpinner(PT.primary);
      }
      return const SizedBox.shrink();
    });
  }

  Widget _buildSpinner(Color color) => Center(
    child: SizedBox(
      width: 48,
      height: 48,
      child: Shimmer.fromColors(
        baseColor: color.withValues(alpha: 0.3),
        highlightColor: color,
        child: const Icon(
          Icons.play_circle_outline_rounded,
          color: AppColors.textPrimary,
          size: 48,
        ),
      ),
    ),
  );

  Widget _buildStall() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildSpinner(AppColors.warning),
        const SizedBox(height: 16),
        Text(
          'Poor network · ${ctrl.abr.currentTier.label}',
          style: const TextStyle(
            color: AppColors.warning,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );

  Widget _buildError() {
    final err = ctrl.errorDescription.value.isNotEmpty
        ? ctrl.errorDescription.value
        : (ctrl.vv.errorDescription ?? 'An unknown error occurred');
    if (err.contains('removed from the document') ||
        err.contains('play() request was interrupted') ||
        err.contains('The play() request was interrupted') ||
        err.contains('AbortError') ||
        err.contains('NotAllowedError')) {
      return const SizedBox.shrink();
    }
    return ColoredBox(
      color: AppColors.bgPage,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.textPrimary, size: 52),
            const SizedBox(height: 16),
            Text('Playback Error', style: TS.title.copyWith(fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              err,
              style: TS.bodySm,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            PremiumButton(
              label: 'Retry',
              icon: Icons.refresh_rounded,
              onTap: ctrl.retryManual,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DOUBLE-TAP RIPPLE (YouTube-style curved arc with 3-chevron animated wave)
// ─────────────────────────────────────────────────────────────────────────────
class DoubleTapRipple extends StatefulWidget {
  const DoubleTapRipple({
    required this.isLeft,
    this.seconds = 10,
    super.key,
  });
  final bool isLeft;
  final int seconds;

  @override
  State<DoubleTapRipple> createState() => _DoubleTapRippleState();
}

class _DoubleTapRippleState extends State<DoubleTapRipple>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..repeat();
  }

  @override
  void didUpdateWidget(DoubleTapRipple oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_animCtrl.isAnimating) {
      _animCtrl.repeat();
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLeft = widget.isLeft;
    final seconds = widget.seconds;

    return Positioned(
      left: isLeft ? 0 : null,
      right: isLeft ? null : 0,
      top: 0,
      bottom: 0,
      width: MediaQuery.of(context).size.width * 0.45,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ClipPath(
            clipper: _YouTubeRippleClipper(isLeft: isLeft),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Animated 3-chevron wave pulse
                    AnimatedBuilder(
                      animation: _animCtrl,
                      builder: (context, child) {
                        final progress = _animCtrl.value;

                        double getArrowOpacity(int index) {
                          final offset = index * 0.22;
                          final localProgress = (progress - offset) % 1.0;
                          if (localProgress < 0.0) return 0.2;
                          if (localProgress <= 0.35) {
                            return 0.2 + (0.8 * (localProgress / 0.35));
                          } else if (localProgress <= 0.7) {
                            return 1.0 - (0.8 * ((localProgress - 0.35) / 0.35));
                          }
                          return 0.2;
                        }

                        final arrowIcons = List.generate(3, (index) {
                          // For left: wave travels from inner (index 2) to outer (index 0)
                          // For right: wave travels from inner (index 0) to outer (index 2)
                          final arrowIdx = isLeft ? (2 - index) : index;
                          final opacity = getArrowOpacity(arrowIdx);

                          return Opacity(
                            opacity: opacity.clamp(0.2, 1.0),
                            child: Icon(
                              isLeft
                                  ? Icons.arrow_left_rounded
                                  : Icons.arrow_right_rounded,
                              color: AppColors.textPrimary,
                              size: 40,
                            ),
                          );
                        });

                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: arrowIcons,
                        );
                      },
                    ),
                    const SizedBox(height: 2),
                    // Accumulated seconds text with smooth pop/scale transition
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      transitionBuilder: (child, anim) => ScaleTransition(
                        scale: anim,
                        child: child,
                      ),
                      child: Text(
                        '$seconds seconds',
                        key: ValueKey<int>(seconds),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                          shadows: [
                            Shadow(
                              color: Colors.black87,
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _YouTubeRippleClipper extends CustomClipper<Path> {
  _YouTubeRippleClipper({required this.isLeft});
  final bool isLeft;

  @override
  Path getClip(Size size) {
    final path = Path();
    if (isLeft) {
      // Parabolic curved arc towards the center right
      path.moveTo(0, 0);
      path.lineTo(size.width * 0.72, 0);
      path.quadraticBezierTo(
        size.width * 1.12,
        size.height / 2,
        size.width * 0.72,
        size.height,
      );
      path.lineTo(0, size.height);
      path.close();
    } else {
      // Parabolic curved arc towards the center left
      path.moveTo(size.width, 0);
      path.lineTo(size.width * 0.28, 0);
      path.quadraticBezierTo(
        -size.width * 0.12,
        size.height / 2,
        size.width * 0.28,
        size.height,
      );
      path.lineTo(size.width, size.height);
      path.close();
    }
    return path;
  }

  @override
  bool shouldReclip(_YouTubeRippleClipper oldClipper) =>
      oldClipper.isLeft != isLeft;
}

// ─────────────────────────────────────────────────────────────────────────────
// SEEK PREVIEW TOOLTIP
// ─────────────────────────────────────────────────────────────────────────────
class SeekPreviewTooltip extends StatelessWidget {
  const SeekPreviewTooltip({required this.ctrl, super.key});
  final TowerPlayerController ctrl;

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  Color _getVerdictColor(String verdict) {
    switch (verdict.toLowerCase()) {
      case 'verified_true':
      case 'mostly_true':
        return AppColors.success;
      case 'false_claim':
      case 'misleading':
      case 'disputed':
        return AppColors.error;
      case 'unproven':
      case 'inconclusive':
      case 'limited_support':
      case 'verification_timeout':
        return AppColors.brandHover;
      default:
        return AppColors.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final dur = ctrl.vv.duration;
      final pos = ctrl.seekPreviewPos.value;
      final xPct = dur.inMilliseconds > 0
          ? pos.inMilliseconds / dur.inMilliseconds
          : 0.0;

      // Check if we are hovering close to a claim
      ClaimResult? hoveredClaim;
      final vc = ctrl.videoController;
      if (vc != null) {
        final claims = vc.video.uiReport?.keyClaims;
        if (claims != null && claims.isNotEmpty && dur.inMilliseconds > 0) {
          final thresholdMs = dur.inMilliseconds * 0.015; // 1.5% hover snap
          for (final claim in claims) {
            if (claim.start != null) {
              final claimMs = claim.start! * 1000.0;
              if ((pos.inMilliseconds - claimMs).abs() <= thresholdMs) {
                hoveredClaim = claim;
                break;
              }
            }
          }
        }
      }

      return Positioned(
        bottom: 100,
        left: 0,
        right: 0,
        child: LayoutBuilder(
          builder: (_, c) {
            final xPx = (xPct * c.maxWidth).clamp(52.0, c.maxWidth - 52.0);
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: hoveredClaim != null
                      ? (xPx - 160).clamp(16.0, c.maxWidth - 336.0)
                      : (xPx - 80).clamp(16.0, c.maxWidth - 176.0),
                  bottom: 0,
                  child: Container(
                    width: hoveredClaim != null ? 320 : 160,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: PT.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: PT.border),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.bgPage.withValues(alpha: 0.65),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Builder(
                      builder: (context) {
                        final thumbUrl =
                            ctrl.videoController?.video.thumbnailUrl;
                        final Widget thumbWidget = Container(
                          width: hoveredClaim != null ? 120 : 144,
                          height: hoveredClaim != null ? 68 : 81,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.bgDivider),
                            color: Colors.black45,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: thumbUrl != null && thumbUrl.isNotEmpty
                                ? Image.network(
                                    thumbUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const Center(
                                              child: Icon(
                                                Icons.movie_creation_rounded,
                                                color: AppColors.textTertiary,
                                                size: 24,
                                              ),
                                            ),
                                  )
                                : const Center(
                                    child: Icon(
                                      Icons.movie_creation_rounded,
                                      color: AppColors.textTertiary,
                                      size: 24,
                                    ),
                                  ),
                          ),
                        );

                        if (hoveredClaim != null) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  thumbWidget,
                                  const SizedBox(height: 6),
                                  Text(
                                    _fmt(pos),
                                    style: TS.time.copyWith(fontSize: 12),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      hoveredClaim.text,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        height: 1.3,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getVerdictColor(
                                          hoveredClaim.verdict,
                                        ).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: _getVerdictColor(
                                            hoveredClaim.verdict,
                                          ).withValues(alpha: 0.4),
                                        ),
                                      ),
                                      child: Text(
                                        hoveredClaim.verdict
                                            .toUpperCase()
                                            .replaceAll('_', ' '),
                                        style: TextStyle(
                                          color: _getVerdictColor(
                                            hoveredClaim.verdict,
                                          ),
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }

                        // Default (no claim hovered)
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            thumbWidget,
                            const SizedBox(height: 6),
                            Text(
                              _fmt(pos),
                              style: TS.time,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUBTITLE OVERLAY
// ─────────────────────────────────────────────────────────────────────────────

class PlayerToast extends StatelessWidget {
  const PlayerToast({required this.message, super.key});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.bgPage.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: PT.border),
        ),
        child: Text(
          message,
          style: TS.body.copyWith(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN CONTROLS
// ─────────────────────────────────────────────────────────────────────────────

class SwipeHUD extends StatelessWidget {
  const SwipeHUD({required this.isBrightness, required this.value, super.key});
  final bool isBrightness;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 200,
      decoration: BoxDecoration(
        color: AppColors.bgPage.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 12),
          Icon(
            isBrightness
                ? Icons.light_mode_rounded
                : value == 0
                ? Icons.volume_mute_rounded
                : Icons.volume_up_rounded,
            color: AppColors.textPrimary,
            size: 20,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textDisabled,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  FractionallySizedBox(
                    heightFactor: value.clamp(0.0, 1.0),
                    child: Container(
                      width: 4,
                      decoration: BoxDecoration(
                        color: PT.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(value * 100).toInt()}%',
            style: TS.mono.copyWith(
              color: AppColors.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// KEYBOARD SHORTCUTS DIALOG
// ─────────────────────────────────────────────────────────────────────────────
