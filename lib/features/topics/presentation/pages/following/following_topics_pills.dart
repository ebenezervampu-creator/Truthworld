import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/presentation/controllers/following_topics_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Horizontal list of topic filter chips (pills) for switching between followed topics.
class FollowingTopicsPills extends StatelessWidget {
  const FollowingTopicsPills({
    required this.controller,
    this.onTopicDetailsTap,
    super.key,
  });

  final FollowingTopicsController controller;
  final void Function(Topic topic)? onTopicDetailsTap;

  void _handleTopicTap(Topic topic, bool isSelected) {
    if (isSelected) {
      if (onTopicDetailsTap != null) {
        onTopicDetailsTap!(topic);
      } else {
        Get.toNamed<void>(
          topic.topicRoute,
          arguments: {
            'slug': topic.slug,
            'fromCard': true,
            'topic': topic,
          },
        );
      }
    } else {
      controller.selectTopic(topic);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final topics = controller.followedTopics;
      if (topics.isEmpty) return const SizedBox.shrink();

      final selected = controller.selectedTopic.value;

      return Container(
        height: 48,
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: topics.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              final isAllSelected = selected == null;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => controller.selectTopic(null),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isAllSelected
                          ? AppColors.textPrimary
                          : const Color(0xFF272727),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'All Topics',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isAllSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: isAllSelected
                            ? AppColors.bgPage
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              );
            }

            final topic = topics[index - 1];
            final isSelected = selected?.id == topic.id;

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => _handleTopicTap(topic, isSelected),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  constraints: const BoxConstraints(maxWidth: 240),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.textPrimary
                        : const Color(0xFF272727),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          topic.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isSelected
                                ? AppColors.bgPage
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: AppColors.bgPage,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    });
  }
}
