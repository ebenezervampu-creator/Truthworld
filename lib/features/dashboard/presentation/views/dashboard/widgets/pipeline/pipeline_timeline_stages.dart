import 'package:flutter/material.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Renders the end-to-end timeline stages for video processing with authentic
/// stage dependency tracking.
class PipelineTimelineStages extends StatelessWidget {
  const PipelineTimelineStages({
    required this.stages,
    required this.video,
    super.key,
  });

  final Map<String, dynamic> stages;
  final Video video;

  Map<String, dynamic>? _getStageData(
    String key,
    Map<String, dynamic> stages,
  ) {
    if (stages.containsKey(key) && stages[key] is Map<String, dynamic>) {
      return stages[key] as Map<String, dynamic>;
    }

    final aliases = <String, List<String>>{
      'upload': ['uploadSource', 'ingestion', 'upload_source'],
      'validation': ['safety', 'safetyFormatCheck', 'formatCheck', 'safety_and_format'],
      'transcription': ['transcribe', 'audioTranscription', 'transcription_gemini'],
      'credibility': ['factcheck', 'fact_check', 'credibilityCheck'],
      'dubbing': ['localization', 'translation', 'translate'],
      'rendering': ['render', 'videoRendering', 'transcoding'],
      'aggregation': ['finalizing', 'finish', 'complete', 'aggregationFinish'],
    };

    final altKeys = aliases[key] ?? [];
    for (final alt in altKeys) {
      if (stages.containsKey(alt) && stages[alt] is Map<String, dynamic>) {
        return stages[alt] as Map<String, dynamic>;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final orderedStages = [
      {'key': 'moderation', 'label': 'Content Moderation (Verification System)'},
      {'key': 'upload', 'label': 'Upload Source'},
      {'key': 'validation', 'label': 'Safety & Format Check'},
      {'key': 'transcription', 'label': 'Transcription (Verification System)'},
      {'key': 'credibility', 'label': 'Factcheck (Verify)'},
      {'key': 'dubbing', 'label': 'Localization (Dubbing)'},
      {'key': 'rendering', 'label': 'Rendering Output'},
      {'key': 'aggregation', 'label': 'Aggregation & Finish'},
    ];

    // Determine real transcription status
    final transcriptionData = _getStageData('transcription', stages);
    final rawTranscriptionStatus =
        (transcriptionData?['status'] as String?)?.toLowerCase() ?? 'pending';
    final hasValidTranscript = (video.transcriptionUrl.isNotEmpty &&
            !video.transcriptionUrl.contains('placeholder')) ||
        video.mediaSubtitles.isNotEmpty;
    final isTranscriptionFailed = rawTranscriptionStatus == 'failed';
    final isTranscriptionDone =
        rawTranscriptionStatus == 'completed' ||
        (rawTranscriptionStatus != 'running' && !isTranscriptionFailed && hasValidTranscript);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...orderedStages.map((stage) {
          final key = stage['key']!;
          final label = stage['label']!;
          final stageData = _getStageData(key, stages);
          var status = (stageData?['status'] as String?)?.toLowerCase() ?? 'pending';

          String? statusSubtitle;

          // Epistemically truthful status evaluation
          if (key == 'upload') {
            if (video.videoUrl.isNotEmpty || video.originalUrl.isNotEmpty) {
              status = 'completed';
            }
          } else if (key == 'moderation') {
            if (video.isApprovedByGeminiOrManual || status == 'approved') {
              status = 'completed';
            }
          } else if (key == 'validation') {
            if (status == 'pending' &&
                (video.status.name == 'ready' || video.status.name == 'published')) {
              status = 'completed';
            }
          } else if (key == 'transcription') {
            if (status == 'failed') {
              status = 'failed';
              statusSubtitle = stageData?['error'] as String?;
            } else if (isTranscriptionDone) {
              status = 'completed';
            }
          } else if (key == 'credibility') {
            if (status == 'failed') {
              status = 'failed';
              statusSubtitle = stageData?['error'] as String?;
            } else if (status == 'skipped') {
              status = 'skipped';
              statusSubtitle = 'Not Requested';
            } else if (video.hasAiCredibility || video.factCheckUrl.isNotEmpty || status == 'completed') {
              status = 'completed';
            } else if (status == 'running') {
              status = 'running';
            } else if (status == 'pending' &&
                (video.factCheckTier == 'none' ||
                    video.factCheckTier == 'off' ||
                    !video.isFactChecked)) {
              status = 'skipped';
              statusSubtitle = 'Not Requested';
            }
          } else if (key == 'dubbing') {
            final hasDubbedOutput = video.dubbedVideos.isNotEmpty ||
                (video.audioTracks.isNotEmpty &&
                    video.audioTracks.keys.any((k) => k != video.language));

            if (isTranscriptionFailed && status != 'completed') {
              status = 'blocked';
              statusSubtitle = 'Requires Transcription';
            } else if (hasDubbedOutput) {
              status = 'completed';
            } else if (status == 'skipped') {
              status = 'skipped';
            } else if (status == 'running') {
              status = 'running';
            } else if (status == 'pending' && video.languages.length <= 1) {
              status = 'skipped';
            } else if (!hasDubbedOutput &&
                (video.languages.length <= 1 || status == 'completed')) {
              // Creator skipped dubbing or no dubbed media exists
              status = 'skipped';
            }
          } else if (key == 'rendering') {
            if (video.adaptiveResolutions.isNotEmpty || status == 'completed') {
              status = 'completed';
            }
          } else if (key == 'aggregation') {
            if (isTranscriptionFailed && status != 'completed') {
              status = 'blocked';
            } else if (status == 'pending' &&
                (video.status.name == 'ready' || video.status.name == 'published') &&
                !isTranscriptionFailed) {
              status = 'completed';
            }
          }

          final progress =
              stageData?['progress'] as num? ?? (status == 'completed' ? 100 : 0);

          Color itemColor;
          Widget leadingWidget;

          switch (status) {
            case 'completed':
              itemColor = AppColors.success;
              leadingWidget = const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 16,
              );
            case 'running':
              itemColor = AppColors.brand;
              leadingWidget = const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.brand,
                ),
              );
            case 'pending_review':
              itemColor = AppColors.info;
              leadingWidget = const Icon(
                Icons.hourglass_top_rounded,
                color: Colors.white,
                size: 16,
              );
            case 'failed':
              itemColor = AppColors.error;
              leadingWidget = const Icon(
                Icons.error_rounded,
                color: Colors.white,
                size: 16,
              );
            case 'blocked':
              itemColor = AppColors.warning;
              leadingWidget = const Icon(
                Icons.block_rounded,
                color: Colors.white,
                size: 16,
              );
            case 'skipped':
              itemColor = AppColors.textTertiary;
              leadingWidget = const Icon(
                Icons.skip_next_rounded,
                color: Colors.white,
                size: 16,
              );
            case 'pending':
            default:
              itemColor = AppColors.textTertiary;
              leadingWidget = const Icon(
                Icons.radio_button_unchecked_rounded,
                color: Colors.white,
                size: 14,
              );
          }

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(width: 24, child: Center(child: leadingWidget)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontSize: 13,
                          fontWeight: status == 'running'
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: status == 'pending' || status == 'skipped'
                              ? AppColors.textTertiary
                              : AppColors.textPrimary,
                        ),
                      ),
                      if (statusSubtitle != null && statusSubtitle.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          statusSubtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 10.5,
                            color: itemColor.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (status == 'running') ...[
                  const SizedBox(width: 8),
                  Text(
                    '${progress.toInt()}%',
                    style: AppTextStyles.labelMedium.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brand,
                    ),
                  ),
                ] else ...[
                  Text(
                    status.toUpperCase(),
                    style: AppTextStyles.labelSmall.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: itemColor,
                    ),
                  ),
                ],
              ],
            ),
          );
        }),

        if (isTranscriptionFailed) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Transcription Incomplete — Fact-Checking Blocked',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  "TruthWorld's Credibility Engine extracts and verifies factual claims directly from the spoken audio transcript. Without speech transcription, automated fact-checks cannot be generated.",
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
