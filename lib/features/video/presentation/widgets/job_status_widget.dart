import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/features/video/data/models/pipeline_status.dart';
import 'package:truthworld/features/video/data/models/content_verification.dart';


/// Job Status Widget - Displays real-time pipeline processing status
class JobStatusWidget extends StatelessWidget {
  final PipelineJobStatus jobStatus;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;
  final bool showActions;

  const JobStatusWidget({
    super.key,
    required this.jobStatus,
    this.onCancel,
    this.onRetry,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: EdgeInsets.all(16),
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
            style: GoogleFonts.roboto(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.blue,
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
    Color statusColor = Colors.blue;
    String statusText = jobStatus.currentStageName;

    if (jobStatus.isCompleted) {
      statusColor = Colors.green;
      statusText = 'Completed';
    } else if (jobStatus.isFailed) {
      statusColor = Colors.red;
      statusText = 'Failed';
    } else if (jobStatus.isProcessing) {
      statusColor = Colors.orange;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Job ID: ${jobStatus.jobId.substring(0, 8)}...',
              style: GoogleFonts.roboto(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Text(
              statusText,
              style: GoogleFonts.roboto(
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
        backgroundColor: Colors.grey[200],
        valueColor: AlwaysStoppedAnimation<Color>(
          jobStatus.isFailed
              ? Colors.red
              : jobStatus.isCompleted
              ? Colors.green
              : Colors.blue,
        ),
      ),
    );
  }

  Widget _buildStageBreakdown() {
    final stages = ['transcription', 'credibility', 'dubbing', 'aggregation'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Stage Progress',
          style: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 12),
        ...stages.map((stage) => _buildStageItem(stage)),
      ],
    );
  }

  Widget _buildStageItem(String stageName) {
    final status = jobStatus.getStageStatus(stageName);
    final progress = jobStatus.getStageProgressPercent(stageName);

    Color statusColor = Colors.grey;
    String statusIcon = '○';

    switch (status) {
      case StageStatus.pending:
        statusColor = Colors.grey;
        statusIcon = '○';
        break;
      case StageStatus.running:
        statusColor = Colors.orange;
        statusIcon = '◑';
        break;
      case StageStatus.completed:
        statusColor = Colors.green;
        statusIcon = '✓';
        break;
      case StageStatus.skipped:
        statusColor = Colors.grey;
        statusIcon = '—';
        break;
      case StageStatus.failed:
        statusColor = Colors.red;
        statusIcon = '✗';
        break;
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
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
                style: GoogleFonts.roboto(
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
              backgroundColor: Colors.grey[200],
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
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        if (jobStatus.errorMessage != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              border: Border.all(color: Colors.red.shade200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.error, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    jobStatus.errorMessage!,
                    style: GoogleFonts.roboto(
                      fontSize: 12,
                      color: Colors.red.shade700,
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
              margin: EdgeInsets.only(bottom: 8),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                border: Border.all(color: Colors.amber.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      warning,
                      style: GoogleFonts.roboto(
                        fontSize: 12,
                        color: Colors.amber.shade700,
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
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: onCancel,
            ),
          ),
        if (jobStatus.isFailed) ...[
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
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
  final ContentVerification verification;
  final VoidCallback? onRefresh;

  const VerificationWidget({
    super.key,
    required this.verification,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: EdgeInsets.all(16),
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
              verification.profanityCheck!,
            ),
          if (verification.contentSafetyCheck != null) ...[
            const SizedBox(height: 16),
            _buildDetailedCheck(
              'Content Safety',
              verification.contentSafetyCheck!,
            ),
          ],
          if (verification.transcriptCheck != null) ...[
            const SizedBox(height: 16),
            _buildDetailedCheck(
              'Transcript Quality',
              verification.transcriptCheck!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVerificationHeader() {
    Color statusColor = Colors.blue;
    String statusText = verification.status.value;

    switch (verification.status) {
      case VerificationStatus.approved:
        statusColor = Colors.green;
        statusText = 'Approved';
        break;
      case VerificationStatus.rejected:
        statusColor = Colors.red;
        statusText = 'Rejected';
        break;
      case VerificationStatus.needsReview:
        statusColor = Colors.orange;
        statusText = 'Needs Review';
        break;
      case VerificationStatus.inProgress:
        statusColor = Colors.blue;
        statusText = 'In Progress';
        break;
      default:
        statusColor = Colors.grey;
        break;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Content Verification',
              style: GoogleFonts.roboto(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              statusText,
              style: GoogleFonts.roboto(
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
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.shade50,
              ),
              child: Icon(Icons.refresh, color: Colors.blue, size: 20),
            ),
          ),
      ],
    );
  }

  Widget _buildScoreCard() {
    final score = verification.getOverallScore();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade400, Colors.blue.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Overall Score',
                style: GoogleFonts.roboto(fontSize: 14, color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Text(
                '$score/100',
                style: GoogleFonts.roboto(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
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
                    backgroundColor: Colors.white.withValues(alpha: 0.3),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                    strokeWidth: 4,
                  ),
                ),
                Text(
                  '$score%',
                  style: GoogleFonts.roboto(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
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
        Text(
          'Verification Checklist',
          style: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 12),
        ...checks.entries.map((entry) {
          final item = entry.value;
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                if (item.hasFailed)
                  const Icon(Icons.close, color: Colors.red, size: 20)
                else if (item.isComplete)
                  const Icon(Icons.check_circle, color: Colors.green, size: 20)
                else
                  const Icon(Icons.schedule, color: Colors.orange, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name, style: GoogleFonts.roboto(fontSize: 13)),
                      if (item.result != null)
                        Text(
                          item.result!,
                          style: GoogleFonts.roboto(
                            fontSize: 11,
                            color: Colors.grey[600],
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
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.roboto(
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
            Text('Severity:', style: GoogleFonts.roboto(fontSize: 12)),
            Text(
              '${(result.severity * 100).toInt()}%',
              style: GoogleFonts.roboto(
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
            style: GoogleFonts.roboto(fontSize: 12, color: Colors.red),
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
            Text('Safety Score:', style: GoogleFonts.roboto(fontSize: 12)),
            Text(
              '${(result.safetyScore * 100).toInt()}%',
              style: GoogleFonts.roboto(
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
            style: GoogleFonts.roboto(fontSize: 12, color: Colors.orange),
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
            Text('Accuracy:', style: GoogleFonts.roboto(fontSize: 12)),
            Text(
              '${(result.accuracy * 100).toInt()}%',
              style: GoogleFonts.roboto(
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





