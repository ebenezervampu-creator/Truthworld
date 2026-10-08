import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Theme 5: Minimalist Zen Aura
/// Harmonic radiating ripples with deep obsidian canvas, ideal for relaxation and distraction-free listening.
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
      duration: const Duration(seconds: 3),
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
    final thumb = widget.video?.thumbnailUrl ?? '';

    return Stack(
      fit: StackFit.expand,
      children: [
        // Pure Obsidian Backdrop
        const ColoredBox(color: Color(0xFF09090B)),

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

        // Center Zen Emblem
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF18181B),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.5),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.25),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: thumb.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: thumb,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => _zenFallback(),
                          placeholder: (_, _) => _zenFallback(),
                        )
                      : _zenFallback(),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                  ),
                ),
                child: const Text(
                  'ZEN HARMONIC MODE',
                  style: TextStyle(
                    color: Color(0xFF34D399),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _zenFallback() {
    return const ColoredBox(
      color: Color(0xFF064E3B),
      child: Center(
        child: Icon(Icons.spa_rounded, color: Color(0xFF34D399), size: 36),
      ),
    );
  }
}

class _ZenRipplesPainter extends CustomPainter {
  _ZenRipplesPainter({required this.progress, required this.isPlaying});

  final double progress;
  final bool isPlaying;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    const ringCount = 3;
    for (var i = 0; i < ringCount; i++) {
      final p = (progress + (i / ringCount)) % 1.0;
      final radius = 55.0 + (p * 85.0);
      final alpha = isPlaying ? ((1.0 - p) * 0.35).clamp(0.0, 0.35) : 0.08;

      paint.color = const Color(0xFF10B981).withValues(alpha: alpha);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_ZenRipplesPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isPlaying != isPlaying;
  }
}
