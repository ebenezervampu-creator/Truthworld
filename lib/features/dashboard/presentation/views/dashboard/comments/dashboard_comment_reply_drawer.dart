import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_comments_controller.dart';
import 'package:truthworld/features/video/data/models/comment.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Inline Reply Drawer for Studio Comments
/// Provides quick suggestion chips, formatted text input, and submission as channel identity.
class DashboardCommentReplyDrawer extends StatelessWidget {
  const DashboardCommentReplyDrawer({
    required this.comment,
    required this.controller,
    super.key,
  });

  final Comment comment;
  final DashboardCommentsController controller;

  static const List<String> quickReplies = [
    'Thanks for watching! 🙏',
    'Appreciate the support! ❤️',
    'Great feedback, thank you!',
    'New video coming soon! 🚀',
  ];

  @override
  Widget build(BuildContext context) {
    final replyCtrl = controller.getReplyController(comment.id);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.bgDivider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick Suggestion Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: quickReplies.map((qr) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6, bottom: 8),
                  child: ActionChip(
                    label: Text(qr),
                    backgroundColor: AppColors.bgSurface,
                    labelStyle: const TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontFamilyFallback: TWTypography.fallbackFamilies,
                      fontSize: 11,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    onPressed: () {
                      replyCtrl.text = qr;
                      replyCtrl.selection = TextSelection.fromPosition(
                        TextPosition(offset: replyCtrl.text.length),
                      );
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          TextField(
            controller: replyCtrl,
            maxLength: ContentValidator.defaultMaxReplyLength,
            buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
            inputFormatters: TruthworldTextInputFormatters.withLimit(
              ContentValidator.defaultMaxReplyLength,
            ),
            maxLines: 3,
            minLines: 1,
            autofocus: true,
            style: const TextStyle(
              fontFamily: TWTypography.uiFamily,
              fontFamilyFallback: TWTypography.fallbackFamilies,
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Reply publicly as channel...',
              hintStyle: const TextStyle(
                fontFamily: TWTypography.uiFamily,
                fontFamilyFallback: TWTypography.fallbackFamilies,
                fontSize: 12,
                color: AppColors.textTertiary,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: AppColors.bgDivider,
                ),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
                borderSide: BorderSide(color: AppColors.brand),
              ),
              contentPadding: const EdgeInsets.all(10),
            ),
          ),
          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => controller.closeReplyBox(comment.id),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontFamilyFallback: TWTypography.fallbackFamilies,
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Obx(() {
                final isSubmitting =
                    controller.isSubmittingReply[comment.id] ?? false;

                return ElevatedButton.icon(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final text = replyCtrl.text.trim();
                          if (text.isEmpty) {
                            AppSnackbar.warning('Please enter a reply message.');
                            return;
                          }

                          final valRes = ContentValidator.validate(
                            text,
                            fieldName: 'Reply',
                            maxLength: ContentValidator.defaultMaxReplyLength,
                          );
                          if (!valRes.isValid) {
                            AppSnackbar.warning(valRes.message);
                            return;
                          }

                          final success = await controller.submitReply(
                            comment: comment,
                            text: text,
                          );

                          if (success) {
                            AppSnackbar.success('Publicly replied as channel.');
                          } else {
                            AppSnackbar.error(
                              'Could not send reply. Please try again.',
                            );
                          }
                        },
                  icon: isSubmitting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Icon(
                          Icons.send_rounded,
                          size: 14,
                          color: Colors.black,
                        ),
                  label: const Text(
                    'Reply',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontFamilyFallback: TWTypography.fallbackFamilies,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }
}
