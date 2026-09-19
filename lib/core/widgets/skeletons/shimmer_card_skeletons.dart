import 'package:flutter/material.dart';
import 'package:truthworld/core/widgets/skeletons/shimmer_base.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Matches the shape of a video card in horizontal/list orientation.
class ShimmerVideoListCard extends StatelessWidget {
  const ShimmerVideoListCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerBase(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            shimmerBone(width: 160, height: 90, radius: 12),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  shimmerBone(width: double.infinity, height: 16),
                  const SizedBox(height: 8),
                  FractionallySizedBox(
                    widthFactor: 0.7,
                    alignment: Alignment.centerLeft,
                    child: shimmerBone(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      shimmerBone(width: 24, height: 24, radius: 12),
                      const SizedBox(width: 8),
                      Expanded(child: shimmerBone(height: 12)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: shimmerBone(height: 10)),
                      const SizedBox(width: 12),
                      Expanded(child: shimmerBone(height: 10)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Matches the shape of a video card in vertical/grid orientation.
class ShimmerVideoGridCard extends StatelessWidget {
  const ShimmerVideoGridCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerBase(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.textPrimary,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              shimmerBone(width: 36, height: 36, radius: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    shimmerBone(width: double.infinity),
                    const SizedBox(height: 6),
                    shimmerBone(width: 120, height: 12),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        shimmerBone(width: 50, height: 10),
                        const SizedBox(width: 8),
                        shimmerBone(width: 50, height: 10),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Matches a typical comment row: avatar + username + text lines + actions.
class ShimmerCommentCard extends StatelessWidget {
  const ShimmerCommentCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerBase(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            shimmerBone(width: 36, height: 36, radius: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      shimmerBone(width: 100, height: 12),
                      const SizedBox(width: 8),
                      shimmerBone(width: 50, height: 10),
                    ],
                  ),
                  const SizedBox(height: 8),
                  shimmerBone(width: double.infinity, height: 12),
                  const SizedBox(height: 4),
                  shimmerBone(width: 200, height: 12),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      shimmerBone(width: 20, height: 20, radius: 10),
                      const SizedBox(width: 4),
                      shimmerBone(width: 24, height: 10),
                      const SizedBox(width: 16),
                      shimmerBone(width: 20, height: 20, radius: 10),
                      const SizedBox(width: 16),
                      shimmerBone(width: 40, height: 10),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Matches a channel discovery card: avatar + name + subscriber count.
class ShimmerChannelCard extends StatelessWidget {
  const ShimmerChannelCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerBase(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        child: Row(
          children: [
            shimmerBone(width: 48, height: 48, radius: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  shimmerBone(width: 140),
                  const SizedBox(height: 6),
                  shimmerBone(width: 90, height: 11),
                ],
              ),
            ),
            shimmerBone(width: 80, height: 32, radius: 16),
          ],
        ),
      ),
    );
  }
}

/// Matches the shape of a featured discovery channel card with banner.
class ShimmerDiscoverChannelCard extends StatelessWidget {
  const ShimmerDiscoverChannelCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerBase(
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.bgDivider, width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 72,
              width: double.infinity,
              color: AppColors.textPrimary,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        shimmerBone(width: 44, height: 44, radius: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              shimmerBone(width: 100),
                              const SizedBox(height: 4),
                              shimmerBone(width: 60, height: 11),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    shimmerBone(width: double.infinity, height: 12),
                    const SizedBox(height: 6),
                    shimmerBone(width: 150, height: 12),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            shimmerBone(width: 80, height: 11),
                            const SizedBox(height: 4),
                            shimmerBone(width: 50, height: 10),
                          ],
                        ),
                        shimmerBone(width: 80, height: 32, radius: 16),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Builds a list of N shimmer video skeletons in list layout.
Widget buildShimmerVideoList({int count = 6}) {
  return ListView.builder(
    physics: const NeverScrollableScrollPhysics(),
    shrinkWrap: true,
    itemCount: count,
    itemBuilder: (_, i) => const ShimmerVideoListCard(),
  );
}

/// Builds a grid of N shimmer video skeletons.
Widget buildShimmerVideoGrid({int crossAxisCount = 2, int count = 6}) {
  return GridView.builder(
    physics: const NeverScrollableScrollPhysics(),
    shrinkWrap: true,
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 0.75,
    ),
    itemCount: count,
    itemBuilder: (_, i) => const ShimmerVideoGridCard(),
  );
}

/// Builds a list of N shimmer comment skeletons.
Widget buildShimmerCommentList({int count = 5}) {
  return ListView.builder(
    physics: const NeverScrollableScrollPhysics(),
    shrinkWrap: true,
    itemCount: count,
    itemBuilder: (_, i) => const ShimmerCommentCard(),
  );
}
