import 'package:flutter/material.dart';

/// Draws threaded connection lines between comments and nested replies.
class ReplyThreadLinePainter extends CustomPainter {
  const ReplyThreadLinePainter({
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
      path.moveTo(10, 0);
      path.lineTo(10, branchY - 4);
      path.quadraticBezierTo(10, branchY, 16, branchY);
      path.lineTo(size.width, branchY);
    } else {
      path.moveTo(10, 0);
      path.lineTo(10, size.height);
      path.moveTo(10, branchY);
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
