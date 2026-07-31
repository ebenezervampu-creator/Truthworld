import 'package:flutter/material.dart';
import 'package:truthworld/features/video/data/models/content_verification.dart';
import 'package:truthworld/features/video/data/models/pipeline_status.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Job Status Widget - Displays real-time pipeline processing status
class JobStatusWidget extends StatelessWidget {
  const JobStatusWidget({
    required this.jobStatus,
    super.key,
    this.onCancel,
    this.onRetry,
    this.showActions = true,
  });
  final PipelineJobStatus jobStatus;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;
  final bool showActions;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.textSecondary),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Status
          _buildHeader(),
          const SizedBox(height: 20),

          // Overall Progress Bar
          _buildProgressBar(),
          const SizedBox(height: 12),

          // Progress Text
          Text(
            '${jobStatus.progressPercent}% Complete',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.info,
            ),
          ),
          const SizedBox(height: 20),

          // Stage Breakdown
          _buildStageBreakdown(),
          const SizedBox(height: 20),

          // ETA and Error Info
          _buildMetadata(),
          const SizedBox(height: 20),

          // Action Buttons
          if (showActions) _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    var statusColor = AppColors.info;
    var statusText = jobStatus.currentStageName;

    if (jobStatus.isCompleted) {
      statusColor = AppColors.success;
      statusText = 'Completed';
    } else if (jobStatus.isFailed) {
      statusColor = AppColors.error;
      statusText = 'Failed';
    } else if (jobStatus.isProcessing) {
      statusColor = AppColors.warning;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Job ID: ${jobStatus.jobId.substring(0, 8)}...',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              statusText,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: statusColor,
              ),
            ),
          ],
        ),
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor),
        ),
      ],
    );
  }

  Widget _buildProgressBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LinearProgressIndicator(
        value: jobStatus.overallProgress,
        minHeight: 8,
        backgroundColor: AppColors.textSecondary,
        valueColor: AlwaysStoppedAnimation<Color>(
          jobStatus.isFailed
              ? AppColors.error
              : jobStatus.isCompleted
              ? AppColors.success
              : AppColors.info,
        ),
      ),
    );
  }

  Widget _buildStageBreakdown() {
    final stages = ['transcription', 'credibility', 'dubbing', 'aggregation'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Stage Progress',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 12),
        ...stages.map(_buildStageItem),
      ],
    );
  }

  Widget _buildStageItem(String stageName) {
    final status = jobStatus.getStageStatus(stageName);
    final progress = jobStatus.getStageProgressPercent(stageName);

    var statusColor = AppColors.textSecondary;
    var statusIcon = '○';

    switch (status) {
      case StageStatus.pending:
        statusColor = AppColors.textSecondary;
        statusIcon = '○';
      case StageStatus.running:
        statusColor = AppColors.warning;
        statusIcon = '◑';
      case StageStatus.completed:
        statusColor = AppColors.success;
        statusIcon = '✓';
      case StageStatus.skipped:
        statusColor = AppColors.textSecondary;
        statusIcon = '—';
      case StageStatus.failed:
        statusColor = AppColors.error;
        statusIcon = '✗';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                statusIcon,
                style: TextStyle(color: statusColor, fontSize: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _getStageName(stageName),
                  style: TextStyle(color: statusColor),
                ),
              ),
              Text(
                '$progress%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress / 100,
              minHeight: 4,
              backgroundColor: AppColors.textSecondary,
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadata() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (jobStatus.eta != null)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('ETA:'),
              Text(
                _formatEta(jobStatus.eta!),
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        if (jobStatus.errorMessage != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error,
              border: Border.all(color: AppColors.error),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.error, color: AppColors.error, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    jobStatus.errorMessage!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (jobStatus.warnings.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...jobStatus.warnings.map(
            (warning) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning,
                border: Border.all(color: AppColors.warning),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: AppColors.warning, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      warning,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        if (!jobStatus.isCompleted && !jobStatus.isFailed)
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.close),
              label: const Text('Cancel'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: onCancel,
            ),
          ),
        if (jobStatus.isFailed) ...[
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
              ),
              onPressed: onRetry,
            ),
          ),
        ],
      ],
    );
  }

  String _getStageName(String stage) {
    switch (stage) {
      case 'transcription':
        return 'Transcription';
      case 'credibility':
        return 'Credibility Check';
      case 'dubbing':
        return 'Dubbing';
      case 'aggregation':
        return 'Aggregation';
      default:
        return stage;
    }
  }

  String _formatEta(int seconds) {
    if (seconds < 60) return '$seconds seconds';
    final minutes = seconds ~/ 60;
    if (minutes < 60) return '$minutes minutes';
    final hours = minutes ~/ 60;
    return '$hours hours';
  }
}

/// Content Verification Widget
class VerificationWidget extends StatelessWidget {
  const VerificationWidget({
    required this.verification,
    super.key,
    this.onRefresh,
  });
  final ContentVerification verification;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.textSecondary),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildVerificationHeader(),
          const SizedBox(height: 20),

          // Overall Score
          _buildScoreCard(),
          const SizedBox(height: 20),

          // Checklist
          _buildChecklistItems(),
          const SizedBox(height: 20),

          // Detailed Results
          if (verification.profanityCheck != null)
            _buildDetailedCheck(
              'Profanity Check',
              verification.profanityCheck,
            ),
          if (verification.contentSafetyCheck != null) ...[
            const SizedBox(height: 16),
            _buildDetailedCheck(
              'Content Safety',
              verification.contentSafetyCheck,
            ),
          ],
          if (verification.transcriptCheck != null) ...[
            const SizedBox(height: 16),
            _buildDetailedCheck(
              'Transcript Quality',
              verification.transcriptCheck,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVerificationHeader() {
    var statusColor = AppColors.info;
    var statusText = verification.status.value;

    switch (verification.status) {
      case VerificationStatus.approved:
        statusColor = AppColors.success;
        statusText = 'Approved';
      case VerificationStatus.rejected:
        statusColor = AppColors.error;
        statusText = 'Rejected';
      case VerificationStatus.needsReview:
        statusColor = AppColors.warning;
        statusText = 'Needs Review';
      case VerificationStatus.inProgress:
        statusColor = AppColors.info;
        statusText = 'In Progress';
      default:
        statusColor = AppColors.textSecondary;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Content Verification',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              statusText,
              style: TextStyle(
                fontSize: 14,
                color: statusColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        if (verification.status == VerificationStatus.inProgress)
          InkWell(
            onTap: onRefresh,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.info,
              ),
              child: const Icon(Icons.refresh, color: AppColors.info, size: 20),
            ),
          ),
      ],
    );
  }

  Widget _buildScoreCard() {
    final score = verification.getOverallScore();

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.info, AppColors.info],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Overall Score',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Text(
                '$score/100',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(
            width: 100,
            height: 100,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  child: CircularProgressIndicator(
                    value: score / 100,
                    backgroundColor: AppColors.textPrimary.withValues(
                      alpha: 0.3,
                    ),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.textPrimary,
                    ),
                    strokeWidth: 4,
                  ),
                ),
                Text(
                  '$score%',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistItems() {
    final checks = verification.checklist;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Verification Checklist',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 12),
        ...checks.entries.map((entry) {
          final item = entry.value;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                if (item.hasFailed)
                  const Icon(Icons.close, color: AppColors.error, size: 20)
                else if (item.isComplete)
                  const Icon(
                    Icons.check_circle,
                    color: AppColors.success,
                    size: 20,
                  )
                else
                  const Icon(
                    Icons.schedule,
                    color: AppColors.warning,
                    size: 20,
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name, style: const TextStyle(fontSize: 13)),
                      if (item.result != null)
                        Text(
                          item.result!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDetailedCheck(String title, dynamic checkResult) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.textSecondary),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          // Render based on type
          if (checkResult is ProfanityCheckResult)
            _buildProfanityDetails(checkResult)
          else if (checkResult is ContentSafetyCheckResult)
            _buildSafetyDetails(checkResult)
          else if (checkResult is TranscriptQualityCheckResult)
            _buildTranscriptDetails(checkResult),
        ],
      ),
    );
  }

  Widget _buildProfanityDetails(ProfanityCheckResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Severity:', style: TextStyle(fontSize: 12)),
            Text(
              '${(result.severity * 100).toInt()}%',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (result.detectedWords.isNotEmpty)
          Text(
            'Words detected: ${result.detectedWords.length}',
            style: const TextStyle(fontSize: 12, color: AppColors.error),
          ),
      ],
    );
  }

  Widget _buildSafetyDetails(ContentSafetyCheckResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Safety Score:', style: TextStyle(fontSize: 12)),
            Text(
              '${(result.safetyScore * 100).toInt()}%',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        if (result.flaggedCategories.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Flagged: ${result.flaggedCategories.join(", ")}',
            style: const TextStyle(fontSize: 12, color: AppColors.warning),
          ),
        ],
      ],
    );
  }

  Widget _buildTranscriptDetails(TranscriptQualityCheckResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Accuracy:', style: TextStyle(fontSize: 12)),
            Text(
              '${(result.accuracy * 100).toInt()}%',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
