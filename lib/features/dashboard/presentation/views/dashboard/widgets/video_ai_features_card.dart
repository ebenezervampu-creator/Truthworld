import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/chapters_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/chapters_page.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/content/content_ai_features_dialog.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/video_management.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/widgets/audio_track_builder.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/models/video_media.dart';
import 'package:truthworld/features/video/data/services/video_media_service.dart';
import 'package:truthworld/features/video/presentation/widgets/fact_check_report_widget.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Comprehensive AI Content Features & Localization Overview Card.
/// Displays live inventory of Subtitles, Dubbing, Auto-Chapters, AI Summary,
/// and Fact-Checking with granular counts and targeted generation actions.
class VideoAIFeaturesOverviewCard extends StatelessWidget {
  const VideoAIFeaturesOverviewCard({
    required this.video,
    required this.isDarkMode,
    required this.controller,
    super.key,
  });

  final Video video;
  final bool isDarkMode;
  final VideoManagementController controller;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<VideoMediaLocalization>(
      stream: VideoMediaService().streamLocalization(video.id),
      builder: (context, locSnap) {
        return StreamBuilder<VideoMediaCredibility>(
          stream: VideoMediaService().streamCredibility(video.id),
          builder: (context, credSnap) {
            final loc = locSnap.data ??
                VideoMediaService.localizationCache[video.id] ??
                const VideoMediaLocalization();
            final cred = credSnap.data ??
                VideoMediaService.credibilityCache[video.id] ??
                const VideoMediaCredibility();

            // 1. Subtitles evaluation
            final subtitles = loc.subtitles.isNotEmpty
                ? loc.subtitles
                : video.mediaSubtitles;
            final hasSubtitles = subtitles.isNotEmpty;
            final subtitleCount = subtitles.length;

            // 2. Dubbing evaluation
            final dubbedVideos = loc.dubbedVideos.isNotEmpty
                ? loc.dubbedVideos
                : video.dubbedVideos;
            final audioTracks = loc.audioTracks.isNotEmpty
                ? loc.audioTracks
                : video.audioTracks;
            final allDubbedLangs = <String>{
              ...dubbedVideos.keys,
              ...audioTracks.keys,
            }.toList();
            final hasDubbing = allDubbedLangs.isNotEmpty;
            final dubbingCount = allDubbedLangs.length;

            // 3. Auto-Chapters evaluation
            final chapters = video.chapters;
            final hasChapters = chapters.isNotEmpty;
            final chaptersCount = chapters.length;

            // 4. AI Summary evaluation
            final rawSummary = cred.summary.isNotEmpty
                ? cred.summary
                : (video.moderationSummary.isNotEmpty
                    ? video.moderationSummary
                    : '');
            final hasRealAiSummary = rawSummary.isNotEmpty &&
                rawSummary.trim() != video.description.trim();

            // 5. Fact-checking evaluation
            final hasRealFactCheckReport = cred.claims.isNotEmpty ||
                cred.factCheckUrl.isNotEmpty ||
                video.factCheckUrl.isNotEmpty ||
                (cred.uiReport != null &&
                    (cred.uiReport!.keyClaims.isNotEmpty ||
                        cred.uiReport!.summary.rating != null)) ||
                (cred.factCheckStats != null &&
                    cred.factCheckStats!.totalClaims > 0);
            final isFactChecked = !video.isNonCredibilityCategory &&
                (video.isFactChecked ||
                    video.hasAiCredibility ||
                    hasRealFactCheckReport);
            final effectiveTrustScore = cred.trustScore > 0
                ? cred.trustScore
                : video.trustScore;

            // Missing features calculation
            final missingFeatures = <String>[];
            if (!hasSubtitles) missingFeatures.add('subtitles');
            if (!hasDubbing) missingFeatures.add('dubbing');
            if (!hasChapters) missingFeatures.add('chapters');
            if (!isFactChecked) missingFeatures.add('factcheck');

            final configuredCount = 5 - missingFeatures.length - (hasRealAiSummary ? 0 : 1);

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.bgDivider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.auto_awesome_rounded,
                              size: 20,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'AI Features & Localization Breakdown',
                                style: AppTextStyles.titleMedium.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: TWTypography.brandFamily,
                                ),
                              ),
                            ),
                            _buildStatusBadge(
                              label: missingFeatures.isEmpty
                                  ? 'ALL COMPLETE'
                                  : '$configuredCount/5 CONFIGURED',
                              color: missingFeatures.isEmpty
                                  ? AppColors.success
                                  : (missingFeatures.length > 2
                                      ? AppColors.warning
                                      : AppColors.info),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Live multi-language status for subtitles, dubbing, auto-chapters, verified summary, and credibility fact-checking.',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Missing features alert banner (if any)
                  if (missingFeatures.isNotEmpty) ...[
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                size: 16,
                                color: AppColors.warning,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Missing AI Capabilities Detected',
                                  style: AppTextStyles.labelMedium.copyWith(
                                    color: AppColors.warning,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Missing: ${_formatMissingNames(missingFeatures)}. Generating these features unlocks wider multi-regional discovery, accessibility, and algorithmic credibility.',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.brand,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            icon: const Icon(
                              Icons.bolt_rounded,
                              size: 16,
                              color: Colors.black,
                            ),
                            label: Text(
                              'Generate Missing AI Features',
                              style: AppTextStyles.buttonText.copyWith(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: () {
                              showGenerateAIFeaturesDialog(
                                context,
                                video,
                                controller,
                                initialFeatures: missingFeatures.toSet(),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  const Divider(color: AppColors.bgDivider, height: 1),

                  // Feature 1: Subtitles & Captions
                  _buildFeatureRow(
                    context: context,
                    icon: Icons.subtitles_rounded,
                    title: 'Subtitles & Captions',
                    countText: hasSubtitles
                        ? '$subtitleCount Subtitle${subtitleCount > 1 ? "s" : ""} Available'
                        : 'No Subtitles Generated',
                    statusBadge: _buildStatusBadge(
                      label: hasSubtitles ? 'ACTIVE ($subtitleCount)' : 'MISSING',
                      color: hasSubtitles ? AppColors.success : AppColors.warning,
                    ),
                    content: hasSubtitles
                        ? Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: subtitles.keys.map((code) {
                              final label = AudioTrackBuilder.labelFor(code);
                              return _buildChip('$label (${code.toUpperCase()})');
                            }).toList(),
                          )
                        : Text(
                            'Adding multilingual subtitles expands viewer retention and search accessibility.',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                    actionButton: OutlinedButton.icon(
                      style: _actionButtonStyle(),
                      icon: const Icon(Icons.add_rounded, size: 14, color: Colors.white),
                      label: Text(
                        hasSubtitles ? 'Add More Subtitles' : 'Add Subtitles',
                        style: _actionButtonTextStyle(),
                      ),
                      onPressed: () {
                        showGenerateAIFeaturesDialog(
                          context,
                          video,
                          controller,
                          initialFeatures: {'subtitles'},
                        );
                      },
                    ),
                  ),

                  const Divider(color: AppColors.bgDivider, height: 1),

                  // Feature 2: Multilingual Dubbing
                  _buildFeatureRow(
                    context: context,
                    icon: Icons.record_voice_over_rounded,
                    title: 'Multilingual Dubbing',
                    countText: hasDubbing
                        ? '$dubbingCount Dubbed Track${dubbingCount > 1 ? "s" : ""} Available'
                        : 'No Dubbed Audio/Video',
                    statusBadge: _buildStatusBadge(
                      label: hasDubbing ? 'ACTIVE ($dubbingCount)' : 'NOT DUBBED',
                      color: hasDubbing ? AppColors.success : AppColors.textTertiary,
                    ),
                    content: hasDubbing
                        ? Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: allDubbedLangs.map((code) {
                              final label = AudioTrackBuilder.labelFor(code);
                              final isVideo = dubbedVideos.containsKey(code);
                              return _buildChip(
                                '$label ${isVideo ? "(Audio+Video)" : "(Audio)"}',
                              );
                            }).toList(),
                          )
                        : Text(
                            'AI Dubbing delivers natural vocal translation in target regional languages.',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                    actionButton: OutlinedButton.icon(
                      style: _actionButtonStyle(),
                      icon: const Icon(Icons.mic_none_rounded, size: 14, color: Colors.white),
                      label: Text(
                        hasDubbing ? 'Add More Dubbing' : 'Generate Dubbing',
                        style: _actionButtonTextStyle(),
                      ),
                      onPressed: () {
                        showGenerateAIFeaturesDialog(
                          context,
                          video,
                          controller,
                          initialFeatures: {'dubbing'},
                        );
                      },
                    ),
                  ),

                  const Divider(color: AppColors.bgDivider, height: 1),

                  // Feature 3: Auto-Chapters
                  _buildFeatureRow(
                    context: context,
                    icon: Icons.view_timeline_rounded,
                    title: 'Auto-Chapters & Timestamps',
                    countText: hasChapters
                        ? '$chaptersCount Chapters Defined'
                        : 'No Chapters Configured',
                    statusBadge: _buildStatusBadge(
                      label: hasChapters ? 'GENERATED ($chaptersCount)' : 'NONE',
                      color: hasChapters ? AppColors.success : AppColors.textTertiary,
                    ),
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (hasChapters) ...[
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: chapters.take(4).map((ch) {
                              return _buildChip(
                                '${ch.startTime} ${ch.title}',
                              );
                            }).toList(),
                          ),
                          if (chapters.length > 4) ...[
                            const SizedBox(height: 4),
                            Text(
                              '+ ${chapters.length - 4} more chapters',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textTertiary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ] else
                          Text(
                            'Chapters allow viewers to navigate key topics directly on the timeline.',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                      ],
                    ),
                    actionButton: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OutlinedButton.icon(
                          style: _actionButtonStyle(),
                          icon: const Icon(Icons.tune_rounded, size: 14, color: Colors.white),
                          label: Text('Manage', style: _actionButtonTextStyle()),
                          onPressed: () {
                            final chaptersCtrl =
                                Get.isRegistered<ChaptersController>()
                                    ? Get.find<ChaptersController>()
                                    : Get.put(ChaptersController());
                            chaptersCtrl.setChannelContext(video.channelId);
                            chaptersCtrl.selectVideo(video);
                            Get.to<dynamic>(
                              () => ChaptersPage(
                                channelId: video.channelId,
                                isDarkMode: isDarkMode,
                              ),
                            );
                          },
                        ),
                        if (!hasChapters) ...[
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            style: _actionButtonStyle(),
                            icon: const Icon(Icons.auto_fix_high_rounded, size: 14, color: Colors.white),
                            label: Text('Auto-Generate', style: _actionButtonTextStyle()),
                            onPressed: () {
                              showGenerateAIFeaturesDialog(
                                context,
                                video,
                                controller,
                                initialFeatures: {'chapters'},
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),

                  const Divider(color: AppColors.bgDivider, height: 1),

                  // Feature 4: AI Summary
                  _buildFeatureRow(
                    context: context,
                    icon: Icons.psychology_rounded,
                    title: 'AI Verification Summary',
                    countText: hasRealAiSummary
                        ? 'Verified AI Synopsis'
                        : 'No Verified AI Summary',
                    statusBadge: _buildStatusBadge(
                      label: hasRealAiSummary ? 'GENERATED' : 'MISSING',
                      color: hasRealAiSummary ? AppColors.success : AppColors.textTertiary,
                    ),
                    content: hasRealAiSummary
                        ? Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.bgSurfaceHover,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              rawSummary,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          )
                        : Text(
                            'A structured AI summary accurately encapsulates key claims and discussion context.',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                    actionButton: hasRealAiSummary
                        ? null
                        : OutlinedButton.icon(
                            style: _actionButtonStyle(),
                            icon: const Icon(Icons.auto_awesome_rounded, size: 14, color: Colors.white),
                            label: Text('Generate Summary', style: _actionButtonTextStyle()),
                            onPressed: () {
                              showGenerateAIFeaturesDialog(
                                context,
                                video,
                                controller,
                                initialFeatures: {'factcheck'},
                              );
                            },
                          ),
                  ),

                  const Divider(color: AppColors.bgDivider, height: 1),

                  // Feature 5: AI Fact-Checking & Credibility
                  _buildFeatureRow(
                    context: context,
                    icon: Icons.fact_check_rounded,
                    title: 'AI Fact-Checking & Trust Score',
                    countText: isFactChecked
                        ? '${effectiveTrustScore.toInt()}% Trust Score • ${cred.claims.length} Claims Evaluated'
                        : 'Not Fact-Checked',
                    statusBadge: _buildStatusBadge(
                      label: isFactChecked
                          ? (effectiveTrustScore >= 75
                              ? 'HIGH TRUST'
                              : (effectiveTrustScore >= 50
                                  ? 'CAUTION'
                                  : 'FLAGGED'))
                          : 'NOT CHECKED',
                      color: isFactChecked
                          ? (effectiveTrustScore >= 75
                              ? AppColors.success
                              : (effectiveTrustScore >= 50
                                  ? AppColors.warning
                                  : AppColors.error))
                          : AppColors.textTertiary,
                    ),
                    content: isFactChecked
                        ? Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              _buildChip('${effectiveTrustScore.toInt()}% Institutional Score'),
                              if (cred.claims.isNotEmpty)
                                _buildChip('${cred.claims.length} Spoken Claims'),
                              if (cred.sources.isNotEmpty)
                                _buildChip('${cred.sources.length} Grounded Sources'),
                              _buildChip(
                                video.canPublicViewFactCheck
                                    ? 'Publicly Visible'
                                    : 'Creator Review Only',
                              ),
                            ],
                          )
                        : Text(
                            'TruthWorld Credibility Engine analyzes spoken transcripts to verify claims against authoritative ground-truth sources.',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                    actionButton: isFactChecked
                        ? OutlinedButton.icon(
                            style: _actionButtonStyle(),
                            icon: const Icon(Icons.analytics_rounded, size: 14, color: Colors.white),
                            label: Text('View Full Report', style: _actionButtonTextStyle()),
                            onPressed: () {
                              final data = cred.toMap();
                              if (!data.containsKey('trustScore') ||
                                  (data['trustScore'] as num? ?? 0) == 0) {
                                data['trustScore'] = effectiveTrustScore;
                              }
                              Get.bottomSheet(
                                FactCheckReportWidget(
                                  data: data,
                                  video: video,
                                ),
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                              );
                            },
                          )
                        : OutlinedButton.icon(
                            style: _actionButtonStyle(),
                            icon: const Icon(Icons.bolt_rounded, size: 14, color: Colors.white),
                            label: Text('Run Fact-Check', style: _actionButtonTextStyle()),
                            onPressed: () {
                              showGenerateAIFeaturesDialog(
                                context,
                                video,
                                controller,
                                initialFeatures: {'factcheck'},
                              );
                            },
                          ),
                  ),

                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFeatureRow({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String countText,
    required Widget statusBadge,
    required Widget content,
    Widget? actionButton,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      countText,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              statusBadge,
            ],
          ),
          const SizedBox(height: 10),
          content,
          if (actionButton != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: actionButton,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.bgSurfaceHover,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: AppColors.textSecondary,
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  ButtonStyle _actionButtonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: Colors.white,
      side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }

  TextStyle _actionButtonTextStyle() {
    return AppTextStyles.labelSmall.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.bold,
      fontSize: 12,
    );
  }

  String _formatMissingNames(List<String> list) {
    return list.map((k) {
      switch (k) {
        case 'subtitles':
          return 'Subtitles';
        case 'dubbing':
          return 'Multilingual Dubbing';
        case 'chapters':
          return 'Auto-Chapters';
        case 'factcheck':
          return 'Fact-Checking';
        default:
          return k;
      }
    }).join(', ');
  }
}
