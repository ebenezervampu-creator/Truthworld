import 'dart:math';
import 'package:flutter/material.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Theme 6: Vintage Reel-to-Reel Tape
/// High-end analog studio master tape machine (Nagra/Studer aesthetic)
/// with precision brushed spools, smooth rotational physics, and clean studio typography.
class VintageCassetteTheme extends StatefulWidget {
  const VintageCassetteTheme({
    required this.isPlaying,
    this.video,
    super.key,
  });

  final bool isPlaying;
  final Video? video;

  @override
  State<VintageCassetteTheme> createState() => _VintageCassetteThemeState();
}

class _VintageCassetteThemeState extends State<VintageCassetteTheme>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spoolController;

  @override
  void initState() {
    super.initState();
    _spoolController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    if (widget.isPlaying) {
      _spoolController.repeat();
    }
  }

  @override
  void didUpdateWidget(VintageCassetteTheme oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _spoolController.repeat();
      } else {
        _spoolController.stop();
      }
    }
  }

  @override
  void dispose() {
    _spoolController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.video?.title.isNotEmpty == true
        ? widget.video!.title
        : 'TruthWorld Master Tape';
    final channel = widget.video?.channelName.isNotEmpty == true
        ? widget.video!.channelName
        : 'Analog Sound Lab';

    return Stack(
      fit: StackFit.expand,
      children: [
        // Dark Studio Canvas
        const ColoredBox(color: Color(0xFF0A0A0D)),

        // Soft Warm Studio Vignette
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 0.95,
              colors: [
                const Color(0xFFD4AF37).withValues(alpha: 0.04),
                Colors.black.withValues(alpha: 0.75),
                const Color(0xFF0A0A0D),
              ],
              stops: const [0.0, 0.65, 1.0],
            ),
          ),
        ),

        // Center Stage Studio Reel Housing
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Container(
                width: 340,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF141418), // Deep brushed titanium
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.7),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Studio Metadata Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Frosted Status Pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
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
                                      ? const Color(0xFFE2E8F0)
                                      : Colors.white38,
                                ),
                              ),
                              const SizedBox(width: 5),
                              const Text(
                                'REEL-TO-REEL',
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
                        Text(
                          widget.isPlaying ? '15 IPS MASTER' : 'STANDBY',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Song Info
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        channel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Dual Rotating Precision Spools
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B0B0E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Magnetic Tape Ribbon Bridge
                          Positioned(
                            top: 30,
                            left: 45,
                            right: 45,
                            height: 6,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF26262B),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _TapeSpool(
                                controller: _spoolController,
                                isPlaying: widget.isPlaying,
                                isLeft: true,
                              ),
                              _TapeSpool(
                                controller: _spoolController,
                                isPlaying: widget.isPlaying,
                                isLeft: false,
                              ),
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
}

class _TapeSpool extends StatelessWidget {
  const _TapeSpool({
    required this.controller,
    required this.isPlaying,
    required this.isLeft,
  });

  final AnimationController controller;
  final bool isPlaying;
  final bool isLeft;

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: controller,
      child: Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF1E1E24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.22),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 10,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Precision 3-spoke metal cutout
            CustomPaint(
              size: const Size(68, 68),
              painter: _SpoolSpokesPainter(),
            ),
            // Center spindle hub
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF101014),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpoolSpokesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < 3; i++) {
      final angle = i * (2 * pi / 3);
      final p1 = Offset(center.dx + 10 * cos(angle), center.dy + 10 * sin(angle));
      final p2 = Offset(center.dx + 28 * cos(angle), center.dy + 28 * sin(angle));
      canvas.drawLine(p1, p2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
