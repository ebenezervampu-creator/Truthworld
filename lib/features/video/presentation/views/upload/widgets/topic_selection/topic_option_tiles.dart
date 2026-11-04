import 'package:flutter/material.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/video/presentation/views/upload/widgets/topic_selection/topic_match_info.dart';
import 'package:truthworld/features/video/presentation/views/upload/widgets/topic_selection/topic_selection_host.dart';
import 'package:truthworld/theme/app_theme.dart';

/// "None" topic option chip to allow standalone video publishing.
class TopicNoneOptionChip extends StatelessWidget {
  const TopicNoneOptionChip({
    required this.isDark,
    required this.textColor,
    required this.subtextColor,
    required this.borderColor,
    required this.controller,
    super.key,
    this.onTopicSelected,
  });

  final bool isDark;
  final Color textColor;
  final Color subtextColor;
  final Color borderColor;
  final TopicSelectionHost controller;
  final Function(Topic? topic)? onTopicSelected;

  @override
  Widget build(BuildContext context) {
    final selectedId = controller.selectedTopicId.value;
    final hasSelectedTopicIds =
        controller.selectedTopicIds?.isNotEmpty ?? false;
    final newTopicData = controller.newTopicData;
    final isSelected = selectedId.isEmpty &&
        !hasSelectedTopicIds &&
        newTopicData.isEmpty;

    return InkWell(
      onTap: () => TopicRecommendationEngine.handleNoneTopicSelection(
        context,
        controller,
        onTopicSelected,
      ),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0))
              : (isDark ? const Color(0xFF111722) : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFF3B82F6) : borderColor,
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.block_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "None (Don't save video to any topic)",
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: textColor,
                    ),
                  ),
                  Text(
                    'Publish video as a standalone upload',
                    style: AppTextStyles.caption.copyWith(fontSize: 12, color: subtextColor),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Color(0xFF3B82F6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
              ),
          ],
        ),
      ),
    );
  }
}

/// Draft topic card option rendered when an in-progress topic draft exists.
class TopicDraftOptionCard extends StatelessWidget {
  const TopicDraftOptionCard({
    required this.isDark,
    required this.borderColor,
    required this.controller,
    super.key,
  });

  final bool isDark;
  final Color borderColor;
  final TopicSelectionHost controller;

  @override
  Widget build(BuildContext context) {
    final selectedId = controller.selectedTopicId.value;
    final isSelected = selectedId == 'new_topic_draft';
    final newTopicData = controller.newTopicData;
    final title = (newTopicData['name'] as String?) ??
        (newTopicData['title'] as String?) ??
        'Untitled Draft';

    return InkWell(
      onTap: () => TopicRecommendationEngine.handleDraftTopicSelection(
        context,
        controller,
      ),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2D1537) : const Color(0xFFFDF4FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFA855F7),
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFA855F7).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.edit_document, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Draft: $title',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF7E22CE),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFA855F7).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'NEW DRAFT',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Topic will be created upon video publish',
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 12,
                      color: isDark ? const Color(0xFFE9D5FF) : const Color(0xFF6B21A8),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Color(0xFFA855F7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
              ),
          ],
        ),
      ),
    );
  }
}

/// Empty state when no topics match search criteria.
class TopicSelectionEmptyState extends StatelessWidget {
  const TopicSelectionEmptyState({
    required this.query,
    required this.textColor,
    required this.subtextColor,
    required this.isDark,
    required this.borderColor,
    super.key,
  });

  final String query;
  final Color textColor;
  final Color subtextColor;
  final bool isDark;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F141C) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          const Icon(Icons.search_off_rounded, size: 48, color: Colors.white),
          const SizedBox(height: 12),
          Text(
            query.isEmpty ? 'No topics found' : 'No matching topics for "$query"',
            textAlign: TextAlign.center,
            style: AppTextStyles.headlineSmall.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Create a new topic to organize and save your videos.',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(fontSize: 13, color: subtextColor),
          ),
        ],
      ),
    );
  }
}
