import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:truthworld/features/analytics/presentation/controllers/creator_analytics_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

class SubscribersPage extends StatelessWidget {
  const SubscribersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<CreatorAnalyticsController>();
    final args = Get.arguments as Map<String, dynamic>? ?? {};
    final channelId = args['channelId'] as String? ?? '';
    final videoId = args['videoId'] as String? ?? '';

    // Load analytics on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (videoId.isNotEmpty) {
        controller.selectedVideoId.value = videoId;
      } else if (channelId.isNotEmpty) {
        controller.selectedChannelId.value = channelId;
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
          'Subscriber Analytics',
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
            child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
          );
        }

        return RefreshIndicator(
          color: const Color(0xFF8B5CF6),
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
                          Icon(Icons.close, color: Color(0xFF8B5CF6), size: 16),
                          SizedBox(width: 4),
                          Text(
                            'Back to Channel Analytics',
                            style: TextStyle(
                              color: Color(0xFF8B5CF6),
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
                const _SectionHeader(title: 'Growth Trend'),
                const SizedBox(height: 12),
                _buildTrendChart(controller),
                const SizedBox(height: 24),
                const _SectionHeader(title: 'Top Videos for Subscriptions'),
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
    final subscribersChange = args['subscribersChange'] as String? ?? '+0';
    final isPositive = !subscribersChange.startsWith('-');
    final totalSubs = controller.selectedVideoId.value.isNotEmpty
        ? (controller.videoAnalytics.value?.subscribersGained ?? 0) -
              (controller.videoAnalytics.value?.subscribersLost ?? 0)
        : (controller.channelAnalytics.value?.subscribersGained ?? 0) -
              (controller.channelAnalytics.value?.subscribersLost ?? 0);

    final title = controller.selectedVideoId.value.isNotEmpty
        ? (controller.videoAnalytics.value?.title ?? 'Video Analytics')
        : 'Net Subscribers';

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
            NumberFormat.compact().format(totalSubs),
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
                  '$subscribersChange in last 28 days',
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
          const SizedBox(height: 16),
          Row(
            children: [
              _StatItem(
                label: 'Gained',
                value: NumberFormat.compact().format(
                  controller.selectedVideoId.value.isNotEmpty
                      ? controller.videoAnalytics.value?.subscribersGained ?? 0
                      : controller.channelAnalytics.value?.subscribersGained ??
                            0,
                ),
                color: const Color(0xFF22C55E),
              ),
              const SizedBox(width: 24),
              _StatItem(
                label: 'Lost',
                value: NumberFormat.compact().format(
                  controller.selectedVideoId.value.isNotEmpty
                      ? controller.videoAnalytics.value?.subscribersLost ?? 0
                      : controller.channelAnalytics.value?.subscribersLost ?? 0,
                ),
                color: const Color(0xFFEF4444),
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
        child: SfCartesianChart(
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
          series: <CartesianSeries<SubscribersTrendModel, DateTime>>[
            ColumnSeries<SubscribersTrendModel, DateTime>(
              dataSource: controller.subscribersTrendData,
              xValueMapper: (SubscribersTrendModel data, _) => data.date,
              yValueMapper: (SubscribersTrendModel data, _) => data.subscribers,
              pointColorMapper: (SubscribersTrendModel data, _) =>
                  data.subscribers >= 0
                  ? const Color(0xFF8B5CF6)
                  : const Color(0xFFEF4444),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(4),
              ),
              name: 'Net Subscribers',
            ),
          ],
        ),
      ),
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
            },
          );
        },
      );
    });
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.textPrimary.withValues(alpha: 0.4),
            fontSize: 11,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
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
                  Row(
                    children: [
                      const Icon(
                        Icons.people_alt_rounded,
                        color: Color(0xFF8B5CF6),
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Most conversions',
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
