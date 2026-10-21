import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:truthworld/core/widgets/studio_loading_indicator.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/chapters_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/chapters/chapters_widgets.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Screen for managing and editing video milestone chapters in Creator Studio.
class ChaptersPage extends StatelessWidget {
  const ChaptersPage({
    required this.channelId,
    required this.isDarkMode,
    super.key,
  });

  final String channelId;
  final bool isDarkMode;

  ChaptersController get controller {
    final ctrl = Get.isRegistered<ChaptersController>()
        ? Get.find<ChaptersController>()
        : Get.put(ChaptersController());
    if (channelId.isNotEmpty && ctrl.channelId.value != channelId) {
      ctrl.setChannelContext(channelId);
    }
    return ctrl;
  }

  bool _isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;
  bool _isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 600 && width < 1024;
  }
  bool _isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1024;

  @override
  Widget build(BuildContext context) {
    const bgColor = AppColors.bgPage;
    final surfaceColor =
        isDarkMode ? AppColors.bgSurface : Colors.white;
    final textColor = isDarkMode ? AppColors.textPrimary : Colors.black87;
    final textSecondaryColor =
        isDarkMode ? AppColors.textSecondary : Colors.black54;
    const borderColor = AppColors.bgDivider;

    return Scaffold(
      backgroundColor: bgColor,
      body: Obx(() {
        if (controller.isLoading && controller.videos.isEmpty) {
          return const StudioLoadingIndicator(
            message: 'Loading chapters workspace...',
          );
        }

        if (controller.isError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 64,
                  color: AppColors.error,
                ),
                const SizedBox(height: 16),
                Text(
                  controller.errorMessage.isNotEmpty
                      ? controller.errorMessage
                      : 'An error occurred loading chapters',
                  style: TextStyle(
                    fontSize: 18,
                    color: textColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: controller.onInit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (controller.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.bookmarks_outlined,
                  size: 80,
                  color: textSecondaryColor.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 20),
                Text(
                  'No Videos Found',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Upload videos to your channel to manage chapters.',
                  style: TextStyle(
                    fontSize: 15,
                    color: textSecondaryColor,
                  ),
                ),
              ],
            ),
          );
        }

        final isDesktopOrTablet = _isDesktop(context) || _isTablet(context);
        return isDesktopOrTablet
            ? _buildDesktopLayout(
                context,
                surfaceColor: surfaceColor,
                textColor: textColor,
                textSecondaryColor: textSecondaryColor,
                borderColor: borderColor,
              )
            : _buildMobileLayout(
                context,
                surfaceColor: surfaceColor,
                textColor: textColor,
                textSecondaryColor: textSecondaryColor,
                borderColor: borderColor,
              );
      }),
    );
  }

  Widget _buildDesktopLayout(
    BuildContext context, {
    required Color surfaceColor,
    required Color textColor,
    required Color textSecondaryColor,
    required Color borderColor,
  }) {
    final isDesktop = _isDesktop(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Video List
        Container(
          width: isDesktop ? 380 : 300,
          decoration: BoxDecoration(
            color: surfaceColor,
            border: Border(right: BorderSide(color: borderColor)),
          ),
          child: ChaptersVideoListPane(
            controller: controller,
            surfaceColor: surfaceColor,
            textColor: textColor,
            textSecondaryColor: textSecondaryColor,
            borderColor: borderColor,
            isDarkMode: isDarkMode,
            isMobile: false,
          ),
        ),

        // Right Column: Workspace
        Expanded(
          child: ColoredBox(
            color: isDarkMode ? AppColors.bgPage : Colors.grey.shade100,
            child: ChaptersWorkspacePane(
              controller: controller,
              surfaceColor: surfaceColor,
              textColor: textColor,
              textSecondaryColor: textSecondaryColor,
              borderColor: borderColor,
              isDarkMode: isDarkMode,
              isMobile: false,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(
    BuildContext context, {
    required Color surfaceColor,
    required Color textColor,
    required Color textSecondaryColor,
    required Color borderColor,
  }) {
    return Obx(() {
      final selected = controller.selectedVideo.value;
      if (selected == null) {
        return ChaptersVideoListPane(
          controller: controller,
          surfaceColor: surfaceColor,
          textColor: textColor,
          textSecondaryColor: textSecondaryColor,
          borderColor: borderColor,
          isDarkMode: isDarkMode,
          isMobile: true,
        );
      }

      return Column(
        children: [
          // Back Button Header
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            color: surfaceColor,
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.arrow_back,
                    color: textColor,
                  ),
                  onPressed: () => controller.selectVideo(null),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    selected.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: borderColor),
          Expanded(
            child: ChaptersWorkspacePane(
              controller: controller,
              surfaceColor: surfaceColor,
              textColor: textColor,
              textSecondaryColor: textSecondaryColor,
              borderColor: borderColor,
              isDarkMode: isDarkMode,
              isMobile: true,
            ),
          ),
        ],
      );
    });
  }
}
