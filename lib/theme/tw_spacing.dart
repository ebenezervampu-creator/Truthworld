import 'dart:ui';
import 'package:flutter/material.dart';

/// Semantic spacing tokens for layouts, padding, and margins.
class TWSpacing extends ThemeExtension<TWSpacing> {
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
      xxs: 2,
      xs: 4,
      sm: 8,
      md: 16,
      lg: 24,
      xl: 32,
      xxl: 48,
    );
  }
  final double xxs;
  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double xxl;

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
  TWSpacing get twSpacing => Theme.of(this).extension<TWSpacing>()!;
  TWInsets get insets => TWInsets(spacing);
  TWInsets get twInsets => TWInsets(spacing);
}

class TWInsetHelper extends EdgeInsets {
  const TWInsetHelper(super.value) : super.all();

  EdgeInsets get h => EdgeInsets.symmetric(horizontal: left);
  EdgeInsets get v => EdgeInsets.symmetric(vertical: top);
  EdgeInsets get horizontalInsets => EdgeInsets.symmetric(horizontal: left);
  EdgeInsets get verticalInsets => EdgeInsets.symmetric(vertical: top);
  EdgeInsets get topOnly => EdgeInsets.only(top: top);
  EdgeInsets get bottomOnly => EdgeInsets.only(bottom: bottom);
  EdgeInsets get leftOnly => EdgeInsets.only(left: left);
  EdgeInsets get rightOnly => EdgeInsets.only(right: right);
}

class TWInsets {
  const TWInsets(this.spacing);
  final TWSpacing spacing;

  TWInsetHelper get xxs => TWInsetHelper(spacing.xxs);
  TWInsetHelper get xs => TWInsetHelper(spacing.xs);
  TWInsetHelper get sm => TWInsetHelper(spacing.sm);
  TWInsetHelper get md => TWInsetHelper(spacing.md);
  TWInsetHelper get lg => TWInsetHelper(spacing.lg);
  TWInsetHelper get xl => TWInsetHelper(spacing.xl);
  TWInsetHelper get xxl => TWInsetHelper(spacing.xxl);
}
