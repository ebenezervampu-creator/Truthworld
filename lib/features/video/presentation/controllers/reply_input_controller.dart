import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/home/presentation/controllers/main_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

class ReplyInputController extends BaseController {

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

    isSending.value = true;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Get.snackbar(
        'Error',
        'Please sign in to reply.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error,
        colorText: AppColors.textPrimary,
      );
      isSending.value = false;
      return;
    }

    try {
      final authService = AuthService.to;
      final finalUserName = authService.activeDisplayName;
      final finalUserProfilePicUrl = authService.activePhotoUrl;

      await _mainController.addReply(
        videoId: videoId,
        commentId: commentId,
        userId: user.uid,
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





