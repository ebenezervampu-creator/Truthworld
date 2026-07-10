import 'package:flutter/material.dart';

/// Semantic motion and transition tokens.
class TWMotion extends ThemeExtension<TWMotion> {
  final Duration fast;
  final Duration normal;
  final Duration slow;

  final Curve easeIn;
  final Curve easeOut;
  final Curve easeInOut;
  final Curve emphasized;

  const TWMotion({
    required this.fast,
    required this.normal,
    required this.slow,
    required this.easeIn,
    required this.easeOut,
    required this.easeInOut,
    required this.emphasized,
  });

  factory TWMotion.defaults() {
    return const TWMotion(
      fast: Duration(milliseconds: 150),
      normal: Duration(milliseconds: 300),
      slow: Duration(milliseconds: 500),
      easeIn: Curves.easeIn,
      easeOut: Curves.easeOutCubic,
      easeInOut: Curves.easeInOutCubic,
      emphasized: Curves.easeInOutCubic,
    );
  }

  @override
  ThemeExtension<TWMotion> copyWith({
    Duration? fast,
    Duration? normal,
    Duration? slow,
    Curve? easeIn,
    Curve? easeOut,
    Curve? easeInOut,
    Curve? emphasized,
  }) {
    return TWMotion(
      fast: fast ?? this.fast,
      normal: normal ?? this.normal,
      slow: slow ?? this.slow,
      easeIn: easeIn ?? this.easeIn,
      easeOut: easeOut ?? this.easeOut,
      easeInOut: easeInOut ?? this.easeInOut,
      emphasized: emphasized ?? this.emphasized,
    );
  }

  @override
  ThemeExtension<TWMotion> lerp(ThemeExtension<TWMotion>? other, double t) {
    if (other is! TWMotion) return this;
    return TWMotion(
      fast: t < 0.5 ? fast : other.fast,
      normal: t < 0.5 ? normal : other.normal,
      slow: t < 0.5 ? slow : other.slow,
      easeIn: t < 0.5 ? easeIn : other.easeIn,
      easeOut: t < 0.5 ? easeOut : other.easeOut,
      easeInOut: t < 0.5 ? easeInOut : other.easeInOut,
      emphasized: t < 0.5 ? emphasized : other.emphasized,
    );
  }
}

extension TWMotionExtension on BuildContext {
  TWMotion get motion => Theme.of(this).extension<TWMotion>()!;
}
