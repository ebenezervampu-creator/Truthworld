import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/widgets/truth_lottie_animation.dart';
import 'package:truthworld/features/video/data/models/fact_check_data_parser.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/claim_comments_controller.dart';
import 'package:truthworld/features/video/presentation/widgets/analysis/comments/claim_comment_tile.dart';
import 'package:truthworld/theme/app_theme.dart';

/// 🏛 VideoCommunityNotesTab
///
/// Comprehensive view aggregating all community deliberation notes
/// across all claims of a video within the Credibility & Intelligence dashboard.
class VideoCommunityNotesTab extends StatelessWidget {
  const VideoCommunityNotesTab({
    required this.video,
    required this.parsed,
    super.key,
  });

  final Video video;
  final ParsedFactCheckData parsed;

  ClaimCommentsController _resolveController() {
    final tag = 'video_notes_${video.id}';
    if (Get.isRegistered<ClaimCommentsController>(tag: tag)) {
      final ctrl = Get.find<ClaimCommentsController>(tag: tag);
      ctrl.initForClaim(videoId: video.id);
      return ctrl;
    }
    final ctrl = Get.put(ClaimCommentsController(), tag: tag);
    ctrl.initForClaim(videoId: video.id);
    return ctrl;
  }

  @override
  Widget build(BuildContext context) {
    final controller = _resolveController();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner introducing community deliberation
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.bgDivider),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.psychology_alt_outlined,
                  size: 22,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Community Notes & Deliberation',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Decentralized peer review and empirical evidence contributed by researchers across all verified claims.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Stance filter chips
          Obx(() {
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
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    label: 'Supports Verdict ($supports)',
                    isSelected: controller.selectedStanceFilter.value == 'supports',
                    activeColor: AppColors.success,
                    onTap: () => controller.setStanceFilter('supports'),
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    label: 'Disputes Verdict ($disputes)',
                    isSelected: controller.selectedStanceFilter.value == 'disputes',
                    activeColor: AppColors.error,
                    onTap: () => controller.setStanceFilter('disputes'),
                  ),
                  const SizedBox(width: 8),
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
          const SizedBox(height: 16),

          // Deliberation comments list
          Obx(() {
            if (controller.isLoadingComments.value) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: TruthLottieAnimation.aiScanning(size: 44),
                ),
              );
            }

            final comments = controller.filteredComments;
            if (comments.isEmpty) {
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.bgDivider),
                ),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.speaker_notes_off_outlined,
                        size: 36,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No community notes in this filter',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Open any claim from the Fact Claims tab to contribute the first evidence note.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              children: comments.map((c) {
                return ClaimCommentTile(
                  comment: c,
                  controller: controller,
                  isEmbeddedInVideoView: true,
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? activeColor : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
