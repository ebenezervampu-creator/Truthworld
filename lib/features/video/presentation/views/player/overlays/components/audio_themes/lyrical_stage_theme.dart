import 'package:flutter/material.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Theme 4: Lyrical Karaoke Stage
/// Prominent time-synced lyrics focus with Apple Music style typography and subtle glowing backdrop.
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
    final hasLyrics = currentSubtitle.trim().isNotEmpty;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Backdrop
        const ColoredBox(color: Color(0xFF0F0818)),
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              radius: 0.85,
              colors: [
                const Color(0xFF7E22CE).withValues(alpha: 0.18),
                Colors.black,
              ],
            ),
          ),
        ),

        // Center Stage Lyrical Presentation
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Tag
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isPlaying
                            ? const Color(0xFFA855F7)
                            : Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Active Lyric Display
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF581C87).withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFA855F7).withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7E22CE).withValues(alpha: 0.25),
                        blurRadius: 20,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Text(
                    hasLyrics ? currentSubtitle : '♪ Listening to audio track ♪',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                      height: 1.3,
                      shadows: [
                        Shadow(
                          color: Color(0xAA000000),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                Text(
                  'SYNCED AUDIO LYRICS',
                  style: TextStyle(
                    color: const Color(0xFFC084FC).withValues(alpha: 0.7),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
