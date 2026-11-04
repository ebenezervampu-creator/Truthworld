import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/core/widgets/truth_lottie_animation.dart';
import 'package:truthworld/features/premium/presentation/controllers/premium_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/widgets/claim_source_submission_dialog.dart';
import 'package:truthworld/features/video/presentation/widgets/fact_check_dispute_dialog.dart';
import 'package:truthworld/theme/app_theme.dart';

  class FactCheckCommunityActions extends StatelessWidget {
  const FactCheckCommunityActions({
    required this.video,
    required this.claims,
    super.key,
  });

  final Video? video;
  final List<Map<String, dynamic>> claims;

  @override
  Widget build(BuildContext context) {
    final v = video;
    if (v == null) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              const Icon(
                Icons.groups_outlined,
                size: 13,
                color: AppColors.textTertiary,
              ),
              const SizedBox(width: 5),
              const Text(
                'Community Review & Citations',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.2,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'IFCN Aligned',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => FactCheckDisputeDialog.show(context, v),
                icon: const Icon(
                  Icons.gavel_rounded,
                  size: 13,
                  color: Colors.white,
                ),
                label: const Text(
                  'Dispute',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => ClaimSourceSubmissionDialog.show(
                  context: context,
                  video: v,
                  claims: claims,
                ),
                icon: const Icon(
                  Icons.add_link_rounded,
                  size: 13,
                  color: Colors.black,
                ),
                label: const Text(
                  'Provide Source',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  }

class NoFactCheckFallback extends StatelessWidget {
  const NoFactCheckFallback({
    required this.video,
    required this.vc,
    super.key,
  });

  final Video? video;
  final VideoController? vc;

  @override
  Widget build(BuildContext context) {
    final isNonCred = video?.isNonCredibilityCategory ?? false;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.textPrimary.withValues(alpha: 0.05),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.textPrimary.withValues(alpha: 0.1),
                ),
              ),
              child: TruthLottieAnimation.emptyClaims(size: 52),
            ),
            const SizedBox(height: 14),
            Text(
              isNonCred ? 'Fact-Checking Not Applicable' : 'Not Fact-Checked Yet',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isNonCred
                  ? 'Theological claims, scriptural interpretations, and spiritual content are categorized as personal convictions and are not subjected to empirical fact-checking.'
                  : 'This video has not yet completed epistemic analysis and verified corroboration.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            if (!isNonCred) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
              onPressed: () async {
                final auth = Get.isRegistered<AuthService>() ? AuthService.to : null;
                if (auth == null || !auth.isAuthenticated.value) {
                  AppSnackbar.warning(
                    'Please sign in to fact-check this video.',
                    title: 'Sign In Required',
                  );
                  return;
                }

                if (!auth.hasFactCheckPremium) {
                  final isAudioOnly = auth.isAudioPremiumOnly;
                  final hasFullPrem = auth.hasFullPremium;

                  final String upgradeDescription;
                  final String buttonLabel;

                  if (isAudioOnly) {
                    upgradeDescription =
                        r'Viewing existing fact-checks is always free. Upgrade your $0.50 plan to the $3 Fact-Checked Plan to trigger on-demand AI claim verification on any unanalyzed video with your previous payment credited directly.';
                    buttonLabel = r'Upgrade to $3 Fact-Checked Plan';
                  } else if (hasFullPrem) {
                    upgradeDescription =
                        r'Viewing existing fact-checks is always free. Upgrade your TruthWorld Premium ($2) to the $3 Fact-Checked Plan to trigger on-demand AI claim verification on any unanalyzed video with your previous payment credited directly.';
                    buttonLabel = r'Upgrade to $3 Fact-Checked Plan';
                  } else {
                    upgradeDescription =
                        r'Viewing published fact-checks is 100% free for everyone. The $3 Fact-Checked Plan unlocks on-demand AI verification, allowing you to queue epistemic fact-checking and truth analysis on any unanalyzed video.';
                    buttonLabel = r'View $3 Fact-Checked Plan';
                  }

                  Get.bottomSheet(
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: const BoxDecoration(
                        color: AppColors.bgPage,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.brand.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.verified_outlined, color: Colors.white, size: 24),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  r'Fact-Checked Plan ($3)',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            upgradeDescription,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: () {
                                Get.back();
                                if (Get.isRegistered<PremiumController>()) {
                                  Get.find<PremiumController>().selectPlan('4k_factchecked_monthly');
                                }
                                Get.toNamed('/premium');
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.brand,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                              child: Text(
                                buttonLabel,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    isScrollControlled: true,
                  );
                  return;
                }

                // User has $3 Fact-Checked Plan: trigger real on-demand verification
                if (auth.user == null) {
                  AppSnackbar.warning('Please sign in to request AI fact-checking.');
                  return;
                }

                try {
                  final v = video;
                  if (v != null) {
                    await FirebaseFirestore.instance
                        .collection(FirestoreCollections.factCheckRequests)
                        .add({
                      'videoId': v.id,
                      'videoTitle': v.title,
                      'channelId': v.channelId,
                      'channelName': v.channelName,
                      'requestedBy': auth.user!.uid,
                      'requestedAt': FieldValue.serverTimestamp(),
                      'status': 'queued',
                      'priority': 'high',
                    });
                  }
                  AppSnackbar.success(
                    'AI Fact-Checking initiated! Epistemic analysis and claim verification is in progress for this video.',
                    title: 'Fact-Check Initiated',
                  );
                } catch (e, s) {
                  ErrorHandler.log(e, stackTrace: s, tag: 'NoFactCheckFallback.requestFactCheck');
                  AppSnackbar.error('Unable to queue fact-check request. Please try again.');
                }
              },
              icon: const Icon(
                Icons.bolt_rounded,
                size: 16,
                color: Colors.black,
              ),
              label: const Text(
                'Fact-Check This Video',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ],
            if (video?.factCheckUrl.isNotEmpty == true) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () {
                  final v = video;
                  if (v != null && v.factCheckUrl.isNotEmpty) {
                    vc?.loadFactCheckData(v.factCheckUrl, true);
                  }
                },
                icon: const Icon(
                  Icons.refresh_rounded,
                  size: 14,
                  color: Colors.white,
                ),
                label: const Text(
                  'Retry Loading',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
