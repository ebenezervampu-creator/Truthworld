import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/components/audio_themes/core/audio_theme_interface.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/components/audio_themes/core/audio_theme_responsive.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/components/audio_themes/widgets/audio_artwork.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/components/audio_themes/widgets/audio_metadata.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/components/audio_themes/widgets/credibility_indicator.dart';

/// Theme 1: Fluid Aura Canvas
/// High-end ambient acoustic stage using lightweight mathematical radial gradients
/// derived from artwork tones without expensive continuously running blur shaders.
class FluidAuraTheme extends AudioThemeStage {
  const FluidAuraTheme({
    required super.ctrl,
    required super.analysisService,
    super.video,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final title = video?.title.isNotEmpty == true ? video!.title : 'TruthWorld Audio Experience';
    final channel = video?.channelName.isNotEmpty == true ? video!.channelName : 'TruthWorld Creator';
    final thumb = video?.thumbnailUrl ?? '';

    return LayoutBuilder(
      builder: (context, constraints) {
        final responsive = AudioThemeResponsive.fromConstraints(constraints);

        return Stack(
          fit: StackFit.expand,
          children: [
            // Base Obsidian Canvas
            const ColoredBox(color: Color(0xFF08090E)),

            // Dynamic Low-Frequency Aura
            Obx(() {
              final rms = analysisService.rmsLevel.value;
              final auraRadius = 0.65 + 0.15 * rms;
              final haloAlpha = (0.12 + 0.10 * rms).clamp(0.08, 0.28);

              return Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: auraRadius,
                    colors: [
                      const Color(0xFF6366F1).withValues(alpha: haloAlpha),
                      const Color(0xFFEC4899).withValues(alpha: haloAlpha * 0.5),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              );
            }),

            // Centered Stage Content (Zero Overflow Guarantee)
            Center(
              child: Padding(
                padding: responsive.padding,
                child: responsive.isCompactHeight
                    ? _buildCompactLayout(responsive, title, channel, thumb)
                    : _buildStandardLayout(responsive, title, channel, thumb),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCompactLayout(
    AudioThemeResponsive responsive,
    String title,
    String channel,
    String thumb,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AudioArtwork(
          size: responsive.artworkSize,
          thumbnailUrl: thumb,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CredibilityIndicator(video: video, compact: true),
              const SizedBox(height: 4),
              AudioMetadata(
                title: title,
                channelName: channel,
                titleSize: responsive.titleFontSize,
                channelSize: responsive.channelFontSize,
                textAlign: TextAlign.start,
              ),
              const SizedBox(height: 6),
              _buildMiniAcousticPulse(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStandardLayout(
    AudioThemeResponsive responsive,
    String title,
    String channel,
    String thumb,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CredibilityIndicator(video: video),
        SizedBox(height: responsive.spacing),
        AudioArtwork(
          size: responsive.artworkSize,
          thumbnailUrl: thumb,
        ),
        SizedBox(height: responsive.spacing),
        AudioMetadata(
          title: title,
          channelName: channel,
          titleSize: responsive.titleFontSize,
          channelSize: responsive.channelFontSize,
          badgeText: analysisService.isLossless.value
              ? 'STUDIO LOSSLESS'
              : 'HD STREAM ${analysisService.sampleRateHz.value ~/ 1000}kHz',
          badgeColor: const Color(0xFFFBBF24),
        ),
        SizedBox(height: responsive.spacing),
        _buildMiniAcousticPulse(),
      ],
    );
  }

  Widget _buildMiniAcousticPulse() {
    return Obx(() {
      final bands = analysisService.frequencyBands;
      final bass = bands.isNotEmpty ? bands[0] : 0.2;
      final mid = bands.length > 1 ? bands[1] : 0.2;
      final air = bands.length > 2 ? bands[2] : 0.2;

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _pulseBar(bass, 14.0),
          const SizedBox(width: 3),
          _pulseBar(mid, 20.0),
          const SizedBox(width: 3),
          _pulseBar(air, 12.0),
          const SizedBox(width: 3),
          _pulseBar(mid * 0.8, 16.0),
        ],
      );
    });
  }

  Widget _pulseBar(double energy, double maxHeight) {
    final height = (maxHeight * energy).clamp(4.0, maxHeight);
    return Container(
      width: 3.5,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
