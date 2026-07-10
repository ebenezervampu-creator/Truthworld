import 'dart:ui';
import 'package:flutter/material.dart';

/// Semantic spacing tokens for layouts, padding, and margins.
class TWSpacing extends ThemeExtension<TWSpacing> {
  final double xxs;
  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double xxl;

  const TWSpacing({
    required this.xxs,
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
    required this.xxl,
  });

  factory TWSpacing.defaults() {
    return const TWSpacing(
      xxs: 2.0,
      xs: 4.0,
      sm: 8.0,
      md: 16.0,
      lg: 24.0,
      xl: 32.0,
      xxl: 48.0,
    );
  }

  @override
  ThemeExtension<TWSpacing> copyWith({
    double? xxs,
    double? xs,
    double? sm,
    double? md,
    double? lg,
    double? xl,
    double? xxl,
  }) {
    return TWSpacing(
      xxs: xxs ?? this.xxs,
      xs: xs ?? this.xs,
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
      xl: xl ?? this.xl,
      xxl: xxl ?? this.xxl,
    );
  }

  @override
  ThemeExtension<TWSpacing> lerp(ThemeExtension<TWSpacing>? other, double t) {
    if (other is! TWSpacing) return this;
    return TWSpacing(
      xxs: lerpDouble(xxs, other.xxs, t)!,
      xs: lerpDouble(xs, other.xs, t)!,
      sm: lerpDouble(sm, other.sm, t)!,
      md: lerpDouble(md, other.md, t)!,
      lg: lerpDouble(lg, other.lg, t)!,
      xl: lerpDouble(xl, other.xl, t)!,
      xxl: lerpDouble(xxl, other.xxl, t)!,
    );
  }
}

extension TWSpacingExtension on BuildContext {
  TWSpacing get spacing => Theme.of(this).extension<TWSpacing>()!;
}
