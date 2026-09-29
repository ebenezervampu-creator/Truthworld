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
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: item.isUntouched
              ? const Color(0xFF38BDF8).withValues(alpha: 0.4)
              : const Color(0xFF27272A),
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
                        color: Colors.white,
                      ),
                    ),
                    if (item.isUntouched)
                      _buildStatusBadge(
                        label: 'Untouched (0 Channels)',
                        icon: Icons.explore_off_rounded,
                        badgeBg: const Color(0xFF1E293B),
                        borderColor: const Color(0xFF38BDF8).withValues(alpha: 0.4),
                        textColor: const Color(0xFF38BDF8),
                      )
                    else if (item.opportunityIndex > 10.0)
                      _buildStatusBadge(
                        label: 'High Content Gap Demand',
                        icon: Icons.verified_rounded,
                        badgeBg: const Color(0xFF064E3B),
                        borderColor: const Color(0xFF10B981).withValues(alpha: 0.4),
                        textColor: const Color(0xFF34D399),
                      )
                    else if (item.growthRate > 25.0)
                      _buildStatusBadge(
                        label: 'Fast Growing',
                        icon: Icons.bolt_rounded,
                        badgeBg: const Color(0xFF1E293B),
                        borderColor: const Color(0xFF38BDF8).withValues(alpha: 0.4),
                        textColor: const Color(0xFF38BDF8),
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
                  color: const Color(0xFF121212),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF27272A)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.bolt_rounded,
                      size: 13,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Score: ${item.opportunityIndex.toStringAsFixed(1)}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
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
            const Divider(height: 1, color: Color(0xFF27272A)),
            const SizedBox(height: 12),
            Text(
              'Top User-Liked Videos in ${item.category}:',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textTertiary,
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
                    color: const Color(0xFF121212),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF27272A)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.thumb_up_rounded,
                        size: 11,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${v['title']}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '(${v['likes']} likes)',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF34D399),
                          fontWeight: FontWeight.bold,
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
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: Colors.white),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
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
              color: highlight ? const Color(0xFF38BDF8) : Colors.white,
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
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
