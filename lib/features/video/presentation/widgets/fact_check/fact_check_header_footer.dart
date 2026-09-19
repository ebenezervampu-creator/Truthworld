import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/widgets/fact_check_dispute_dialog.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Top header for the AI Full Disclosure sheet with title, verification badge, and close button.
class FactCheckReportHeader extends StatelessWidget {
  const FactCheckReportHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.bgDivider)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textTertiary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI FULL DISCLOSURE',
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.brand,
                      letterSpacing: 2,
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.verified_user,
                        size: 10,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'CRYPTO-VERIFIED ANALYSIS',
                        style: AppTextStyles.labelSmall.copyWith(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textTertiary,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                onPressed: Get.back,
                icon: const Icon(Icons.close, color: Colors.white),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Footer with institutional disclaimer and dispute action.
class FactCheckReportFooter extends StatelessWidget {
  const FactCheckReportFooter({
    required this.video,
    super.key,
  });

  final Video video;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Divider(color: AppColors.bgDivider),
        const SizedBox(height: 16),
        Text(
          'TruthWorld employs multi-stage AI verification using institutional-grade data sources. This report represents a point-in-time analysis of the audio-visual content provided.',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textTertiary,
            fontSize: 10,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => FactCheckDisputeDialog.show(context, video),
          icon: const Icon(
            Icons.gavel_rounded,
            color: AppColors.textPrimary,
            size: 16,
          ),
          label: const Text(
            'Report Incorrect? Dispute & Provide Sources',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFF59E0B)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }
}

/// Returns the color associated with a credibility/trust score.
Color getFactCheckScoreColor(double score) {
  if (score >= 90) return AppColors.success;
  if (score >= 75) return const Color(0xFFA3E635);
  if (score >= 60) return AppColors.brandHover;
  if (score >= 45) return AppColors.warning;
  if (score >= 30) return AppColors.error;
  return const Color(0xFF991B1B);
}

/// Returns the human-readable integrity label for a score.
String getFactCheckRatingLabel(double score) {
  if (score >= 90) return 'EXCEPTIONAL';
  if (score >= 75) return 'HIGH INTEGRITY';
  if (score >= 60) return 'TRUSTWORTHY';
  if (score >= 45) return 'CAUTION ADVISED';
  if (score >= 30) return 'LOW INTEGRITY';
  return 'UNRELIABLE';
}
