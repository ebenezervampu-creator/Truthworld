import 'package:flutter/material.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/copyright_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Static helper for showing copyright-related dialogs and interactive flows.
class CopyrightDialogs {
  const CopyrightDialogs._();

  /// Shows contact dialog to send a courteous warning notice to the uploader of a matched video.
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

    final dialogBg = isDarkMode ? AppColors.bgSurface : Colors.white;
    final primaryTextColor = isDarkMode ? AppColors.textPrimary : Colors.black87;
    final secondaryTextColor =
        isDarkMode ? AppColors.textSecondary : Colors.black54;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: dialogBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDarkMode ? AppColors.bgDivider : Colors.grey.shade300,
          ),
        ),
        title: Text(
          'Contact Channel Owner',
          style: TextStyle(
            fontFamily: TWTypography.brandFamily,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: primaryTextColor,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Send a courteous notice requesting the creator to delete the re-uploaded clip before filing a formal DMCA takedown.',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                fontSize: 13,
                color: secondaryTextColor,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: messageController,
              maxLength: 1000,
              buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
              inputFormatters: TruthworldTextInputFormatters.internationalWithLimit(1000),
              maxLines: 4,
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: primaryTextColor,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                labelText: 'Notice Message',
                labelStyle: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: secondaryTextColor,
                ),
                filled: true,
                fillColor: isDarkMode ? AppColors.bgInput : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDarkMode ? AppColors.bgDivider : Colors.grey.shade300,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDarkMode ? AppColors.bgDivider : Colors.grey.shade300,
                  ),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide(color: AppColors.info, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: secondaryTextColor,
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
    var is7DayScheduled = false;

    final dialogBg = isDarkMode ? AppColors.bgSurface : Colors.white;
    final primaryTextColor = isDarkMode ? AppColors.textPrimary : Colors.black87;
    final secondaryTextColor =
        isDarkMode ? AppColors.textSecondary : Colors.black54;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: dialogBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isDarkMode ? AppColors.bgDivider : Colors.grey.shade300,
            ),
          ),
          title: Text(
            'Submit DMCA Removal Request?',
            style: TextStyle(
              fontFamily: TWTypography.brandFamily,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: primaryTextColor,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filing a formal removal request for "$title" uploaded by $channelName '
                'will issue an official takedown notice under Truthworld Copyright Policy.',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontSize: 14,
                  color: secondaryTextColor,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? AppColors.bgSurfaceHigh
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDarkMode
                        ? AppColors.bgDivider
                        : Colors.grey.shade300,
                  ),
                ),
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: is7DayScheduled,
                  activeColor: AppColors.info,
                  onChanged: (val) {
                    setDialogState(() {
                      is7DayScheduled = val ?? false;
                    });
                  },
                  title: Text(
                    'Give 7-day notice before takedown',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: primaryTextColor,
                    ),
                  ),
                  subtitle: Text(
                    'Allows the uploader 7 days to remove the video voluntarily to prevent receiving a copyright strike.',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontSize: 11,
                      color: secondaryTextColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: secondaryTextColor,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final success = await controller.submitRemovalRequest(
                  videoId: videoId,
                  title: title,
                  channelName: channelName,
                  isScheduled7Day: is7DayScheduled,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                if (success) {
                  AppSnackbar.success(
                    is7DayScheduled
                        ? '7-Day notice submitted for "$title".'
                        : 'Removal request submitted for "$title".',
                  );
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
      ),
    );
  }

  /// Shows the dispute modal allowing creators to contest Content ID or copyright claims.
  static void showDisputeClaim({
    required BuildContext context,
    required String claimId,
    required String videoTitle,
    required String claimant,
    required bool isDarkMode,
  }) {
    var selectedReason = 'Original Content';
    final explanationController = TextEditingController();
    var hasConfirmed = false;

    final dialogBg = isDarkMode ? AppColors.bgSurface : Colors.white;
    final primaryTextColor = isDarkMode ? AppColors.textPrimary : Colors.black87;
    final secondaryTextColor =
        isDarkMode ? AppColors.textSecondary : Colors.black54;

    final reasons = [
      'Original Content (I own all rights)',
      'Valid License or Permission',
      'Fair Use (Commentary, critique, education)',
      'Public Domain Content',
    ];

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: dialogBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isDarkMode ? AppColors.bgDivider : Colors.grey.shade300,
            ),
          ),
          title: Text(
            'Dispute Copyright Claim',
            style: TextStyle(
              fontFamily: TWTypography.brandFamily,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: primaryTextColor,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Disputing claim from "$claimant" for video "$videoTitle".',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontSize: 13,
                    color: secondaryTextColor,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'DISPUTE REASON',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: secondaryTextColor,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? AppColors.bgInput
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDarkMode
                          ? AppColors.bgDivider
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      dropdownColor: dialogBg,
                      value: selectedReason,
                      items: reasons.map((r) {
                        return DropdownMenuItem(
                          value: r,
                          child: Text(
                            r,
                            style: TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              fontSize: 13,
                              color: primaryTextColor,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedReason = val);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: explanationController,
                  maxLines: 3,
                  maxLength: 500,
                  buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontSize: 13,
                    color: primaryTextColor,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Explanation & Evidence',
                    labelStyle: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: secondaryTextColor,
                    ),
                    filled: true,
                    fillColor: isDarkMode
                        ? AppColors.bgInput
                        : Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: isDarkMode
                            ? AppColors.bgDivider
                            : Colors.grey.shade300,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: isDarkMode
                            ? AppColors.bgDivider
                            : Colors.grey.shade300,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: hasConfirmed,
                  activeColor: AppColors.info,
                  onChanged: (val) {
                    setDialogState(() => hasConfirmed = val ?? false);
                  },
                  title: Text(
                    'I believe in good faith that this claim is an error.',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontSize: 12,
                      color: primaryTextColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: secondaryTextColor,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: hasConfirmed
                  ? () {
                      final exp = explanationController.text.trim();
                      if (exp.length < 5) {
                        AppSnackbar.warning(
                          'Please provide a brief explanation for your dispute.',
                        );
                        return;
                      }
                      Navigator.pop(ctx);
                      AppSnackbar.success(
                        'Dispute filed for "$videoTitle". Claimant has 30 days to respond.',
                      );
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Submit Dispute',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shows the Copyright Policy and Safe Harbor educational walkthrough.
  static void showCopyrightEducation({
    required BuildContext context,
    required bool isDarkMode,
  }) {
    final dialogBg = isDarkMode ? AppColors.bgSurface : Colors.white;
    final primaryTextColor = isDarkMode ? AppColors.textPrimary : Colors.black87;
    final secondaryTextColor =
        isDarkMode ? AppColors.textSecondary : Colors.black54;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: dialogBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Understanding Copyright & Content ID',
                    style: TextStyle(
                      fontFamily: TWTypography.brandFamily,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryTextColor,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: primaryTextColor),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildEduItem(
                icon: Icons.gavel_rounded,
                iconColor: AppColors.error,
                title: 'Copyright Strike (DMCA Takedown)',
                description:
                    'Issued when a legal rights holder requests removal under 17 U.S.C. § 512. 3 strikes result in channel termination. Strikes expire after 90 days.',
                primaryTextColor: primaryTextColor,
                secondaryTextColor: secondaryTextColor,
              ),
              const SizedBox(height: 14),
              _buildEduItem(
                icon: Icons.audiotrack_rounded,
                iconColor: AppColors.info,
                title: 'Content ID Claim',
                description:
                    'Automated match against cataloged audio or video. Does not issue a copyright strike and does not harm your channel standing.',
                primaryTextColor: primaryTextColor,
                secondaryTextColor: secondaryTextColor,
              ),
              const SizedBox(height: 14),
              _buildEduItem(
                icon: Icons.balance_rounded,
                iconColor: AppColors.success,
                title: 'Fair Use Doctrine',
                description:
                    'Criticism, news reporting, parody, or transformative commentary may qualify as fair use under copyright law.',
                primaryTextColor: primaryTextColor,
                secondaryTextColor: secondaryTextColor,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Got It',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildEduItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required Color primaryTextColor,
    required Color secondaryTextColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontSize: 12,
                  color: secondaryTextColor,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
