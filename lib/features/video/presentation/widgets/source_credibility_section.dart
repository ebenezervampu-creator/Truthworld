import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/features/video/data/models/credibility_report.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

/// 🏛 Source Credibility Section (v15.0)
///
/// A premium evidence-visibility widget that shows:
/// - Source Diversity Score
/// - Source Quality Distribution (High/Medium/Low)
/// - Expandable Source Ledger with progressive disclosure
///
/// This transforms evidence from "hidden metadata" into
/// "first-class platform infrastructure."
class SourceCredibilityController extends BaseController {
  final RxBool isExpanded = false.obs;

  void toggleExpanded() {
    isExpanded.value = !isExpanded.value;
  }
}

class SourceCredibilitySection extends StatelessWidget {
  const SourceCredibilitySection({
    required this.sources,
    super.key,
    this.claims = const [],
    this.isCompact = false,
  });
  final List<UISource> sources;
  final List<ClaimResult> claims;
  final bool isCompact;

  int get _highCount => sources.where((s) {
    final lvl = s.trustLevel.toLowerCase();
    return lvl == 'high' || lvl == 'institutional' || lvl == 'established';
  }).length;
  int get _mediumCount => sources.where((s) {
    final lvl = s.trustLevel.toLowerCase();
    return lvl == 'medium' || lvl == 'reference';
  }).length;
  int get _lowCount => sources.where((s) {
    final lvl = s.trustLevel.toLowerCase();
    return lvl == 'low' || lvl == 'general' || lvl == 'unverified';
  }).length;

  int get _uniqueDomains {
    final domains = <String>{};
    for (final s in sources) {
      if (s.domain != null && s.domain!.isNotEmpty) {
        domains.add(s.domain!);
      }
    }
    return domains.length;
  }

  String get _diversityLabel {
    if (_uniqueDomains >= 6) return 'Excellent';
    if (_uniqueDomains >= 4) return 'Strong';
    if (_uniqueDomains >= 2) return 'Moderate';
    if (_uniqueDomains >= 1) return 'Limited';
    return 'None';
  }

  Color get _diversityColor {
    if (_uniqueDomains >= 6) return AppColors.success;
    if (_uniqueDomains >= 4) return const Color(0xFFA3E635);
    if (_uniqueDomains >= 2) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    if (sources.isEmpty) return const SizedBox.shrink();

    // Use a unique tag based on the sources list to maintain independent state
    final controller = Get.put(
      SourceCredibilityController(),
      tag: 'credibility_${sources.hashCode}',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'EVIDENCE SOURCES',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textTertiary,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        _buildDiversityHeader(),
        const SizedBox(height: 16),
        _buildQualityDistribution(),
        const SizedBox(height: 16),
        _buildSourceLedger(controller),
      ],
    ).animate().fadeIn(delay: 400.ms);
  }

  /// Top row: Source diversity score + institution count
  Widget _buildDiversityHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _diversityColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _diversityColor.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _diversityColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.hub_outlined, color: _diversityColor, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '$_uniqueDomains',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'INDEPENDENT SOURCES',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textTertiary,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _diversityColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _diversityLabel.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _diversityColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Evidence Diversity',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Total citation count
          Column(
            children: [
              Text(
                '${sources.fold<int>(0, (sum, s) => sum + s.citationCount)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                'CITATIONS',
                style: AppTextStyles.captionBold.copyWith(letterSpacing: 0.5),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Quality distribution: High / Medium / Low counts with visual bars
  Widget _buildQualityDistribution() {
    final total = sources.length;
    if (total == 0) return const SizedBox.shrink();

    return Row(
      children: [
        _buildQualityPill(
          'HIGH RELIABILITY',
          _highCount,
          total,
          AppColors.success,
        ),
        const SizedBox(width: 8),
        _buildQualityPill('MODERATE', _mediumCount, total, AppColors.warning),
        const SizedBox(width: 8),
        _buildQualityPill('LIMITED', _lowCount, total, AppColors.warning),
      ],
    );
  }

  Widget _buildQualityPill(String label, int count, int total, Color color) {
    final fraction = total > 0 ? count / total : 0.0;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  '${(fraction * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Mini progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: fraction,
                backgroundColor: AppColors.textPrimary.withValues(alpha: 0.05),
                color: color.withValues(alpha: 0.6),
                minHeight: 3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTextStyles.captionBold.copyWith(letterSpacing: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  /// Expandable source ledger with progressive disclosure
  Widget _buildSourceLedger(SourceCredibilityController controller) {
    final hasMore = sources.length > 3;

    return Obx(() {
      final isExpanded = controller.isExpanded.value;
      final visibleSources = isExpanded ? sources : sources.take(3).toList();

      return Column(
        children: [
          ...visibleSources.asMap().entries.map(
            (entry) => _buildSourceTile(entry.value, entry.key),
          ),
          if (hasMore && !isExpanded) _buildExpandButton(controller),
          if (isExpanded && hasMore) _buildCollapseButton(controller),
        ],
      );
    });
  }

  Widget _buildSourceTile(UISource source, int index) {
    final tierColor = _getTierColor(source.trustLevel);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.textPrimary.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.05),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _launchSourceUrl(source.url),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Trust tier indicator
                Container(
                  width: 4,
                  height: 36,
                  decoration: BoxDecoration(
                    color: tierColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                // Source info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        source.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (source.domain != null) ...[
                            const Icon(
                              Icons.language,
                              size: 10,
                              color: AppColors.textTertiary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              source.domain!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textTertiary,
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          if (source.snippet != null &&
                              source.snippet!.isNotEmpty)
                            Expanded(
                              child: Text(
                                source.snippet!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textTertiary.withValues(
                                    alpha: 0.6,
                                  ),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Badges column
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildTierBadge(source.trustLevel, tierColor),
                    const SizedBox(height: 4),
                    if (source.citationCount > 1)
                      Text(
                        '${source.citationCount} claims',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 6),
                if (source.url != null && source.url!.isNotEmpty)
                  Icon(
                    Icons.open_in_new_rounded,
                    size: 14,
                    color: AppColors.textTertiary.withValues(alpha: 0.5),
                  ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: (200 + index * 80).ms).slideX(begin: 0.05);
  }

  Widget _buildTierBadge(String level, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        level.toUpperCase(),
        style: AppTextStyles.captionBold.copyWith(
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildExpandButton(SourceCredibilityController controller) {
    return TextButton.icon(
      onPressed: controller.toggleExpanded,
      icon: const Icon(Icons.expand_more_rounded, size: 16),
      label: Text(
        'Show all ${sources.length} sources',
        style: const TextStyle(fontSize: 12),
      ),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.textTertiary,
        padding: const EdgeInsets.symmetric(vertical: 8),
      ),
    );
  }

  Widget _buildCollapseButton(SourceCredibilityController controller) {
    return TextButton.icon(
      onPressed: controller.toggleExpanded,
      icon: const Icon(Icons.expand_less_rounded, size: 16),
      label: const Text(
        'Show fewer',
        style: TextStyle(fontSize: 12),
      ),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.textTertiary,
        padding: const EdgeInsets.symmetric(vertical: 8),
      ),
    );
  }

  Future<void> _launchSourceUrl(String? url) async {
    if (url == null || url.isEmpty || !url.startsWith('http')) return;
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      // Silently fail — source may not be a valid URL
    }
  }

  Color _getTierColor(String level) {
    switch (level.toLowerCase()) {
      case 'high':
      case 'institutional':
      case 'established':
        return AppColors.success;
      case 'medium':
      case 'reference':
        return const Color(0xFF8B9DFF);
      case 'low':
      case 'general':
        return AppColors.warning;
      case 'unverified':
      default:
        return AppColors.textTertiary;
    }
  }
}
