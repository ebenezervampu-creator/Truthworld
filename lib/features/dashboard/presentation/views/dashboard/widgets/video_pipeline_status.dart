import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:get/get.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:truthworld/features/video/data/models/video.dart';

class VideoPipelineStatusWidget extends StatelessWidget {
  final Video video;
  final bool isDarkMode;
  final RxBool _isExpanded;

  VideoPipelineStatusWidget({
    super.key,
    required this.video,
    required this.isDarkMode,
  }) : _isExpanded = (video.status.name != 'ready').obs;

  String? _getThumbnailFileName(String url) {
    if (url.isEmpty) return null;
    try {
      if (url.startsWith('gs://')) {
        return url.split('/').last;
      }
      final uri = Uri.parse(url);
      final decodedPath = Uri.decodeComponent(uri.pathSegments.last);
      return decodedPath.split('/').last;
    } catch (e) {
      try {
        final base = url.split('?').first;
        final segments = base.split('%2F');
        if (segments.length > 1) {
          return segments.last;
        }
        return base.split('/').last;
      } catch (_) {
        return null;
      }
    }
  }

  Future<void> _launchURL(String urlString) async {
    if (urlString.isEmpty) return;
    try {
      final url = Uri.parse(urlString);
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Failed to launch URL: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final thumbnailFile = _getThumbnailFileName(video.thumbnailUrl);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('videos').doc(video.id).snapshots(),
      builder: (context, videoDocSnap) {
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: thumbnailFile != null
              ? FirebaseFirestore.instance.collection('image_verification').doc(thumbnailFile).snapshots()
              : Stream<DocumentSnapshot<Map<String, dynamic>>>.empty(),
          builder: (context, imageSnap) {
            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('resolution_jobs').doc(video.id).snapshots(),
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

                    // Video Content Moderation (Gemini Audio Analysis)
                    final moderationData = videoDocData?['moderation'] as Map<String, dynamic>?;
                    final moderationStatus = (moderationData?['status'] as String?)?.toUpperCase() ?? 'PENDING';
                    final moderationReason = moderationData?['reason'] as String?;
                    final moderationSummary = moderationData?['summary'] as String?;
                    final moderationCategories = (moderationData?['violationCategories'] as List<dynamic>?)?.cast<String>() ?? [];
                    final moderationTime = moderationData?['processingTimeMs'] as num?;

                    // Thumbnail Safety Verification (Vertex AI Vision)
                    final imageStatus = (imageDoc?['status'] as String?)?.toUpperCase() ?? 'PENDING';
                    final imageReason = imageDoc?['reason'] as String?;

                    // Resolution job status mapping
                    final variants = resolutionDoc?['variants'] as Map<String, dynamic>? ?? {};

                    // Pipeline timeline stages mapping from videoDoc
                    final stages = videoDocData?['stages'] as Map<String, dynamic>? ?? {};

                    return Obx(() {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? AppColors.bgSurface
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDarkMode
                                ? AppColors.bgDivider.withValues(alpha: 0.5)
                                : Colors.grey.shade300,
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
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                key: const Key('pipeline_header_row'),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.settings_suggest_outlined,
                                      color: isDarkMode ? AppColors.brand : Colors.deepPurple,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      "Processing Pipeline",
                                      style: GoogleFonts.roboto(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                                      ),
                                    ),
                                    const Spacer(),
                                    // Thumbnail Moderation Tag
                                    _buildMiniBadge(
                                      label: "Content: $moderationStatus",
                                      color: _getSafetyColor(moderationStatus),
                                    ),
                                    const SizedBox(width: 6),
                                    _buildMiniBadge(
                                      label: "Thumb: $imageStatus",
                                      color: _getSafetyColor(imageStatus),
                                    ),
                                    const SizedBox(width: 8),
                                    // Status Indicator
                                    _buildMiniBadge(
                                      label: video.status.name.toUpperCase(),
                                      color: video.status.name == 'ready'
                                          ? AppColors.success
                                          : (video.status.name == 'failed'
                                              ? AppColors.error
                                              : AppColors.warning),
                                    ),
                                    const SizedBox(width: 10),
                                    Icon(
                                      _isExpanded.value ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                                      color: isDarkMode ? AppColors.textSecondary : Colors.black54,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            
                            // Collapsible Body
                            AnimatedCrossFade(
                              firstChild: const SizedBox.shrink(),
                              secondChild: Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Divider(height: 16),
                                    
                                    // Section 1: Video Content Moderation (Gemini Audio Analysis)
                                    _buildSectionTitle("Video Content Moderation (Gemini)"),
                                    const SizedBox(height: 6),
                                    _buildModerationPanel(
                                      status: moderationStatus,
                                      reason: moderationReason,
                                      summary: moderationSummary,
                                      categories: moderationCategories,
                                      processingTimeMs: moderationTime?.toInt(),
                                    ),

                                    const SizedBox(height: 16),

                                    // Section 2: Thumbnail Safety Verification
                                    _buildSectionTitle("Thumbnail Safety Verification"),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(
                                          _getSafetyIcon(imageStatus),
                                          color: _getSafetyColor(imageStatus),
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          imageReason ?? "Awaiting safety checks from Vertex AI Vision...",
                                          style: GoogleFonts.roboto(
                                            fontSize: 13,
                                            color: isDarkMode ? AppColors.textSecondary : Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                    
                                    const SizedBox(height: 16),
                                    
                                    // Section 2: Adaptive Resolution Transcoding
                                    _buildSectionTitle("Resolution Transcoding (Adaptive HLS)"),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _buildResolutionChip("144p", variants["144p"]),
                                        _buildResolutionChip("240p", variants["240p"]),
                                        _buildResolutionChip("360p", variants["360p"]),
                                        _buildResolutionChip("480p", variants["480p"]),
                                        _buildResolutionChip("720p", variants["720p"]),
                                      ],
                                    ),
                                    
                                    const SizedBox(height: 16),
                                    
                                    // Section 3: AI Processing Timeline Stages
                                    _buildSectionTitle("AI Metadata & Pipeline Stages"),
                                    const SizedBox(height: 10),
                                    _buildPipelineTimeline(stages),
                                    
                                    // Section 4: Direct Links & Stored Artifacts (Only if ready)
                                    if (video.status.name == 'ready' || stages.isNotEmpty) ...[
                                      const SizedBox(height: 16),
                                      _buildSectionTitle("Direct Links & Stored Artifacts"),
                                      const SizedBox(height: 8),
                                      _buildArtifactLinksPanel(),
                                    ],

                                    // Section 5: Gemini Generated Summary (Low Latency Stored)
                                    if (video.description.isNotEmpty && video.status.name == 'ready') ...[
                                      const SizedBox(height: 16),
                                      _buildSectionTitle("Gemini Video Summary"),
                                      const SizedBox(height: 8),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: isDarkMode
                                              ? AppColors.bgSurfaceHover
                                              : Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          video.description,
                                          style: GoogleFonts.roboto(
                                            fontSize: 12.5,
                                            color: isDarkMode ? AppColors.textSecondary : Colors.black87,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              crossFadeState: _isExpanded.value ? CrossFadeState.showSecond : CrossFadeState.showFirst,
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

  /// Builds the Video Content Moderation panel showing Gemini audio analysis result.
  Widget _buildModerationPanel({
    required String status,
    String? reason,
    String? summary,
    List<String> categories = const [],
    int? processingTimeMs,
  }) {
    final color = _getSafetyColor(status);
    final icon = _getSafetyIcon(status);
    final isProcessing = status == 'PROCESSING';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
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
                Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isProcessing
                      ? "Analyzing audio against Community Guidelines..."
                      : (status == 'APPROVED'
                          ? "Content approved — complies with Community Guidelines"
                          : (status == 'REJECTED'
                              ? "Content rejected — violates Community Guidelines"
                              : "Awaiting content moderation...")),
                  style: GoogleFonts.roboto(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                  ),
                ),
              ),
              if (processingTimeMs != null)
                Text(
                  "${(processingTimeMs / 1000).toStringAsFixed(1)}s",
                  style: GoogleFonts.roboto(
                    fontSize: 10,
                    color: AppColors.textTertiary,
                  ),
                ),
            ],
          ),
          // Violation Categories (if rejected)
          if (categories.isNotEmpty && status == 'REJECTED') ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: categories.map((cat) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    cat.replaceAll('_', ' ').toUpperCase(),
                    style: GoogleFonts.roboto(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: AppColors.error,
                      letterSpacing: 0.5,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          // Reason (if rejected)
          if (reason != null && reason.isNotEmpty && status == 'REJECTED') ...[
            const SizedBox(height: 6),
            Text(
              reason,
              style: GoogleFonts.roboto(
                fontSize: 11.5,
                color: AppColors.error,
                height: 1.3,
              ),
            ),
          ],
          // Summary (if approved)
          if (summary != null && summary.isNotEmpty && status == 'APPROVED') ...[
            const SizedBox(height: 6),
            Text(
              summary,
              style: GoogleFonts.roboto(
                fontSize: 11.5,
                color: isDarkMode ? AppColors.textSecondary : Colors.black87,
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
      style: GoogleFonts.roboto(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: isDarkMode ? AppColors.textTertiary : Colors.grey.shade700,
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
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Text(
        label,
        style: GoogleFonts.roboto(
          fontSize: 10,
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
      case 'FLAGGED':
        return Icons.warning_amber_rounded;
      case 'PENDING':
      default:
        return Icons.hourglass_empty_rounded;
    }
  }

  Widget _buildResolutionChip(String label, dynamic variantData) {
    final status = (variantData is Map) ? (variantData['status'] as String? ?? 'pending') : 'pending';
    
    Color chipColor;
    IconData icon;
    
    switch (status) {
      case 'completed':
        chipColor = AppColors.success;
        icon = Icons.check_circle_outline_rounded;
        break;
      case 'processing':
        chipColor = AppColors.brand;
        icon = Icons.sync_rounded;
        break;
      case 'failed':
        chipColor = AppColors.error;
        icon = Icons.error_outline_rounded;
        break;
      case 'pending':
      default:
        chipColor = AppColors.textTertiary;
        icon = Icons.radio_button_unchecked_rounded;
        break;
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
          Icon(icon, size: 12, color: chipColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.roboto(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? AppColors.textPrimary : Colors.black87,
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
            leadingWidget = const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 16);
            break;
          case 'running':
            itemColor = AppColors.brand;
            leadingWidget = const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brand),
            );
            break;
          case 'failed':
            itemColor = AppColors.error;
            leadingWidget = const Icon(Icons.error_rounded, color: AppColors.error, size: 16);
            break;
          case 'skipped':
            itemColor = AppColors.textTertiary;
            leadingWidget = const Icon(Icons.skip_next_rounded, color: AppColors.textTertiary, size: 16);
            break;
          case 'pending':
          default:
            itemColor = AppColors.textTertiary;
            leadingWidget = const Icon(Icons.radio_button_unchecked_rounded, color: AppColors.textTertiary, size: 14);
            break;
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: [
              SizedBox(width: 24, child: Center(child: leadingWidget)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.roboto(
                    fontSize: 12.5,
                    fontWeight: status == 'running' ? FontWeight.bold : FontWeight.normal,
                    color: status == 'pending'
                        ? AppColors.textTertiary
                        : (isDarkMode ? AppColors.textPrimary : Colors.black87),
                  ),
                ),
              ),
              if (status == 'running') ...[
                const SizedBox(width: 8),
                Text(
                  "${progress.toInt()}%",
                  style: GoogleFonts.roboto(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brand,
                  ),
                ),
              ] else ...[
                Text(
                  status.toUpperCase(),
                  style: GoogleFonts.roboto(
                    fontSize: 10,
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
        // Grid of Download actions
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // 1. Transcription jsonUrl
            if (video.transcriptionUrl.isNotEmpty)
              _buildActionButton(
                icon: Icons.description_outlined,
                label: "Transcript JSON",
                onPressed: () => _launchURL(video.transcriptionUrl),
              ),
            // 2. Factchecking report Url
            if (video.factCheckUrl.isNotEmpty)
              _buildActionButton(
                icon: Icons.fact_check_outlined,
                label: "Fact-Check Report",
                onPressed: () => _launchURL(video.factCheckUrl),
              ),
            // 3. Subtitles
            if (video.mediaSubtitles.isNotEmpty)
              ...video.mediaSubtitles.entries.map((entry) {
                return _buildActionButton(
                  icon: Icons.subtitles_outlined,
                  label: "SRT/VTT (${entry.key.toUpperCase()})",
                  onPressed: () => _launchURL(entry.value),
                );
              }),
            // 4. Audio Tracks / Dubs
            if (video.audioTracks.isNotEmpty)
              ...video.audioTracks.entries.map((entry) {
                return _buildActionButton(
                  icon: Icons.audiotrack_outlined,
                  label: "Audio (${entry.key.toUpperCase()})",
                  onPressed: () => _launchURL(entry.value),
                );
              }),
            // 5. Resolution variants
            if (video.resolutions.isNotEmpty)
              ...video.adaptiveResolutions.map((res) {
                return _buildActionButton(
                  icon: Icons.hd_outlined,
                  label: "${res.label} Direct Link",
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
        backgroundColor: isDarkMode
            ? AppColors.bgSurfaceHover
            : Colors.grey.shade200,
        foregroundColor: isDarkMode ? AppColors.textPrimary : Colors.black87,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(
            color: isDarkMode
                ? AppColors.bgDivider.withValues(alpha: 0.4)
                : Colors.grey.shade300,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: isDarkMode ? AppColors.brand : Colors.deepPurple),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.roboto(
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
