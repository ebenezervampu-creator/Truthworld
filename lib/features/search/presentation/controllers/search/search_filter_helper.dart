import 'package:truthworld/features/search/data/models/search_result.dart';

/// Helper methods for query normalization, validation, and multi-criteria search filtering.
class SearchFilterHelper {
  /// Validate and sanitize raw search query string
  static (bool isValid, String sanitized, String errorMessage) validateQuery(
    String query, {
    int maxSearchQueryLength = 100,
  }) {
    var trimmed = query.trim().replaceAll(RegExp(r'\s+'), ' ');
    trimmed = trimmed.replaceAll(RegExp(r'[\.\?\!\,\;\:\-_]+$'), '').trim();
    trimmed = trimmed.replaceAll(RegExp(r'^[\.\?\!\,\;\:\-_]+'), '').trim();
    trimmed = trimmed.toLowerCase();

    if (trimmed.length > maxSearchQueryLength) {
      trimmed = trimmed.substring(0, maxSearchQueryLength);
    }

    if (trimmed.isEmpty) {
      return (false, '', 'Query cannot be empty');
    }

    return (true, trimmed, '');
  }

  /// Filter search results based on category chip, watched status, upload age, or live stream status
  static List<SearchResult> applyFilter({
    required List<SearchResult> results,
    required String filter,
    required Set<String> watchedVideoIds,
  }) {
    var list = results;

    if (filter == 'Videos') {
      list = list.where((r) => r.type == ResultType.video).toList();
    } else if (filter == 'Channels') {
      list = list.where((r) => r.type == ResultType.channel).toList();
    } else if (filter == 'Playlists') {
      list = list.where((r) => r.type == ResultType.playlist).toList();
    } else if (filter == 'Topics') {
      list = list.where((r) => r.type == ResultType.topic).toList();
    }

    if (filter == 'Watched') {
      list = list.where((r) => r.type != ResultType.video || watchedVideoIds.contains(r.id)).toList();
    } else if (filter == 'Unwatched') {
      list = list.where((r) => r.type != ResultType.video || !watchedVideoIds.contains(r.id)).toList();
    }

    if (filter == 'Recently uploaded') {
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      list = list.where((r) => r.type != ResultType.video || r.uploadedAt.isAfter(sevenDaysAgo)).toList();
    }

    if (filter == 'Live') {
      list = list.where((r) => r.type != ResultType.video || r.title.toLowerCase().contains('live')).toList();
    }

    return list;
  }
}
