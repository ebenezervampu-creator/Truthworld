/// Utility for sanitizing search queries and extracting alphanumeric tokens.
class SearchSanitizer {
  SearchSanitizer._();

  static final RegExp _whitespaceRegExp = RegExp(r'\s+');
  static final RegExp _trailingPunctuationRegExp = RegExp(r'[\.\?\!\,\;\:\-_]+$');
  static final RegExp _leadingPunctuationRegExp = RegExp(r'^[\.\?\!\,\;\:\-_]+');
  static final RegExp _nonWordNonDigitRegExp = RegExp(r'[^\w\d]');

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
