import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Violation category distribution chart displaying horizontal bars and breakdown by policy category.
class AdminAnalyticsViolationChart extends StatelessWidget {
  const AdminAnalyticsViolationChart({
    required this.data,
    super.key,
  });

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final categoriesRaw = data['violationCategories'];
    final categories = categoriesRaw is Map<String, dynamic>
        ? categoriesRaw
        : <String, dynamic>{};

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Violation Category Distribution',
                style: TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (categories.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${categories.length} Categories',
                    style: const TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: AppColors.error,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Accurate breakdown of verified content violations and user reports',
            style: TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 24),
          if (categories.isEmpty)
            const AdminAnalyticsZeroViolationsState()
          else
            AdminAnalyticsCategoriesList(categories: categories),
        ],
      ),
    );
  }
}

/// Zero violations empty state widget.
class AdminAnalyticsZeroViolationsState extends StatelessWidget {
  const AdminAnalyticsZeroViolationsState({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36.0, horizontal: 20.0),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Zero Violations Recorded',
            style: TextStyle(
              fontFamily: TWTypography.brandFamily,
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'No community guidelines violations or safety breaches have been detected in the selected time range.',
            style: TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Category horizontal bar rows list.
class AdminAnalyticsCategoriesList extends StatelessWidget {
  const AdminAnalyticsCategoriesList({
    required this.categories,
    super.key,
  });

  final Map<String, dynamic> categories;

  static const List<Color> chartColors = [
    Color(0xFFEF5350), // Red
    Color(0xFFFF7043), // Deep Orange
    Color(0xFFFFA726), // Amber
    Color(0xFFEC407A), // Pink
    Color(0xFFAB47BC), // Purple
    Color(0xFF42A5F5), // Blue
    Color(0xFF26A69A), // Teal
  ];

  @override
  Widget build(BuildContext context) {
    final totalCount = categories.values.fold<int>(
      0,
      (prev, curr) => prev + (curr is num ? curr.toInt() : 0),
    );

    final categoryList = categories.entries.toList()
      ..sort((a, b) => (b.value as num).compareTo(a.value as num));

    return Column(
      children: List.generate(categoryList.length, (index) {
        final entry = categoryList[index];
        final count = entry.value is num ? (entry.value as num).toInt() : 0;
        final percentage = totalCount > 0
            ? ((count / totalCount) * 100).roundToDouble()
            : 0.0;
        final color = chartColors[index % chartColors.length];

        return AdminAnalyticsBarChartRow(
          label: entry.key,
          percentage: percentage,
          count: count,
          color: color,
        );
      }),
    );
  }
}

/// Single bar chart row with category label, colored proportional progress bar, and percentage.
class AdminAnalyticsBarChartRow extends StatelessWidget {
  const AdminAnalyticsBarChartRow({
    required this.label,
    required this.percentage,
    required this.count,
    required this.color,
    super.key,
  });

  final String label;
  final double percentage;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Flexible(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.textPrimary,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: const Color(0xFF242424),
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: (percentage / 100).clamp(0.02, 1.0),
                  child: Container(
                    height: 14,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 75,
            child: Text(
              '${percentage.toInt()}% ($count)',
              style: const TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
