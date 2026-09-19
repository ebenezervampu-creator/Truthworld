import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/topics/presentation/widgets/comments/topic_comment_reply_controller.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Header displaying the comment count and sort selection popup button.
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
      children: [
        Text(
          '$commentCount ${commentCount == 1 ? 'Comment' : 'Comments'}',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 24),
        PopupMenuButton<bool>(
          onSelected: (newest) {
            headerController.isSortNewest.value = newest;
          },
          offset: const Offset(0, 30),
          itemBuilder: (context) => <PopupMenuEntry<bool>>[
            PopupMenuItem<bool>(
              value: false,
              child: Obx(() {
                final isSelected = !headerController.isSortNewest.value;
                return Row(
                  children: [
                    Icon(
                      Icons.check,
                      size: 18,
                      color: isSelected ? Colors.white : Colors.transparent,
                    ),
                    const SizedBox(width: 8),
                    const Text('Top comments'),
                  ],
                );
              }),
            ),
            PopupMenuItem<bool>(
              value: true,
              child: Obx(() {
                final isSelected = headerController.isSortNewest.value;
                return Row(
                  children: [
                    Icon(
                      Icons.check,
                      size: 18,
                      color: isSelected ? Colors.white : Colors.transparent,
                    ),
                    const SizedBox(width: 8),
                    const Text('Newest first'),
                  ],
                );
              }),
            ),
          ],
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.sort_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'Sort by',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
