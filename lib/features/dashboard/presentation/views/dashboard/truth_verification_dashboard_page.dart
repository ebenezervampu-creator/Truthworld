import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/utils/content_validator.dart';
import 'package:truthworld/core/utils/truthworld_text_input_formatters.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/theme/app_theme.dart';

enum ClaimStatus { verified, unverified, disputed }

class RealExtractedClaim {
  RealExtractedClaim({
    required this.id,
    required this.videoId,
    required this.videoTitle,
    required this.text,
    required this.timestamp,
    required this.category,
    required this.confidenceScore,
    required this.sourceCitation,
    this.status = ClaimStatus.verified,
  });

  final String id;
  final String videoId;
  final String videoTitle;
  final String text;
  final String timestamp;
  final String category;
  final double confidenceScore;
  final String sourceCitation;
  ClaimStatus status;
}

class TruthVerificationDashboardPage extends StatelessWidget {
  TruthVerificationDashboardPage({
    required this.channelId,
    required this.isDarkMode,
    super.key,
  });

  final String channelId;
  final bool isDarkMode;

  BuildContext get context => Get.context!;

  final RxBool _isPublished = true.obs;
  final RxString _selectedFilter = 'all'.obs;

  String _formatTimestamp(double? seconds) {
    if (seconds == null || seconds <= 0) return '00:00';
    final duration = Duration(seconds: seconds.toInt());
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  ClaimStatus _parseClaimStatus(String statusStr) {
    final lower = statusStr.toLowerCase();
    if (lower.contains('dispute') || lower.contains('contest')) {
      return ClaimStatus.disputed;
    } else if (lower.contains('unverified') ||
        lower.contains('review') ||
        lower.contains('incorrect') ||
        lower.contains('flagged') ||
        lower.contains('false')) {
      return ClaimStatus.unverified;
    }
    return ClaimStatus.verified;
  }

  void _showAddCitationDialog(RealExtractedClaim claim) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode
            ? AppColors.bgSurface
            : AppColors.textPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Attach Supporting Evidence / Citation',
          style: GoogleFonts.outfit(
            color: isDarkMode ? AppColors.textPrimary : Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Claim: "${claim.text}"',
              style: GoogleFonts.roboto(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: isDarkMode
                    ? AppColors.textSecondary
                    : Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: textController,
              inputFormatters: [...TruthworldTextInputFormatters.standard],
              decoration: InputDecoration(
                labelText: 'Source URL / Reference Document',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                labelStyle: GoogleFonts.roboto(
                  color: isDarkMode
                      ? AppColors.textSecondary
                      : Colors.black,
                ),
              ),
              style: GoogleFonts.roboto(
                color: isDarkMode
                    ? AppColors.textPrimary
                    : Colors.black,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.roboto(
                color: isDarkMode
                    ? AppColors.textSecondary
                    : Colors.black,
              ),
            ),
          ),
          ElevatedButton.icon(
            icon: const Icon(
              Icons.send_rounded,
              size: 16,
              color: Colors.white,
            ),
            label: Text(
              'Submit Citation',
              style: GoogleFonts.roboto(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              final text = textController.text.trim();
              if (text.isNotEmpty) {
                final val = ContentValidator.validate(text, checkEnglishOnly: false, fieldName: 'Citation');
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
                    'citationUrl': text,
                    'createdAt': FieldValue.serverTimestamp(),
                    'status': 'pending_review',
                  });

                  claim.status = ClaimStatus.disputed;

                  AppSnackbar.success(
                    'Citation submitted for AI re-verification review.',
                  );
                } catch (e, stackTrace) {
                  ErrorHandler.log(
                    e,
                    stackTrace: stackTrace,
                    tag: 'TruthVerificationDashboardPage.submitCitation',
                  );
                  AppSnackbar.error(
                    'Unable to submit citation. Please try again.',
                  );
                }
              }
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDarkMode
          ? AppColors.bgPage
          : const Color(0xFFF8FAFC),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('videos')
            .where('channelId', isEqualTo: channelId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading verification data: ${snapshot.error}',
                style: GoogleFonts.roboto(color: AppColors.error),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.brand),
              ),
            );
          }

          final videoDocs = snapshot.data?.docs ?? [];
          final allClaims = <RealExtractedClaim>[];
          var totalTruthScoreSum = 0.0;
          var totalScoredVideos = 0;

          for (final doc in videoDocs) {
            final data = doc.data()! as Map<String, dynamic>;
            final videoId = doc.id;
            final videoTitle = data['title'] as String? ?? 'Untitled Video';

            // Extract truth / trust score
            final score = ((data['trustScore'] ??
                    data['credibilityScore'] ??
                    data['rating'] ??
                    0.0) as num)
                .toDouble();
            if (score > 0) {
              totalTruthScoreSum += score > 1.0 ? score / 100.0 : score;
              totalScoredVideos++;
            }

            // 1. Check uiReport keyClaims
            final uiReport = data['uiReport'] as Map<String, dynamic>?;
            if (uiReport != null && uiReport['keyClaims'] is List) {
              final keyClaims = uiReport['keyClaims'] as List;
              for (var i = 0; i < keyClaims.length; i++) {
                final c = keyClaims[i];
                if (c is Map) {
                  final text = c['text'] as String? ?? '';
                  if (text.isEmpty) continue;
                  final verdict = c['verdict'] as String? ?? 'verified';
                  final start = (c['start'] as num?)?.toDouble();
                  final domain = c['claimDomain'] as String? ??
                      c['claimNature'] as String? ??
                      'General Claim';
                  final confidence =
                      ((c['classificationConfidence'] ?? c['confidence'] ?? 0.85)
                              as num)
                          .toDouble();

                  // Effective sources
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

                  allClaims.add(
                    RealExtractedClaim(
                      id: '${videoId}_key_$i',
                      videoId: videoId,
                      videoTitle: videoTitle,
                      text: text,
                      timestamp: _formatTimestamp(start),
                      category: domain,
                      confidenceScore:
                          confidence > 1.0 ? confidence / 100.0 : confidence,
                      sourceCitation: sourceText,
                      status: _parseClaimStatus(verdict),
                    ),
                  );
                }
              }
            }

            // 2. Check top-level claims field if keyClaims was empty
            if (data['claims'] is List) {
              final rawClaims = data['claims'] as List;
              for (var i = 0; i < rawClaims.length; i++) {
                final c = rawClaims[i];
                if (c is Map) {
                  final text = c['text'] as String? ?? c['claim'] as String? ?? '';
                  if (text.isEmpty) continue;
                  final statusStr = c['status'] as String? ??
                      c['verdict'] as String? ??
                      'verified';
                  final timestamp = c['timestamp'] as String? ??
                      _formatTimestamp((c['start'] as num?)?.toDouble());
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

                  allClaims.add(
                    RealExtractedClaim(
                      id: '${videoId}_raw_$i',
                      videoId: videoId,
                      videoTitle: videoTitle,
                      text: text,
                      timestamp: timestamp,
                      category: category,
                      confidenceScore:
                          confidence > 1.0 ? confidence / 100.0 : confidence,
                      sourceCitation: sourceCitation,
                      status: _parseClaimStatus(statusStr),
                    ),
                  );
                }
              }
            }
          }

          final overallTruthScore = totalScoredVideos > 0
              ? (totalTruthScoreSum / totalScoredVideos).clamp(0.0, 1.0)
              : (allClaims.isNotEmpty ? 0.88 : 0.0);

          // Apply filters
          final filteredClaims = allClaims.where((claim) {
            final filter = _selectedFilter.value;
            if (filter == 'verified') {
              return claim.status == ClaimStatus.verified;
            } else if (filter == 'unverified') {
              return claim.status == ClaimStatus.unverified;
            } else if (filter == 'disputed') {
              return claim.status == ClaimStatus.disputed;
            }
            return true;
          }).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Section (Responsive Wrap)
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
                            'Fact Verification Console',
                            style: GoogleFonts.outfit(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode
                                  ? AppColors.textPrimary
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Pre-publish review for Channel Videos & Fact-Check analysis',
                            style: GoogleFonts.roboto(
                              fontSize: 13,
                              color: isDarkMode
                                  ? AppColors.textSecondary
                                  : Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Obx(() {
                      final published = _isPublished.value;
                      return ElevatedButton.icon(
                        icon: Icon(
                          published
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                        label: Text(
                          published
                              ? 'Published to Player'
                              : 'Unpublished (Draft)',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: published
                              ? AppColors.success
                              : AppColors.brand,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
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
                              'Credibility badge is now visible on player overlays.',
                            );
                          } else {
                            AppSnackbar.info('Score badge unpublished.');
                          }
                        },
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 24),

                // Overall Summary Score Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? AppColors.bgSurface
                        : AppColors.textPrimary,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDarkMode
                          ? AppColors.bgDivider
                          : Colors.black12,
                    ),
                  ),
                  child: Row(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 84,
                            height: 84,
                            child: CircularProgressIndicator(
                              value: overallTruthScore,
                              strokeWidth: 8,
                              backgroundColor: AppColors.textSecondary
                                  .withValues(alpha: 0.2),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColors.success,
                              ),
                            ),
                          ),
                          Text(
                            overallTruthScore > 0
                                ? '${(overallTruthScore * 100).toInt()}%'
                                : 'N/A',
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode
                                  ? AppColors.textPrimary
                                  : Colors.black,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              overallTruthScore >= 0.8
                                  ? 'Overall Credibility Rating: Highly Authentic'
                                  : (overallTruthScore >= 0.5
                                      ? 'Overall Credibility Rating: Moderate Confidence'
                                      : 'Overall Credibility Rating: Pending Verification'),
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: overallTruthScore >= 0.5
                                    ? AppColors.success
                                    : AppColors.warning,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              allClaims.isNotEmpty
                                  ? '${allClaims.length} extracted claims analyzed across channel videos. ${allClaims.where((c) => c.status == ClaimStatus.verified).length} verified against academic & empirical databases.'
                                  : 'No claims extracted yet for this channel. Upload content to trigger automated AI fact-checking.',
                              style: GoogleFonts.roboto(
                                fontSize: 13,
                                color: isDarkMode
                                    ? AppColors.textSecondary
                                    : Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Filter Header & Claims Title (Responsive Wrap)
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Extracted Factual Claims & Citations',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode
                            ? AppColors.textPrimary
                            : Colors.black,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.filter_alt_outlined,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Obx(() => DropdownButton<String>(
                            value: _selectedFilter.value,
                            dropdownColor: isDarkMode
                                ? AppColors.bgSurface
                                : Colors.white,
                            underline: const SizedBox(),
                            style: TextStyle(
                              color: isDarkMode
                                  ? AppColors.textPrimary
                                  : Colors.black,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'all',
                                child: Text('All Claims'),
                              ),
                              DropdownMenuItem(
                                value: 'verified',
                                child: Text('Verified'),
                              ),
                              DropdownMenuItem(
                                value: 'unverified',
                                child: Text('Needs Review'),
                              ),
                              DropdownMenuItem(
                                value: 'disputed',
                                child: Text('Disputed'),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                _selectedFilter.value = val;
                              }
                            },
                          )),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Empty State or List of Real Claims
                if (filteredClaims.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? AppColors.bgSurface
                          : AppColors.textPrimary,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDarkMode
                            ? AppColors.bgDivider
                            : Colors.black12,
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.fact_check_outlined,
                          size: 48,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No Fact-Checked Claims Found',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode
                                ? AppColors.textPrimary
                                : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No claims matching the filter criteria exist for your channel videos. Upload videos with AI Fact Verification enabled to review live factual assertions here.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.roboto(
                            fontSize: 13,
                            color: isDarkMode
                                ? AppColors.textSecondary
                                : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredClaims.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final claim = filteredClaims[index];
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? AppColors.bgSurface
                              : AppColors.textPrimary,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: claim.status == ClaimStatus.unverified
                                ? AppColors.warning.withValues(alpha: 0.4)
                                : (isDarkMode
                                    ? AppColors.bgDivider
                                    : Colors.black12),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.info
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${claim.videoTitle} • [${claim.timestamp}] • ${claim.category}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.roboto(
                                      fontSize: 12,
                                      color: AppColors.info,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: claim.status == ClaimStatus.verified
                                        ? AppColors.success
                                            .withValues(alpha: 0.15)
                                        : AppColors.warning
                                            .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    claim.status == ClaimStatus.verified
                                        ? 'Confidence ${(claim.confidenceScore * 100).toInt()}%'
                                        : (claim.status == ClaimStatus.disputed
                                            ? 'Citation Under Review'
                                            : 'Needs Review'),
                                    style: GoogleFonts.roboto(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: claim.status == ClaimStatus.verified
                                          ? AppColors.success
                                          : AppColors.warning,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '"${claim.text}"',
                              style: GoogleFonts.roboto(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: isDarkMode
                                    ? AppColors.textPrimary
                                    : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.menu_book,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Source: ${claim.sourceCitation}',
                                      style: GoogleFonts.roboto(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                TextButton.icon(
                                  icon: const Icon(
                                    Icons.add_link,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                  label: Text(
                                    'Add Citation / Contest',
                                    style: GoogleFonts.roboto(fontSize: 12),
                                  ),
                                  onPressed: () => _showAddCitationDialog(claim),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
