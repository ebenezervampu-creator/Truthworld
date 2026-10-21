import 'package:flutter/material.dart';
import 'package:truthworld/core/widgets/skeletons/shimmer_base.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Loading skeleton matching the Creator Studio dashboard view.
class ShimmerDashboard extends StatelessWidget {
  const ShimmerDashboard({
    this.isMobile,
    this.isTablet,
    this.isDesktop,
    this.horizontalPadding,
    this.isDarkMode = true,
    super.key,
  });

  final bool? isMobile;
  final bool? isTablet;
  final bool? isDesktop;
  final double? horizontalPadding;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final width = mediaQuery.size.width;
    final mobile = isMobile ?? (width < 600);
    final tablet = isTablet ?? (width >= 600 && width < 1024);
    final desktop = isDesktop ?? (width >= 1024);
    final hPadding = horizontalPadding ??
        (desktop ? 32.0 : (tablet ? 24.0 : 16.0));

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.bgPage,
            border: Border(
              bottom: BorderSide(
                color: AppColors.bgDivider,
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: 64,
              child: ShimmerBase(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: mobile ? 12 : 20,
                  ),
                  child: Row(
                    children: [
                      if (!desktop) ...[
                        shimmerBone(width: 24, height: 24),
                        const SizedBox(width: 14),
                      ],
                      if (!mobile) ...[
                        shimmerBone(width: 34, height: 34, radius: 8),
                        const SizedBox(width: 12),
                      ],
                      shimmerBone(
                        width: mobile ? 70 : 120,
                        height: 20,
                      ),
                      const Spacer(),
                      if (desktop) ...[
                        shimmerBone(width: 240, height: 38, radius: 8),
                        const SizedBox(width: 16),
                      ],
                      shimmerBone(width: 32, height: 32, radius: 16),
                      SizedBox(width: mobile ? 6 : 10),
                      shimmerBone(
                        width: desktop ? 80 : 32,
                        height: 32,
                        radius: desktop ? 8 : 16,
                      ),
                      SizedBox(width: mobile ? 6 : 10),
                      shimmerBone(width: 32, height: 32, radius: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (desktop)
            Container(
              width: 240,
              decoration: const BoxDecoration(
                color: AppColors.bgPage,
                border: Border(
                  right: BorderSide(
                    color: AppColors.bgDivider,
                    width: 0.5,
                  ),
                ),
              ),
              child: ShimmerBase(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                  child: Column(
                    children: List.generate(
                      9,
                      (index) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            shimmerBone(width: 20, height: 20),
                            const SizedBox(width: 14),
                            shimmerBone(
                              width: (70 + (index * 13) % 45).toDouble(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Expanded(
            child: DashboardOverviewContentSkeleton(
              isMobile: mobile,
              isTablet: tablet,
              isDesktop: desktop,
              horizontalPadding: hPadding,
              isDarkMode: isDarkMode,
            ),
          ),
        ],
      ),
    );
  }
}

/// Overview content skeleton for Creator Studio dashboard tab.
class DashboardOverviewContentSkeleton extends StatelessWidget {
  const DashboardOverviewContentSkeleton({
    required this.isMobile,
    required this.isTablet,
    required this.isDesktop,
    this.horizontalPadding = 16.0,
    this.isDarkMode = true,
    super.key,
  });

  final bool isMobile;
  final bool isTablet;
  final bool isDesktop;
  final double horizontalPadding;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.all(horizontalPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Channel Header Skeleton (DashboardHeader)
          ShimmerBase(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        shimmerBone(
                          width: isMobile ? 160 : 210,
                          height: isMobile ? 22 : 28,
                          radius: 6,
                        ),
                        const SizedBox(height: 6),
                        shimmerBone(
                          width: 90,
                        ),
                      ],
                    ),
                    shimmerBone(
                      width: isMobile ? 110 : 140,
                      height: 32,
                      radius: 16,
                    ),
                  ],
                ),
                if (isMobile) ...[
                  const SizedBox(height: 16),
                  shimmerBone(
                    width: double.infinity,
                    height: 44,
                    radius: 10,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 2. Channel Stats Grid Skeleton (DashboardChannelStatsGrid)
          if (isMobile)
            Column(
              children: List.generate(
                4,
                (index) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildStatCard(),
                ),
              ),
            )
          else
            GridView.count(
              crossAxisCount: isDesktop ? 4 : 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: isDesktop ? 1.25 : 1.5,
              children: List.generate(
                4,
                (index) => _buildStatCard(),
              ),
            ),
          const SizedBox(height: 16),

          // 3. Recent Performance Section Skeleton (DashboardRecentPerformanceSection)
          ShimmerBase(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                shimmerBone(
                  width: isMobile ? 150 : 190,
                  height: isMobile ? 18 : 22,
                ),
                shimmerBone(
                  width: 95,
                  height: 26,
                  radius: 13,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: isMobile ? 240 : 280,
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.bgDivider,
                width: 0.5,
              ),
            ),
            child: ShimmerBase(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      shimmerBone(width: 110),
                      shimmerBone(width: 70, height: 16),
                    ],
                  ),
                  const Spacer(),
                  Column(
                    children: List.generate(
                      4,
                      (index) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Container(
                          height: 1,
                          color: AppColors.bgDivider,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // 4. Latest Content Section Skeleton (DashboardLatestContentSection)
          ShimmerBase(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                shimmerBone(width: 130, height: 18),
                shimmerBone(width: 60),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.bgDivider,
                width: 0.5,
              ),
            ),
            child: ShimmerBase(
              child: Row(
                children: [
                  shimmerBone(
                    width: isMobile ? 110 : 140,
                    height: isMobile ? 64 : 80,
                    radius: 8,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        shimmerBone(
                          width: double.infinity,
                        ),
                        const SizedBox(height: 8),
                        shimmerBone(width: 120, height: 12),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            shimmerBone(width: 44, height: 10, radius: 3),
                            const SizedBox(width: 8),
                            shimmerBone(width: 44, height: 10, radius: 3),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.bgDivider,
          width: 0.5,
        ),
      ),
      child: ShimmerBase(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                shimmerBone(width: 70),
                shimmerBone(width: 24, height: 24, radius: 6),
              ],
            ),
            const SizedBox(height: 12),
            shimmerBone(width: 90, height: 22),
            const SizedBox(height: 10),
            shimmerBone(width: 50),
          ],
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
