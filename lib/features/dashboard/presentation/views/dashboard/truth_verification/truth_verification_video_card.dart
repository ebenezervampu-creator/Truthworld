import 'package:flutter/material.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification/truth_verification_dialogs.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification/truth_verification_full_inspector_modal.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification/truth_verification_models.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Clean, professional, high-contrast Video Fact-Check Report Card.
/// Engineered for zero layout overflows, responsive mobile/desktop layouts,
/// and instant access to consumer-grade deep analysis + Studio tools.
class TruthVerificationVideoCard extends StatelessWidget {
  const TruthVerificationVideoCard({
    required this.video,
    required this.channelId,
    required this.isDarkMode,
    required this.onToggleApproval,
    required this.onApprove,
    this.onClaimSelected,
    super.key,
  });

  final VideoFactCheckItem video;
  final String channelId;
  final bool isDarkMode;
  final void Function(String videoId, bool currentStatus) onToggleApproval;
  final void Function(String videoId) onApprove;
  final void Function(RealExtractedClaim claim)? onClaimSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.bgSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: video.hasConcerns
              ? AppColors.error.withValues(alpha: 0.5)
              : (isDarkMode ? AppColors.bgDivider : const Color(0xFFE5E7EB)),
          width: video.hasConcerns ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Video Thumbnail + Title + Status Ribbon
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 90,
                  height: 56,
                  color: isDarkMode
                      ? const Color(0xFF242424)
                      : const Color(0xFFE5E7EB),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: video.thumbnailUrl.isNotEmpty
                            ? Image.network(
                                video.thumbnailUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, stack) => Icon(
                                  Icons.video_library_rounded,
                                  color: isDarkMode
                                      ? AppColors.textSecondary
                                      : Colors.black54,
                                ),
                              )
                            : Icon(
                                Icons.video_library_rounded,
                                color: isDarkMode
                                    ? AppColors.textSecondary
                                    : Colors.black54,
                              ),
                      ),
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            TruthVerificationParser.formatTimestamp(
                              video.durationSeconds,
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: TWTypography.brandFamily,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode
                            ? AppColors.textPrimary
                            : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _buildStatusBadge(),
                        if (video.hasConcerns)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  size: 12,
                                  color: AppColors.error,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${video.highConcernClaims.length} Concern Alert',
                                  style: const TextStyle(
                                    color: AppColors.error,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? AppColors.bgPage
                                : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            video.domain,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isDarkMode
                                  ? AppColors.textSecondary
                                  : Colors.black54,
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
          const SizedBox(height: 12),

          // 2. Timeline scrubber preview (if claims exist)
          if (video.claims.isNotEmpty) ...[
            _buildInteractiveTimelineScrubber(context),
            const SizedBox(height: 10),
          ],

          // 3. Score Impact Simulator (if potential boost exists)
          if (video.hasConcerns || video.needsSourceClaims.isNotEmpty) ...[
            _buildScoreImpactSimulator(),
            const SizedBox(height: 10),
          ],

          // 4. Credibility & Evidence Metrics Bar (RESPONSIVE, ZERO OVERFLOW)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDarkMode ? AppColors.bgPage : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDarkMode
                    ? AppColors.bgDivider
                    : const Color(0xFFE5E7EB),
              ),
            ),
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                final isNarrow = constraints.maxWidth < 450;
                final leftContent = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 16,
                      color: video.truthScore >= 0.8
                          ? AppColors.success
                          : (video.truthScore >= 0.5
                              ? AppColors.warning
                              : AppColors.error),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      video.claims.isEmpty
                          ? 'Media Authenticity Verified'
                          : 'Truth Score: ${video.truthScore > 0 ? "${(video.truthScore * 100).toInt()}%" : "N/A"}',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: video.claims.isEmpty
                            ? AppColors.info
                            : (video.truthScore >= 0.8
                                ? AppColors.success
                                : (video.truthScore >= 0.5
                                    ? AppColors.warning
                                    : AppColors.error)),
                      ),
                    ),
                  ],
                );

                final rightContent = Text(
                  video.claims.isEmpty
                      ? 'No empirical assertions • Rhetorical inquiry'
                      : '${video.claims.length} Claims: ${video.verifiedClaims.length} verified, ${video.needsSourceClaims.length} need source, ${video.highConcernClaims.length} concern',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontSize: 11,
                    color: isDarkMode
                        ? AppColors.textSecondary
                        : Colors.black54,
                  ),
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      leftContent,
                      const SizedBox(height: 4),
                      rightContent,
                    ],
                  );
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(child: leftContent),
                    const SizedBox(width: 10),
                    Flexible(child: rightContent),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 14),

          // 5. Card Action Buttons (Clean, Professional Wrap)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () =>
                    TruthVerificationDialogs.showExportAuditDossierModal(
                  context,
                  video,
                  channelId,
                  isDarkMode: isDarkMode,
                ),
                icon: Icon(
                  Icons.description_outlined,
                  size: 14,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
                label: const Text('Export Dossier'),
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      isDarkMode ? AppColors.textPrimary : Colors.black87,
                  side: BorderSide(
                    color: isDarkMode
                        ? AppColors.bgDivider
                        : const Color(0xFFD1D5DB),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),

              ElevatedButton.icon(
                onPressed: () {
                  TruthVerificationFullInspectorModal.open(
                    context,
                    videoItem: video,
                    channelId: channelId,
                    isDarkMode: isDarkMode,
                    onToggleApproval: onToggleApproval,
                  );
                },
                icon: const Icon(
                  Icons.analytics_outlined,
                  size: 15,
                  color: Colors.white,
                ),
                label: const Text('Inspect Full Report'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDarkMode
                      ? AppColors.bgSurfaceHover
                      : const Color(0xFF374151),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              if (video.isPendingApproval)
                ElevatedButton.icon(
                  onPressed: () => onApprove(video.id),
                  icon: const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 15,
                    color: Colors.white,
                  ),
                  label: const Text('Approve for Viewers'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else
                OutlinedButton.icon(
                  onPressed: () => onToggleApproval(
                    video.id,
                    video.isFactCheckApproved,
                  ),
                  icon: Icon(
                    video.isFactCheckApproved
                        ? Icons.visibility_off_rounded
                        : Icons.check_circle_outline_rounded,
                    size: 14,
                    color: isDarkMode
                        ? AppColors.textSecondary
                        : Colors.black54,
                  ),
                  label: Text(
                    video.isFactCheckApproved
                        ? 'Make Private'
                        : 'Publish to Viewers',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        isDarkMode ? AppColors.textPrimary : Colors.black87,
                    side: BorderSide(
                      color: isDarkMode
                          ? AppColors.bgDivider
                          : const Color(0xFFD1D5DB),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),

              OutlinedButton.icon(
                onPressed: () => TruthVerificationDialogs.showDisputeDialog(
                  context,
                  video,
                  isDarkMode: isDarkMode,
                  onConfirmDispute: (reason, url) async {
                    AppSnackbar.success(
                      'Dispute submitted to truth consensus review.',
                    );
                  },
                ),
                icon: const Icon(
                  Icons.gavel_rounded,
                  size: 14,
                  color: AppColors.warning,
                ),
                label: const Text('Dispute'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.warning,
                  side: const BorderSide(color: AppColors.warning),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),

              ElevatedButton.icon(
                onPressed: () => TruthVerificationDialogs.showTalkToAiDialog(
                  context,
                  video,
                  isDarkMode: isDarkMode,
                  onSubmit: (commentary, sources) async {
                    AppSnackbar.success(
                      'Additional sources queued for AI evaluation.',
                    );
                  },
                ),
                icon: const Icon(
                  Icons.psychology_rounded,
                  size: 15,
                  color: Colors.black,
                ),
                label: const Text('Talk to AI (Add Sources)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    if (video.isPendingApproval) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_clock_rounded, size: 12, color: AppColors.warning),
            SizedBox(width: 4),
            Text(
              'Pending Creator Review (Private)',
              style: TextStyle(
                color: AppColors.warning,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }
    if (video.isFactCheckApproved) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 12,
              color: AppColors.success,
            ),
            SizedBox(width: 4),
            Text(
              'Approved (Visible to Viewers)',
              style: TextStyle(
                color: AppColors.success,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.visibility_off_rounded,
            size: 12,
            color: isDarkMode ? AppColors.textSecondary : Colors.black54,
          ),
          const SizedBox(width: 4),
          Text(
            'Held Private',
            style: TextStyle(
              color: isDarkMode ? AppColors.textSecondary : Colors.black54,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveTimelineScrubber(BuildContext context) {
    final totalDuration = video.durationSeconds > 0
        ? video.durationSeconds
        : 600.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.bgPage : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Interactive Claim Timeline',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? AppColors.textSecondary : Colors.black54,
                ),
              ),
              Text(
                'Tap marker dot to inspect',
                style: TextStyle(
                  fontSize: 10,
                  color: isDarkMode
                      ? AppColors.textTertiary
                      : Colors.black38,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (ctx, constraints) {
              final trackWidth = constraints.maxWidth;
              return Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    width: trackWidth,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? const Color(0xFF333333)
                          : const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  ...video.claims.map((claim) {
                    final fraction =
                        (claim.timestampSeconds / totalDuration).clamp(0.0, 1.0);
                    final dotX = (fraction * trackWidth).clamp(0.0, trackWidth - 12);
                    var dotColor = AppColors.success;
                    if (claim.isHighConcern) {
                      dotColor = AppColors.error;
                    } else if (claim.isNeedsSource) {
                      dotColor = AppColors.warning;
                    } else if (claim.isDisputed) {
                      dotColor = Colors.purpleAccent;
                    }

                    return Positioned(
                      left: dotX,
                      child: GestureDetector(
                        onTap: () {
                          if (onClaimSelected != null) {
                            onClaimSelected!(claim);
                          } else {
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
                                    'Citation queued for evaluation.',
                                  );
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
                                },
                              ),
                            );
                          }
                        },
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: dotColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDarkMode ? Colors.black : Colors.white,
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: dotColor.withValues(alpha: 0.6),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '00:00',
                style: TextStyle(fontSize: 9.5, color: AppColors.textTertiary),
              ),
              Text(
                TruthVerificationParser.formatTimestamp(totalDuration),
                style: const TextStyle(
                  fontSize: 9.5,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScoreImpactSimulator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.brandVariant.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.brandVariant.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.trending_up_rounded,
            size: 16,
            color: AppColors.success,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Credibility Booster: Providing sources can boost Truth Score to ${(video.projectedTruthScore * 100).toInt()}% (+${video.boostPercentage}%)',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: AppColors.success,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
