import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';

import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/audio_only_service.dart';
import 'package:truthworld/features/video/presentation/views/player/controls/player_controls.dart';
import 'package:truthworld/features/video/presentation/controllers/adaptive_birate_controller.dart';
import 'package:truthworld/features/video/data/models/credibility_report.dart';

class SwitchingResolutionOverlay extends StatelessWidget {
  const SwitchingResolutionOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.4),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
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
                        color: Colors.white,
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
                  Text('Switching to a better resolution', style: TS.bodySm),
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
  final TowerPlayerController ctrl;
  const AudioOnlyOverlay({super.key, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
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
                  Icons.audiotrack_rounded,
                  size: 60,
                  color: Colors.white70,
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
            crossAxisAlignment: CrossAxisAlignment.center,
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
  final TowerPlayerController ctrl;
  const StateOverlay({super.key, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final state = ctrl.abr.playbackState.value;
      final buffering = ctrl.isBuffering.value;
      final hasError = ctrl.vv.hasError;

      // Suppress spinner for transparent auto-quality switches
      bool isAutoSwitch = false;
      try {
        if (Get.isRegistered<VideoController>(tag: ctrl.tag)) {
          isAutoSwitch = Get.find<VideoController>(
            tag: ctrl.tag,
          ).isAutoSwitching.value;
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
          color: Colors.white,
          size: 48,
        ),
      ),
    ),
  );

  Widget _buildStall() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildSpinner(Colors.orange),
        const SizedBox(height: 16),
        Obx(
          () => Text(
            'Poor network · ${ctrl.abr.currentTier.label}',
            style: TextStyle(
              fontFamily: 'Roboto',
              color: Colors.orange,
              fontSize: 13,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildError() => Container(
    color: Colors.black87,
    child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, color: PT.primary, size: 52),
          const SizedBox(height: 16),
          Text('Playback Error', style: TS.title.copyWith(fontSize: 18)),
          const SizedBox(height: 8),
          Text(
            ctrl.vv.errorDescription ?? 'An unknown error occurred',
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

// ─────────────────────────────────────────────────────────────────────────────
// DOUBLE-TAP RIPPLE
// ─────────────────────────────────────────────────────────────────────────────
class DoubleTapRipple extends StatelessWidget {
  final bool isLeft;
  const DoubleTapRipple({super.key, required this.isLeft});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: isLeft ? 0 : null,
      right: isLeft ? null : 0,
      top: 0,
      bottom: 0,
      width: 160,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: isLeft
              ? const BorderRadius.only(
                  topRight: Radius.circular(80),
                  bottomRight: Radius.circular(80),
                )
              : const BorderRadius.only(
                  topLeft: Radius.circular(80),
                  bottomLeft: Radius.circular(80),
                ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isLeft ? Icons.replay_10_rounded : Icons.forward_10_rounded,
                color: Colors.white,
                size: 44,
              ),
              Text(
                '10 seconds',
                style: TS.bodySm.copyWith(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SEEK PREVIEW TOOLTIP
// ─────────────────────────────────────────────────────────────────────────────
class SeekPreviewTooltip extends StatelessWidget {
  final TowerPlayerController ctrl;
  const SeekPreviewTooltip({super.key, required this.ctrl});

  String _fmt(Duration d) {
    final h = d.inHours,
        m = d.inMinutes.remainder(60).toString().padLeft(2, '0'),
        s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
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
          final double thresholdMs =
              dur.inMilliseconds * 0.015; // 1.5% hover snap
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

      Color getVerdictColor(String verdict) {
        switch (verdict.toLowerCase()) {
          case 'verified_true':
          case 'mostly_true':
            return Colors.greenAccent;
          case 'false_claim':
          case 'misleading':
          case 'disputed':
            return Colors.redAccent;
          case 'unproven':
          case 'inconclusive':
          case 'limited_support':
          case 'verification_timeout':
            return Colors.amberAccent;
          default:
            return Colors.blueAccent;
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
                      ? (xPx - 150).clamp(16.0, c.maxWidth - 316.0)
                      : xPx - 52,
                  bottom: 0,
                  child: Container(
                    width: hoveredClaim != null ? 300 : 104,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: PT.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: PT.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _fmt(pos),
                          textAlign: TextAlign.center,
                          style: TS.time,
                        ),
                        if (hoveredClaim != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            hoveredClaim.text,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              color: Colors.white,
                              fontSize: 11,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hoveredClaim.verdict.toUpperCase().replaceAll(
                              '_',
                              ' ',
                            ),
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              color: getVerdictColor(hoveredClaim.verdict),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ],
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
  final String message;
  const PlayerToast({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.75),
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
  final bool isBrightness;
  final double value;
  const SwipeHUD({super.key, required this.isBrightness, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12),
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
            color: Colors.white,
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
                      color: Colors.white24,
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
              color: Colors.white,
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
