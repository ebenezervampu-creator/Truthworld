import 'package:flutter/material.dart';

/// Represents the result of a typography measurement
class TypographyMeasurement {

  TypographyMeasurement({
    required this.width,
    required this.height,
    required this.lineCount,
  });
  final double width;
  final double height;
  final int lineCount;

  @override
  String toString() => 'TypographyMeasurement(width: $width, height: $height, lineCount: $lineCount)';
}

/// Utility class for measuring text dimensions without rendering
class TypographyUtils {
  /// Measures the dimensions of a text block given a specific style and constraints.
  /// 
  /// Useful for:
  /// * Dynamic card sizing
  /// * Adaptive typography
  /// * Read-time estimation
  /// * Overflow prediction
  /// * Accessibility analytics
  static TypographyMeasurement measureText({
    required String text,
    required TextStyle style,
    double maxWidth = double.infinity,
    int? maxLines,
    TextDirection textDirection = TextDirection.ltr,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: textDirection,
      maxLines: maxLines,
    )..layout(maxWidth: maxWidth);

    return TypographyMeasurement(
      width: textPainter.width,
      height: textPainter.height,
      lineCount: textPainter.computeLineMetrics().length,
    );
  }
}
