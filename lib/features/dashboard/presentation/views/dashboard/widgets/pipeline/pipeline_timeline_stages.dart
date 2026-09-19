import 'package:flutter/material.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Renders the end-to-end timeline stages for video processing.
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
      'credibility': ['factcheck', 'truthEngine', 'fact_check', 'credibilityCheck'],
      'dubbing': ['localization', 'reachEngine', 'translation', 'translate'],
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

    return Column(
      children: orderedStages.map((stage) {
        final key = stage['key']!;
        final label = stage['label']!;
        final stageData = _getStageData(key, stages);
        var status = (stageData?['status'] as String?)?.toLowerCase() ?? 'pending';

        if (status == 'pending' &&
            (video.status.name == 'ready' || video.status.name == 'published')) {
          status = 'completed';
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
                child: Text(
                  label,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontSize: 13,
                    fontWeight: status == 'running'
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: status == 'pending'
                        ? AppColors.textTertiary
                        : AppColors.textPrimary,
                  ),
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
      }).toList(),
    );
  }
}
