import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/features/topics/presentation/controllers/topic_interaction_controller.dart';
import 'package:truthworld/features/topics/presentation/widgets/comments/topic_comment_models_and_helpers.dart';
import 'package:truthworld/features/topics/presentation/widgets/comments/topic_reply_item_widget.dart';
import 'package:truthworld/features/video/data/models/reply.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Section rendering the threaded replies tree for a specific parent comment.
class TopicRepliesSection extends StatelessWidget {
  TopicRepliesSection({
    required this.commentId,
    required this.topicId,
    required this.controller,
    required this.theme,
    required this.isMobile,
    required this.isTablet,
    required this.isDesktop,
    required this.onNavigateToChannel,
    super.key,
  });

  final String commentId;
  final String topicId;
  final TopicInteractionController controller;
  final ThemeData theme;
  final bool isMobile;
  final bool isTablet;
  final bool isDesktop;
  final void Function(String?) onNavigateToChannel;

  final RxBool _isRepliesExpanded = false.obs;

  @override
  Widget build(BuildContext context) {
    final repliesRef = FirebaseFirestore.instance
        .collection(FirestoreCollections.topics)
        .doc(topicId)
        .collection('comments')
        .doc(commentId)
        .collection('replies')
        .orderBy('createdAt', descending: false);

    return StreamBuilder<QuerySnapshot>(
      stream: repliesRef.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final replies = snapshot.data!.docs
            .map(Reply.fromDocumentSnapshot)
            .toList();

        return Obx(() {
          final isExpanded = _isRepliesExpanded.value;

          if (!isExpanded) {
            final firstReply = replies.first;
            return InkWell(
              onTap: () => _isRepliesExpanded.value = true,
              child: Row(
                children: [
                  CustomPaint(
                    size: const Size(40, 36),
                    painter: ReplyThreadLinePainter(
                      color: AppColors.textDisabled,
                      isLast: true,
                      branchY: 18,
                    ),
                  ),
                  UserAvatar(
                    radius: 10,
                    photoUrl: firstReply.avatarUrl,
                    displayName: firstReply.displayName,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    replies.length == 1
                        ? '• 1 reply'
                        : '• ${replies.length} replies',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.info,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.expand_more,
                    color: Colors.white,
                    size: 16,
                  ),
                ],
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...List.generate(replies.length, (index) {
                final reply = replies[index];
                final isLastReply = index == replies.length - 1;

                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomPaint(
                        size: const Size(40, double.infinity),
                        painter: ReplyThreadLinePainter(
                          color: AppColors.textDisabled,
                          isLast: isLastReply,
                          branchY: 20,
                        ),
                      ),
                      Expanded(
                        child: TopicReplyItemWidget(
                          reply: reply,
                          commentId: commentId,
                          topicId: topicId,
                          controller: controller,
                          theme: theme,
                          isMobile: isMobile,
                          isTablet: isTablet,
                          isDesktop: isDesktop,
                          onNavigateToChannel: onNavigateToChannel,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              InkWell(
                onTap: () => _isRepliesExpanded.value = false,
                child: Row(
                  children: [
                    CustomPaint(
                      size: const Size(40, 36),
                      painter: ReplyThreadLinePainter(
                        color: AppColors.textDisabled,
                        isLast: true,
                        branchY: 18,
                      ),
                    ),
                    const Text(
                      '• Hide replies',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.info,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.expand_less,
                      color: Colors.white,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ],
          );
        });
      },
    );
  }
}
