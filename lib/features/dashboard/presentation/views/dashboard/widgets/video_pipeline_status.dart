import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/ux/user_feedback_sanitizer.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/video_management.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/widgets/pipeline/pipeline_components.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/models/video_media.dart';
import 'package:truthworld/features/video/data/services/video_media_service.dart';
import 'package:truthworld/features/video/presentation/widgets/fact_check_report_widget.dart';
import 'package:truthworld/theme/app_theme.dart';

export 'package:truthworld/features/dashboard/presentation/views/dashboard/widgets/pipeline/pipeline_components.dart';

/// Coordinator widget displaying the complete multi-stage processing pipeline
/// status for a creator video.
class VideoPipelineStatusWidget extends StatelessWidget {
  VideoPipelineStatusWidget({
    required this.video,
    required this.isDarkMode,
    this.initiallyExpanded = false,
    super.key,
  }) : _isExpanded = (initiallyExpanded || video.status.name != 'ready').obs;

  final Video video;
  final bool isDarkMode;
  final bool initiallyExpanded;
  final RxBool _isExpanded;

  String? _getThumbnailFileName(String url) {
    if (url.isEmpty) return null;
    try {
      if (url.startsWith('gs://')) {
        return url.split('/').last;
      }
      final uri = Uri.parse(url);
      final decodedPath = Uri.decodeComponent(uri.pathSegments.last);
      return decodedPath.split('/').last;
    } on Object catch (_) {
      try {
        final base = url.split('?').first;
        final segments = base.split('%2F');
        if (segments.length > 1) {
          return segments.last;
        }
        return base.split('/').last;
      } on Object catch (_) {
        return null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final thumbnailFile = _getThumbnailFileName(video.thumbnailUrl);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(FirestoreCollections.videos)
          .doc(video.id)
          .snapshots(),
      builder: (context, videoDocSnap) {
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: thumbnailFile != null
              ? FirebaseFirestore.instance
                    .collection('image_verification')
                    .doc(thumbnailFile)
                    .snapshots()
              : const Stream<DocumentSnapshot<Map<String, dynamic>>>.empty(),
          builder: (context, imageSnap) {
            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('resolution_jobs')
                  .doc(video.id)
                  .snapshots(),
              builder: (context, resolutionSnap) {
                final videoDocData = videoDocSnap.data?.data();
                final resolvedJobId = video.jobId?.isNotEmpty == true
                    ? video.jobId!
                    : ((videoDocData?['jobId'] as String?)?.isNotEmpty == true
                        ? videoDocData!['jobId'] as String
                        : video.id);

                return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('video_jobs')
                      .doc(resolvedJobId)
                      .snapshots(),
                  builder: (context, jobDocSnap) {
                    final videoDocData = videoDocSnap.data?.data();
                    final imageDoc = imageSnap.data?.data();
                    final resolutionDoc = resolutionSnap.data?.data();
                    final jobDocData = jobDocSnap.data?.data();

                    final jobStages =
                        (jobDocData?['stages'] as Map<String, dynamic>?) ?? {};
                    final videoStages =
                        (videoDocData?['stages'] as Map<String, dynamic>?) ?? {};
                    final stages = {...videoStages, ...jobStages};

                    // Video Content Moderation
                    final moderationData =
                        (jobDocData?['moderation'] as Map<String, dynamic>?) ??
                            (videoDocData?['moderation']
                                as Map<String, dynamic>?) ??
                            (stages['moderation'] as Map<String, dynamic>?);
                    final moderationStatus =
                        (moderationData?['status'] as String?)?.toUpperCase() ??
                        'PENDING';
                    final moderationReason =
                        moderationData?['policyReason'] as String? ??
                        moderationData?['reason'] as String?;
                    final moderationSummary =
                        moderationData?['summary'] as String?;
                    final moderationCategories =
                        (moderationData?['violationCategories']
                                as List<dynamic>?)
                            ?.cast<String>() ??
                        [];
                    final moderationTime =
                        moderationData?['processingTimeMs'] as num?;
                    final moderationTopic =
                        moderationData?['topic'] as String?;
                    final moderationIntent =
                        moderationData?['intent'] as String?;
                    final moderationRiskLevel =
                        moderationData?['riskLevel'] as String?;
                    final moderationExplanation =
                        moderationData?['explanation'] as String?;

                    // Thumbnail Safety Verification
                    final imageStatus =
                        (imageDoc?['status'] as String?)?.toUpperCase() ??
                        'PENDING';
                    final imageReason = imageDoc?['reason'] as String?;

                    // Resolution variant status
                    final variants =
                        resolutionDoc?['variants'] as Map<String, dynamic>? ??
                        (jobDocData?['variants'] as Map<String, dynamic>?) ??
                        (jobDocData?['resolutions'] as Map<String, dynamic>?) ??
                        {};

                    return Obx(() {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.bgSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.bgDivider,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Row (Click to toggle expansion)
                            InkWell(
                              onTap: () {
                                _isExpanded.value = !_isExpanded.value;
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                key: const Key('pipeline_header_row'),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.tune_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Processing Pipeline',
                                            style: AppTextStyles.titleMedium
                                                .copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.textPrimary,
                                                ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(
                                          _isExpanded.value
                                              ? Icons.expand_less_rounded
                                              : Icons.expand_more_rounded,
                                          color: Colors.white,
                                          size: 22,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        _buildMiniBadge(
                                          label: 'Content: $moderationStatus',
                                          color: getSafetyColor(
                                            moderationStatus,
                                          ),
                                        ),
                                        _buildMiniBadge(
                                          label: 'Thumb: $imageStatus',
                                          color: getSafetyColor(imageStatus),
                                        ),
                                        _buildMiniBadge(
                                          label:
                                              video.status.name ==
                                                  'pending_review'
                                              ? 'PENDING REVIEW'
                                              : video.status.name.toUpperCase(),
                                          color: video.status.name == 'ready'
                                              ? AppColors.success
                                              : (video.status.name == 'rejected'
                                                    ? AppColors.error
                                                    : (video.status.name ==
                                                              'pending_review'
                                                          ? AppColors.info
                                                          : (video
                                                                        .status
                                                                        .name ==
                                                                    'failed'
                                                                ? AppColors
                                                                      .error
                                                                : AppColors
                                                                      .warning))),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Collapsible Body
                            AnimatedCrossFade(
                              firstChild: const SizedBox.shrink(),
                              secondChild: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  0,
                                  12,
                                  12,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Divider(
                                      height: 16,
                                      color: AppColors.bgDivider,
                                    ),

                                    // Section 1: Video Content Moderation
                                    _buildSectionTitle(
                                      'Video Content Moderation (Verification System)',
                                    ),
                                    const SizedBox(height: 6),
                                    PipelineModerationPanel(
                                      status: moderationStatus,
                                      reason: moderationReason,
                                      summary: moderationSummary,
                                      categories: moderationCategories,
                                      processingTimeMs: moderationTime?.toInt(),
                                      topic: moderationTopic,
                                      intent: moderationIntent,
                                      riskLevel: moderationRiskLevel,
                                      explanation: moderationExplanation,
                                    ),

                                    const SizedBox(height: 16),

                                    // Section 2: Thumbnail Safety Verification
                                    _buildSectionTitle(
                                      'Thumbnail Safety Verification',
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(
                                          getSafetyIcon(imageStatus),
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            imageReason ??
                                                'Awaiting safety checks from Vertex AI Vision...',
                                            style: AppTextStyles.bodySmall
                                                .copyWith(
                                                  fontSize: 12,
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 16),

                                    // Section 3: Adaptive Resolution Transcoding
                                    _buildSectionTitle(
                                      'Resolution Transcoding (Adaptive HLS)',
                                    ),
                                    const SizedBox(height: 8),
                                    PipelineResolutionChips(
                                      variants: variants,
                                    ),

                                    const SizedBox(height: 16),

                                    // Section 4: AI Processing Timeline Stages
                                    _buildSectionTitle(
                                      'AI Metadata & Pipeline Stages',
                                    ),
                                    const SizedBox(height: 10),
                                    PipelineTimelineStages(
                                      stages: stages,
                                      video: video,
                                    ),

                                    // Section 5: Direct Links & Stored Artifacts (Only if ready)
                                    if (video.status.name == 'ready' ||
                                        stages.isNotEmpty) ...[
                                      const SizedBox(height: 16),
                                      _buildSectionTitle(
                                        'Direct Links & Stored Artifacts',
                                      ),
                                      const SizedBox(height: 8),
                                      PipelineArtifactLinksPanel(
                                        video: video,
                                      ),
                                    ],

                                    // Section 6: AI Verification & Fact-Checking Intelligence
                                    _buildVerificationIntelligenceSection(
                                      context,
                                      stages,
                                      jobDocData,
                                      videoDocData,
                                    ),

                                    // Section 7: Creator Video Description
                                    _buildCreatorDescriptionSection(),

                                    const SizedBox(height: 16),
                                    PipelineGenerateAIButton(
                                      video: video,
                                    ),
                                  ],
                                ),
                              ),
                              crossFadeState: _isExpanded.value
                                  ? CrossFadeState.showSecond
                                  : CrossFadeState.showFirst,
                              duration: const Duration(milliseconds: 250),
                            ),
                          ],
                        ),
                      );
                    });
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTextStyles.titleMedium.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: AppColors.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildMiniBadge({required String label, required Color color}) {
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
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildVerificationIntelligenceSection(
    BuildContext context,
    Map<String, dynamic> stages,
    Map<String, dynamic>? jobDocData,
    Map<String, dynamic>? videoDocData,
  ) {
    final transcriptionData = stages['transcription'] as Map<String, dynamic>?;
    final rawTranscriptionStatus =
        (transcriptionData?['status'] as String?)?.toLowerCase() ?? 'pending';
    final isTranscriptionFailed = rawTranscriptionStatus == 'failed';

    final credibilityData = stages['credibility'] as Map<String, dynamic>?;
    final rawCredibilityStatus =
        (credibilityData?['status'] as String?)?.toLowerCase() ?? 'pending';
    final isCredibilityRunning = rawCredibilityStatus == 'running' ||
        rawCredibilityStatus == 'in_progress' ||
        rawCredibilityStatus == 'processing';
    final isCredibilityFailed = rawCredibilityStatus == 'failed';

    final jobOutputs =
        (jobDocData?['outputs'] as Map<String, dynamic>?) ?? {};
    return StreamBuilder<VideoMediaCredibility>(
      stream: VideoMediaService().streamCredibility(video.id),
      builder: (context, credSnap) {
        final cred = credSnap.data ??
            VideoMediaService.credibilityCache[video.id] ??
            const VideoMediaCredibility();

        final hasRealFactCheckReport = cred.claims.isNotEmpty ||
            cred.factCheckUrl.isNotEmpty ||
            video.factCheckUrl.isNotEmpty ||
            (cred.uiReport != null &&
                (cred.uiReport!.keyClaims.isNotEmpty ||
                    cred.uiReport!.summary.rating != null)) ||
            (cred.factCheckStats != null &&
                cred.factCheckStats!.totalClaims > 0);

        final hasRealFactChecking = hasRealFactCheckReport ||
            (rawCredibilityStatus == 'completed' && cred.claims.isNotEmpty);

        final isSkippedOrNotRequested = rawCredibilityStatus == 'skipped' ||
            (rawCredibilityStatus == 'pending' &&
                (video.factCheckTier == 'none' ||
                    video.factCheckTier == 'off' ||
                    !video.isFactChecked));

        final hasCredibilityResults = !video.isNonCredibilityCategory &&
            (hasRealFactChecking ||
                (video.hasAiCredibility && !isSkippedOrNotRequested) ||
                (video.isFactChecked && !isSkippedOrNotRequested));

        final rawSummary = cred.summary.isNotEmpty
            ? cred.summary
            : UserFeedbackSanitizer.sanitizeVideoSummary(
                (videoDocData?['summary'] as String?) ?? '',
              );
        final hasRealAiSummary = rawSummary.isNotEmpty &&
            rawSummary.trim() != video.description.trim();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Row(
              children: [
                _buildSectionTitle('AI Fact-Checking & Credibility'),
                const Spacer(),
                if (isTranscriptionFailed && !hasRealFactChecking)
                  _buildMiniBadge(
                    label: 'Awaiting Transcript',
                    color: AppColors.warning,
                  )
                else if (rawCredibilityStatus == 'skipped' && !hasCredibilityResults)
                  _buildMiniBadge(
                    label: 'Not Requested',
                    color: AppColors.textTertiary,
                  )
                else if (hasCredibilityResults && cred.claims.isEmpty)
                  _buildMiniBadge(
                    label: 'Unassessed Claims',
                    color: AppColors.textTertiary,
                  )
                else if (hasCredibilityResults && cred.claims.isNotEmpty)
                  _buildMiniBadge(
                    label: '${cred.claims.length} Claims Verified',
                    color: AppColors.success,
                  )
                else if (isCredibilityRunning)
                  _buildMiniBadge(
                    label: 'Verifying Claims...',
                    color: AppColors.info,
                  )
                else if (isCredibilityFailed)
                  _buildMiniBadge(
                    label: 'Verification Interrupted',
                    color: AppColors.warning,
                  )
                else
                  _buildMiniBadge(
                    label: 'Not Checked',
                    color: AppColors.textTertiary,
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Case 1: Transcription Failed -> Fact-checking blocked
            if (isTranscriptionFailed && !hasRealFactChecking)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
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
                          Icons.warning_amber_rounded,
                          size: 18,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Speech Transcription Required for Fact-Checking',
                            style: AppTextStyles.labelMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'TruthWorld extracts and verifies claims directly from spoken audio transcripts. Because speech transcription did not complete, AI claim verification cannot run yet.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      icon: const Icon(
                        Icons.refresh_rounded,
                        size: 15,
                        color: Colors.white,
                      ),
                      label: Text(
                        'Retry Transcription & Fact-Checking',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () {
                        final controller =
                            Get.isRegistered<VideoManagementController>()
                                ? Get.find<VideoManagementController>()
                                : Get.put(VideoManagementController());
                        showGenerateAIFeaturesQuickModal(
                          context,
                          video,
                          controller,
                        );
                      },
                    ),
                  ],
                ),
              )
            // Case 2: Credibility In Progress
            else if (isCredibilityRunning)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.bgSurfaceHover,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.info.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Credibility Engine in Progress',
                            style: AppTextStyles.labelMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Extracting verifiable claims from the transcript and cross-referencing authoritative sources...',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            // Case 2.5: Credibility Interrupted / Degraded
            else if (isCredibilityFailed)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          size: 16,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Fact-Checking Interrupted',
                            style: AppTextStyles.labelMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      UserFeedbackSanitizer.sanitizeMessage(
                        (credibilityData?['suggestedRemedy'] as String?) ??
                            (credibilityData?['error'] as String?) ??
                            'We encountered a temporary interruption while verifying claims. Tap below to retry.',
                      ),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      icon: const Icon(
                        Icons.refresh_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                      label: Text(
                        'Retry Fact-Check',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () {
                        final controller =
                            Get.isRegistered<VideoManagementController>()
                                ? Get.find<VideoManagementController>()
                                : Get.put(VideoManagementController());
                        showGenerateAIFeaturesQuickModal(
                          context,
                          video,
                          controller,
                        );
                      },
                    ),
                  ],
                ),
              )
            // Case 3: Genuine Fact-Checking Results Available
            else if (hasCredibilityResults)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.bgSurfaceHover,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.bgDivider,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasRealAiSummary) ...[
                      Row(
                        children: [
                          const Icon(
                            Icons.auto_awesome_rounded,
                            size: 15,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'AI Verification Summary',
                            style: AppTextStyles.labelSmall.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        rawSummary,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (cred.claims.isNotEmpty)
                          _buildMiniBadge(
                            label: '${cred.claims.length} Claims Evaluated',
                            color: Colors.white70,
                          ),
                        if (cred.sources.isNotEmpty)
                          _buildMiniBadge(
                            label: '${cred.sources.length} Verified Sources',
                            color: Colors.white70,
                          ),
                        if (cred.trustLabel != null &&
                            cred.trustLabel!.isNotEmpty)
                          _buildMiniBadge(
                            label: cred.trustLabel!,
                            color: cred.trustLabel!.toLowerCase().contains('verified') || cred.trustLabel!.toLowerCase().contains('reliable') ? AppColors.success : AppColors.warning,
                          ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      icon: const Icon(
                        Icons.analytics_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                      label: Text(
                        'View Full Fact-Check Report',
                        style: AppTextStyles.labelMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      onPressed: () {
                        final factData = cred.toMap();
                        
                        Get.bottomSheet(
                          FactCheckReportWidget(
                            data: factData,
                            video: video,
                          ),
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                        );
                      },
                    ),
                  ],
                ),
              )
            // Case 4: Not yet run
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.bgSurfaceHover,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No Fact-Check Report Generated Yet',
                      style: AppTextStyles.labelMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Generate on-demand AI fact-checking to extract claims and verify authenticity against trusted sources.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      icon: const Icon(
                        Icons.fact_check_rounded,
                        size: 15,
                        color: Colors.white,
                      ),
                      label: Text(
                        'Run On-Demand Fact-Check',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () {
                        final controller =
                            Get.isRegistered<VideoManagementController>()
                                ? Get.find<VideoManagementController>()
                                : Get.put(VideoManagementController());
                        showGenerateAIFeaturesQuickModal(
                          context,
                          video,
                          controller,
                        );
                      },
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildCreatorDescriptionSection() {
    if (video.description.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        _buildSectionTitle('Creator Video Description'),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.bgSurfaceHover,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                video.description,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Provided by creator at upload',
                style: AppTextStyles.labelSmall.copyWith(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

