import 'dart:ui';
import 'package:flutter/material.dart';

/// Semantic corner-radius tokens for rounded borders and shapes.
///
/// `sm`, `md`, `lg`, `xl` return [BorderRadius] objects for direct use in
/// `borderRadius:` parameters. Use `smValue`, `mdValue`, `lgValue`, `xlValue`
/// for the raw [double] values when needed (e.g. `BorderRadius.only(...)`).
class TWRadius extends ThemeExtension<TWRadius> {
  const TWRadius({
    required this.smValue,
    required this.mdValue,
    required this.lgValue,
    required this.xlValue,
  });

  factory TWRadius.defaults() {
    return const TWRadius(
      smValue: 4,
      mdValue: 8,
      lgValue: 12,
      xlValue: 24,
    );
  }
  final double smValue;
  final double mdValue;
  final double lgValue;
  final double xlValue;

  // Convenience getters returning BorderRadius for direct widget use
  BorderRadius get sm => BorderRadius.circular(smValue);
  BorderRadius get md => BorderRadius.circular(mdValue);
  BorderRadius get lg => BorderRadius.circular(lgValue);
  BorderRadius get xl => BorderRadius.circular(xlValue);

  BorderRadius get circularSm => sm;
  BorderRadius get circularMd => md;
  BorderRadius get circularLg => lg;
  BorderRadius get circularXl => xl;

  @override
  ThemeExtension<TWRadius> copyWith({
    double? smValue,
    double? mdValue,
    double? lgValue,
    double? xlValue,
  }) {
    return TWRadius(
      smValue: smValue ?? this.smValue,
      mdValue: mdValue ?? this.mdValue,
      lgValue: lgValue ?? this.lgValue,
      xlValue: xlValue ?? this.xlValue,
    );
  }

  @override
  ThemeExtension<TWRadius> lerp(ThemeExtension<TWRadius>? other, double t) {
    if (other is! TWRadius) return this;
    return TWRadius(
      smValue: lerpDouble(smValue, other.smValue, t)!,
      mdValue: lerpDouble(mdValue, other.mdValue, t)!,
      lgValue: lerpDouble(lgValue, other.lgValue, t)!,
      xlValue: lerpDouble(xlValue, other.xlValue, t)!,
    );
  }
}

extension TWRadiusExtension on BuildContext {
  TWRadius get radius => Theme.of(this).extension<TWRadius>()!;
  TWRadius get twRadius => Theme.of(this).extension<TWRadius>()!;
}
