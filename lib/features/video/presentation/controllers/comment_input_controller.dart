import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/home/presentation/controllers/main_controller.dart';

class CommentInputController extends BaseController with ContentValidationMixin {
  CommentInputController({required this.videoId, required this.enableComments});
  final String videoId;
  final bool enableComments;

  // State Variables as observables
  final RxBool isFocused = false.obs;
  final RxBool hasText = false.obs;
  final RxBool isSubmitting = false.obs;
  final RxBool isHovering = false.obs;
  final RxInt characterCount = 0.obs;

  final TextEditingController commentController = TextEditingController();
  final FocusNode focusNode = FocusNode();
  final MainController _mainController = Get.find();

  @override
  void onInit() {
    super.onInit();
    commentController.addListener(_onTextChanged);
    focusNode.addListener(_onFocusChanged);
  }

  void _onTextChanged() {
    final text = commentController.text;
    hasText.value = text.isNotEmpty;
    characterCount.value = text.length;
  }

  void _onFocusChanged() {
    isFocused.value = focusNode.hasFocus;
  }

  void setHovering(bool val) {
    isHovering.value = val;
  }

  Future<void> submitComment() async {
    if (commentController.text.trim().isEmpty ||
        !enableComments ||
        isSubmitting.value) {
      return;
    }

    final validation = await validateContent(commentController.text, fieldName: 'Comment');
    if (!validation.isValid) {
      showWarning(validation.message);
      return;
    }

    await safeExecute(() async {
      isSubmitting.value = true;
      final user = FirebaseAuth.instance.currentUser!;

      final authService = AuthService.to;
      final finalUserName = authService.activeDisplayName;
      final finalUserProfilePicUrl = authService.activePhotoUrl;

      await _mainController.addComment(
        videoId: videoId,
        userId: user.uid,
        userName: finalUserName,
        userProfilePicUrl: finalUserProfilePicUrl,
        text: commentController.text,
      );

      commentController.clear();
      focusNode.unfocus();
      showSuccess('Comment posted successfully');
    }, showLoading: false);

    isSubmitting.value = false;
  }

  @override
  void onClose() {
    commentController.dispose();
    focusNode.dispose();
    super.onClose();
  }
}
