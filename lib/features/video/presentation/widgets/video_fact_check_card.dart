import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/widgets/truth_lottie_animation.dart';
import 'package:truthworld/features/video/data/models/fact_check_data_parser.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/widgets/video_analysis_bottom_sheet.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Inline Trust Score Card that surfaces fact-check data directly in the video
/// scroll flow for maximum discoverability and engagement.
///
/// V2 Enhancements:
/// - Animated trust bar that fills on appearance
/// - Staggered claim pill entrance animations
/// - Dynamic contextual CTA text based on claim data
/// - Visual urgency (gradient tint + glow) for disputed/low-trust content
/// - Card entrance fade+scale animation
///
/// Renders [SizedBox.shrink] when no fact-check data is available.
class VideoFactCheckCard extends StatelessWidget {
  const VideoFactCheckCard({required this.controller, super.key});

  final VideoController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final currentUid = AuthService.to.uid;
      final userChannelId = AuthService.to.userChannel?.id;
      final isOwner = currentUid.isNotEmpty &&
          (controller.video.ownerId == currentUid ||
              controller.video.userId == currentUid ||
              (userChannelId != null &&
                  userChannelId.isNotEmpty &&
                  controller.video.channelId == userChannelId));
      if (!controller.video.hasAiCredibility ||
          (!controller.video.canPublicViewFactCheck && !isOwner)) {
        return const SizedBox.shrink();
      }

      final data = controller.factCheckData;

      // Show shimmer while loading
      if (controller.isLoadingFactCheck.value) {
        return _buildLoadingSkeleton();
      }

      // If URL exists and load hasn't been attempted yet, trigger once
      if (data.isEmpty &&
          controller.video.factCheckUrl.isNotEmpty &&
          !controller.hasAttemptedFactCheck.value) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (controller.factCheckData.isEmpty &&
              !controller.isLoadingFactCheck.value &&
              !controller.hasAttemptedFactCheck.value) {
            controller.loadFactCheckData(controller.video.factCheckUrl);
          }
        });
        return _buildLoadingSkeleton();
      }

      final parsed = FactCheckDataParser.parse(
        data,
        fallbackReport: controller.video.uiReport,
        fallbackTrustScore: controller.video.trustScore > 0 ? controller.video.trustScore : null,
        isVideoFactChecked: controller.video.isFactChecked,
      );

      // Hide entirely when no fact-check data and no fallback data available
      if (parsed.isEmpty) {
        return const SizedBox.shrink();
      }

      // Wrap entire card in entrance animation
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 12 * (1 - value)),
              child: child,
            ),
          );
        },
        child: _buildCard(context, data, cachedParsed: parsed),
      );
    });
  }

  Widget _buildCard(
    BuildContext context,
    Map<String, dynamic> data, {
    ParsedFactCheckData? cachedParsed,
  }) {
    final parsed = cachedParsed ??
        FactCheckDataParser.parse(
          data,
          fallbackReport: controller.video.uiReport,
          fallbackTrustScore: controller.video.trustScore > 0
              ? controller.video.trustScore
              : null,
          isVideoFactChecked: controller.video.isFactChecked,
        );

    return GestureDetector(
      onTap: () => _openFullAnalysis(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: parsed.needsUrgency
                ? Colors.white.withValues(alpha: 0.25)
                : AppColors.bgDivider.withValues(alpha: 0.6),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: Badge + Trust Score ──
            _buildHeader(
              context,
              parsed.trustLabel,
              parsed.trustScore,
              parsed.normalizedScore,
              parsed.scoreColor,
              parsed.confidenceTier,
              isDisputed: parsed.isDisputed,
              isCaution: parsed.isCaution,
              totalClaims: parsed.claims.length,
              isShortOverview: parsed.isShortOverview,
              isFullGround: parsed.isFullGround,
            ),

            // ── Animated Trust Progress Bar ──
            if (parsed.normalizedScore != null || parsed.claims.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildAnimatedTrustBar(
                parsed.normalizedScore ?? 100.0,
                parsed.scoreColor,
                totalClaims: parsed.claims.length,
                verifiedCount: parsed.verifiedCount,
                cautionCount: parsed.cautionCount,
                falseCount: parsed.falseCount,
              ),
            ],

            // ── Viewer Advisory ──
            if (parsed.viewerNote.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                parsed.viewerNote,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.roboto(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],

            // ── Animated Claim Breakdown Pills ──
            if (parsed.claims.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildAnimatedClaimPills(
                parsed.verifiedCount,
                parsed.cautionCount,
                parsed.falseCount,
              ),
            ],

            // ── Source Chips ──
            if (parsed.sources.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildSourceChips(parsed.sources),
            ],

            // ── Dynamic CTA ──
            const SizedBox(height: 14),
            _buildDynamicCTA(
              verifiedCount: parsed.verifiedCount,
              cautionCount: parsed.cautionCount,
              falseCount: parsed.falseCount,
              totalClaims: parsed.claims.length,
              sourceCount: parsed.sources.length,
              isDisputed: parsed.isDisputed,
              isShortOverview: parsed.isShortOverview,
              isFullGround: parsed.isFullGround,
            ),
          ],
        ),
      ),
    );
  }

  // ── Header Row ──
  Widget _buildHeader(
    BuildContext context,
    String trustLabel,
    double? trustScore,
    double? normalizedScore,
    Color scoreColor,
    String confidenceTier, {
    bool isDisputed = false,
    bool isCaution = false,
    int totalClaims = 0,
    bool isShortOverview = false,
    bool isFullGround = false,
  }) {
    // Contextual header label
    final headerLabel = isDisputed
        ? 'DISPUTED CONTENT'
        : (isCaution
            ? 'REVIEW ADVISED'
            : (isShortOverview
                ? 'SHORT FACT-CHECK • OVERVIEW'
                : (isFullGround
                    ? 'FULL GROUND FACT-CHECK • VERIFIED'
                    : 'AI CREDIBILITY CHECK')));
    const headerColor = Colors.white70;

    final isNotScored = trustScore == null || trustScore <= 0 || trustLabel.toLowerCase().contains('not scored');
    final headlineTitle = isNotScored
        ? (isShortOverview
            ? 'Epistemic Overview'
            : (totalClaims > 0 ? '$totalClaims Claims Evaluated' : 'Credibility Analysis'))
        : (isFullGround ? '$trustLabel (Ground Truth)' : trustLabel);

    return Row(
      children: [
        // Shield icon with clean styling & entrance scale animation
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.85, end: 1.0),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutBack,
          builder: (context, scale, child) => Transform.scale(
            scale: scale,
            child: child,
          ),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
            ),
            child: isDisputed
                ? const Icon(
                    Icons.gpp_bad_outlined,
                    size: 20,
                    color: Colors.white,
                  )
                : TruthLottieAnimation.verifiedShield(
                    size: 22,
                  ),
          ),
        ),
        const SizedBox(width: 10),
        // Label and status
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                headerLabel,
                style: GoogleFonts.roboto(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: headerColor,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      headlineTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.roboto(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (confidenceTier.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text(
                      '• ${confidenceTier.capitalizeFirst} Confidence',
                      style: GoogleFonts.roboto(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        // Trust score badge
        if (trustScore != null && trustScore > 0)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.85, end: 1.0),
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) => Transform.scale(
              scale: scale,
              child: child,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                ),
              ),
              child: Text(
                trustScore <= 5.0
                    ? '${trustScore.toStringAsFixed(1)}/5'
                    : '${trustScore.toInt()}%',
                style: GoogleFonts.roboto(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── Animated Trust Progress Bar ──
  Widget _buildAnimatedTrustBar(
    double score,
    Color color, {
    int totalClaims = 0,
    int verifiedCount = 0,
    int cautionCount = 0,
    int falseCount = 0,
  }) {
    if (totalClaims > 0) {
      final verifiedFactor = verifiedCount / totalClaims;
      final cautionFactor = cautionCount / totalClaims;
      final falseFactor = falseCount / totalClaims;
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, animFactor, _) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Container(
              height: 5,
              width: double.infinity,
              color: Colors.white.withValues(alpha: 0.08),
              child: Row(
                children: [
                  if (verifiedFactor > 0)
                    Expanded(
                      flex: (verifiedFactor * 1000 * animFactor).toInt().clamp(1, 1000),
                      child: Container(color: Colors.white),
                    ),
                  if (cautionFactor > 0)
                    Expanded(
                      flex: (cautionFactor * 1000 * animFactor).toInt().clamp(1, 1000),
                      child: Container(color: Colors.white.withValues(alpha: 0.55)),
                    ),
                  if (falseFactor > 0)
                    Expanded(
                      flex: (falseFactor * 1000 * animFactor).toInt().clamp(1, 1000),
                      child: Container(color: Colors.white.withValues(alpha: 0.20)),
                    ),
                  if (animFactor < 1.0)
                    Expanded(
                      flex: ((1.0 - animFactor) * 1000).toInt().clamp(1, 1000),
                      child: const SizedBox.shrink(),
                    ),
                ],
              ),
            ),
          );
        },
      );
    }
    final targetValue = (score / 100.0).clamp(0.0, 1.0);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: targetValue),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            height: 5,
            child: LinearProgressIndicator(
              value: value,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        );
      },
    );
  }

  // ── Animated Claim Breakdown Pills ──
  Widget _buildAnimatedClaimPills(int verified, int caution, int falseCount) {
    final pills = <_ClaimPillData>[];
    if (verified > 0) {
      pills.add(_ClaimPillData(
        icon: Icons.check_circle_rounded,
        label: '$verified Verified',
        color: Colors.white,
      ));
    }
    if (caution > 0) {
      pills.add(_ClaimPillData(
        icon: Icons.warning_amber_rounded,
        label: '$caution Unconfirmed',
        color: Colors.white70,
      ));
    }
    if (falseCount > 0) {
      pills.add(_ClaimPillData(
        icon: Icons.cancel_outlined,
        label: '$falseCount False',
        color: Colors.white54,
      ));
    }

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: List.generate(pills.length, (i) {
        final pill = pills[i];
        // Stagger each pill by 150ms
        final delay = Duration(milliseconds: 300 + (i * 150));
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutBack,
          // Use a unique key incorporating the delay to force rebuild
          key: ValueKey('pill_${pill.label}_${delay.inMilliseconds}'),
          builder: (context, value, child) {
            // Compute delayed progress: stays at 0 until delay, then animates
            final delayFraction =
                delay.inMilliseconds / (delay.inMilliseconds + 400);
            final adjustedProgress =
                ((value - delayFraction) / (1 - delayFraction)).clamp(0.0, 1.0);
            return Opacity(
              opacity: adjustedProgress,
              child: Transform.translate(
                offset: Offset(0, 8 * (1 - adjustedProgress)),
                child: child,
              ),
            );
          },
          child: _claimPill(
            icon: pill.icon,
            label: pill.label,
            color: pill.color,
          ),
        );
      }),
    );
  }

  Widget _claimPill({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.roboto(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ── Source Chips ──
  Widget _buildSourceChips(List<dynamic> sources) {
    final sourceNames = <String>[];
    for (final s in sources) {
      if (s is! Map) continue;
      final name = (s['domain'] ?? s['title'] ?? s['author'] ?? '')
          .toString()
          .replaceAll('www.', '')
          .trim();
      if (name.isNotEmpty && !sourceNames.contains(name)) {
        sourceNames.add(name);
      }
    }

    if (sourceNames.isEmpty) return const SizedBox.shrink();

    const maxVisible = 3;
    final visible = sourceNames.take(maxVisible).toList();
    final overflow = math.max(0, sourceNames.length - maxVisible);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          const Icon(
            Icons.article_outlined,
            size: 14,
            color: AppColors.textTertiary,
          ),
          const SizedBox(width: 6),
          ...visible.map((name) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Text(
                    name.length > 20 ? '${name.substring(0, 18)}…' : name,
                    style: GoogleFonts.roboto(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              )),
          if (overflow > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '+$overflow more',
                style: GoogleFonts.roboto(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Dynamic Contextual CTA ──
  Widget _buildDynamicCTA({
    required int verifiedCount,
    required int cautionCount,
    required int falseCount,
    required int totalClaims,
    required int sourceCount,
    required bool isDisputed,
    bool isShortOverview = false,
    bool isFullGround = false,
  }) {
    // Build contextual, curiosity-driving CTA text
    String ctaText;
    IconData ctaIcon;
    if (isDisputed && falseCount > 0) {
      ctaText = isFullGround
          ? '$falseCount ground-truth disputed claim${falseCount > 1 ? 's' : ''} — see report'
          : '$falseCount claim${falseCount > 1 ? 's' : ''} disputed — see why';
      ctaIcon = Icons.gpp_bad_outlined;
    } else if (falseCount > 0) {
      ctaText = isFullGround
          ? '$falseCount empirical claim${falseCount > 1 ? 's' : ''} debunked — see evidence'
          : '$falseCount false claim${falseCount > 1 ? 's' : ''} found — see details';
      ctaIcon = Icons.warning_amber_rounded;
    } else if (cautionCount > 0 && verifiedCount > 0) {
      ctaText = '$verifiedCount verified, $cautionCount need review';
      ctaIcon = Icons.fact_check_outlined;
    } else if (verifiedCount > 0) {
      ctaText = isFullGround
          ? 'See $verifiedCount ground-truth verified claim${verifiedCount > 1 ? 's' : ''} & $sourceCount source${sourceCount > 1 ? 's' : ''}'
          : 'See $verifiedCount verified claim${verifiedCount > 1 ? 's' : ''} & $sourceCount source${sourceCount > 1 ? 's' : ''}';
      ctaIcon = Icons.verified_outlined;
    } else if (totalClaims > 0) {
      ctaText = isShortOverview
          ? 'View Epistemic Overview & $totalClaims Claims'
          : 'See $totalClaims analyzed claim${totalClaims > 1 ? 's' : ''}';
      ctaIcon = Icons.fact_check_outlined;
    } else {
      ctaText = isShortOverview
          ? 'View Complete Epistemic Overview'
          : (isFullGround ? 'View Ground-Truth Report' : 'View Full Analysis');
      ctaIcon = Icons.verified_user_outlined;
    }

    const ctaAccent = Colors.white;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(ctaIcon, size: 16, color: ctaAccent),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              ctaText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.roboto(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 6),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 2.5),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
            builder: (context, dx, child) => Transform.translate(
              offset: Offset(dx, 0),
              child: child,
            ),
            child: const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 12,
              color: Colors.white54,
            ),
          ),
        ],
      ),
    );
  }

  // ── Loading Skeleton ──
  Widget _buildLoadingSkeleton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          TruthLottieAnimation.aiScanning(size: 22),
          const SizedBox(width: 10),
          Text(
            'Loading credibility analysis…',
            style: GoogleFonts.roboto(
              fontSize: 13,
              color: AppColors.textTertiary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  void _openFullAnalysis(BuildContext context) {
    Get.bottomSheet(
      VideoAnalysisBottomSheet(
        video: controller.video,
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }
}

/// Internal data holder for claim pill animation builder.
class _ClaimPillData {
  const _ClaimPillData({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;
}
