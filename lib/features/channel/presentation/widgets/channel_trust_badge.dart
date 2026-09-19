import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/features/channel/data/models/channel_trust_score.dart';
import 'package:truthworld/theme/app_colors.dart';

class ChannelTrustBadge extends StatelessWidget {
  final ChannelTrustScore? score;

  const ChannelTrustBadge({super.key, this.score});

  @override
  Widget build(BuildContext context) {
    if (score == null) return const SizedBox.shrink();

    final label = score!.trackRecordLabel;

    final Color dotColor;
    switch (label) {
      case 'Highly Reliable':
        dotColor = AppColors.success;
      case 'Mixed Record':
        dotColor = AppColors.warning;
      case 'Low Reliability':
        dotColor = AppColors.error;
      default:
        dotColor = AppColors.textTertiary;
    }

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: AppColors.bgSurface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          builder: (context) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trust Score',
                    style: GoogleFonts.roboto(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: dotColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Track Record: $label',
                        style: GoogleFonts.roboto(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Verification Rate: ${(score!.verificationRate * 100).toStringAsFixed(1)}%',
                    style: GoogleFonts.roboto(
                      color: AppColors.textPrimary70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Based on ${score!.totalVideosAnalyzed} videos analyzed.',
                    style: GoogleFonts.roboto(
                      color: AppColors.textPrimary70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.bgDivider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.roboto(
                color: AppColors.brand,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
