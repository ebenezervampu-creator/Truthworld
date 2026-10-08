import 'dart:math';
import 'package:flutter/material.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Theme 10: Fluid Horizon Wave
/// Silky harmonic ribbon waves flowing across the lower horizon with clean typography and ample control clearance.
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

    return Stack(
      fit: StackFit.expand,
      children: [
        // Dark Obsidian Horizon
        const ColoredBox(color: Color(0xFF090A0F)),

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

        // Center Content (Sits comfortably above the lower wave)
        Center(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 40, left: 24, right: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF818CF8).withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Text(
                    'FLUID HORIZON ACOUSTIC',
                    style: TextStyle(
                      color: Color(0xFFA5B4FC),
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  channel,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
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
    final baseY = size.height * 0.75;
    final t = isPlaying ? time : 0.0;

    // Layer 1: Soft Cyan/Blue Wave
    final path1 = Path()..moveTo(0, size.height);
    for (var x = 0.0; x <= size.width; x += 10) {
      final u = x / size.width;
      final y = baseY + sin(u * 2 * pi + t) * 16 + cos(u * 4 * pi - t * 0.6) * 10;
      path1.lineTo(x, y);
    }
    path1.lineTo(size.width, size.height);
    path1.close();

    final paint1 = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0x3306B6D4), Color(0x333B82F6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, baseY - 30, size.width, size.height - baseY + 30));
    canvas.drawPath(path1, paint1);

    // Layer 2: Luminous Violet Ribbon
    final path2 = Path();
    var first = true;
    for (var x = 0.0; x <= size.width; x += 6) {
      final u = x / size.width;
      final y = baseY + sin(u * 3 * pi - t * 1.2) * 12 + cos(u * 2 * pi + t * 0.8) * 8;
      if (first) {
        path2.moveTo(x, y);
        first = false;
      } else {
        path2.lineTo(x, y);
      }
    }

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..shader = const LinearGradient(
        colors: [Color(0xFF38BDF8), Color(0xFFA855F7), Color(0xFFEC4899)],
      ).createShader(Rect.fromLTWH(0, baseY - 20, size.width, 40));

    canvas.drawPath(path2, strokePaint);
  }

  @override
  bool shouldRepaint(_FluidRibbonPainter oldDelegate) {
    return oldDelegate.time != time || oldDelegate.isPlaying != isPlaying;
  }
}
