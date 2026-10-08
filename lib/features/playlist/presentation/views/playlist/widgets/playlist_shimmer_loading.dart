import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Shimmer skeleton loading state matching the modern PlaylistScreenCard architecture.
class PlaylistShimmerLoading extends StatelessWidget {
  const PlaylistShimmerLoading({
    required this.isListView,
    required this.isMobile,
    required this.isTablet,
    required this.isDesktop,
    super.key,
  });

  final bool isListView;
  final bool isMobile;
  final bool isTablet;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int crossAxisCount;
        if (width >= 1150) {
          crossAxisCount = 4;
        } else if (width >= 780) {
          crossAxisCount = 3;
        } else if (width >= 520) {
          crossAxisCount = 2;
        } else {
          crossAxisCount = width >= 360 ? 2 : 1;
        }

        const horizontalPadding = 32.0;
        const crossAxisSpacing = 16.0;
        final availableWidth = width - horizontalPadding;
        final cardWidth = (availableWidth - (crossAxisSpacing * (crossAxisCount - 1))) / crossAxisCount;
        final thumbWidth = cardWidth - 24;
        final thumbHeight = thumbWidth * (9.0 / 16.0);
        final cardHeight = thumbHeight + 104;
        final childAspectRatio = (cardWidth / cardHeight).clamp(0.65, 1.45);

        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: 4,
          itemBuilder: (context, index) => const PlaylistShimmerCard(),
        );
      },
    );
  }
}

class PlaylistShimmerCard extends StatelessWidget {
  const PlaylistShimmerCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF242424),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Shimmer.fromColors(
        baseColor: const Color(0xFF1E1E1E),
        highlightColor: const Color(0xFF2A2A2A),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 16:9 Thumbnail skeleton
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF222222),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Title skeleton
            Container(
              height: 16,
              width: 140,
              decoration: BoxDecoration(
                color: const Color(0xFF222222),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 6),
            // Subtitle skeleton
            Container(
              height: 12,
              width: 90,
              decoration: BoxDecoration(
                color: const Color(0xFF222222),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
