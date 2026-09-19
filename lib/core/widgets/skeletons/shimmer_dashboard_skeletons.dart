import 'package:flutter/material.dart';
import 'package:truthworld/core/widgets/skeletons/shimmer_base.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Loading skeleton matching the Creator Studio dashboard view.
class ShimmerDashboard extends StatelessWidget {
  const ShimmerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ShimmerBase(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      shimmerBone(width: 250, height: 28),
                      const SizedBox(height: 8),
                      shimmerBone(width: 180),
                    ],
                  ),
                  shimmerBone(width: 140, height: 40, radius: 20),
                ],
              ),
              const SizedBox(height: 32),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 600;
                  final isTablet =
                      constraints.maxWidth >= 600 &&
                      constraints.maxWidth < 1000;

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isMobile ? 2 : (isTablet ? 2 : 4),
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.5,
                    ),
                    itemCount: 4,
                    itemBuilder: (context, index) {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.bgSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.bgDivider,
                            width: 0.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                shimmerBone(width: 24, height: 24, radius: 12),
                                const SizedBox(width: 8),
                                shimmerBone(width: 70, height: 12),
                              ],
                            ),
                            const SizedBox(height: 16),
                            shimmerBone(width: 100, height: 24),
                            const SizedBox(height: 8),
                            shimmerBone(width: 60, height: 11),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 32),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isSingleColumn = constraints.maxWidth < 900;

                  final mainArea = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 240,
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.bgSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.bgDivider,
                            width: 0.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            shimmerBone(width: 180, height: 18),
                            const SizedBox(height: 24),
                            Expanded(
                              child: Container(
                                width: double.infinity,
                                color: AppColors.bgDivider,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      shimmerBone(width: 140, height: 18),
                      const SizedBox(height: 16),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: 3,
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              shimmerBone(width: 120, height: 68, radius: 8),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    shimmerBone(width: double.infinity),
                                    const SizedBox(height: 6),
                                    shimmerBone(width: 150, height: 11),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );

                  final sidebarArea = Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.bgSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.bgDivider,
                        width: 0.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        shimmerBone(width: 100, height: 16),
                        const SizedBox(height: 16),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: 4,
                          itemBuilder: (context, index) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              children: [
                                shimmerBone(width: 20, height: 20, radius: 10),
                                const SizedBox(width: 10),
                                shimmerBone(width: 80, height: 12),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );

                  if (isSingleColumn) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        mainArea,
                        const SizedBox(height: 24),
                        sidebarArea,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: mainArea),
                      const SizedBox(width: 24),
                      Expanded(child: sidebarArea),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Loading skeleton matching the Channel Details screen.
class ShimmerChannelDetailsScreen extends StatelessWidget {
  const ShimmerChannelDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: ShimmerBase(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                height: 140,
                color: AppColors.textPrimary,
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    shimmerBone(width: 80, height: 80, radius: 40),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          shimmerBone(width: 180, height: 22, radius: 6),
                          const SizedBox(height: 8),
                          shimmerBone(width: 120),
                          const SizedBox(height: 8),
                          shimmerBone(width: 200, height: 12),
                          const SizedBox(height: 12),
                          shimmerBone(width: 130, height: 36, radius: 18),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    shimmerBone(width: 60, height: 32, radius: 8),
                    const SizedBox(width: 12),
                    shimmerBone(width: 70, height: 32, radius: 8),
                    const SizedBox(width: 12),
                    shimmerBone(width: 70, height: 32, radius: 8),
                    const SizedBox(width: 12),
                    shimmerBone(width: 60, height: 32, radius: 8),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Divider(color: AppColors.bgDivider, height: 1),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth >= 900;
                    final crossAxisCount = isDesktop ? 3 : 1;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: isDesktop ? 16 / 13 : 16 / 10,
                      ),
                      itemCount: isDesktop ? 6 : 3,
                      itemBuilder: (context, index) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: shimmerBone(
                                width: double.infinity,
                                radius: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            shimmerBone(width: double.infinity, height: 16),
                            const SizedBox(height: 4),
                            shimmerBone(width: 140, height: 12),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
