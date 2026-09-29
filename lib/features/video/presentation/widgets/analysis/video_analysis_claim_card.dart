import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/core/utils/source_url_sanitizer.dart';
import 'package:truthworld/core/widgets/truth_credibility_badge.dart';
import 'package:truthworld/features/video/data/models/claim_verdict_helper.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/widgets/analysis/video_analysis_controller.dart';
import 'package:truthworld/features/video/presentation/widgets/analysis/video_analysis_helpers.dart';
import 'package:truthworld/features/video/presentation/widgets/claim_source_submission_dialog.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

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

  @override
  Widget build(BuildContext context) {
    final verdict = ClaimVerdictHelper.resolveVerdict(claim);
    final isVerified = verdict.isVerified;
    final isDisputed = verdict.isCaution;
    final isFalse = verdict.isFalse;
    final statusBadgeText = verdict.label;
    final statusIcon = verdict.icon;

    final resolved = VideoAnalysisHelpers.resolveRealClaimDetails(claim, index, allSources);
    final cleanClaimText = resolved.cleanText;
    final responseText = resolved.response;
    final effectiveSources = resolved.sources;

    return Obx(() {
      final isExpanded = analysisCtrl.expandedClaimIndices.contains(index);
      return InkWell(
        onTap: () {
          if (analysisCtrl.expandedClaimIndices.contains(index)) {
            analysisCtrl.expandedClaimIndices.remove(index);
          } else {
            analysisCtrl.expandedClaimIndices.add(index);
          }
        },
        borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isExpanded
              ? Colors.white.withValues(alpha: 0.05)
              : AppColors.bgSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isExpanded
                ? Colors.white.withValues(alpha: 0.3)
                : AppColors.bgDivider.withValues(alpha: 0.7),
          ),
          boxShadow: isExpanded
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : const [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Number, Clean Claim Text, Status Badge, Expand Icon
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: context.twTypography.caption.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: TWTypography.uiFamily,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          TruthCredibilityBadge(
                            label: statusBadgeText,
                            color: Colors.white,
                            icon: statusIcon,
                            isVerified: isVerified,
                            isDisputed: isDisputed,
                            isFalse: isFalse,
                            showGlow: isExpanded,
                            fontSize: 9,
                            iconSize: 11,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2.5,
                            ),
                          ),
                          () {
                            final rawClaimStart = claim['start'] ??
                                claim['startMs'] ??
                                claim['startTime'] ??
                                claim['startTimeMs'] ??
                                claim['timestampStart'];
                            final claimStartMs = VideoAnalysisHelpers.normalizeTimestampToMs(rawClaimStart);
                            if (claimStartMs > 0) {
                              final claimDur = Duration(milliseconds: claimStartMs);
                              return Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: InkWell(
                                  onTap: () {
                                    if (videoCtrl.videoPlayerController != null &&
                                        videoCtrl.videoPlayerController!.value.isInitialized) {
                                      videoCtrl.videoPlayerController!.seekTo(claimDur);
                                      videoCtrl.videoPlayerController!.play();
                                      Get.back();
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(4),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.play_arrow_rounded,
                                          size: 11,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          FormatUtils.formatDuration(claimDur),
                                          style: context.twTypography.caption.copyWith(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            fontFamily: TWTypography.uiFamily,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          }(),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        cleanClaimText,
                        style: context.twTypography.title.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppColors.textPrimary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOutCubic,
                  child: const Icon(
                    Icons.expand_more_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),

            // Expanded Details: Real AI Response & Real Tapable Sources
            if (isExpanded) ...[
              const SizedBox(height: 14),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 12),

              // AI Verification Response
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'AI VERIFICATION RESPONSE & EVIDENCE ANALYSIS',
                          style: context.twTypography.overline.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.brand,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      responseText,
                      style: context.twTypography.body.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 12.5,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),

              // Tapable Sources & Citations
              if (effectiveSources.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.link_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'SUPPORTING CITATIONS & PROVENANCE (${effectiveSources.length})',
                      style: context.twTypography.overline.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                ...effectiveSources.map((s) => _buildTapableClaimSource(context, s)),
              ],

              // Action Buttons: Search on Web + Provide Evidence
              const SizedBox(height: 12),
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
                            tag: 'VideoAnalysisClaimCard.searchWeb',
                          );
                        }
                      },
                      icon: const Icon(
                        Icons.search_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                      label: Text(
                        'Search Web',
                        style: context.twTypography.button.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => ClaimSourceSubmissionDialog.show(
                        context: context,
                        video: video,
                        claims: allClaims,
                        initialClaim: claim,
                      ),
                      icon: const Icon(
                        Icons.add_link_rounded,
                        size: 14,
                        color: Colors.black,
                      ),
                      label: Text(
                        'Provide Source',
                        style: context.twTypography.button.copyWith(
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
                          borderRadius: BorderRadius.circular(10),
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
    );
    });
  }


  Widget _buildTapableClaimSource(BuildContext context, Map<dynamic, dynamic> source) {
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
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () async {
          await SourceUrlSanitizer.launchSourceUrl(
            url: url,
            title: title,
            domain: domain,
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.language_rounded,
                size: 16,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.twTypography.title.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (domain.isNotEmpty) ...[
                      Text(
                        domain,
                        style: context.twTypography.caption.copyWith(
                          fontSize: 10,
                          color: AppColors.textLink,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                    if (snippet != null && snippet.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '"$snippet"',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.twTypography.caption.copyWith(
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.open_in_new_rounded,
                size: 14,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }

}
