import 'package:flutter/material.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification/truth_verification_dialogs.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification/truth_verification_models.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Professional, high-contrast interactive claim card for Studio Truth Verification.
/// Zero raw JSON, zero developer tokens, fully responsive with creator actions.
class TruthVerificationClaimCard extends StatelessWidget {
  const TruthVerificationClaimCard({
    required this.claim,
    required this.video,
    required this.isDarkMode,
    required this.channelId,
    this.onClaimUpdated,
    super.key,
  });

  final RealExtractedClaim claim;
  final VideoFactCheckItem? video;
  final bool isDarkMode;
  final String channelId;
  final VoidCallback? onClaimUpdated;

  @override
  Widget build(BuildContext context) {
    String badgeText;
    Color badgeFg;
    IconData tierIcon;

    if (claim.isHighConcern) {
      badgeText = '🔴 HIGH CONCERN • NO EVIDENCE FOUND';
      badgeFg = AppColors.error;
      tierIcon = Icons.warning_amber_rounded;
    } else if (claim.isNeedsSource) {
      badgeText = '🟡 NEEDS EVIDENCE / CITATION';
      badgeFg = AppColors.warning;
      tierIcon = Icons.help_outline_rounded;
    } else if (claim.isDisputed) {
      badgeText = '🟣 CITATION UNDER REVIEW';
      badgeFg = Colors.purpleAccent;
      tierIcon = Icons.gavel_rounded;
    } else {
      badgeText =
          '🟢 VERIFIED EVIDENCE (${(claim.confidenceScore * 100).toInt()}%)';
      badgeFg = AppColors.success;
      tierIcon = Icons.verified_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.appBarSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.bgSurface,
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Ribbon
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: AppColors.bgInput,
              borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
              border: Border(bottom: BorderSide(color: AppColors.bgSurface)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(tierIcon, size: 16, color: badgeFg),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          badgeText,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: badgeFg,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.appBarSurface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.bgSurface),
                  ),
                  child: Text(
                    claim.timestamp,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (claim.videoTitle.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.movie_outlined,
                        size: 13,
                        color: isDarkMode
                            ? AppColors.textSecondary
                            : Colors.black54,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          claim.videoTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode
                                ? AppColors.textSecondary
                                : Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],

                // Assertion text
                Text(
                  '"${claim.text}"',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontSize: 14,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),

                // Concern / Diagnostic Callout
                if (claim.isHighConcern) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              size: 15,
                              color: AppColors.error,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Creator Concern: No Verifiable Evidence Found',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.error,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          claim.aiExplanation.isNotEmpty
                              ? claim.aiExplanation
                              : 'Our verification scan found no reliable empirical citation for this statement. Provide an official source URL below to clear this flag.',
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.35,
                            color: isDarkMode
                                ? AppColors.textSecondary
                                : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else if (claim.isNeedsSource) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 15,
                              color: AppColors.warning,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Needs Supporting Citation to Verify',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.warning,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          claim.aiExplanation.isNotEmpty
                              ? claim.aiExplanation
                              : 'This statement lacks a direct primary document. Provide an authoritative research or government link below to upgrade this claim to Verified status.',
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.35,
                            color: isDarkMode
                                ? AppColors.textSecondary
                                : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else ...[
                  Row(
                    children: [
                      Icon(
                        Icons.library_books_rounded,
                        size: 13,
                        color: isDarkMode
                            ? AppColors.textSecondary
                            : Colors.black54,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Indexed Source: ${claim.sourceCitation}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDarkMode
                                ? AppColors.textSecondary
                                : Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                if (claim.creatorActionNote != null &&
                    claim.creatorActionNote!.isNotEmpty) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.content_cut_rounded,
                          size: 13,
                          color: AppColors.info,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Creator Resolution: ${claim.creatorActionNote}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.info,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Action Buttons
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () =>
                          TruthVerificationDialogs.showProvideSourceForClaimDialog(
                        context,
                        claim,
                        isDarkMode: isDarkMode,
                        onSubmit: (claimId, sourceUrl, notes) {
                          claim.tier = ClaimEvidenceTier.disputed;
                          AppSnackbar.success(
                            'Authoritative citation submitted for re-evaluation.',
                          );
                          onClaimUpdated?.call();
                        },
                      ),
                      icon: const Icon(
                        Icons.add_link,
                        size: 14,
                        color: Colors.black,
                      ),
                      label: const Text('Provide Source'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (claim.isHighConcern || claim.isNeedsSource)
                      OutlinedButton.icon(
                        onPressed: () =>
                            TruthVerificationDialogs.showMarkVideoEditDialog(
                          context,
                          claim,
                          isDarkMode: isDarkMode,
                          onSave: (note) {
                            claim.creatorActionNote = note;
                            AppSnackbar.success('Action note attached.');
                            onClaimUpdated?.call();
                          },
                        ),
                        icon: const Icon(
                          Icons.edit_note_rounded,
                          size: 14,
                          color: AppColors.warning,
                        ),
                        label: const Text('Mark for Edit'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.warning,
                          side: const BorderSide(color: AppColors.warning),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          textStyle: const TextStyle(fontSize: 11),
                        ),
                      ),
                    if (video != null)
                      OutlinedButton.icon(
                        onPressed: () =>
                            TruthVerificationDialogs.showTruthAiCoachModal(
                          context,
                          claim,
                          video!,
                          isDarkMode: isDarkMode,
                        ),
                        icon: Icon(
                          Icons.psychology_rounded,
                          size: 14,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                        label: const Text('AI Coach'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDarkMode
                              ? AppColors.textPrimary
                              : Colors.black87,
                          side: BorderSide(
                            color: isDarkMode
                                ? AppColors.bgDivider
                                : const Color(0xFFD1D5DB),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          textStyle: const TextStyle(fontSize: 11),
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed: () =>
                          TruthVerificationDialogs.showAskAiWhyDialog(
                        context,
                        claim,
                        isDarkMode: isDarkMode,
                        onProvideSource: (c) => TruthVerificationDialogs
                            .showProvideSourceForClaimDialog(
                          context,
                          c,
                          isDarkMode: isDarkMode,
                          onSubmit: (id, url, notes) {
                            c.tier = ClaimEvidenceTier.disputed;
                            AppSnackbar.success(
                              'Citation queued for AI evaluation.',
                            );
                            onClaimUpdated?.call();
                          },
                        ),
                        onMarkEdit: (c) =>
                            TruthVerificationDialogs.showMarkVideoEditDialog(
                          context,
                          c,
                          isDarkMode: isDarkMode,
                          onSave: (note) {
                            c.creatorActionNote = note;
                            AppSnackbar.success('Action note saved.');
                            onClaimUpdated?.call();
                          },
                        ),
                      ),
                      icon: Icon(
                        Icons.help_outline_rounded,
                        size: 14,
                        color: isDarkMode
                            ? AppColors.textPrimary
                            : Colors.black87,
                      ),
                      label: const Text('Why Flagged?'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDarkMode
                            ? AppColors.textPrimary
                            : Colors.black87,
                        side: BorderSide(
                          color: isDarkMode
                              ? AppColors.bgDivider
                              : const Color(0xFFD1D5DB),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        textStyle: const TextStyle(fontSize: 11),
                      ),
                    ),
                    if (video != null)
                      TextButton.icon(
                        onPressed: () =>
                            TruthVerificationDialogs.showDisputeDialog(
                          context,
                          video!,
                          specificClaim: claim,
                          isDarkMode: isDarkMode,
                          onConfirmDispute: (reason, url) async {
                            claim.tier = ClaimEvidenceTier.disputed;
                            AppSnackbar.success('Claim dispute registered.');
                            onClaimUpdated?.call();
                          },
                        ),
                        icon: const Icon(
                          Icons.gavel_rounded,
                          size: 13,
                          color: AppColors.textSecondary,
                        ),
                        label: const Text(
                          'Dispute Claim',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
