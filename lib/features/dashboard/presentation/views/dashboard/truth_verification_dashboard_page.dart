import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/theme/app_theme.dart';

enum ClaimStatus { verified, unverified, disputed }

class ExtractedClaim {
  ExtractedClaim({
    required this.id,
    required this.text,
    required this.timestamp,
    required this.category,
    required this.confidenceScore,
    required this.sourceCitation,
    this.status = ClaimStatus.verified,
  });
  final String id;
  final String text;
  final String timestamp;
  final String category;
  final double confidenceScore;
  final String sourceCitation;
  ClaimStatus status;
}

class TruthVerificationDashboardPage extends StatefulWidget {
  const TruthVerificationDashboardPage({
    required this.channelId,
    required this.isDarkMode,
    super.key,
  });
  final String channelId;
  final bool isDarkMode;

  @override
  State<TruthVerificationDashboardPage> createState() =>
      _TruthVerificationDashboardPageState();
}

class _TruthVerificationDashboardPageState
    extends State<TruthVerificationDashboardPage> {
  final RxList<ExtractedClaim> _claims = <ExtractedClaim>[
    ExtractedClaim(
      id: 'c1',
      text:
          'Global solar energy generation increased by 22% year-over-year in 2025.',
      timestamp: '02:14',
      category: 'Energy Statistics',
      confidenceScore: 0.94,
      sourceCitation: 'International Energy Agency (IEA) 2025 Annual Review',
    ),
    ExtractedClaim(
      id: 'c2',
      text:
          'Over 80% of urban transit networks currently run exclusively on hydrogen fuel cells.',
      timestamp: '06:45',
      category: 'Infrastructure',
      confidenceScore: 0.42,
      sourceCitation:
          'World Transit Database 2025 (Claim unverified - actual figure is ~14%)',
      status: ClaimStatus.unverified,
    ),
    ExtractedClaim(
      id: 'c3',
      text:
          'Battery recycling efficiency surpassed 95% threshold across tier-1 facilities.',
      timestamp: '11:20',
      category: 'Clean Technology',
      confidenceScore: 0.88,
      sourceCitation: 'Clean Tech Journal Vol. 48',
    ),
  ].obs;

  final RxBool _isPublished = false.obs;

  void _showAddCitationDialog(ExtractedClaim claim) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: widget.isDarkMode
            ? const Color(0xFF1E222B)
            : AppColors.textPrimary,
        title: Text(
          'Attach Supporting Evidence / Citation',
          style: TextStyle(
            color: widget.isDarkMode ? AppColors.textPrimary : AppColors.bgPage,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Claim: "${claim.text}"',
              style: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: widget.isDarkMode
                    ? AppColors.textSecondary
                    : AppColors.bgPage,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: textController,
              decoration: InputDecoration(
                labelText: 'Source URL / Reference Document',
                border: const OutlineInputBorder(),
                labelStyle: TextStyle(
                  color: widget.isDarkMode
                      ? AppColors.textSecondary
                      : AppColors.bgPage54,
                ),
              ),
              style: TextStyle(
                color: widget.isDarkMode
                    ? AppColors.textPrimary
                    : AppColors.bgPage,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
            ),
            onPressed: () {
              if (textController.text.isNotEmpty) {
                claim.status = ClaimStatus.disputed;
                _claims.refresh();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Citation submitted for AI re-verification review.',
                    ),
                  ),
                );
              }
              Navigator.pop(context);
            },
            child: const Text(
              'Submit Citation',
              style: TextStyle(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const overallTruthScore = 0.88; // 88% overall credibility rating

    return Scaffold(
      backgroundColor: widget.isDarkMode
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Truth Verification Console',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: widget.isDarkMode
                            ? AppColors.textPrimary
                            : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pre-publish review for Path 1 Credibility & Fact-Check analysis',
                      style: TextStyle(
                        fontSize: 13,
                        color: widget.isDarkMode
                            ? AppColors.textSecondary
                            : AppColors.bgPage54,
                      ),
                    ),
                  ],
                ),
                Obx(
                  () => ElevatedButton.icon(
                    icon: Icon(
                      _isPublished.value ? Icons.verified : Icons.publish,
                      color: AppColors.textPrimary,
                    ),
                    label: Text(
                      _isPublished.value
                          ? 'Score Badge Published'
                          : 'Approve & Publish Score Badge',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isPublished.value
                          ? const Color(0xFF10B981)
                          : const Color(0xFF8B5CF6),
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            _isPublished.value
                                ? 'Credibility badge is now visible on player overlays.'
                                : 'Score badge unpublished.',
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Summary Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: widget.isDarkMode
                    ? const Color(0xFF1E293B)
                    : AppColors.textPrimary,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: widget.isDarkMode
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
                          backgroundColor: AppColors.textSecondary.withValues(
                            alpha: 0.2,
                          ),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF10B981),
                          ),
                        ),
                      ),
                      Text(
                        '${(overallTruthScore * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: widget.isDarkMode
                              ? AppColors.textPrimary
                              : AppColors.bgPage,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Overall Credibility Rating: Highly Authentic',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF10B981),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '3 extracted claims analyzed. 2 verified against academic databases, 1 claim flagged for unverified statistical assertion.',
                          style: TextStyle(
                            fontSize: 13,
                            color: widget.isDarkMode
                                ? AppColors.textSecondary
                                : AppColors.bgPage,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Extracted Factual Claims & Citations',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: widget.isDarkMode
                    ? AppColors.textPrimary
                    : AppColors.bgPage,
              ),
            ),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _claims.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final claim = _claims[index];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: widget.isDarkMode
                        ? const Color(0xFF1E293B)
                        : AppColors.textPrimary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: claim.status == ClaimStatus.unverified
                          ? AppColors.warning.withValues(alpha: 0.4)
                          : widget.isDarkMode
                          ? AppColors.bgDivider
                          : Colors.black12,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.info.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Timestamp [${claim.timestamp}] • ${claim.category}',
                              style: const TextStyle(
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
                                  ? AppColors.success.withValues(alpha: 0.15)
                                  : AppColors.warning.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              claim.status == ClaimStatus.verified
                                  ? 'Confidence ${(claim.confidenceScore * 100).toInt()}%'
                                  : 'Needs Review',
                              style: TextStyle(
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
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: widget.isDarkMode
                              ? AppColors.textPrimary
                              : AppColors.bgPage,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.menu_book,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Source: ${claim.sourceCitation}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.add_link, size: 14),
                            label: const Text(
                              'Add Citation / Contest',
                              style: TextStyle(fontSize: 12),
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
      ),
    );
  }
}
