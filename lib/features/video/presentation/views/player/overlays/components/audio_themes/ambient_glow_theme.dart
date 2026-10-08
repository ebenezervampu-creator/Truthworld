import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Theme 1: Ambient Studio Glow
/// Vibrant blurred backdrop with breathing audio halo, elevated artwork, and rhythmic spectrum bars.
class AmbientGlowTheme extends StatefulWidget {
  const AmbientGlowTheme({
    required this.isPlaying,
    this.video,
    super.key,
  });

  final bool isPlaying;
  final Video? video;

  @override
  State<AmbientGlowTheme> createState() => _AmbientGlowThemeState();
}

class _AmbientGlowThemeState extends State<AmbientGlowTheme>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(AmbientGlowTheme oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.video?.title.isNotEmpty == true
        ? widget.video!.title
        : 'TruthWorld Audio Experience';
    final channel = widget.video?.channelName.isNotEmpty == true
        ? widget.video!.channelName
        : 'TruthWorld Creator';
    final thumb = widget.video?.thumbnailUrl ?? '';

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Dynamic Ambient Aura ─────────────────────────────────────
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value * 2 * pi;
            final scale1 = 1.0 + 0.15 * sin(t);
            final scale2 = 1.0 + 0.18 * cos(t + 1.2);

            return Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Color(0xFF0A0A0E)),
                // Blurred Radial Gradient 1
                Positioned(
                  top: -60,
                  left: -60,
                  child: Transform.scale(
                    scale: scale1,
                    child: Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.22),
                      ),
                    ),
                  ),
                ),
                // Blurred Radial Gradient 2
                Positioned(
                  bottom: -60,
                  right: -60,
                  child: Transform.scale(
                    scale: scale2,
                    child: Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF9333EA).withValues(alpha: 0.18),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),

        // ── Center Stage Artwork & Info ──────────────────────────────
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Elevated Artwork Card
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
                        blurRadius: 28,
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.7),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: thumb.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: thumb,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) => _fallbackCover(),
                            placeholder: (_, _) => _fallbackCover(),
                          )
                        : _fallbackCover(),
                  ),
                ),

                const SizedBox(width: 20),

                // Metadata & Mini Spectrum
                Flexible(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFA855F7).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFFA855F7).withValues(alpha: 0.4),
                            ),
                          ),
                          child: const Text(
                            'NOW PLAYING AUDIO',
                            style: TextStyle(
                              color: Color(0xFFC084FC),
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          channel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Animated soundwave bars
                        _RhythmicVisualizerBars(
                          animation: _controller,
                          isPlaying: widget.isPlaying,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _fallbackCover() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF312E81), Color(0xFF581C87)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.music_note_rounded,
          size: 40,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _RhythmicVisualizerBars extends StatelessWidget {
  const _RhythmicVisualizerBars({
    required this.animation,
    required this.isPlaying,
  });

  final Animation<double> animation;
  final bool isPlaying;

  static const _barHeights = [
    0.35, 0.75, 1.0, 0.55, 0.85, 0.3, 0.95, 0.5, 0.7, 0.45, 0.9, 0.65, 0.4,
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value * 2 * pi;
        return SizedBox(
          height: 22,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(_barHeights.length, (i) {
              final baseH = _barHeights[i];
              final wave = isPlaying
                  ? (0.3 + 0.7 * ((sin(t * 2.5 + i * 0.8) + 1.0) / 2.0))
                  : 0.25;
              final h = (baseH * wave).clamp(0.18, 1.0) * 22;

              return Container(
                width: 3.5,
                height: h,
                margin: const EdgeInsets.only(right: 3.5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF818CF8), Color(0xFFC084FC)],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
