import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/features/admin/presentation/views/widgets/admin_queue_helpers.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Overview dashboard tab displaying key system metrics and queues
class OverviewTab extends StatelessWidget {
  final AdminController controller;

  const OverviewTab({
    required this.controller,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Stats Row
          LayoutBuilder(
            builder: (context, constraints) {
              final textScale = MediaQuery.textScalerOf(context).scale(1.0);
              final width = constraints.maxWidth;
              final int cols;
              final double baseRatio;

              if (width >= 1200) {
                cols = 4;
                baseRatio = 1.45;
              } else if (width >= 800) {
                cols = 3;
                baseRatio = 1.45;
              } else if (width >= 500) {
                cols = 2;
                baseRatio = 1.5;
              } else {
                cols = 1;
                baseRatio = 2.4;
              }

              final childAspectRatio = (baseRatio / textScale.clamp(1.0, 1.5)).clamp(0.9, 2.6);

              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: childAspectRatio,
                children: [
                  _buildStatCard(
                    title: 'Pending Video Reviews',
                    value: controller.pendingVideos,
                    subtitle: 'Awaiting manual decision',
                    icon: Icons.video_collection_outlined,
                  ),
                  _buildStatCard(
                    title: 'Pending Topic Reviews',
                    value: controller.pendingTopics,
                    subtitle: 'Awaiting topic verification',
                    icon: Icons.tag_rounded,
                  ),
                  _buildStatCard(
                    title: 'Pending Image Reviews',
                    value: controller.pendingImages,
                    subtitle: 'Flagged by SafeSearch',
                    icon: Icons.photo_library_outlined,
                  ),
                  _buildStatCard(
                    title: 'Pending Channel Reviews',
                    value: controller.pendingChannels,
                    subtitle: 'AI verification warnings',
                    icon: Icons.account_circle_outlined,
                  ),
                  _buildStatCard(
                    title: 'Pending Video Reports',
                    value: controller.pendingReports,
                    subtitle: 'User submitted reports',
                    icon: Icons.report_problem_outlined,
                  ),
                  _buildStatCard(
                    title: 'Total Quarantined Records',
                    value: RxInt(controller.auditLogs.length),
                    subtitle: 'Audit registry entries',
                    icon: Icons.history_toggle_off_rounded,
                  ),
                  _buildStatCard(
                    title: 'Verification System Status',
                    value: RxString('Healthy'),
                    subtitle: 'AI pipelines active',
                    icon: Icons.health_and_safety_outlined,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 32),

          // Recent Activity Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF181818),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recent Moderation Feed (Real-time)',
                  style: TextStyle(
                    fontFamily: TWTypography.brandFamily,
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Obx(() {
                  final list = [
                    ...controller.videos.map((v) => {'type': 'video', ...v}),
                    ...controller.topics.map((t) => {'type': 'topic', ...t}),
                    ...controller.images.map(
                      (img) => {'type': 'image', ...img},
                    ),
                    ...controller.channels.map(
                      (ch) => {'type': 'channel', ...ch},
                    ),
                    ...controller.reports.map((r) => {'type': 'report', ...r}),
                  ];
                  list.sort((a, b) {
                    final timeA =
                        a['createdAt'] ?? a['flaggedAt'] ?? a['updatedAt'];
                    final timeB =
                        b['createdAt'] ?? b['flaggedAt'] ?? b['updatedAt'];
                    if (timeA == null) return 1;
                    if (timeB == null) return -1;
                    final dtA = timeA is Timestamp
                        ? timeA.toDate()
                        : (timeA is num
                            ? DateTime.fromMillisecondsSinceEpoch(timeA.toInt())
                            : (DateTime.tryParse(timeA.toString()) ??
                                DateTime.fromMillisecondsSinceEpoch(0)));
                    final dtB = timeB is Timestamp
                        ? timeB.toDate()
                        : (timeB is num
                            ? DateTime.fromMillisecondsSinceEpoch(timeB.toInt())
                            : (DateTime.tryParse(timeB.toString()) ??
                                DateTime.fromMillisecondsSinceEpoch(0)));
                    return dtB.compareTo(dtA);
                  });

                  if (list.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          'No recent activity records available.',
                          style: TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: list.take(6).length,
                    separatorBuilder: (context, index) =>
                        Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
                    itemBuilder: (context, index) {
                      final item = list[index];
                      final type = item['type'] as String;
                      final isVideo = type == 'video';
                      final isTopic = type == 'topic';
                      final isChannel = type == 'channel';
                      final isReport = type == 'report';

                      var titleText = 'Unknown Item';
                      if (isVideo) {
                        titleText = item['title'] ?? 'Untitled Video';
                      } else if (isTopic) {
                        titleText = '#${item['title'] ?? item['name'] ?? 'Untitled Topic'}';
                      } else if (isChannel) {
                        titleText =
                            item['channelName'] ??
                            item['name'] ??
                            'Unnamed Channel';
                      } else if (isReport) {
                        final reasonMap = item['reason'];
                        final reason = reasonMap is Map
                            ? (reasonMap['label'] ?? 'General')
                            : (reasonMap?.toString() ?? 'General');
                        titleText = 'Report: $reason';
                      } else {
                        titleText = item['fileName'] ?? 'Flagged Image';
                      }

                      final timestamp =
                          item['createdAt'] ??
                          item['flaggedAt'] ??
                          item['updatedAt'];

                      var status = 'pending';
                      if (isVideo) {
                        status = item['moderation']?['status'] ?? 'pending';
                      } else if (isTopic) {
                        status = item['status'] ?? 'underReview';
                      } else if (isChannel) {
                        status = item['status'] ?? 'underReview';
                      } else if (isReport) {
                        status = item['status'] ?? 'pending';
                      } else {
                        status = item['status'] ?? 'PENDING';
                      }

                      var iconData = Icons.help_outline;
                      if (isVideo) {
                        iconData = Icons.movie_outlined;
                      } else if (isTopic) {
                        iconData = Icons.tag_rounded;
                      } else if (isChannel) {
                        iconData = Icons.account_circle_outlined;
                      } else if (isReport) {
                        iconData = Icons.report_gmailerrorred_rounded;
                      } else {
                        iconData = Icons.image_outlined;
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: const Color(0xFF212121),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                iconData,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    titleText,
                                    style: const TextStyle(
                                      fontFamily: TWTypography.brandFamily,
                                      color: AppColors.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatTimestamp(timestamp),
                                    style: const TextStyle(
                                      fontFamily: TWTypography.uiFamily,
                                      color: AppColors.textTertiary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            _buildStatusBadge(status),
                          ],
                        ),
                      );
                    },
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required Rx value,
    required String subtitle,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: TWTypography.brandFamily,
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Icon(icon, color: Colors.white, size: 20),
            ],
          ),
          const SizedBox(height: 6),
          Obx(() {
            final displayValue = value.value.toString();
            return Text(
              displayValue,
              style: const TextStyle(
                fontFamily: TWTypography.brandFamily,
                color: AppColors.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            );
          }),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }


  String _formatTimestamp(dynamic val) => formatAdminTimestamp(val);
  Widget _buildStatusBadge(String status) => AdminStatusBadge(status: status);
}
