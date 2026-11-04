import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:truthworld/core/utils/watch_time_formatter.dart';
import 'package:truthworld/features/analytics/presentation/controllers/creator_analytics_controller.dart';
import 'package:truthworld/features/analytics/presentation/pages/creator_analytics/creator_retention_and_traffic_cards.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

class WatchTimePage extends StatelessWidget {
  const WatchTimePage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = CreatorAnalyticsController.to;
    final args = Get.arguments as Map<String, dynamic>? ?? {};
    final channelId = args['channelId'] as String? ?? '';
    final videoId = args['videoId'] as String? ?? '';
    final videoTitle = args['videoTitle'] as String? ?? '';
    final initialWatchTime = args['watchTime'] as String? ?? '';

    // Immediately seed initial watch time if available to prevent showing 0 mins
    if (initialWatchTime.isNotEmpty &&
        (controller.totalWatchTime.value == '0 mins' ||
            controller.totalWatchTime.value == '0h' ||
            controller.totalWatchTime.value.isEmpty)) {
      controller.totalWatchTime.value = initialWatchTime;
    }

    // Load analytics on init
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (channelId.isNotEmpty) {
        controller.selectedChannelId.value = channelId;
      }
      if (videoId.isNotEmpty) {
        controller.selectedVideoId.value = videoId;
        await controller.loadVideoAnalytics(videoId, videoTitle: videoTitle);
      } else if (channelId.isNotEmpty) {
        controller.selectedVideoId.value = '';
        await controller.loadChannelAnalytics(channelId);
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: Get.back,
        ),
        title: Obx(() {
          final isVideo = controller.selectedVideoId.value.isNotEmpty;
          return Text(
            isVideo ? 'Video Watch Time' : 'Channel Watch Time',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          );
        }),
      ),
      body: Obx(() {
        final isLoading =
            controller.isLoadingVideoAnalytics.value ||
            controller.isLoadingChannelAnalytics.value;

        if (isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFDC2626)),
          );
        }

        final isVideoSelected = controller.selectedVideoId.value.isNotEmpty;

        return RefreshIndicator(
          color: const Color(0xFFDC2626),
          onRefresh: controller.refreshAnalytics,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isVideoSelected)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: InkWell(
                      onTap: () {
                        controller.selectedVideoId.value = '';
                        final targetChan = controller.selectedChannelId.value.isNotEmpty
                            ? controller.selectedChannelId.value
                            : (channelId.isNotEmpty
                                ? channelId
                                : (controller.channelVideos.isNotEmpty
                                    ? controller.channelVideos.first.channelId
                                    : ''));
                        if (targetChan.isNotEmpty) {
                          controller.loadChannelAnalytics(targetChan);
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.arrow_back_rounded,
                              color: AppColors.textPrimary,
                              size: 16,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Back to Channel Watch Time',
                              style: TextStyle(
                                color: Color(0xFF60A5FA),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                _buildMainMetric(controller, args),
                const SizedBox(height: 24),
                const _SectionHeader(title: 'Watch Time Trend'),
                const SizedBox(height: 12),
                _buildTrendChart(controller),
                const SizedBox(height: 24),
                const _SectionHeader(title: 'Audience Retention'),
                const SizedBox(height: 12),
                _WatchtimeRetentionCard(controller: controller),
                const SizedBox(height: 24),
                const _SectionHeader(title: 'Key Insights'),
                const SizedBox(height: 12),
                _buildInsightsGrid(controller),
                const SizedBox(height: 24),
                const _SectionHeader(title: 'Individual Video Watch Time'),
                const SizedBox(height: 12),
                _buildVideosList(controller),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildMainMetric(
    CreatorAnalyticsController controller,
    Map<String, dynamic> args,
  ) {
    final watchTimeChange = args['watchTimeChange'] as String? ?? '+0%';
    final initialWatchTime = args['watchTime'] as String? ?? '';
    final isPositive = watchTimeChange.startsWith('+');

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Obx(() {
            final isVideo = controller.selectedVideoId.value.isNotEmpty;
            final videoTitle = controller.videoAnalytics.value?.title ?? '';
            return Text(
              isVideo && videoTitle.isNotEmpty
                  ? videoTitle
                  : 'Total Watch Time',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textPrimary.withValues(alpha: 0.6),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            );
          }),
          const SizedBox(height: 8),
          Obx(() {
            var displayTime = controller.totalWatchTime.value;
            final isVideoSelected = controller.selectedVideoId.value.isNotEmpty;

            if (isVideoSelected) {
              final currentVideo = controller.channelVideos.firstWhereOrNull(
                (v) => v.id == controller.selectedVideoId.value,
              );
              final expectedSeconds = (currentVideo != null && currentVideo.totalWatchTimeSeconds > 0)
                  ? currentVideo.totalWatchTimeSeconds
                  : (controller.videoAnalytics.value?.totalWatchTimeSeconds ?? 0);

              if (expectedSeconds > 0) {
                final currentSeconds =
                    controller.videoAnalytics.value?.totalWatchTimeSeconds ?? 0;
                if ((displayTime.isEmpty ||
                        displayTime == '0 mins' ||
                        displayTime == '0h' ||
                        displayTime == '0.0h') ||
                    currentSeconds == 0 ||
                    currentSeconds < expectedSeconds ||
                    currentSeconds > expectedSeconds) {
                  displayTime = WatchTimeFormatter.format(expectedSeconds);
                }
              }
            } else if (controller.channelVideos.isNotEmpty) {
              final totalSec = controller.channelVideos.fold<int>(
                0,
                (sum, v) => sum + v.totalWatchTimeSeconds,
              );
              if ((displayTime.isEmpty ||
                      displayTime == '0 mins' ||
                      displayTime == '0h' ||
                      displayTime == '0.0h') &&
                  totalSec > 0) {
                displayTime = WatchTimeFormatter.format(totalSec);
              } else if (totalSec > 0) {
                final currentSeconds =
                    controller.channelAnalytics.value?.totalWatchTimeSeconds ?? 0;
                final bestSec = math.max(currentSeconds, totalSec);
                displayTime = WatchTimeFormatter.format(bestSec);
              }
            }

            if ((displayTime.isEmpty ||
                    displayTime == '0 mins' ||
                    displayTime == '0h' ||
                    displayTime == '0.0h') &&
                initialWatchTime.isNotEmpty) {
              displayTime = initialWatchTime;
            }

            return Text(
              displayTime.isNotEmpty ? displayTime : '0 mins',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 48,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
              ),
            );
          }),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                isPositive ? Icons.trending_up : Icons.trending_down,
                color: AppColors.textPrimary,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                '$watchTimeChange in last 28 days',
                style: TextStyle(
                  color:
                      (isPositive
                              ? const Color(0xFF22C55E)
                              : const Color(0xFFEF4444))
                          .withValues(alpha: 0.8),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrendChart(CreatorAnalyticsController controller) {
    return Obx(() {
      final hasData = controller.watchTimeTrendData.isNotEmpty;
      final minDate = hasData
          ? controller.watchTimeTrendData.first.date
          : DateTime.now().subtract(const Duration(days: 28));
      final maxDate = hasData
          ? controller.watchTimeTrendData.last.date
          : DateTime.now();

      return _GlassCard(
        child: SizedBox(
          height: 240,
          child: SfCartesianChart(
            plotAreaBorderWidth: 0,
            margin: EdgeInsets.zero,
            primaryXAxis: DateTimeAxis(
              majorGridLines: const MajorGridLines(width: 0),
              labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
              axisLine: const AxisLine(width: 0),
              minimum: minDate,
              maximum: maxDate,
              intervalType: DateTimeIntervalType.days,
            ),
            primaryYAxis: NumericAxis(
              majorGridLines: MajorGridLines(
                width: 1,
                color: AppColors.textPrimary.withValues(alpha: 0.05),
                dashArray: const [5, 5],
              ),
              labelStyle: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
              ),
              axisLine: const AxisLine(width: 0),
              labelFormat: '{value}h',
            ),
            tooltipBehavior: TooltipBehavior(enable: true),
            series: <CartesianSeries<WatchTimeTrendModel, DateTime>>[
              SplineAreaSeries<WatchTimeTrendModel, DateTime>(
                dataSource: controller.watchTimeTrendData.toList(),
                xValueMapper: (data, _) => data.date,
                yValueMapper: (data, _) => data.watchTimeHours,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF3B82F6).withValues(alpha: 0.3),
                    const Color(0xFF3B82F6).withValues(alpha: 0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderColor: const Color(0xFF3B82F6),
                name: 'Watch Time',
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildVideosList(CreatorAnalyticsController controller) {
    return Obx(() {
      final videos = controller.channelVideos;
      if (videos.isEmpty) {
        return const _GlassCard(
          child: Center(
            child: Text(
              'No videos found for this channel',
              style: TextStyle(color: AppColors.textTertiary),
            ),
          ),
        );
      }

      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: videos.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final video = videos[index];
          final isSelected = controller.selectedVideoId.value == video.id;
          return _VideoWatchTimeCard(
            video: video,
            isSelected: isSelected,
            onTap: () {
              if (isSelected) {
                controller.selectedVideoId.value = '';
                controller.loadChannelAnalytics(
                  controller.selectedChannelId.value,
                );
              } else {
                controller.selectedVideoId.value = video.id;
                controller.loadVideoAnalytics(video.id, videoTitle: video.title);
              }
            },
          );
        },
      );
    });
  }

  Widget _buildInsightsGrid(CreatorAnalyticsController controller) {
    return Obx(() {
      var avgDuration = controller.averageWatchTime.value;
      if (avgDuration == '0s' || avgDuration == '0:00' || avgDuration.isEmpty) {
        if (controller.selectedVideoId.value.isNotEmpty) {
          final v = controller.channelVideos.firstWhereOrNull((v) => v.id == controller.selectedVideoId.value);
          if (v != null && v.totalWatchTimeSeconds > 0 && v.viewCount > 0) {
            avgDuration = CreatorGeoTaxonomyHelper.formatSeconds((v.totalWatchTimeSeconds / v.viewCount).round());
          }
        } else if (controller.channelVideos.isNotEmpty) {
          final totalSec = controller.channelVideos.fold<int>(0, (s, v) => s + v.totalWatchTimeSeconds);
          final totalV = controller.channelVideos.fold<int>(0, (s, v) => s + v.viewCount);
          if (totalSec > 0 && totalV > 0) {
            avgDuration = CreatorGeoTaxonomyHelper.formatSeconds((totalSec / totalV).round());
          }
        }
      }

      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
        children: [
          _buildInsightItem(
            'Avg Duration',
            avgDuration.isNotEmpty ? avgDuration : '0s',
            Icons.speed,
            const Color(0xFF8B5CF6),
          ),
          _buildInsightItem(
            'Returning',
            '${controller.returningViewerCount.value}',
            Icons.person_add,
            const Color(0xFFEC4899),
          ),
        ],
      );
    });
  }

  Widget _buildInsightItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: AppColors.textPrimary.withValues(alpha: 0.5),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.textPrimary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.08),
        ),
      ),
      child: child,
    );
  }
}

class _WatchtimeRetentionCard extends StatelessWidget {
  const _WatchtimeRetentionCard({required this.controller});
  final CreatorAnalyticsController controller;

  @override
  Widget build(BuildContext context) {
    return CreatorWatchtimeRetentionCard(controller: controller);
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    required this.value,
  });
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label: $value',
          style: TextStyle(
            color: AppColors.textPrimary.withValues(alpha: 0.7),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _VideoWatchTimeCard extends StatelessWidget {
  const _VideoWatchTimeCard({
    required this.video,
    required this.isSelected,
    required this.onTap,
  });

  final Video video;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final watchTimeStr = WatchTimeFormatter.format(video.totalWatchTimeSeconds);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF3B82F6).withValues(alpha: 0.12)
              : AppColors.textPrimary.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF3B82F6).withValues(alpha: 0.5)
                : AppColors.textPrimary.withValues(alpha: 0.06),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: video.thumbnailUrl,
                    width: 100,
                    height: 56,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: 100,
                      height: 56,
                      color: AppColors.textPrimary.withValues(alpha: 0.05),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 100,
                      height: 56,
                      color: AppColors.textPrimary.withValues(alpha: 0.08),
                      child: const Icon(
                        Icons.video_library_rounded,
                        color: AppColors.textPrimary,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                if (video.duration.isNotEmpty)
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        video.duration,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.timer_outlined,
                              size: 11,
                              color: AppColors.textPrimary,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              watchTimeStr,
                              style: const TextStyle(
                                color: Color(0xFF60A5FA),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${NumberFormat.compact().format(video.viewCount)} views',
                        style: TextStyle(
                          color: AppColors.textPrimary.withValues(alpha: 0.5),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
              color: AppColors.textPrimary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
