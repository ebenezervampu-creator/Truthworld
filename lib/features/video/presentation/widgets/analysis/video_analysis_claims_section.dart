import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/widgets/analysis/video_analysis_claim_card.dart';
import 'package:truthworld/features/video/presentation/widgets/analysis/video_analysis_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

  class VideoAnalysisClaimsSection extends StatelessWidget {
  final List<dynamic> claims;
  final List<dynamic> allSources;
  final VideoController videoCtrl;
  final VideoAnalysisController analysisCtrl;
  final Video video;
  final int verifiedCount;
  final int cautionCount;
  final int falseCount;

  const VideoAnalysisClaimsSection({
    required this.claims,
    required this.allSources,
    required this.videoCtrl,
    required this.analysisCtrl,
    required this.video,
    this.verifiedCount = 0,
    this.cautionCount = 0,
    this.falseCount = 0,
    super.key,
  });

  BuildContext get context => Get.context!;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.fact_check_outlined,
                  size: 16,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  'FACT-CHECKED CLAIMS (${claims.length})',
                  style: context.twTypography.overline.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textTertiary,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
            if (claims.isNotEmpty)
              Text(
                'Tap to inspect sources',
                style: context.twTypography.caption.copyWith(
                  fontSize: 10,
                  color: AppColors.textTertiary,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),

        // Claim Filter Tabs (All, Verified, Caution, False)
        if (claims.length > 3) ...[
          Obx(() {
            final current = analysisCtrl.selectedClaimFilter.value;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildClaimFilterChip(
                    'All',
                    'All (${claims.length})',
                    current == 'All',
                  ),
                  const SizedBox(width: 8),
                  if (verifiedCount > 0) ...[
                    _buildClaimFilterChip(
                      'Verified',
                      'Verified ($verifiedCount)',
                      current == 'Verified',
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (cautionCount > 0) ...[
                    _buildClaimFilterChip(
                      'Caution',
                      'Caution ($cautionCount)',
                      current == 'Caution',
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (falseCount > 0) ...[
                    _buildClaimFilterChip(
                      'False',
                      'False ($falseCount)',
                      current == 'False',
                      color: AppColors.error,
                    ),
                  ],
                ],
              ),
            );
          }),
          const SizedBox(height: 12),
        ],

        Obx(() {
          final filter = analysisCtrl.selectedClaimFilter.value;
          final filteredClaims = claims.where((claim) {
            if (claim is! Map) return false;
            if (filter == 'All') return true;
            final status = (claim['status'] ?? claim['verificationStatus'] ?? '')
                .toString()
                .toLowerCase();
            final isVerified = status == 'correct' ||
                status == 'mostly_correct' ||
                status == 'verified' ||
                status == 'true' ||
                claim['isVerified'] == true;
            final isFalse = status == 'false' || status == 'incorrect';
            if (filter == 'Verified') return isVerified;
            if (filter == 'False') return isFalse;
            if (filter == 'Caution') return !isVerified && !isFalse;
            return true;
          }).toList();

          if (filteredClaims.isEmpty) {
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.bgDivider),
              ),
              child: Center(
                child: Text(
                  'No claims found in "$filter" category.',
                  style: context.twTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            );
          }

          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredClaims.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final claim = filteredClaims[index];
              final originalIndex = claims.indexOf(claim);
              return VideoAnalysisClaimCard(
                claim: claim as Map,
                index: originalIndex != -1 ? originalIndex : index,
                allClaims: claims,
                allSources: allSources,
                videoCtrl: videoCtrl,
                analysisCtrl: analysisCtrl,
                video: video,
              );
            },
          );
        }),
      ],
    );
  }

  Widget _buildClaimFilterChip(
    String filterKey,
    String label,
    bool isSelected, {
    Color? color,
  }) {
    final activeColor = color ?? AppColors.brand;
    return InkWell(
      onTap: () => analysisCtrl.selectedClaimFilter.value = filterKey,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? activeColor.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Text(
          label,
          style: context.twTypography.caption.copyWith(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

}
