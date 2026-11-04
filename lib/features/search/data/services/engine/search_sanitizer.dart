/// Utility for sanitizing search queries and extracting alphanumeric tokens.
class SearchSanitizer {
  SearchSanitizer._();

  static final RegExp _whitespaceRegExp = RegExp(r'\s+');
  static final RegExp _trailingPunctuationRegExp = RegExp(r'[\p{P}\p{S}\s]+$', unicode: true);
  static final RegExp _leadingPunctuationRegExp = RegExp(r'^[\p{P}\p{S}\s]+', unicode: true);
  static final RegExp _nonWordNonDigitRegExp = RegExp(r'[^\p{L}\p{M}\p{N}]', unicode: true);

  /// Strips trailing and leading punctuation marks (. ? ! , ; : - _) and collapses whitespace
  static String sanitizeQuery(String query) {
    var cleaned = query.trim().replaceAll(_whitespaceRegExp, ' ');
    cleaned = cleaned.replaceAll(_trailingPunctuationRegExp, '').trim();
    cleaned = cleaned.replaceAll(_leadingPunctuationRegExp, '').trim();
    return cleaned.toLowerCase();
  }

  /// Extracts clean alphanumeric search tokens without punctuation
  static List<String> extractTokens(String query) {
    return query
        .toLowerCase()
        .split(_whitespaceRegExp)
        .map((t) => t.replaceAll(_nonWordNonDigitRegExp, '').trim())
        .where((t) => t.isNotEmpty)
        .toList();
  }
}
