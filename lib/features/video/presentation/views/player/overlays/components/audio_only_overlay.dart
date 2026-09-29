import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';

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
    return RepaintBoundary(
      child: AnimatedBuilder(
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
      ),
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
