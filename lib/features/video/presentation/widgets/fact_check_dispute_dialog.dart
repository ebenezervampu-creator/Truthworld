import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/utils/source_url_sanitizer.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Controller managing fact-check dispute form state, validation, and submission.
class FactCheckDisputeController extends GetxController {
  final reasonController = TextEditingController();
  final sourceController = TextEditingController();
  final RxList<String> additionalSources = <String>[].obs;
  final RxBool isSubmitting = false.obs;

  void addSource() {
    final text = sourceController.text.trim();
    final validation = SourceUrlSanitizer.validateAuthoritativeSource(text);
    if (!validation.isValid) {
      AppSnackbar.warning(
        validation.errorMessage ??
            'Please enter a valid source URL (e.g. https://reuters.com).',
      );
      return;
    }

    final cleanUrl = validation.normalizedUrl!;
    if (additionalSources.contains(cleanUrl)) {
      AppSnackbar.info('This source is already added.');
      return;
    }

    additionalSources.add(cleanUrl);
    sourceController.clear();
  }

  void removeSource(int index) {
    if (index >= 0 && index < additionalSources.length) {
      additionalSources.removeAt(index);
    }
  }

  Future<void> submitDispute(BuildContext context, Video video) async {
    final reason = reasonController.text.trim();
    final validation = ContentValidator.validate(
      reason,
      fieldName: 'Dispute Reason',
      minLength: 10,
      maxLength: 2000,
    );
    if (!validation.isValid) {
      AppSnackbar.warning(validation.message);
      return;
    }

    if (additionalSources.isEmpty) {
      AppSnackbar.warning(
        'Please provide at least one supporting source link for the Credibility System to review.',
      );
      return;
    }

    isSubmitting.value = true;

    try {
      final firestore = FirebaseFirestore.instance;
      await firestore.collection(FirestoreCollections.videos).doc(video.id).set(
        {
          'factCheckDispute': {
            'status': 'pending_review',
            'reason': reason,
            'additionalSources': additionalSources.toList(),
            'submittedAt': FieldValue.serverTimestamp(),
            'consensusStatus': 'pending_cross_perspective',
          },
          'credibilityStatus': 'disputed',
        },
        SetOptions(merge: true),
      );

      if (context.mounted) {
        Navigator.of(context).pop();
        AppSnackbar.success(
          'Your dispute and sources have been sent to the Credibility System for cross-perspective re-evaluation.',
        );
      }
    } catch (e) {
      ErrorHandler.log(e);
      isSubmitting.value = false;
      AppSnackbar.error(
        'Unable to submit dispute. Please try again.',
      );
    }
  }

  @override
  void onClose() {
    reasonController.dispose();
    sourceController.dispose();
    super.onClose();
  }
}

/// Modal dialog allowing creators and viewers to submit factual disputes with counter-sources.
/// Governed by Cross-Perspective Consensus to prevent factional brigading.
class FactCheckDisputeDialog extends StatelessWidget {
  const FactCheckDisputeDialog({
    required this.video,
    super.key,
  });

  final Video video;

  static Future<void> show(BuildContext context, Video video) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FactCheckDisputeDialog(video: video),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(FactCheckDisputeController());

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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.gavel_rounded,
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
                        'Dispute Fact-Checking Result',
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Submit counter-sources to the Credibility System',
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
            const SizedBox(height: 16),

            // Anti-Brigading Notice
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.bgDivider),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.balance_rounded,
                    size: 16,
                    color: AppColors.brand,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'TruthWorld uses Cross-Perspective Bridging. Disputes require corroboration across diverse contributor clusters to prevent brigading.',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Reason input
            Text(
              'Why is this Fact-Checking result incorrect?',
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl.reasonController,
              inputFormatters: TruthworldTextInputFormatters.standard,
              maxLines: 4,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText:
                    'Explain the error or missing context in the automated evaluation...',
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
            const SizedBox(height: 20),

            // Source input
            Text(
              'Provide Supporting Sources / References',
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Add links to academic studies, news reports, or official documents.',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: ctrl.sourceController,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText: 'https://example.com/evidence-link',
                      hintStyle: TextStyle(
                        color: AppColors.textSecondary.withValues(alpha: 0.6),
                      ),
                      filled: true,
                      fillColor: AppColors.bgInput,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: AppColors.bgDivider,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: ctrl.addSource,
                  icon: const Icon(
                    Icons.add_rounded,
                    color: Colors.black,
                    size: 16,
                  ),
                  label: const Text(
                    'Add',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),

            Obx(() {
              if (ctrl.additionalSources.isEmpty) return const SizedBox.shrink();
              return Column(
                children: [
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: ctrl.additionalSources.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final src = entry.value;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 220),
                              child: Text(
                                src,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () => ctrl.removeSource(idx),
                              child: const Icon(
                                Icons.close_rounded,
                                color: AppColors.textPrimary,
                                size: 14,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              );
            }),

            const SizedBox(height: 24),
            Obx(() {
              final isSubmitting = ctrl.isSubmitting.value;
              return SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: isSubmitting ? null : () => ctrl.submitDispute(context, video),
                  icon: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Icon(
                          Icons.send_rounded,
                          color: Colors.black,
                          size: 18,
                        ),
                  label: Text(
                    isSubmitting
                        ? 'Submitting Dispute...'
                        : 'Submit to Credibility System',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
