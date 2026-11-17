import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/data/models/claim_verdict_helper.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/widgets/analysis/video_analysis_claim_card.dart';
import 'package:truthworld/features/video/presentation/widgets/analysis/video_analysis_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// 🏛 VideoAnalysisClaimsSection
///
/// Section displaying the interactive list of Fact-Checked Claims:
/// - Section Header with total claim count, search toggle, and sort dropdown
/// - Filter Capsule Pills (All, Verified, Caution, False)
/// - List of claims matching exact visual design
class VideoAnalysisClaimsSection extends StatelessWidget {
  final List<dynamic> claims;
  final List<dynamic> allSources;
  final VideoController videoCtrl;
  final VideoAnalysisController analysisCtrl;
  final Video video;
  final int verifiedCount;
  final int cautionCount;
  final int falseCount;

  const VideoAnalysisClaimsSection({
    required this.claims,
    required this.allSources,
    required this.videoCtrl,
    required this.analysisCtrl,
    required this.video,
    this.verifiedCount = 0,
    this.cautionCount = 0,
    this.falseCount = 0,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. SECTION HEADER (Title, Search Button, Sort Menu)
        Obx(() {
          final isSearchOpen = analysisCtrl.isSearchOpen.value;
          final sortOrder = analysisCtrl.sortOrder.value;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.article_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            'Fact-Checked Claims (${claims.length})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Search toggle button
                  IconButton(
                    icon: Icon(
                      isSearchOpen ? Icons.close_rounded : Icons.search_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                    tooltip: isSearchOpen ? 'Close Search' : 'Search Claims',
                    onPressed: analysisCtrl.toggleSearch,
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 6),

                  // Sort Dropdown Pill
                  PopupMenuButton<String>(
                    onSelected: analysisCtrl.setSortOrder,
                    color: AppColors.bgSurface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    itemBuilder: (ctx) => [
                      _buildPopupItem('Video Order', sortOrder == 'Video Order'),
                      _buildPopupItem('Highest Confidence', sortOrder == 'Highest Confidence'),
                      _buildPopupItem('Disputed First', sortOrder == 'Disputed First'),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5.5),
                      decoration: BoxDecoration(
                        color: AppColors.bgSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 85),
                            child: Text(
                              _getSortLabel(sortOrder),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 15,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Inline Search TextField (if open)
              if (isSearchOpen) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: TextField(
                    autofocus: true,
                    style: TextStyle(color: Colors.white, fontSize: 13.5),
                    decoration: InputDecoration(
                      hintText: 'Search verified claim statements…',
                      hintStyle: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 13,
                      ),
                      icon: const Icon(Icons.search_rounded, size: 18, color: AppColors.textTertiary),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onChanged: analysisCtrl.setSearchQuery,
                  ),
                ),
              ],
            ],
          );
        }),
        const SizedBox(height: 12),

        // 2. FILTER CAPSULE PILLS ROW (All, Verified, Caution, False)
        Obx(() {
          final current = analysisCtrl.selectedClaimFilter.value;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterPill(
                  filterKey: 'All',
                  label: 'All (${claims.length})',
                  isSelected: current == 'All',
                ),
                const SizedBox(width: 8),
                _buildFilterPill(
                  filterKey: 'Verified',
                  label: 'Verified ($verifiedCount)',
                  dotColor: AppColors.success,
                  isSelected: current == 'Verified',
                ),
                const SizedBox(width: 8),
                _buildFilterPill(
                  filterKey: 'Caution',
                  label: 'Caution ($cautionCount)',
                  dotColor: AppColors.warning,
                  isSelected: current == 'Caution',
                ),
                const SizedBox(width: 8),
                _buildFilterPill(
                  filterKey: 'False',
                  label: 'False ($falseCount)',
                  dotColor: AppColors.error,
                  isSelected: current == 'False',
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 14),

        // 3. CLAIMS LIST
        Obx(() {
          final filter = analysisCtrl.selectedClaimFilter.value;
          final search = analysisCtrl.searchQuery.value.trim().toLowerCase();
          final sort = analysisCtrl.sortOrder.value;

          final workingList = claims.where((c) {
            if (c is! Map) return false;
            if (filter != 'All') {
              final verdict = ClaimVerdictHelper.resolveVerdict(c);
              if (filter == 'Verified' && !verdict.isVerified) return false;
              if (filter == 'False' && !verdict.isFalse) return false;
              if (filter == 'Caution' && !verdict.isCaution) return false;
            }
            if (search.isNotEmpty) {
              final text = (c['claim'] ?? c['text'] ?? c['statement'] ?? '').toString().toLowerCase();
              if (!text.contains(search)) return false;
            }
            return true;
          }).toList();

          // Apply Sorting
          if (sort == 'Disputed First') {
            workingList.sort((a, b) {
              final vA = ClaimVerdictHelper.resolveVerdict(a as Map);
              final vB = ClaimVerdictHelper.resolveVerdict(b as Map);
              final rankA = vA.isFalse ? 0 : (vA.isCaution ? 1 : 2);
              final rankB = vB.isFalse ? 0 : (vB.isCaution ? 1 : 2);
              return rankA.compareTo(rankB);
            });
          } else if (sort == 'Highest Confidence') {
            workingList.sort((a, b) {
              final vA = ClaimVerdictHelper.resolveVerdict(a as Map);
              final vB = ClaimVerdictHelper.resolveVerdict(b as Map);
              final scoreA = (a['confidence'] is num) ? (a['confidence'] as num).toDouble() : (vA.isVerified ? 1.0 : 0.5);
              final scoreB = (b['confidence'] is num) ? (b['confidence'] as num).toDouble() : (vB.isVerified ? 1.0 : 0.5);
              return scoreB.compareTo(scoreA);
            });
          }

          if (workingList.isEmpty) {
            final isSearch = search.isNotEmpty;
            final hasZeroTotalClaims = claims.isEmpty;

            if (isSearch) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.bgPage,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.bgDivider),
                ),
                child: Center(
                  child: Text(
                    'No claims match "$search"',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }

            if (hasZeroTotalClaims) {
              return Container(
                padding: const EdgeInsets.all(28),
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.bgDivider),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.fact_check_outlined,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'No Factual Claims Detected',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Our verification engine analyzed this video and found no specific verifiable factual claims. The content may consist of commentary, personal opinions, creative expression, or general conversation.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => analysisCtrl.setSelectedTab(1),
                          icon: const Icon(Icons.show_chart_rounded, size: 15, color: Colors.black),
                          label: const Text(
                            'View Overview',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: () => analysisCtrl.setSelectedTab(3),
                          icon: const Icon(Icons.verified_user_outlined, size: 15, color: Colors.white),
                          label: const Text(
                            'View Conclusion',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12.5,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }

            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.bgPage,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.bgDivider),
              ),
              child: Center(
                child: Text(
                  search.isNotEmpty
                      ? 'No claims match "$search"'
                      : 'No claims found in "$filter" category.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          }

          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: workingList.length,
            separatorBuilder: (_, _) => const Divider(
              height: 16,
              thickness: 0.6,
              color: AppColors.bgDivider,
            ),
            itemBuilder: (context, index) {
              final claim = workingList[index] as Map<dynamic, dynamic>;
              final originalIndex = claims.indexOf(claim);

              return VideoAnalysisClaimCard(
                claim: claim,
                index: originalIndex != -1 ? originalIndex : index,
                allClaims: claims,
                allSources: allSources,
                videoCtrl: videoCtrl,
                analysisCtrl: analysisCtrl,
                video: video,
              );
            },
          );
        }),
      ],
    );
  }

  Widget _buildFilterPill({
    required String filterKey,
    required String label,
    required bool isSelected,
    Color? dotColor,
  }) {
    // Zero white-on-white: If background is pure white, text & icons MUST be black
    final bgColor = isSelected ? Colors.white : AppColors.bgSurface;
    final textColor = isSelected ? Colors.black : Colors.white;
    final borderColor = isSelected ? Colors.transparent : Colors.white.withValues(alpha: 0.12);

    return InkWell(
      onTap: () => analysisCtrl.selectedClaimFilter.value = filterKey,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dotColor != null) ...[
              Container(
                width: 7.5,
                height: 7.5,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: textColor, // Strictly black when selected white
              ),
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildPopupItem(String title, bool isSelected) {
    return PopupMenuItem<String>(
      value: title,
      height: 38,
      child: Row(
        children: [
          Icon(
            isSelected ? Icons.check_rounded : Icons.circle_outlined,
            size: 16,
            color: isSelected ? AppColors.success : AppColors.textTertiary,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w400,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  String _getSortLabel(String order) {
    switch (order) {
      case 'Highest Confidence':
        return 'Confidence';
      case 'Disputed First':
        return 'Disputed';
      default:
        return 'Video Order';
    }
  }
}
