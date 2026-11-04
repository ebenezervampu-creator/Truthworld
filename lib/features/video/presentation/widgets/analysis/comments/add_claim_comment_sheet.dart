import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/utils/source_url_sanitizer.dart';
import 'package:truthworld/features/video/presentation/controllers/claim_comments_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// 🏛 AddClaimCommentSheet
///
/// Modal bottom sheet allowing viewers and researchers to draft an evidence-backed
/// community deliberation note with clear stance selection and citation links.
class AddClaimCommentSheet extends StatelessWidget {
  const AddClaimCommentSheet({
    required this.videoId,
    required this.claimIndex,
    required this.claimText,
    required this.controller,
    super.key,
  });

  final String videoId;
  final int claimIndex;
  final String claimText;
  final ClaimCommentsController controller;

  static Future<void> show({
    required BuildContext context,
    required String videoId,
    required int claimIndex,
    required String claimText,
    required ClaimCommentsController controller,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddClaimCommentSheet(
        videoId: videoId,
        claimIndex: claimIndex,
        claimText: claimText,
        controller: controller,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(color: AppColors.bgDivider),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Title Row
              Row(
                children: [
                  const Icon(
                    Icons.rate_review_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Add Community Note',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textSecondary,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: Get.back,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Submit empirical context, counter-evidence, or supporting rationale for this claim.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 14),

              // Claim Statement Context Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.format_quote_rounded,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Claim #${claimIndex + 1}: $claimText',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Stance Selection
              Text(
                'SELECT YOUR STANCE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 8),
              Obx(() {
                final currentStance = controller.newCommentStance.value;
                return Row(
                  children: [
                    Expanded(
                      child: _buildStanceOption(
                        label: 'Supports',
                        icon: Icons.check_circle_outline_rounded,
                        isSelected: currentStance == 'supports',
                        activeColor: AppColors.success,
                        activeBg: const Color(0xFF052e16),
                        activeBorder: const Color(0xFF059669),
                        onTap: () => controller.setNewCommentStance('supports'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStanceOption(
                        label: 'Disputes',
                        icon: Icons.cancel_outlined,
                        isSelected: currentStance == 'disputes',
                        activeColor: AppColors.error,
                        activeBg: const Color(0xFF310B10),
                        activeBorder: const Color(0xFFE11D48),
                        onTap: () => controller.setNewCommentStance('disputes'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStanceOption(
                        label: 'Context',
                        icon: Icons.info_outline_rounded,
                        isSelected: currentStance == 'context',
                        activeColor: AppColors.warning,
                        activeBg: const Color(0xFF261905),
                        activeBorder: const Color(0xFFD97706),
                        onTap: () => controller.setNewCommentStance('context'),
                      ),
                    ),
                  ],
                );
              }),
              const SizedBox(height: 14),

              // Note text input
              TextField(
                controller: controller.noteTextController,
                maxLines: 4,
                maxLength: 2000,
                style: TextStyle(
                  fontSize: 13.5,
                  color: Colors.white,
                ),
                decoration: InputDecoration(
                  hintText: 'Explain the factual evidence or context clearly…',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: AppColors.textTertiary,
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.04),
                  counterStyle: TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 8),

              // Optional Evidence Link Input
              Text(
                'ATTACH CITATION LINK (OPTIONAL)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller.sourceUrlController,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.white,
                      ),
                      decoration: InputDecoration(
                        hintText: 'https://example.org/study-or-report',
                        hintStyle: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textTertiary,
                        ),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.04),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.white),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onSubmitted: controller.addAttachedSource,
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    icon: const Icon(Icons.add_link_rounded, size: 16),
                    label: const Text('Add Link'),
                    onPressed: () =>
                        controller.addAttachedSource(controller.sourceUrlController.text),
                  ),
                ],
              ),

              // Display attached citation links
              Obx(() {
                if (controller.attachedSources.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: controller.attachedSources.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final url = entry.value;
                      final domain = SourceUrlSanitizer.resolveDisplayDomain(url);
                      return Chip(
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        avatar: const Icon(
                          Icons.link_rounded,
                          size: 14,
                          color: Colors.white70,
                        ),
                        label: Text(
                          domain,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.white,
                          ),
                        ),
                        deleteIcon: const Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: Colors.white70,
                        ),
                        onDeleted: () => controller.removeAttachedSource(idx),
                      );
                    }).toList(),
                  ),
                );
              }),
              const SizedBox(height: 16),

              // Submit Button (High Contrast WCAG AA Compliance: White button with Black foreground)
              SizedBox(
                width: double.infinity,
                height: 46,
                child: Obx(() {
                  final isSubmitting = controller.isSubmitting.value;
                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final success = await controller.submitNote(
                              videoId: videoId,
                              claimIndex: claimIndex,
                              claimText: claimText,
                            );
                            if (success) {
                              Get.back();
                            }
                          },
                    child: isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                            ),
                          )
                        : Text(
                            'Publish Community Note',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStanceOption({
    required String label,
    required IconData icon,
    required bool isSelected,
    required Color activeColor,
    required Color activeBg,
    required Color activeBorder,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? activeBorder : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? activeColor : Colors.white70,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? activeColor : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
