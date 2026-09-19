import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';

/// Topic Recommendation Item helper representing ranking, score, and justification.
class TopicMatchInfo {
  const TopicMatchInfo({
    required this.topic,
    required this.matchPercentage,
    required this.reason,
    required this.isTopRecommendation,
  });

  final Topic topic;
  final int matchPercentage;
  final String reason;
  final bool isTopRecommendation;
}

/// Recommendation and selection logic engine for topic assignment during video upload.
class TopicRecommendationEngine {
  const TopicRecommendationEngine._();

  /// Calculates dynamic topic recommendations for the active video.
  static List<TopicMatchInfo> computeRankedTopicMatches(
    dynamic controller,
    List<Topic> topics,
  ) {
    if (topics.isEmpty) return [];

    try {
      if (controller != null) {
        final ranked = controller.getRankedTopicsForCurrentVideo?.call();
        if (ranked != null && ranked.isNotEmpty) {
          final results = <TopicMatchInfo>[];
          for (var i = 0; i < ranked.length; i++) {
            final r = ranked[i];
            results.add(
              TopicMatchInfo(
                topic: r.topic as Topic,
                matchPercentage: r.matchPercentage as int,
                reason: r.recommendationReason as String,
                isTopRecommendation: i == 0,
              ),
            );
          }
          return results;
        }
      }
    } catch (e, s) {
      if (e is! NoSuchMethodError) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'TopicRecommendationEngine.computeRankedTopicMatches',
        );
      }
    }

    // Smart fallback recommendation ranking
    final videoTitle =
        (controller?.titleController?.text as String? ?? '').trim().toLowerCase();
    final videoCat =
        (controller?.selectedCategory?.value as String? ?? '').trim().toLowerCase();

    final fallback = <TopicMatchInfo>[];
    for (var i = 0; i < topics.length; i++) {
      final t = topics[i];
      final topicCat = t.category.toLowerCase();
      var score = 70;
      var reason = 'Suggested topic knowledge hub';

      if (videoCat.isNotEmpty &&
          (videoCat == topicCat ||
              videoCat.contains(topicCat) ||
              topicCat.contains(videoCat))) {
        score += 25;
        reason = 'Category match (${t.category})';
      }

      if (videoTitle.isNotEmpty &&
          t.title.toLowerCase().split(' ').any(
                (w) => w.length > 3 && videoTitle.contains(w),
              )) {
        score += 15;
        reason = 'Matches video title keywords';
      }

      final pct = score.clamp(64, 98);
      fallback.add(
        TopicMatchInfo(
          topic: t,
          matchPercentage: pct,
          reason: reason,
          isTopRecommendation: false,
        ),
      );
    }

    fallback.sort((a, b) => b.matchPercentage.compareTo(a.matchPercentage));
    if (fallback.isNotEmpty) {
      return List<TopicMatchInfo>.generate(fallback.length, (index) {
        final item = fallback[index];
        return TopicMatchInfo(
          topic: item.topic,
          matchPercentage: item.matchPercentage,
          reason: item.reason,
          isTopRecommendation: index == 0,
        );
      });
    }
    return fallback;
  }

  /// Helper to format date string e.g. "Aug 14, 2026".
  static String formatTopicDate(DateTime? dateTime) {
    final dt = dateTime ?? DateTime.now();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  /// Handles selection of an authentic Topic.
  static void handleTopicSelection(
    BuildContext context,
    dynamic controller,
    Topic topic,
    Function(Topic? topic)? onTopicSelected,
  ) {
    if (controller?.selectTopic != null) {
      controller.selectTopic(topic.slug.isNotEmpty ? topic.slug : topic.id);
    } else if (controller?.selectedTopicId != null) {
      controller.selectedTopicId.value =
          topic.slug.isNotEmpty ? topic.slug : topic.id;
    }
    if (controller?.newTopicData != null) {
      controller.newTopicData.clear();
    }
    if (onTopicSelected != null) {
      onTopicSelected(topic);
    }
    HapticFeedback.lightImpact();
    Navigator.pop(context);
  }

  /// Handles deselecting / removing topic association.
  static void handleNoneTopicSelection(
    BuildContext context,
    dynamic controller,
    Function(Topic? topic)? onTopicSelected,
  ) {
    if (controller?.selectTopic != null) {
      controller.selectTopic('');
    } else if (controller?.selectedTopicId != null) {
      controller.selectedTopicId.value = '';
    }
    if (controller?.newTopicData != null) {
      controller.newTopicData.clear();
    }
    if (onTopicSelected != null) {
      onTopicSelected(null);
    }
    HapticFeedback.lightImpact();
    Navigator.pop(context);
  }

  /// Handles choosing an in-progress draft topic.
  static void handleDraftTopicSelection(
    BuildContext context,
    dynamic controller,
  ) {
    if (controller?.selectTopic != null) {
      controller.selectTopic('new_topic_draft');
    } else if (controller?.selectedTopicId != null) {
      controller.selectedTopicId.value = 'new_topic_draft';
    }
    HapticFeedback.lightImpact();
    Navigator.pop(context);
  }
}
