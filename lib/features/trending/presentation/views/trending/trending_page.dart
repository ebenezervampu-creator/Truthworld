import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/trending/presentation/controllers/trending_controller.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:truthworld/core/widgets/responsive_video_grid.dart';

class TrendingVideosPage extends GetView<TrendingController> {
  final bool isDashboard;
  const TrendingVideosPage({super.key, this.isDashboard = false});

  @override
  Widget build(BuildContext context) {
    // Inject the controller if not already present
    Get.put(TrendingController());
    
    return ResponsiveBuilder(
      builder: (context, deviceType) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: !isDashboard ? _buildAppBar(context, deviceType) : null,
          body: Obx(() => _buildBody(context, deviceType)),
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
        "Trending Videos",
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
          SizedBox(height: context.spacing),
          Expanded(child: _buildVideoGrid(context, deviceType)),
        ],
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context, DeviceType deviceType) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            strokeWidth: deviceType == DeviceType.mobile ? 3 : 4,
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
            ),
          ),
          SizedBox(height: context.spacing),
          Text(
            "Loading trending videos...",
            style: AppTextStyles.bodyMedium.copyWith(
              fontSize:
                  (AppTextStyles.bodyMedium.fontSize ?? 14) * context.fontScale,
            ),
          ),
        ],
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
            SizedBox(height: context.spacing),
            Text(
              "No trending videos available",
              style: AppTextStyles.headlineSmall.copyWith(
                fontSize:
                    (AppTextStyles.headlineSmall.fontSize ?? 24) *
                    context.fontScale,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            SizedBox(height: context.spacing / 2),
            Text(
              "Check back later for the latest trending content",
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
              child: const Text("Refresh"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendingHeader(BuildContext context, DeviceType deviceType) {
    return ResponsiveContainer(
      padding: EdgeInsets.symmetric(horizontal: context.spacing),
      child: Row(
        children: [
          const Icon(
            Icons.local_fire_department,
            color: Colors.orange,
            size: 24,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "🔥 Hot Right Now",
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
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              "${controller.trendingVideos.length} videos",
              style: AppTextStyles.labelSmall.copyWith(
                fontSize:
                    (AppTextStyles.labelSmall.fontSize ?? 11) *
                    context.fontScale,
                color: Colors.orange,
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
      accentColor: Colors.orange,
      showListView: deviceType == DeviceType.mobile,
      maxColumns: deviceType == DeviceType.mobile
          ? 2
          : deviceType == DeviceType.tablet
          ? 3
          : 4,
    );
  }
}





