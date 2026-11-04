import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/video/presentation/views/upload/widgets/topic_selection/topic_selection_host.dart';

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
    TopicSelectionHost controller,
    List<Topic> topics,
  ) {
    if (topics.isEmpty) return [];

    try {
      final ranked = controller.getRankedTopicsForCurrentVideo();
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
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TopicRecommendationEngine.computeRankedTopicMatches',
      );
    }

    // Smart fallback recommendation ranking
    final videoTitle =
        (controller.titleController?.text ?? '').trim().toLowerCase();
    final videoCat =
        (controller.selectedCategory?.value ?? '').trim().toLowerCase();

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
          t.name.toLowerCase().split(' ').any(
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

  /// Handles selection of an authentic Topic and dismisses sheet.
  static void handleTopicSelection(
    BuildContext context,
    TopicSelectionHost controller,
    Topic topic,
    Function(Topic? topic)? onTopicSelected,
  ) {
    final key = topic.slug.isNotEmpty ? topic.slug : topic.id;
    if (!controller.isTopicSelected(key)) {
      controller.toggleTopicSelection(topic);
    }
    controller.newTopicData.clear();
    if (onTopicSelected != null) {
      onTopicSelected(topic);
    }
    HapticFeedback.lightImpact();
    Navigator.pop(context);
  }

  /// Handles toggling of an authentic Topic for multi-topic selection (keeps sheet open).
  static void handleTopicToggle(
    BuildContext context,
    TopicSelectionHost controller,
    Topic topic,
    Function(Topic? topic)? onTopicSelected,
  ) {
    controller.toggleTopicSelection(topic);
    if (onTopicSelected != null) {
      onTopicSelected(topic);
    }
    HapticFeedback.lightImpact();
  }

  /// Handles deselecting / removing topic association.
  static void handleNoneTopicSelection(
    BuildContext context,
    TopicSelectionHost controller,
    Function(Topic? topic)? onTopicSelected,
  ) {
    controller.selectTopic('');
    controller.newTopicData.clear();
    if (onTopicSelected != null) {
      onTopicSelected(null);
    }
    HapticFeedback.lightImpact();
    Navigator.pop(context);
  }

  /// Handles choosing an in-progress draft topic.
  static void handleDraftTopicSelection(
    BuildContext context,
    TopicSelectionHost controller,
  ) {
    controller.selectTopic('new_topic_draft');
    HapticFeedback.lightImpact();
    Navigator.pop(context);
  }
}
