import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Loading skeleton placeholder for search results.
class SearchResultSkeleton extends StatelessWidget {
  const SearchResultSkeleton({
    super.key,
    this.count = 5,
    this.shrinkWrap = false,
    this.physics,
  });

  final int count;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    if (shrinkWrap) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(count, (index) => _buildSkeletonItem(context)),
      );
    }

    return ListView.builder(
      physics: physics,
      itemCount: count,
      itemBuilder: (context, index) => _buildSkeletonItem(context),
    );
  }

  Widget _buildSkeletonItem(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: MediaQuery.of(context).size.width * 0.38,
            height: 90,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: AppColors.textPrimary.withValues(alpha: 0.05),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 16,
                  color: AppColors.textPrimary.withValues(alpha: 0.05),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 12,
                  width: 120,
                  color: AppColors.textPrimary.withValues(alpha: 0.05),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 12,
                  width: 80,
                  color: AppColors.textPrimary.withValues(alpha: 0.05),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
