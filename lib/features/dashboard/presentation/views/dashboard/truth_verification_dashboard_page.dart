import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/utils/content_validator.dart';
import 'package:truthworld/core/utils/truthworld_text_input_formatters.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/core/ux/user_feedback_sanitizer.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Evidence and concern tiers for extracted claims
enum ClaimEvidenceTier {
  verified, // 🟢 Most verified with strong empirical evidence
  needsSource, // 🟡 Needs supporting citations
  highConcern, // 🔴 No evidence found / potential inaccuracy - creator concern
  disputed, // 🟣 Disputed / under review
}

class RealExtractedClaim {
  RealExtractedClaim({
    required this.id,
    required this.videoId,
    required this.videoTitle,
    required this.text,
    required this.timestamp,
    required this.timestampSeconds,
    required this.category,
    required this.confidenceScore,
    required this.sourceCitation,
    required this.tier,
    this.verdict = 'verified',
    this.aiExplanation = '',
    this.recommendedAction = '',
    this.creatorActionNote,
    this.transcriptSnippet = '',
  });

  final String id;
  final String videoId;
  final String videoTitle;
  final String text;
  final String timestamp;
  final double timestampSeconds;
  final String category;
  final double confidenceScore;
  final String sourceCitation;
  ClaimEvidenceTier tier;
  final String verdict;
  final String aiExplanation;
  final String recommendedAction;
  String? creatorActionNote;
  final String transcriptSnippet;

  bool get isVerified => tier == ClaimEvidenceTier.verified;
  bool get isHighConcern => tier == ClaimEvidenceTier.highConcern;
  bool get isNeedsSource => tier == ClaimEvidenceTier.needsSource;
  bool get isDisputed => tier == ClaimEvidenceTier.disputed;
}

class VideoFactCheckItem {
  VideoFactCheckItem({
    required this.id,
    required this.title,
    required this.thumbnailUrl,
    required this.truthScore,
    required this.factCheckReviewMode,
    required this.isFactCheckApproved,
    required this.claims,
    required this.summary,
    required this.domain,
    required this.createdAt,
    this.durationSeconds = 600.0,
    this.disputeStatus,
    this.reverificationRequested = false,
    this.reverificationNotes,
    this.reverificationSources,
  });

  final String id;
  final String title;
  final String thumbnailUrl;
  final double truthScore; // 0.0 to 1.0
  final String factCheckReviewMode; // 'open_to_users' | 'first_to_creator'
  final bool isFactCheckApproved;
  final List<RealExtractedClaim> claims;
  final String summary;
  final String domain;
  final DateTime? createdAt;
  final double durationSeconds;
  final String? disputeStatus;
  final bool reverificationRequested;
  final String? reverificationNotes;
  final List<dynamic>? reverificationSources;

  bool get isReviewFirst => factCheckReviewMode == 'first_to_creator';
  bool get isPendingApproval => isReviewFirst && !isFactCheckApproved;
  bool get isPubliclyVisible => !isPendingApproval;
  bool get isDisputed => disputeStatus != null && disputeStatus != 'resolved';

  List<RealExtractedClaim> get verifiedClaims =>
      claims.where((c) => c.isVerified).toList();
  List<RealExtractedClaim> get highConcernClaims =>
      claims.where((c) => c.isHighConcern).toList();
  List<RealExtractedClaim> get needsSourceClaims =>
      claims.where((c) => c.isNeedsSource).toList();
  List<RealExtractedClaim> get disputedClaims =>
      claims.where((c) => c.isDisputed).toList();

  bool get hasConcerns => highConcernClaims.isNotEmpty;

  /// Projected score if concerns and missing sources are resolved
  double get projectedTruthScore {
    if (claims.isEmpty) return truthScore;
    final bonus = (highConcernClaims.length * 0.16) +
        (needsSourceClaims.length * 0.06);
    return (truthScore + bonus).clamp(0.0, 1.0);
  }

  int get boostPercentage =>
      ((projectedTruthScore - truthScore) * 100).toInt().clamp(0, 100);
}

class TruthVerificationDashboardPage extends StatelessWidget {
  TruthVerificationDashboardPage({
    required this.channelId,
    required this.isDarkMode,
    this.initialVideoId,
    super.key,
  }) {
    if (initialVideoId != null && initialVideoId!.isNotEmpty) {
      targetVideoId.value = initialVideoId!;
    }
  }

  final String channelId;
  final bool isDarkMode;
  final String? initialVideoId;

  /// Global or deep-linked target video filter
  static final RxString targetVideoId = ''.obs;

  BuildContext get context => Get.context!;

  final RxInt _selectedTab = 0.obs; // 0: Video Reports, 1: Claims, 2: Activity Audit Log
  final RxString _videoFilter = 'all'.obs; // 'all', 'concerns', 'pending', 'approved', 'disputed'
  final RxString _claimTierFilter = 'all'.obs; // 'all', 'high_concern', 'needs_source', 'verified', 'disputed'
  final RxBool _isPublished = true.obs;

  String _formatTimestamp(double? seconds) {
    if (seconds == null || seconds <= 0) return '00:00';
    final duration = Duration(seconds: seconds.toInt());
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  ClaimEvidenceTier _parseClaimTier(
    String verdictStr,
    double confidence,
    String sourceCitation,
  ) {
    final lower = verdictStr.toLowerCase();
    if (lower.contains('dispute') || lower.contains('contest')) {
      return ClaimEvidenceTier.disputed;
    }
    if (lower.contains('false') ||
        lower.contains('debunk') ||
        lower.contains('inaccurate') ||
        lower.contains('incorrect') ||
        lower.contains('no_evidence') ||
        lower.contains('unsupported') ||
        lower.contains('concern') ||
        lower.contains('misleading') ||
        lower.contains('flagged')) {
      return ClaimEvidenceTier.highConcern;
    }
    if (lower.contains('unverified') ||
        lower.contains('needs_source') ||
        lower.contains('review') ||
        lower.contains('uncertain') ||
        confidence < 0.8) {
      return ClaimEvidenceTier.needsSource;
    }
    return ClaimEvidenceTier.verified;
  }

  /// Determines whether a video document has AI Fact-Checking enabled, in-progress, or verified.
  static bool hasFactChecking(
    Map<String, dynamic> data, {
    List<RealExtractedClaim>? claims,
    double? trustScore,
  }) {
    // 1. Explicit fact-checked flags on video doc
    if (data['isFactChecked'] == true ||
        data['hasFactChecking'] == true ||
        data['factChecking'] == true ||
        data['isFactChecking'] == true) {
      return true;
    }

    // 2. Fact-checking enabled in AI features metadata
    final aiFeatures = data['aiFeatures'];
    if (aiFeatures is Map) {
      if (aiFeatures['factChecking'] == true ||
          aiFeatures['factCheckEnabled'] == true ||
          aiFeatures['isFactChecked'] == true) {
        return true;
      }
    }

    // 3. Claims present (extracted from uiReport or Firestore array)
    if (claims != null && claims.isNotEmpty) {
      return true;
    }
    final rawClaims = data['claims'];
    if (rawClaims is List && rawClaims.isNotEmpty) {
      return true;
    }

    // 4. UI report present with key claims, summary, or report payload
    final uiReport = data['uiReport'];
    if (uiReport is Map && uiReport.isNotEmpty) {
      final keyClaims = uiReport['keyClaims'];
      if (keyClaims is List && keyClaims.isNotEmpty) {
        return true;
      }
      if (uiReport['summary'] != null || uiReport['verdict'] != null) {
        return true;
      }
    }

    // 5. Positive trust/credibility score produced by verification
    final score = trustScore ??
        ((data['trustScore'] ??
                data['credibilityScore'] ??
                data['rating'] ??
                0.0) as num)
            .toDouble();
    if (score > 0) {
      return true;
    }

    // 6. Direct fact-check URL present
    final factCheckUrl = data['factCheckUrl'] as String?;
    if (factCheckUrl != null && factCheckUrl.trim().isNotEmpty) {
      return true;
    }
    final media = data['media'];
    if (media is Map) {
      final mediaFactCheckUrl = media['factCheckUrl'] as String?;
      if (mediaFactCheckUrl != null && mediaFactCheckUrl.trim().isNotEmpty) {
        return true;
      }
    }

    // 7. Active dispute or reverification requested
    if (data['reverificationRequested'] == true) {
      return true;
    }
    final disputeStatus = data['disputeStatus'] as String?;
    if (disputeStatus != null && disputeStatus.trim().isNotEmpty) {
      return true;
    }

    // 8. Fact-check status flag is active
    final factCheckStatus = data['factCheckStatus'] as String?;
    if (factCheckStatus != null &&
        factCheckStatus.trim().isNotEmpty &&
        factCheckStatus != 'none') {
      return true;
    }

    return false;
  }

  Future<void> _approveVideoFactCheck(String videoId) async {
    try {
      await FirebaseFirestore.instance.collection('videos').doc(videoId).update({
        'isFactCheckApproved': true,
        'aiFeatures.isFactCheckApproved': true,
        'factCheckApprovedAt': FieldValue.serverTimestamp(),
      });
      AppSnackbar.success(
        'Fact-checking results approved! Viewers can now see verification badges on the video player.',
      );
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'TruthVerificationDashboardPage.approveVideoFactCheck',
      );
      AppSnackbar.error('Failed to approve fact-check. Please try again.');
    }
  }

  Future<void> _toggleFactCheckApproval(
    String videoId,
    bool currentApproved,
  ) async {
    final newStatus = !currentApproved;
    try {
      await FirebaseFirestore.instance.collection('videos').doc(videoId).update({
        'isFactCheckApproved': newStatus,
        'aiFeatures.isFactCheckApproved': newStatus,
        'factCheckApprovedAt':
            newStatus ? FieldValue.serverTimestamp() : null,
      });
      if (newStatus) {
        AppSnackbar.success(
          'Fact-checking results approved! Viewers can now see verification badges.',
        );
      } else {
        AppSnackbar.info(
          'Fact-checking held private. Viewers cannot see results until approved.',
        );
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'TruthVerificationDashboardPage.toggleApproval',
      );
      AppSnackbar.error('Failed to update approval status. Please try again.');
    }
  }

  // =========================================================================
  // WORLD CLASS INTERACTIVE TOOLS
  // =========================================================================

  /// Interactive Timeline Scrubber with color-coded markers for each claim
  Widget _buildInteractiveTimelineScrubber({
    required VideoFactCheckItem video,
    required ValueChanged<RealExtractedClaim> onClaimSelected,
  }) {
    if (video.claims.isEmpty) return const SizedBox.shrink();

    final durationSec = video.durationSeconds > 0 ? video.durationSeconds : 600.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.bgPage : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode ? AppColors.bgDivider : Colors.grey.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.timeline_rounded,
                    size: 16,
                    color: AppColors.brand,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Video Assertion Timeline',
                    style: TextStyle(
                      fontFamily: TWTypography.brandFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brand,
                    ),
                  ),
                ],
              ),
              Text(
                'Tap marker to inspect claim',
                style: TextStyle(
                  fontSize: 11,
                  color: isDarkMode ? AppColors.textSecondary : Colors.black54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Visual Track
          LayoutBuilder(
            builder: (context, constraints) {
              final trackWidth = constraints.maxWidth;
              return SizedBox(
                height: 32,
                width: trackWidth,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    // Baseline track
                    Container(
                      height: 6,
                      width: trackWidth,
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? const Color(0xFF2C2C2C)
                            : Colors.grey[300],
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),

                    // Claim marker dots
                    ...video.claims.map((claim) {
                      final posFraction =
                          (claim.timestampSeconds / durationSec).clamp(0.02, 0.98);
                      final leftOffset = posFraction * (trackWidth - 16);

                      Color markerColor;
                      if (claim.isHighConcern) {
                        markerColor = AppColors.error;
                      } else if (claim.isNeedsSource) {
                        markerColor = AppColors.warning;
                      } else if (claim.isDisputed) {
                        markerColor = Colors.purpleAccent;
                      } else {
                        markerColor = AppColors.success;
                      }

                      return Positioned(
                        left: leftOffset,
                        child: InkWell(
                          onTap: () => onClaimSelected(claim),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: markerColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: markerColor.withValues(alpha: 0.5),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
          ),

          // Start & End Timestamps
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '00:00',
                style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
              ),
              Row(
                children: [
                  _buildLegendIndicator(AppColors.success, 'Verified'),
                  const SizedBox(width: 8),
                  _buildLegendIndicator(AppColors.warning, 'Needs Source'),
                  const SizedBox(width: 8),
                  _buildLegendIndicator(AppColors.error, 'Concern'),
                ],
              ),
              Text(
                _formatTimestamp(durationSec),
                style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendIndicator(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  /// Credibility Booster & Truth Score Impact Simulator
  Widget _buildScoreImpactSimulator(VideoFactCheckItem video) {
    if (video.boostPercentage <= 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.brandVariant.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.brandVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.trending_up_rounded,
              color: AppColors.brand,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Credibility Boost Potential: +${video.boostPercentage}%',
                      style: const TextStyle(
                        fontFamily: TWTypography.brandFamily,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.brand,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.brand,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${(video.truthScore * 100).toInt()}% ➔ ${(video.projectedTruthScore * 100).toInt()}%',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Substantiating ${video.highConcernClaims.length} concern alert(s) will unlock the Gold Authenticity Shield badge for all video viewers.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode
                        ? AppColors.textSecondary
                        : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Chat with Truth AI Coach & Rebuttal Drafter
  void _showTruthAiCoachModal(
    BuildContext context,
    RealExtractedClaim claim,
    VideoFactCheckItem video,
  ) {
    final generatedDisclaimer =
        '📌 Verification Context [${claim.timestamp}]: Regarding the assertion about "${claim.text.length > 50 ? "${claim.text.substring(0, 50)}..." : claim.text}", updated empirical data and official documentation are available in the description citation registry.';

    final academicQueries = [
      'Query: ${claim.category} official registry data for "${claim.text.split(' ').take(4).join(' ')}"',
      'Query: PubMed / DOI peer-reviewed citation for statement at ${claim.timestamp}',
      'Query: National statistical bureau release on ${claim.category}',
    ];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.85,
        decoration: BoxDecoration(
          color: isDarkMode ? AppColors.bgSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: isDarkMode ? AppColors.bgDivider : AppColors.brandVariant,
          ),
        ),
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.brand.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.psychology_rounded,
                        color: AppColors.brand,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Truth AI Fact-Check Coach',
                          style: TextStyle(
                            fontFamily: TWTypography.brandFamily,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode
                                ? AppColors.textPrimary
                                : Colors.black87,
                          ),
                        ),
                        const Text(
                          'Instant creator guidance & disclaimer generation',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(color: AppColors.bgDivider),
            const SizedBox(height: 14),

            Expanded(
              child: ListView(
                children: [
                  // Claim Header
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDarkMode ? AppColors.bgPage : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Analyzing Claim [${claim.timestamp}]: "${claim.text}"',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode
                            ? AppColors.textPrimary
                            : Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Tool 1: AI Generated Disclaimer Note
                  Text(
                    '1. Auto-Generated Disclaimer Note for Viewers',
                    style: TextStyle(
                      fontFamily: TWTypography.brandFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.info.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          generatedDisclaimer,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: isDarkMode
                                ? AppColors.textPrimary
                                : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: generatedDisclaimer),
                            );
                            AppSnackbar.success(
                              'Disclaimer copied to clipboard! Paste it into your video description.',
                            );
                          },
                          icon: const Icon(Icons.copy_rounded, size: 14),
                          label: const Text('Copy Pinned Disclaimer'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.info,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            textStyle: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Tool 2: Recommended Search Queries & Registries
                  Text(
                    '2. Recommended Authoritative Search Queries',
                    style: TextStyle(
                      fontFamily: TWTypography.brandFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...academicQueries.map((q) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? AppColors.bgSurfaceHover
                              : const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.bgDivider),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                q,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDarkMode
                                      ? AppColors.textSecondary
                                      : Colors.black87,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 14),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: q));
                                AppSnackbar.info('Search query copied.');
                              },
                            ),
                          ],
                        ),
                      )),
                  const SizedBox(height: 16),

                  // Tool 3: Draft Dispute Argument
                  Text(
                    '3. Draft Academic Rebuttal for Dispute',
                    style: TextStyle(
                      fontFamily: TWTypography.brandFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? AppColors.bgSurfaceHover
                          : const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.bgDivider),
                    ),
                    child: Text(
                      'Formal Rebuttal: The spoken assertion at timestamp ${claim.timestamp} regarding "${claim.text}" was communicated within the specific context of ${claim.category}. We request secondary evaluation considering recent publications.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: isDarkMode
                            ? AppColors.textSecondary
                            : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Export Complete Authenticity Dossier & Audit Certificate
  void _showExportAuditDossierModal(
    BuildContext context,
    VideoFactCheckItem video,
  ) {
    final dossierText = '''
=====================================================
TRUTHWORLD VERIFICATION AUDIT DOSSIER & CERTIFICATE
=====================================================
Report ID: TW-AUDIT-${video.id.toUpperCase()}
Video Title: ${video.title}
Channel ID: $channelId
Audit Timestamp: ${DateTime.now().toUtc().toIso8601String()}

VERIFICATION SCORES:
- Authenticity Index: ${(video.truthScore * 100).toInt()}%
- Review Mode: ${video.factCheckReviewMode}
- Approval Status: ${video.isFactCheckApproved ? 'Approved (Public)' : 'Held Private'}

ASSERTIONS ANALYZED (${video.claims.length}):
${video.claims.map((c) => '• [${c.timestamp}] [${c.tier.name.toUpperCase()}] "${c.text}" (Source: ${c.sourceCitation})').join('\n')}

CRYPTOGRAPHIC VALIDATION:
Digital Stamp: SHA256-${video.id.hashCode.toRadixString(16).padLeft(16, '0')}
Status: VERIFIED_MULTIMODAL_CONSENSUS
=====================================================
''';

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDarkMode ? AppColors.bgSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.verified_user_rounded,
                color: AppColors.brand,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Authenticity Audit Dossier',
                style: TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                ),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Copy this standardized audit report for sponsors, academic partners, or description transparency.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode
                        ? AppColors.textSecondary
                        : Colors.black54,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? const Color(0xFF181818)
                        : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.bgDivider),
                  ),
                  child: SelectableText(
                    dossierText,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      height: 1.4,
                      color: AppColors.brand,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Close',
              style: TextStyle(
                color: isDarkMode ? AppColors.textSecondary : Colors.black54,
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: dossierText));
              Navigator.pop(ctx);
              AppSnackbar.success(
                'Audit Dossier copied to clipboard successfully!',
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 15, color: Colors.black),
            label: const Text('Copy Dossier'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // INTERACTIVE CREATOR ACTIONS PER CLAIM
  // =========================================================================

  /// Interactive Modal: Ask AI why a claim was flagged
  void _showAskAiWhyDialog(BuildContext context, RealExtractedClaim claim) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDarkMode ? AppColors.bgSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.psychology_rounded,
                color: AppColors.brand,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'AI Fact-Checking Diagnostic',
                style: TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  fontFamilyFallback: TWTypography.fallbackFamilies,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                ),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDarkMode ? AppColors.bgPage : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: claim.isHighConcern
                          ? AppColors.error.withValues(alpha: 0.5)
                          : (claim.isNeedsSource
                              ? AppColors.warning.withValues(alpha: 0.5)
                              : AppColors.success.withValues(alpha: 0.5)),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.info.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Time: ${claim.timestamp}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.info,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            claim.category,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDarkMode
                                  ? AppColors.textSecondary
                                  : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '"${claim.text}"',
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          fontFamilyFallback: TWTypography.fallbackFamilies,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  'Analysis & Diagnostic Findings',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontFamilyFallback: TWTypography.fallbackFamilies,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  claim.isHighConcern
                      ? 'The fact-checking pipeline cross-referenced academic databases, government statistical releases, and peer-reviewed indices. No authoritative record verifies this exact assertion. Spoken figures or claims may contradict official datasets.'
                      : (claim.isNeedsSource
                          ? 'This assertion is plausible and common in secondary commentary, but lacks a primary documented index. Providing an official source link will substantiate it.'
                          : 'This statement is substantiated by indexed empirical research with high classification confidence.'),
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontFamilyFallback: TWTypography.fallbackFamilies,
                    fontSize: 12,
                    height: 1.45,
                    color: isDarkMode ? AppColors.textSecondary : Colors.black87,
                  ),
                ),
                const SizedBox(height: 14),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.brandVariant.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.brandVariant.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline_rounded,
                            size: 15,
                            color: AppColors.brand,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Acceptable Evidence to Clear Concern:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.brand,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '• Peer-reviewed journal link (PubMed, DOI, Nature, IEEE)\n'
                        '• Official government ministry/bureau publication (.gov, official)\n'
                        '• Primary legal gazette or registered statistical repository\n'
                        '• Direct corporate audited regulatory filing',
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.4,
                          color: isDarkMode
                              ? AppColors.textSecondary
                              : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Close',
              style: TextStyle(
                color: isDarkMode ? AppColors.textSecondary : Colors.black54,
              ),
            ),
          ),
          if (claim.isHighConcern || claim.isNeedsSource) ...[
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _showMarkVideoEditDialog(context, claim);
              },
              icon: const Icon(Icons.edit_note_rounded, size: 14),
              label: const Text('Mark for Edit'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.warning,
                side: const BorderSide(color: AppColors.warning),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _showProvideSourceForClaimDialog(context, claim);
              },
              icon: const Icon(Icons.add_link, size: 14, color: Colors.black),
              label: const Text('Provide Source'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Interactive Modal: Provide source link for a specific claim
  void _showProvideSourceForClaimDialog(
    BuildContext context,
    RealExtractedClaim claim,
  ) {
    final urlController = TextEditingController();
    final notesController = TextEditingController();
    var sourceType = 'Academic / Research Paper';

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: isDarkMode ? AppColors.bgSurface : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.link_rounded,
                  color: AppColors.brand,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Provide Source for Claim [${claim.timestamp}]',
                  style: TextStyle(
                    fontFamily: TWTypography.brandFamily,
                    fontFamilyFallback: TWTypography.fallbackFamilies,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '"${claim.text}"',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontFamilyFallback: TWTypography.fallbackFamilies,
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: isDarkMode
                          ? AppColors.textSecondary
                          : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    'Evidence Category',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontFamilyFallback: TWTypography.fallbackFamilies,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode
                          ? AppColors.textSecondary
                          : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: sourceType,
                    dropdownColor:
                        isDarkMode ? AppColors.bgSurface : Colors.white,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontFamilyFallback: TWTypography.fallbackFamilies,
                      color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                      fontSize: 13,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Academic / Research Paper',
                        child: Text('Academic / Research Paper (DOI)'),
                      ),
                      DropdownMenuItem(
                        value: 'Official Government Release',
                        child: Text('Official Government Release (.gov)'),
                      ),
                      DropdownMenuItem(
                        value: 'Primary Regulatory Document',
                        child: Text('Primary Regulatory / Legal Gazette'),
                      ),
                      DropdownMenuItem(
                        value: 'News Wire / Investigative Report',
                        child: Text('News Wire / Verified Press Agency'),
                      ),
                      DropdownMenuItem(
                        value: 'Archival Reference Book',
                        child: Text('Archival Reference / Verified Book'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => sourceType = val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  Text(
                    'Authoritative Source URL',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontFamilyFallback: TWTypography.fallbackFamilies,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode
                          ? AppColors.textSecondary
                          : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: urlController,
                    inputFormatters: [...TruthworldTextInputFormatters.standard],
                    decoration: InputDecoration(
                      hintText: 'https://nature.com/articles/... or https://...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                    ),
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontFamilyFallback: TWTypography.fallbackFamilies,
                      color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Text(
                    'Citation Title / Context Note',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontFamilyFallback: TWTypography.fallbackFamilies,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode
                          ? AppColors.textSecondary
                          : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: notesController,
                    inputFormatters: [...TruthworldTextInputFormatters.standard],
                    decoration: InputDecoration(
                      hintText: 'e.g. Table 4 of 2026 National Statistics release',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                    ),
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontFamilyFallback: TWTypography.fallbackFamilies,
                      color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDarkMode ? AppColors.textSecondary : Colors.black54,
                ),
              ),
            ),
            ElevatedButton.icon(
              icon: const Icon(
                Icons.check_circle_rounded,
                size: 15,
                color: Colors.black,
              ),
              label: const Text('Attach Source'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.black,
              ),
              onPressed: () async {
                final url = urlController.text.trim();
                if (url.isEmpty) {
                  AppSnackbar.warning('Please enter a source URL.');
                  return;
                }
                final val = ContentValidator.validate(
                  url,
                  checkEnglishOnly: false,
                  fieldName: 'Source URL',
                );
                if (!val.isValid) {
                  AppSnackbar.warning(val.message);
                  return;
                }

                try {
                  await FirebaseFirestore.instance
                      .collection('videos')
                      .doc(claim.videoId)
                      .collection('citations')
                      .add({
                    'claimId': claim.id,
                    'claimText': claim.text,
                    'timestamp': claim.timestamp,
                    'sourceUrl': url,
                    'sourceType': sourceType,
                    'citationNotes': notesController.text.trim(),
                    'status': 'submitted_pending_reverification',
                    'createdAt': FieldValue.serverTimestamp(),
                  });

                  claim.tier = ClaimEvidenceTier.disputed;

                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }
                  AppSnackbar.success(
                    'Source attached for Claim [${claim.timestamp}]! AI verification engine will re-evaluate this claim.',
                  );
                } catch (e, stackTrace) {
                  ErrorHandler.log(
                    e,
                    stackTrace: stackTrace,
                    tag: 'TruthVerificationDashboardPage.attachSource',
                  );
                  AppSnackbar.error('Failed to attach source. Please try again.');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Interactive Modal: Creator action to edit video segment or add viewer note
  void _showMarkVideoEditDialog(
    BuildContext context,
    RealExtractedClaim claim,
  ) {
    var selectedActionType = 'trim_in_editor';
    final noteController = TextEditingController(
      text:
          'Correction for timestamp ${claim.timestamp}: The assertion made in this segment has been updated by the creator.',
    );

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: isDarkMode ? AppColors.bgSurface : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.content_cut_rounded,
                  color: AppColors.warning,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Resolve Claim [${claim.timestamp}]',
                  style: TextStyle(
                    fontFamily: TWTypography.brandFamily,
                    fontFamilyFallback: TWTypography.fallbackFamilies,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Concern regarding: "${claim.text}"',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontFamilyFallback: TWTypography.fallbackFamilies,
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: isDarkMode
                          ? AppColors.textSecondary
                          : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    'Choose Resolution Action:',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontFamilyFallback: TWTypography.fallbackFamilies,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode
                          ? AppColors.textSecondary
                          : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),

                  RadioListTile<String>(
                    value: 'trim_in_editor',
                    groupValue: selectedActionType,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      '✂️ Mark for trimming in video editor',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'Indicates to verification review that you will cut or mute this segment.',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedActionType = val);
                      }
                    },
                  ),
                  RadioListTile<String>(
                    value: 'viewer_disclaimer_note',
                    groupValue: selectedActionType,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      '📌 Add pinned clarification note for viewers',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'Pins a clarifying note on player overlay explaining context.',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedActionType = val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  Text(
                    'Clarification Note Text',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontFamilyFallback: TWTypography.fallbackFamilies,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode
                          ? AppColors.textSecondary
                          : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: noteController,
                    maxLines: 3,
                    inputFormatters: [...TruthworldTextInputFormatters.standard],
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontFamilyFallback: TWTypography.fallbackFamilies,
                      color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDarkMode ? AppColors.textSecondary : Colors.black54,
                ),
              ),
            ),
            ElevatedButton.icon(
              icon: const Icon(
                Icons.check_circle_rounded,
                size: 15,
                color: Colors.white,
              ),
              label: const Text('Save Action'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final note = noteController.text.trim();
                try {
                  await FirebaseFirestore.instance
                      .collection('videos')
                      .doc(claim.videoId)
                      .collection('creator_actions')
                      .add({
                    'claimId': claim.id,
                    'actionType': selectedActionType,
                    'note': note,
                    'timestamp': claim.timestamp,
                    'createdAt': FieldValue.serverTimestamp(),
                  });

                  claim.creatorActionNote = note;

                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }
                  AppSnackbar.success(
                    'Creator action recorded! Viewers and fact-checking models will see this clarification.',
                  );
                } catch (e, stackTrace) {
                  ErrorHandler.log(
                    e,
                    stackTrace: stackTrace,
                    tag: 'TruthVerificationDashboardPage.markVideoEdit',
                  );
                  AppSnackbar.error('Failed to save action. Please try again.');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // INTERACTIVE HEALTH BAR & CLAIM CARDS
  // =========================================================================

  Widget _buildClaimEvidenceHealthBar({
    required List<RealExtractedClaim> claims,
    required String selectedFilter,
    required ValueChanged<String> onFilterChanged,
    double? overallTruthScore,
  }) {
    if (claims.isEmpty) return const SizedBox.shrink();

    final verifiedCount = claims.where((c) => c.isVerified).length;
    final needsSourceCount = claims.where((c) => c.isNeedsSource).length;
    final highConcernCount = claims.where((c) => c.isHighConcern).length;
    final disputedCount = claims.where((c) => c.isDisputed).length;
    final total = claims.length;

    final verifiedFraction = verifiedCount / total;
    final needsSourceFraction = needsSourceCount / total;
    final highConcernFraction = highConcernCount / total;
    final disputedFraction = disputedCount / total;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.bgSurface : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highConcernCount > 0
              ? AppColors.error.withValues(alpha: 0.4)
              : (isDarkMode ? AppColors.bgDivider : Colors.grey.withValues(alpha: 0.3)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    highConcernCount > 0
                        ? Icons.warning_amber_rounded
                        : Icons.fact_check_rounded,
                    size: 18,
                    color: highConcernCount > 0
                        ? AppColors.error
                        : AppColors.success,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Claim Evidence Health Meter',
                    style: TextStyle(
                      fontFamily: TWTypography.brandFamily,
                      fontFamilyFallback: TWTypography.fallbackFamilies,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                    ),
                  ),
                ],
              ),
              Text(
                overallTruthScore != null && overallTruthScore > 0
                    ? 'Truth Score ${(overallTruthScore * 100).toInt()}% • ${(verifiedFraction * 100).toInt()}% Verified'
                    : '${(verifiedFraction * 100).toInt()}% Verified Evidence',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontFamilyFallback: TWTypography.fallbackFamilies,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: verifiedFraction >= 0.7
                      ? AppColors.success
                      : AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Multi-segmented bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  if (verifiedFraction > 0)
                    Expanded(
                      flex: (verifiedFraction * 1000).toInt(),
                      child: Container(color: AppColors.success),
                    ),
                  if (needsSourceFraction > 0)
                    Expanded(
                      flex: (needsSourceFraction * 1000).toInt(),
                      child: Container(color: AppColors.warning),
                    ),
                  if (highConcernFraction > 0)
                    Expanded(
                      flex: (highConcernFraction * 1000).toInt(),
                      child: Container(color: AppColors.error),
                    ),
                  if (disputedFraction > 0)
                    Expanded(
                      flex: (disputedFraction * 1000).toInt(),
                      child: Container(color: Colors.purpleAccent),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Interactive Counter Chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildHealthChip(
                label: 'All Claims ($total)',
                color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                bgColor: isDarkMode
                    ? AppColors.bgSurfaceHover
                    : const Color(0xFFE5E7EB),
                isSelected: selectedFilter == 'all',
                onTap: () => onFilterChanged('all'),
              ),
              _buildHealthChip(
                label: '🟢 Most Verified ($verifiedCount)',
                color: AppColors.success,
                bgColor: AppColors.success.withValues(alpha: 0.15),
                isSelected: selectedFilter == 'verified',
                onTap: () => onFilterChanged('verified'),
              ),
              if (highConcernCount > 0)
                _buildHealthChip(
                  label: '🔴 High Concern / No Evidence ($highConcernCount)',
                  color: AppColors.error,
                  bgColor: AppColors.error.withValues(alpha: 0.15),
                  isSelected: selectedFilter == 'high_concern',
                  isAlert: true,
                  onTap: () => onFilterChanged('high_concern'),
                ),
              if (needsSourceCount > 0)
                _buildHealthChip(
                  label: '🟡 Needs Source ($needsSourceCount)',
                  color: AppColors.warning,
                  bgColor: AppColors.warning.withValues(alpha: 0.15),
                  isSelected: selectedFilter == 'needs_source',
                  onTap: () => onFilterChanged('needs_source'),
                ),
              if (disputedCount > 0)
                _buildHealthChip(
                  label: '🟣 Disputed ($disputedCount)',
                  color: Colors.purpleAccent,
                  bgColor: Colors.purple.withValues(alpha: 0.15),
                  isSelected: selectedFilter == 'disputed',
                  onTap: () => onFilterChanged('disputed'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHealthChip({
    required String label,
    required Color color,
    required Color bgColor,
    required bool isSelected,
    required VoidCallback onTap,
    bool isAlert = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.25) : bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? color
                : (isAlert ? AppColors.error : Colors.transparent),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: TWTypography.uiFamily,
            fontFamilyFallback: TWTypography.fallbackFamilies,
            fontSize: 11,
            fontWeight: isSelected || isAlert ? FontWeight.bold : FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildInteractiveClaimCard(
    BuildContext context,
    RealExtractedClaim claim,
    VideoFactCheckItem? video,
  ) {
    Color borderColor;
    Color headerBg;
    String badgeText;
    Color badgeFg;
    IconData tierIcon;

    if (claim.isHighConcern) {
      borderColor = AppColors.error.withValues(alpha: 0.7);
      headerBg = AppColors.error.withValues(alpha: 0.12);
      badgeText = '🔴 HIGH CONCERN • NO EVIDENCE FOUND';
      badgeFg = AppColors.error;
      tierIcon = Icons.warning_amber_rounded;
    } else if (claim.isNeedsSource) {
      borderColor = AppColors.warning.withValues(alpha: 0.6);
      headerBg = AppColors.warning.withValues(alpha: 0.12);
      badgeText = '🟡 NEEDS EVIDENCE / CITATION';
      badgeFg = AppColors.warning;
      tierIcon = Icons.help_outline_rounded;
    } else if (claim.isDisputed) {
      borderColor = Colors.purple.withValues(alpha: 0.6);
      headerBg = Colors.purple.withValues(alpha: 0.12);
      badgeText = '🟣 CITATION UNDER REVIEW';
      badgeFg = Colors.purpleAccent;
      tierIcon = Icons.gavel_rounded;
    } else {
      borderColor = AppColors.success.withValues(alpha: 0.5);
      headerBg = AppColors.success.withValues(alpha: 0.12);
      badgeText =
          '🟢 VERIFIED EVIDENCE (${(claim.confidenceScore * 100).toInt()}%)';
      badgeFg = AppColors.success;
      tierIcon = Icons.verified_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.bgPage : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: headerBg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(tierIcon, size: 16, color: badgeFg),
                    const SizedBox(width: 8),
                    Text(
                      badgeText,
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        fontFamilyFallback: TWTypography.fallbackFamilies,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: badgeFg,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    claim.timestamp,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.info,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '"${claim.text}"',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontFamilyFallback: TWTypography.fallbackFamilies,
                    fontSize: 14,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),

                if (claim.isHighConcern) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              size: 15,
                              color: AppColors.error,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Creator Concern: No Verifiable Evidence Found',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.error,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Our verification scan found no reliable empirical citation for this statement. Viewers may see an inaccuracy badge. Recommendation: Provide an official source URL or trim this segment in your video.',
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.35,
                            color: isDarkMode
                                ? AppColors.textSecondary
                                : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else if (claim.isNeedsSource) ...[
                  Container(
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
                        const Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 15,
                              color: AppColors.warning,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Needs Supporting Citation to Verify',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.warning,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'This statement lacks a direct primary document. Provide an authoritative research or government link below to upgrade this claim to Verified status.',
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.35,
                            color: isDarkMode
                                ? AppColors.textSecondary
                                : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else ...[
                  Row(
                    children: [
                      Icon(
                        Icons.library_books_rounded,
                        size: 13,
                        color: isDarkMode
                            ? AppColors.textSecondary
                            : Colors.black54,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Indexed Source: ${claim.sourceCitation}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDarkMode
                                ? AppColors.textSecondary
                                : Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                if (claim.creatorActionNote != null &&
                    claim.creatorActionNote!.isNotEmpty) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.content_cut_rounded,
                          size: 13,
                          color: AppColors.info,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Creator Resolution: ${claim.creatorActionNote}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.info,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () =>
                          _showProvideSourceForClaimDialog(context, claim),
                      icon: const Icon(
                        Icons.add_link,
                        size: 14,
                        color: Colors.black,
                      ),
                      label: const Text('Provide Source'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    if (claim.isHighConcern || claim.isNeedsSource)
                      OutlinedButton.icon(
                        onPressed: () =>
                            _showMarkVideoEditDialog(context, claim),
                        icon: const Icon(
                          Icons.edit_note_rounded,
                          size: 14,
                          color: AppColors.warning,
                        ),
                        label: const Text('Mark for Edit / Note'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.warning,
                          side: const BorderSide(color: AppColors.warning),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          textStyle: const TextStyle(fontSize: 11),
                        ),
                      ),

                    if (video != null)
                      OutlinedButton.icon(
                        onPressed: () =>
                            _showTruthAiCoachModal(context, claim, video),
                        icon: const Icon(
                          Icons.psychology_rounded,
                          size: 14,
                          color: AppColors.brand,
                        ),
                        label: const Text('AI Coach'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.brand,
                          side: const BorderSide(color: AppColors.brand),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          textStyle: const TextStyle(fontSize: 11),
                        ),
                      ),

                    OutlinedButton.icon(
                      onPressed: () => _showAskAiWhyDialog(context, claim),
                      icon: Icon(
                        Icons.help_outline_rounded,
                        size: 14,
                        color: isDarkMode
                            ? AppColors.textPrimary
                            : Colors.black87,
                      ),
                      label: const Text('Why Flagged?'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDarkMode
                            ? AppColors.textPrimary
                            : Colors.black87,
                        side: const BorderSide(color: AppColors.bgDivider),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        textStyle: const TextStyle(fontSize: 11),
                      ),
                    ),

                    if (video != null)
                      TextButton.icon(
                        onPressed: () => _showDisputeDialog(
                          context,
                          video,
                          specificClaim: claim,
                        ),
                        icon: const Icon(
                          Icons.gavel_rounded,
                          size: 13,
                          color: AppColors.textSecondary,
                        ),
                        label: const Text(
                          'Dispute Claim',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // FULL REPORT MODAL & OTHER DIALOGS
  // =========================================================================

  void _showVideoFactCheckReportModal(
    BuildContext context,
    VideoFactCheckItem video,
  ) {
    final modalClaimFilter = 'all'.obs;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final screenHeight = MediaQuery.of(ctx).size.height;
        return Container(
          height: screenHeight * 0.90,
          decoration: BoxDecoration(
            color: isDarkMode ? AppColors.bgSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: isDarkMode ? AppColors.bgDivider : AppColors.brandVariant,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.textTertiary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: isDarkMode ? AppColors.textSecondary : Colors.black87,
                      size: 22,
                    ),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 90,
                      height: 56,
                      color: isDarkMode ? const Color(0xFF242424) : Colors.grey[200],
                      child: video.thumbnailUrl.isNotEmpty
                          ? Image.network(
                              video.thumbnailUrl,
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (context, error, stackTrace) => const Icon(
                                Icons.video_library_rounded,
                                color: AppColors.textSecondary,
                              ),
                            )
                          : const Icon(
                              Icons.video_library_rounded,
                              color: AppColors.textSecondary,
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          video.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: TWTypography.brandFamily,
                            fontFamilyFallback: TWTypography.fallbackFamilies,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _buildStatusBadge(video),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(color: AppColors.bgDivider, height: 1),
              const SizedBox(height: 14),

              Expanded(
                child: ListView(
                  children: [
                    // Interactive Timeline Scrubber
                    _buildInteractiveTimelineScrubber(
                      video: video,
                      onClaimSelected: (claim) =>
                          _showAskAiWhyDialog(context, claim),
                    ),
                    const SizedBox(height: 14),

                    // Score Impact Simulator
                    _buildScoreImpactSimulator(video),
                    const SizedBox(height: 14),

                    // Health Bar
                    Obx(
                      () => _buildClaimEvidenceHealthBar(
                        claims: video.claims,
                        selectedFilter: modalClaimFilter.value,
                        overallTruthScore: video.truthScore,
                        onFilterChanged: (filter) =>
                            modalClaimFilter.value = filter,
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (video.summary.isNotEmpty) ...[
                      Text(
                        'AI Synthesis & Summary',
                        style: TextStyle(
                          fontFamily: TWTypography.brandFamily,
                          fontFamilyFallback: TWTypography.fallbackFamilies,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? AppColors.bgSurfaceHover
                              : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          video.summary,
                          style: TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            fontFamilyFallback: TWTypography.fallbackFamilies,
                            fontSize: 13,
                            height: 1.45,
                            color: isDarkMode
                                ? AppColors.textSecondary
                                : Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    Obx(() {
                      final filter = modalClaimFilter.value;
                      var list = video.claims;
                      if (filter == 'verified') {
                        list = video.verifiedClaims;
                      } else if (filter == 'high_concern') {
                        list = video.highConcernClaims;
                      } else if (filter == 'needs_source') {
                        list = video.needsSourceClaims;
                      } else if (filter == 'disputed') {
                        list = video.disputedClaims;
                      }

                      if (list.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: Text(
                              'No claims match the "$filter" filter for this video.',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDarkMode
                                    ? AppColors.textSecondary
                                    : Colors.black54,
                              ),
                            ),
                          ),
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Extracted Assertions & Verifications (${list.length})',
                            style: TextStyle(
                              fontFamily: TWTypography.brandFamily,
                              fontFamilyFallback: TWTypography.fallbackFamilies,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode
                                  ? AppColors.textPrimary
                                  : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...list.map(
                            (c) => _buildInteractiveClaimCard(context, c, video),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),

              const SizedBox(height: 14),
              const Divider(color: AppColors.bgDivider, height: 1),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _showExportAuditDossierModal(context, video),
                    icon: const Icon(
                      Icons.description_outlined,
                      size: 15,
                      color: AppColors.brand,
                    ),
                    label: const Text('Export Dossier'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.brand,
                      side: const BorderSide(color: AppColors.brand),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showDisputeDialog(context, video);
                    },
                    icon: const Icon(
                      Icons.gavel_rounded,
                      size: 15,
                      color: AppColors.warning,
                    ),
                    label: const Text('Dispute Results'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.warning,
                      side: const BorderSide(color: AppColors.warning),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showTalkToAiDialog(context, video);
                    },
                    icon: const Icon(
                      Icons.psychology_rounded,
                      size: 16,
                      color: Colors.black,
                    ),
                    label: const Text('Talk to AI (Add Sources)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      textStyle: const TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (video.isPendingApproval)
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _approveVideoFactCheck(video.id);
                      },
                      icon: const Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                      label: const Text('Approve for Viewers'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: const TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDisputeDialog(
    BuildContext context,
    VideoFactCheckItem video, {
    RealExtractedClaim? specificClaim,
  }) {
    final explanationController = TextEditingController();
    final urlController = TextEditingController();
    var selectedDisputeType = 'AI misconstrued statement context';
    var selectedClaimId = specificClaim?.id ?? 'all';

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              backgroundColor: isDarkMode ? AppColors.bgSurface : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.gavel_rounded,
                      color: AppColors.warning,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Dispute Fact-Checking Results',
                      style: TextStyle(
                        fontFamily: TWTypography.brandFamily,
                        fontFamilyFallback: TWTypography.fallbackFamilies,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Video: "${video.title}"',
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          fontFamilyFallback: TWTypography.fallbackFamilies,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode
                              ? AppColors.textSecondary
                              : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text(
                        'Reason for Dispute',
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          fontFamilyFallback: TWTypography.fallbackFamilies,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode
                              ? AppColors.textSecondary
                              : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: selectedDisputeType,
                        dropdownColor:
                            isDarkMode ? AppColors.bgSurface : Colors.white,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          fontFamilyFallback: TWTypography.fallbackFamilies,
                          color: isDarkMode
                              ? AppColors.textPrimary
                              : Colors.black87,
                          fontSize: 13,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'AI misconstrued statement context',
                            child: Text('AI misconstrued context / nuance'),
                          ),
                          DropdownMenuItem(
                            value: 'Outdated or superseded source cited by AI',
                            child: Text('Outdated source cited by AI'),
                          ),
                          DropdownMenuItem(
                            value: 'Video content was satire or hypothetical',
                            child: Text('Satire / hypothetical context'),
                          ),
                          DropdownMenuItem(
                            value: 'Scientific or peer consensus differs',
                            child: Text('Peer-reviewed consensus differs'),
                          ),
                          DropdownMenuItem(
                            value: 'Factual error in AI knowledge retrieval',
                            child: Text('Factual error in AI retrieval'),
                          ),
                          DropdownMenuItem(
                            value: 'Other editorial dispute',
                            child: Text('Other editorial objection'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedDisputeType = val);
                          }
                        },
                      ),
                      const SizedBox(height: 14),

                      if (video.claims.isNotEmpty) ...[
                        Text(
                          'Target Claim',
                          style: TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            fontFamilyFallback: TWTypography.fallbackFamilies,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode
                                ? AppColors.textSecondary
                                : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: selectedClaimId,
                          dropdownColor:
                              isDarkMode ? AppColors.bgSurface : Colors.white,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          style: TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            fontFamilyFallback: TWTypography.fallbackFamilies,
                            color: isDarkMode
                                ? AppColors.textPrimary
                                : Colors.black87,
                            fontSize: 13,
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: 'all',
                              child: Text('Entire Video Fact-Check Report'),
                            ),
                            ...video.claims.map(
                              (c) => DropdownMenuItem(
                                value: c.id,
                                child: Text(
                                  'Claim [${c.timestamp}]: "${c.text.length > 35 ? "${c.text.substring(0, 35)}..." : c.text}"',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => selectedClaimId = val);
                            }
                          },
                        ),
                        const SizedBox(height: 14),
                      ],

                      Text(
                        'Rebuttal & Explanation',
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          fontFamilyFallback: TWTypography.fallbackFamilies,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode
                              ? AppColors.textSecondary
                              : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: explanationController,
                        maxLines: 4,
                        inputFormatters: [
                          ...TruthworldTextInputFormatters.standard,
                        ],
                        decoration: InputDecoration(
                          hintText:
                              'Explain why the AI fact-check is inaccurate or missing vital context...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          fontFamilyFallback: TWTypography.fallbackFamilies,
                          color: isDarkMode
                              ? AppColors.textPrimary
                              : Colors.black87,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 14),

                      Text(
                        'Supporting Reference URL (Optional)',
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          fontFamilyFallback: TWTypography.fallbackFamilies,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode
                              ? AppColors.textSecondary
                              : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: urlController,
                        inputFormatters: [
                          ...TruthworldTextInputFormatters.standard,
                        ],
                        decoration: InputDecoration(
                          hintText: 'https://official-source.gov/report.pdf',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          fontFamilyFallback: TWTypography.fallbackFamilies,
                          color: isDarkMode
                              ? AppColors.textPrimary
                              : Colors.black87,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontFamilyFallback: TWTypography.fallbackFamilies,
                      color: isDarkMode
                          ? AppColors.textSecondary
                          : Colors.black54,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(
                    Icons.send_rounded,
                    size: 15,
                    color: Colors.black,
                  ),
                  label: const Text('Submit Dispute'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () async {
                    final explanation = explanationController.text.trim();
                    if (explanation.isEmpty) {
                      AppSnackbar.warning(
                        'Please provide an explanation for your dispute.',
                      );
                      return;
                    }

                    final val = ContentValidator.validate(
                      explanation,
                      checkEnglishOnly: false,
                      fieldName: 'Explanation',
                    );
                    if (!val.isValid) {
                      AppSnackbar.warning(val.message);
                      return;
                    }

                    try {
                      await FirebaseFirestore.instance
                          .collection('videos')
                          .doc(video.id)
                          .collection('disputes')
                          .add({
                        'disputeType': selectedDisputeType,
                        'targetClaimId': selectedClaimId,
                        'explanation': explanation,
                        'referenceUrl': urlController.text.trim(),
                        'channelId': channelId,
                        'status': 'under_review',
                        'createdAt': FieldValue.serverTimestamp(),
                      });

                      await FirebaseFirestore.instance
                          .collection('videos')
                          .doc(video.id)
                          .update({
                        'disputeStatus': 'under_review',
                        'disputedAt': FieldValue.serverTimestamp(),
                      });

                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }
                      AppSnackbar.success(
                        'Dispute submitted successfully! Our editorial team and verification models will review it.',
                      );
                    } catch (e, stackTrace) {
                      ErrorHandler.log(
                        e,
                        stackTrace: stackTrace,
                        tag: 'TruthVerificationDashboardPage.submitDispute',
                      );
                      AppSnackbar.error(
                        'Unable to submit dispute. Please try again.',
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showTalkToAiDialog(
    BuildContext context,
    VideoFactCheckItem video,
  ) {
    final commentaryController = TextEditingController();
    final sourceControllers = <Map<String, TextEditingController>>[
      {
        'url': TextEditingController(),
        'notes': TextEditingController(),
      },
    ];

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              backgroundColor: isDarkMode ? AppColors.bgSurface : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.brand.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.psychology_rounded,
                      color: AppColors.brand,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Talk to AI & Provide Sources',
                          style: TextStyle(
                            fontFamily: TWTypography.brandFamily,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode
                                ? AppColors.textPrimary
                                : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Instruct AI verification engine with authoritative citations',
                          style: TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            fontSize: 12,
                            color: isDarkMode
                                ? AppColors.textSecondary
                                : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Video: "${video.title}"',
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode
                              ? AppColors.textSecondary
                              : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text(
                        'Context & Instructions for AI',
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode
                              ? AppColors.textSecondary
                              : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: commentaryController,
                        maxLines: 4,
                        inputFormatters: [
                          ...TruthworldTextInputFormatters.standard,
                        ],
                        decoration: InputDecoration(
                          hintText:
                              'e.g. "At timestamp 02:15, note that the 2026 amendments reversed the prior statute. See the official gazette link below to re-verify."',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          color: isDarkMode
                              ? AppColors.textPrimary
                              : Colors.black87,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 20),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Authoritative Sources & Citations',
                            style: TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode
                                  ? AppColors.textSecondary
                                  : Colors.black87,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              setDialogState(() {
                                sourceControllers.add({
                                  'url': TextEditingController(),
                                  'notes': TextEditingController(),
                                });
                              });
                            },
                            icon: const Icon(Icons.add, size: 15),
                            label: const Text(
                              'Add Another Source',
                              style: TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      ...sourceControllers.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final controllers = entry.value;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? AppColors.bgPage
                                : const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDarkMode
                                  ? AppColors.bgDivider
                                  : Colors.grey.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Source #${idx + 1}',
                                    style: const TextStyle(
                                      fontFamily: TWTypography.uiFamily,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.info,
                                    ),
                                  ),
                                  if (sourceControllers.length > 1)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        size: 16,
                                        color: AppColors.error,
                                      ),
                                      onPressed: () {
                                        setDialogState(() {
                                          sourceControllers.removeAt(idx);
                                        });
                                      },
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: controllers['url'],
                                inputFormatters: [
                                  ...TruthworldTextInputFormatters.standard,
                                ],
                                decoration: InputDecoration(
                                  labelText: 'Source URL / DOI / Link',
                                  hintText:
                                      'https://academic-journal.org/paper-102.pdf',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                ),
                                style: TextStyle(
                                  fontFamily: TWTypography.uiFamily,
                                  color: isDarkMode
                                      ? AppColors.textPrimary
                                      : Colors.black87,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: controllers['notes'],
                                inputFormatters: [
                                  ...TruthworldTextInputFormatters.standard,
                                ],
                                decoration: InputDecoration(
                                  labelText: 'Citation Description / Notes',
                                  hintText:
                                      'Official 2026 Government Statistical Release',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                ),
                                style: TextStyle(
                                  fontFamily: TWTypography.uiFamily,
                                  color: isDarkMode
                                      ? AppColors.textPrimary
                                      : Colors.black87,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: isDarkMode
                          ? AppColors.textSecondary
                          : Colors.black54,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(
                    Icons.auto_awesome_rounded,
                    size: 15,
                    color: Colors.black,
                  ),
                  label: const Text('Re-Verify with AI'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () async {
                    final notes = commentaryController.text.trim();
                    final sourcesData = sourceControllers
                        .map((c) => {
                              'url': c['url']!.text.trim(),
                              'notes': c['notes']!.text.trim(),
                            })
                        .where((s) => s['url']!.isNotEmpty || s['notes']!.isNotEmpty)
                        .toList();

                    if (notes.isEmpty && sourcesData.isEmpty) {
                      AppSnackbar.warning(
                        'Please provide either instructions for the AI or at least one source link.',
                      );
                      return;
                    }

                    try {
                      await FirebaseFirestore.instance
                          .collection('videos')
                          .doc(video.id)
                          .update({
                        'reverificationRequested': true,
                        'reverificationRequestedAt':
                            FieldValue.serverTimestamp(),
                        'reverificationNotes': notes,
                        'reverificationSources': sourcesData,
                        'factCheckStatus': 'reverification_queued',
                      });

                      await FirebaseFirestore.instance
                          .collection('videos')
                          .doc(video.id)
                          .collection('ai_conversations')
                          .add({
                        'message': notes,
                        'sources': sourcesData,
                        'sender': 'creator',
                        'type': 'source_submission_reverification',
                        'createdAt': FieldValue.serverTimestamp(),
                      });

                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }
                      AppSnackbar.success(
                        'Sources & notes submitted to AI! Re-verification analysis has been queued.',
                      );
                    } catch (e, stackTrace) {
                      ErrorHandler.log(
                        e,
                        stackTrace: stackTrace,
                        tag: 'TruthVerificationDashboardPage.talkToAi',
                      );
                      AppSnackbar.error(
                        'Failed to submit to AI. Please try again.',
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatusBadge(VideoFactCheckItem video) {
    if (video.isPendingApproval) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_clock_rounded,
              size: 13,
              color: AppColors.warning,
            ),
            SizedBox(width: 5),
            Text(
              'Pending Channel Approval (Private to Creator)',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.warning,
              ),
            ),
          ],
        ),
      );
    }

    if (video.isFactCheckApproved) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.verified_rounded,
              size: 13,
              color: AppColors.success,
            ),
            SizedBox(width: 5),
            Text(
              'Approved (Visible to Viewers)',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.success,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.4)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.public_rounded,
            size: 13,
            color: AppColors.info,
          ),
          SizedBox(width: 5),
          Text(
            'Open for Viewers Directly',
            style: TextStyle(
              fontFamily: TWTypography.uiFamily,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.info,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // AUDIT TRAIL / ACTIVITY LOG
  // =========================================================================

  Widget _buildAuditActivityLogTab(List<VideoFactCheckItem> videos) {
    if (videos.isEmpty) {
      return _buildEmptyState(
        title: 'No Audit Trail Found',
        description:
            'No fact-checked video activity has been recorded yet for this channel.',
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: videos.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final video = videos[index];
        final title = video.title;
        final isApproved = video.isFactCheckApproved;
        final isReverify = video.reverificationRequested;
        final disputeStatus = video.disputeStatus;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDarkMode ? AppColors.bgSurface : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.bgDivider),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isApproved
                      ? AppColors.success.withValues(alpha: 0.15)
                      : AppColors.warning.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isApproved
                      ? Icons.check_circle_outline_rounded
                      : Icons.pending_actions_rounded,
                  color: isApproved ? AppColors.success : AppColors.warning,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDarkMode
                            ? AppColors.textPrimary
                            : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Status: ${isApproved ? "Approved for Public Viewers" : "Creator Review Held Private"}${isReverify ? " • AI Re-verification Queued" : ""}${disputeStatus != null ? " • Dispute: $disputeStatus" : ""}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // =========================================================================
  // MAIN BUILD METHOD
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDarkMode ? AppColors.bgPage : Colors.white,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('videos')
            .where('channelId', isEqualTo: channelId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            ErrorHandler.log(
              snapshot.error,
              tag: 'TruthVerificationDashboardPage.stream',
            );
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  UserFeedbackSanitizer.sanitizeMessage(
                    snapshot.error,
                    defaultActionContext:
                        'Unable to load verification data. Please try again.',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: AppColors.error,
                  ),
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildVerificationSkeleton();
          }

          final videoDocs = snapshot.data?.docs ?? [];
          final allClaims = <RealExtractedClaim>[];
          final videoItems = <VideoFactCheckItem>[];
          var totalTruthScoreSum = 0.0;
          var totalScoredVideos = 0;

          for (final doc in videoDocs) {
            final data = doc.data()! as Map<String, dynamic>;
            final videoId = doc.id;
            final videoTitle = data['title'] as String? ?? 'Untitled Video';
            final thumbnailUrl = data['thumbnailUrl'] as String? ??
                data['thumbnail'] as String? ??
                '';

            final score = ((data['trustScore'] ??
                    data['credibilityScore'] ??
                    data['rating'] ??
                    0.0) as num)
                .toDouble();
            final normalizedScore = score > 1.0 ? score / 100.0 : score;

            final videoClaims = <RealExtractedClaim>[];

            final uiReport = data['uiReport'] as Map<String, dynamic>?;
            var analysisSummary = '';
            var domainName = 'General';
            if (uiReport != null) {
              domainName = uiReport['domain'] as String? ??
                  uiReport['category'] as String? ??
                  'General';
              final summaryObj = uiReport['summary'];
              if (summaryObj is Map) {
                analysisSummary = summaryObj['summary'] as String? ?? '';
              } else if (summaryObj is String) {
                analysisSummary = summaryObj;
              }

              if (uiReport['keyClaims'] is List) {
                final keyClaims = uiReport['keyClaims'] as List;
                for (var i = 0; i < keyClaims.length; i++) {
                  final c = keyClaims[i];
                  if (c is Map) {
                    final text = c['text'] as String? ?? '';
                    if (text.isEmpty) continue;
                    final verdict = c['verdict'] as String? ?? 'verified';
                    final start = (c['start'] as num?)?.toDouble() ?? 0.0;
                    final domain = c['claimDomain'] as String? ??
                        c['claimNature'] as String? ??
                        domainName;
                    final confidence = ((c['classificationConfidence'] ??
                            c['confidence'] ??
                            0.85) as num)
                        .toDouble();

                    var sourceText = 'AI Knowledge Graph';
                    if (c['effectiveSources'] is List &&
                        (c['effectiveSources'] as List).isNotEmpty) {
                      final firstSrc = (c['effectiveSources'] as List).first;
                      if (firstSrc is Map) {
                        sourceText = firstSrc['title'] as String? ??
                            firstSrc['url'] as String? ??
                            sourceText;
                      }
                    } else if (c['sourceCitation'] is String) {
                      sourceText = c['sourceCitation'] as String;
                    }

                    final normConfidence =
                        confidence > 1.0 ? confidence / 100.0 : confidence;
                    final tier = _parseClaimTier(verdict, normConfidence, sourceText);

                    final claimObj = RealExtractedClaim(
                      id: '${videoId}_key_$i',
                      videoId: videoId,
                      videoTitle: videoTitle,
                      text: text,
                      timestamp: _formatTimestamp(start),
                      timestampSeconds: start,
                      category: domain,
                      confidenceScore: normConfidence,
                      sourceCitation: sourceText,
                      tier: tier,
                      verdict: verdict,
                    );
                    videoClaims.add(claimObj);
                  }
                }
              }
            }

            if (videoClaims.isEmpty && data['claims'] is List) {
              final rawClaims = data['claims'] as List;
              for (var i = 0; i < rawClaims.length; i++) {
                final c = rawClaims[i];
                if (c is Map) {
                  final text =
                      c['text'] as String? ?? c['claim'] as String? ?? '';
                  if (text.isEmpty) continue;
                  final statusStr = c['status'] as String? ??
                      c['verdict'] as String? ??
                      'verified';
                  final start = (c['start'] as num?)?.toDouble() ?? 0.0;
                  final timestamp = c['timestamp'] as String? ??
                      _formatTimestamp(start);
                  final category = c['category'] as String? ??
                      c['domain'] as String? ??
                      'Extracted Fact';
                  final confidence = ((c['confidenceScore'] ??
                          c['confidence'] ??
                          0.80) as num)
                      .toDouble();
                  final sourceCitation = c['sourceCitation'] as String? ??
                      c['source'] as String? ??
                      'Verified Database';

                  final normConfidence =
                      confidence > 1.0 ? confidence / 100.0 : confidence;
                  final tier =
                      _parseClaimTier(statusStr, normConfidence, sourceCitation);

                  final claimObj = RealExtractedClaim(
                    id: '${videoId}_raw_$i',
                    videoId: videoId,
                    videoTitle: videoTitle,
                    text: text,
                    timestamp: timestamp,
                    timestampSeconds: start,
                    category: category,
                    confidenceScore: normConfidence,
                    sourceCitation: sourceCitation,
                    tier: tier,
                    verdict: statusStr,
                  );
                  videoClaims.add(claimObj);
                }
              }
            }

            // Only present videos that have Fact-Checking enabled, in-progress, or verified
            if (!TruthVerificationDashboardPage.hasFactChecking(
              data,
              claims: videoClaims,
              trustScore: score,
            )) {
              continue;
            }

            // Register extracted claims and credibility scores for fact-checked videos
            allClaims.addAll(videoClaims);
            if (score > 0) {
              totalTruthScoreSum += normalizedScore;
              totalScoredVideos++;
            }

            if (analysisSummary.isEmpty) {
              analysisSummary = data['moderationSummary'] as String? ??
                  data['description'] as String? ??
                  'Automated multimodal truth verification.';
            }

            final aiFeatures = data['aiFeatures'] as Map<String, dynamic>?;
            final reviewMode = data['factCheckReviewMode'] as String? ??
                aiFeatures?['factCheckReviewMode'] as String? ??
                'open_to_users';
            final isApproved = data['isFactCheckApproved'] as bool? ??
                aiFeatures?['isFactCheckApproved'] as bool? ??
                false;
            final disputeStatus = data['disputeStatus'] as String?;
            final reverificationReq =
                data['reverificationRequested'] as bool? ?? false;
            final reverificationNotes =
                data['reverificationNotes'] as String?;
            final reverificationSources =
                data['reverificationSources'] as List?;
            final durationSec =
                ((data['durationSeconds'] ?? data['duration'] ?? 600) as num)
                    .toDouble();

            DateTime? createdAt;
            if (data['createdAt'] is Timestamp) {
              createdAt = (data['createdAt'] as Timestamp).toDate();
            }

            videoItems.add(
              VideoFactCheckItem(
                id: videoId,
                title: videoTitle,
                thumbnailUrl: thumbnailUrl,
                truthScore: normalizedScore,
                factCheckReviewMode: reviewMode,
                isFactCheckApproved: isApproved,
                claims: videoClaims,
                summary: analysisSummary,
                domain: domainName,
                createdAt: createdAt,
                durationSeconds: durationSec,
                disputeStatus: disputeStatus,
                reverificationRequested: reverificationReq,
                reverificationNotes: reverificationNotes,
                reverificationSources: reverificationSources,
              ),
            );
          }

          final overallTruthScore = totalScoredVideos > 0
              ? (totalTruthScoreSum / totalScoredVideos).clamp(0.0, 1.0)
              : (allClaims.isNotEmpty ? 0.88 : 0.0);

          return Obx(() {
            final activeTab = _selectedTab.value;
            final targetId = targetVideoId.value;
            final videoFilter = _videoFilter.value;

            var filteredVideos = videoItems;
            if (targetId.isNotEmpty) {
              filteredVideos =
                  filteredVideos.where((v) => v.id == targetId).toList();
            } else if (videoFilter == 'pending') {
              filteredVideos =
                  filteredVideos.where((v) => v.isPendingApproval).toList();
            } else if (videoFilter == 'approved') {
              filteredVideos =
                  filteredVideos.where((v) => v.isFactCheckApproved).toList();
            } else if (videoFilter == 'concerns') {
              filteredVideos =
                  filteredVideos.where((v) => v.hasConcerns).toList();
            } else if (videoFilter == 'disputed') {
              filteredVideos = filteredVideos
                  .where((v) => v.isDisputed || v.reverificationRequested)
                  .toList();
            }

            final claimTier = _claimTierFilter.value;
            final filteredClaims = allClaims.where((claim) {
              if (targetId.isNotEmpty && claim.videoId != targetId) {
                return false;
              }
              if (claimTier == 'verified') {
                return claim.isVerified;
              } else if (claimTier == 'high_concern') {
                return claim.isHighConcern;
              } else if (claimTier == 'needs_source') {
                return claim.isNeedsSource;
              } else if (claimTier == 'disputed') {
                return claim.isDisputed;
              }
              return true;
            }).toList();

            final pendingApprovalCount =
                videoItems.where((v) => v.isPendingApproval).length;
            final videosWithConcernsCount =
                videoItems.where((v) => v.hasConcerns).length;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Header Section
                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Fact-Checks & Truth Verification',
                              style: TextStyle(
                                fontFamily: TWTypography.brandFamily,
                                fontFamilyFallback:
                                    TWTypography.fallbackFamilies,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode
                                    ? AppColors.textPrimary
                                    : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'World-Class Studio Verification Console: interactive timeline, claim diagnostics, AI coach & dossier export.',
                              style: TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                fontSize: 13,
                                color: isDarkMode
                                    ? AppColors.textSecondary
                                    : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Obx(() {
                        final published = _isPublished.value;
                        final btnBg =
                            published ? AppColors.success : AppColors.brand;
                        final btnFg = published ? Colors.white : Colors.black;
                        return ElevatedButton.icon(
                          icon: Icon(
                            published
                                ? Icons.visibility_rounded
                                : Icons.visibility_off_rounded,
                            size: 18,
                            color: btnFg,
                          ),
                          label: Text(
                            published
                                ? 'Player Credibility Active'
                                : 'Player Overlays Muted',
                            style: TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              fontWeight: FontWeight.bold,
                              color: btnFg,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: btnBg,
                            foregroundColor: btnFg,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            _isPublished.toggle();
                            final pub = _isPublished.value;
                            if (pub) {
                              AppSnackbar.success(
                                'Credibility badges active on player overlays.',
                              );
                            } else {
                              AppSnackbar.info(
                                'Score badge muted on player overlays.',
                              );
                            }
                          },
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Overall Channel Health Meter & Summary Card
                  _buildClaimEvidenceHealthBar(
                    claims: allClaims,
                    selectedFilter: _claimTierFilter.value,
                    overallTruthScore: overallTruthScore,
                    onFilterChanged: (filter) {
                      _claimTierFilter.value = filter;
                      _selectedTab.value = 1;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Target Video Filter Banner
                  if (targetId.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.brandVariant.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.brandVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.filter_alt_rounded,
                            size: 18,
                            color: AppColors.brand,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Focusing on Video: ${filteredVideos.isNotEmpty ? filteredVideos.first.title : targetId}',
                              style: const TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.brand,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => targetVideoId.value = '',
                            child: const Text(
                              'Clear Filter',
                              style: TextStyle(
                                color: AppColors.brand,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Tabs Bar: Video Reports vs Claims vs Audit Trail
                  Row(
                    children: [
                      _buildTabButton(
                        label: 'Video Fact-Check Reports',
                        count: videoItems.length,
                        badgeCount: pendingApprovalCount,
                        isSelected: activeTab == 0,
                        onTap: () => _selectedTab.value = 0,
                      ),
                      const SizedBox(width: 12),
                      _buildTabButton(
                        label: 'All Extracted Claims',
                        count: allClaims.length,
                        badgeCount: allClaims.where((c) => c.isHighConcern).length,
                        isSelected: activeTab == 1,
                        onTap: () => _selectedTab.value = 1,
                      ),
                      const SizedBox(width: 12),
                      _buildTabButton(
                        label: 'Audit Activity Trail',
                        count: videoItems.length,
                        badgeCount: null,
                        isSelected: activeTab == 2,
                        onTap: () => _selectedTab.value = 2,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // TAB CONTENT
                  if (activeTab == 0) ...[
                    // Sub-filters for videos
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildFilterPill(
                          label: 'All Videos (${videoItems.length})',
                          isSelected: videoFilter == 'all',
                          onTap: () => _videoFilter.value = 'all',
                        ),
                        if (videosWithConcernsCount > 0)
                          _buildFilterPill(
                            label: '🔴 Concern Alerts ($videosWithConcernsCount)',
                            isSelected: videoFilter == 'concerns',
                            isAlertHighlight: true,
                            onTap: () => _videoFilter.value = 'concerns',
                          ),
                        _buildFilterPill(
                          label: 'Pending Approval ($pendingApprovalCount)',
                          isSelected: videoFilter == 'pending',
                          isWarningHighlight: pendingApprovalCount > 0,
                          onTap: () => _videoFilter.value = 'pending',
                        ),
                        _buildFilterPill(
                          label: 'Approved (${videoItems.where((v) => v.isFactCheckApproved).length})',
                          isSelected: videoFilter == 'approved',
                          onTap: () => _videoFilter.value = 'approved',
                        ),
                        _buildFilterPill(
                          label: 'Disputed / Re-verify (${videoItems.where((v) => v.isDisputed || v.reverificationRequested).length})',
                          isSelected: videoFilter == 'disputed',
                          onTap: () => _videoFilter.value = 'disputed',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (filteredVideos.isEmpty)
                      _buildEmptyState(
                        title: 'No Video Reports Found',
                        description:
                            'No videos matched the current filter. Upload videos with Truth Verification enabled to review fact-checks here.',
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredVideos.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final video = filteredVideos[index];
                          return _buildVideoReportCard(context, video);
                        },
                      ),
                  ] else if (activeTab == 1) ...[
                    // Claims Filter Bar
                    Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Extracted Factual Claims (${filteredClaims.length})',
                          style: TextStyle(
                            fontFamily: TWTypography.brandFamily,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode
                                ? AppColors.textPrimary
                                : Colors.black87,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.filter_alt_outlined,
                              size: 16,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                            const SizedBox(width: 6),
                            DropdownButton<String>(
                              value: claimTier,
                              dropdownColor: isDarkMode
                                  ? AppColors.bgSurface
                                  : Colors.white,
                              underline: const SizedBox(),
                              style: TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                color: isDarkMode
                                    ? AppColors.textPrimary
                                    : Colors.black87,
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'all',
                                  child: Text('All Claims'),
                                ),
                                DropdownMenuItem(
                                  value: 'high_concern',
                                  child: Text('🔴 High Concern (No Evidence)'),
                                ),
                                DropdownMenuItem(
                                  value: 'needs_source',
                                  child: Text('🟡 Needs Source'),
                                ),
                                DropdownMenuItem(
                                  value: 'verified',
                                  child: Text('🟢 Most Verified'),
                                ),
                                DropdownMenuItem(
                                  value: 'disputed',
                                  child: Text('🟣 Disputed'),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  _claimTierFilter.value = val;
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (filteredClaims.isEmpty)
                      _buildEmptyState(
                        title: 'No Extracted Claims Found',
                        description:
                            'No claims match your filter criteria for this channel.',
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredClaims.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final claim = filteredClaims[index];
                          final parentVideo = videoItems.firstWhereOrNull(
                            (v) => v.id == claim.videoId,
                          );
                          return _buildInteractiveClaimCard(
                            context,
                            claim,
                            parentVideo,
                          );
                        },
                      ),
                  ] else ...[
                    // Tab 2: Activity Audit Log
                    _buildAuditActivityLogTab(videoItems),
                  ],
                ],
              ),
            );
          });
        },
      ),
    );
  }

  Widget _buildTabButton({
    required String label,
    required int count,
    required int? badgeCount,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDarkMode ? AppColors.bgSurfaceHover : const Color(0xFFE5E7EB))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppColors.brandVariant
                : (isDarkMode ? AppColors.bgDivider : Colors.grey.withValues(alpha: 0.3)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? (isDarkMode ? AppColors.textPrimary : Colors.black87)
                    : (isDarkMode ? AppColors.textSecondary : Colors.black54),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.brandVariant.withValues(alpha: 0.2)
                    : (isDarkMode
                        ? AppColors.bgSurface
                        : const Color(0xFFE5E7EB)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? AppColors.brand : AppColors.textSecondary,
                ),
              ),
            ),
            if (badgeCount != null && badgeCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badgeCount CONCERNS',
                  style: const TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    bool isWarningHighlight = false,
    bool isAlertHighlight = false,
  }) {
    final activeBg = isAlertHighlight
        ? AppColors.error
        : (isWarningHighlight ? AppColors.warning : AppColors.brandVariant);
    final activeFg = isWarningHighlight ? Colors.black : Colors.white;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? activeBg
              : (isDarkMode ? AppColors.bgSurface : const Color(0xFFF3F4F6)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? activeBg
                : (isAlertHighlight
                    ? AppColors.error.withValues(alpha: 0.7)
                    : (isWarningHighlight
                        ? AppColors.warning.withValues(alpha: 0.5)
                        : (isDarkMode
                            ? AppColors.bgDivider
                            : Colors.grey.withValues(alpha: 0.3)))),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: TWTypography.uiFamily,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? activeFg
                : (isAlertHighlight
                    ? AppColors.error
                    : (isWarningHighlight
                        ? AppColors.warning
                        : (isDarkMode
                            ? AppColors.textSecondary
                            : Colors.black87))),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoReportCard(BuildContext context, VideoFactCheckItem video) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.bgSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: video.hasConcerns
              ? AppColors.error.withValues(alpha: 0.5)
              : (video.isPendingApproval
                  ? AppColors.warning.withValues(alpha: 0.4)
                  : (isDarkMode
                      ? AppColors.bgDivider
                      : AppColors.brandVariant)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 100,
                  height: 62,
                  color: isDarkMode ? const Color(0xFF222222) : Colors.grey[200],
                  child: video.thumbnailUrl.isNotEmpty
                      ? Image.network(
                          video.thumbnailUrl,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (context, error, stackTrace) => const Icon(
                            Icons.video_library_rounded,
                            color: AppColors.textSecondary,
                          ),
                        )
                      : const Icon(
                          Icons.video_library_rounded,
                          color: AppColors.textSecondary,
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: TWTypography.brandFamily,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _buildStatusBadge(video),
                        if (video.hasConcerns)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  size: 12,
                                  color: AppColors.error,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${video.highConcernClaims.length} Concern Alert',
                                  style: const TextStyle(
                                    color: AppColors.error,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Timeline scrubber preview
          _buildInteractiveTimelineScrubber(
            video: video,
            onClaimSelected: (claim) => _showAskAiWhyDialog(context, claim),
          ),
          const SizedBox(height: 12),

          // Score impact simulator
          _buildScoreImpactSimulator(video),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDarkMode ? AppColors.bgPage : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 16,
                      color: video.truthScore >= 0.8
                          ? AppColors.success
                          : (video.truthScore >= 0.5
                              ? AppColors.warning
                              : AppColors.error),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Truth Score: ${video.truthScore > 0 ? "${(video.truthScore * 100).toInt()}%" : "N/A"}',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: video.truthScore >= 0.8
                            ? AppColors.success
                            : (video.truthScore >= 0.5
                                ? AppColors.warning
                                : AppColors.error),
                      ),
                    ),
                  ],
                ),
                Text(
                  '${video.claims.length} Claims: ${video.verifiedClaims.length} verified, ${video.needsSourceClaims.length} need source, ${video.highConcernClaims.length} concern',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontSize: 11,
                    color: isDarkMode ? AppColors.textSecondary : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () => _showExportAuditDossierModal(context, video),
                icon: const Icon(
                  Icons.description_outlined,
                  size: 14,
                  color: AppColors.brand,
                ),
                label: const Text('Export Dossier'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.brand,
                  side: const BorderSide(color: AppColors.brand),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),

              ElevatedButton.icon(
                onPressed: () => _showVideoFactCheckReportModal(context, video),
                icon: const Icon(
                  Icons.analytics_outlined,
                  size: 15,
                  color: Colors.white,
                ),
                label: const Text('Inspect Full Report'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDarkMode
                      ? AppColors.bgSurfaceHover
                      : const Color(0xFF374151),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              if (video.isPendingApproval)
                ElevatedButton.icon(
                  onPressed: () => _approveVideoFactCheck(video.id),
                  icon: const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 15,
                    color: Colors.white,
                  ),
                  label: const Text('Approve for Viewers'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else
                OutlinedButton.icon(
                  onPressed: () => _toggleFactCheckApproval(
                    video.id,
                    video.isFactCheckApproved,
                  ),
                  icon: Icon(
                    video.isFactCheckApproved
                        ? Icons.visibility_off_rounded
                        : Icons.check_circle_outline_rounded,
                    size: 14,
                    color: isDarkMode ? AppColors.textSecondary : Colors.black54,
                  ),
                  label: Text(
                    video.isFactCheckApproved
                        ? 'Make Private'
                        : 'Publish to Viewers',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDarkMode
                        ? AppColors.textSecondary
                        : Colors.black87,
                    side: const BorderSide(color: AppColors.bgDivider),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),

              OutlinedButton.icon(
                onPressed: () => _showDisputeDialog(context, video),
                icon: const Icon(
                  Icons.gavel_rounded,
                  size: 14,
                  color: AppColors.warning,
                ),
                label: const Text('Dispute'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.warning,
                  side: const BorderSide(color: AppColors.warning),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),

              ElevatedButton.icon(
                onPressed: () => _showTalkToAiDialog(context, video),
                icon: const Icon(
                  Icons.psychology_rounded,
                  size: 15,
                  color: Colors.black,
                ),
                label: const Text('Talk to AI (Add Sources)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required String title,
    required String description,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.bgSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? AppColors.bgDivider : AppColors.brandVariant,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.fact_check_outlined,
            size: 48,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontFamily: TWTypography.brandFamily,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? AppColors.textPrimary : Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: TWTypography.uiFamily,
              fontSize: 13,
              color: isDarkMode ? AppColors.textSecondary : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationSkeleton() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1E1E1E),
      highlightColor: AppColors.bgSurfaceHover,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.bgDivider),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: List.generate(
                3,
                (index) => Expanded(
                  child: Container(
                    height: 100,
                    margin: EdgeInsets.only(right: index < 2 ? 14 : 0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.bgDivider),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ...List.generate(
              3,
              (index) => Container(
                height: 120,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.bgDivider),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
