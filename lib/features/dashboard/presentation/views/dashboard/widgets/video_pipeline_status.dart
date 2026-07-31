import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/video_management.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

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

  Future<void> _launchURL(String urlString) async {
    if (urlString.isEmpty) return;
    try {
      final url = Uri.parse(urlString);
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } on Object catch (e) {
      debugPrint('Failed to launch URL: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final thumbnailFile = _getThumbnailFileName(video.thumbnailUrl);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('videos')
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
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('video_jobs')
                      .where('videoId', isEqualTo: video.id)
                      .limit(1)
                      .snapshots(),
                  builder: (context, jobsSnap) {
                    final videoDocData = videoDocSnap.data?.data();
                    final imageDoc = imageSnap.data?.data();
                    final resolutionDoc = resolutionSnap.data?.data();

                    // Video Content Moderation (Gemini v3.0 Intent-Aware Analysis)
                    final moderationData =
                        videoDocData?['moderation'] as Map<String, dynamic>?;
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
                    final moderationTopic = moderationData?['topic'] as String?;
                    final moderationIntent =
                        moderationData?['intent'] as String?;
                    final moderationRiskLevel =
                        moderationData?['riskLevel'] as String?;
                    final moderationExplanation =
                        moderationData?['explanation'] as String?;

                    // Thumbnail Safety Verification (Vertex AI Vision)
                    final imageStatus =
                        (imageDoc?['status'] as String?)?.toUpperCase() ??
                        'PENDING';
                    final imageReason = imageDoc?['reason'] as String?;

                    // Resolution job status mapping
                    final variants =
                        resolutionDoc?['variants'] as Map<String, dynamic>? ??
                        {};

                    // Pipeline timeline stages mapping from videoDoc
                    final stages =
                        videoDocData?['stages'] as Map<String, dynamic>? ?? {};

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
                                          color: _getSafetyColor(
                                            moderationStatus,
                                          ),
                                        ),
                                        _buildMiniBadge(
                                          label: 'Thumb: $imageStatus',
                                          color: _getSafetyColor(imageStatus),
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

                                    // Section 1: Video Content Moderation (Gemini Audio Analysis)
                                    _buildSectionTitle(
                                      'Video Content Moderation (Gemini)',
                                    ),
                                    const SizedBox(height: 6),
                                    _buildModerationPanel(
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
                                          _getSafetyIcon(imageStatus),
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

                                    // Section 2: Adaptive Resolution Transcoding
                                    _buildSectionTitle(
                                      'Resolution Transcoding (Adaptive HLS)',
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _buildResolutionChip(
                                          '144p',
                                          variants['144p'],
                                        ),
                                        _buildResolutionChip(
                                          '240p',
                                          variants['240p'],
                                        ),
                                        _buildResolutionChip(
                                          '360p',
                                          variants['360p'],
                                        ),
                                        _buildResolutionChip(
                                          '480p',
                                          variants['480p'],
                                        ),
                                        _buildResolutionChip(
                                          '720p',
                                          variants['720p'],
                                        ),
                                        _buildResolutionChip(
                                          '1040p',
                                          variants['1040p'],
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 16),

                                    // Section 3: AI Processing Timeline Stages
                                    _buildSectionTitle(
                                      'AI Metadata & Pipeline Stages',
                                    ),
                                    const SizedBox(height: 10),
                                    _buildPipelineTimeline(stages),

                                    // Section 4: Direct Links & Stored Artifacts (Only if ready)
                                    if (video.status.name == 'ready' ||
                                        stages.isNotEmpty) ...[
                                      const SizedBox(height: 16),
                                      _buildSectionTitle(
                                        'Direct Links & Stored Artifacts',
                                      ),
                                      const SizedBox(height: 8),
                                      _buildArtifactLinksPanel(),
                                    ],

                                    // Section 5: Gemini Generated Summary (Low Latency Stored)
                                    if (video.description.isNotEmpty &&
                                        video.status.name == 'ready') ...[
                                      const SizedBox(height: 16),
                                      _buildSectionTitle(
                                        'Gemini Video Summary',
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AppColors.bgSurfaceHover,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          video.description,
                                          style: AppTextStyles.bodyMedium
                                              .copyWith(
                                                fontSize: 13,
                                                color: AppColors.textSecondary,
                                                height: 1.4,
                                              ),
                                        ),
                                      ),
                                    ],

                                    const SizedBox(height: 16),
                                    _buildGenerateAIButton(context),
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

  /// Builds the Video Content Moderation panel showing Gemini v3.0 intent-aware analysis.
  Widget _buildModerationPanel({
    required String status,
    String? reason,
    String? summary,
    List<String> categories = const [],
    int? processingTimeMs,
    String? topic,
    String? intent,
    String? riskLevel,
    String? explanation,
  }) {
    final color = _getSafetyColor(status);
    final icon = _getSafetyIcon(status);
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
                  '${(processingTimeMs / 1000).toStringAsFixed(1)}s',
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
                    label: topic.replaceAll('_', ' '),
                    color: AppColors.brand,
                    prefix: 'Topic',
                  ),
                if (intent != null)
                  _buildInfoChip(
                    label: intent.replaceAll('_', ' '),
                    color: _getIntentColor(intent),
                    prefix: 'Intent',
                  ),
                if (riskLevel != null)
                  _buildInfoChip(
                    label: riskLevel.toUpperCase(),
                    color: _getRiskColor(riskLevel),
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
              reason.isNotEmpty &&
              (status == 'REJECTED' ||
                  isManualReview ||
                  status == 'ERROR')) ...[
            const SizedBox(height: 6),
            Text(
              reason,
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
              explanation.isNotEmpty &&
              status != 'ERROR') ...[
            const SizedBox(height: 4),
            Text(
              explanation,
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
              summary.isNotEmpty &&
              status == 'APPROVED') ...[
            const SizedBox(height: 6),
            Text(
              summary,
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

  Color _getSafetyColor(String status) {
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

  IconData _getSafetyIcon(String status) {
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

  Color _getIntentColor(String intent) {
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

  Color _getRiskColor(String riskLevel) {
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

  Widget _buildResolutionChip(String label, dynamic variantData) {
    final status = (variantData is Map)
        ? (variantData['status'] as String? ?? 'pending')
        : 'pending';

    Color chipColor;
    IconData icon;

    switch (status) {
      case 'completed':
        chipColor = AppColors.success;
        icon = Icons.check_circle_outline_rounded;
      case 'processing':
        chipColor = AppColors.brand;
        icon = Icons.sync_rounded;
      case 'failed':
        chipColor = AppColors.error;
        icon = Icons.error_outline_rounded;
      case 'pending':
      default:
        chipColor = AppColors.textTertiary;
        icon = Icons.radio_button_unchecked_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: chipColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPipelineTimeline(Map<String, dynamic> stages) {
    final orderedStages = [
      {'key': 'moderation', 'label': 'Content Moderation (Gemini)'},
      {'key': 'upload', 'label': 'Upload Source'},
      {'key': 'validation', 'label': 'Safety & Format Check'},
      {'key': 'transcription', 'label': 'Transcription (Gemini)'},
      {'key': 'credibility', 'label': 'Factcheck (Verify)'},
      {'key': 'dubbing', 'label': 'Localization (Dubbing)'},
      {'key': 'rendering', 'label': 'Rendering Output'},
      {'key': 'aggregation', 'label': 'Aggregation & Finish'},
    ];

    return Column(
      children: orderedStages.map((stage) {
        final key = stage['key']!;
        final label = stage['label']!;
        final stageData = stages[key] as Map<String, dynamic>?;
        final status = stageData?['status'] as String? ?? 'pending';
        final progress = stageData?['progress'] as num? ?? 0;

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

  Widget _buildArtifactLinksPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (video.transcriptionUrl.isNotEmpty)
              _buildActionButton(
                icon: Icons.description_outlined,
                label: 'Transcript JSON',
                onPressed: () => _launchURL(video.transcriptionUrl),
              ),
            if (video.factCheckUrl.isNotEmpty)
              _buildActionButton(
                icon: Icons.fact_check_outlined,
                label: 'Fact-Check Report',
                onPressed: () => _launchURL(video.factCheckUrl),
              ),
            if (video.mediaSubtitles.isNotEmpty)
              ...video.mediaSubtitles.entries.map((entry) {
                return _buildActionButton(
                  icon: Icons.subtitles_outlined,
                  label: 'SRT/VTT (${entry.key.toUpperCase()})',
                  onPressed: () => _launchURL(entry.value),
                );
              }),
            if (video.audioTracks.isNotEmpty)
              ...video.audioTracks.entries.map((entry) {
                return _buildActionButton(
                  icon: Icons.audiotrack_outlined,
                  label: 'Audio (${entry.key.toUpperCase()})',
                  onPressed: () => _launchURL(entry.value),
                );
              }),
            if (video.resolutions.isNotEmpty)
              ...video.adaptiveResolutions.map((res) {
                return _buildActionButton(
                  icon: Icons.hd_outlined,
                  label: '${res.label} Direct Link',
                  onPressed: () => _launchURL(res.url),
                );
              }),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.bgSurfaceHover,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(
            color: AppColors.bgDivider,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerateAIButton(BuildContext context) {
    final controller = Get.isRegistered<VideoManagementController>()
        ? Get.find<VideoManagementController>()
        : Get.put(VideoManagementController());

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.brand,
          side: const BorderSide(color: AppColors.brand, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        icon: const Icon(
          Icons.auto_awesome_rounded,
          size: 18,
          color: Colors.white,
        ),
        label: Text(
          'Generate / Add AI Features (Telugu, Hindi, Dubbing, Factcheck...)',
          style: AppTextStyles.labelMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.brand,
          ),
        ),
        onPressed: () {
          _showGenerateAIFeaturesQuickModal(context, video, controller);
        },
      ),
    );
  }

  void _showGenerateAIFeaturesQuickModal(
    BuildContext context,
    Video video,
    VideoManagementController controller,
  ) {
    final selectedLangs = <String>{'te', 'hi'}.obs;
    final selectedFeatures = <String>{
      'subtitles',
      'dubbing',
      'factcheck',
      'summary',
      'chapters',
    }.obs;
    final isAccuracyMode = true.obs;

    final availableLangs = [
      {'code': 'te', 'name': 'Telugu (తెలుగు)'},
      {'code': 'hi', 'name': 'Hindi (हिन्दी)'},
      {'code': 'en', 'name': 'English'},
      {'code': 'ta', 'name': 'Tamil (தமிழ்)'},
      {'code': 'kn', 'name': 'Kannada (ಕನ್ನಡ)'},
      {'code': 'ml', 'name': 'Malayalam (മലയാളം)'},
      {'code': 'es', 'name': 'Spanish'},
    ];

    Get.dialog<void>(
      Dialog(
        backgroundColor: AppColors.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.bgDivider),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Obx(
                () => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'On-Demand AI Features',
                            style: AppTextStyles.titleLarge.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 18,
                          ),
                          onPressed: Get.back<void>,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Target Languages',
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: availableLangs.map((lang) {
                        final code = lang['code']!;
                        final name = lang['name']!;
                        final isSelected = selectedLangs.contains(code);
                        return FilterChip(
                          label: Text(name),
                          selected: isSelected,
                          selectedColor: AppColors.brand.withValues(alpha: 0.2),
                          checkmarkColor: Colors.white,
                          labelStyle: AppTextStyles.labelMedium.copyWith(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? AppColors.brand
                                : AppColors.textPrimary,
                          ),
                          onSelected: (val) {
                            if (val) {
                              selectedLangs.add(code);
                            } else if (selectedLangs.length > 1) {
                              selectedLangs.remove(code);
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'AI Features',
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    CheckboxListTile(
                      value: selectedFeatures.contains('subtitles'),
                      activeColor: AppColors.brand,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Subtitles (SRT/VTT)',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        'Generate captions in target languages',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      onChanged: (val) => (val ?? false)
                          ? selectedFeatures.add('subtitles')
                          : selectedFeatures.remove('subtitles'),
                    ),
                    CheckboxListTile(
                      value: selectedFeatures.contains('dubbing'),
                      activeColor: AppColors.brand,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Audio Dubbing Tracks',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        'Generate voice audio in Telugu, Hindi, etc.',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      onChanged: (val) => (val ?? false)
                          ? selectedFeatures.add('dubbing')
                          : selectedFeatures.remove('dubbing'),
                    ),
                    CheckboxListTile(
                      value: selectedFeatures.contains('factcheck'),
                      activeColor: AppColors.brand,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Fact-Checking Report',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        'Extract claims and truth score',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      onChanged: (val) => (val ?? false)
                          ? selectedFeatures.add('factcheck')
                          : selectedFeatures.remove('factcheck'),
                    ),
                    CheckboxListTile(
                      value: selectedFeatures.contains('summary'),
                      activeColor: AppColors.brand,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'AI Video Summary',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        'Generate smart video summary',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      onChanged: (val) => (val ?? false)
                          ? selectedFeatures.add('summary')
                          : selectedFeatures.remove('summary'),
                    ),
                    CheckboxListTile(
                      value: selectedFeatures.contains('chapters'),
                      activeColor: AppColors.brand,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Auto-Chapters',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        'Generate timestamped section breaks',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      onChanged: (val) => (val ?? false)
                          ? selectedFeatures.add('chapters')
                          : selectedFeatures.remove('chapters'),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: Get.back<void>,
                          child: Text(
                            'Cancel',
                            style: AppTextStyles.buttonText.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brand,
                            foregroundColor: AppColors.textPrimary,
                          ),
                          icon: const Icon(
                            Icons.bolt_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                          label: Text(
                            'Generate AI Features',
                            style: AppTextStyles.buttonText.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: selectedFeatures.isEmpty
                              ? null
                              : () {
                                  Get.back<void>();
                                  controller.triggerAIFeatures(
                                    videoId: video.id,
                                    features: selectedFeatures.toList(),
                                    targetLanguages: selectedLangs.toList(),
                                    priorityMode: isAccuracyMode.value
                                        ? 'accuracy'
                                        : 'speed',
                                    autoChapters: selectedFeatures.contains(
                                      'chapters',
                                    ),
                                  );
                                },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
