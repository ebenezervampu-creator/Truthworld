import 'package:flutter/material.dart';

/// Custom painter for rendering branching reply thread curves and lines.
class ReplyThreadLinePainter extends CustomPainter {
  ReplyThreadLinePainter({
    required this.color,
    required this.isLast,
    required this.branchY,
  });

  final Color color;
  final bool isLast;
  final double branchY;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path();
    if (isLast) {
      path.moveTo(20, 0);
      path.lineTo(20, branchY - 8);
      path.quadraticBezierTo(20, branchY, 28, branchY);
      path.lineTo(size.width, branchY);
    } else {
      path.moveTo(20, 0);
      path.lineTo(20, size.height);
      path.moveTo(20, branchY);
      path.lineTo(size.width, branchY);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant ReplyThreadLinePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.isLast != isLast ||
        oldDelegate.branchY != branchY;
  }
}
