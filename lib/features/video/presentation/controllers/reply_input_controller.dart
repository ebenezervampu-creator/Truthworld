import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/home/presentation/controllers/main_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

class ReplyInputController extends BaseController with ContentValidationMixin {
  ReplyInputController({
    required this.videoId,
    required this.commentId,
    this.initialText,
  });
  final String videoId;
  final String commentId;
  final String? initialText;

  final TextEditingController textController = TextEditingController();
  final FocusNode focusNode = FocusNode();
  final MainController _mainController = Get.find();

  final RxBool isFocused = false.obs;
  final RxBool isSending = false.obs;
  final RxString replyText = ''.obs;

  @override
  void onInit() {
    super.onInit();
    if (initialText != null) {
      textController.text = initialText!;
      replyText.value = initialText!;
    }

    focusNode.addListener(() {
      isFocused.value = focusNode.hasFocus;
    });

    textController.addListener(() {
      replyText.value = textController.text;
    });
  }

  @override
  void onClose() {
    textController.dispose();
    focusNode.dispose();
    super.onClose();
  }

  Future<void> sendReply() async {
    if (replyText.value.trim().isEmpty) return;

    final validation = await validateContent(replyText.value, fieldName: 'Reply');
    if (!validation.isValid) {
      Get.snackbar(
        'Inappropriate Content',
        validation.message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error,
        colorText: AppColors.textPrimary,
      );
      return;
    }

    isSending.value = true;

    if (!AuthService.to.isAuthenticated.value) {
      Get.snackbar(
        'Sign in required',
        'Please sign in with your Google account to reply.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.bgSurface,
        colorText: AppColors.textPrimary,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        duration: const Duration(seconds: 4),
        mainButton: TextButton(
          onPressed: () {
            AuthService.to.signInWithGoogle();
          },
          child: const Text(
            'SIGN IN',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
      isSending.value = false;
      return;
    }

    try {
      final authService = AuthService.to;
      final uid = authService.uid;
      if (uid.isEmpty) {
        isSending.value = false;
        return;
      }
      final finalUserName = authService.activeDisplayName;
      final finalUserProfilePicUrl = authService.activePhotoUrl;

      await _mainController.addReply(
        videoId: videoId,
        commentId: commentId,
        userId: uid,
        userName: finalUserName,
        userProfilePicUrl: finalUserProfilePicUrl,
        text: replyText.value.trim(),
      );
      textController.clear();
      focusNode.unfocus();
      Get.back();
      // Success snackbar is usually handled by the UI or implicitly by success
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to send reply: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error,
        colorText: AppColors.textPrimary,
      );
    } finally {
      isSending.value = false;
    }
  }

  void clearText() {
    textController.clear();
  }
}
