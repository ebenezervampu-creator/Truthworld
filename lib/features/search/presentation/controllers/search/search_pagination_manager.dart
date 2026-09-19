import 'package:truthworld/features/search/data/models/search_result.dart';

/// Helper for computing deterministic page slices and pagination boundaries.
class SearchPaginationManager {
  static const int defaultResultsPerPage = 15;

  /// Calculate slice of items for current page and check whether more results exist
  static (List<SearchResult> pageItems, bool hasMore) getPageSlice({
    required List<SearchResult> allItems,
    required int page,
    int resultsPerPage = defaultResultsPerPage,
  }) {
    final startIndex = page * resultsPerPage;
    final endIndex = (page + 1) * resultsPerPage;

    if (startIndex >= allItems.length) {
      return (<SearchResult>[], false);
    }

    final endIndexCapped = endIndex > allItems.length ? allItems.length : endIndex;
    final pageItems = allItems.sublist(startIndex, endIndexCapped);
    final hasMore = endIndexCapped < allItems.length;

    return (pageItems, hasMore);
  }
}
