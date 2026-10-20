import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/presentation/controllers/topic_interaction_controller.dart';
import 'package:truthworld/features/topics/presentation/widgets/comments/topic_comments_components.dart';
import 'package:truthworld/theme/app_colors.dart';

export 'comments/topic_comments_components.dart';

/// Top-level declarative section coordinating topic comments, reactions, sorting,
/// and discussion threads matching the redesigned upload UI.
class TopicCommentsSection extends StatelessWidget {
  const TopicCommentsSection({
    required this.topic,
    super.key,
  });

  final Topic topic;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
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
            // 1. Header with white vertical bar, comment count & sort dropdown
            TopicCommentsHeader(
              commentCount: commentCount,
              headerController: headerController,
            ),
            const SizedBox(height: 18),

            // 2. Add Comment Input Bar matching screenshot (User Avatar + Rounded Box with Image Icon)
            _TopicCommentInputBar(
              topicId: topic.id,
              onSubmit: (text) async {
                await controller.addComment(topic.id, text);
              },
            ),

            const SizedBox(height: 20),

            // 3. Comments List or Loading / Empty states
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
                    key: ValueKey(comment.id),
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

            if (sortedComments.isNotEmpty && controller.hasMoreComments.value) ...[
              const SizedBox(height: 16),
              Center(
                child: OutlinedButton(
                  onPressed: controller.isLoadingMoreComments.value
                      ? null
                      : () => controller.loadMoreComments(topic.id),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: BorderSide(
                      color: AppColors.textSecondary.withValues(alpha: 0.3),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: controller.isLoadingMoreComments.value
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Load more comments',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ],
        ),
      );
    });
  }
}

/// Controller managing text input and submission for the comment input box
class _TopicCommentInputBarController extends GetxController {
  final TextEditingController textController = TextEditingController();
  final FocusNode focusNode = FocusNode();
  final RxString currentText = ''.obs;
  final RxBool isSubmitting = false.obs;

  @override
  void onInit() {
    super.onInit();
    textController.addListener(() {
      currentText.value = textController.text;
    });
  }

  @override
  void onClose() {
    textController.dispose();
    focusNode.dispose();
    super.onClose();
  }
}

/// Redesigned Comment Input Bar matching the screenshot:
/// [User Avatar (EV)]  [ Add a comment...                   (Image Icon) ]
class _TopicCommentInputBar extends StatelessWidget {
  const _TopicCommentInputBar({
    required this.topicId,
    required this.onSubmit,
  });

  final String topicId;
  final Future<void> Function(String text) onSubmit;

  @override
  Widget build(BuildContext context) {
    final inputCtrl = Get.put(
      _TopicCommentInputBarController(),
      tag: 'topic_comment_input_$topicId',
    );

    return Obx(() {
      final auth = AuthService.to;
      final isAuth = auth.isAuthenticated.value;
      final photoUrl = auth.activePhotoUrl;
      final user = auth.user;
      final channel = auth.userChannel;

      final initial = channel?.name.isNotEmpty ?? false
          ? channel!.name.substring(0, 1).toUpperCase()
          : (user?.displayName?.isNotEmpty ?? false
              ? user!.displayName!.substring(0, 1).toUpperCase()
              : (user?.email?.isNotEmpty ?? false
                  ? user!.email!.substring(0, 1).toUpperCase()
                  : 'U'));

      Future<void> handleSubmit() async {
        if (!isAuth) {
          showTopicSignInPrompt('post a comment');
          return;
        }

        final text = inputCtrl.textController.text.trim();
        if (text.isEmpty || inputCtrl.isSubmitting.value) return;

        inputCtrl.isSubmitting.value = true;
        try {
          await onSubmit(text);
          inputCtrl.textController.clear();
          inputCtrl.focusNode.unfocus();
        } finally {
          inputCtrl.isSubmitting.value = false;
        }
      }

      return Row(
        children: [
          // User Avatar on Left (EV circle)
          UserAvatar(
            photoUrl: photoUrl,
            displayName: initial,
            backgroundColor: const Color(0xFF2E2E32),
            textColor: Colors.white,
          ),

          const SizedBox(width: 14),

          // Rounded Input Box with Image Icon and Submit Button
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF161618),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: const Color(0xFF2E2E34),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: inputCtrl.textController,
                      focusNode: inputCtrl.focusNode,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                      maxLength: ContentValidator.defaultMaxCommentLength,
                      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                      inputFormatters: TruthworldTextInputFormatters.withLimit(
                        ContentValidator.defaultMaxCommentLength,
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => handleSubmit(),
                      decoration: const InputDecoration(
                        hintText: 'Add a comment...',
                        hintStyle: TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        isDense: true,
                      ),
                    ),
                  ),

                  // Image attachment icon
                  IconButton(
                    icon: const Icon(
                      Icons.image_outlined,
                      color: Color(0xFFAAAAAA),
                      size: 20,
                    ),
                    tooltip: 'Attach image',
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      AppSnackbar.info(
                        'Image attachments for comments will be supported in an upcoming update.',
                      );
                    },
                  ),

                  // Send button (if text has been entered)
                  Obx(() {
                    final hasText = inputCtrl.currentText.value.trim().isNotEmpty;
                    if (!hasText) return const SizedBox.shrink();

                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: inputCtrl.isSubmitting.value
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : IconButton(
                              icon: const Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                              tooltip: 'Post comment',
                              onPressed: handleSubmit,
                            ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }
}
