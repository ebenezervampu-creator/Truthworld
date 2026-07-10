import 'package:flutter/material.dart';

/// Semantic typography roles for TruthWorld.
class TWTypography extends ThemeExtension<TWTypography> {
  static const String brandFamily = 'TruthWorld Sans';
  static const String uiFamily = 'Roboto';

  final TextStyle logo;
  final TextStyle hero;
  final TextStyle display;
  final TextStyle headline;
  final TextStyle title;
  final TextStyle body;
  final TextStyle bodySmall;
  final TextStyle label;
  final TextStyle caption;
  final TextStyle button;
  final TextStyle overline;

  const TWTypography({
    required this.logo,
    required this.hero,
    required this.display,
    required this.headline,
    required this.title,
    required this.body,
    required this.bodySmall,
    required this.label,
    required this.caption,
    required this.button,
    required this.overline,
  });

  /// Factory to generate standard default text styles.
  factory TWTypography.defaults(Color textColor) {
    return TWTypography(
      logo: TextStyle(
        fontFamily: brandFamily,
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: textColor,
        letterSpacing: -1.2,
      ),
      hero: TextStyle(
        fontFamily: brandFamily,
        fontSize: 36,
        fontWeight: FontWeight.bold,
        color: textColor,
        letterSpacing: -1.0,
      ),
      display: TextStyle(
        fontFamily: brandFamily,
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
      headline: TextStyle(
        fontFamily: uiFamily,
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
      title: TextStyle(
        fontFamily: uiFamily,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      body: TextStyle(
        fontFamily: uiFamily,
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: textColor,
      ),
      bodySmall: TextStyle(
        fontFamily: uiFamily,
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: textColor.withValues(alpha: 0.7),
      ),
      label: TextStyle(
        fontFamily: uiFamily,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: textColor,
      ),
      caption: TextStyle(
        fontFamily: uiFamily,
        fontSize: 11,
        fontWeight: FontWeight.normal,
        color: textColor.withValues(alpha: 0.54),
      ),
      button: TextStyle(
        fontFamily: uiFamily,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: textColor,
      ),
      overline: TextStyle(
        fontFamily: uiFamily,
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: textColor.withValues(alpha: 0.6),
        letterSpacing: 1.2,
      ),
    );
  }

  @override
  ThemeExtension<TWTypography> copyWith({
    TextStyle? logo,
    TextStyle? hero,
    TextStyle? display,
    TextStyle? headline,
    TextStyle? title,
    TextStyle? body,
    TextStyle? bodySmall,
    TextStyle? label,
    TextStyle? caption,
    TextStyle? button,
    TextStyle? overline,
  }) {
    return TWTypography(
      logo: logo ?? this.logo,
      hero: hero ?? this.hero,
      display: display ?? this.display,
      headline: headline ?? this.headline,
      title: title ?? this.title,
      body: body ?? this.body,
      bodySmall: bodySmall ?? this.bodySmall,
      label: label ?? this.label,
      caption: caption ?? this.caption,
      button: button ?? this.button,
      overline: overline ?? this.overline,
    );
  }

  @override
  ThemeExtension<TWTypography> lerp(ThemeExtension<TWTypography>? other, double t) {
    if (other is! TWTypography) return this;
    return TWTypography(
      logo: TextStyle.lerp(logo, other.logo, t)!,
      hero: TextStyle.lerp(hero, other.hero, t)!,
      display: TextStyle.lerp(display, other.display, t)!,
      headline: TextStyle.lerp(headline, other.headline, t)!,
      title: TextStyle.lerp(title, other.title, t)!,
      body: TextStyle.lerp(body, other.body, t)!,
      bodySmall: TextStyle.lerp(bodySmall, other.bodySmall, t)!,
      label: TextStyle.lerp(label, other.label, t)!,
      caption: TextStyle.lerp(caption, other.caption, t)!,
      button: TextStyle.lerp(button, other.button, t)!,
      overline: TextStyle.lerp(overline, other.overline, t)!,
    );
  }
}

/// Helper extension to easily access TruthWorld typography from [BuildContext].
extension TWTypographyExtension on BuildContext {
  TWTypography get typography => Theme.of(this).extension<TWTypography>()!;
}
