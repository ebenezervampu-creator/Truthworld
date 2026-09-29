import 'package:flutter/material.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/fact_check/fact_check_claim_card.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/fact_check/fact_check_overlay_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

  class FactCheckClaimsSection extends StatelessWidget {
  const FactCheckClaimsSection({
    required this.claims,
    required this.allSources,
    required this.posSec,
    required this.video,
    required this.ctrl,
    required this.overlayCtrl,
    super.key,
  });

  final List<Map<String, dynamic>> claims;
  final List<Map<String, dynamic>> allSources;
  final double posSec;
  final Video? video;
  final TowerPlayerController ctrl;
  final FactCheckOverlayController overlayCtrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.fact_check_outlined,
                  size: 14,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  'FACT-CHECKED CLAIMS (${claims.length})',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textTertiary,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: ctrl.isFactCheckAutoPlay.value
                        ? Colors.white
                        : AppColors.textSecondary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  ctrl.isFactCheckAutoPlay.value ? 'Live Sync' : 'Tap to Play',
                  style: TextStyle(
                    fontSize: 10,
                    color: ctrl.isFactCheckAutoPlay.value
                        ? Colors.white
                        : AppColors.textSecondary.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Quick Claim Navigation Bar
        FactCheckClaimNavigationBar(
          claims: claims,
          posSec: posSec,
          ctrl: ctrl,
        ),
        const SizedBox(height: 10),

        // Claims list
        ...List.generate(claims.length, (index) {
          final claim = claims[index];
          overlayCtrl.claimKeys.putIfAbsent(index, GlobalKey.new);

          return FactCheckClaimCard(
            claim: claim,
            index: index,
            allClaims: claims,
            allSources: allSources,
            posSec: posSec,
            video: video,
            ctrl: ctrl,
            overlayCtrl: overlayCtrl,
          );
        }),
      ],
    );
  }
}

class FactCheckClaimNavigationBar extends StatelessWidget {
  const FactCheckClaimNavigationBar({
    required this.claims,
    required this.posSec,
    required this.ctrl,
    super.key,
  });

  final List<Map<String, dynamic>> claims;
  final double posSec;
  final TowerPlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.textPrimary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous claim button
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: ctrl.playPreviousClaim,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.skip_previous_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Prev',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Live Play / Sync status toggle
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: ctrl.toggleFactCheckAutoPlay,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  Icon(
                    ctrl.isFactCheckAutoPlay.value
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    ctrl.isFactCheckAutoPlay.value
                        ? 'Syncing Live'
                        : 'Play Claims',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Next claim button
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: ctrl.playNextClaim,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                children: [
                  Text(
                    'Next',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    Icons.skip_next_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


}
