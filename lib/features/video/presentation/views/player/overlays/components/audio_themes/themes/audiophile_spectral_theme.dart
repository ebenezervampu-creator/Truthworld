import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/components/audio_themes/core/audio_theme_interface.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/components/audio_themes/core/audio_theme_responsive.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/components/audio_themes/widgets/audio_artwork.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/components/audio_themes/widgets/audio_metadata.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/components/audio_themes/widgets/credibility_indicator.dart';

/// Theme 3: Audiophile Studio Spectral
/// High-precision three-band frequency visualizer with real-time RMS, peak dBFS meters,
/// and verified audio pipeline metadata (sample rate, bit-depth, codec).
class AudiophileSpectralTheme extends AudioThemeStage {
  const AudiophileSpectralTheme({
    required super.ctrl,
    required super.analysisService,
    super.video,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final title = video?.title.isNotEmpty == true ? video!.title : 'TruthWorld Studio Master';
    final channel = video?.channelName.isNotEmpty == true ? video!.channelName : 'Precision Acoustic Feed';
    final thumb = video?.thumbnailUrl ?? '';

    return LayoutBuilder(
      builder: (context, constraints) {
        final responsive = AudioThemeResponsive.fromConstraints(constraints);

        return Stack(
          fit: StackFit.expand,
          children: [
            // Dark Studio Obsidian Canvas
            const ColoredBox(color: Color(0xFF07080B)),

            // Technical Grid Background
            CustomPaint(
              painter: _StudioGridPainter(),
            ),

            // Content Container
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
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: _buildTechnicalHeader(compact: true),
              ),
              const SizedBox(height: 4),
              AudioMetadata(
                title: title,
                channelName: channel,
                titleSize: responsive.titleFontSize,
                channelSize: responsive.channelFontSize,
                textAlign: TextAlign.start,
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: _buildThreeBandVisualizer(maxHeight: 28.0),
              ),
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
        _buildTechnicalHeader(compact: false),
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
        ),
        SizedBox(height: responsive.spacing),
        _buildThreeBandVisualizer(maxHeight: 46.0),
      ],
    );
  }

  Widget _buildTechnicalHeader({required bool compact}) {
    return Obx(() {
      final badge = analysisService.verifiedQualityBadge;
      final isHardware = analysisService.isHardwarePcmActive.value;

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 6 : 8,
              vertical: compact ? 2 : 3,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.35),
                width: 0.8,
              ),
            ),
            child: Text(
              badge,
              style: TextStyle(
                color: const Color(0xFF10B981),
                fontSize: compact ? 8.5 : 9.5,
                fontWeight: FontWeight.w700,
                fontFamily: 'RobotoMono',
                letterSpacing: 0.6,
              ),
            ),
          ),
          if (isHardware) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'PCM SINK',
                style: TextStyle(
                  color: Color(0xFF38BDF8),
                  fontSize: 7.5,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'RobotoMono',
                ),
              ),
            ),
          ],
          const SizedBox(width: 8),
          CredibilityIndicator(video: video, compact: compact),
        ],
      );
    });
  }

  Widget _buildThreeBandVisualizer({required double maxHeight}) {
    return Obx(() {
      final bands = analysisService.frequencyBands;
      final bass = bands.isNotEmpty ? bands[0] : 0.0;
      final mid = bands.length > 1 ? bands[1] : 0.0;
      final air = bands.length > 2 ? bands[2] : 0.0;
      final peak = analysisService.peakAmplitude.value;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF10121A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.10),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _bandColumn('SUB', bass, const Color(0xFFF59E0B), maxHeight),
            const SizedBox(width: 14),
            _bandColumn('MID', mid, const Color(0xFF10B981), maxHeight),
            const SizedBox(width: 14),
            _bandColumn('AIR', air, const Color(0xFF38BDF8), maxHeight),
            const SizedBox(width: 16),
            _peakMeter(peak, maxHeight),
          ],
        ),
      );
    });
  }

  Widget _bandColumn(String label, double value, Color color, double maxHeight) {
    final height = (maxHeight * value).clamp(3.0, maxHeight);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: maxHeight,
          width: 18,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: height,
              width: 14,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.50),
            fontSize: 8.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _peakMeter(double peak, double maxHeight) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: maxHeight,
          width: 6,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: (maxHeight * peak).clamp(2.0, maxHeight),
              width: 5,
              decoration: BoxDecoration(
                color: peak > 0.85 ? Colors.redAccent : Colors.amberAccent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'PEAK',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.50),
            fontSize: 7.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _StudioGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.02)
      ..strokeWidth = 1.0;

    const step = 24.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
