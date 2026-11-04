import 'package:flutter/material.dart';

/// Pixel-perfect vector Google 'G' logo component.
/// Renders authentic Google brand colors (Red, Yellow, Green, Blue)
/// with zero external asset dependencies and full resolution independence.
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({
    super.key,
    this.size = 18,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: const _GoogleLogoPainter(),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24.0;
    final paint = Paint()..style = PaintingStyle.fill;

    // 1. Blue path (#4285F4)
    paint.color = const Color(0xFF4285F4);
    final bluePath = Path()
      ..moveTo(23.49 * s, 12.28 * s)
      ..cubicTo(23.49 * s, 11.43 * s, 23.41 * s, 10.6 * s, 23.27 * s, 9.8 * s)
      ..lineTo(12.0 * s, 9.8 * s)
      ..lineTo(12.0 * s, 14.5 * s)
      ..lineTo(18.48 * s, 14.5 * s)
      ..cubicTo(18.19 * s, 15.98 * s, 17.34 * s, 17.23 * s, 16.08 * s, 18.08 * s)
      ..lineTo(19.84 * s, 21.0 * s)
      ..cubicTo(22.04 * s, 18.97 * s, 23.49 * s, 15.98 * s, 23.49 * s, 12.28 * s)
      ..close();
    canvas.drawPath(bluePath, paint);

    // 2. Green path (#34A853)
    paint.color = const Color(0xFF34A853);
    final greenPath = Path()
      ..moveTo(12.0 * s, 24.0 * s)
      ..cubicTo(15.24 * s, 24.0 * s, 17.96 * s, 22.92 * s, 19.84 * s, 21.0 * s)
      ..lineTo(16.08 * s, 18.08 * s)
      ..cubicTo(15.04 * s, 18.78 * s, 13.67 * s, 19.3 * s, 12.0 * s, 19.3 * s)
      ..cubicTo(8.78 * s, 19.3 * s, 6.07 * s, 17.15 * s, 5.19 * s, 14.28 * s)
      ..lineTo(1.53 * s, 17.12 * s)
      ..cubicTo(3.47 * s, 20.96 * s, 7.42 * s, 24.0 * s, 12.0 * s, 24.0 * s)
      ..close();
    canvas.drawPath(greenPath, paint);

    // 3. Yellow path (#FBBC05)
    paint.color = const Color(0xFFFBBC05);
    final yellowPath = Path()
      ..moveTo(5.19 * s, 14.28 * s)
      ..cubicTo(4.97 * s, 13.62 * s, 4.85 * s, 12.92 * s, 4.85 * s, 12.0 * s)
      ..cubicTo(4.85 * s, 11.08 * s, 4.97 * s, 10.38 * s, 5.19 * s, 9.72 * s)
      ..lineTo(1.53 * s, 6.88 * s)
      ..cubicTo(0.56 * s, 8.81 * s, 0.0 * s, 10.36 * s, 0.0 * s, 12.0 * s)
      ..cubicTo(0.0 * s, 13.64 * s, 0.56 * s, 15.19 * s, 1.53 * s, 17.12 * s)
      ..lineTo(5.19 * s, 14.28 * s)
      ..close();
    canvas.drawPath(yellowPath, paint);

    // 4. Red path (#EA4335)
    paint.color = const Color(0xFFEA4335);
    final redPath = Path()
      ..moveTo(12.0 * s, 4.7 * s)
      ..cubicTo(13.76 * s, 4.7 * s, 15.34 * s, 5.3 * s, 16.58 * s, 6.48 * s)
      ..lineTo(20.0 * s, 3.06 * s)
      ..cubicTo(17.96 * s, 1.16 * s, 15.24 * s, 0.0 * s, 12.0 * s, 0.0 * s)
      ..cubicTo(7.42 * s, 0.0 * s, 3.47 * s, 3.04 * s, 1.53 * s, 6.88 * s)
      ..lineTo(5.19 * s, 9.72 * s)
      ..cubicTo(6.07 * s, 6.85 * s, 8.78 * s, 4.7 * s, 12.0 * s, 4.7 * s)
      ..close();
    canvas.drawPath(redPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
