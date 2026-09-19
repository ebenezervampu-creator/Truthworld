import 'package:flutter/material.dart';

/// Custom Painter to draw a clean dashed border around upload dropzones
class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;
  final double dash;
  final double borderRadius;

  DashedBorderPainter({
    this.color = const Color(0xFF3F3F3F),
    this.strokeWidth = 1.5,
    this.gap = 4.0,
    this.dash = 6.0,
    this.borderRadius = 12.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );
    final path = Path()..addRRect(rrect);

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final len = (distance + dash > metric.length)
            ? metric.length - distance
            : dash;
        canvas.drawPath(metric.extractPath(distance, distance + len), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// CustomPainter to overlay YouTube standard safe area zones across a 16:9 Banner canvas.
/// Visualizes:
/// - TV Viewable (Full 16:9 - 2560 x 1440)
/// - Desktop Viewable (2560 x 423 band)
/// - All Devices Safe Area (1546 x 423 box for logos & text)
class YouTubeBannerSafeAreaPainter extends CustomPainter {
  const YouTubeBannerSafeAreaPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Subtle 6% safe content margin for text & logos
    final safeLeft = w * 0.06;
    final safeRight = w * 0.94;
    final safeTop = h * 0.06;
    final safeBottom = h * 0.94;

    // Safe Area boundary
    final safeBorderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.65)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(safeLeft, safeTop, safeRight, safeBottom),
        const Radius.circular(4),
      ),
      safeBorderPaint,
    );

    // Corner brackets
    final cornerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const cornerLength = 12.0;
    // Top-left
    canvas.drawLine(Offset(safeLeft, safeTop), Offset(safeLeft + cornerLength, safeTop), cornerPaint);
    canvas.drawLine(Offset(safeLeft, safeTop), Offset(safeLeft, safeTop + cornerLength), cornerPaint);
    // Top-right
    canvas.drawLine(Offset(safeRight, safeTop), Offset(safeRight - cornerLength, safeTop), cornerPaint);
    canvas.drawLine(Offset(safeRight, safeTop), Offset(safeRight, safeTop + cornerLength), cornerPaint);
    // Bottom-left
    canvas.drawLine(Offset(safeLeft, safeBottom), Offset(safeLeft + cornerLength, safeBottom), cornerPaint);
    canvas.drawLine(Offset(safeLeft, safeBottom), Offset(safeLeft, safeBottom + cornerLength), cornerPaint);
    // Bottom-right
    canvas.drawLine(Offset(safeRight, safeBottom), Offset(safeRight - cornerLength, safeBottom), cornerPaint);
    canvas.drawLine(Offset(safeRight, safeBottom), Offset(safeRight, safeBottom + cornerLength), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Backward compatibility painter alias
class YouTubeDesktopSafeAreaPainter extends YouTubeBannerSafeAreaPainter {
  const YouTubeDesktopSafeAreaPainter();
}

