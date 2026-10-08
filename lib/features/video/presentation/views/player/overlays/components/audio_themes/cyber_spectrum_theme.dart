import 'dart:math';
import 'package:flutter/material.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Theme 3: Cyber Neon Spectrum
/// 32-band real-time multi-band equalizer with gradient neon peaks and futuristic studio vibes.
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
      duration: const Duration(milliseconds: 2500),
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
        : 'TruthWorld Audio Spectrum';

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background
        const ColoredBox(color: Color(0xFF08080C)),
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF061826), Colors.black],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),

        // Center Stage Equalizer & Info
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header Pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFF06B6D4).withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Text(
                    'STUDIO 32-BAND SPECTRUM ANALYZER',
                    style: TextStyle(
                      color: Color(0xFF22D3EE),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
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
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 14),

                // Equalizer Bars Container
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF06B6D4).withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _EqualizerBars(
                        animation: _anim,
                        isPlaying: widget.isPlaying,
                      ),
                      const SizedBox(height: 6),
                      // Frequency scale markers
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _freqLabel('20 Hz'),
                          _freqLabel('250 Hz'),
                          _freqLabel('1 kHz'),
                          _freqLabel('4 kHz'),
                          _freqLabel('20 kHz'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
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
        color: Colors.white.withValues(alpha: 0.45),
        letterSpacing: 0.3,
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
    0.3, 0.45, 0.7, 0.95, 0.8, 0.6, 0.88, 0.4,
    0.65, 1.0, 0.75, 0.5, 0.9, 0.85, 0.6, 0.45,
    0.7, 0.95, 0.8, 0.55, 0.9, 0.4, 0.65, 0.8,
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value * 2 * pi;
        return SizedBox(
          height: 60,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(_barProfile.length, (i) {
              final baseH = _barProfile[i];
              final wave = isPlaying
                  ? (0.2 + 0.8 * ((sin(t * 3.0 + i * 0.5) + 1.0) / 2.0))
                  : 0.15;
              final height = (baseH * wave).clamp(0.12, 1.0) * 58;

              return Container(
                width: 6,
                height: height,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF06B6D4), // Cyan
                      Color(0xFF3B82F6), // Blue
                      Color(0xFFD946EF), // Magenta
                    ],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(2),
                  ),
                  boxShadow: isPlaying && height > 35
                      ? [
                          BoxShadow(
                            color: const Color(0xFFD946EF).withValues(alpha: 0.4),
                            blurRadius: 4,
                          ),
                        ]
                      : null,
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
