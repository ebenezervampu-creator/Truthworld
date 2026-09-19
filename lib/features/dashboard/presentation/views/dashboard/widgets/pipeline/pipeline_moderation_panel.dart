import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Content safety and policy violation status color resolver.
Color getSafetyColor(String status) {
  switch (status.toUpperCase()) {
    case 'APPROVED':
      return AppColors.success;
    case 'REJECTED':
      return AppColors.error;
    case 'MANUAL_REVIEW':
      return AppColors.info;
    case 'ERROR':
    case 'FLAGGED':
      return AppColors.warning;
    case 'PENDING':
    default:
      return AppColors.warning;
  }
}

/// Content safety and policy violation status icon resolver.
IconData getSafetyIcon(String status) {
  switch (status.toUpperCase()) {
    case 'APPROVED':
      return Icons.check_circle_outline_rounded;
    case 'REJECTED':
      return Icons.cancel_outlined;
    case 'MANUAL_REVIEW':
      return Icons.hourglass_top_rounded;
    case 'ERROR':
    case 'FLAGGED':
      return Icons.warning_amber_rounded;
    case 'PENDING':
    default:
      return Icons.hourglass_empty_rounded;
  }
}

/// Content intent color classifier.
Color getIntentColor(String intent) {
  switch (intent.toLowerCase()) {
    case 'news_reporting':
    case 'documentary':
      return AppColors.info;
    case 'educational':
      return AppColors.success;
    case 'commentary':
    case 'review':
    case 'satire':
      return AppColors.brand;
    case 'personal_experience':
    case 'entertainment':
      return AppColors.textSecondary;
    case 'promotional':
      return AppColors.warning;
    case 'instructional_harmful':
      return AppColors.error;
    default:
      return AppColors.textTertiary;
  }
}

/// Content risk level color classifier.
Color getRiskColor(String riskLevel) {
  switch (riskLevel.toLowerCase()) {
    case 'safe':
    case 'low':
      return AppColors.success;
    case 'medium':
      return AppColors.warning;
    case 'high':
    case 'critical':
      return AppColors.error;
    default:
      return AppColors.textTertiary;
  }
}

/// Video Content Moderation panel presenting Gemini v3.0 intent-aware analysis.
class PipelineModerationPanel extends StatelessWidget {
  const PipelineModerationPanel({
    required this.status,
    this.reason,
    this.summary,
    this.categories = const [],
    this.processingTimeMs,
    this.topic,
    this.intent,
    this.riskLevel,
    this.explanation,
    super.key,
  });

  final String status;
  final String? reason;
  final String? summary;
  final List<String> categories;
  final int? processingTimeMs;
  final String? topic;
  final String? intent;
  final String? riskLevel;
  final String? explanation;

  @override
  Widget build(BuildContext context) {
    final color = getSafetyColor(status);
    final icon = getSafetyIcon(status);
    final isProcessing = status == 'PROCESSING';
    final isManualReview = status == 'MANUAL_REVIEW';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Row
          Row(
            children: [
              if (isProcessing)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              else
                Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isProcessing
                      ? 'Analyzing content (topic, intent, risk)...'
                      : (status == 'APPROVED'
                            ? 'Content approved — complies with Community Guidelines'
                            : (status == 'REJECTED'
                                  ? 'Content rejected — policy violation detected'
                                  : (isManualReview
                                        ? 'Pending manual review — awaiting admin decision'
                                        : (status == 'ERROR'
                                              ? 'Moderation system error (transient failure)'
                                              : 'Awaiting content moderation...')))),
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (processingTimeMs != null)
                Text(
                  '${(processingTimeMs! / 1000).toStringAsFixed(1)}s',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
            ],
          ),

          // Intent & Topic Badges
          if ((topic != null || intent != null || riskLevel != null) &&
              (status == 'APPROVED' ||
                  status == 'REJECTED' ||
                  isManualReview)) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (topic != null)
                  _buildInfoChip(
                    label: topic!.replaceAll('_', ' '),
                    color: AppColors.brand,
                    prefix: 'Topic',
                  ),
                if (intent != null)
                  _buildInfoChip(
                    label: intent!.replaceAll('_', ' '),
                    color: getIntentColor(intent!),
                    prefix: 'Intent',
                  ),
                if (riskLevel != null)
                  _buildInfoChip(
                    label: riskLevel!.toUpperCase(),
                    color: getRiskColor(riskLevel!),
                    prefix: 'Risk',
                  ),
              ],
            ),
          ],

          // Violation Categories (if rejected)
          if (categories.isNotEmpty && status == 'REJECTED') ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: categories.map((cat) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    cat.replaceAll('_', ' ').toUpperCase(),
                    style: AppTextStyles.labelSmall.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.error,
                      letterSpacing: 0.5,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          // Policy Reason
          if (reason != null &&
              reason!.isNotEmpty &&
              (status == 'REJECTED' ||
                  isManualReview ||
                  status == 'ERROR')) ...[
            const SizedBox(height: 6),
            Text(
              reason!,
              style: AppTextStyles.bodySmall.copyWith(
                fontSize: 12,
                color: status == 'REJECTED'
                    ? AppColors.error
                    : AppColors.warning,
                height: 1.3,
              ),
            ),
          ],

          // Explanation
          if (explanation != null &&
              explanation!.isNotEmpty &&
              status != 'ERROR') ...[
            const SizedBox(height: 4),
            Text(
              explanation!,
              style: AppTextStyles.caption.copyWith(
                fontSize: 11,
                color: AppColors.textTertiary,
                fontStyle: FontStyle.italic,
                height: 1.3,
              ),
            ),
          ],

          // Manual review guidance info box
          if (isManualReview) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppColors.info.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(
                      Icons.info_outline_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Our AI detected this content discusses a sensitive topic but could not confidently determine if it is journalistic/educational or promotional. An admin will review shortly.',
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 11,
                        color: AppColors.info,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Summary (if approved)
          if (summary != null &&
              summary!.isNotEmpty &&
              status == 'APPROVED') ...[
            const SizedBox(height: 6),
            Text(
              summary!,
              style: AppTextStyles.bodySmall.copyWith(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.3,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required String label,
    required Color color,
    String? prefix,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        prefix != null ? '$prefix: $label' : label,
        style: AppTextStyles.labelSmall.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
