import 'package:flutter/material.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/category_insights_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Detailed information card for a specific category's demand metrics.
class CategoryInsightsDetailCard extends StatelessWidget {
  const CategoryInsightsDetailCard({required this.item, super.key});
  final CategoryStats item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: item.isUntouched
              ? AppColors.info.withValues(alpha: 0.5)
              : AppColors.bgDivider,
          width: item.isUntouched ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: Category Title, Badges & Score Pill
          Row(
            children: [
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    Text(
                      item.category,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        fontFamily: TWTypography.brandFamily,
                      ),
                    ),
                    if (item.isUntouched)
                      _buildStatusBadge(
                        label: 'Untouched (0 Channels)',
                        icon: Icons.explore_off_rounded,
                        badgeBg: AppColors.infoContainer,
                        borderColor: AppColors.info.withValues(alpha: 0.4),
                        textColor: AppColors.info,
                      )
                    else if (item.opportunityIndex > 10.0)
                      _buildStatusBadge(
                        label: 'High Content Gap Demand',
                        icon: Icons.verified_rounded,
                        badgeBg: AppColors.successContainer,
                        borderColor: AppColors.success.withValues(alpha: 0.4),
                        textColor: AppColors.success,
                      )
                    else if (item.growthRate > 25.0)
                      _buildStatusBadge(
                        label: 'Fast Growing',
                        icon: Icons.bolt_rounded,
                        badgeBg: AppColors.warningContainer,
                        borderColor: AppColors.warning.withValues(alpha: 0.4),
                        textColor: AppColors.warning,
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.bgPage,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.bgDivider),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.bolt_rounded,
                      size: 13,
                      color: AppColors.textPrimary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Score: ${item.opportunityIndex.toStringAsFixed(1)}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        fontFamily: TWTypography.brandFamily,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Stats Sub-Cards Row / Column
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 600;
              final card1 = _buildSubStatCard(
                label: 'Channels Operating',
                value: '${item.channelCount} ${item.channelCount == 1 ? 'channel' : 'channels'}',
                highlight: item.isUntouched,
                icon: Icons.tv,
              );
              final card2 = _buildSubStatCard(
                label: 'Total Videos Published',
                value: '${item.videoCount} videos',
                highlight: false,
                icon: Icons.play_circle_outline,
              );
              final card3 = _buildSubStatCard(
                label: 'Total User Likes',
                value: '${item.totalLikes} likes',
                highlight: false,
                icon: Icons.thumb_up_alt_outlined,
              );
              final card4 = _buildSubStatCard(
                label: 'Avg Likes / Video',
                value: item.avgLikesPerVideo.toStringAsFixed(1),
                highlight: false,
                icon: Icons.auto_graph_rounded,
              );

              if (isSmall) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: card1),
                        const SizedBox(width: 10),
                        Expanded(child: card2),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: card3),
                        const SizedBox(width: 10),
                        Expanded(child: card4),
                      ],
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: card1),
                  const SizedBox(width: 10),
                  Expanded(child: card2),
                  const SizedBox(width: 10),
                  Expanded(child: card3),
                  const SizedBox(width: 10),
                  Expanded(child: card4),
                ],
              );
            },
          ),

          // Top Liked Videos Section (if available)
          if (item.topLikedVideos.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.bgDivider),
            const SizedBox(height: 12),
            const Text(
              'Top User-Liked Videos in this Category:',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textTertiary,
                fontFamily: TWTypography.uiFamily,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: item.topLikedVideos.map((v) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.bgPage,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.bgDivider),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.thumb_up_rounded,
                        size: 11,
                        color: AppColors.textPrimary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${v['title']}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                          fontFamily: TWTypography.uiFamily,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '(${v['likes']} likes)',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.success,
                          fontWeight: FontWeight.bold,
                          fontFamily: TWTypography.uiFamily,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubStatCard({
    required String label,
    required String value,
    required bool highlight,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bgPage,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: AppColors.textPrimary),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontFamily: TWTypography.uiFamily,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: highlight ? AppColors.info : AppColors.textPrimary,
              fontFamily: TWTypography.uiFamily,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge({
    required String label,
    required IconData icon,
    required Color badgeBg,
    required Color borderColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textPrimary),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor,
              fontFamily: TWTypography.uiFamily,
            ),
          ),
        ],
      ),
    );
  }
}
