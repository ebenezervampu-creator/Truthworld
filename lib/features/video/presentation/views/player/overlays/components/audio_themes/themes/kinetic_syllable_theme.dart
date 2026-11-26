import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/components/audio_themes/core/audio_theme_interface.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/components/audio_themes/core/audio_theme_responsive.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/components/audio_themes/widgets/credibility_indicator.dart';

/// Theme 2: Kinetic Syllable Stage
/// Real-time sentence and word-synchronized transcript presentation with tap-to-seek navigation.
/// Optimized for high readability across podcasts, interviews, and lyrics with optional credibility context.
class KineticSyllableTheme extends AudioThemeStage {
  const KineticSyllableTheme({
    required super.ctrl,
    required super.analysisService,
    super.video,
    this.currentSubtitle = '',
    super.key,
  });

  final String currentSubtitle;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final responsive = AudioThemeResponsive.fromConstraints(constraints);

        return Stack(
          fit: StackFit.expand,
          children: [
            // Dark Frosted Charcoal Background
            const ColoredBox(color: Color(0xFF0A0B10)),

            // Subtle Top Metadata Header with Credibility Context
            Positioned(
              top: responsive.isCompactHeight ? 8 : 16,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFA78BFA).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFA78BFA).withValues(alpha: 0.35),
                        width: 0.8,
                      ),
                    ),
                    child: const Text(
                      'LIVE TRANSCRIPT',
                      style: TextStyle(
                        color: Color(0xFFA78BFA),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const Spacer(),
                  CredibilityIndicator(video: video, compact: true),
                ],
              ),
            ),

            // Transcript Body Stage
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: responsive.isCompactHeight ? 32 : 50,
                ),
                child: Obx(() {
                  final segments = ctrl.subtitleSegments;
                  final activeSegment = ctrl.activeSubtitleSegment.value;
                  final liveSubtitle = ctrl.currentSubtitle.value.isNotEmpty
                      ? ctrl.currentSubtitle.value
                      : currentSubtitle;

                  if (segments.isNotEmpty) {
                    return _buildSynchronizedSegmentList(
                      segments,
                      activeSegment,
                      responsive,
                    );
                  }

                  if (liveSubtitle.trim().isNotEmpty) {
                    return _buildSingleSubtitleView(liveSubtitle, responsive);
                  }

                  return _buildEmptyTranscriptFallback(responsive);
                }),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSynchronizedSegmentList(
    List<SubtitleSegment> segments,
    SubtitleSegment? activeSegment,
    AudioThemeResponsive responsive,
  ) {
    final activeIndex = activeSegment != null ? segments.indexOf(activeSegment) : -1;

    // Show current segment with previous and next lines for smooth reading flow
    final prevLine = (activeIndex > 0) ? segments[activeIndex - 1].text : '';
    final currentLine = (activeIndex >= 0) ? segments[activeIndex].text : segments.first.text;
    final nextLine = (activeIndex >= 0 && activeIndex < segments.length - 1)
        ? segments[activeIndex + 1].text
        : '';

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (prevLine.isNotEmpty && !responsive.isCompactHeight) ...[
          GestureDetector(
            onTap: () {
              if (activeIndex > 0) ctrl.seekTo(segments[activeIndex - 1].start);
            },
            child: Text(
              prevLine,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFFC5C8D6), // High contrast (WCAG AAA compliant: >11:1 against #0A0B10)
                fontSize: responsive.isCompactHeight ? 12 : 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          SizedBox(height: responsive.spacing),
        ],

        // Active highlighted line
        GestureDetector(
          onTap: () {
            if (activeSegment != null) ctrl.seekTo(activeSegment.start);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
                width: 1.0,
              ),
            ),
            child: Text(
              currentLine,
              maxLines: responsive.isCompactHeight ? 2 : 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: responsive.isCompactHeight ? 15 : 20,
                fontWeight: FontWeight.w700,
                height: 1.3,
                shadows: const [
                  Shadow(
                    color: Colors.black,
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
          ),
        ),

        if (nextLine.isNotEmpty && !responsive.isCompactHeight) ...[
          SizedBox(height: responsive.spacing),
          GestureDetector(
            onTap: () {
              if (activeIndex >= 0 && activeIndex < segments.length - 1) {
                ctrl.seekTo(segments[activeIndex + 1].start);
              }
            },
            child: Text(
              nextLine,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFFC5C8D6), // High contrast (WCAG AAA compliant: >11:1 against #0A0B10)
                fontSize: responsive.isCompactHeight ? 12 : 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSingleSubtitleView(String subtitle, AudioThemeResponsive responsive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.16),
        ),
      ),
      child: Text(
        subtitle,
        maxLines: responsive.isCompactHeight ? 2 : 4,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: responsive.isCompactHeight ? 15 : 18,
          fontWeight: FontWeight.w700,
          height: 1.35,
        ),
      ),
    );
  }

  Widget _buildEmptyTranscriptFallback(AudioThemeResponsive responsive) {
    final title = video?.title ?? 'TruthWorld Audio';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.subtitles_off_rounded,
          size: responsive.isCompactHeight ? 22 : 32,
          color: Colors.white38,
        ),
        const SizedBox(height: 8),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white70,
            fontSize: responsive.titleFontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Synchronizing live transcript stream...',
          style: TextStyle(
            color: Colors.white38,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
