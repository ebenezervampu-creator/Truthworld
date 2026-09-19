import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/features/admin/presentation/views/widgets/admin_decision_dialog.dart';
import 'package:truthworld/features/admin/presentation/views/widgets/admin_queue_helpers.dart';
import 'package:truthworld/theme/app_theme.dart';


/// Reports review queue tab
class ReportsQueueTab extends StatelessWidget {
  final AdminController controller;

  const ReportsQueueTab({
    required this.controller,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width <= 800;
    return Obx(() {
      final currentFilter = controller.reportFilterTab.value;
      final allReports = controller.reports;

      final filteredList = allReports.where((r) {
        if (currentFilter == 'pending') {
          return controller.isReportPending(r);
        } else if (currentFilter == 'resolved') {
          return controller.isReportResolved(r);
        }
        return true; // 'all'
      }).toList();

      final filterBar = Container(
        padding: const EdgeInsets.all(12),
        color: const Color(0xFF181818),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip(
                controller,
                'pending',
                'Pending (${allReports.where(controller.isReportPending).length})',
                controller.reportFilterTab,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                controller,
                'all',
                'All Reports (${allReports.length})',
                controller.reportFilterTab,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                controller,
                'resolved',
                'Resolved (${allReports.where(controller.isReportResolved).length})',
                controller.reportFilterTab,
              ),
            ],
          ),
        ),
      );

      Widget listWidget;
      if (filteredList.isEmpty) {
        listWidget = Column(
          children: [
            filterBar,
            const Expanded(
              child: Center(
                child: Text(
                  'No video reports found in this view.',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        );
      } else {
        listWidget = Container(
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
          ),
          child: Column(
            children: [
              filterBar,
              Expanded(
                child: ListView.separated(
                  itemCount: filteredList.length,
                  separatorBuilder: (context, index) =>
                      Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
                  itemBuilder: (context, index) {
                    final report = filteredList[index];
            final isSelected =
                controller.selectedReport.value?['id'] == report['id'];

            final reasonMap = report['reason'] ??
                report['reportReason'] ??
                report['category'] ??
                report['issue'];
            final reason = reasonMap is Map
                ? (reasonMap['label'] ??
                    reasonMap['name'] ??
                    reasonMap['title'] ??
                    'User Reported Content')
                : (reasonMap?.toString().isNotEmpty == true
                    ? reasonMap.toString()
                    : 'User Reported Content');
            final status = report['status'] ?? 'pending';
            final reporter = report['userEmail'] ??
                report['reporterEmail'] ??
                report['reporterId'] ??
                report['userId'] ??
                'Anonymous User';

            return Material(
              color: isSelected ? const Color(0xFF212121) : Colors.transparent,
              child: InkWell(
                onTap: () {
                  controller.selectedReport.value = report;
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: Color(0xFF212121),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.report_gmailerrorred_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              reason,
                              style: const TextStyle(
                                fontFamily: TWTypography.brandFamily,
                                color: AppColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Reporter: $reporter',
                              style: const TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                color: AppColors.textTertiary,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            _buildStatusBadge(status),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ],
  ),
);
      }

      final inspectorWidget = Obx(() {
        final selected = controller.selectedReport.value;
        if (selected == null) {
          return const Center(
            child: Text(
              'Select a report to inspect details',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.textSecondary,
              ),
            ),
          );
        }

        final videoId = selected['videoId'] as String?;
        final video = controller.videos.firstWhereOrNull(
          (v) => v['id'] == videoId,
        );
        final status = selected['status'] ?? 'pending';

        final reasonMap = selected['reason'] ??
            selected['reportReason'] ??
            selected['category'] ??
            selected['issue'];
        final reason = reasonMap is Map
            ? (reasonMap['label'] ??
                reasonMap['name'] ??
                reasonMap['title'] ??
                'User Reported Content')
            : (reasonMap?.toString().isNotEmpty == true
                ? reasonMap.toString()
                : 'User Reported Content');
        final comment = selected['comment'] ??
            selected['reportComment'] ??
            selected['details'] ??
            selected['description'] ??
            'No detailed description provided.';
        final reporterEmail = selected['userEmail'] ??
            selected['reporterEmail'] ??
            selected['reporterId'] ??
            selected['userId'] ??
            'Anonymous User';
        final createdAtStr = _formatTimestamp(selected['createdAt'] ?? selected['reportedAt'] ?? selected['timestamp']);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isMobile)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextButton.icon(
                    onPressed: () => controller.selectedReport.value = null,
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 18,
                    ),
                    label: const Text(
                      'Back to Reports',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              // Status Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (status == 'pending' || status == 'PENDING')
                      ? AppColors.warning.withValues(alpha: 0.1)
                      : (status == 'resolved_rejected'
                            ? AppColors.error.withValues(alpha: 0.1)
                            : AppColors.success.withValues(alpha: 0.1)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (status == 'pending' || status == 'PENDING')
                        ? AppColors.warning.withValues(alpha: 0.3)
                        : (status == 'resolved_rejected'
                              ? AppColors.error.withValues(alpha: 0.3)
                              : AppColors.success.withValues(alpha: 0.3)),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          (status == 'pending' || status == 'PENDING')
                              ? Icons.hourglass_empty_rounded
                              : (status == 'resolved_rejected'
                                    ? Icons.cancel_outlined
                                    : Icons.check_circle_outline_rounded),
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            (status == 'pending' || status == 'PENDING')
                                ? 'UNDER MANUAL REVIEW'
                                : (status == 'resolved_rejected'
                                      ? 'REPORT RESOLVED: VIDEO REJECTED'
                                      : 'REPORT RESOLVED: DISMISSED'),
                            style: TextStyle(
                              fontFamily: TWTypography.brandFamily,
                              color:
                                  (status == 'pending' || status == 'PENDING')
                                  ? AppColors.warning
                                  : (status == 'resolved_rejected'
                                        ? AppColors.error
                                        : AppColors.success),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 1.1,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (selected['resolutionComment'] != null &&
                        selected['resolutionComment']
                            .toString()
                            .isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Resolution Note: ${selected['resolutionComment']}',
                        style: const TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          color: AppColors.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Video Section
              const Text(
                'Reported Video Details',
                style: TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              if (video != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF181818),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (video['thumbnailUrl'] != null &&
                          video['thumbnailUrl'].toString().isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: video['thumbnailUrl'].toString(),
                            width: 120,
                            height: 68,
                            fit: BoxFit.cover,
                            memCacheWidth: 240,
                            memCacheHeight: 136,
                            placeholder: (context, url) => Container(
                              width: 120,
                              height: 68,
                              color: const Color(0xFF212121),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              width: 120,
                              height: 68,
                              color: const Color(0xFF212121),
                              child: const Icon(
                                Icons.broken_image,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        )
                      else
                        Container(
                          width: 120,
                          height: 68,
                          decoration: BoxDecoration(
                            color: const Color(0xFF212121),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.movie_creation_outlined,
                            color: Colors.white,
                          ),
                        ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              video['title'] ?? 'Untitled Video',
                              style: const TextStyle(
                                fontFamily: TWTypography.brandFamily,
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Channel: ${video['channelName'] ?? 'Unknown'}',
                              style: const TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                color: AppColors.textTertiary,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Status: ${video['moderation']?['status'] ?? 'unknown'}',
                              style: const TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                color: AppColors.textTertiary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF181818),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Text(
                    'Video ID: $videoId (Video details not cached or video deleted)',
                    style: const TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Report Info Section
              const Text(
                'Report Submission Info',
                style: TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _buildMetadataTable([
                MetadataRow('Report ID', selected['id']),
                MetadataRow('Reporter', reporterEmail),
                MetadataRow('Reason', reason),
                MetadataRow('Submitted At', createdAtStr),
              ]),
              const SizedBox(height: 24),

              // Reporter Comment block
              const Text(
                'Reporter Comment',
                style: TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF181818),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Text(
                  comment,
                  style: const TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Action buttons (Only if pending)
              if (status == 'pending' || status == 'PENDING')
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ElevatedButton.icon(
                      onPressed: controller.isActionSubmitting.value
                          ? null
                          : () => _showDecisionDialog(
                              context,
                              controller,
                              selected['id'],
                              'dismiss',
                              false,
                              isReport: true,
                            ),
                      icon: const Icon(
                        Icons.check_circle_outline,
                        size: 18,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Dismiss Report (Keep Video)',
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: controller.isActionSubmitting.value
                          ? null
                          : () => _showDecisionDialog(
                              context,
                              controller,
                              selected['id'],
                              'reject',
                              false,
                              isReport: true,
                            ),
                      icon: const Icon(
                        Icons.block_flipped,
                        size: 18,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Reject Video & Resolve',
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.error),
                        foregroundColor: AppColors.error,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      });

      if (isMobile) {
        return controller.selectedReport.value != null
            ? inspectorWidget
            : listWidget;
      }

      return Row(
        children: [
          Expanded(flex: 2, child: listWidget),
          Expanded(flex: 3, child: inspectorWidget),
        ],
      );
    });
  }

  void _showDecisionDialog(
    BuildContext context,
    AdminController controller,
    String id,
    String action,
    bool isVideo, {
    bool isTopic = false,
    bool isChannel = false,
    bool isReport = false,
  }) {
    showAdminDecisionDialog(
      context,
      controller,
      id,
      action,
      isVideo,
      isTopic: isTopic,
      isChannel: isChannel,
      isReport: isReport,
    );
  }

  Widget _buildStatusBadge(String status) => AdminStatusBadge(status: status);

  Widget _buildMetadataTable(List<MetadataRow> rows) => AdminMetadataTable(rows: rows);

  Widget _buildFilterChip(
    AdminController controller,
    String value,
    String label,
    RxString targetProperty,
  ) => AdminFilterChip(
    controller: controller,
    value: value,
    label: label,
    targetProperty: targetProperty,
  );

  String _formatTimestamp(dynamic val) => formatAdminTimestamp(val);
}
