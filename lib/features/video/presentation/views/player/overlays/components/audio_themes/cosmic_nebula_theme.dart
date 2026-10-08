import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Theme 8: Cosmic Nebula Orbit
/// Celestial planetary orb, orbiting stardust particles, and deep galaxy nebula pulses.
class CosmicNebulaTheme extends StatefulWidget {
  const CosmicNebulaTheme({
    required this.isPlaying,
    this.video,
    super.key,
  });

  final bool isPlaying;
  final Video? video;

  @override
  State<CosmicNebulaTheme> createState() => _CosmicNebulaThemeState();
}

class _CosmicNebulaThemeState extends State<CosmicNebulaTheme>
    with SingleTickerProviderStateMixin {
  late final AnimationController _orbitController;

  @override
  void initState() {
    super.initState();
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
    if (widget.isPlaying) {
      _orbitController.repeat();
    }
  }

  @override
  void didUpdateWidget(CosmicNebulaTheme oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _orbitController.repeat();
      } else {
        _orbitController.stop();
      }
    }
  }

  @override
  void dispose() {
    _orbitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.video?.title.isNotEmpty == true
        ? widget.video!.title
        : 'TruthWorld Deep Space';
    final thumb = widget.video?.thumbnailUrl ?? '';

    return Stack(
      fit: StackFit.expand,
      children: [
        // Deep Cosmos Void
        const ColoredBox(color: Color(0xFF05050A)),

        // Nebula Cloud Pulsing
        AnimatedBuilder(
          animation: _orbitController,
          builder: (context, _) {
            final t = _orbitController.value * 2 * pi;
            return Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  top: -40,
                  right: -40,
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF3B82F6).withValues(
                        alpha: 0.15 + 0.08 * sin(t),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -50,
                  left: -50,
                  child: Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF8B5CF6).withValues(
                        alpha: 0.16 + 0.07 * cos(t),
                      ),
                    ),
                  ),
                ),
                // Orbiting Stardust Rings
                CustomPaint(
                  size: Size.infinite,
                  painter: _CosmicOrbitPainter(
                    angle: t,
                    isPlaying: widget.isPlaying,
                  ),
                ),
              ],
            );
          },
        ),

        // Center Planetary Orb
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 95,
                height: 95,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF60A5FA).withValues(alpha: 0.6),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.45),
                      blurRadius: 28,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: thumb.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: thumb,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => _cosmicFallback(),
                          placeholder: (_, _) => _cosmicFallback(),
                        )
                      : _cosmicFallback(),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF60A5FA).withValues(alpha: 0.3),
                  ),
                ),
                child: const Text(
                  'COSMIC NEBULA ORBIT',
                  style: TextStyle(
                    color: Color(0xFF93C5FD),
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 4),
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
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _cosmicFallback() {
    return const ColoredBox(
      color: Color(0xFF1E1B4B),
      child: Center(
        child: Icon(Icons.public_rounded, color: Color(0xFF93C5FD), size: 40),
      ),
    );
  }
}

class _CosmicOrbitPainter extends CustomPainter {
  _CosmicOrbitPainter({required this.angle, required this.isPlaying});
  final double angle;
  final bool isPlaying;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 12);
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0xFF60A5FA).withValues(alpha: 0.2);

    // Orbit ellipse
    final rect = Rect.fromCenter(center: center, width: 230, height: 80);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-pi / 9); // Tilted planetary plane
    canvas.translate(-center.dx, -center.dy);
    canvas.drawOval(rect, ringPaint);

    // Orbiting Moon / Satellite Particle
    if (isPlaying) {
      final particleX = center.dx + cos(angle) * 115;
      final particleY = center.dy + sin(angle) * 40;
      final moonPaint = Paint()..color = const Color(0xFF93C5FD);
      final moonGlow = Paint()
        ..color = const Color(0xFF60A5FA).withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

      canvas.drawCircle(Offset(particleX, particleY), 6.0, moonGlow);
      canvas.drawCircle(Offset(particleX, particleY), 3.0, moonPaint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CosmicOrbitPainter oldDelegate) {
    return oldDelegate.angle != angle || oldDelegate.isPlaying != isPlaying;
  }
}
