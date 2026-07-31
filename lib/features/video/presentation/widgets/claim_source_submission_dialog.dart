import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

/// 🏛 ClaimSourceSubmissionDialog
///
/// Allows Truthworld Premium subscribers and Channel Members to submit
/// supporting evidence sources for specific claims or the entire video.
class ClaimSourceSubmissionDialog extends StatefulWidget {
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
  State<ClaimSourceSubmissionDialog> createState() =>
      _ClaimSourceSubmissionDialogState();
}

class _ClaimSourceSubmissionDialogState
    extends State<ClaimSourceSubmissionDialog> {
  final _urlController = TextEditingController();
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();
  late final RxString _selectedTarget;
  final RxBool _isSubmitting = false.obs;

  bool get _isPremiumUser => AuthService.to.isPremiumUser.value;
  bool get _isChannelOwner =>
      AuthService.to.user?.uid != null &&
      (AuthService.to.user!.uid == widget.video.ownerId ||
          AuthService.to.user!.uid == widget.video.channelId);

  // Users are eligible if they are Premium subscribers or Channel Owners/Members
  bool get _isEligible => _isPremiumUser || _isChannelOwner;

  @override
  void initState() {
    super.initState();
    if (widget.initialClaim != null) {
      _selectedTarget =
          (widget.initialClaim!['claim'] ?? widget.initialClaim!['text'] ?? '')
              .toString()
              .obs;
    } else {
      _selectedTarget = 'Entire Video'.obs;
    }
  }

  Future<void> _submitSource() async {
    final url = _urlController.text.trim();
    if (url.isEmpty || !url.startsWith('http')) {
      Get.snackbar(
        'Invalid Source URL',
        'Please enter a valid HTTP/HTTPS source link.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.9),
        colorText: Colors.white,
      );
      return;
    }

    _isSubmitting.value = true;

    try {
      final user = AuthService.to.user;
      final firestore = FirebaseFirestore.instance;

      final sourceData = {
        'videoId': widget.video.id,
        'target': _selectedTarget.value,
        'url': url,
        'title': _titleController.text.trim(),
        'note': _noteController.text.trim(),
        'submittedBy': user?.uid,
        'submittedByEmail': user?.email,
        'submittedByName': user?.displayName ?? 'Anonymous User',
        'submittedAt': FieldValue.serverTimestamp(),
        'status': 'pending_review',
      };

      await firestore.collection('claim_sources').add(sourceData);

      if (mounted) {
        Navigator.of(context).pop();
        Get.snackbar(
          'Source Submitted',
          'Thank you! Your supporting evidence has been submitted for credibility review.',
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
          'Submission Failed',
          'Failed to submit source: $e',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.9),
          colorText: Colors.white,
        );
      }
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _titleController.dispose();
    _noteController.dispose();
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
            if (!_isEligible)
              _buildUpgradeCard()
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
              _buildTargetSelector(),
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
                controller: _urlController,
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
                controller: _titleController,
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
                controller: _noteController,
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
                final isSubmitting = _isSubmitting.value;
                return SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: isSubmitting ? null : _submitSource,
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
  }

  Widget _buildTargetSelector() {
    final targets = <String>['Entire Video'];
    for (final c in widget.claims) {
      if (c is Map) {
        final text = (c['claim'] ?? c['text'] ?? '').toString();
        if (text.isNotEmpty && !targets.contains(text)) {
          targets.add(text);
        }
      }
    }

    if (!targets.contains(_selectedTarget.value)) {
      targets.insert(0, _selectedTarget.value);
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
            value: _selectedTarget.value,
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
                _selectedTarget.value = val;
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildUpgradeCard() {
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
