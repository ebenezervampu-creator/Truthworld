import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/video/presentation/controllers/comments_controller.dart';
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
    required this.videoId,
    required this.onSubmit,
    super.key,
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
          ? (channel?.name.isNotEmpty ?? false
                ? channel!.name.substring(0, 1).toUpperCase()
                : 'C')
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
                          if (!isReply) ...[
                            IconButton(
                              onPressed: () =>
                                  _showSuperThanksModal(context, videoId),
                              icon: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.attach_money,
                                  color: AppColors.textPrimary,
                                  size: 18,
                                ),
                              ),
                              tooltip: 'Super Thanks / Donate',
                            ),
                            const SizedBox(width: 8),
                          ],
                          ElevatedButton(
                            onPressed:
                                controller.isSubmitting.value ||
                                    !controller.hasText.value
                                ? null
                                : submitComment,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: controller.hasText.value
                                  ? AppColors.info
                                  : AppColors.textPrimary.withValues(
                                      alpha: 0.1,
                                    ),
                              foregroundColor: controller.hasText.value
                                  ? AppColors.textPrimary
                                  : AppColors.textPrimary.withValues(
                                      alpha: 0.3,
                                    ),
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

  void _showSuperThanksModal(BuildContext context, String videoId) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Get.snackbar(
        'Authentication Required',
        'Please sign in to send Super Thanks.',
      );
      return;
    }

    final messageController = TextEditingController();
    final selectedTierIndex = 1.obs; // Default $5.00
    final isSubmitting = false.obs;

    final tiers = [
      {'amount': 2.0, 'color': '0xFF00B8D4', 'label': r'$2.00'},
      {'amount': 5.0, 'color': '0xFF1E88E5', 'label': r'$5.00'},
      {'amount': 10.0, 'color': '0xFF00C853', 'label': r'$10.00'},
      {'amount': 20.0, 'color': '0xFFFFD600', 'label': r'$20.00'},
      {'amount': 50.0, 'color': '0xFFFF6D00', 'label': r'$50.00'},
      {'amount': 100.0, 'color': '0xFFD50000', 'label': r'$100.00'},
    ];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Obx(() {
                final currentTier = tiers[selectedTierIndex.value];
                final tierColor = Color(
                  int.parse(currentTier['color']! as String),
                );
                final amountStr = currentTier['label']! as String;
                final amountVal = currentTier['amount']! as double;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.bgDivider,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: tierColor.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.attach_money,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Send Super Thanks',
                                style: AppTextStyles.titleLarge.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                'Post a highlighted comment & support the creator directly',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: AppColors.textPrimary,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Tier Selection Pills
                    Text(
                      'SELECT DONATION AMOUNT',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(tiers.length, (index) {
                          final isSelected = selectedTierIndex.value == index;
                          final item = tiers[index];
                          final itemColor = Color(
                            int.parse(item['color']! as String),
                          );
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(
                                item['label']! as String,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              selected: isSelected,
                              selectedColor: itemColor,
                              backgroundColor: AppColors.bgInput,
                              onSelected: (_) =>
                                  selectedTierIndex.value = index,
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // YouTube-Style Donated Comment Preview Box
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.bgInput,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: tierColor, width: 1.5),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          // Tier Banner Header
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            color: tierColor,
                            child: Row(
                              children: [
                                UserAvatar(
                                  photoUrl: user.photoURL,
                                  displayName: user.displayName ?? 'U',
                                  radius: 16,
                                  textColor: Colors.white,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    user.displayName ?? 'User',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.favorite,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        amountStr,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Comment Input Area inside preview
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: TextField(
                              controller: messageController,
                              maxLines: 3,
                              minLines: 2,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Write a Super Thanks message...',
                                hintStyle: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tierColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: isSubmitting.value
                            ? null
                            : () async {
                                final text = messageController.text.trim();
                                if (text.isEmpty) {
                                  Get.snackbar(
                                    'Message Required',
                                    'Please enter a message for your Super Thanks.',
                                  );
                                  return;
                                }

                                isSubmitting.value = true;
                                try {
                                  if (Get.isRegistered<CommentsController>()) {
                                    final commentsCtrl =
                                        Get.find<CommentsController>();
                                    await commentsCtrl.submitComment(
                                      text: text,
                                      donationAmount: amountVal,
                                      isDonatedComment: true,
                                      donationColorHex:
                                          currentTier['color']! as String,
                                    );
                                  } else {
                                    await onSubmit(text, false, null);
                                  }

                                  if (!context.mounted) return;
                                  Navigator.pop(context);
                                  HapticFeedback.heavyImpact();
                                  Get.snackbar(
                                    'Super Thanks Sent! 🎉',
                                    'Thank you for supporting the creator with $amountStr!',
                                    backgroundColor: AppColors.bgSurface,
                                    colorText: AppColors.textPrimary,
                                    duration: const Duration(seconds: 4),
                                  );
                                } catch (e) {
                                  Get.snackbar(
                                    'Error',
                                    'Failed to send Super Thanks: $e',
                                  );
                                } finally {
                                  isSubmitting.value = false;
                                }
                              },
                        icon: const Icon(
                          Icons.attach_money,
                          color: Colors.white,
                        ),
                        label: Text(
                          'Buy & Send Super Thanks ($amountStr)',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                );
              }),
            ),
          ),
        );
      },
    );
  }
}
