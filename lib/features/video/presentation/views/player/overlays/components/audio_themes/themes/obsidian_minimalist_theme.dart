import 'package:flutter/material.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/components/audio_themes/core/audio_theme_interface.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/components/audio_themes/core/audio_theme_responsive.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/components/audio_themes/widgets/audio_artwork.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/components/audio_themes/widgets/audio_metadata.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/components/audio_themes/widgets/audio_progress_rail.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/components/audio_themes/widgets/credibility_indicator.dart';

/// Theme 4: Obsidian Minimalist
/// Pure OLED black (#000000) distraction-free canvas engineered for maximum battery efficiency,
/// reduced glare, and WCAG AAA typography contrast.
/// Serves as the universal fallback for low-power or reduced-motion environments.
class ObsidianMinimalistTheme extends AudioThemeStage {
  const ObsidianMinimalistTheme({
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
            // Pure Deep OLED Black (True Zero Pixel Power Consumption on OLED)
            const ColoredBox(color: Color(0xFF000000)),

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
          borderRadius: 8.0,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CredibilityIndicator(video: video, compact: true),
              const SizedBox(height: 3),
              AudioMetadata(
                title: title,
                channelName: channel,
                titleSize: responsive.titleFontSize,
                channelSize: responsive.channelFontSize,
                textAlign: TextAlign.start,
              ),
              const SizedBox(height: 4),
              AudioProgressRail(
                ctrl: ctrl,
                accentColor: Colors.white,
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
        CredibilityIndicator(video: video),
        SizedBox(height: responsive.spacing),
        AudioArtwork(
          size: responsive.artworkSize,
          thumbnailUrl: thumb,
          borderRadius: 12.0,
        ),
        SizedBox(height: responsive.spacing),
        AudioMetadata(
          title: title,
          channelName: channel,
          titleSize: responsive.titleFontSize,
          channelSize: responsive.channelFontSize,
        ),
        SizedBox(height: responsive.spacing),
        SizedBox(
          width: responsive.maxWidth * 0.75,
          child: AudioProgressRail(
            ctrl: ctrl,
            accentColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
