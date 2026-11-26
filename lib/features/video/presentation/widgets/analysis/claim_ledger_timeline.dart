import 'package:flutter/material.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/features/video/data/models/claim_verdict_helper.dart';
import 'package:truthworld/theme/app_theme.dart';

/// 📜 ClaimLedgerTimeline
///
/// Horizontal chronological ledger of all claims across a video:
/// - Visual timeline cards for each claim with timestamp & verdict badge
/// - Active selection glow and responsive scroll tracking
/// - One-tap navigation to scrub between claims in the command center
class ClaimLedgerTimeline extends StatelessWidget {
  final List<dynamic> allClaims;
  final int activeIndex;
  final ValueChanged<int> onClaimSelected;
  final ScrollController scrollController;

  const ClaimLedgerTimeline({
    required this.allClaims,
    required this.activeIndex,
    required this.onClaimSelected,
    required this.scrollController,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (allClaims.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.timeline_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'CLAIM LEDGER TIMELINE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${allClaims.length} Claims',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const Spacer(),
              // Navigation arrows
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 20),
                color: activeIndex > 0 ? Colors.white : Colors.white24,
                tooltip: 'Previous Claim',
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                splashRadius: 16,
                onPressed: activeIndex > 0
                    ? () => onClaimSelected(activeIndex - 1)
                    : null,
              ),
              const SizedBox(width: 6),
              Text(
                '${activeIndex + 1} / ${allClaims.length}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 20),
                color: activeIndex < allClaims.length - 1 ? Colors.white : Colors.white24,
                tooltip: 'Next Claim',
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                splashRadius: 16,
                onPressed: activeIndex < allClaims.length - 1
                    ? () => onClaimSelected(activeIndex + 1)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Horizontal Ledger Strip
          SizedBox(
            height: 84,
            child: ListView.separated(
              controller: scrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: allClaims.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final item = allClaims[index];
                final claimMap = item is Map ? item : <dynamic, dynamic>{};
                final isActive = (index == activeIndex);
                final verdict = ClaimVerdictHelper.resolveVerdict(claimMap);

                // Timestamp
                final startSec = _extractStartSec(claimMap);
                final timeStr = startSec != null
                    ? FormatUtils.formatDuration(Duration(milliseconds: (startSec * 1000).toInt()))
                    : '--:--';

                // Claim snippet
                final text = (claimMap['claim'] ??
                        claimMap['statement'] ??
                        claimMap['text'] ??
                        claimMap['title'] ??
                        'Claim #${index + 1}')
                    .toString()
                    .trim();

                final Color pillColor = _getVerdictPillColor(verdict);

                return InkWell(
                  onTap: () => onClaimSelected(index),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    width: 172,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isActive
                            ? Colors.white.withValues(alpha: 0.6)
                            : Colors.white.withValues(alpha: 0.1),
                        width: isActive ? 1.5 : 0.8,
                      ),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.08),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Top Row: Claim # & Timestamp Pill
                        Row(
                          children: [
                            Text(
                              '#${index + 1}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isActive ? Colors.white : AppColors.textSecondary,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: pillColor.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: pillColor.withValues(alpha: 0.4),
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                verdict.localizedLabel().toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w700,
                                  color: pillColor,
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Middle: Claim Snippet
                        Text(
                          text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                            color: isActive ? Colors.white : AppColors.textTertiary,
                          ),
                        ),

                        // Bottom: Timestamp
                        Row(
                          children: [
                            Icon(
                              Icons.play_circle_outline_rounded,
                              size: 13,
                              color: isActive ? Colors.white70 : AppColors.textTertiary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              timeStr,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isActive ? Colors.white70 : AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static Color _getVerdictPillColor(ClaimVerdictInfo verdict) {
    if (verdict.type == ClaimVerdictType.mostlyTrue ||
        verdict.label.toLowerCase().contains('mostly')) {
      return const Color(0xFF2DD4BF);
    }
    if (verdict.label.toLowerCase().contains('partial') ||
        verdict.label.toLowerCase().contains('half')) {
      return AppColors.warning;
    }
    if (verdict.isVerified) {
      return AppColors.success;
    }
    if (verdict.isFalse) {
      return AppColors.error;
    }
    if (verdict.isCaution) {
      return const Color(0xFFFB923C);
    }
    if (verdict.isContextual) {
      return AppColors.textLink;
    }
    return AppColors.warning;
  }

  static double? _extractStartSec(Map<dynamic, dynamic> claim) {
    dynamic val = claim['startSec'] ??
        claim['startTime'] ??
        claim['start_time'] ??
        claim['start'] ??
        claim['timestampSec'] ??
        claim['timestamp'] ??
        claim['time'];
    if (val is num) return val.toDouble();
    if (val is String) {
      final parsed = double.tryParse(val);
      if (parsed != null) return parsed;
      if (val.contains(':')) {
        final parts = val.split(':');
        if (parts.length == 2) {
          final m = int.tryParse(parts[0]) ?? 0;
          final s = double.tryParse(parts[1]) ?? 0.0;
          return m * 60 + s;
        } else if (parts.length == 3) {
          final h = int.tryParse(parts[0]) ?? 0;
          final m = int.tryParse(parts[1]) ?? 0;
          final s = double.tryParse(parts[2]) ?? 0.0;
          return h * 3600 + m * 60 + s;
        }
      }
    }
    return null;
  }
}
