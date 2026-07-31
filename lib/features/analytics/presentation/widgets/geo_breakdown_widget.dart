import 'package:flutter/material.dart';
import 'package:truthworld/features/analytics/data/models/watch_event_model.dart';
import 'package:truthworld/features/analytics/presentation/widgets/geo_breakdown_state.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Geographic breakdown widget that splits regions into Indian States
/// and Countries sections.
///
/// Features:
/// - Two collapsible sections: "Indian States" and "Countries"
/// - Progress bars with percentage for each region
/// - Sorted by view count descending
/// - Dark theme matching the app's aesthetic
class GeoBreakdownWidget extends StatelessWidget {
  const GeoBreakdownWidget({required this.regions, super.key});
  final List<GeoRegionModel> regions;

  @override
  Widget build(BuildContext context) {
    final state = GeoBreakdownState.fromRegions(regions);

    if (!state.hasData) {
      return _buildEmptyState();
    }

    final indianStates = state.indianStates;
    final countries = state.countries;
    final totalCount = state.totalCount;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Geographic Breakdown',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${regions.length} regions • $totalCount total views',
            style: TextStyle(
              color: AppColors.textPrimary.withValues(alpha: 0.5),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 20),

          // Indian States section
          if (indianStates.isNotEmpty) ...[
            _SectionTitle(
              icon: Icons.flag,
              title: 'Indian States',
              count: indianStates.length,
              color: const Color(0xFFF97316),
            ),
            const SizedBox(height: 12),
            ...indianStates
                .take(10)
                .map(
                  (r) => _RegionRow(
                    region: r,
                    totalCount: totalCount,
                    barColor: const Color(0xFFF97316),
                  ),
                ),
            if (indianStates.length > 10) ...[
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+ ${indianStates.length - 10} more states',
                  style: TextStyle(
                    color: AppColors.textPrimary.withValues(alpha: 0.4),
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
          ],

          // Countries section
          if (countries.isNotEmpty) ...[
            _SectionTitle(
              icon: Icons.public,
              title: 'Countries',
              count: countries.length,
              color: const Color(0xFF3B82F6),
            ),
            const SizedBox(height: 12),
            ...countries
                .take(10)
                .map(
                  (r) => _RegionRow(
                    region: r,
                    totalCount: totalCount,
                    barColor: const Color(0xFF3B82F6),
                  ),
                ),
            if (countries.length > 10) ...[
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+ ${countries.length - 10} more countries',
                  style: TextStyle(
                    color: AppColors.textPrimary.withValues(alpha: 0.4),
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.public,
              color: AppColors.textPrimary.withValues(alpha: 0.3),
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              'No geographic data available yet',
              style: TextStyle(
                color: AppColors.textPrimary.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.count,
    required this.color,
  });
  final IconData icon;
  final String title;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _RegionRow extends StatelessWidget {
  const _RegionRow({
    required this.region,
    required this.totalCount,
    required this.barColor,
  });
  final GeoRegionModel region;
  final int totalCount;
  final Color barColor;

  @override
  Widget build(BuildContext context) {
    final percentage = totalCount > 0 ? (region.count / totalCount) * 100 : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              region.regionKey,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${region.count}',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: (percentage / 100).clamp(0.0, 1.0),
                backgroundColor: AppColors.textPrimary.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation(barColor),
                minHeight: 6,
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 45,
            child: Text(
              '${percentage.toStringAsFixed(1)}%',
              style: TextStyle(
                color: AppColors.textPrimary.withValues(alpha: 0.5),
                fontSize: 11,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
