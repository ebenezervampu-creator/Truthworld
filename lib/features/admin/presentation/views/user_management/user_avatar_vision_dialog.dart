import 'package:flutter/material.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/features/admin/presentation/views/user_management/user_management_badges.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Displays the Google Cloud Vision AI avatar audit inspection modal dialog.
void showAvatarVisionInspectionDialog(
  BuildContext context,
  AdminController controller,
  Map<String, dynamic> user,
) {
  final photoUrl = (user['photoURL'] ?? user['avatarUrl'] ?? '').toString();
  final name = (user['name'] ?? user['displayName'] ?? 'User').toString();
  final userId = (user['id'] ?? user['uid'] ?? '').toString();
  final avatarFileId = (user['avatarFileId'] ?? '').toString();
  final avatarStatus =
      (user['avatarStatus'] ?? 'UNVERIFIED').toString().toUpperCase();
  final avatarReason = (user['avatarStatusReason'] ?? '').toString();

  showDialog<void>(
    context: context,
    builder: (dialogCtx) {
      return Dialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dialog Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.verified_user,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Google Cloud Vision AI Inspection',
                            style: TextStyle(
                              fontFamily: TWTypography.brandFamily,
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Avatar safety audit for $name',
                            style: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(dialogCtx),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Avatar Large Image Preview with Status Badge
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF2A2A2A),
                          border: Border.all(
                            color: avatarStatus == 'APPROVED'
                                ? const Color(0xFF2BA640)
                                : (avatarStatus == 'REJECTED'
                                    ? AppColors.error
                                    : (avatarStatus == 'PENDING'
                                        ? Colors.blue
                                        : Colors.white
                                            .withValues(alpha: 0.2))),
                            width: 3,
                          ),
                          image: photoUrl.isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage(photoUrl),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: photoUrl.isEmpty
                            ? Center(
                                child: Text(
                                  name.isNotEmpty
                                      ? name.substring(0, 1).toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                    fontFamily: TWTypography.brandFamily,
                                    color: AppColors.textPrimary,
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 12),
                      UserVisionStatusBadge(status: avatarStatus),
                      if (avatarReason.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            avatarReason,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              color: AppColors.textTertiary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                Divider(color: Colors.white.withValues(alpha: 0.08)),
                const SizedBox(height: 16),

                // FutureBuilder to load real Cloud Vision SafeSearch data
                FutureBuilder<Map<String, dynamic>?>(
                  future: controller.fetchAvatarVerification(
                    userId,
                    avatarFileId: avatarFileId,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Center(
                          child: Column(
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(height: 10),
                              Text(
                                'Loading Cloud Vision AI analysis...',
                                style: TextStyle(
                                  fontFamily: TWTypography.uiFamily,
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final verifData = snapshot.data;
                    final detailedScores = (verifData?['detailedScores']
                            as Map<String, dynamic>?) ??
                        {};
                    final overallScore = verifData?['score'] ?? 0;
                    final gcsUri = verifData?['gcsUri'] ??
                        verifData?['filePath'] ??
                        '';

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'SafeSearch Criteria Scores',
                              style: TextStyle(
                                fontFamily: TWTypography.brandFamily,
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Severity: $overallScore / 5',
                              style: const TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Scores Grid (Adult, Racy, Violence, Medical, Spoof)
                        Row(
                          children: [
                            UserVisionScoreTile(label: 'Adult', rawScore: detailedScores['adult']),
                            const SizedBox(width: 8),
                            UserVisionScoreTile(label: 'Racy', rawScore: detailedScores['racy']),
                            const SizedBox(width: 8),
                            UserVisionScoreTile(
                                label: 'Violence', rawScore: detailedScores['violence']),
                            const SizedBox(width: 8),
                            UserVisionScoreTile(
                                label: 'Medical', rawScore: detailedScores['medical']),
                            const SizedBox(width: 8),
                            UserVisionScoreTile(label: 'Spoof', rawScore: detailedScores['spoof']),
                          ],
                        ),

                        if (gcsUri.toString().isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF141414),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color:
                                      Colors.white.withValues(alpha: 0.05)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.storage,
                                    size: 14, color: Colors.white),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    gcsUri.toString(),
                                    style: const TextStyle(
                                      fontFamily: TWTypography.uiFamily,
                                      color: AppColors.textTertiary,
                                      fontSize: 11,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),

                const SizedBox(height: 24),
                Divider(color: Colors.white.withValues(alpha: 0.08)),
                const SizedBox(height: 16),

                // Admin Moderation Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.error),
                          foregroundColor: AppColors.error,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.cancel_outlined,
                            color: Colors.white, size: 16),
                        label: const Text(
                          'Reject Avatar',
                          style: TextStyle(
                            fontFamily: TWTypography.brandFamily,
                            fontWeight: FontWeight.bold,
                            color: AppColors.error,
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(dialogCtx);
                          showRejectAvatarPrompt(
                              context, controller, userId, avatarFileId);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2BA640),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.check_circle_outline,
                            color: Colors.white, size: 16),
                        label: const Text(
                          'Approve Avatar',
                          style: TextStyle(
                            fontFamily: TWTypography.brandFamily,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(dialogCtx);
                          controller.moderateUserAvatar(
                            userId: userId,
                            action: 'approve',
                            avatarFileId: avatarFileId.isNotEmpty
                                ? avatarFileId
                                : null,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Score tile component displaying severity for a specific SafeSearch criterion.
class UserVisionScoreTile extends StatelessWidget {
  final String label;
  final dynamic rawScore;

  const UserVisionScoreTile({
    required this.label,
    required this.rawScore,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    var score = 0;
    if (rawScore is num) {
      score = (rawScore as num).toInt();
    } else if (rawScore is String) {
      final s = (rawScore as String).toUpperCase();
      if (s == 'VERY_UNLIKELY') {
        score = 0;
      } else if (s == 'UNLIKELY') {
        score = 1;
      } else if (s == 'POSSIBLE') {
        score = 2;
      } else if (s == 'LIKELY') {
        score = 3;
      } else if (s == 'VERY_LIKELY') {
        score = 4;
      } else {
        score = int.tryParse(s) ?? 0;
      }
    }

    Color color;
    if (score == 0) {
      color = const Color(0xFF2BA640);
    } else if (score == 1) {
      color = const Color(0xFF8BC34A);
    } else if (score == 2) {
      color = Colors.amber;
    } else if (score == 3) {
      color = Colors.orange;
    } else {
      color = AppColors.error;
    }

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '$score/4',
              style: TextStyle(
                fontFamily: TWTypography.brandFamily,
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Displays a modal prompt to input a violation reason and reject an avatar.
void showRejectAvatarPrompt(
  BuildContext context,
  AdminController controller,
  String userId,
  String avatarFileId,
) {
  final reasonController = TextEditingController();
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: const Text(
        'Reject User Avatar',
        style: TextStyle(
          fontFamily: TWTypography.brandFamily,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Specify reason for rejecting this avatar (e.g. nudity, violence, spoof, low quality):',
            style: TextStyle(
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
              hintText: 'Safety violation reason...',
              hintStyle: const TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.textTertiary,
              ),
              filled: true,
              fillColor: AppColors.bgInput,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
            ),
            maxLines: 2,
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
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            final reason = reasonController.text.trim();
            if (reason.isNotEmpty) {
              final val = ContentValidator.validate(reason, checkEnglishOnly: false, fieldName: 'Violation Reason');
              if (!val.isValid) {
                AppSnackbar.warning(val.message);
                return;
              }
            }
            Navigator.pop(ctx);
            controller.moderateUserAvatar(
              userId: userId,
              action: 'reject',
              avatarFileId:
                  avatarFileId.isNotEmpty ? avatarFileId : null,
              reason: reason.isNotEmpty
                  ? reason
                  : 'Avatar violates safety guidelines',
            );
          },
          child: const Text(
            'Reject',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );
}
