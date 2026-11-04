import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/widgets/truth_lottie_animation.dart';
import 'package:truthworld/features/video/presentation/controllers/claim_comments_controller.dart';
import 'package:truthworld/features/video/presentation/widgets/analysis/comments/add_claim_comment_sheet.dart';
import 'package:truthworld/features/video/presentation/widgets/analysis/comments/claim_comment_tile.dart';
import 'package:truthworld/theme/app_theme.dart';

/// 🏛 ClaimCommunityNotesSection
///
/// Dedicated interactive community deliberation & evidence notes section
/// embedded directly within [ClaimDetailScreen].
class ClaimCommunityNotesSection extends StatelessWidget {
  const ClaimCommunityNotesSection({
    required this.videoId,
    required this.claimIndex,
    required this.claimText,
    this.targetCommentId,
    super.key,
  });

  final String videoId;
  final int claimIndex;
  final String claimText;
  final String? targetCommentId;

  ClaimCommentsController _resolveController() {
    final tag = 'claim_${videoId}_$claimIndex';
    if (Get.isRegistered<ClaimCommentsController>(tag: tag)) {
      final ctrl = Get.find<ClaimCommentsController>(tag: tag);
      ctrl.initForClaim(videoId: videoId, claimIndex: claimIndex);
      return ctrl;
    }
    final ctrl = Get.put(ClaimCommentsController(), tag: tag);
    ctrl.initForClaim(videoId: videoId, claimIndex: claimIndex);
    return ctrl;
  }

  @override
  Widget build(BuildContext context) {
    final controller = _resolveController();
    final effectiveTargetCommentId = targetCommentId ??
        (Get.arguments is Map ? (Get.arguments['commentId'] as String?) : null) ??
        Get.parameters['commentId'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              const Icon(
                Icons.forum_outlined,
                size: 18,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Text(
                'Community Deliberation & Notes',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Obx(() {
                final total = controller.comments.length;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$total',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Peer reviews, counter-evidence, and contextual nuances from verified researchers and community members.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 14),

          // Stance Breakdown & Add Note Action
          Row(
            children: [
              Expanded(
                child: Obx(() {
                  final supports = controller.supportsCount;
                  final disputes = controller.disputesCount;
                  final contextCount = controller.contextCount;

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildFilterChip(
                          label: 'All (${controller.comments.length})',
                          isSelected: controller.selectedStanceFilter.value == 'all',
                          onTap: () => controller.setStanceFilter('all'),
                        ),
                        const SizedBox(width: 6),
                        _buildFilterChip(
                          label: 'Supports ($supports)',
                          isSelected: controller.selectedStanceFilter.value == 'supports',
                          activeColor: AppColors.success,
                          onTap: () => controller.setStanceFilter('supports'),
                        ),
                        const SizedBox(width: 6),
                        _buildFilterChip(
                          label: 'Disputes ($disputes)',
                          isSelected: controller.selectedStanceFilter.value == 'disputes',
                          activeColor: AppColors.error,
                          onTap: () => controller.setStanceFilter('disputes'),
                        ),
                        const SizedBox(width: 6),
                        _buildFilterChip(
                          label: 'Context ($contextCount)',
                          isSelected: controller.selectedStanceFilter.value == 'context',
                          activeColor: AppColors.warning,
                          onTap: () => controller.setStanceFilter('context'),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Add Note Action Button (High Contrast WCAG AA compliant)
          InkWell(
            onTap: () => AddClaimCommentSheet.show(
              context: context,
              videoId: videoId,
              claimIndex: claimIndex,
              claimText: claimText,
              controller: controller,
            ),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.rate_review_outlined,
                    size: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Add a deliberation note or evidence…',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.add_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // List of Deliberation Notes
          Obx(() {
            if (controller.isLoadingComments.value) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: TruthLottieAnimation.aiScanning(size: 36),
                ),
              );
            }

            final filtered = controller.filteredComments;
            if (filtered.isEmpty) {
              return _buildEmptyState(context, controller);
            }

            return Column(
              children: filtered.map((c) {
                return ClaimCommentTile(
                  comment: c,
                  controller: controller,
                  targetCommentId: effectiveTargetCommentId,
                );
              }).toList(),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color activeColor = Colors.white,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? activeColor.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? activeColor : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ClaimCommentsController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(
              Icons.chat_bubble_outline_rounded,
              size: 28,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 8),
            Text(
              'No community deliberation notes yet',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Be the first to provide supporting rationale, counter-evidence, or additional context.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
