import 'dart:ui';
import 'package:flutter/material.dart';

/// Semantic corner-radius tokens for rounded borders and shapes.
///
/// `sm`, `md`, `lg`, `xl` return [BorderRadius] objects for direct use in
/// `borderRadius:` parameters. Use `smValue`, `mdValue`, `lgValue`, `xlValue`
/// for the raw [double] values when needed (e.g. `BorderRadius.only(...)`).
class TWRadius extends ThemeExtension<TWRadius> {
  static const double smVal = 4.0;
  static const double mdVal = 8.0;
  static const double lgVal = 12.0;
  static const double xlVal = 16.0;
  static const double xxlVal = 24.0;
  static const double pillVal = 999.0;

  static final BorderRadius smBorderRadius = BorderRadius.circular(smVal);
  static final BorderRadius mdBorderRadius = BorderRadius.circular(mdVal);
  static final BorderRadius lgBorderRadius = BorderRadius.circular(lgVal);
  static final BorderRadius xlBorderRadius = BorderRadius.circular(xlVal);
  static final BorderRadius xxlBorderRadius = BorderRadius.circular(xxlVal);
  static final BorderRadius pillBorderRadius = BorderRadius.circular(pillVal);

  const TWRadius({
    required this.smValue,
    required this.mdValue,
    required this.lgValue,
    required this.xlValue,
    this.xxlValue = xxlVal,
    this.pillValue = pillVal,
  });

  factory TWRadius.defaults() {
    return const TWRadius(
      smValue: smVal,
      mdValue: mdVal,
      lgValue: lgVal,
      xlValue: xlVal,
    );
  }
  final double smValue;
  final double mdValue;
  final double lgValue;
  final double xlValue;
  final double xxlValue;
  final double pillValue;

  // Convenience getters returning BorderRadius for direct widget use
  BorderRadius get sm => BorderRadius.circular(smValue);
  BorderRadius get md => BorderRadius.circular(mdValue);
  BorderRadius get lg => BorderRadius.circular(lgValue);
  BorderRadius get xl => BorderRadius.circular(xlValue);
  BorderRadius get xxl => BorderRadius.circular(xxlValue);
  BorderRadius get pill => BorderRadius.circular(pillValue);

  BorderRadius get circularSm => sm;
  BorderRadius get circularMd => md;
  BorderRadius get circularLg => lg;
  BorderRadius get circularXl => xl;
  BorderRadius get circularXxl => xxl;
  BorderRadius get circularPill => pill;

  @override
  ThemeExtension<TWRadius> copyWith({
    double? smValue,
    double? mdValue,
    double? lgValue,
    double? xlValue,
    double? xxlValue,
    double? pillValue,
  }) {
    return TWRadius(
      smValue: smValue ?? this.smValue,
      mdValue: mdValue ?? this.mdValue,
      lgValue: lgValue ?? this.lgValue,
      xlValue: xlValue ?? this.xlValue,
      xxlValue: xxlValue ?? this.xxlValue,
      pillValue: pillValue ?? this.pillValue,
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
      xxlValue: lerpDouble(xxlValue, other.xxlValue, t)!,
      pillValue: lerpDouble(pillValue, other.pillValue, t)!,
    );
  }
}

extension TWRadiusExtension on BuildContext {
  TWRadius get radius =>
      Theme.of(this).extension<TWRadius>() ?? TWRadius.defaults();
  TWRadius get twRadius =>
      Theme.of(this).extension<TWRadius>() ?? TWRadius.defaults();
}
