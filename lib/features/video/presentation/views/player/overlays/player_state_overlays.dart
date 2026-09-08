import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import 'package:truthworld/features/video/data/models/credibility_report.dart';
import 'package:truthworld/features/video/presentation/controllers/adaptive_bitrate_controller.dart';
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
                      baseColor: PT.primary.withValues(alpha: 0.4),
                      highlightColor: PT.primary,
                      child: const Icon(
                        Icons.hd_rounded,
                        color: AppColors.textPrimary,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Optimizing Stream',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Auto-adjusting resolution...',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
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
    return Obx(() {
      ctrl.isAudioOnly.value; // reactive touch
      final isPlaying = ctrl.isPlaying.value;

      return ColoredBox(
        color: Colors.black,
        child: AcousticWaveformThemeVisualizer(
          isPlaying: isPlaying,
        ),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACOUSTIC WAVEFORM THEME VISUALIZER (High-Resolution Ambient Soundwave)
// ─────────────────────────────────────────────────────────────────────────────
class AcousticWaveformThemeVisualizer extends StatefulWidget {
  const AcousticWaveformThemeVisualizer({
    required this.isPlaying,
    super.key,
  });
  final bool isPlaying;

  @override
  State<AcousticWaveformThemeVisualizer> createState() =>
      _AcousticWaveformThemeVisualizerState();
}

class _AcousticWaveformThemeVisualizerState
    extends State<AcousticWaveformThemeVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    if (widget.isPlaying) {
      _anim.repeat();
    }
  }

  @override
  void didUpdateWidget(AcousticWaveformThemeVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _anim.repeat();
      } else {
        _anim.stop();
      }
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        return CustomPaint(
          size: Size.infinite,
          painter: _AcousticWavePainter(
            time: _anim.value * 2 * pi,
            isPlaying: widget.isPlaying,
          ),
        );
      },
    );
  }
}

class _AcousticWavePainter extends CustomPainter {
  _AcousticWavePainter({
    required this.time,
    required this.isPlaying,
  });
  final double time;
  final bool isPlaying;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final centerY = size.height / 2;
    final maxAmp = (size.height * 0.32).clamp(35.0, 160.0);
    const strandCount = 18;

    final corePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4.0)
      ..isAntiAlias = true;

    // Subtle luminous horizon line
    final horizonPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(0, centerY),
      Offset(size.width, centerY),
      horizonPaint,
    );

    final pointsCount = (size.width / 4).clamp(80, 240).toInt();
    final dx = size.width / pointsCount;

    for (var k = 0; k < strandCount; k++) {
      final v = (k - (strandCount / 2)) / (strandCount / 2); // -1.0 to 1.0
      final absV = v.abs();
      final phaseOffset = k * 0.38 + (v * 0.5);
      final freq1 = 4.0 + (k % 3) * 0.5;
      final freq2 = 8.0 + (k % 2) * 1.2;

      final path = Path();
      var isFirst = true;

      for (var i = 0; i <= pointsCount; i++) {
        final x = i * dx;
        final u = (x / size.width).clamp(0.0, 1.0);
        final d = (u - 0.5) * 2.0;

        // Smooth bell-curve envelope tapering to 0 at edges
        final env = cos(d * (pi / 2)).clamp(0.0, 1.0);
        final envelope = env * env * env;

        // Multi-harmonic oscillation matching acoustic waveform visualizer
        final t = isPlaying ? time : 0.0;
        final w1 = sin(u * freq1 * pi + t * 1.6 + phaseOffset);
        final w2 = sin(u * freq2 * pi - t * 0.9 + phaseOffset * 1.5);
        final w3 = cos(u * 2 * pi + t * 0.4);

        final crestMod = (sin(u * 6 * pi).abs() * 0.7) + 0.3;
        final harmonic = (w1 * 0.65 + w2 * 0.25 + w3 * 0.1) * (1.0 + 0.35 * v);

        final yOffset = envelope * maxAmp * harmonic * crestMod + (v * 2.5 * envelope);
        final y = centerY + yOffset;

        if (isFirst) {
          path.moveTo(x, y);
          isFirst = false;
        } else {
          path.lineTo(x, y);
        }
      }

      // Draw glowing aura
      if (k % 3 == 0) {
        glowPaint
          ..color = Colors.white.withValues(alpha: 0.12 * (1.0 - absV * 0.5))
          ..strokeWidth = 3.2;
        canvas.drawPath(path, glowPaint);
      }

      // Draw luminous high-definition strand
      final alpha = (0.85 - absV * 0.45).clamp(0.15, 0.95);
      final strokeW = (1.5 - absV * 0.5).clamp(0.8, 1.8);
      corePaint
        ..color = Colors.white.withValues(alpha: alpha)
        ..strokeWidth = strokeW;
      canvas.drawPath(path, corePaint);
    }
  }

  @override
  bool shouldRepaint(_AcousticWavePainter oldDelegate) {
    return oldDelegate.time != time || oldDelegate.isPlaying != isPlaying;
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

      // Suppress spinner/errors for transparent auto-quality switches or format recovery
      var isAutoSwitch = false;
      var isRecovering = false;
      try {
        final vc = ctrl.videoController;
        if (vc != null) {
          isAutoSwitch = vc.isAutoSwitching.value;
          isRecovering = vc.isRecoveringFromFormatError;
        }
      } catch (_) {}
      if (isAutoSwitch || isRecovering) return const SizedBox.shrink();

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
    final lower = err.toLowerCase();
    if (lower.contains('removed from the document') ||
        lower.contains('play() request was interrupted') ||
        lower.contains('the play() request was interrupted') ||
        lower.contains('aborterror') ||
        lower.contains('notallowederror') ||
        lower.contains('media_err_aborted') ||
        lower.contains('client returned a buffer') ||
        lower.contains('bad_index') ||
        lower.contains('pause()') ||
        lower.contains('user gesture')) {
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
            final tooltipWidth = hoveredClaim != null
                ? (c.maxWidth - 32.0).clamp(160.0, 320.0)
                : 160.0;
            final leftPx = (xPx - (tooltipWidth / 2)).clamp(
              16.0,
              (c.maxWidth - tooltipWidth - 16.0).clamp(16.0, c.maxWidth),
            );

            return Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: EdgeInsets.only(left: leftPx),
                child: Container(
                  width: tooltipWidth,
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
                                              color: AppColors.textPrimary,
                                              size: 24,
                                            ),
                                          ),
                                )
                              : const Center(
                                  child: Icon(
                                    Icons.movie_creation_rounded,
                                    color: AppColors.textPrimary,
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
