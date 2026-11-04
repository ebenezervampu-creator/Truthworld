import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Theme 4: Lyrical Stage
/// Apple Music-grade typographic lyric experience with deep obsidian canvas,
/// dynamic blurred artwork ambient lighting, and elegant time-synced presentation.
class LyricalStageTheme extends StatelessWidget {
  const LyricalStageTheme({
    required this.isPlaying,
    required this.currentSubtitle,
    this.video,
    super.key,
  });

  final bool isPlaying;
  final String currentSubtitle;
  final Video? video;

  @override
  Widget build(BuildContext context) {
    final title = video?.title.isNotEmpty == true ? video!.title : 'TruthWorld Audio';
    final channel = video?.channelName.isNotEmpty == true ? video!.channelName : 'TruthWorld Creator';
    final thumb = video?.thumbnailUrl ?? '';
    final hasLyrics = currentSubtitle.trim().isNotEmpty;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Deep Obsidian Canvas
        const ColoredBox(color: Color(0xFF08090C)),

        // Dynamic Artwork Ambient Diffusion
        if (thumb.isNotEmpty)
          Positioned.fill(
            child: Opacity(
              opacity: 0.28,
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: CachedNetworkImage(
                  imageUrl: thumb,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),

        // Dark Luxury Vignette
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.0,
                colors: [
                  Colors.black.withValues(alpha: 0.5),
                  Colors.black.withValues(alpha: 0.85),
                  const Color(0xFF08090C),
                ],
                stops: const [0.0, 0.65, 1.0],
              ),
            ),
          ),
        ),

        // Center Stage Lyrical Presentation
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top Frosted Status Pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.mic_rounded,
                            size: 11,
                            color: isPlaying ? Colors.white : Colors.white38,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            hasLyrics ? 'SYNCED LYRICS' : 'LYRICAL STAGE',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Active Lyric or Song Header
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: hasLyrics
                          ? Container(
                              key: ValueKey(currentSubtitle),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.12),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    blurRadius: 16,
                                  ),
                                ],
                              ),
                              child: Text(
                                currentSubtitle,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  height: 1.35,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            )
                          : Column(
                              key: const ValueKey('no_lyrics'),
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  channel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.65),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
