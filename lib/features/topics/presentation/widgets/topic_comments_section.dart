import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/presentation/controllers/topic_interaction_controller.dart';
import 'package:truthworld/features/topics/presentation/widgets/comments/topic_comments_components.dart';
import 'package:truthworld/features/video/presentation/views/comments/premium_comment_input.dart';

export 'comments/topic_comments_components.dart';

/// Top-level declarative section coordinating topic comments, reactions, sorting,
/// and discussion threads.
class TopicCommentsSection extends StatelessWidget {
  const TopicCommentsSection({
    required this.topic,
    super.key,
  });

  final Topic topic;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    final isTablet = size.width >= 600 && size.width < 1000;
    final isDesktop = size.width >= 1000;
    final theme = Theme.of(context);

    final controller = Get.isRegistered<TopicInteractionController>(
      tag: topic.id,
    )
        ? Get.find<TopicInteractionController>(tag: topic.id)
        : Get.put(TopicInteractionController(), tag: topic.id);
    controller.initializeTopic(topic);

    final headerController = Get.isRegistered<TopicCommentsHeaderController>(
      tag: topic.id,
    )
        ? Get.find<TopicCommentsHeaderController>(tag: topic.id)
        : Get.put(TopicCommentsHeaderController(), tag: topic.id);

    return Obx(() {
      final commentCount = controller.commentCount.value;
      final rawComments = controller.comments;
      final sortedComments = headerController.sortComments(rawComments);

      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TopicCommentsHeader(
              commentCount: commentCount,
              headerController: headerController,
            ),
            const SizedBox(height: 20),
            PremiumCommentInput(
              videoId: topic.id,
              onSubmit: (text, postAsChannel, channelId) async {
                await controller.addComment(topic.id, text);
              },
            ),
            const SizedBox(height: 24),
            if (controller.isLoadingComments.value && sortedComments.isEmpty)
              const TopicCommentsSkeleton()
            else if (sortedComments.isEmpty)
              const TopicCommentsEmptyState()
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sortedComments.length,
                itemBuilder: (context, index) {
                  final comment = sortedComments[index];
                  return TopicCommentItemWidget(
                    comment: comment,
                    topicId: topic.id,
                    controller: controller,
                    theme: theme,
                    isMobile: isMobile,
                    isTablet: isTablet,
                    isDesktop: isDesktop,
                    onNavigateToChannel: navigateToTopicChannel,
                  );
                },
              ),
          ],
        ),
      );
    });
  }
}
