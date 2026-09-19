import 'package:truthworld/features/search/data/models/search_result.dart';

/// Ranks and sorts search results locally using multi-factor relevance scoring.
class SearchResultRanker {
  const SearchResultRanker();

  /// Sort results locally using multi-factor relevance ranking
  List<SearchResult> rankAndSortResults(
    List<SearchResult> results,
    String rawQuery,
  ) {
    final query = rawQuery.toLowerCase().trim();
    if (query.isEmpty) return results;

    final tokens = query
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();

    for (final item in results) {
      var score = 0.0;
      final title = item.title.toLowerCase();
      final channel = item.channelName.toLowerCase();

      // 1. Title matching (Exact: 100, Prefix: 80, Substring: 60)
      if (title == query) {
        score += 100.0;
      } else if (title.startsWith(query)) {
        score += 80.0;
      } else if (title.contains(query)) {
        score += 60.0;
      }

      // 2. Channel matching (Exact: 75, Prefix: 55, Substring: 35)
      if (channel == query) {
        score += 75.0;
      } else if (channel.startsWith(query)) {
        score += 55.0;
      } else if (channel.contains(query)) {
        score += 35.0;
      }

      // 3. Multi-token coverage boost (up to 50 points based on ratio of matched words)
      if (tokens.isNotEmpty) {
        var tokenMatches = 0;
        for (final token in tokens) {
          if (title.contains(token) || channel.contains(token)) {
            tokenMatches++;
          }
        }
        final tokenRatio = tokenMatches / tokens.length;
        score += tokenRatio * 50.0;
      }

      // 4. Prominence boost for channels, topics, and playlists when there is a strong match
      if (score >= 60.0) {
        if (item.type == ResultType.channel) {
          score += 25.0; // Place strongly matching channel near the top
        } else if (item.type == ResultType.topic) {
          score += 15.0; // Place strongly matching topic hub prominently
        } else if (item.type == ResultType.playlist) {
          score += 10.0; // Place strongly matching playlist prominently
        }
      }

      // 5. Popularity Boost (Log scale of views)
      if (item.views > 0) {
        score += item.views.toString().length * 2.5;
      }

      // 6. Freshness / Recency Boost
      final daysOld = DateTime.now().difference(item.createdAt.toDate()).inDays;
      if (daysOld >= 0 && daysOld < 30) {
        score += (30 - daysOld) * 0.3;
      }

      item.relevanceScore = score;
    }

    results.sort((a, b) {
      final scoreCompare = b.relevanceScore.compareTo(a.relevanceScore);
      if (scoreCompare != 0) return scoreCompare;
      final viewsCompare = b.views.compareTo(a.views);
      if (viewsCompare != 0) return viewsCompare;
      return b.createdAt.compareTo(a.createdAt);
    });

    return results;
  }
}
