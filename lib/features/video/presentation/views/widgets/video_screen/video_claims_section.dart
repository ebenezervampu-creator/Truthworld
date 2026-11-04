import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/video/data/models/claim_verdict_helper.dart';
import 'package:truthworld/features/video/data/models/credibility_report.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/widgets/fact_check/fact_check_epistemic_banner.dart';
import 'package:truthworld/features/video/presentation/widgets/video_claims_bottom_sheet.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Expandable AI Credibility Claims section displayed directly on [VideoScreen]
/// structured as video chapters based on chronological timestamps.
class VideoClaimsChaptersSection extends StatelessWidget {
  const VideoClaimsChaptersSection({
    required this.controller,
    this.videoTag,
    super.key,
  });

  final VideoController controller;
  final String? videoTag;

  TowerPlayerController? _getPlayerController() {
    try {
      if (videoTag != null &&
          Get.isRegistered<TowerPlayerController>(tag: videoTag)) {
        return Get.find<TowerPlayerController>(tag: videoTag);
      }
      if (Get.isRegistered<TowerPlayerController>(tag: controller.video.id)) {
        return Get.find<TowerPlayerController>(tag: controller.video.id);
      }
      if (Get.isRegistered<TowerPlayerController>()) {
        return Get.find<TowerPlayerController>();
      }
    } catch (_) {}
    return null;
  }

  List<ClaimResult> _resolveClaims(TowerPlayerController? playerCtrl) {
    if (playerCtrl != null && playerCtrl.timestampedClaims.isNotEmpty) {
      return playerCtrl.timestampedClaims;
    }

    final keyClaims = controller.video.uiReport?.keyClaims;
    if (keyClaims != null && keyClaims.isNotEmpty) {
      final list = List<ClaimResult>.from(keyClaims);
      list.sort((a, b) => (a.start ?? 0.0).compareTo(b.start ?? 0.0));
      return list;
    }

    final rawClaims = controller.factCheckData['claims'] ??
        controller.factCheckData['uiReport']?['keyClaims'];
    if (rawClaims is List && rawClaims.isNotEmpty) {
      final list = rawClaims
          .map((c) => ClaimResult.fromMap(
                Map<String, dynamic>.from(
                  c is Map ? c : {'text': c.toString()},
                ),
              ))
          .toList();
      list.sort((a, b) => (a.start ?? 0.0).compareTo(b.start ?? 0.0));
      return list;
    }

    return const <ClaimResult>[];
  }

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

      final playerCtrl = _getPlayerController();
      final claims = _resolveClaims(playerCtrl);
      if (claims.isEmpty) return const SizedBox.shrink();

      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.bgDivider.withValues(alpha: 0.5),
          ),
        ),
        child: ExpansionTile(
          iconColor: Colors.white,
          collapsedIconColor: Colors.white,
          title: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => VideoClaimsChaptersBottomSheet.show(
                context,
                video: controller.video,
                videoTag: videoTag,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.fact_check_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'AI Credibility Claims',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF162A45),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          claims.length.toString(),
                          style: const TextStyle(
                            color: AppColors.textLink,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      _buildSummaryDots(claims),
                    ],
                  ),
                  if (playerCtrl != null)
                    Obx(() {
                      final current = playerCtrl.activeClaim.value;
                      if (current == null) {
                        return const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            'Watch along to see timestamped fact-checks',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        );
                      }
                      final verdict = ClaimVerdictHelper.resolveVerdict(current);
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: verdict.color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: verdict.color.withValues(alpha: 0.4),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                verdict.label,
                                style: TextStyle(
                                  color: verdict.color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Current: ${current.text}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
          shape: const RoundedRectangleBorder(),
          collapsedShape: const RoundedRectangleBorder(),
          childrenPadding: EdgeInsets.zero,
          children: [
            // Inline Preview of Claims
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: claims.length > 4 ? 4 : claims.length,
              padding: const EdgeInsets.only(bottom: 4),
              itemBuilder: (context, index) {
                final claim = claims[index];
                return ClaimChapterTile(
                  claim: claim,
                  video: controller.video,
                  playerCtrl: playerCtrl,
                  index: index,
                );
              },
            ),

            // If more than 4 claims exist, show "View All Claims" footer button
            if (claims.length > 4)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () => VideoClaimsChaptersBottomSheet.show(
                      context,
                      video: controller.video,
                      videoTag: videoTag,
                    ),
                    icon: const Icon(
                      Icons.format_list_bulleted_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: Text(
                      'View All ${claims.length} Claims',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),

            // Epistemic disclaimer for users when using Factchecking feature
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: FactCheckEpistemicBanner(),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildSummaryDots(List<ClaimResult> claims) {
    var hasVerified = false;
    var hasCaution = false;
    var hasFalse = false;

    for (final c in claims) {
      final v = ClaimVerdictHelper.resolveVerdict(c);
      if (v.isVerified) hasVerified = true;
      if (v.isCaution) hasCaution = true;
      if (v.isFalse) hasFalse = true;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasVerified)
          Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.only(right: 4),
            decoration: const BoxDecoration(
              color: Color(0xFF4CAF50),
              shape: BoxShape.circle,
            ),
          ),
        if (hasCaution)
          Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.only(right: 4),
            decoration: const BoxDecoration(
              color: Color(0xFFFFB300),
              shape: BoxShape.circle,
            ),
          ),
        if (hasFalse)
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: Color(0xFFFF5252),
              shape: BoxShape.circle,
            ),
          ),
      ],
    );
  }
}
