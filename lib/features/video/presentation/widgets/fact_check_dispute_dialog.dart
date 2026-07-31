import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

/// 🏛 FactCheckDisputeDialog
///
/// Allows channels/creators to dispute fact-checking results,
/// provide reason explanations, and submit additional counter-sources
/// directly to the Credibility System for re-evaluation.
class FactCheckDisputeDialog extends StatefulWidget {
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
  State<FactCheckDisputeDialog> createState() => _FactCheckDisputeDialogState();
}

class _FactCheckDisputeDialogState extends State<FactCheckDisputeDialog> {
  final _reasonController = TextEditingController();
  final _sourceController = TextEditingController();
  final RxList<String> _additionalSources = <String>[].obs;
  final RxBool _isSubmitting = false.obs;

  void _addSource() {
    final text = _sourceController.text.trim();
    if (text.isNotEmpty && !_additionalSources.contains(text)) {
      _additionalSources.add(text);
      _sourceController.clear();
    }
  }

  void _removeSource(int index) {
    _additionalSources.removeAt(index);
  }

  Future<void> _submitDispute() async {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      Get.snackbar(
        'Required Field',
        'Please state why you believe the fact-checking result is incorrect.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.9),
        colorText: Colors.white,
      );
      return;
    }

    if (_additionalSources.isEmpty) {
      Get.snackbar(
        'Sources Required',
        'Please provide at least one supporting source link for the Credibility System to review.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFF59E0B).withValues(alpha: 0.9),
        colorText: Colors.white,
      );
      return;
    }

    _isSubmitting.value = true;

    try {
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('videos').doc(widget.video.id).set(
        {
          'factCheckDispute': {
            'status': 'pending_review',
            'reason': reason,
            'additionalSources': _additionalSources.toList(),
            'submittedAt': FieldValue.serverTimestamp(),
          },
          'credibilityStatus': 'disputed',
        },
        SetOptions(merge: true),
      );

      if (mounted) {
        Navigator.of(context).pop();
        Get.snackbar(
          'Dispute Submitted',
          'Your dispute and sources have been sent to the Credibility System for re-evaluation.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.9),
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      if (mounted) {
        _isSubmitting.value = false;
        Get.snackbar(
          'Submission Error',
          'Failed to submit dispute: $e',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.9),
          colorText: Colors.white,
        );
      }
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _sourceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            const SizedBox(height: 20),

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
              controller: _reasonController,
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
                    controller: _sourceController,
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
                  onPressed: _addSource,
                  icon: const Icon(
                    Icons.add_rounded,
                    color: AppColors.textPrimary,
                    size: 16,
                  ),
                  label: const Text(
                    'Add',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
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
              if (_additionalSources.isEmpty) return const SizedBox.shrink();
              return Column(
                children: [
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _additionalSources.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final src = entry.value;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFF59E0B,
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(
                              0xFFF59E0B,
                            ).withValues(alpha: 0.3),
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
                              onTap: () => _removeSource(idx),
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
              final isSubmitting = _isSubmitting.value;
              return SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: isSubmitting ? null : _submitDispute,
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
                        ? 'Submitting Dispute...'
                        : 'Submit to Credibility System',
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
        ),
      ),
    );
  }
}
