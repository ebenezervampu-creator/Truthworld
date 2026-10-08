import 'dart:math';
import 'package:flutter/material.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Theme 7: Analog VU Needle Meters
/// Dual backlit analog meters with ballistic bouncing needles, warm amber glow, and vintage receiver faceplate.
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

    return Stack(
      fit: StackFit.expand,
      children: [
        // Dark Receiver Faceplate
        const ColoredBox(color: Color(0xFF0F0E0C)),

        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Receiver Top Header
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.isPlaying
                          ? const Color(0xFFF59E0B)
                          : Colors.white24,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFD4AF37), // Metallic champagne gold
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Dual VU Meters Housing
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1917),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF78350F).withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD97706).withValues(alpha: 0.15),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: AnimatedBuilder(
                  animation: _anim,
                  builder: (context, _) {
                    final t = _anim.value * 2 * pi;
                    // Dual ballistic physics simulation
                    final leftVal = widget.isPlaying
                        ? (0.35 + 0.45 * sin(t * 2.8).abs() + 0.15 * cos(t * 5.2).abs()).clamp(0.0, 1.0)
                        : 0.05;
                    final rightVal = widget.isPlaying
                        ? (0.30 + 0.50 * sin(t * 2.4 + 0.8).abs() + 0.15 * cos(t * 4.6).abs()).clamp(0.0, 1.0)
                        : 0.05;

                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _singleMeter('CHANNEL L', leftVal),
                        const SizedBox(width: 14),
                        _singleMeter('CHANNEL R', rightVal),
                      ],
                    );
                  },
                ),
              ),

              const SizedBox(height: 8),
              const Text(
                'DUAL BALLISTIC VU MONITOR • CALIBRATED 0 dB = 1.228V RMS',
                style: TextStyle(
                  color: Color(0xFF78716C),
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _singleMeter(String label, double needlePosition) {
    return Container(
      width: 130,
      height: 75,
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7), // Warm backlit dial paper
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF44403C),
          width: 2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background Dial Markings
          CustomPaint(
            size: const Size(130, 75),
            painter: _VuScalePainter(),
          ),
          // Ballistic Needle
          CustomPaint(
            size: const Size(130, 75),
            painter: _VuNeedlePainter(needlePosition: needlePosition),
          ),
          // Channel Label at bottom
          Positioned(
            bottom: 3,
            left: 0,
            right: 0,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF78350F),
                fontSize: 8,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
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
      ..strokeWidth = 1.2
      ..color = const Color(0xFF292524);

    final peakPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = const Color(0xFFDC2626); // Red peak zone

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
  final double needlePosition; // 0.0 to 1.0

  @override
  void paint(Canvas canvas, Size size) {
    final pivot = Offset(size.width / 2, size.height + 15);
    // Angle sweep from -pi * 0.78 to -pi * 0.22
    const startAngle = -pi * 0.78;
    const endAngle = -pi * 0.22;
    final angle = startAngle + (endAngle - startAngle) * needlePosition;

    final length = size.height * 0.92;
    final target = Offset(
      pivot.dx + cos(angle) * length,
      pivot.dy + sin(angle) * length,
    );

    final needlePaint = Paint()
      ..color = needlePosition > 0.85 ? const Color(0xFFDC2626) : const Color(0xFF1C1917)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(pivot, target, needlePaint);

    // Needle pivot cap
    final capPaint = Paint()..color = const Color(0xFF1C1917);
    canvas.drawCircle(pivot, 4.0, capPaint);
  }

  @override
  bool shouldRepaint(_VuNeedlePainter oldDelegate) {
    return oldDelegate.needlePosition != needlePosition;
  }
}
