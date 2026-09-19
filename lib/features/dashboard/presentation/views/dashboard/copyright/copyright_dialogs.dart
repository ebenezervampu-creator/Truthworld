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
        backgroundColor:
            isDarkMode ? AppColors.bgSurface : AppColors.textPrimary,
        title: Text(
          'Contact Channel Owner',
          style: TextStyle(
            color: isDarkMode ? AppColors.textPrimary : Colors.black,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: messageController,
              inputFormatters: TruthworldTextInputFormatters.standard,
              maxLines: 4,
              style: TextStyle(
                color: isDarkMode ? AppColors.textPrimary : Colors.black,
              ),
              decoration: InputDecoration(
                labelText: 'Notice Message',
                labelStyle: TextStyle(
                  color: isDarkMode
                      ? AppColors.textSecondary
                      : Colors.black,
                ),
                filled: true,
                fillColor: isDarkMode
                    ? AppColors.bgInput
                    : const Color(0xFFF1F5F9),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
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
            ),
            child: const Text('Send Warning'),
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
        backgroundColor:
            isDarkMode ? AppColors.bgSurface : AppColors.textPrimary,
        title: Text(
          'Submit DMCA Removal Request?',
          style: TextStyle(
            color: isDarkMode ? AppColors.textPrimary : Colors.black,
          ),
        ),
        content: Text(
          'Filing a formal removal request for "$title" uploaded by $channelName '
          'will issue an official takedown notice under Truthworld Copyright Policy.',
          style: TextStyle(
            color: isDarkMode ? AppColors.textSecondary : Colors.black,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
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
              foregroundColor: AppColors.textPrimary,
            ),
            child: const Text('File Removal Request'),
          ),
        ],
      ),
    );
  }
}
