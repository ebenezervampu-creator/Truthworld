import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/widgets/pipeline/pipeline_components.dart';
import 'package:truthworld/features/video/data/models/video.dart';
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
                return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('video_jobs')
                      .doc(video.id)
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

                                    // Section 6: Video Verification Summary
                                    if (video.description.isNotEmpty &&
                                        video.status.name == 'ready') ...[
                                      const SizedBox(height: 16),
                                      _buildSectionTitle(
                                        'Video Verification Summary',
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
}
