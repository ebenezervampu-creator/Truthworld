import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/widgets/skeletons/shimmer_base.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/analytics/presentation/pages/revenue_analytics_page.dart';
import 'package:truthworld/features/analytics/presentation/pages/subscribers_page.dart';
import 'package:truthworld/features/analytics/presentation/pages/views_page.dart';
import 'package:truthworld/features/analytics/presentation/pages/watch_time_page.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/monetization_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/widgets/studio_animated_counter.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/widgets/studio_interactive_card.dart';
import 'package:truthworld/theme/app_theme.dart';

class DashboardChannelStatsGrid extends StatelessWidget {
  final bool isDarkMode;
  final bool isMobile;
  final bool isDesktop;
  final bool isTablet;
  final dynamic channel;
  final Map<String, dynamic> channelStats;
  final bool isLoading;
  final Animation<double> statsAnimation;

  const DashboardChannelStatsGrid({
    required this.isDarkMode,
    required this.isMobile,
    required this.isDesktop,
    required this.isTablet,
    required this.channel,
    required this.channelStats,
    required this.isLoading,
    required this.statsAnimation,
    super.key,
  });

  static String getChannelId(dynamic ch) {
    if (ch == null) return '';
    if (ch is Channel) return ch.id;
    if (ch is Map) return (ch['id'] ?? '').toString();
    if (ch is DocumentSnapshot) return ch.id;
    return '';
  }

  static String getChannelName(dynamic ch) {
    if (ch == null) return 'Unknown Channel';
    if (ch is Channel) return ch.name.isNotEmpty ? ch.name : 'Unknown Channel';
    if (ch is Map) {
      final val = ch['channelName'] ?? ch['name'];
      return (val != null && val.toString().isNotEmpty)
          ? val.toString()
          : 'Unknown Channel';
    }
    if (ch is DocumentSnapshot) {
      final data = ch.data() as Map<String, dynamic>?;
      final val = data?['channelName'] ?? data?['name'];
      return (val != null && val.toString().isNotEmpty)
          ? val.toString()
          : 'Unknown Channel';
    }
    return 'Unknown Channel';
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: statsAnimation,
      child: FadeTransition(
        opacity: statsAnimation,
        child: Builder(
          builder: (context) {
            if (isLoading && channelStats.isEmpty) {
              return DashboardStatsLoadingGrid(
                isDarkMode: isDarkMode,
                isMobile: isMobile,
                isDesktop: isDesktop,
                isTablet: isTablet,
              );
            }

            final channelData = channel;
            final channelId = getChannelId(channelData);
            final channelName = getChannelName(channelData);

            if (isMobile) {
              return Column(
                children: [
                  DashboardStatCard(
                    index: 0,
                    title: 'Views',
                    value: channelStats['views'] ?? '0',
                    change: channelStats['viewsChange'] ?? '+0%',
                    icon: Icons.visibility_rounded,
                    color: AppColors.success,
                    isDarkMode: isDarkMode,
                    isMobile: isMobile,
                    onTap: () {
                      if (channelData != null) {
                        Get.to(
                          () => const ViewsPage(),
                          arguments: {
                            'channelId': channelId,
                            'channelName': channelName,
                            'viewsChange': channelStats['viewsChange'] ?? '+0%',
                            'views': channelStats['views'] ?? '0',
                          },
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  DashboardStatCard(
                    index: 1,
                    title: 'Watch Time',
                    value: channelStats['watchTime'] ?? '0h',
                    change: channelStats['watchTimeChange'] ?? '+0%',
                    icon: Icons.timer_rounded,
                    color: AppColors.info,
                    isDarkMode: isDarkMode,
                    isMobile: isMobile,
                    onTap: () {
                      if (channelData != null) {
                        Get.to(
                          () => const WatchTimePage(),
                          arguments: {
                            'channelId': channelId,
                            'channelName': channelName,
                            'watchTimeChange':
                                channelStats['watchTimeChange'] ?? '+0%',
                            'watchTime': channelStats['watchTime'] ?? '0 mins',
                          },
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  DashboardStatCard(
                    index: 2,
                    title: 'Subscribers',
                    value: channelStats['subscribers'] ?? '0',
                    change: channelStats['subscribersChange'] ?? '+0',
                    icon: Icons.people_rounded,
                    color: AppColors.brand,
                    isDarkMode: isDarkMode,
                    isMobile: isMobile,
                    onTap: () {
                      if (channelData != null) {
                        Get.to(
                          () => const SubscribersPage(),
                          arguments: {
                            'channelId': channelId,
                            'channelName': channelName,
                            'subscribersChange':
                                channelStats['subscribersChange'] ?? '+0',
                            'subscribers': channelStats['subscribers'] ?? '0',
                          },
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  DashboardStatCard(
                    index: 3,
                    title: 'Revenue',
                    value: channelStats['revenue'] ?? '₹0.00',
                    change: channelStats['revenueChange'] ?? '+₹0.00',
                    icon: Icons.currency_rupee_rounded,
                    color: AppColors.warning,
                    isDarkMode: isDarkMode,
                    isMobile: isMobile,
                    onTap: () {
                      if (channelData != null) {
                        if (Get.isRegistered<DashboardController>()) {
                          Get.find<DashboardController>().setSelectedIndex(5);
                        } else {
                          Get.to(
                            () => MonetizationScreen(isDarkMode: isDarkMode),
                            arguments: {
                              'channelId': channelId,
                              'channelName': channelName,
                              'revenueChange':
                                  channelStats['revenueChange'] ?? '+₹0.00',
                            },
                          );
                        }
                      }
                    },
                  ),
                ],
              );
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                final textScale = MediaQuery.textScalerOf(context).scale(1.0);
                final width = constraints.maxWidth;
                final cols = (isDesktop && width >= 860) ? 4 : (width >= 480 ? 2 : 1);
                final baseRatio = cols == 4 ? 1.25 : (cols == 2 ? 1.5 : 2.4);
                final childAspectRatio = (baseRatio / textScale.clamp(1.0, 1.5)).clamp(0.85, 3.0);

                return GridView.count(
                  crossAxisCount: cols,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: childAspectRatio,
                  children: [
                DashboardStatCard(
                  index: 0,
                  title: 'Views',
                  value: channelStats['views'] ?? '0',
                  change: channelStats['viewsChange'] ?? '+0%',
                  icon: Icons.visibility_rounded,
                  color: AppColors.success,
                  isDarkMode: isDarkMode,
                  isMobile: isMobile,
                  onTap: () {
                    if (channelData != null) {
                      Get.to(
                        () => const ViewsPage(),
                        arguments: {
                          'channelId': channelId,
                          'channelName': channelName,
                          'viewsChange': channelStats['viewsChange'] ?? '+0%',
                          'views': channelStats['views'] ?? '0',
                        },
                      );
                    }
                  },
                ),
                DashboardStatCard(
                  index: 1,
                  title: 'Watch Time',
                  value: channelStats['watchTime'] ?? '0h',
                  change: channelStats['watchTimeChange'] ?? '+0%',
                  icon: Icons.timer_rounded,
                  color: AppColors.info,
                  isDarkMode: isDarkMode,
                  isMobile: isMobile,
                  onTap: () {
                    if (channelData != null) {
                      Get.to(
                        () => const WatchTimePage(),
                        arguments: {
                          'channelId': channelId,
                          'channelName': channelName,
                          'watchTimeChange':
                              channelStats['watchTimeChange'] ?? '+0%',
                          'watchTime': channelStats['watchTime'] ?? '0 mins',
                        },
                      );
                    }
                  },
                ),
                DashboardStatCard(
                  index: 2,
                  title: 'Subscribers',
                  value: channelStats['subscribers'] ?? '0',
                  change: channelStats['subscribersChange'] ?? '+0',
                  icon: Icons.people_rounded,
                  color: AppColors.brand,
                  isDarkMode: isDarkMode,
                  isMobile: isMobile,
                  onTap: () {
                    if (channelData != null) {
                      Get.to(
                        () => const SubscribersPage(),
                        arguments: {
                          'channelId': channelId,
                          'channelName': channelName,
                          'subscribersChange':
                              channelStats['subscribersChange'] ?? '+0',
                          'subscribers': channelStats['subscribers'] ?? '0',
                        },
                      );
                    }
                  },
                ),
                DashboardStatCard(
                  index: 3,
                  title: 'Revenue',
                  value: channelStats['revenue'] ?? '₹0.00',
                  change: channelStats['revenueChange'] ?? '+₹0.00',
                  icon: Icons.currency_rupee_rounded,
                  color: AppColors.warning,
                  isDarkMode: isDarkMode,
                  isMobile: isMobile,
                  onTap: () {
                    if (channelData != null) {
                      if (Get.isRegistered<DashboardController>()) {
                        Get.find<DashboardController>().setSelectedIndex(5);
                      } else {
                        Get.to(
                          () => MonetizationScreen(isDarkMode: isDarkMode),
                          arguments: {
                            'channelId': channelId,
                            'channelName': channelName,
                            'revenueChange':
                                channelStats['revenueChange'] ?? '+₹0.00',
                          },
                        );
                      }
                    }
                  },
                ),
              ],
            );
          },
        );
          },
        ),
      ),
    );
  }
}

class DashboardStatsLoadingGrid extends StatelessWidget {
  final bool isDarkMode;
  final bool isMobile;
  final bool isDesktop;
  final bool isTablet;

  const DashboardStatsLoadingGrid({
    required this.isDarkMode,
    required this.isMobile,
    required this.isDesktop,
    required this.isTablet,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (isMobile) {
      return Column(
        children: List.generate(
          4,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: DashboardStatCardSkeleton(isDarkMode: isDarkMode),
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1.0);
        final width = constraints.maxWidth;
        final cols = (isDesktop && width >= 860) ? 4 : (width >= 480 ? 2 : 1);
        final baseRatio = cols == 4 ? 1.25 : (cols == 2 ? 1.5 : 2.4);
        final childAspectRatio = (baseRatio / textScale.clamp(1.0, 1.5)).clamp(0.85, 3.0);

        return GridView.count(
          crossAxisCount: cols,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: childAspectRatio,
          children: List.generate(
            4,
            (index) => DashboardStatCardSkeleton(isDarkMode: isDarkMode),
          ),
        );
      },
    );
  }
}

class DashboardStatCardSkeleton extends StatelessWidget {
  final bool isDarkMode;

  const DashboardStatCardSkeleton({
    required this.isDarkMode,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.bgDivider,
        ),
      ),
      child: ShimmerBase(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  shimmerBone(width: 60, height: 14, radius: 6),
                  shimmerBone(width: 24, height: 24, radius: 8),
                ],
              ),
              const SizedBox(height: 16),
              shimmerBone(width: 80, height: 24, radius: 6),
              const SizedBox(height: 12),
              shimmerBone(width: 50, height: 14, radius: 4),
            ],
          ),
        ),
      ),
    );
  }
}

class DashboardStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String change;
  final IconData icon;
  final Color color;
  final bool isDarkMode;
  final bool isMobile;
  final VoidCallback? onTap;
  final int index;

  const DashboardStatCard({
    required this.title,
    required this.value,
    required this.change,
    required this.icon,
    required this.color,
    required this.isDarkMode,
    required this.isMobile,
    this.onTap,
    this.index = 0,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = change.startsWith('+');

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 320 + (index * 70)),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, animationValue, child) {
        return Transform.translate(
          offset: Offset(0, 16 * (1 - animationValue)),
          child: Opacity(
            opacity: animationValue,
            child: StudioInteractiveCard(
              onTap: () {
                HapticFeedback.lightImpact();
                if (onTap != null) onTap!();
              },
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.bgSurfaceHover,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(icon, color: AppColors.textPrimary, size: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  StudioAnimatedMetricValue(
                    value: value,
                    style: TextStyle(
                      fontFamily: TWTypography.brandFamily,
                      fontSize: isMobile ? 20 : 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isPositive
                              ? AppColors.success.withValues(alpha: 0.15)
                              : AppColors.error.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPositive
                                  ? Icons.trending_up_rounded
                                  : Icons.trending_down_rounded,
                              size: 13,
                              color: isPositive
                                  ? AppColors.success
                                  : AppColors.error,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              change,
                              style: TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                color: isPositive
                                    ? AppColors.success
                                    : AppColors.error,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
