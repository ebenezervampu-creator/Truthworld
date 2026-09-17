import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/utils/content_validator.dart';
import 'package:truthworld/core/utils/truthworld_text_input_formatters.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Modal dialog for confirming admin approval or rejection with optional audit notes.
void showAdminDecisionDialog(
  BuildContext context,
  AdminController controller,
  String id,
  String action,
  bool isVideo, {
  bool isTopic = false,
  bool isChannel = false,
  bool isReport = false,
}) {
  final textCtrl = TextEditingController();

  unawaited(
    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF181818),
        title: Text(
          'Confirm Manual ${action.capitalizeFirst}',
          style: const TextStyle(
            fontFamily: TWTypography.brandFamily,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Are you sure you want to manually $action this resource? '
              '${action == 'reject' ? 'This action logs an audit/moderation record.' : ''}',
              style: const TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: textCtrl,
              inputFormatters: TruthworldTextInputFormatters.standard,
              maxLines: 3,
              style: const TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Enter review reason (optional)...',
                hintStyle: const TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textTertiary,
                ),
                fillColor: AppColors.bgInput,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
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
              final reason = textCtrl.text.trim();
              if (reason.isNotEmpty) {
                final val = ContentValidator.validate(reason, checkEnglishOnly: false, fieldName: 'Review Reason');
                if (!val.isValid) {
                  AppSnackbar.warning(val.message);
                  return;
                }
              }
              Get.back();
              if (isReport) {
                await controller.moderateReport(id, action, reason);
              } else if (isTopic) {
                await controller.moderateTopic(id, action, reason);
              } else if (isChannel) {
                await controller.moderateChannel(id, action, reason);
              } else if (isVideo) {
                await controller.moderateVideo(id, action, reason);
              } else {
                await controller.moderateImage(id, action, reason);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: (action == 'approve' || action == 'dismiss')
                  ? AppColors.success
                  : AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Confirm ${action.capitalizeFirst}',
              style: const TextStyle(
                fontFamily: TWTypography.brandFamily,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
