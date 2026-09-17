import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/utils/format_utils.dart';
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
    final status = (claim['status'] ?? claim['verificationStatus'] ?? '')
        .toString()
        .toLowerCase();
    final isVerified = status == 'correct' ||
        status == 'mostly_correct' ||
        status == 'verified' ||
        status == 'true' ||
        claim['isVerified'] == true;
    final isDisputed = status.contains('dispute') ||
        status.contains('caution') ||
        status.contains('mostly_false') ||
        status.contains('unverified') ||
        status == 'unconfirmed';
    final isFalse = status == 'false' || status == 'incorrect';

    Color color;
    String statusBadgeText;
    IconData statusIcon;
    if (isVerified) {
      color = AppColors.success;
      statusBadgeText = 'VERIFIED TRUE';
      statusIcon = Icons.check_circle_rounded;
    } else if (isFalse) {
      color = AppColors.error;
      statusBadgeText = 'FALSE';
      statusIcon = Icons.cancel_rounded;
    } else if (isDisputed) {
      color = AppColors.warning;
      statusBadgeText = 'UNCONFIRMED';
      statusIcon = Icons.warning_amber_rounded;
    } else {
      color = AppColors.info;
      statusBadgeText = 'ANALYZED';
      statusIcon = Icons.help_outline_rounded;
    }

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
        borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isExpanded
              ? color.withValues(alpha: 0.12)
              : color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isExpanded
                ? color.withValues(alpha: 0.45)
                : color.withValues(alpha: 0.18),
            width: isExpanded ? 1.5 : 1.0,
          ),
          boxShadow: isExpanded
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.08),
                    blurRadius: 12,
                    spreadRadius: 2,
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
                    color: color.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: context.twTypography.caption.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: color,
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
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  statusIcon,
                                  size: 11,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  statusBadgeText,
                                  style: context.twTypography.overline.copyWith(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: color,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
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
                Icon(
                  isExpanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  color: Colors.white,
                  size: 20,
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
                        color: Colors.white,
                      ),
                      label: Text(
                        'Provide Source',
                        style: context.twTypography.button.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        foregroundColor: Colors.white,
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
    final title = (source['title'] ??
            source['author'] ??
            source['domain'] ??
            source['url'] ??
            'Source Citation')
        .toString();
    final url =
        (source['url'] ?? source['directUrl'] ?? source['link'])?.toString();
    final domain = (source['domain'] ??
            (url != null ? Uri.tryParse(url)?.host : null) ??
            '')
        .toString();
    final snippet = source['snippet']?.toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () async {
          if (url != null && url.isNotEmpty) {
            try {
              final uri =
                  Uri.parse(url.startsWith('http') ? url : 'https://$url');
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            } catch (e, stackTrace) {
              ErrorHandler.log(
                e,
                stackTrace: stackTrace,
                tag: 'VideoAnalysisClaimCard.launchSourceUrl',
              );
            }
          }
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
