import 'package:flutter/material.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/copyright_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Static helper for showing copyright-related dialogs.
class CopyrightDialogs {
  const CopyrightDialogs._();

  /// Shows contact dialog to send a warning message to the uploader of a matched video.
  static void showContactUploader({
    required BuildContext context,
    required String channelName,
    required String videoTitle,
    required bool isDarkMode,
  }) {
    final messageController = TextEditingController(
      text:
          'Hello $channelName, it has come to our attention that your video "$videoTitle" '
          'contains our copyrighted content. Please remove it immediately to avoid formal copyright strikes.',
    );

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.bgDivider),
        ),
        title: const Text(
          'Contact Channel Owner',
          style: TextStyle(
            fontFamily: TWTypography.brandFamily,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: messageController,
              maxLength: 1000,
              buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
              inputFormatters: TruthworldTextInputFormatters.internationalWithLimit(1000),
              maxLines: 4,
              style: const TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                labelText: 'Notice Message',
                labelStyle: const TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textSecondary,
                ),
                filled: true,
                fillColor: AppColors.bgInput,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.bgDivider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.bgDivider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.brand),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final msg = messageController.text.trim();
              final validation = ContentValidator.validate(
                msg,
                fieldName: 'Notice Message',
                minLength: 5,
                maxLength: 1000,
              );
              if (!validation.isValid) {
                AppSnackbar.warning(validation.message);
                return;
              }
              Navigator.pop(ctx);
              AppSnackbar.success('Warning message sent to $channelName.');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Send Warning',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Shows confirmation dialog to submit an official DMCA removal request.
  static void showRequestRemoval({
    required BuildContext context,
    required CopyrightController controller,
    required String videoId,
    required String title,
    required String channelName,
    required bool isDarkMode,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.bgDivider),
        ),
        title: const Text(
          'Submit DMCA Removal Request?',
          style: TextStyle(
            fontFamily: TWTypography.brandFamily,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          'Filing a formal removal request for "$title" uploaded by $channelName '
          'will issue an official takedown notice under Truthworld Copyright Policy.',
          style: const TextStyle(
            fontFamily: TWTypography.uiFamily,
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await controller.submitRemovalRequest(
                videoId: videoId,
                title: title,
              );
              if (ctx.mounted) Navigator.pop(ctx);
              if (success) {
                AppSnackbar.success('Removal request submitted for "$title".');
              } else {
                AppSnackbar.error(
                  'Unable to submit removal request. Please try again.',
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'File Removal Request',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
