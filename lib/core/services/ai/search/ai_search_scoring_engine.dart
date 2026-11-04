import 'package:get/get.dart';
import 'package:truthworld/core/constants/app_categories.dart';
import 'package:truthworld/core/services/ai/models/ai_search_intent.dart';
import 'package:truthworld/core/services/user_languages_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/search/data/models/search_result.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/video/data/models/ai_features.dart';

/// Relevance scoring engine for channels, topics, and search results against AI search intents.
class AiSearchScoringEngine {
  const AiSearchScoringEngine();

  // ==========================================================================
  // CHANNEL SCORING & RELEVANCE RANKING
  // ==========================================================================

  /// Scores a channel against the parsed AI intent
  /// Returns 0.0 if not a match, or a positive relevance score.
  double scoreChannel(
    Channel channel,
    AiSearchIntent intent, {
    String? userPrimaryLanguage,
  }) {
    // Check exclusions first
    final lowerName = channel.name.toLowerCase();
    final lowerHandle = channel.handle.toLowerCase();
    final lowerDesc = channel.description.toLowerCase();
    final lowerCat = channel.category.toLowerCase();
    final lowerCats = channel.categories.map((c) => c.toLowerCase()).toList();
    final channelLang = channel.language.toLowerCase().trim();

    for (final excluded in intent.excludedTerms) {
      final exc = excluded.toLowerCase();
      if (lowerName.contains(exc) ||
          lowerHandle.contains(exc) ||
          lowerDesc.contains(exc)) {
        return 0.0;
      }
    }

    var score = 0.0;

    // 1. Language matching
    if (intent.detectedLanguage != null &&
        intent.detectedLanguage!.isNotEmpty) {
      final lang = intent.detectedLanguage!.toLowerCase();
      final langCode = intent.detectedLanguageCode?.toLowerCase() ?? '';

      final isLangMatch =
          channelLang == lang ||
          channelLang == langCode ||
          (channelLang.contains(lang) || channelLang.contains(langCode)) ||
          lowerName.contains(lang) ||
          lowerDesc.contains(lang);

      if (isLangMatch) {
        score += 50.0;
      } else {
        // Strict language filter: if query explicitly specified a language,
        // channels that don't match the language are excluded
        return 0.0;
      }
    } else {
      final userPrimary = (userPrimaryLanguage != null &&
              userPrimaryLanguage.trim().isNotEmpty)
          ? userPrimaryLanguage.trim()
          : (Get.isRegistered<UserLanguagesService>()
              ? UserLanguagesService.to.primaryLanguage.value
              : null);
      if (userPrimary != null &&
          userPrimary.isNotEmpty &&
          channelLang.isNotEmpty) {
        final targetCode = normalizeLanguageCode(userPrimary);
        final cLangCode = normalizeLanguageCode(channelLang);
        if (cLangCode == targetCode) {
          score += 25.0; // Primary language preference boost for channel
        }
      }
    }

    // 2. Semantic concepts & keywords
    final allTokens = intent.allTokens;
    var matchCount = 0;

    for (final token in allTokens) {
      final tok = token.toLowerCase();
      if (tok.length < 3) continue;
      final regex = RegExp(r'\b' + RegExp.escape(tok) + r'\b');

      if (regex.hasMatch(lowerName)) {
        score += 35.0;
        matchCount++;
      } else if (regex.hasMatch(lowerHandle)) {
        score += 25.0;
        matchCount++;
      } else if (lowerCat == tok || lowerCats.contains(tok)) {
        score += 30.0;
        matchCount++;
      } else if (regex.hasMatch(lowerDesc)) {
        score += 15.0;
        matchCount++;
      }
    }

    // If query has semantic tokens but none matched, channel is not relevant
    if (allTokens.isNotEmpty && matchCount == 0) {
      return 0.0;
    }

    // 3. Category match boost
    if (intent.detectedCategory != null &&
        intent.detectedCategory!.isNotEmpty) {
      final cat = intent.detectedCategory!.toLowerCase();
      if (lowerCat == cat || lowerCats.contains(cat)) {
        score += 25.0;
      }
    }

    // 4. Result Mode Adjustments (Decoupled: Quality 15%, Activity 10%, Audience 5%)
    if (intent.resultMode == SearchResultMode.ranked) {
      // Quality signal (verified badge / trust)
      if (channel.isVerified) score += 15.0;
      // Activity signal (catalog size / consistency)
      score += (channel.videoCount > 0
          ? (channel.videoCount.toDouble() / 100.0).clamp(0.0, 10.0)
          : 0.0);
      // Audience size (popularity)
      score += (channel.subscriberCount > 0
          ? (channel.subscriberCount.toDouble() / 50000.0).clamp(0.0, 5.0)
          : 0.0);
    }

    return score > 0 ? score : 0.0;
  }

  // ==========================================================================
  // TOPIC SCORING & RELEVANCE RANKING
  // ==========================================================================

  /// Scores a topic against the parsed AI intent
  double scoreTopic(Topic topic, AiSearchIntent intent) {
    final lowerTitle = topic.name.toLowerCase();
    final lowerSlug = topic.slug.toLowerCase();
    final lowerDesc = topic.description.toLowerCase();
    final lowerCat = topic.category.toLowerCase();
    final lowerTags = topic.tags.map((t) => t.toLowerCase()).toList();

    for (final excluded in intent.excludedTerms) {
      final exc = excluded.toLowerCase();
      if (lowerTitle.contains(exc) || lowerDesc.contains(exc)) {
        return 0.0;
      }
    }

    var score = 0.0;
    final allTokens = intent.allTokens;
    var matchCount = 0;

    // Subdomains match is highest relevance
    for (final sub in intent.subdomains) {
      final lowerSub = sub.toLowerCase();
      if (lowerTitle.contains(lowerSub) || lowerSlug.contains(lowerSub)) {
        score += 45.0;
        matchCount++;
      }
    }

    for (final token in allTokens) {
      final tok = token.toLowerCase();
      if (tok.length < 3) continue;
      final regex = RegExp(r'\b' + RegExp.escape(tok) + r'\b');

      if (regex.hasMatch(lowerTitle)) {
        score += 35.0;
        matchCount++;
      } else if (regex.hasMatch(lowerSlug)) {
        score += 30.0;
        matchCount++;
      } else if (lowerCat == tok || lowerCat.contains(tok)) {
        score += 25.0;
        matchCount++;
      } else if (lowerTags.any((t) => t == tok || regex.hasMatch(t))) {
        score += 20.0;
        matchCount++;
      } else if (regex.hasMatch(lowerDesc)) {
        score += 15.0;
        matchCount++;
      }
    }

    if (allTokens.isNotEmpty && matchCount == 0) {
      return 0.0;
    }

    if (intent.detectedCategory != null &&
        intent.detectedCategory!.isNotEmpty) {
      if (lowerCat == intent.detectedCategory!.toLowerCase()) {
        score += 20.0;
      }
    }

    if (intent.resultMode == SearchResultMode.ranked) {
      score += (topic.videoCount.toDouble() * 2.0).clamp(0.0, 30.0);
      score += topic.trendingScore.clamp(0.0, 20.0);
    }

    return score > 0 ? score : 0.0;
  }

  // ==========================================================================
  // SEARCH RESULT SCORING & RELEVANCE RANKING
  // ==========================================================================

  /// Scores any SearchResult (video, channel, topic, playlist) against the parsed AI intent
  /// Returns 0.0 if not a match, or a positive relevance score.
  double scoreSearchResult(
    SearchResult item,
    AiSearchIntent intent, {
    String? userPrimaryLanguage,
  }) {
    final lowerTitle = item.title.toLowerCase();
    final lowerChannel = item.channelName.toLowerCase();
    final lowerCat = (item.category ?? '').toLowerCase();
    final itemLang = (item.language ?? '').toLowerCase().trim();

    // 1. Check exclusions first (negation handling)
    for (final excluded in intent.excludedTerms) {
      final exc = excluded.toLowerCase();
      if (lowerTitle.contains(exc) ||
          lowerChannel.contains(exc) ||
          lowerCat.contains(exc)) {
        return 0.0;
      }
    }

    var score = 0.0;

    // 2. Language matching
    if (intent.detectedLanguage != null &&
        intent.detectedLanguage!.isNotEmpty) {
      final lang = intent.detectedLanguage!.toLowerCase();
      final langCode = intent.detectedLanguageCode?.toLowerCase() ?? '';

      final isExplicitMatch =
          itemLang == lang ||
          itemLang == langCode ||
          (itemLang.isNotEmpty &&
              (itemLang.contains(lang) || itemLang.contains(langCode))) ||
          lowerTitle.contains(lang) ||
          lowerChannel.contains(lang);

      if (isExplicitMatch) {
        score += 50.0;
      } else {
        // Strict language filter: if query explicitly specified a language,
        // results that don't match the language are excluded
        return 0.0;
      }
    } else {
      final userPrimary = (userPrimaryLanguage != null &&
              userPrimaryLanguage.trim().isNotEmpty)
          ? userPrimaryLanguage.trim()
          : (Get.isRegistered<UserLanguagesService>()
              ? UserLanguagesService.to.primaryLanguage.value
              : null);
      if (userPrimary != null &&
          userPrimary.isNotEmpty &&
          itemLang.isNotEmpty) {
        final targetCode = normalizeLanguageCode(userPrimary);
        final itemLangCode = normalizeLanguageCode(itemLang);
        if (itemLangCode == targetCode) {
          score += 30.0; // Primary language preference boost for search result
        }
      }
    }

    // 3. Subdomains match (highest relevance boost)
    for (final sub in intent.subdomains) {
      final lowerSub = sub.toLowerCase();
      if (lowerTitle.contains(lowerSub) || lowerChannel.contains(lowerSub)) {
        score += 40.0;
      }
    }

    // 4. Semantic concepts & keywords
    final allTokens = intent.allTokens;
    var matchCount = 0;

    for (final token in allTokens) {
      final tok = token.toLowerCase();
      if (tok.length < 3) continue;
      final regex = RegExp(r'\b' + RegExp.escape(tok) + r'\b');

      if (regex.hasMatch(lowerTitle)) {
        score += 35.0;
        matchCount++;
      } else if (regex.hasMatch(lowerChannel)) {
        score += 25.0;
        matchCount++;
      } else if (lowerCat.isNotEmpty &&
          (lowerCat == tok || regex.hasMatch(lowerCat))) {
        score += 20.0;
        matchCount++;
      } else if (lowerTitle.contains(tok)) {
        score += 15.0;
        matchCount++;
      }
    }

    // If query has semantic tokens but none matched, item is not relevant
    if (allTokens.isNotEmpty && matchCount == 0) {
      return 0.0;
    }

    // 5. Category match boost
    if (intent.detectedCategory != null &&
        intent.detectedCategory!.isNotEmpty) {
      final cat = intent.detectedCategory!.toLowerCase();
      if (lowerCat == cat || lowerCat.contains(cat)) {
        score += 25.0;
      }
    }

    // 6. Result Mode Adjustments (Decoupled signals for ranked mode)
    if (intent.resultMode == SearchResultMode.ranked) {
      // Views / Popularity Boost (Log scale)
      if (item.views > 0) {
        score += (item.views.toString().length * 2.0).clamp(0.0, 15.0);
      }
      // Content-type prominence if strong match
      if (score >= 40.0) {
        if (item.type == ResultType.channel) {
          score += 15.0;
        } else if (item.type == ResultType.topic) {
          score += 10.0;
        }
      }
      // Freshness boost (for videos in the last 30 days)
      final daysOld = DateTime.now().difference(item.createdAt.toDate()).inDays;
      if (daysOld >= 0 && daysOld < 30) {
        score += (30 - daysOld) * 0.2;
      }

      // Fact-Checking Priority Boost (10 High-Credibility Categories)
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
    }

    return score > 0 ? score : 0.0;
  }
}
