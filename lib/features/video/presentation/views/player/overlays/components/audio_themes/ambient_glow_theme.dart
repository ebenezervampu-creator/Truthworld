import 'dart:math';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Theme 1: Ambient Studio Glow
/// High-end, Spotify & Apple Music-grade ambient acoustic stage.
/// Dynamically diffuses the artwork's authentic palette into a deep, luxurious studio backdrop
/// paired with crisp typography and a silky, rhythmic waveform.
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
        // ── Deep Obsidian Canvas ─────────────────────────────────────
        const ColoredBox(color: Color(0xFF08090C)),

        // ── Dynamic Artwork Ambient Diffusion ───────────────────────
        if (thumb.isNotEmpty)
          Positioned.fill(
            child: Opacity(
              opacity: 0.35,
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 70, sigmaY: 70),
                child: CachedNetworkImage(
                  imageUrl: thumb,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),

        // Dark Luxury Vignette Overlay
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.1,
                colors: [
                  Colors.black.withValues(alpha: 0.4),
                  Colors.black.withValues(alpha: 0.88),
                  const Color(0xFF08090C),
                ],
                stops: const [0.0, 0.65, 1.0],
              ),
            ),
          ),
        ),

        // Subtle Breathing Halo
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value * 2 * pi;
            final haloOpacity = widget.isPlaying
                ? (0.10 + 0.05 * sin(t)).clamp(0.05, 0.18)
                : 0.06;

            return Center(
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: haloOpacity),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: haloOpacity * 0.7),
                      blurRadius: 70,
                      spreadRadius: 20,
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        // ── Center Stage Artwork & Info ──────────────────────────────
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 440;

                final artworkWidget = Container(
                  width: isNarrow ? 110 : 124,
                  height: isNarrow ? 110 : 124,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.16),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(17),
                    child: thumb.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: thumb,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) => _fallbackCover(),
                            placeholder: (_, _) => _fallbackCover(),
                          )
                        : _fallbackCover(),
                  ),
                );

                final metaWidget = Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: isNarrow
                      ? CrossAxisAlignment.center
                      : CrossAxisAlignment.start,
                  children: [
                    // Sleek Frosted Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
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
                          AnimatedBuilder(
                            animation: _controller,
                            builder: (context, _) {
                              final dotOpacity = widget.isPlaying
                                  ? (0.6 + 0.4 * sin(_controller.value * 2 * pi)).clamp(0.2, 1.0)
                                  : 0.4;
                              return Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: dotOpacity),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            'AUDIO ONLY',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: isNarrow ? TextAlign.center : TextAlign.start,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      channel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: isNarrow ? TextAlign.center : TextAlign.start,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Minimalist Waveform Bars
                    _RhythmicVisualizerBars(
                      animation: _controller,
                      isPlaying: widget.isPlaying,
                    ),
                  ],
                );

                if (isNarrow) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      artworkWidget,
                      const SizedBox(height: 14),
                      Flexible(child: metaWidget),
                    ],
                  );
                }

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    artworkWidget,
                    const SizedBox(width: 22),
                    Flexible(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: metaWidget,
                      ),
                    ),
                  ],
                );
              },
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
          colors: [Color(0xFF1E2028), Color(0xFF111216)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.headphones_rounded,
          size: 38,
          color: Colors.white70,
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
    0.35, 0.70, 0.95, 0.55, 0.85, 0.35, 0.90, 0.50, 0.75, 0.45, 0.85, 0.60,
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value * 2 * pi;
        return SizedBox(
          height: 18,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(_barHeights.length, (i) {
              final baseH = _barHeights[i];
              final wave = isPlaying
                  ? (0.3 + 0.7 * ((sin(t * 2.6 + i * 0.75) + 1.0) / 2.0))
                  : 0.22;
              final h = (baseH * wave).clamp(0.18, 1.0) * 18;

              return Container(
                width: 3,
                height: h,
                margin: const EdgeInsets.only(right: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: isPlaying ? 0.85 : 0.4),
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
