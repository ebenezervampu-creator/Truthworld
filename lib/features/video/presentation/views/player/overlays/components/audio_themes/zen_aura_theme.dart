import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Theme 5: Minimalist Zen Flow
/// Harmonic radiating ripples on deep velvet obsidian, designed for distraction-free,
/// tranquil listening with soft pearl/silver acoustic vibrations.
class ZenAuraTheme extends StatefulWidget {
  const ZenAuraTheme({
    required this.isPlaying,
    this.video,
    super.key,
  });

  final bool isPlaying;
  final Video? video;

  @override
  State<ZenAuraTheme> createState() => _ZenAuraThemeState();
}

class _ZenAuraThemeState extends State<ZenAuraTheme>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    if (widget.isPlaying) {
      _pulseController.repeat();
    }
  }

  @override
  void didUpdateWidget(ZenAuraTheme oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _pulseController.repeat();
      } else {
        _pulseController.stop();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.video?.title.isNotEmpty == true
        ? widget.video!.title
        : 'TruthWorld Zen Flow';
    final channel = widget.video?.channelName.isNotEmpty == true
        ? widget.video!.channelName
        : 'Meditation & Acoustic';
    final thumb = widget.video?.thumbnailUrl ?? '';

    return Stack(
      fit: StackFit.expand,
      children: [
        // Pure Obsidian Backdrop
        const ColoredBox(color: Color(0xFF08080B)),

        // Concentric Harmonic Ripples
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, _) {
            final t = _pulseController.value;
            return CustomPaint(
              size: Size.infinite,
              painter: _ZenRipplesPainter(
                progress: t,
                isPlaying: widget.isPlaying,
              ),
            );
          },
        ),

        // Center Zen Emblem & Typography
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Circular Album Art Emblem
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF141418),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: thumb.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: thumb,
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) => _fallbackEmblem(),
                              placeholder: (_, _) => _fallbackEmblem(),
                            )
                          : _fallbackEmblem(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Frosted Zen Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                    ),
                    child: const Text(
                      'ZEN FLOW',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

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
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _fallbackEmblem() {
    return Container(
      color: const Color(0xFF18181C),
      child: const Center(
        child: Icon(
          Icons.spa_rounded,
          size: 32,
          color: Colors.white70,
        ),
      ),
    );
  }
}

class _ZenRipplesPainter extends CustomPainter {
  _ZenRipplesPainter({
    required this.progress,
    required this.isPlaying,
  });

  final double progress;
  final bool isPlaying;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = min(size.width, size.height) * 0.48;

    // 4 harmonic concentric ripple waves
    for (int i = 0; i < 4; i++) {
      final waveProgress = (progress + (i / 4.0)) % 1.0;
      final radius = 54.0 + (maxRadius - 54.0) * waveProgress;
      final alpha = isPlaying
          ? (1.0 - waveProgress) * 0.12
          : 0.04;

      final paint = Paint()
        ..color = Colors.white.withValues(alpha: alpha.clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ZenRipplesPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isPlaying != isPlaying;
  }
}
