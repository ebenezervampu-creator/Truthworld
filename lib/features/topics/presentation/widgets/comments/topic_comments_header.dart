import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/topics/presentation/widgets/comments/topic_comment_reply_controller.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Header displaying the white vertical bar indicator, comment count,
/// and the responsive sort by dropdown pill matching the updated UI design.
class TopicCommentsHeader extends StatelessWidget {
  const TopicCommentsHeader({
    required this.commentCount,
    required this.headerController,
    super.key,
  });

  final int commentCount;
  final TopicCommentsHeaderController headerController;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Left: Vertical bar indicator + Comment Count
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 3.5,
              height: 22,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '$commentCount ${commentCount == 1 ? 'Comment' : 'Comments'}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),

        // Right: Sort by + [Newest first ∨] Dropdown Pill
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.sort_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 6),
            const Text(
              'Sort by',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 10),
            PopupMenuButton<bool>(
              onSelected: (newest) {
                HapticFeedback.selectionClick();
                headerController.isSortNewest.value = newest;
              },
              offset: const Offset(0, 36),
              color: const Color(0xFF1E1E22),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              itemBuilder: (context) => <PopupMenuEntry<bool>>[
                PopupMenuItem<bool>(
                  value: true,
                  child: Obx(() {
                    final isSelected = headerController.isSortNewest.value;
                    return Row(
                      children: [
                        Icon(
                          Icons.check,
                          size: 16,
                          color: isSelected ? Colors.white : Colors.transparent,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Newest first',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                          ),
                        ),
                      ],
                    );
                  }),
                ),
                PopupMenuItem<bool>(
                  value: false,
                  child: Obx(() {
                    final isSelected = !headerController.isSortNewest.value;
                    return Row(
                      children: [
                        Icon(
                          Icons.check,
                          size: 16,
                          color: isSelected ? Colors.white : Colors.transparent,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Top comments',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ],
              child: Obx(() {
                final isSortNewest = headerController.isSortNewest.value;
                final currentLabel = isSortNewest ? 'Newest first' : 'Top comments';

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161618),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF2E2E32),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        currentLabel,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ],
    );
  }
}
