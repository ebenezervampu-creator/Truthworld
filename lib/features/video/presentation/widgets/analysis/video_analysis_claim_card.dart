import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/features/video/data/models/claim_verdict_helper.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/views/claim_detail_screen.dart';
import 'package:truthworld/features/video/presentation/widgets/analysis/video_analysis_controller.dart';
import 'package:truthworld/features/video/presentation/widgets/analysis/video_analysis_helpers.dart';
import 'package:truthworld/features/video/presentation/widgets/claim_share_card.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

/// 🏛 VideoAnalysisClaimCard
///
/// Clean, high-fidelity claim list item matching the updated UI design:
/// - Left: Circular badge with 1-based claim index (`1`, `2`, `3`...)
/// - Top meta row: Verdict pill (`[ ✓ Verified ]`, `[ ⚠️ Partially Verified ]`, `[ ✕ False ]`) + Timestamp (`00:52`)
/// - Prominent claim statement text
/// - Source attribution line with direct external launch action
/// - Trailing chevron navigation arrow to dedicated [ClaimDetailScreen]
class VideoAnalysisClaimCard extends StatelessWidget {
  final Map<dynamic, dynamic> claim;
  final int index;
  final List<dynamic> allClaims;
  final List<dynamic> allSources;
  final VideoController videoCtrl;
  final VideoAnalysisController analysisCtrl;
  final Video video;

  const VideoAnalysisClaimCard({
    required this.claim,
    required this.index,
    required this.allClaims,
    required this.allSources,
    required this.videoCtrl,
    required this.analysisCtrl,
    required this.video,
    super.key,
  });

  Future<void> _launchUrl(String? urlStr) async {
    if (urlStr == null || urlStr.trim().isEmpty) return;
    try {
      final uri = Uri.parse(urlStr.startsWith('http') ? urlStr : 'https://$urlStr');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'VideoAnalysisClaimCard._launchUrl');
    }
  }

  @override
  Widget build(BuildContext context) {
    final verdict = ClaimVerdictHelper.resolveVerdict(claim);
    final resolved = VideoAnalysisHelpers.resolveRealClaimDetails(claim, index, allSources);
    final cleanClaimText = resolved.cleanText;

    // 1. Resolve timestamp
    final rawClaimStart = claim['start'] ??
        claim['startMs'] ??
        claim['startTime'] ??
        claim['startTimeMs'] ??
        claim['timestampStart'];
    final claimStartMs = VideoAnalysisHelpers.normalizeTimestampToMs(rawClaimStart);
    final timestampText = claimStartMs > 0
        ? FormatUtils.formatDuration(Duration(milliseconds: claimStartMs))
        : '00:00';

    // 2. Resolve top source attribution text & direct URL
    var sourceAttribution = '';
    String? sourceUrl;

    if (resolved.sources.isNotEmpty) {
      final firstSource = resolved.sources.first;
      sourceUrl = firstSource['url']?.toString() ?? firstSource['directUrl']?.toString();
      final pub = firstSource['publisher']?.toString() ??
          firstSource['domain']?.toString() ??
          firstSource['author']?.toString() ??
          '';
      final title = firstSource['title']?.toString() ?? firstSource['name']?.toString() ?? '';
      sourceAttribution = pub.isNotEmpty && title.isNotEmpty && pub != title
          ? '$pub – $title'
          : (pub.isNotEmpty ? pub : title);
    }

    if (sourceAttribution.isEmpty) {
      final rawSource = claim['source'] ?? claim['citation'] ?? claim['sourceName'];
      if (rawSource != null && rawSource.toString().isNotEmpty) {
        sourceAttribution = rawSource.toString();
      }
    }

    return InkWell(
      onTap: () {
        ClaimDetailScreen.open(
          context,
          claim: claim,
          claimIndex: index,
          video: video,
          controller: videoCtrl,
          allSources: allSources,
          allClaims: allClaims,
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Circular Number Badge
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: const Color(0xFF222634),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 0.8,
                ),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: GoogleFonts.roboto(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // 2. Center Content Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Meta Row: Verdict Pill & Timestamp & Share button
                  Row(
                    children: [
                      _buildVerdictPill(verdict),
                      const SizedBox(width: 10),

                      // Timestamp Text (Tappable to seek)
                      InkWell(
                        onTap: () {
                          if (claimStartMs > 0 &&
                              videoCtrl.videoPlayerController != null &&
                              videoCtrl.videoPlayerController!.value.isInitialized) {
                            videoCtrl.videoPlayerController!.seekTo(
                              Duration(milliseconds: claimStartMs),
                            );
                            videoCtrl.videoPlayerController!.play();
                          }
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: Text(
                          timestampText,
                          style: GoogleFonts.roboto(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const Spacer(),

                      // Share Button for this specific claim
                      IconButton(
                        icon: const Icon(
                          Icons.share_outlined,
                          size: 16.5,
                          color: AppColors.textSecondary,
                        ),
                        tooltip: 'Share Claim',
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          final domain = resolved.sources.isNotEmpty
                              ? resolved.sources.first['domain']?.toString()
                              : null;
                          ClaimShareService.shareClaim(
                            context: context,
                            video: video,
                            claimText: cleanClaimText,
                            verdict: verdict,
                            primarySourceDomain: domain,
                            claimIndex: index,
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),

                  // Claim Statement
                  Text(
                    cleanClaimText,
                    style: GoogleFonts.roboto(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      height: 1.35,
                    ),
                  ),

                  // Source Attribution Row (if present)
                  if (sourceAttribution.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    InkWell(
                      onTap: sourceUrl != null && sourceUrl.isNotEmpty
                          ? () => _launchUrl(sourceUrl)
                          : null,
                      borderRadius: BorderRadius.circular(4),
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Source: $sourceAttribution',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.roboto(
                                fontSize: 11.5,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ),
                          if (sourceUrl != null && sourceUrl.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.open_in_new_rounded,
                              size: 12,
                              color: AppColors.textTertiary,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),

            // 3. Trailing Chevron Action Arrow
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerdictPill(ClaimVerdictInfo verdict) {
    final Color bgColor;
    final Color borderColor;
    final Color textColor;
    final IconData iconData;
    final String label;

    final rawStatus = (claim['status'] ??
            claim['verificationStatus'] ??
            claim['verdict'] ??
            claim['label'] ??
            '')
        .toString()
        .trim()
        .toLowerCase();
    final verdictLabelLower = verdict.label.toLowerCase();

    final isMostly = rawStatus.contains('mostly') ||
        verdictLabelLower.contains('mostly') ||
        verdict.type == ClaimVerdictType.mostlyTrue;

    final isPartially = rawStatus.contains('partial') ||
        verdictLabelLower.contains('partial') ||
        rawStatus.contains('half');

    if (isMostly) {
      // 🌿 Mostly Verified (Clean modern mint / teal)
      label = 'Mostly Verified';
      bgColor = const Color(0xFF14B8A6).withValues(alpha: 0.14);
      borderColor = const Color(0xFF2DD4BF).withValues(alpha: 0.35);
      textColor = const Color(0xFF2DD4BF);
      iconData = Icons.check_circle_outline_rounded;
    } else if (isPartially) {
      // ⚡ Partially Verified (Warm luminous amber / gold - zero murky brown)
      label = 'Partially Verified';
      bgColor = const Color(0xFFF59E0B).withValues(alpha: 0.14);
      borderColor = const Color(0xFFFBBF24).withValues(alpha: 0.35);
      textColor = const Color(0xFFFBBF24);
      iconData = Icons.warning_amber_rounded;
    } else if (verdict.isVerified) {
      // 🛡️ Fully Verified (Vibrant emerald)
      label = 'Verified';
      bgColor = const Color(0xFF10B981).withValues(alpha: 0.14);
      borderColor = const Color(0xFF10B981).withValues(alpha: 0.35);
      textColor = const Color(0xFF34D399);
      iconData = Icons.check_rounded;
    } else if (verdict.isFalse || rawStatus.contains('false') || rawStatus.contains('misleading')) {
      // 🛑 False / Misleading (Crisp coral red - zero muddy maroon)
      label = (verdict.type == ClaimVerdictType.misleading || rawStatus.contains('misleading'))
          ? 'Misleading'
          : 'False';
      bgColor = const Color(0xFFEF4444).withValues(alpha: 0.14);
      borderColor = const Color(0xFFF87171).withValues(alpha: 0.35);
      textColor = const Color(0xFFF87171);
      iconData = Icons.close_rounded;
    } else if (verdict.isCaution ||
        rawStatus.contains('caution') ||
        rawStatus.contains('disputed') ||
        rawStatus.contains('context') ||
        verdictLabelLower.contains('caution') ||
        verdictLabelLower.contains('disputed') ||
        verdictLabelLower.contains('context')) {
      // ⚠️ Caution / Disputed (Refined warm orange)
      label = (rawStatus.contains('disputed') || verdictLabelLower.contains('disputed'))
          ? 'Disputed'
          : ((rawStatus.contains('context') || verdictLabelLower.contains('context'))
              ? 'Needs Context'
              : 'Caution');
      bgColor = const Color(0xFFF97316).withValues(alpha: 0.14);
      borderColor = const Color(0xFFFB923C).withValues(alpha: 0.35);
      textColor = const Color(0xFFFB923C);
      iconData = Icons.warning_rounded;
    } else if (verdict.isContextual) {
      final isFaith = rawStatus.contains('faith') ||
          rawStatus.contains('religion') ||
          rawStatus.contains('tradition') ||
          verdictLabelLower.contains('faith') ||
          verdictLabelLower.contains('tradition');
      final isSatire = rawStatus.contains('satire') ||
          rawStatus.contains('humor') ||
          rawStatus.contains('parody') ||
          verdictLabelLower.contains('satire');

      if (isFaith) {
        // 📖 Faith / Spiritual Tradition (Luminous soft purple)
        label = verdict.label.isNotEmpty ? verdict.label : 'Faith / Tradition';
        bgColor = const Color(0xFF8B5CF6).withValues(alpha: 0.14);
        borderColor = const Color(0xFFA78BFA).withValues(alpha: 0.35);
        textColor = const Color(0xFFA78BFA);
        iconData = Icons.auto_stories_rounded;
      } else if (isSatire) {
        // 😄 Satire / Hyperbole (Soft rose / pink)
        label = verdict.label.isNotEmpty ? verdict.label : 'Satire / Hyperbole';
        bgColor = const Color(0xFFEC4899).withValues(alpha: 0.14);
        borderColor = const Color(0xFFF472B6).withValues(alpha: 0.35);
        textColor = const Color(0xFFF472B6);
        iconData = Icons.sentiment_very_satisfied_rounded;
      } else {
        // 🧠 Opinion / Value Judgment (Sky blue)
        label = verdict.label.isNotEmpty ? verdict.label : 'Opinion';
        bgColor = const Color(0xFF0284C7).withValues(alpha: 0.14);
        borderColor = const Color(0xFF38BDF8).withValues(alpha: 0.35);
        textColor = const Color(0xFF38BDF8);
        iconData = Icons.psychology_rounded;
      }
    } else {
      // ℹ️ Default / Inconclusive
      label = verdict.label.isNotEmpty ? verdict.label : 'Caution';
      bgColor = const Color(0xFFF59E0B).withValues(alpha: 0.14);
      borderColor = const Color(0xFFFBBF24).withValues(alpha: 0.35);
      textColor = const Color(0xFFFBBF24);
      iconData = Icons.warning_amber_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconData, size: 12.5, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.roboto(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
