import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Theme 10: Fluid Horizon Waves
/// Silky harmonic ribbon waves flowing across the lower horizon on deep obsidian,
/// paired with elevated artwork, crisp typography, and comfortable control clearance.
class FluidHorizonTheme extends StatefulWidget {
  const FluidHorizonTheme({
    required this.isPlaying,
    this.video,
    super.key,
  });

  final bool isPlaying;
  final Video? video;

  @override
  State<FluidHorizonTheme> createState() => _FluidHorizonThemeState();
}

class _FluidHorizonThemeState extends State<FluidHorizonTheme>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    if (widget.isPlaying) {
      _waveController.repeat();
    }
  }

  @override
  void didUpdateWidget(FluidHorizonTheme oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _waveController.repeat();
      } else {
        _waveController.stop();
      }
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.video?.title.isNotEmpty == true
        ? widget.video!.title
        : 'TruthWorld Acoustic Horizon';
    final channel = widget.video?.channelName.isNotEmpty == true
        ? widget.video!.channelName
        : 'TruthWorld Audio';
    final thumb = widget.video?.thumbnailUrl ?? '';

    return Stack(
      fit: StackFit.expand,
      children: [
        // Dark Obsidian Horizon
        const ColoredBox(color: Color(0xFF08090C)),

        // Soft Studio Vignette
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 0.95,
              colors: [
                const Color(0xFF1E293B).withValues(alpha: 0.2),
                Colors.black.withValues(alpha: 0.75),
                const Color(0xFF08090C),
              ],
              stops: const [0.0, 0.65, 1.0],
            ),
          ),
        ),

        // Lower Fluid Ribbon Waves
        AnimatedBuilder(
          animation: _waveController,
          builder: (context, _) {
            final t = _waveController.value * 2 * pi;
            return CustomPaint(
              size: Size.infinite,
              painter: _FluidRibbonPainter(
                time: t,
                isPlaying: widget.isPlaying,
              ),
            );
          },
        ),

        // Center Content (Comfortably elevated above lower waves)
        Center(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 32, left: 24, right: 24),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (thumb.isNotEmpty) ...[
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.6),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(13),
                          child: CachedNetworkImage(
                            imageUrl: thumb,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) => const SizedBox.shrink(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Frosted Status Badge
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.waves_rounded,
                            size: 11,
                            color: widget.isPlaying ? Colors.white : Colors.white38,
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            'FLUID HORIZON',
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
        ),
      ],
    );
  }
}

class _FluidRibbonPainter extends CustomPainter {
  _FluidRibbonPainter({required this.time, required this.isPlaying});
  final double time;
  final bool isPlaying;

  @override
  void paint(Canvas canvas, Size size) {
    final baseY = size.height * 0.76;
    final t = isPlaying ? time : 0.0;

    // Layer 1: Soft Translucent Base Wave
    final path1 = Path()..moveTo(0, size.height);
    for (var x = 0.0; x <= size.width; x += 10) {
      final u = x / size.width;
      final y = baseY + sin(u * 2 * pi + t) * 14 + cos(u * 4 * pi - t * 0.6) * 8;
      path1.lineTo(x, y);
    }
    path1.lineTo(size.width, size.height);
    path1.close();

    final paint1 = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.06),
          Colors.white.withValues(alpha: 0.02),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, baseY - 30, size.width, size.height - baseY + 30));
    canvas.drawPath(path1, paint1);

    // Layer 2: Refined Surface Harmonic Crest
    final path2 = Path();
    var first = true;
    for (var x = 0.0; x <= size.width; x += 6) {
      final u = x / size.width;
      final y = baseY + sin(u * 3 * pi - t * 1.1) * 10 + cos(u * 2 * pi + t * 0.7) * 6;
      if (first) {
        path2.moveTo(x, y);
        first = false;
      } else {
        path2.lineTo(x, y);
      }
    }

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: isPlaying ? 0.35 : 0.15);

    canvas.drawPath(path2, strokePaint);
  }

  @override
  bool shouldRepaint(_FluidRibbonPainter oldDelegate) {
    return oldDelegate.time != time || oldDelegate.isPlaying != isPlaying;
  }
}
