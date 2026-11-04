import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Theme 3: Studio Acoustic Spectrum
/// Professional studio equalizer with sleek monochromatic/ice-white visualizer bars,
/// smooth harmonic dancing, dynamic audio reflections, and clean metadata.
class CyberSpectrumTheme extends StatefulWidget {
  const CyberSpectrumTheme({
    required this.isPlaying,
    this.video,
    super.key,
  });

  final bool isPlaying;
  final Video? video;

  @override
  State<CyberSpectrumTheme> createState() => _CyberSpectrumThemeState();
}

class _CyberSpectrumThemeState extends State<CyberSpectrumTheme>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    if (widget.isPlaying) {
      _anim.repeat();
    }
  }

  @override
  void didUpdateWidget(CyberSpectrumTheme oldWidget) {
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
    final title = widget.video?.title.isNotEmpty == true
        ? widget.video!.title
        : 'TruthWorld Acoustic Spectrum';
    final channel = widget.video?.channelName.isNotEmpty == true
        ? widget.video!.channelName
        : 'Studio Audio';
    final thumb = widget.video?.thumbnailUrl ?? '';

    return Stack(
      fit: StackFit.expand,
      children: [
        // Deep Charcoal Studio Canvas
        const ColoredBox(color: Color(0xFF090A0D)),

        // Soft Radial Vignette
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 0.9,
              colors: [
                const Color(0xFF1E293B).withValues(alpha: 0.25),
                Colors.black.withValues(alpha: 0.7),
                const Color(0xFF090A0D),
              ],
              stops: const [0.0, 0.65, 1.0],
            ),
          ),
        ),

        // Center Stage Equalizer & Info
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Artwork / Audio Badge
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (thumb.isNotEmpty) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: thumb,
                              width: 32,
                              height: 32,
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) => const SizedBox.shrink(),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
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
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: widget.isPlaying
                                      ? Colors.white
                                      : Colors.white38,
                                ),
                              ),
                              const SizedBox(width: 5),
                              const Text(
                                'STUDIO SPECTRUM',
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
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
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
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Modern Equalizer Glass Stage
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _EqualizerBars(
                            animation: _anim,
                            isPlaying: widget.isPlaying,
                          ),
                          const SizedBox(height: 8),
                          // Minimalist frequency scale markers
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _freqLabel('SUB'),
                              _freqLabel('BASS'),
                              _freqLabel('MID'),
                              _freqLabel('TREBLE'),
                              _freqLabel('AIR'),
                            ],
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

  Widget _freqLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w600,
        color: Colors.white.withValues(alpha: 0.35),
        letterSpacing: 0.6,
      ),
    );
  }
}

class _EqualizerBars extends StatelessWidget {
  const _EqualizerBars({
    required this.animation,
    required this.isPlaying,
  });

  final Animation<double> animation;
  final bool isPlaying;

  static const _barProfile = [
    0.30, 0.45, 0.70, 0.90, 0.80, 0.60, 0.85, 0.45,
    0.65, 0.95, 0.75, 0.50, 0.90, 0.80, 0.60, 0.45,
    0.70, 0.90, 0.80, 0.55, 0.85, 0.45, 0.65, 0.75,
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value * 2 * pi;
        return SizedBox(
          height: 54,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(_barProfile.length, (i) {
              final baseH = _barProfile[i];
              final wave = isPlaying
                  ? (0.2 + 0.8 * ((sin(t * 2.8 + i * 0.48) + 1.0) / 2.0))
                  : 0.15;
              final height = (baseH * wave).clamp(0.12, 1.0) * 52;

              return Container(
                width: 5,
                height: height,
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.4),
                      Colors.white.withValues(alpha: isPlaying ? 0.95 : 0.6),
                    ],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(2.5),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
