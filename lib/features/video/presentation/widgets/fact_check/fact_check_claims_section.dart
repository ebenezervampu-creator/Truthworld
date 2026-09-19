import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:truthworld/features/video/data/models/claim_verdict_helper.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/widgets/claim_source_submission_dialog.dart';
import 'package:truthworld/features/video/presentation/widgets/fact_check/fact_check_details_section.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Claims verification section with evidence submission trigger.
class FactCheckClaimsSection extends StatelessWidget {
  const FactCheckClaimsSection({
    required this.claims,
    required this.video,
    super.key,
  });

  final List<dynamic> claims;
  final Video video;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'CLAIM VERIFICATION',
              style: AppTextStyles.labelSmall.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textTertiary,
                letterSpacing: 1.5,
              ),
            ),
            TextButton.icon(
              onPressed: () => ClaimSourceSubmissionDialog.show(
                context: context,
                video: video,
                claims: claims,
              ),
              icon: const Icon(
                Icons.add_link_rounded,
                color: AppColors.textPrimary,
                size: 14,
              ),
              label: const Text(
                'Provide Evidence',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (claims.isEmpty)
          const FactCheckEmptyBox(
            text: 'No specific claims extracted for this analysis.',
          )
        else
          ...claims.asMap().entries.map(
                (entry) => FactCheckClaimCard(
                  claim: entry.value as Map<dynamic, dynamic>,
                  claims: claims,
                  video: video,
                  index: entry.key,
                ),
              ),
      ],
    );
  }
}

/// Single claim item card with verdict styling, details, and source contribution.
class FactCheckClaimCard extends StatelessWidget {
  const FactCheckClaimCard({
    required this.claim,
    required this.claims,
    required this.video,
    required this.index,
    super.key,
  });

  final Map<dynamic, dynamic> claim;
  final List<dynamic> claims;
  final Video video;
  final int index;

  @override
  Widget build(BuildContext context) {
    final verdict = ClaimVerdictHelper.resolveVerdict(claim);
    final color = verdict.color;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(color: color, width: 4),
          top: BorderSide(color: color.withValues(alpha: 0.15)),
          right: BorderSide(color: color.withValues(alpha: 0.15)),
          bottom: BorderSide(color: color.withValues(alpha: 0.15)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  verdict.icon,
                  color: Colors.white,
                  size: 13,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            verdict.label,
                            style: AppTextStyles.labelSmall.copyWith(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: color,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        if (verdict.confidenceText != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            verdict.confidenceText!,
                            style: AppTextStyles.labelSmall.copyWith(
                              fontSize: 9,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      ClaimVerdictHelper.cleanClaimText(
                        claim['claim'] ?? claim['text'],
                        index,
                      ),
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                    if (claim['explanation'] != null ||
                        claim['reasoning'] != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        ClaimVerdictHelper.cleanResponseText(
                          claim['explanation'] ?? claim['reasoning'],
                        ),
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textTertiary,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => ClaimSourceSubmissionDialog.show(
                context: context,
                video: video,
                claims: claims,
                initialClaim: claim,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.add_link_rounded,
                      size: 14,
                      color: AppColors.textPrimary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Provide Source for Claim',
                      style: TextStyle(
                        fontSize: 11,
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: (600 + (index * 100)).ms).slideX(begin: 0.05);
  }
}
