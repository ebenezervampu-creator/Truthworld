import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Theme 8: Celestial Orbit
/// Deep space celestial acoustic experience with floating artwork orb,
/// delicate planetary orbital rings, drifting stardust particles, and clean typography.
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
    final channel = widget.video?.channelName.isNotEmpty == true
        ? widget.video!.channelName
        : 'Celestial Soundscapes';
    final thumb = widget.video?.thumbnailUrl ?? '';

    return Stack(
      fit: StackFit.expand,
      children: [
        // Deep Cosmos Void
        const ColoredBox(color: Color(0xFF06060A)),

        // Soft Ambient Stardust Glow
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 0.9,
              colors: [
                const Color(0xFF1E1B4B).withValues(alpha: 0.15),
                Colors.black.withValues(alpha: 0.8),
                const Color(0xFF06060A),
              ],
              stops: const [0.0, 0.65, 1.0],
            ),
          ),
        ),

        // Rotating Orbital Ring with Celestial Satellites
        AnimatedBuilder(
          animation: _orbitController,
          builder: (context, _) {
            final t = _orbitController.value * 2 * pi;
            return CustomPaint(
              size: Size.infinite,
              painter: _CelestialOrbitPainter(
                angle: t,
                isPlaying: widget.isPlaying,
              ),
            );
          },
        ),

        // Center Stage Celestial Orb & Typography
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Floating Celestial Artwork Orb
                  Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF121218),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.7),
                          blurRadius: 28,
                          offset: const Offset(0, 10),
                        ),
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.06),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: thumb.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: thumb,
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) => _fallbackOrb(),
                              placeholder: (_, _) => _fallbackOrb(),
                            )
                          : _fallbackOrb(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Frosted Celestial Badge
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
                      'CELESTIAL ORBIT',
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
                      color: Colors.white.withValues(alpha: 0.65),
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

  Widget _fallbackOrb() {
    return Container(
      color: const Color(0xFF14141E),
      child: const Center(
        child: Icon(
          Icons.brightness_medium_rounded,
          size: 34,
          color: Colors.white70,
        ),
      ),
    );
  }
}

class _CelestialOrbitPainter extends CustomPainter {
  _CelestialOrbitPainter({
    required this.angle,
    required this.isPlaying,
  });

  final double angle;
  final bool isPlaying;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final orbitRadius = min(size.width, size.height) * 0.38;

    // Delicate Elliptical Orbit Track
    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(center, orbitRadius, trackPaint);

    // Orbiting Stardust Satellites
    final satellitePositions = [
      angle,
      angle + pi * 0.65,
      angle + pi * 1.35,
    ];

    final dotPaint = Paint()..color = Colors.white.withValues(alpha: isPlaying ? 0.85 : 0.4);
    final glowPaint = Paint()
      ..color = Colors.white.withValues(alpha: isPlaying ? 0.25 : 0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    for (final pos in satellitePositions) {
      final offset = Offset(
        center.dx + orbitRadius * cos(pos),
        center.dy + orbitRadius * sin(pos),
      );
      canvas.drawCircle(offset, 4.0, glowPaint);
      canvas.drawCircle(offset, 2.0, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CelestialOrbitPainter oldDelegate) {
    return oldDelegate.angle != angle || oldDelegate.isPlaying != isPlaying;
  }
}
