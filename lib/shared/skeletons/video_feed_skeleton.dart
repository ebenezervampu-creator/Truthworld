import 'package:flutter/material.dart';

import 'package:truthworld/shared/skeletons/skeleton_base.dart';

/// Skeleton loading state for the home video feed grid.
class VideoFeedSkeleton extends StatelessWidget {
  const VideoFeedSkeleton({super.key, this.itemCount = 12});

  /// Number of placeholder cards to display.
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0014),
      body: SafeArea(
        child: SkeletonBase(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = _columnsForWidth(constraints.maxWidth);
              final childAspectRatio = crossAxisCount == 1 ? 0.85 : 0.75;

              return GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 20,
                  childAspectRatio: childAspectRatio,
                ),
                itemCount: itemCount,
                itemBuilder: (_, _) => const VideoCardSkeleton(),
              );
            },
          ),
        ),
      ),
    );
  }

  static int _columnsForWidth(double width) {
    if (width >= 1200) return 3;
    if (width >= 600) return 2;
    return 1;
  }
}

/// A single video-card placeholder matching the real card layout.
class VideoCardSkeleton extends StatelessWidget {
  const VideoCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 16:9 thumbnail
        AspectRatio(
          aspectRatio: 16 / 9,
          child: SkeletonBox(borderRadius: 12),
        ),
        SizedBox(height: 12),

        // Bottom row: avatar + text
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonCircle(size: 36),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(height: 14, width: double.infinity),
                  SizedBox(height: 8),
                  SkeletonBox(height: 12, width: 160),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
