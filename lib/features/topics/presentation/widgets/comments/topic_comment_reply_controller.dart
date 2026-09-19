import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/topics/presentation/controllers/topic_interaction_controller.dart';
import 'package:truthworld/features/topics/presentation/widgets/comments/topic_comment_models_and_helpers.dart';
import 'package:truthworld/features/video/data/models/comment.dart';

/// Controller managing sorting mode and filtered comments view state.
class TopicCommentsHeaderController extends GetxController {
  final RxBool isSortNewest = true.obs;

  List<Comment> sortComments(List<Comment> rawComments) {
    final list = List<Comment>.from(rawComments);
    if (isSortNewest.value) {
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } else {
      list.sort((a, b) => b.likeCount.compareTo(a.likeCount));
    }
    return list;
  }
}

/// Controller managing reply drafting, validation, and lifecycle per comment item.
class TopicCommentReplyController extends GetxController {
  final RxBool isReplying = false.obs;
  final RxString replyText = ''.obs;

  late final TextEditingController replyController;
  late final FocusNode replyFocusNode;

  @override
  void onInit() {
    super.onInit();
    replyController = TextEditingController();
    replyFocusNode = FocusNode();
    replyController.addListener(() {
      replyText.value = replyController.text;
    });
  }

  @override
  void onClose() {
    replyController.dispose();
    replyFocusNode.dispose();
    super.onClose();
  }

  void startReplying(BuildContext context) {
    if (!AuthService.to.isAuthenticated.value) {
      showTopicSignInPrompt('reply to comments');
      return;
    }
    isReplying.value = !isReplying.value;
    if (isReplying.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (replyFocusNode.canRequestFocus) {
          FocusScope.of(context).requestFocus(replyFocusNode);
        }
      });
    }
  }

  void cancelReplying() {
    isReplying.value = false;
    replyController.clear();
  }

  Future<void> submitReply({
    required String topicId,
    required String commentId,
    required TopicInteractionController controller,
  }) async {
    final text = replyController.text.trim();
    if (text.isEmpty) return;

    final validation = ContentValidator.validate(
      text,
      fieldName: 'Reply',
      maxLength: 1000,
    );
    if (!validation.isValid) {
      AppSnackbar.warning(validation.message);
      return;
    }

    if (commentId.isEmpty) return;

    if (!AuthService.to.isAuthenticated.value) {
      showTopicSignInPrompt('reply to comments');
      return;
    }

    try {
      await controller.addReply(topicId, commentId, text);
      replyController.clear();
      isReplying.value = false;
      AppSnackbar.success('Reply posted');
    } catch (e) {
      ErrorHandler.log(e, context: 'TopicCommentsSection.postReply');
      AppSnackbar.error('Unable to post reply. Please try again.');
    }
  }
}
