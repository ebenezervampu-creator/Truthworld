import 'package:flutter/material.dart';

import 'skeleton_base.dart';

/// Skeleton loading state for the channel / profile page.
class ChannelSkeleton extends StatelessWidget {
  const ChannelSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0014),
      body: SafeArea(
        child: SkeletonBase(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Banner image
                const SkeletonBox(
                  width: double.infinity,
                  height: 200,
                  borderRadius: 0,
                ),
                const SizedBox(height: 16),

                // Channel header: avatar + name + subs
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const SkeletonCircle(size: 72),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            SkeletonBox(height: 18, width: 200),
                            SizedBox(height: 8),
                            SkeletonBox(height: 14, width: 140),
                            SizedBox(height: 6),
                            SkeletonBox(height: 12, width: 100),
                          ],
                        ),
                      ),
                      const SkeletonBox(
                        height: 36,
                        width: 110,
                        borderRadius: 20,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Tab bar placeholder
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: const [
                      SkeletonBox(height: 32, width: 72, borderRadius: 16),
                      SizedBox(width: 12),
                      SkeletonBox(height: 32, width: 72, borderRadius: 16),
                      SizedBox(width: 12),
                      SkeletonBox(height: 32, width: 72, borderRadius: 16),
                      SizedBox(width: 12),
                      SkeletonBox(height: 32, width: 72, borderRadius: 16),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Divider
                Container(height: 1, color: const Color(0xFF1A1A2E)),
                const SizedBox(height: 16),

                // Video grid
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = constraints.maxWidth >= 1200
                          ? 3
                          : constraints.maxWidth >= 600
                          ? 2
                          : 1;

                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 20,
                          childAspectRatio: crossAxisCount == 1 ? 0.85 : 0.75,
                        ),
                        itemCount: 6,
                        itemBuilder: (_, _) =>
                            const _ChannelVideoCardSkeleton(),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChannelVideoCardSkeleton extends StatelessWidget {
  const _ChannelVideoCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        AspectRatio(aspectRatio: 16 / 9, child: SkeletonBox(borderRadius: 12)),
        SizedBox(height: 10),
        SkeletonBox(height: 14, width: double.infinity),
        SizedBox(height: 6),
        SkeletonBox(height: 12, width: 120),
      ],
    );
  }
}
