import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/ai/models/ai_search_intent.dart';
import 'package:truthworld/features/topics/presentation/controllers/explore_topics_controller.dart';
import 'package:truthworld/features/topics/presentation/pages/explore/explore_topics_constants.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Active AI topic search intent banner displaying intent explanation,
/// topic match count, search mode, and interactive criteria chips.
class ExploreTopicsAiBanner extends StatelessWidget {
  const ExploreTopicsAiBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ExploreTopicsController>();

    return Obx(() {
      final intent = controller.activeAiIntent.value;
      if (intent == null) return const SizedBox.shrink();

      final matchCount = controller.topics.length;

      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.textPrimary.withValues(alpha: 0.12),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: AppColors.textPrimary,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        intent.explanation.isNotEmpty
                            ? intent.explanation
                            : 'AI Topic Search',
                        style: const TextStyle(
                          color: primaryText,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$matchCount topics found • Mode: ${intent.resultMode == SearchResultMode.exhaustive ? "All Topics" : "Top Ranked"}',
                        style: const TextStyle(
                          color: secondaryText,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.textPrimary,
                    size: 18,
                  ),
                  tooltip: 'Clear AI Topic Search',
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    controller.clearAiSearch();
                  },
                ),
              ],
            ),
            if (intent.subdomains.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Subdomains & Related Disciplines:',
                style: TextStyle(
                  color: secondaryText.withValues(alpha: 0.9),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: intent.subdomains.map((sub) {
                  return TopicCriterionChip(
                    label: sub,
                    icon: Icons.bubble_chart_rounded,
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (intent.detectedCategory != null)
                  TopicCriterionChip(
                    label: intent.detectedCategory!,
                    icon: Icons.category_rounded,
                  ),
                if (intent.detectedLanguage != null)
                  TopicCriterionChip(
                    label: intent.detectedLanguage!,
                    icon: Icons.language_rounded,
                  ),
                if (intent.resultMode == SearchResultMode.exhaustive)
                  const TopicCriterionChip(
                    label: 'Exhaustive / All Topics',
                    icon: Icons.all_inclusive_rounded,
                  ),
              ],
            ),
          ],
        ),
      );
    });
  }
}

/// Criterion tag chip showing metadata extracted by AI semantic reasoning.
class TopicCriterionChip extends StatelessWidget {
  const TopicCriterionChip({
    required this.label,
    required this.icon,
    super.key,
  });

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: buttonBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.textPrimary, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: primaryText,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
