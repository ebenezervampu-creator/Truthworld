import 'package:flutter/material.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audience_controller.dart';

Widget buildAudienceSubscribersWatchShareCard({
  required AudienceController controller,
  required bool isDarkMode,
  required Color surfaceColor,
  required Color borderColor,
  required Color textColor,
  required Color subtitleColor,
}) {
    final subPct = controller.subscribedPercentage;
    final notSubPct = controller.notSubscribedPercentage;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.pie_chart_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Watch Time from Subscribers',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Views breakdown by subscription status',
                      style: TextStyle(fontSize: 12, color: subtitleColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Not Subscribed Row
          buildAudienceSubscriptionShareRow(
            label: 'Not subscribed',
            percentage: notSubPct,
            color: const Color(0xFFF59E0B),
            textColor: textColor,
            subtitleColor: subtitleColor,
            isDominant: notSubPct >= subPct,
          ),
          const SizedBox(height: 14),

          // Subscribed Row
          buildAudienceSubscriptionShareRow(
            label: 'Subscribed',
            percentage: subPct,
            color: const Color(0xFF10B981),
            textColor: textColor,
            subtitleColor: subtitleColor,
            isDominant: subPct > notSubPct,
          ),

          const SizedBox(height: 20),
          // Tip Banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? const Color(0xFF1E293B)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDarkMode
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.lightbulb_outline_rounded,
                  size: 18,
                  color: Colors.white,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    controller.totalViews.value == 0
                        ? 'No watch time recorded yet for this channel.'
                        : (notSubPct == 0 && subPct == 0
                            ? 'No watch time breakdown recorded yet.'
                            : (notSubPct > 50
                                ? '${notSubPct.toStringAsFixed(0)}% of your viewers are not subscribed. Use call-to-actions and interactive end cards to convert them!'
                                : 'High subscriber loyalty! Your core subscribers are actively consuming new releases.')),
                    style: TextStyle(
                      fontSize: 12,
                      color: subtitleColor,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildAudienceSubscriptionShareRow({
    required String label,
    required double percentage,
    required Color color,
    required Color textColor,
    required Color subtitleColor,
    required bool isDominant,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isDominant ? FontWeight.bold : FontWeight.w500,
                    color: textColor,
                  ),
                ),
              ],
            ),
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: percentage > 0 ? (percentage / 100).clamp(0.01, 1.0) : 0,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }


