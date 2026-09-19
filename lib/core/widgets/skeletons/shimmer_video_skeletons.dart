import 'package:flutter/material.dart';
import 'package:truthworld/core/widgets/skeletons/shimmer_base.dart';
import 'package:truthworld/core/widgets/skeletons/shimmer_card_skeletons.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Loading skeleton matching the responsive playlist detail screen.
class ShimmerPlaylistDetail extends StatelessWidget {
  const ShimmerPlaylistDetail({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 1000;
          final isTablet =
              constraints.maxWidth >= 600 && constraints.maxWidth < 1000;

          if (isDesktop) {
            return Row(
              children: [
                Container(
                  width: 360,
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    border: Border(
                      right: BorderSide(color: AppColors.bgDivider, width: 0.5),
                    ),
                  ),
                  child: ShimmerBase(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        AspectRatio(
                          aspectRatio: 16 / 9,
                          child: shimmerBone(
                            width: double.infinity,
                            radius: 12,
                          ),
                        ),
                        const SizedBox(height: 24),
                        shimmerBone(width: 220, height: 24),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            shimmerBone(width: 32, height: 32, radius: 16),
                            const SizedBox(width: 10),
                            shimmerBone(width: 120),
                          ],
                        ),
                        const SizedBox(height: 16),
                        shimmerBone(width: 180, height: 12),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(child: shimmerBone(height: 38, radius: 20)),
                            const SizedBox(width: 8),
                            Expanded(child: shimmerBone(height: 38, radius: 20)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(24),
                    itemCount: 5,
                    itemBuilder: (_, _) => const ShimmerVideoListCard(),
                  ),
                ),
              ],
            );
          } else {
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: ShimmerBase(
                    child: Padding(
                      padding: EdgeInsets.all(isTablet ? 24.0 : 16.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: isTablet ? 200.0 : 140.0,
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: shimmerBone(
                                width: double.infinity,
                                radius: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                shimmerBone(
                                  width: double.infinity,
                                  height: 18,
                                ),
                                const SizedBox(height: 8),
                                shimmerBone(width: 100),
                                const SizedBox(height: 10),
                                shimmerBone(width: 120, height: 12),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: shimmerBone(
                                        height: 38,
                                        radius: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: shimmerBone(
                                        height: 38,
                                        radius: 20,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: ShimmerBase(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: shimmerBone(
                        width: double.infinity,
                        height: 40,
                        radius: 8,
                      ),
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => const ShimmerVideoListCard(),
                    childCount: 4,
                  ),
                ),
              ],
            );
          }
        },
      ),
    );
  }
}

/// Loading skeleton matching the responsive Video detail playback screen.
class ShimmerVideoScreen extends StatelessWidget {
  const ShimmerVideoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth > 1050;

            final videoPlayerPlaceholder = ShimmerBase(
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  decoration: const BoxDecoration(color: AppColors.bgPage),
                  child: const Center(
                    child: Icon(
                      Icons.play_circle_outline_rounded,
                      color: Colors.white38,
                      size: 64,
                    ),
                  ),
                ),
              ),
            );

            final mainContent = ShimmerBase(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    shimmerBone(width: double.infinity, height: 20),
                    const SizedBox(height: 8),
                    shimmerBone(width: 200),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        shimmerBone(width: 40, height: 40, radius: 20),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            shimmerBone(width: 120),
                            const SizedBox(height: 4),
                            shimmerBone(width: 80, height: 11),
                          ],
                        ),
                        const Spacer(),
                        shimmerBone(width: 90, height: 36, radius: 18),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        shimmerBone(width: 80, height: 36, radius: 18),
                        const SizedBox(width: 8),
                        shimmerBone(width: 80, height: 36, radius: 18),
                        const SizedBox(width: 8),
                        shimmerBone(width: 80, height: 36, radius: 18),
                      ],
                    ),
                  ],
                ),
              ),
            );

            if (isDesktop) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          videoPlayerPlaceholder,
                          mainContent,
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Divider(
                              color: AppColors.bgDivider,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: 360,
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: AppColors.bgDivider,
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 4,
                      itemBuilder: (_, _) => const ShimmerVideoListCard(),
                    ),
                  ),
                ],
              );
            } else {
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    videoPlayerPlaceholder,
                    mainContent,
                    const Divider(color: AppColors.bgDivider, height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: ShimmerBase(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            shimmerBone(width: 100, height: 16),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                shimmerBone(width: 28, height: 28, radius: 14),
                                const SizedBox(width: 10),
                                shimmerBone(width: 200, height: 12),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
          },
        ),
      ),
    );
  }
}
