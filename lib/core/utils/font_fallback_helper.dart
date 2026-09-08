/// Utility for sanitizing Unicode variation selectors to prevent
/// Flutter Web CanvasKit font fallback lookup errors.
///
/// Flutter Web's CanvasKit fallback engine does not include code point
/// U+FE0F (Variation Selector-16) in its Noto font tables, causing:
/// "Could not find a set of Noto fonts to display all missing characters".
library;

/// Regular expression matching Unicode Variation Selectors (U+FE00 - U+FE0F).
final RegExp _variationSelectorRegex = RegExp(r'[\uFE00-\uFE0F]');

/// Strips Unicode variation selectors (U+FE00 through U+FE0F) from the string.
///
/// This preserves the base character/emoji while removing the invisible
/// variation selector that Flutter Web CanvasKit cannot map to a Noto font.
String stripVariationSelectors(String input) {
  if (input.isEmpty) return input;
  return input.replaceAll(_variationSelectorRegex, '');
}

/// Extension on [String] for safe text and emoji rendering across all platforms.
extension FontFallbackStringExtension on String {
  /// Returns this string with Unicode variation selectors removed.
  String get safeText => stripVariationSelectors(this);

  /// Alias for [safeText] when dealing specifically with emoji strings.
  String get safeEmoji => stripVariationSelectors(this);
}
