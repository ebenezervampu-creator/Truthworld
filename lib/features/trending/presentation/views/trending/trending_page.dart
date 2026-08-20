import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/widgets/responsive_video_grid.dart';
import 'package:truthworld/core/widgets/shimmer_skeletons.dart';
import 'package:truthworld/features/trending/presentation/controllers/trending_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

class TrendingVideosPage extends GetView<TrendingController> {
  const TrendingVideosPage({super.key, this.isDashboard = false});
  final bool isDashboard;

  @override
  TrendingController get controller =>
      Get.isRegistered<TrendingController>()
          ? Get.find<TrendingController>()
          : Get.put(TrendingController());

  @override
  Widget build(BuildContext context) {
    controller;

    return ResponsiveBuilder(
      builder: (context, device) {
        final deviceType = device.type;
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: !isDashboard ? _buildAppBar(context, deviceType) : null,
          body: SafeArea(child: Obx(() => _buildBody(context, deviceType))),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    DeviceType deviceType,
  ) {
    return AppBar(
      title: Text(
        'Trending Videos',
        style: AppTextStyles.headlineSmall.copyWith(
          fontSize:
              (AppTextStyles.headlineSmall.fontSize ?? 24) * context.fontScale,
        ),
      ),
      backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      elevation: 0,
      centerTitle: deviceType == DeviceType.mobile,
      actions: [
        IconButton(
          icon: Icon(
            Icons.filter_list,
            size: deviceType == DeviceType.mobile ? 20 : 24,
          ),
          onPressed: () {
            // Show filter options
          },
        ),
        if (deviceType != DeviceType.mobile) ...[
          const SizedBox(width: 20),
          IconButton(
            icon: Icon(
              Icons.view_list,
              size: deviceType == DeviceType.mobile ? 20 : 24,
            ),
            onPressed: () {
              // Toggle view mode
            },
          ),
        ],
      ],
    );
  }

  Widget _buildBody(BuildContext context, DeviceType deviceType) {
    if (controller.isLoading) {
      return _buildLoadingState(context, deviceType);
    }

    if (controller.trendingVideos.isEmpty) {
      return _buildEmptyState(context, deviceType);
    }

    return ResponsiveContainer(
      child: Column(
        children: [
          _buildTrendingHeader(context, deviceType),
          SizedBox(height: context.layoutSpacing),
          Expanded(child: _buildVideoGrid(context, deviceType)),
        ],
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context, DeviceType deviceType) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.layoutSpacing,
          vertical: 16,
        ),
        child: deviceType == DeviceType.mobile
            ? buildShimmerVideoList()
            : buildShimmerVideoGrid(
                crossAxisCount: deviceType == DeviceType.tablet ? 3 : 4,
                count: 8,
              ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, DeviceType deviceType) {
    return ResponsiveContainer(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.trending_up,
              size: deviceType == DeviceType.mobile ? 64 : 96,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            SizedBox(height: context.layoutSpacing),
            Text(
              'No trending videos available',
              style: AppTextStyles.headlineSmall.copyWith(
                fontSize:
                    (AppTextStyles.headlineSmall.fontSize ?? 24) *
                    context.fontScale,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            SizedBox(height: context.layoutSpacing / 2),
            Text(
              'Check back later for the latest trending content',
              style: AppTextStyles.bodyMedium.copyWith(
                fontSize:
                    (AppTextStyles.bodyMedium.fontSize ?? 14) *
                    context.fontScale,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => controller.refreshTrending(),
              child: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendingHeader(BuildContext context, DeviceType deviceType) {
    return ResponsiveContainer(
      padding: EdgeInsets.symmetric(horizontal: context.layoutSpacing),
      child: Row(
        children: [
          const Icon(
            Icons.local_fire_department,
            color: AppColors.warning,
            size: 24,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '🔥 Hot Right Now',
              style: AppTextStyles.titleLarge.copyWith(
                fontSize:
                    (AppTextStyles.titleLarge.fontSize ?? 22) *
                    context.fontScale,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${controller.trendingVideos.length} videos',
              style: AppTextStyles.labelSmall.copyWith(
                fontSize:
                    (AppTextStyles.labelSmall.fontSize ?? 11) *
                    context.fontScale,
                color: AppColors.warning,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoGrid(BuildContext context, DeviceType deviceType) {
    return ResponsiveVideoGrid(
      videos: controller.trendingVideos,
      heroPrefix: 'trending',
      accentColor: AppColors.warning,
      showListView: deviceType == DeviceType.mobile,
      maxColumns: deviceType == DeviceType.mobile
          ? 2
          : deviceType == DeviceType.tablet
          ? 3
          : 4,
    );
  }
}
