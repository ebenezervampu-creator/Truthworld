import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audience_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

Widget buildAudienceSummaryCardsMatrix({
  required AudienceController controller,
  required bool isDarkMode,
  required Color surfaceColor,
  required Color borderColor,
  required Color textColor,
  required Color subtitleColor,
}) {
    final views = controller.totalViews.value;
    final returning = controller.returningViewers.value;
    final unique = controller.totalUniqueViewers.value > 0
        ? controller.totalUniqueViewers.value
        : views;
    final netSubs = controller.netSubscribers;
    final unSubPct = controller.notSubscribedPercentage;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 900;
        final cardWidth = isDesktop
            ? (constraints.maxWidth - 64) / 5
            : (constraints.maxWidth > 550
                ? (constraints.maxWidth - 16) / 2
                : constraints.maxWidth);

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            buildAudienceMetricTile(
              isDarkMode: isDarkMode,
              title: 'Returning Viewers',
              value: NumberFormat.compact().format(returning),
              subtitle: '${controller.returningPercentage.toStringAsFixed(0)}% watched before',
              icon: Icons.replay_rounded,
              accentColor: const Color(0xFF6366F1),
              width: cardWidth,
              surfaceColor: surfaceColor,
              borderColor: borderColor,
              textColor: textColor,
              subtitleColor: subtitleColor,
            ),
            buildAudienceMetricTile(
              isDarkMode: isDarkMode,
              title: 'Unique Viewers',
              value: NumberFormat.compact().format(unique),
              subtitle: 'Distinct viewer accounts',
              icon: Icons.people_outline_rounded,
              accentColor: const Color(0xFF3B82F6),
              width: cardWidth,
              surfaceColor: surfaceColor,
              borderColor: borderColor,
              textColor: textColor,
              subtitleColor: subtitleColor,
            ),
            buildAudienceMetricTile(
              isDarkMode: isDarkMode,
              title: 'Subscribers (+/-)',
              value: (netSubs >= 0 ? '+$netSubs' : '$netSubs'),
              subtitle: '${NumberFormat.compact().format(controller.totalSubscribersGained.value)} gained in period',
              icon: Icons.person_add_rounded,
              accentColor: const Color(0xFF10B981),
              width: cardWidth,
              surfaceColor: surfaceColor,
              borderColor: borderColor,
              textColor: textColor,
              subtitleColor: subtitleColor,
            ),
            buildAudienceMetricTile(
              isDarkMode: isDarkMode,
              title: 'Not Subscribed Views',
              value: '${unSubPct.toStringAsFixed(1)}%',
              subtitle: 'Audience discovery reach',
              icon: Icons.unsubscribe_outlined,
              accentColor: const Color(0xFFF59E0B),
              width: cardWidth,
              surfaceColor: surfaceColor,
              borderColor: borderColor,
              textColor: textColor,
              subtitleColor: subtitleColor,
            ),
            buildAudienceMetricTile(
              isDarkMode: isDarkMode,
              title: 'Total View Reach',
              value: NumberFormat.compact().format(views),
              subtitle: '${controller.subscriberConversionRate.value.toStringAsFixed(1)}% sub conversion',
              icon: Icons.visibility_rounded,
              accentColor: const Color(0xFF8B5CF6),
              width: cardWidth,
              surfaceColor: surfaceColor,
              borderColor: borderColor,
              textColor: textColor,
              subtitleColor: subtitleColor,
            ),
          ],
        );
      },
    );
  }



  Widget buildAudienceMetricTile({
    required bool isDarkMode,
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required double width,
    required Color surfaceColor,
    required Color borderColor,
    required Color textColor,
    required Color subtitleColor,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: AppColors.bgPage.withValues(
              alpha: isDarkMode ? 0.2 : 0.02,
            ),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: subtitleColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, size: 16, color: Colors.white),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: subtitleColor.withValues(alpha: 0.8),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

