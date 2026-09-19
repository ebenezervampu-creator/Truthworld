import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/video/presentation/controllers/comments_controller.dart';
import 'package:truthworld/features/video/presentation/views/widgets/comments/comment_action_handler.dart';

/// Controller managing reactive reply input and reply list expansion for a comment.
class CommentItemController extends GetxController {
  final RxBool isReplying = false.obs;
  final RxBool isRepliesExpanded = false.obs;
  final RxString replyText = ''.obs;

  final TextEditingController replyController = TextEditingController();
  final FocusNode replyFocusNode = FocusNode();

  @override
  void onInit() {
    super.onInit();
    replyController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    replyText.value = replyController.text;
  }

  void toggleReplying(BuildContext context) {
    isReplying.toggle();
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
    replyFocusNode.unfocus();
  }

  void toggleRepliesExpanded() {
    isRepliesExpanded.toggle();
  }

  void setRepliesExpanded(bool expanded) {
    isRepliesExpanded.value = expanded;
  }

  Future<void> submitReply({
    required String commentId,
    required String videoId,
    required String commentAuthorId,
  }) async {
    final text = replyController.text.trim();
    if (text.isEmpty) return;
    if (commentId.isEmpty) return;

    if (!AuthService.to.isAuthenticated.value) {
      CommentActionHandler.showSignInPrompt();
      return;
    }

    try {
      final tag = 'video_$videoId';
      final commentsController = Get.isRegistered<CommentsController>(tag: tag)
          ? Get.find<CommentsController>(tag: tag)
          : Get.put(CommentsController(), tag: tag);

      final authService = AuthService.to;
      final hasChannel = authService.hasChannel.value;
      final channel = authService.userChannel;

      final targetChannelId = hasChannel ? channel?.id : null;
      final targetChannelName = hasChannel
          ? (channel?.handle.isNotEmpty ?? false
                ? channel?.handle
                : channel?.name)
          : null;
      final targetChannelAvatar = authService.activePhotoUrl.isNotEmpty
          ? authService.activePhotoUrl
          : null;
      final targetUserAvatar = authService.activePhotoUrl;

      await commentsController.submitReply(
        commentId: commentId,
        text: text,
        channelId: targetChannelId,
        channelName: targetChannelName,
        channelProfilePicUrl: targetChannelAvatar,
        userProfilePicUrl: targetUserAvatar,
        commentAuthorId: commentAuthorId,
      );

      cancelReplying();
      AppSnackbar.success('Reply posted');
    } catch (e) {
      ErrorHandler.log(e, context: 'VideoScreen.submitReply');
      AppSnackbar.error('Unable to post reply. Please try again.');
    }
  }

  @override
  void onClose() {
    replyController.removeListener(_onTextChanged);
    replyController.dispose();
    replyFocusNode.dispose();
    super.onClose();
  }
}
