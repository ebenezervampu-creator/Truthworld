import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/components/audio_themes/core/audio_theme_interface.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/components/audio_themes/core/audio_theme_responsive.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/components/audio_themes/widgets/audio_metadata.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/components/audio_themes/widgets/credibility_indicator.dart';

/// Theme 5: TruthPulse Spatial Hologram
/// Geometric acoustic orbital pulse with evaluated-only credibility illumination at the core.
/// Strictly bounded against viewport height and width.
class TruthPulseHologramTheme extends AudioThemeStage {
  const TruthPulseHologramTheme({
    required super.ctrl,
    required super.analysisService,
    super.video,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final title = video?.title.isNotEmpty == true ? video!.title : 'TruthWorld Spatial Sound';
    final channel = video?.channelName.isNotEmpty == true ? video!.channelName : 'TruthPulse Engine';

    return LayoutBuilder(
      builder: (context, constraints) {
        final responsive = AudioThemeResponsive.fromConstraints(constraints);

        return Stack(
          fit: StackFit.expand,
          children: [
            // Deep Cosmic Obsidian Void
            const ColoredBox(color: Color(0xFF06070B)),

            // Bounded Geometric Acoustic Orbital Rings
            Center(
              child: Obx(() {
                final peak = analysisService.peakAmplitude.value;
                final rms = analysisService.rmsLevel.value;
                final assessmentState = EpistemicAssessmentState.resolve(video);

                // Max radius clamped strictly to 38% of available height
                final maxOrbRadius = (responsive.maxHeight * 0.38).clamp(36.0, 110.0);

                return CustomPaint(
                  size: Size(maxOrbRadius * 2, maxOrbRadius * 2),
                  painter: _OrbitalRingsPainter(
                    peak: peak,
                    rms: rms,
                    assessmentState: assessmentState,
                  ),
                );
              }),
            ),

            // Metadata & Credibility Overlay
            Center(
              child: Padding(
                padding: responsive.padding,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CredibilityIndicator(video: video, compact: responsive.isCompactHeight),
                    SizedBox(height: responsive.spacing * 1.5),
                    // Centered Orb space reservation
                    SizedBox(height: (responsive.maxHeight * 0.35).clamp(32.0, 90.0)),
                    SizedBox(height: responsive.spacing),
                    AudioMetadata(
                      title: title,
                      channelName: channel,
                      titleSize: responsive.titleFontSize,
                      channelSize: responsive.channelFontSize,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _OrbitalRingsPainter extends CustomPainter {
  _OrbitalRingsPainter({
    required this.peak,
    required this.rms,
    required this.assessmentState,
  });

  final double peak;
  final double rms;
  final EpistemicAssessmentState assessmentState;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width / 2;

    // Epistemic illumination: authentic assessment color, or neutral cyan when unevaluated
    final Color coreColor = assessmentState == EpistemicAssessmentState.notEvaluated
        ? const Color(0xFF38BDF8)
        : assessmentState.color;

    // Outer Harmonic Ring
    final outerPaint = Paint()
      ..color = coreColor.withValues(alpha: (0.15 + 0.20 * peak).clamp(0.05, 0.45))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, baseRadius * (0.85 + 0.15 * peak), outerPaint);

    // Mid Harmonic Ring
    final midPaint = Paint()
      ..color = coreColor.withValues(alpha: (0.25 + 0.30 * rms).clamp(0.10, 0.65))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawCircle(center, baseRadius * (0.60 + 0.10 * rms), midPaint);

    // Inner Glowing Core
    final corePaint = Paint()
      ..color = coreColor.withValues(alpha: (0.35 + 0.40 * rms).clamp(0.20, 0.85))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, baseRadius * 0.28, corePaint);

    // Core Highlight
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.70)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, baseRadius * 0.08, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant _OrbitalRingsPainter oldDelegate) {
    return oldDelegate.peak != peak ||
        oldDelegate.rms != rms ||
        oldDelegate.assessmentState != assessmentState;
  }
}
