import 'dart:ui';
import 'package:flutter/material.dart';

/// Semantic corner-radius tokens for rounded borders and shapes.
class TWRadius extends ThemeExtension<TWRadius> {
  final double sm;
  final double md;
  final double lg;
  final double xl;

  const TWRadius({
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
  });

  factory TWRadius.defaults() {
    return const TWRadius(
      sm: 4.0,
      md: 8.0,
      lg: 12.0,
      xl: 24.0,
    );
  }

  // Helper properties to avoid wrapping BorderRadius.circular manually in UI code
  BorderRadius get circularSm => BorderRadius.circular(sm);
  BorderRadius get circularMd => BorderRadius.circular(md);
  BorderRadius get circularLg => BorderRadius.circular(lg);
  BorderRadius get circularXl => BorderRadius.circular(xl);

  @override
  ThemeExtension<TWRadius> copyWith({
    double? sm,
    double? md,
    double? lg,
    double? xl,
  }) {
    return TWRadius(
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
      xl: xl ?? this.xl,
    );
  }

  @override
  ThemeExtension<TWRadius> lerp(ThemeExtension<TWRadius>? other, double t) {
    if (other is! TWRadius) return this;
    return TWRadius(
      sm: lerpDouble(sm, other.sm, t)!,
      md: lerpDouble(md, other.md, t)!,
      lg: lerpDouble(lg, other.lg, t)!,
      xl: lerpDouble(xl, other.xl, t)!,
    );
  }
}

extension TWRadiusExtension on BuildContext {
  TWRadius get radius => Theme.of(this).extension<TWRadius>()!;
}
