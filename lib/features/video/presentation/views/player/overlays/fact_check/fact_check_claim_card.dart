import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/utils/source_url_sanitizer.dart';
import 'package:truthworld/features/video/data/models/claim_verdict_helper.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/fact_check/fact_check_models_helper.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/fact_check/fact_check_overlay_controller.dart';
import 'package:truthworld/features/video/presentation/widgets/claim_source_submission_dialog.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

  class FactCheckClaimCard extends StatelessWidget {
  const FactCheckClaimCard({
    required this.claim,
    required this.index,
    required this.allClaims,
    required this.allSources,
    required this.posSec,
    required this.video,
    required this.ctrl,
    required this.overlayCtrl,
    super.key,
  });

  final Map<String, dynamic> claim;
  final int index;
  final List<Map<String, dynamic>> allClaims;
  final List<Map<String, dynamic>> allSources;
  final double posSec;
  final Video? video;
  final TowerPlayerController ctrl;
  final FactCheckOverlayController overlayCtrl;

  @override
  Widget build(BuildContext context) {
    final startSec = getClaimStartSeconds(claim);
    final endSec = getClaimEndSeconds(claim, startSec);

    final isCurrentlyActive = startSec != null &&
        posSec >= startSec &&
        posSec <= (endSec ?? (startSec + 8.0));

    final verdict = ClaimVerdictHelper.resolveVerdict(claim);
    final verdictColor = verdict.color;
    final verdictLabel = verdict.label;

    final resolved = resolveRealClaimDetails(claim, index, allSources);
    final cleanClaimText = resolved.cleanText;
    final responseText = resolved.response;
    final effectiveSources = resolved.sources;

    return Obx(() {
      final isExpanded = overlayCtrl.expandedClaimIndices.contains(index);

      return Container(
        key: overlayCtrl.claimKeys[index],
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isCurrentlyActive
              ? verdictColor.withValues(alpha: 0.14)
              : (isExpanded
                  ? verdictColor.withValues(alpha: 0.08)
                  : AppColors.textPrimary.withValues(alpha: 0.04)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCurrentlyActive
                ? verdictColor.withValues(alpha: 0.8)
                : (isExpanded
                    ? verdictColor.withValues(alpha: 0.35)
                    : AppColors.textPrimary.withValues(alpha: 0.08)),
            width: isCurrentlyActive ? 1.5 : 1.0,
          ),
          boxShadow: isCurrentlyActive
              ? [
                  BoxShadow(
                    color: verdictColor.withValues(alpha: 0.2),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            if (overlayCtrl.expandedClaimIndices.contains(index)) {
              overlayCtrl.expandedClaimIndices.remove(index);
            } else {
              overlayCtrl.expandedClaimIndices.add(index);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Index badge
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: verdictColor.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: verdictColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Verdict Pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: verdictColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: verdictColor.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        verdictLabel.toUpperCase(),
                        style: TextStyle(
                          color: verdictColor,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),

                    // Play / Timestamp Button
                    if (startSec != null)
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => playClaimAt(ctrl, claim, startSec, endSec),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isCurrentlyActive
                                ? AppColors.textPrimary.withValues(alpha: 0.22)
                                : AppColors.textPrimary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isCurrentlyActive
                                    ? Icons.volume_up_rounded
                                    : Icons.play_arrow_rounded,
                                size: 12,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                endSec != null
                                    ? '${formatSeconds(startSec)} - ${formatSeconds(endSec)}'
                                    : formatSeconds(startSec),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isCurrentlyActive
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(width: 6),

                    // Expand Icon
                    Icon(
                      isExpanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Clean Claim Text
                Text(
                  cleanClaimText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isCurrentlyActive
                        ? FontWeight.bold
                        : FontWeight.w600,
                    color: AppColors.textPrimary,
                    height: 1.35,
                  ),
                ),

                // Expanded Section: AI Response & Evidence
                if (isExpanded) ...[
                  const SizedBox(height: 10),
                  const Divider(color: Colors.white12, height: 1),
                  const SizedBox(height: 10),

                  // AI Verification Response Box
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              size: 13,
                              color: Colors.white,
                            ),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'AI VERIFICATION & EVIDENCE ANALYSIS',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.brand,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          responseText,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 11.5,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Supporting Citations
                  if (effectiveSources.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.link_rounded,
                          size: 13,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'SUPPORTING CITATIONS (${effectiveSources.length})',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ...effectiveSources.map((s) => TapableClaimSource(source: s)),
                  ],

                  // Action Buttons: Search Web + Provide Source
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final query = Uri.encodeComponent(cleanClaimText);
                            final searchUrl =
                                'https://www.google.com/search?q=$query';
                            try {
                              await launchUrl(
                                Uri.parse(searchUrl),
                                mode: LaunchMode.externalApplication,
                              );
                            } catch (e, stackTrace) {
                              ErrorHandler.log(
                                e,
                                stackTrace: stackTrace,
                                tag: 'FactCheckClaimCard.searchWeb',
                              );
                            }
                          },
                          icon: const Icon(
                            Icons.search_rounded,
                            size: 13,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Search Web',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            side: const BorderSide(color: Colors.white24),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            final v = video;
                            if (v != null) {
                              ClaimSourceSubmissionDialog.show(
                                context: context,
                                video: v,
                                claims: allClaims,
                                initialClaim: claim,
                              );
                            }
                          },
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
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    });
  }


}

  class TapableClaimSource extends StatelessWidget {
  const TapableClaimSource({required this.source, super.key});
  final Map<dynamic, dynamic> source;

  @override
  Widget build(BuildContext context) {
    final cleanSource = SourceUrlSanitizer.sanitizeSourceMap(source);
    final title = (cleanSource['title'] ??
            cleanSource['author'] ??
            cleanSource['domain'] ??
            'Source Citation')
        .toString();
    final url = cleanSource['url']?.toString();
    final domain = (cleanSource['domain'] ?? '').toString();
    final snippet = cleanSource['snippet']?.toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: InkWell(
        onTap: () async {
          await SourceUrlSanitizer.launchSourceUrl(
            url: url,
            title: title,
            domain: domain,
            source: cleanSource,
          );
        },
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.language_rounded,
                size: 14,
                color: Colors.white,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (domain.isNotEmpty)
                      Text(
                        domain,
                        style: const TextStyle(
                          fontSize: 9,
                          color: AppColors.textLink,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    if (snippet != null && snippet.isNotEmpty)
                      Text(
                        '"$snippet"',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 9,
                          fontStyle: FontStyle.italic,
                          color: AppColors.textTertiary,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.open_in_new_rounded,
                size: 12,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }


}
