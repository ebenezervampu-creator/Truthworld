import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/claim_source_submission_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

export 'package:truthworld/features/video/presentation/controllers/claim_source_submission_controller.dart';

/// 🏛 ClaimSourceSubmissionDialog
///
/// Allows Truthworld Premium subscribers and Channel Members to submit
/// supporting evidence sources for specific claims or the entire video.
class ClaimSourceSubmissionDialog extends StatelessWidget {
  const ClaimSourceSubmissionDialog({
    required this.video,
    super.key,
    this.claims = const [],
    this.initialClaim,
  });

  final Video video;
  final List<dynamic> claims;
  final Map<dynamic, dynamic>? initialClaim;

  static Future<void> show({
    required BuildContext context,
    required Video video,
    List<dynamic> claims = const [],
    Map<dynamic, dynamic>? initialClaim,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClaimSourceSubmissionDialog(
        video: video,
        claims: claims,
        initialClaim: initialClaim,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ClaimSourceSubmissionController>(
      init: ClaimSourceSubmissionController(
        video: video,
        claims: claims,
        initialClaim: initialClaim,
      ),
      builder: (controller) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            top: 24,
            left: 24,
            right: 24,
          ),
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: AppColors.bgDivider),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.library_add_check_rounded,
                        color: AppColors.textPrimary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Provide Evidence Source',
                            style: AppTextStyles.titleMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Submit citations for video claims',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // If not eligible (not Premium or Channel Member), show Upgrade Card
                if (!controller.isEligible)
                  _buildUpgradeCard(context)
                else ...[
                  // Target Selection (Claim or Entire Video)
                  Text(
                    'Target Claim / Scope',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildTargetSelector(controller),
                  const SizedBox(height: 16),

                  // Source URL input
                  Text(
                    'Source URL',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: controller.urlController,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText: 'https://example.com/research-paper',
                      hintStyle: TextStyle(
                        color: AppColors.textSecondary.withValues(alpha: 0.6),
                      ),
                      filled: true,
                      fillColor: AppColors.bgInput,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.bgDivider),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Optional Title / Author
                  Text(
                    'Source Title / Author (Optional)',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: controller.titleController,
                    inputFormatters: TruthworldTextInputFormatters.standard,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g. Nature Journal Article / Harvard Study',
                      hintStyle: TextStyle(
                        color: AppColors.textSecondary.withValues(alpha: 0.6),
                      ),
                      filled: true,
                      fillColor: AppColors.bgInput,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.bgDivider),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Citation Note
                  Text(
                    'Citation Excerpt / Note (Optional)',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: controller.noteController,
                    inputFormatters: TruthworldTextInputFormatters.standard,
                    maxLines: 2,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText:
                          'Briefly explain how this source verifies or clarifies the claim...',
                      hintStyle: TextStyle(
                        color: AppColors.textSecondary.withValues(alpha: 0.6),
                      ),
                      filled: true,
                      fillColor: AppColors.bgInput,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.bgDivider),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Submit button
                  Obx(() {
                    final isSubmitting = controller.isSubmitting.value;
                    return SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: isSubmitting
                            ? null
                            : () => controller.submitSource(context),
                        icon: isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.send_rounded,
                                color: AppColors.textPrimary,
                                size: 18,
                              ),
                        label: Text(
                          isSubmitting
                              ? 'Submitting...'
                              : 'Submit Evidence to Credibility System',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTargetSelector(ClaimSourceSubmissionController controller) {
    final targets = <String>['Entire Video'];
    for (final c in claims) {
      if (c is Map) {
        final text = (c['claim'] ?? c['text'] ?? '').toString();
        if (text.isNotEmpty && !targets.contains(text)) {
          targets.add(text);
        }
      }
    }

    if (!targets.contains(controller.selectedTarget.value)) {
      targets.insert(0, controller.selectedTarget.value);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.bgInput,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: DropdownButtonHideUnderline(
        child: Obx(
          () => DropdownButton<String>(
            value: controller.selectedTarget.value,
            isExpanded: true,
            dropdownColor: AppColors.bgSurface,
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.textPrimary,
            ),
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              fontSize: 13,
            ),
            items: targets.map((t) {
              return DropdownMenuItem<String>(
                value: t,
                child: Text(
                  t,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                controller.selectedTarget.value = val;
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildUpgradeCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFF59E0B).withValues(alpha: 0.15),
            const Color(0xFF10B981).withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.star_rounded,
                color: AppColors.textPrimary,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                'Exclusive Member Feature',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Providing community evidence sources for video claims is reserved for Truthworld Premium members and Channel Members.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                Get.toNamed('/premium');
              },
              icon: const Icon(
                Icons.workspace_premium_rounded,
                color: AppColors.textPrimary,
                size: 18,
              ),
              label: const Text(
                'Upgrade to Truthworld Premium',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
