import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/theme/app_theme.dart';

class PremiumCommentInputController extends GetxController {
  final TextEditingController commentController = TextEditingController();
  final FocusNode focusNode = FocusNode();
  final RxBool isSubmitting = false.obs;
  final RxBool isFocused = false.obs;
  final RxBool hasText = false.obs;

  @override
  void onInit() {
    super.onInit();
    focusNode.addListener(() {
      isFocused.value = focusNode.hasFocus;
    });
    commentController.addListener(() {
      hasText.value = commentController.text.trim().isNotEmpty;
    });
  }

  @override
  void onClose() {
    commentController.dispose();
    focusNode.dispose();
    super.onClose();
  }
}

/// Premium comment input with enhanced YouTube-style UI and onSubmit callback
class PremiumCommentInput extends StatelessWidget {

  const PremiumCommentInput({
    required this.videoId, required this.onSubmit, super.key,
    this.isReply = false,
    this.onCancel,
  });
  final String videoId;
  final bool isReply;
  final Function(String text, bool postAsChannel, String? channelId) onSubmit;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(
      PremiumCommentInputController(),
      tag: 'premium_input_${videoId}_$isReply',
    );
    final user = FirebaseAuth.instance.currentUser;

    return Obx(() {
      final authService = AuthService.to;
      final hasChannel = authService.hasChannel.value;
      final channel = authService.userChannel;

      final photoUrl = authService.activePhotoUrl;
      final initial = hasChannel
          ? (channel?.name.isNotEmpty ?? false ? channel!.name.substring(0, 1).toUpperCase() : 'C')
          : (user?.email?.isNotEmpty ?? false
              ? user!.email!.substring(0, 1).toUpperCase()
              : (user?.displayName?.isNotEmpty ?? false
                  ? user!.displayName!.substring(0, 1).toUpperCase()
                  : 'U'));

      Future<void> submitComment() async {
        final text = controller.commentController.text.trim();
        if (text.isEmpty || controller.isSubmitting.value) return;

        controller.isSubmitting.value = true;

        try {
          HapticFeedback.mediumImpact();
          await onSubmit(
            text,
            hasChannel,
            hasChannel ? channel?.id : null,
          );
          controller.commentController.clear();
          controller.focusNode.unfocus();
        } catch (e) {
          debugPrint('Error submitting comment: $e');
        } finally {
          controller.isSubmitting.value = false;
        }
      }

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(
            photoUrl: photoUrl,
            displayName: initial,
            radius: 18,
            backgroundColor: AppColors.info,
            textColor: AppColors.textPrimary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                TextField(
                  controller: controller.commentController,
                  focusNode: controller.focusNode,
                  maxLines: null,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => submitComment(),
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: isReply ? 'Add a reply...' : 'Add a comment...',
                    hintStyle: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                    enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: AppColors.textPrimary,
                        width: 1.5,
                      ),
                    ),
                    border: const UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
                Obx(() {
                  if (controller.isFocused.value || controller.hasText.value) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              controller.commentController.clear();
                              controller.focusNode.unfocus();
                              if (onCancel != null) onCancel!();
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.textSecondary,
                            ),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: controller.isSubmitting.value ||
                                    !controller.hasText.value
                                ? null
                                : submitComment,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: controller.hasText.value
                                  ? AppColors.info
                                  : AppColors.textPrimary.withValues(alpha: 0.1),
                              foregroundColor: controller.hasText.value
                                  ? AppColors.textPrimary
                                  : AppColors.textPrimary.withValues(alpha: 0.3),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                            child: const Text('Comment'),
                          ),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                }),
              ],
            ),
          ),
        ],
      );
    });
  }
}
