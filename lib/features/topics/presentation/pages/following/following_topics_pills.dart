import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/presentation/controllers/following_topics_controller.dart';

/// Horizontal list of topic filter chips (pills) matching the uploaded UI:
/// - Unselected "All Topics": Dark rounded pill with clean white text
/// - Selected Topic: High contrast white pill with bold black text & chevron `>`
/// - Unselected Topics: Dark rounded pill with clean white text
/// - Zero White-on-White Policy strictly enforced
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

      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Container(
            height: 42,
            margin: const EdgeInsets.only(top: 4, bottom: 12),
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
                          horizontal: 18,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: isAllSelected
                              ? Colors.white
                              : const Color(0xFF222224),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isAllSelected
                                ? Colors.transparent
                                : Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'All Topics',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isAllSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isAllSelected
                                ? Colors.black
                                : Colors.white,
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
                        horizontal: 18,
                        vertical: 9,
                      ),
                      constraints: const BoxConstraints(maxWidth: 280),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF222224),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? Colors.transparent
                              : Colors.white.withValues(alpha: 0.08),
                        ),
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
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? Colors.black
                                    : Colors.white,
                              ),
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 16,
                              color: Colors.black,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
    });
  }
}
