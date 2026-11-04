import 'package:get/get.dart';
import 'package:truthworld/core/constants/app_categories.dart';
import 'package:truthworld/core/services/user_languages_service.dart';
import 'package:truthworld/features/search/data/models/search_result.dart';
import 'package:truthworld/features/video/data/models/ai_features.dart';

/// Ranks and sorts search results locally using multi-factor relevance scoring.
class SearchResultRanker {
  const SearchResultRanker();

  /// Sort results locally using multi-factor relevance ranking, including primary language prioritization.
  List<SearchResult> rankAndSortResults(
    List<SearchResult> results,
    String rawQuery, {
    String? userPrimaryLanguage,
    List<String>? secondaryLanguages,
  }) {
    final query = rawQuery.toLowerCase().trim();
    if (query.isEmpty) return results;

    final effectivePrimary = userPrimaryLanguage ??
        (Get.isRegistered<UserLanguagesService>()
            ? UserLanguagesService.to.primaryLanguage.value
            : null);
    final targetCode = (effectivePrimary != null && effectivePrimary.isNotEmpty)
        ? normalizeLanguageCode(effectivePrimary)
        : null;

    final secondaries = secondaryLanguages ??
        (Get.isRegistered<UserLanguagesService>()
            ? UserLanguagesService.to.secondaryLanguages.toList()
            : const []);
    final secondaryCodes =
        secondaries.map(normalizeLanguageCode).toSet();

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

      // 7. Fact-Checking Priority Boost (10 High-Credibility Categories)
      // Prioritizes fact-checked videos over normal/unverified videos for search results.
      if (item.type == ResultType.video &&
          item.category != null &&
          AppCategories.isFactCheckRelevant(item.category!)) {
        if (item.isFactChecked || item.trustScore >= 3.5) {
          score += 45.0; // Major priority push for fact-checked content
          if (item.trustScore >= 4.0) {
            score += 15.0; // Extra bonus for exceptional credibility
          }
        } else if (item.trustScore > 0.0 && item.trustScore < 2.0) {
          score -= 30.0; // Demote low-credibility/flagged content
        }
      }

      // 8. Primary Language Relevance Boost
      if (targetCode != null &&
          item.language != null &&
          item.language!.trim().isNotEmpty) {
        final itemLangCode = normalizeLanguageCode(item.language);
        if (itemLangCode == targetCode) {
          score += 35.0; // Major priority push for matching user's primary language
        } else if (secondaryCodes.contains(itemLangCode)) {
          score += 15.0; // Secondary/known language boost
        }
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
