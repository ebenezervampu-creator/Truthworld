import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/features/video/data/models/video_report.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/reports_controller.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ReportsPage extends StatelessWidget {
  final String channelId;
  const ReportsPage({super.key, required this.channelId});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ReportsController(channelId: channelId));
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 800;

        return Obx(() {
          if (controller.isLoading.value && controller.reports.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (controller.reports.isEmpty) {
            return _buildEmptyState(
              isDarkMode,
              controller,
              'No reports found',
              'Your content is clean! No reports yet.',
            );
          }

          if (isDesktop) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sidebar: List of reported videos
                SizedBox(
                  width: 350,
                  child: _buildVideoList(controller, isDarkMode),
                ),
                const VerticalDivider(width: 1, thickness: 1),
                // Detail View: Reports for selected video
                Expanded(child: _buildReportDetails(controller, isDarkMode)),
              ],
            );
          } else {
            // Mobile layout
            return controller.selectedVideoId.value.isEmpty
                ? _buildVideoList(controller, isDarkMode)
                : _buildReportDetails(controller, isDarkMode, showBack: true);
          }
        });
      },
    );
  }

  Widget _buildEmptyState(
    bool isDarkMode,
    ReportsController controller,
    String title,
    String subtitle,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.flag_outlined,
            size: 80,
            color: isDarkMode ? Colors.white24 : Colors.grey[300],
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: GoogleFonts.roboto(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.roboto(
              fontSize: 16,
              color: isDarkMode ? Colors.white60 : AppColors.textSecondary,
            ),
          ),
          if (foundation.kDebugMode) ...[
            const SizedBox(height: 16),
            Text(
              'Channel ID: ${controller.channelId}',
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVideoList(ReportsController controller, bool isDarkMode) {
    final videoIds = controller.groupedReports.keys.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'Reported Content',
            style: GoogleFonts.roboto(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: videoIds.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final videoId = videoIds[index];
              final video = controller.reportedVideos[videoId];
              final activityCount =
                  controller.groupedReports[videoId]?.length ?? 0;
              final isSelected = controller.selectedVideoId.value == videoId;

              return InkWell(
                onTap: () => controller.selectVideo(videoId),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDarkMode
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.blue.withValues(alpha: 0.05))
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppColors.brand : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Video Thumbnail
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: video != null && video.thumbnailUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: video.thumbnailUrl,
                                width: 100,
                                height: 56,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                width: 100,
                                height: 56,
                                color: Colors.grey[800],
                                child: const Icon(
                                  Icons.video_library,
                                  color: Colors.white24,
                                ),
                              ),
                      ),
                      const SizedBox(width: 12),
                      // Video Title & Report Count
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              video?.title ??
                                  'Unknown Video (${videoId.length > 8 ? videoId.substring(0, 8) : videoId})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.roboto(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isDarkMode
                                    ? Colors.white
                                    : AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '$activityCount ${activityCount == 1 ? 'report' : 'reports'}',
                                style: GoogleFonts.roboto(
                                  color: AppColors.error,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReportDetails(
    ReportsController controller,
    bool isDarkMode, {
    bool showBack = false,
  }) {
    if (foundation.kDebugMode) {
      debugPrint(
        'ReportsPage: Building details for video: ${controller.selectedVideoId.value}',
      );
      debugPrint(
        'ReportsPage: Reports available in groupedReports: ${controller.groupedReports[controller.selectedVideoId.value]?.length ?? 0}',
      );
    }
    if (controller.selectedVideoId.value.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.video_library_outlined,
              size: 64,
              color: isDarkMode ? Colors.white10 : Colors.grey[200],
            ),
            const SizedBox(height: 16),
            Text(
              'Select a video to see reports',
              style: GoogleFonts.roboto(
                color: isDarkMode ? Colors.white54 : Colors.grey[600],
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    final videoId = controller.selectedVideoId.value;
    final video = controller.reportedVideos[videoId];
    final reports = controller.groupedReports[videoId] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            children: [
              if (showBack)
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new),
                  onPressed: () => controller.selectVideo(''),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video?.title ?? 'Loading video details...',
                      style: GoogleFonts.roboto(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode
                            ? Colors.white
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'All reports submitted for this content',
                      style: GoogleFonts.roboto(
                        fontSize: 14,
                        color: isDarkMode
                            ? Colors.white60
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // List of reports
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index];
              return _buildReportCard(report, isDarkMode);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReportCard(VideoReport report, bool isDarkMode) {
    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');
    final String dateString = dateFormat.format(report.createdAt.toDate());

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.bgSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.grey[200]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  report.reasonLabel.toUpperCase(),
                  style: GoogleFonts.roboto(
                    color: AppColors.error,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Text(
                dateString,
                style: GoogleFonts.roboto(
                  color: isDarkMode ? Colors.white38 : Colors.grey[500],
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (report.comment.isNotEmpty) ...[
            Text(
              'User Comment:',
              style: GoogleFonts.roboto(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white38 : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              report.comment,
              style: GoogleFonts.roboto(
                fontSize: 15,
                height: 1.5,
                color: isDarkMode ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.account_balance_rounded,
                    size: 16,
                    color: isDarkMode ? Colors.white38 : Colors.grey[400],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Channel: ${report.channelId}',
                    style: GoogleFonts.roboto(
                      fontSize: 13,
                      color: isDarkMode
                          ? Colors.white60
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              if (report.status == 'pending')
                TextButton.icon(
                  onPressed: () {
                    final reportsController = Get.find<ReportsController>();
                    reportsController.resolveReport(report.id);
                  },
                  icon: const Icon(
                    Icons.check_circle_outline,
                    size: 16,
                    color: AppColors.brand,
                  ),
                  label: Text(
                    'Resolve',
                    style: GoogleFonts.roboto(
                      color: AppColors.brand,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check, size: 12, color: Colors.green),
                      const SizedBox(width: 4),
                      Text(
                        'Resolved',
                        style: GoogleFonts.roboto(
                          color: Colors.green,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
