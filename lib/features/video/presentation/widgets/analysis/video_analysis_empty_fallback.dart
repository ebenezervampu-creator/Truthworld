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
import 'package:truthworld/theme/app_theme.dart';

class VideoAnalysisEmptyFallback extends StatelessWidget {
  final Video? video;
  const VideoAnalysisEmptyFallback({this.video, super.key});

  @override
  Widget build(BuildContext context) {
    final isNonCred = video?.isNonCredibilityCategory ?? false;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.bgDivider),
              ),
              child: TruthLottieAnimation.emptyClaims(size: 72),
            ),
            const SizedBox(height: 24),
            Text(
              isNonCred ? 'Fact-Checking Not Applicable' : 'Not Fact-Checked Yet',
              style: context.twTypography.headline.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isNonCred
                  ? 'Theological claims, scriptural interpretations, and spiritual or creative content are categorized as personal convictions and are not subjected to empirical fact-checking.'
                  : 'Artificial intelligence and epistemic fact-checking engines are deployed for verified videos. Subscribers to TruthWorld Premium + Fact-Checked can trigger instant analysis.',
              textAlign: TextAlign.center,
              style: context.twTypography.body.copyWith(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            if (!isNonCred) ...[
              const SizedBox(height: 32),
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
                        r'You currently have the $0.50 Audio Premium plan. Upgrade to the $3 Fact-Checked Plan to unlock verified and on-demand fact-checking on every video with full credit applied.';
                    buttonLabel = r'Upgrade to $3 Fact-Checked Plan';
                  } else if (hasFullPrem) {
                    upgradeDescription =
                        r'You currently have TruthWorld Premium ($2). Upgrade to the $3 Fact-Checked Plan to unlock verified and on-demand fact-checking on every video with full credit applied.';
                    buttonLabel = r'Upgrade to $3 Fact-Checked Plan';
                  } else {
                    upgradeDescription =
                        r'On-demand AI video fact-checking is exclusive to the $3 TruthWorld Premium + Fact-Checked Plan. Upgrade to fact-check any video instantly with AI claim verification and truth scores.';
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

                // Authenticated user on $3 Fact-Checked tier can fact check
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
                      'requestedBy': auth.user?.uid ?? 'anonymous',
                      'requestedAt': FieldValue.serverTimestamp(),
                      'status': 'queued',
                      'priority': 'high',
                    });
                  }
                  AppSnackbar.success(
                    'Truth Intelligence Check initiated! Epistemic analysis and claim verification is in progress for this video.',
                    title: 'Fact-Check Initiated',
                  );
                } catch (e, s) {
                  ErrorHandler.log(e, stackTrace: s, tag: 'VideoAnalysisEmptyFallback.requestFactCheck');
                  AppSnackbar.error('Unable to queue fact-check request. Please try again.');
                }
              },
              icon: const Icon(
                Icons.bolt_rounded,
                size: 18,
                color: Colors.black,
              ),
              label: Text(
                'Fact-Check This Video',
                style: context.twTypography.button.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ],
        ],
        ),
      ),
    );
  }

}
