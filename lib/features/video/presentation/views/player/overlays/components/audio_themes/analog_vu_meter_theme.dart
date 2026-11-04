import 'dart:math';
import 'package:flutter/material.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Theme 7: Precision VU Meters
/// Ultra-luxury high-end Hi-Fi studio analog meters (McIntosh/Yamaha A-S3200 aesthetic)
/// with deep dark glass dial faces, crisp scale markings, and smooth ballistic needle response.
class AnalogVuMeterTheme extends StatefulWidget {
  const AnalogVuMeterTheme({
    required this.isPlaying,
    this.video,
    super.key,
  });

  final bool isPlaying;
  final Video? video;

  @override
  State<AnalogVuMeterTheme> createState() => _AnalogVuMeterThemeState();
}

class _AnalogVuMeterThemeState extends State<AnalogVuMeterTheme>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    if (widget.isPlaying) {
      _anim.repeat();
    }
  }

  @override
  void didUpdateWidget(AnalogVuMeterTheme oldWidget) {
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
        : 'TruthWorld Analog Master';
    final channel = widget.video?.channelName.isNotEmpty == true
        ? widget.video!.channelName
        : 'Precision Audio Lab';

    return Stack(
      fit: StackFit.expand,
      children: [
        // Dark Studio Faceplate
        const ColoredBox(color: Color(0xFF090A0D)),

        // Soft Radial Vignette
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 0.95,
              colors: [
                const Color(0xFFD4AF37).withValues(alpha: 0.04),
                Colors.black.withValues(alpha: 0.75),
                const Color(0xFF090A0D),
              ],
              stops: const [0.0, 0.65, 1.0],
            ),
          ),
        ),

        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header Badge
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
                                  ? const Color(0xFFE2E8F0)
                                  : Colors.white38,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            'PRECISION VU METERS',
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
                    const SizedBox(height: 10),

                    // Song Info
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
                    const SizedBox(height: 16),

                    // Dual VU Meters Housing
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF121318), // Deep obsidian glass
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.7),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: AnimatedBuilder(
                        animation: _anim,
                        builder: (context, _) {
                          final t = _anim.value * 2 * pi;
                          final leftVal = widget.isPlaying
                              ? (0.35 + 0.40 * sin(t * 2.8).abs() + 0.12 * cos(t * 5.2).abs()).clamp(0.0, 1.0)
                              : 0.05;
                          final rightVal = widget.isPlaying
                              ? (0.30 + 0.44 * sin(t * 2.4 + 0.8).abs() + 0.12 * cos(t * 4.6).abs()).clamp(0.0, 1.0)
                              : 0.05;

                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _singleMeter('CHANNEL L', leftVal),
                              const SizedBox(width: 12),
                              _singleMeter('CHANNEL R', rightVal),
                            ],
                          );
                        },
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

  Widget _singleMeter(String label, double needlePosition) {
    return Container(
      width: 140,
      height: 82,
      decoration: BoxDecoration(
        color: const Color(0xFF181920), // Dark glass dial face
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background Dial Markings
          CustomPaint(
            size: const Size(140, 82),
            painter: _VuScalePainter(),
          ),
          // Ballistic Needle
          CustomPaint(
            size: const Size(140, 82),
            painter: _VuNeedlePainter(needlePosition: needlePosition),
          ),
          // Channel Label at bottom
          Positioned(
            bottom: 5,
            left: 0,
            right: 0,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 8,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VuScalePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.white.withValues(alpha: 0.25);

    final peakPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0xFFEF4444).withValues(alpha: 0.8); // Subtle crimson peak

    final center = Offset(size.width / 2, size.height + 15);
    final radius = size.height * 0.95;

    // Normal arc (-20 to 0 dB)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi * 0.78,
      pi * 0.40,
      false,
      arcPaint,
    );

    // Peak arc (0 to +3 dB)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi * 0.38,
      pi * 0.16,
      false,
      peakPaint,
    );
  }

  @override
  bool shouldRepaint(_VuScalePainter oldDelegate) => false;
}

class _VuNeedlePainter extends CustomPainter {
  _VuNeedlePainter({required this.needlePosition});
  final double needlePosition;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height + 15);
    final length = size.height * 0.92;

    // Angle sweep: -pi * 0.76 (left ~ -20dB) to -pi * 0.24 (right ~ +3dB)
    final angle = -pi * 0.76 + needlePosition * (pi * 0.52);

    final needlePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final target = Offset(
      center.dx + length * cos(angle),
      center.dy + length * sin(angle),
    );

    canvas.drawLine(center, target, needlePaint);

    // Needle pivot hub
    final hubPaint = Paint()..color = const Color(0xFF26262B);
    final hubBorder = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawCircle(center, 7, hubPaint);
    canvas.drawCircle(center, 7, hubBorder);
  }

  @override
  bool shouldRepaint(covariant _VuNeedlePainter oldDelegate) {
    return oldDelegate.needlePosition != needlePosition;
  }
}
