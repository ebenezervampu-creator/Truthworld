import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Shows an action dialog to confirm moderation actions (warn, ban, suspend, reset trust, etc.).
void showUserActionDialog({
  required BuildContext context,
  required AdminController controller,
  required String title,
  required String userId,
  required String actionCode,
  int? duration,
}) {
  final reasonController = TextEditingController();
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF181818),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      title: Text(
        'Confirm $title',
        style: const TextStyle(
          fontFamily: TWTypography.brandFamily,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Are you sure you want to apply this action to user $userId?',
            style: const TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: reasonController,
            maxLength: 500,
            buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
            inputFormatters: TruthworldTextInputFormatters.withLimit(500),
            style: const TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Enter reason for this action...',
              hintStyle: const TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.textTertiary,
              ),
              filled: true,
              fillColor: AppColors.bgInput,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
            ),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: actionCode.contains('ban') || actionCode == 'delete'
                ? AppColors.error
                : (actionCode == 'unban' ? Colors.green : const Color(0xFF252525)),
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            final reason = reasonController.text.trim();
            if (reason.isNotEmpty) {
              final val = ContentValidator.validate(reason, fieldName: 'Reason');
              if (!val.isValid) {
                AppSnackbar.warning(val.message);
                return;
              }
            }
            Navigator.pop(context);
            controller.moderateUser(
              userId,
              actionCode,
              reason.isNotEmpty ? reason : 'Admin moderation action: $title',
              durationDays: duration,
            );
          },
          child: const Text(
            'Confirm',
            style: TextStyle(
              fontFamily: TWTypography.brandFamily,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Shows a dialog to confirm consolidation of duplicate accounts under an email.
void showConfirmConsolidationDialog({
  required BuildContext context,
  required AdminController controller,
  required String email,
  required String primaryUid,
}) {
  Get.dialog(
    AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: const Row(
        children: [
          Icon(Icons.merge_type, color: Colors.white, size: 22),
          SizedBox(width: 8),
          Text(
            'Consolidate Accounts',
            style: TextStyle(
              fontFamily: TWTypography.brandFamily,
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: Text(
        'This will search for all duplicate documents associated with "$email", merge channels and profiles into primary UID "$primaryUid", remove stale duplicates, and create an audit log. Continue?',
        style: const TextStyle(
          fontFamily: TWTypography.uiFamily,
          color: AppColors.textSecondary,
          fontSize: 13,
        ),
      ),
      actions: [
        TextButton(
          onPressed: Get.back,
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2BA640),
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            Get.back();
            controller.consolidateUserAccounts(email, primaryUid: primaryUid);
          },
          child: const Text('Consolidate Now'),
        ),
      ],
    ),
  );
}
