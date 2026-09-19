import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/ai/models/ai_search_intent.dart';
import 'package:truthworld/features/discover/presentation/controllers/discover_channels_controller.dart';
import 'package:truthworld/features/discover/presentation/views/channels/widgets/discover_channels_constants.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Banner displaying active AI search query interpretation, detected criteria chips, and broadening options.
class DiscoverAiBanner extends StatelessWidget {
  const DiscoverAiBanner({
    required this.controller,
    super.key,
  });

  final DiscoverChannelsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final intent = controller.activeAiIntent.value;
      if (intent == null) {
        return const SizedBox.shrink();
      }
      final matchCount = controller.channels.length;
      final isBroadened = controller.isBroadenedView.value;

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
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isBroadened
                            ? 'Showing broadened Christian channels across languages'
                            : (intent.explanation.isNotEmpty
                                ? intent.explanation
                                : 'AI Search Active'),
                        style: const TextStyle(
                          color: primaryText,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$matchCount channels found • Mode: ${intent.resultMode == SearchResultMode.exhaustive ? "All Channels" : "Top Ranked"}',
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
                    color: Colors.white,
                    size: 18,
                  ),
                  tooltip: 'Clear AI Search',
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    controller.clearAiSearch();
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (intent.detectedLanguage != null)
                  DiscoverCriterionChip(
                    label: intent.detectedLanguage!,
                    icon: Icons.language_rounded,
                  ),
                if (intent.detectedCategory != null)
                  DiscoverCriterionChip(
                    label: intent.detectedCategory!,
                    icon: Icons.category_rounded,
                  ),
                if (intent.cleanKeywords.isNotEmpty)
                  ...intent.cleanKeywords.map(
                    (k) => DiscoverCriterionChip(
                      label: k,
                      icon: Icons.tag_rounded,
                    ),
                  ),
                if (intent.resultMode == SearchResultMode.exhaustive)
                  const DiscoverCriterionChip(
                    label: 'Exhaustive / All',
                    icon: Icons.all_inclusive_rounded,
                  ),
              ],
            ),
            // Fallback broadening suggestion when language-specific count is low
            if (controller.broadenedChannels.isNotEmpty && !isBroadened) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: buttonBg.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.travel_explore_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Found only $matchCount ${intent.detectedLanguage} channels. Broaden search?',
                        style: const TextStyle(
                          color: secondaryText,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        controller.broadenSearch();
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Show All Christian Channels',
                        style: TextStyle(
                          color: primaryText,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    });
  }
}

/// Small pill chip displaying an individual criterion detected by AI search.
class DiscoverCriterionChip extends StatelessWidget {
  const DiscoverCriterionChip({
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
          Icon(icon, color: Colors.white, size: 12),
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
