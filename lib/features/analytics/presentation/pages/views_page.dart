import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:truthworld/features/analytics/presentation/controllers/creator_analytics_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

class ViewsPage extends StatelessWidget {
  const ViewsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = CreatorAnalyticsController.to;
    final args = Get.arguments as Map<String, dynamic>? ?? {};
    final channelId = args['channelId'] as String? ?? '';
    final videoId = args['videoId'] as String? ?? '';

    // Load analytics on init
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (channelId.isNotEmpty) {
        controller.selectedChannelId.value = channelId;
      }
      if (videoId.isNotEmpty) {
        controller.selectedVideoId.value = videoId;
        await controller.loadVideoAnalytics(videoId);
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
        title: const Text(
          'Views Analytics',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
      ),
      body: Obx(() {
        final isLoading =
            controller.isLoadingVideoAnalytics.value ||
            controller.isLoadingChannelAnalytics.value;

        if (isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF10B981)),
          );
        }

        return RefreshIndicator(
          color: const Color(0xFF10B981),
          onRefresh: controller.refreshAnalytics,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (controller.selectedVideoId.value.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: InkWell(
                      onTap: () {
                        controller.selectedVideoId.value = '';
                        controller.loadChannelAnalytics(
                          controller.selectedChannelId.value,
                        );
                      },
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.close, color: Color(0xFF10B981), size: 16),
                          SizedBox(width: 4),
                          Text(
                            'Back to Channel Analytics',
                            style: TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                _buildMainMetric(controller, args),
                const SizedBox(height: 24),
                const _SectionHeader(title: 'Views Trend'),
                const SizedBox(height: 12),
                _buildTrendChart(controller),
                const SizedBox(height: 24),
                const _SectionHeader(title: 'Geographic Distribution'),
                const SizedBox(height: 12),
                _buildGeoBreakdown(controller),
                const SizedBox(height: 24),
                const _SectionHeader(title: 'Individual Video Performance'),
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
    final viewsChange = args['viewsChange'] as String? ?? '+0%';
    final isPositive = viewsChange.startsWith('+');
    var totalViews = controller.selectedVideoId.value.isNotEmpty
        ? (controller.videoAnalytics.value?.totalViews ?? 0)
        : ((controller.channelAnalytics.value?.totalVideoWatches ?? 0) > 0
            ? controller.channelAnalytics.value!.totalVideoWatches
            : (controller.channelVideos.isNotEmpty
                ? controller.channelVideos.fold<int>(
                    0,
                    (sum, v) => sum + v.viewCount,
                  )
                : 0));

    if (totalViews == 0 && controller.selectedVideoId.value.isEmpty) {
      final initialViewsStr = args['views'] as String? ?? '';
      final parsed = int.tryParse(initialViewsStr.replaceAll(RegExp('[^0-9]'), ''));
      if (parsed != null && parsed > 0) {
        totalViews = parsed;
      }
    }

    final title = controller.selectedVideoId.value.isNotEmpty
        ? (controller.videoAnalytics.value?.title ?? 'Video Analytics')
        : 'Total Channel Views';

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppColors.textPrimary.withValues(alpha: 0.6),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            NumberFormat.compact().format(totalViews),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 48,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 4),
          if (controller.selectedVideoId.value.isEmpty)
            Row(
              children: [
                Icon(
                  isPositive ? Icons.trending_up : Icons.trending_down,
                  color: isPositive
                      ? const Color(0xFF22C55E)
                      : const Color(0xFFEF4444),
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  '$viewsChange in last 28 days',
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
    return _GlassCard(
      child: SizedBox(
        height: 240,
        child: Obx(() {
          final trend = controller.viewsTrendData;
          return SfCartesianChart(
            plotAreaBorderWidth: 0,
            margin: EdgeInsets.zero,
            primaryXAxis: const DateTimeAxis(
              majorGridLines: MajorGridLines(width: 0),
              labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 10),
              axisLine: AxisLine(width: 0),
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
            ),
            tooltipBehavior: TooltipBehavior(enable: true),
            series: <CartesianSeries<ViewsTrendModel, DateTime>>[
              SplineAreaSeries<ViewsTrendModel, DateTime>(
                dataSource: trend,
                xValueMapper: (data, _) => data.date,
                yValueMapper: (data, _) => data.views,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF10B981).withValues(alpha: 0.3),
                    const Color(0xFF10B981).withValues(alpha: 0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderColor: const Color(0xFF10B981),
                name: 'Views',
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildGeoBreakdown(CreatorAnalyticsController controller) {
    return Column(
      children: [
        _GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Country Distribution',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 180,
                child: Obx(() {
                  final data = controller.countryTrafficChartData;
                  if (data.isEmpty) {
                    return const Center(
                      child: Text(
                        'No data',
                        style: TextStyle(color: AppColors.textTertiary),
                      ),
                    );
                  }
                  return SfCircularChart(
                    margin: EdgeInsets.zero,
                    series: <CircularSeries>[
                      DoughnutSeries<dynamic, String>(
                        dataSource: data,
                        xValueMapper: (dynamic d, _) => d.title as String,
                        yValueMapper: (dynamic d, _) => d.value as num,
                        pointColorMapper: (dynamic d, _) => Color(d.color as int),
                        dataLabelMapper: (dynamic d, _) =>
                            '${((d.percentage as num?)?.toDouble() ?? 0.0).toStringAsFixed(1)}%',
                        dataLabelSettings: const DataLabelSettings(
                          isVisible: true,
                          textStyle: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        innerRadius: '45%',
                        radius: '85%',
                      ),
                    ],
                  );
                }),
              ),
              const SizedBox(height: 12),
              Obx(
                () => Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: controller.countryTrafficChartData
                      .map(
                        (d) => _LegendItem(
                          color: Color(d.color),
                          label: d.title,
                          value: '${d.percentage.toStringAsFixed(1)}%',
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Top Indian States',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Obx(() {
                final states = controller.stateTrafficChartData;
                if (states.isEmpty) {
                  return const Center(
                    child: Text(
                      'No data',
                      style: TextStyle(color: AppColors.textTertiary),
                    ),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: states.length.clamp(0, 5),
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final s = states[index];
                    return Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              s.title,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '${s.percentage.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: s.percentage / 100,
                            backgroundColor: AppColors.textPrimary.withValues(
                              alpha: 0.05,
                            ),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(s.color),
                            ),
                            minHeight: 4,
                          ),
                        ),
                      ],
                    );
                  },
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVideosList(CreatorAnalyticsController controller) {
    return Obx(() {
      final videos = controller.channelVideos;
      if (videos.isEmpty) {
        return const Center(
          child: Text(
            'No videos found',
            style: TextStyle(color: AppColors.textTertiary),
          ),
        );
      }

      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: videos.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final video = videos[index];
          return _VideoStatCard(
            video: video,
            onTap: () {
              controller.selectedVideoId.value = video.id;
              // Scroll to top or just update metrics
            },
          );
        },
      );
    });
  }
}

class _VideoStatCard extends StatelessWidget {
  const _VideoStatCard({required this.video, required this.onTap});
  final Video video;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.textPrimary.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.textPrimary.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
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
                  Text(
                    '${NumberFormat.compact().format(video.viewCount)} views',
                    style: TextStyle(
                      color: AppColors.textPrimary.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textDisabled,
              size: 20,
            ),
          ],
        ),
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
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label: $value',
          style: TextStyle(
            color: AppColors.textPrimary.withValues(alpha: 0.6),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
