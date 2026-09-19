import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/video/presentation/views/upload/widgets/topic_selection/topic_selection_components.dart';
import 'package:truthworld/theme/app_theme.dart';

export 'package:truthworld/features/video/presentation/views/upload/widgets/topic_selection/topic_selection_components.dart';

/// Dynamic Smart Topic Selection & Video Saving Component.
/// Ranks topics dynamically using Firebase Cloud Functions / Smart Recommendation Engine
/// specifically for the active video's title, category, description, and tags.
/// Adheres strictly to AppTheme, AppTextStyles, White Icons Rule, and responsive design.
class TopicSelectionBottomSheet extends StatelessWidget {
  const TopicSelectionBottomSheet({
    required this.controller,
    required this.onCreateNewTopicRequested,
    super.key,
    this.onTopicSelected,
  });

  final dynamic controller;
  final Function(bool isDark) onCreateNewTopicRequested;
  final Function(Topic? topic)? onTopicSelected;

  /// Present as modal bottom sheet
  static void show(
    BuildContext context,
    dynamic controller, {
    required Function(bool isDark) onCreateNewTopic,
    Function(Topic? topic)? onTopicSelected,
  }) {
    if (controller != null && controller.topicSearchQuery != null) {
      controller.topicSearchQuery.value = '';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TopicSelectionBottomSheet(
        controller: controller,
        onCreateNewTopicRequested: onCreateNewTopic,
        onTopicSelected: onTopicSelected,
      ),
    );
  }

  /// Present as centered popup dialog
  static Future<void> showPopupDialog(
    BuildContext context,
    dynamic controller, {
    required Function(bool isDark) onCreateNewTopic,
    Function(Topic? topic)? onTopicSelected,
  }) async {
    if (controller != null && controller.topicSearchQuery != null) {
      controller.topicSearchQuery.value = '';
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860, maxHeight: 780),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Material(
              color: isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF8FAFC),
              child: TopicSelectionBottomSheet(
                controller: controller,
                onCreateNewTopicRequested: onCreateNewTopic,
                onTopicSelected: onTopicSelected,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF8FAFC);
    final borderColor =
        isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor =
        isDark ? AppColors.textSecondary : const Color(0xFF64748B);

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            children: [
              // Top Drag Handle & Header Toolbar
              TopicSelectionTopHeader(
                isDark: isDark,
                textColor: textColor,
                subtextColor: subtextColor,
                borderColor: borderColor,
                controller: controller,
              ),

              // Search Input & Action Bar
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: TopicSelectionSearchBar(
                  isDark: isDark,
                  textColor: textColor,
                  subtextColor: subtextColor,
                  borderColor: borderColor,
                  controller: controller,
                  onCreateNewTopicRequested: onCreateNewTopicRequested,
                ),
              ),

              // Scrollable Content
              Expanded(
                child: Obx(() {
                  final isLoading =
                      controller?.isTopicsLoading?.value as bool? ?? false;
                  if (isLoading) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Recommending best topics for your video...',
                            style: AppTextStyles.bodyMedium
                                .copyWith(color: subtextColor),
                          ),
                        ],
                      ),
                    );
                  }

                  final query =
                      (controller?.topicSearchQuery?.value as String? ?? '')
                          .trim()
                          .toLowerCase();
                  final allTopics = List<Topic>.from(
                    controller?.availableTopics as Iterable? ?? [],
                  );

                  // Rank topics dynamically for the video
                  final rankedMatches =
                      TopicRecommendationEngine.computeRankedTopicMatches(
                    controller,
                    allTopics,
                  );

                  // Filter topics by user query
                  final filteredMatches = rankedMatches.where((match) {
                    if (query.isEmpty) return true;
                    final t = match.topic;
                    if (t.title.toLowerCase().contains(query)) return true;
                    if (t.slug.toLowerCase().contains(query)) return true;
                    if (t.handle.toLowerCase().contains(query)) return true;
                    if (t.category.toLowerCase().contains(query)) return true;
                    if (t.description.toLowerCase().contains(query)) {
                      return true;
                    }
                    return false;
                  }).toList();

                  final selectedId =
                      controller?.selectedTopicId?.value as String? ?? '';

                  // Top Hero Topic (#1 Recommendation for this video)
                  TopicMatchInfo? featuredMatch;
                  if (selectedId.isNotEmpty) {
                    featuredMatch = rankedMatches.firstWhereOrNull(
                      (m) =>
                          m.topic.slug == selectedId ||
                          m.topic.id == selectedId,
                    );
                  }
                  featuredMatch ??= filteredMatches.isNotEmpty
                      ? filteredMatches.first
                      : (rankedMatches.isNotEmpty ? rankedMatches.first : null);

                  final hasDraft = controller?.newTopicData != null &&
                      (controller.newTopicData as Map).isNotEmpty;

                  return ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                    children: [
                      // "None" Topic Option Chip
                      TopicNoneOptionChip(
                        isDark: isDark,
                        textColor: textColor,
                        subtextColor: subtextColor,
                        borderColor: borderColor,
                        controller: controller,
                        onTopicSelected: onTopicSelected,
                      ),
                      const SizedBox(height: 16),

                      // Draft Topic Option Card (if active draft exists)
                      if (hasDraft) ...[
                        TopicDraftOptionCard(
                          isDark: isDark,
                          borderColor: borderColor,
                          controller: controller,
                        ),
                        const SizedBox(height: 16),
                      ],

                      // 1. TOP HERO CONTAINER (#1 Recommended Topic for this Video)
                      if (featuredMatch != null && query.isEmpty) ...[
                        TopicHeroCard(
                          match: featuredMatch,
                          isSelected: selectedId == featuredMatch.topic.slug ||
                              selectedId == featuredMatch.topic.id,
                          isDark: isDark,
                          textColor: textColor,
                          subtextColor: subtextColor,
                          borderColor: borderColor,
                          controller: controller,
                          onTopicSelected: onTopicSelected,
                        ),
                        const SizedBox(height: 24),
                      ],

                      // 2. MIDDLE SECTION HEADER
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add this video to another topic',
                              style: AppTextStyles.headlineSmall.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Topics ranked by relevance for your video',
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 13,
                                color: subtextColor,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 3. TOPIC CARDS LIST (Ranked topics below section header)
                      if (filteredMatches.isEmpty)
                        TopicSelectionEmptyState(
                          query: query,
                          textColor: textColor,
                          subtextColor: subtextColor,
                          isDark: isDark,
                          borderColor: borderColor,
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredMatches.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final match = filteredMatches[index];
                            final isSelected = selectedId ==
                                    match.topic.slug ||
                                selectedId == match.topic.id;
                            return TopicListItemCard(
                              match: match,
                              isSelected: isSelected,
                              isDark: isDark,
                              textColor: textColor,
                              subtextColor: subtextColor,
                              borderColor: borderColor,
                              controller: controller,
                              onTopicSelected: onTopicSelected,
                            );
                          },
                        ),
                    ],
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }
}
