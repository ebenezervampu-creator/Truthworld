import 'package:chewie/chewie.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:video_player/video_player.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(AdminController());
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Obx(() {
      if (controller.isAuthChecking.value) {
        return const Scaffold(
          backgroundColor: AppColors.bgPage,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.brand),
                ),
                SizedBox(height: 16),
                Text(
                  'Verifying admin console credentials...',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                ),
              ],
            ),
          ),
        );
      }

      if (!controller.isAdmin.value) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Get.offAllNamed('/admin/login');
        });
        return const Scaffold(
          backgroundColor: AppColors.bgPage,
          body: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.brand),
            ),
          ),
        );
      }

      return Scaffold(
        backgroundColor: AppColors.bgPage,
        body: Row(
          children: [
            // Sidebar (desktop only, otherwise we can show drawer)
            if (isDesktop) _buildSidebar(context, controller),

            // Main Workspace
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(context, controller, isDesktop),
                  Expanded(
                    child: Obx(() {
                      switch (controller.currentTab.value) {
                        case 'videos':
                          return _buildVideoQueueTab(context, controller);
                        case 'images':
                          return _buildImageQueueTab(context, controller);
                        case 'channels':
                          return _buildChannelQueueTab(context, controller);
                        case 'reports':
                          return _buildReportsQueueTab(context, controller);
                        case 'logs':
                          return _buildAuditLogsTab(context, controller);
                        default:
                          return _buildOverviewTab(context, controller);
                      }
                    }),
                  ),
                ],
              ),
            ),
          ],
        ),
        drawer: isDesktop ? null : Drawer(child: _buildSidebar(context, controller)),
      );
    });
  }

  // Sidebar widget
  Widget _buildSidebar(BuildContext context, AdminController controller) {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: AppColors.bgSurface,
        border: Border(
          right: BorderSide(color: AppColors.bgDivider),
        ),
      ),
      child: Column(
        children: [
          // Sidebar Header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFFE0B0FF), AppColors.brand],
                  ).createShader(bounds),
                  child: Text(
                    'TruthWorld',
                    style: context.typography.logo.copyWith(
                      fontSize: 22,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.brand.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Console',
                    style: TextStyle(
                      color: AppColors.brand,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.bgDivider, height: 1),
          const SizedBox(height: 16),

          // Navigation list
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _buildNavItem(
                  icon: Icons.dashboard_outlined,
                  activeIcon: Icons.dashboard_rounded,
                  label: 'Dashboard',
                  tabId: 'dashboard',
                  controller: controller,
                ),
                Obx(() => _buildNavItem(
                      icon: Icons.video_library_outlined,
                      activeIcon: Icons.video_library_rounded,
                      label: 'Video Queue',
                      tabId: 'videos',
                      badgeCount: controller.pendingVideos.value,
                      controller: controller,
                    )),
                Obx(() => _buildNavItem(
                      icon: Icons.image_outlined,
                      activeIcon: Icons.image_rounded,
                      label: 'Image Queue',
                      tabId: 'images',
                      badgeCount: controller.pendingImages.value,
                      controller: controller,
                    )),
                Obx(() => _buildNavItem(
                      icon: Icons.account_circle_outlined,
                      activeIcon: Icons.account_circle_rounded,
                      label: 'Channel Queue',
                      tabId: 'channels',
                      badgeCount: controller.pendingChannels.value,
                      controller: controller,
                    )),
                Obx(() => _buildNavItem(
                      icon: Icons.report_gmailerrorred_rounded,
                      activeIcon: Icons.report_gmailerrorred_rounded,
                      label: 'Video Reports',
                      tabId: 'reports',
                      badgeCount: controller.pendingReports.value,
                      controller: controller,
                    )),
                _buildNavItem(
                  icon: Icons.history_edu_outlined,
                  activeIcon: Icons.history_edu_rounded,
                  label: 'Audit History Logs',
                  tabId: 'logs',
                  controller: controller,
                ),
              ],
            ),
          ),

          // User Profile Info
          const Divider(color: AppColors.bgDivider, height: 1),
          Obx(() {
            final email = controller.isAdmin.value
                ? (FirebaseAuth.instance.currentUser?.email ?? 'Admin User')
                : 'Not Logged In';
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.brand.withValues(alpha: 0.2),
                    child: Text(
                      email[0].toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.brand,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          email,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Moderation Administrator',
                          style: TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required String tabId,
    required AdminController controller, int badgeCount = 0,
  }) {
    return Obx(() {
      final isSelected = controller.currentTab.value == tabId;
      return Container(
        margin: const EdgeInsets.only(bottom: 4),
        child: Material(
          color: isSelected ? AppColors.brand.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              controller.currentTab.value = tabId;
              controller.selectedVideo.value = null;
              controller.selectedImage.value = null;
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    isSelected ? activeIcon : icon,
                    color: isSelected ? AppColors.brand : AppColors.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                  if (badgeCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.brand,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$badgeCount',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  // Header Widget
  Widget _buildHeader(BuildContext context, AdminController controller, bool isDesktop) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: AppColors.bgSurface,
        border: Border(
          bottom: BorderSide(color: AppColors.bgDivider),
        ),
      ),
      child: Row(
        children: [
          if (!isDesktop)
            IconButton(
              icon: const Icon(Icons.menu_rounded, color: AppColors.textPrimary),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          Obx(() {
            var title = 'Dashboard Overview';
            if (controller.currentTab.value == 'videos') title = 'Video Verification Queue';
            if (controller.currentTab.value == 'images') title = 'Image Moderation Grid';
            if (controller.currentTab.value == 'channels') title = 'Channel Verification Queue';
            if (controller.currentTab.value == 'reports') title = 'Video Reports Review';
            if (controller.currentTab.value == 'logs') title = 'Audit History Logs';
            return Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            );
          }),
          const Spacer(),
          TextButton.icon(
            onPressed: () => controller.signOutAdmin(),
            icon: const Icon(Icons.logout_rounded, size: 16, color: AppColors.error),
            label: const Text(
              'Sign Out',
              style: TextStyle(
                color: AppColors.error,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Formatting helpers
  String _formatTimestamp(dynamic val) {
    if (val == null) return 'N/A';
    DateTime? dt;
    if (val is Timestamp) {
      dt = val.toDate();
    } else if (val is String) {
      dt = DateTime.tryParse(val);
    }
    if (dt == null) return 'N/A';
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
  }

  // TAB 1: OVERVIEW TAB
  Widget _buildOverviewTab(BuildContext context, AdminController controller) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Stats Row
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth > 1200 ? 6 : (constraints.maxWidth > 800 ? 3 : 2);
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: cols == 6 ? 1.2 : 1.5,
                children: [
                  _buildStatCard(
                    title: 'Pending Video Reviews',
                    value: controller.pendingVideos,
                    subtitle: 'Awaiting manual decision',
                    icon: Icons.video_collection_outlined,
                    iconColor: AppColors.warning,
                  ),
                  _buildStatCard(
                    title: 'Pending Image Reviews',
                    value: controller.pendingImages,
                    subtitle: 'Flagged by SafeSearch',
                    icon: Icons.photo_library_outlined,
                    iconColor: AppColors.brand,
                  ),
                  _buildStatCard(
                    title: 'Pending Channel Reviews',
                    value: controller.pendingChannels,
                    subtitle: 'AI verification warnings',
                    icon: Icons.account_circle_outlined,
                    iconColor: AppColors.warning,
                  ),
                  _buildStatCard(
                    title: 'Pending Video Reports',
                    value: controller.pendingReports,
                    subtitle: 'User submitted reports',
                    icon: Icons.report_problem_outlined,
                    iconColor: Colors.deepOrangeAccent,
                  ),
                  _buildStatCard(
                    title: 'Total Quarantined Records',
                    value: RxInt(controller.auditLogs.length),
                    subtitle: 'Audit registry entries',
                    icon: Icons.history_toggle_off_rounded,
                    iconColor: AppColors.success,
                  ),
                  _buildStatCard(
                    title: 'Verification System Status',
                    value: RxString('Healthy'),
                    subtitle: 'AI pipelines active',
                    icon: Icons.health_and_safety_outlined,
                    iconColor: AppColors.success,
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
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.bgDivider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recent Moderation Feed (Real-time)',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Obx(() {
                  final list = [
                    ...controller.videos.map((v) => {'type': 'video', ...v}),
                    ...controller.images.map((img) => {'type': 'image', ...img}),
                    ...controller.channels.map((ch) => {'type': 'channel', ...ch}),
                    ...controller.reports.map((r) => {'type': 'report', ...r}),
                  ];
                  list.sort((a, b) {
                    final timeA = a['createdAt'] ?? a['flaggedAt'] ?? a['updatedAt'];
                    final timeB = b['createdAt'] ?? b['flaggedAt'] ?? b['updatedAt'];
                    if (timeA == null) return 1;
                    if (timeB == null) return -1;
                    final dtA = timeA is Timestamp ? timeA.toDate() : DateTime.parse(timeA.toString());
                    final dtB = timeB is Timestamp ? timeB.toDate() : DateTime.parse(timeB.toString());
                    return dtB.compareTo(dtA);
                  });

                  if (list.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          'No recent activity records available.',
                          style: TextStyle(color: AppColors.textTertiary),
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: list.take(6).length,
                    separatorBuilder: (context, index) => const Divider(color: AppColors.bgDivider, height: 1),
                    itemBuilder: (context, index) {
                      final item = list[index];
                      final type = item['type'] as String;
                      final isVideo = type == 'video';
                      final isChannel = type == 'channel';
                      final isReport = type == 'report';

                      var titleText = 'Unknown Item';
                      if (isVideo) {
                        titleText = item['title'] ?? 'Untitled Video';
                      } else if (isChannel) {
                        titleText = item['channelName'] ?? item['name'] ?? 'Unnamed Channel';
                      } else if (isReport) {
                        final reasonMap = item['reason'];
                        final reason = reasonMap is Map ? (reasonMap['label'] ?? 'General') : (reasonMap?.toString() ?? 'General');
                        titleText = 'Report: $reason';
                      } else {
                        titleText = item['fileName'] ?? 'Flagged Image';
                      }

                      final timestamp = item['createdAt'] ?? item['flaggedAt'] ?? item['updatedAt'];
                      
                      var status = 'pending';
                      if (isVideo) {
                        status = item['moderation']?['status'] ?? 'pending';
                      } else if (isChannel) {
                        status = item['status'] ?? 'underReview';
                      } else if (isReport) {
                        status = item['status'] ?? 'pending';
                      } else {
                        status = item['status'] ?? 'PENDING';
                      }

                      var iconData = Icons.help_outline;
                      var iconColor = AppColors.textSecondary;
                      if (isVideo) {
                        iconData = Icons.movie_outlined;
                        iconColor = AppColors.brand;
                      } else if (isChannel) {
                        iconData = Icons.account_circle_outlined;
                        iconColor = AppColors.warning;
                      } else if (isReport) {
                        iconData = Icons.report_gmailerrorred_rounded;
                        iconColor = Colors.deepOrangeAccent;
                      } else {
                        iconData = Icons.image_outlined;
                        iconColor = Colors.cyan;
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: iconColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                iconData,
                                color: iconColor,
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
                                      color: AppColors.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatTimestamp(timestamp),
                                    style: const TextStyle(
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
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Icon(icon, color: iconColor, size: 20),
            ],
          ),
          Obx(() {
            final displayValue = value.value.toString();
            return Text(
              displayValue,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            );
          }),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // TAB 2: VIDEOS QUEUE TAB
  Widget _buildVideoQueueTab(BuildContext context, AdminController controller) {
    return Obx(() {
      final list = controller.videos.where((v) {
        final topStatus = v['status'] as String?;
        if (topStatus == 'rejected') return true;

        final mod = v['moderation'] as Map<String, dynamic>?;
        if (mod == null) return false;
        final status = mod['status'] as String?;
        final violations = mod['violationCategories'] as List<dynamic>?;
        return status == 'processing' || status == 'error' || 
               (status == 'approved' && violations != null && violations.contains('timeout_passthrough')) || 
               status == 'rejected' || status == 'pending';
      }).toList();

      if (list.isEmpty) {
        return const Center(
          child: Text(
            'No videos in the moderation queue.',
            style: TextStyle(color: AppColors.textTertiary),
          ),
        );
      }

      return Row(
        children: [
          // Left Pane: Video list
          Expanded(
            flex: 2,
            child: Container(
              decoration: const BoxDecoration(
                border: Border(right: BorderSide(color: AppColors.bgDivider)),
              ),
              child: ListView.separated(
                itemCount: list.length,
                separatorBuilder: (context, index) => const Divider(color: AppColors.bgDivider, height: 1),
                itemBuilder: (context, index) {
                  final video = list[index];
                  final isSelected = controller.selectedVideo.value?['id'] == video['id'];
                  final title = video['title'] ?? 'Untitled Video';
                  final mod = video['moderation'] as Map<String, dynamic>?;
                  final status = mod?['status'] ?? video['status'] ?? 'pending';
                  final isTimeout = mod?['violationCategories']?.contains('timeout_passthrough') == true;

                  return Material(
                    color: isSelected ? AppColors.bgSurfaceHover : Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        controller.selectedVideo.value = video;
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 80,
                              height: 50,
                              decoration: BoxDecoration(
                                color: AppColors.bgElevated,
                                borderRadius: BorderRadius.circular(6),
                                image: video['thumbnailUrl'] != null
                                    ? DecorationImage(
                                        image: NetworkImage(video['thumbnailUrl']),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: video['thumbnailUrl'] == null
                                  ? const Icon(Icons.videocam_rounded, color: AppColors.textSecondary)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'User: ${video['userId'] ?? video['ownerId'] ?? 'Unknown'}',
                                    style: const TextStyle(
                                      color: AppColors.textTertiary,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      _buildStatusBadge(status),
                                      if (isTimeout) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.error.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'TIMEOUT',
                                            style: TextStyle(
                                              color: AppColors.error,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
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
          ),

          // Right Pane: Video details inspector
          Expanded(
            flex: 3,
            child: Obx(() {
              final selected = controller.selectedVideo.value;
              if (selected == null) {
                return const Center(
                  child: Text(
                    'Select a video to inspect details',
                    style: TextStyle(color: AppColors.textTertiary),
                  ),
                );
              }

              final videoUrl = selected['videoUrl'];
              final mod = selected['moderation'] as Map<String, dynamic>?;
              final status = mod?['status'] ?? selected['status'] ?? 'pending';

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selected['title'] ?? 'Untitled Video',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Status Box
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: (status == 'approved'
                            ? AppColors.success
                            : (status == 'rejected' ? AppColors.error : AppColors.warning)).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: (status == 'approved'
                              ? AppColors.success
                              : (status == 'rejected' ? AppColors.error : AppColors.warning)).withValues(alpha: 0.25),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            status == 'approved'
                                ? Icons.check_circle_outline
                                : (status == 'rejected' ? Icons.block_flipped : Icons.sync_rounded),
                            color: status == 'approved'
                                ? AppColors.success
                                : (status == 'rejected' ? AppColors.error : AppColors.warning),
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Current Status: ${status.toUpperCase()}',
                                  style: TextStyle(
                                    color: status == 'approved'
                                        ? AppColors.success
                                        : (status == 'rejected' ? AppColors.error : AppColors.warning),
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (mod?['reason'] != null && mod!['reason'].toString().isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    mod['reason'].toString(),
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Video Player Frame
                    if (videoUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: ColoredBox(
                          color: AppColors.bgPage,
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: AdminVideoPlayer(
                              key: ValueKey(selected['id']),
                              url: videoUrl,
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        height: 200,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.bgSurface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'No video URL metadata present.',
                          style: TextStyle(color: AppColors.textTertiary),
                        ),
                      ),
                    const SizedBox(height: 24),

                    // Metadata Details Table
                    const Text(
                      'Technical Metadata',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildMetadataTable([
                      _MetadataRow('Video ID', selected['id']),
                      _MetadataRow('Description', selected['description'] ?? 'None'),
                      _MetadataRow('Pipeline Status', status),
                      _MetadataRow('Flagged Reason', mod?['reason'] ?? selected['rejectionReason'] ?? 'System automatic moderation trigger.'),
                      _MetadataRow('Confidence Score', (mod?['confidenceScore'] ?? 'N/A').toString()),
                      _MetadataRow('GCS Storage Path', selected['storage']?['videoPath'] ?? 'N/A'),
                      _MetadataRow('Uploaded At', _formatTimestamp(selected['createdAt'])),
                    ]),
                    const SizedBox(height: 32),

                    // Action buttons
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: controller.isActionSubmitting.value
                              ? null
                              : () => _showDecisionDialog(context, controller, selected['id'], 'approve', true),
                          icon: const Icon(Icons.check_circle_outline, size: 18, color: AppColors.textPrimary),
                          label: const Text('Approve Video'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        OutlinedButton.icon(
                          onPressed: controller.isActionSubmitting.value
                              ? null
                              : () => _showDecisionDialog(context, controller, selected['id'], 'reject', true),
                          icon: const Icon(Icons.block_flipped, size: 18, color: AppColors.error),
                          label: const Text('Reject Video & Quarantine'),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.error),
                            foregroundColor: AppColors.error,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      );
    });
  }

  // TAB: CHANNELS QUEUE TAB
  Widget _buildChannelQueueTab(BuildContext context, AdminController controller) {
    return Obx(() {
      final list = controller.channels;

      if (list.isEmpty) {
        return const Center(
          child: Text(
            'No channels in the database.',
            style: TextStyle(color: AppColors.textTertiary),
          ),
        );
      }

      return Row(
        children: [
          // Left Pane: Channel list
          Expanded(
            flex: 2,
            child: Container(
              decoration: const BoxDecoration(
                border: Border(right: BorderSide(color: AppColors.bgDivider)),
              ),
              child: ListView.separated(
                itemCount: list.length,
                separatorBuilder: (context, index) => const Divider(color: AppColors.bgDivider, height: 1),
                itemBuilder: (context, index) {
                  final channel = list[index];
                  final isSelected = controller.selectedChannel.value?['id'] == channel['id'];
                  final title = channel['channelName'] ?? channel['name'] ?? 'Unnamed Channel';
                  final status = channel['status'] ?? 'underReview';

                  return Material(
                    color: isSelected ? AppColors.bgSurfaceHover : Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        controller.selectedChannel.value = channel;
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: AppColors.bgElevated,
                                shape: BoxShape.circle,
                                image: channel['avatarUrl'] != null && channel['avatarUrl'].toString().isNotEmpty
                                    ? DecorationImage(
                                        image: NetworkImage(channel['avatarUrl']),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: channel['avatarUrl'] == null || channel['avatarUrl'].toString().isEmpty
                                  ? const Icon(Icons.face_rounded, color: AppColors.textSecondary)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Handle: @${channel['handle'] ?? channel['customUrl'] ?? 'none'}',
                                    style: const TextStyle(
                                      color: AppColors.textTertiary,
                                      fontSize: 11,
                                    ),
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
          ),

          // Right Pane: Channel details inspector
          Expanded(
            flex: 3,
            child: Obx(() {
              final selected = controller.selectedChannel.value;
              if (selected == null) {
                return const Center(
                  child: Text(
                    'Select a channel to inspect details',
                    style: TextStyle(color: AppColors.textTertiary),
                  ),
                );
              }

              final avatarUrl = selected['avatarUrl'];
              final bannerUrl = selected['bannerImageUrl'] ?? selected['bannerUrl'];
              final status = selected['status'] ?? 'underReview';
              final geminiResponse = selected['moderationReason'] ?? 'No automated response logged.';

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Banner Image if present
                    if (bannerUrl != null && bannerUrl.toString().isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          height: 120,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            image: DecorationImage(
                              image: NetworkImage(bannerUrl),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundImage: avatarUrl != null && avatarUrl.toString().isNotEmpty
                              ? NetworkImage(avatarUrl)
                              : null,
                          backgroundColor: AppColors.bgElevated,
                          child: avatarUrl == null || avatarUrl.toString().isEmpty
                              ? const Icon(Icons.face_rounded, size: 30)
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selected['channelName'] ?? selected['name'] ?? 'Unnamed Channel',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '@${selected['handle'] ?? selected['customUrl'] ?? 'none'}',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Status Box
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: (status == 'active'
                            ? AppColors.success
                            : (status == 'verificationRejected' ? AppColors.error : AppColors.warning)).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: (status == 'active'
                              ? AppColors.success
                              : (status == 'verificationRejected' ? AppColors.error : AppColors.warning)).withValues(alpha: 0.25),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            status == 'active'
                                ? Icons.check_circle_outline
                                : (status == 'verificationRejected' ? Icons.block_flipped : Icons.sync_rounded),
                            color: status == 'active'
                                ? AppColors.success
                                : (status == 'verificationRejected' ? AppColors.error : AppColors.warning),
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Current Status: ${status == 'active' ? 'APPROVED/ACTIVE' : (status == 'verificationRejected' ? 'REJECTED' : 'UNDER REVIEW')}',
                                  style: TextStyle(
                                    color: status == 'active'
                                        ? AppColors.success
                                        : (status == 'verificationRejected' ? AppColors.error : AppColors.warning),
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Gemini response block
                    const Text(
                      'Gemini AI Moderation Analysis',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.bgSurfaceHover,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.bgDivider),
                      ),
                      child: Text(
                        geminiResponse,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Metadata details
                    const Text(
                      'Channel Metadata',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildMetadataTable([
                      _MetadataRow('Channel ID', selected['id']),
                      _MetadataRow('Owner ID', selected['ownerId'] ?? 'N/A'),
                      _MetadataRow('Description', selected['description'] ?? 'None'),
                      _MetadataRow('Category', selected['category'] ?? 'None'),
                      _MetadataRow('Language', selected['language'] ?? 'en'),
                      _MetadataRow('Tags', (selected['tags'] as List?)?.join(', ') ?? 'None'),
                      _MetadataRow('Status', status),
                      _MetadataRow('Updated At', _formatTimestamp(selected['updatedAt'])),
                    ]),
                    const SizedBox(height: 32),

                    // Action buttons
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: controller.isActionSubmitting.value
                              ? null
                              : () => _showDecisionDialog(context, controller, selected['id'], 'approve', false, isChannel: true),
                          icon: const Icon(Icons.check_circle_outline, size: 18, color: AppColors.textPrimary),
                          label: const Text('Approve Channel'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        OutlinedButton.icon(
                          onPressed: controller.isActionSubmitting.value
                              ? null
                              : () => _showDecisionDialog(context, controller, selected['id'], 'reject', false, isChannel: true),
                          icon: const Icon(Icons.block_flipped, size: 18, color: AppColors.error),
                          label: const Text('Reject Channel'),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.error),
                            foregroundColor: AppColors.error,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      );
    });
  }

  // TAB: REPORTS QUEUE TAB
  Widget _buildReportsQueueTab(BuildContext context, AdminController controller) {
    return Obx(() {
      final list = controller.reports;

      if (list.isEmpty) {
        return const Center(
          child: Text(
            'No reports in the database.',
            style: TextStyle(color: AppColors.textTertiary),
          ),
        );
      }

      return Row(
        children: [
          // Left Pane: Report list
          Expanded(
            flex: 2,
            child: Container(
              decoration: const BoxDecoration(
                border: Border(right: BorderSide(color: AppColors.bgDivider)),
              ),
              child: ListView.separated(
                itemCount: list.length,
                separatorBuilder: (context, index) => const Divider(color: AppColors.bgDivider, height: 1),
                itemBuilder: (context, index) {
                  final report = list[index];
                  final isSelected = controller.selectedReport.value?['id'] == report['id'];
                  
                  final reasonMap = report['reason'];
                  final reason = reasonMap is Map ? (reasonMap['label'] ?? 'Unknown Reason') : (reasonMap?.toString() ?? 'Unknown Reason');
                  final status = report['status'] ?? 'pending';
                  final reporter = report['userEmail'] ?? 'anonymous';

                  return Material(
                    color: isSelected ? AppColors.bgSurfaceHover : Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        controller.selectedReport.value = report;
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: const BoxDecoration(
                                color: AppColors.bgElevated,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.report_gmailerrorred_rounded, color: Colors.deepOrangeAccent),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    reason,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Reporter: $reporter',
                                    style: const TextStyle(
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
          ),

          // Right Pane: Inspector
          Expanded(
            flex: 3,
            child: Obx(() {
              final selected = controller.selectedReport.value;
              if (selected == null) {
                return const Center(
                  child: Text(
                    'Select a report to inspect details',
                    style: TextStyle(color: AppColors.textTertiary),
                  ),
                );
              }

              final videoId = selected['videoId'] as String?;
              final video = controller.videos.firstWhereOrNull((v) => v['id'] == videoId);
              final status = selected['status'] ?? 'pending';

              final reasonMap = selected['reason'];
              final reason = reasonMap is Map ? (reasonMap['label'] ?? 'Unknown Reason') : (reasonMap?.toString() ?? 'Unknown Reason');
              final comment = selected['comment'] ?? 'No detailed description provided.';
              final reporterEmail = selected['userEmail'] ?? 'anonymous';
              final createdAtStr = _formatTimestamp(selected['createdAt']);

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                                    : (status == 'resolved_rejected' ? Icons.cancel_outlined : Icons.check_circle_outline_rounded),
                                color: (status == 'pending' || status == 'PENDING')
                                    ? AppColors.warning
                                    : (status == 'resolved_rejected' ? AppColors.error : AppColors.success),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                (status == 'pending' || status == 'PENDING')
                                    ? 'UNDER MANUAL REVIEW'
                                    : (status == 'resolved_rejected' ? 'REPORT RESOLVED: VIDEO REJECTED' : 'REPORT RESOLVED: DISMISSED'),
                                style: TextStyle(
                                  color: (status == 'pending' || status == 'PENDING')
                                      ? AppColors.warning
                                      : (status == 'resolved_rejected' ? AppColors.error : AppColors.success),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ],
                          ),
                          if (selected['resolutionComment'] != null && selected['resolutionComment'].toString().isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              'Resolution Note: ${selected['resolutionComment']}',
                              style: const TextStyle(
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
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (video != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.bgSurfaceHover,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.bgDivider),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (video['thumbnailUrl'] != null && video['thumbnailUrl'].toString().isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  video['thumbnailUrl'],
                                  width: 120,
                                  height: 68,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    width: 120,
                                    height: 68,
                                    color: AppColors.textSecondary,
                                    child: const Icon(Icons.broken_image, color: AppColors.textSecondary),
                                  ),
                                ),
                              )
                            else
                              Container(
                                width: 120,
                                height: 68,
                                decoration: BoxDecoration(
                                  color: AppColors.textSecondary,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.movie_creation_outlined, color: AppColors.textSecondary),
                              ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    video['title'] ?? 'Untitled Video',
                                    style: const TextStyle(
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
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Status: ${video['moderation']?['status'] ?? 'unknown'}',
                                    style: const TextStyle(
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
                          color: AppColors.bgSurfaceHover,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.bgDivider),
                        ),
                        child: Text(
                          'Video ID: $videoId (Video details not cached or video deleted)',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Report Info Section
                    const Text(
                      'Report Submission Info',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildMetadataTable([
                      _MetadataRow('Report ID', selected['id']),
                      _MetadataRow('Reporter', reporterEmail),
                      _MetadataRow('Reason', reason),
                      _MetadataRow('Submitted At', createdAtStr),
                    ]),
                    const SizedBox(height: 24),

                    // Reporter Comment block
                    const Text(
                      'Reporter Comment',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.bgSurfaceHover,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.bgDivider),
                      ),
                      child: Text(
                        comment,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Action buttons (Only if pending)
                    if (status == 'pending' || status == 'PENDING')
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: controller.isActionSubmitting.value
                                ? null
                                : () => _showDecisionDialog(context, controller, selected['id'], 'dismiss', false, isReport: true),
                            icon: const Icon(Icons.check_circle_outline, size: 18, color: AppColors.textPrimary),
                            label: const Text('Dismiss Report (Keep Video)'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          OutlinedButton.icon(
                            onPressed: controller.isActionSubmitting.value
                                ? null
                                : () => _showDecisionDialog(context, controller, selected['id'], 'reject', false, isReport: true),
                            icon: const Icon(Icons.block_flipped, size: 18, color: AppColors.error),
                            label: const Text('Reject Video & Resolve'),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.error),
                              foregroundColor: AppColors.error,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              );
            }),
          ),
        ],
      );
    });
  }

  // TAB 3: IMAGES QUEUE TAB
  Widget _buildImageQueueTab(BuildContext context, AdminController controller) {
    return Obx(() {
      final list = controller.images;

      if (list.isEmpty) {
        return const Center(
          child: Text(
            'No images in the moderation queue.',
            style: TextStyle(color: AppColors.textTertiary),
          ),
        );
      }

      return Row(
        children: [
          // Left Pane: Flagged images grid
          Expanded(
            flex: 2,
            child: Container(
              decoration: const BoxDecoration(
                border: Border(right: BorderSide(color: AppColors.bgDivider)),
              ),
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.9,
                ),
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final img = list[index];
                  final isSelected = controller.selectedImage.value?['id'] == img['id'];
                  final rawUrl = img['gcsUri'] ?? img['filePath'] ?? '';
                  final displayUrl = rawUrl.toString().replaceAll('gs://', 'https://storage.googleapis.com/').replaceAll('truthworld-1.firebasestorage.app/', 'truthworld-1.firebasestorage.app/');

                  return GestureDetector(
                    onTap: () {
                      controller.selectedImage.value = img;
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.bgSurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? AppColors.brand : AppColors.bgDivider,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: displayUrl.isNotEmpty
                                ? Image.network(
                                    displayUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => const Center(
                                      child: Icon(Icons.broken_image, color: AppColors.textTertiary),
                                    ),
                                  )
                                : const Icon(Icons.image, color: AppColors.textTertiary),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  img['fileName'] ?? 'Image File',
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.bgElevated,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        img['category'] ?? 'Post',
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 8,
                                        ),
                                      ),
                                    ),
                                    _buildStatusBadge(img['status'] ?? 'PENDING'),
                                  ],
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
          ),

          // Right Pane: Image details inspector
          Expanded(
            flex: 3,
            child: Obx(() {
              final selected = controller.selectedImage.value;
              if (selected == null) {
                return const Center(
                  child: Text(
                    'Select an image to inspect details',
                    style: TextStyle(color: AppColors.textTertiary),
                  ),
                );
              }

              final rawUrl = selected['gcsUri'] ?? selected['filePath'] ?? '';
              final displayUrl = rawUrl.toString().replaceAll('gs://', 'https://storage.googleapis.com/').replaceAll('truthworld-1.firebasestorage.app/', 'truthworld-1.firebasestorage.app/');
              final scores = selected['detailedScores'] as Map<String, dynamic>? ?? {};

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selected['fileName'] ?? 'Inspect Image',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Image Frame
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        color: AppColors.bgSurface,
                        constraints: const BoxConstraints(maxHeight: 280),
                        width: double.infinity,
                        child: displayUrl.isNotEmpty
                            ? Image.network(
                                displayUrl,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => const Center(
                                  child: Icon(Icons.broken_image, size: 48, color: AppColors.textTertiary),
                                ),
                              )
                            : const Icon(Icons.image, size: 48, color: AppColors.textTertiary),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Safe Search Scores
                    const Text(
                      'AI SafeSearch Violations',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildSafeSearchChip('Adult', scores['adult']),
                        _buildSafeSearchChip('Racy', scores['racy']),
                        _buildSafeSearchChip('Violence', scores['violence']),
                        _buildSafeSearchChip('Medical', scores['medical']),
                        _buildSafeSearchChip('Spoof', scores['spoof']),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Metadata Details Table
                    const Text(
                      'Verification Metadata',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildMetadataTable([
                      _MetadataRow('Document ID', selected['id']),
                      _MetadataRow('Uploader ID', selected['userId'] ?? 'Anonymous'),
                      _MetadataRow('Trigger Category', selected['category'] ?? 'image'),
                      _MetadataRow('AI Reason Log', selected['reason'] ?? 'Flagged by SafeSearch filters.'),
                      _MetadataRow('Severity Score', '${selected['score'] ?? 0} / 5'),
                      _MetadataRow('GCS Path', selected['filePath'] ?? 'N/A'),
                      _MetadataRow('Flagged At', _formatTimestamp(selected['flaggedAt'])),
                    ]),
                    const SizedBox(height: 32),

                    // Action buttons
                    if (selected['status'] == 'PENDING_REVIEW')
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: controller.isActionSubmitting.value
                                ? null
                                : () => _showDecisionDialog(context, controller, selected['id'], 'approve', false),
                            icon: const Icon(Icons.check_circle_outline, size: 18, color: AppColors.textPrimary),
                            label: const Text('Approve Image'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          OutlinedButton.icon(
                            onPressed: controller.isActionSubmitting.value
                                ? null
                                : () => _showDecisionDialog(context, controller, selected['id'], 'reject', false),
                            icon: const Icon(Icons.block_flipped, size: 18, color: AppColors.error),
                            label: const Text('Reject & Quarantine'),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.error),
                              foregroundColor: AppColors.error,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              );
            }),
          ),
        ],
      );
    });
  }

  // TAB 4: AUDIT LOGS TAB
  Widget _buildAuditLogsTab(BuildContext context, AdminController controller) {
    return Obx(() {
      final logs = controller.auditLogs;

      if (logs.isEmpty) {
        return const Center(
          child: Text(
            'No manual rejection logs recorded.',
            style: TextStyle(color: AppColors.textTertiary),
          ),
        );
      }

      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.bgDivider),
          ),
          child: DataTable(
            columnSpacing: 16,
            horizontalMargin: 20,
            columns: const [
              DataColumn(label: Text('Original Location', style: TextStyle(color: AppColors.textSecondary))),
              DataColumn(label: Text('Quarantine GCS Path', style: TextStyle(color: AppColors.textSecondary))),
              DataColumn(label: Text('Reason Code', style: TextStyle(color: AppColors.textSecondary))),
              DataColumn(label: Text('Owner ID', style: TextStyle(color: AppColors.textSecondary))),
              DataColumn(label: Text('Rejection Date', style: TextStyle(color: AppColors.textSecondary))),
            ],
            rows: logs.map((log) {
              return DataRow(
                cells: [
                  DataCell(Text(
                    log['originalPath'] ?? 'N/A',
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                  )),
                  DataCell(Text(
                    log['quarantinePath'] ?? 'N/A',
                    style: GoogleFonts.robotoMono(color: AppColors.brand, fontSize: 11),
                  )),
                  DataCell(Text(
                    log['reason'] ?? 'N/A',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  )),
                  DataCell(Text(
                    log['userId'] ?? 'N/A',
                    style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                  )),
                  DataCell(Text(
                    _formatTimestamp(log['rejectedAt']),
                    style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                  )),
                ],
              );
            }).toList(),
          ),
        ),
      );
    });
  }

  // Dialog window for approval/rejection input notes
  void _showDecisionDialog(
    BuildContext context,
    AdminController controller,
    String id,
    String action,
    bool isVideo, {
    bool isChannel = false,
    bool isReport = false,
  }) {
    final textCtrl = TextEditingController();

    Get.dialog(
      AlertDialog(
        backgroundColor: AppColors.bgSurface,
        title: Text(
          'Confirm Manual ${action.capitalizeFirst}',
          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Are you sure you want to manually $action this resource? '
              '${action == 'reject' ? 'This action logs an audit/moderation record.' : ''}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: textCtrl,
              maxLines: 3,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Enter review reason (optional)...',
                hintStyle: const TextStyle(color: AppColors.textTertiary),
                fillColor: AppColors.bgInput,
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Get.back();
              if (isReport) {
                await controller.moderateReport(id, action, textCtrl.text);
              } else if (isChannel) {
                await controller.moderateChannel(id, action, textCtrl.text);
              } else if (isVideo) {
                await controller.moderateVideo(id, action, textCtrl.text);
              } else {
                await controller.moderateImage(id, action, textCtrl.text);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: (action == 'approve' || action == 'dismiss') ? AppColors.success : AppColors.error,
              foregroundColor: AppColors.textPrimary,
            ),
            child: Text('Confirm ${action.capitalizeFirst}'),
          ),
        ],
      ),
    );
  }

  // SafeSearch ratings chip helper
  Widget _buildSafeSearchChip(String label, dynamic val) {
    final score = int.tryParse(val?.toString() ?? '0') ?? 0;
    var scoreColor = AppColors.success;
    if (score >= 3) scoreColor = AppColors.warning;
    if (score >= 5) scoreColor = AppColors.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scoreColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scoreColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
          Text(
            '$score',
            style: TextStyle(color: scoreColor, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // Status Badge Builder
  Widget _buildStatusBadge(String status) {
    var color = AppColors.textTertiary;
    final txt = status.toUpperCase();

    if (txt == 'APPROVED' || txt == 'SUCCESS' || txt == 'RESOLVED_DISMISSED' || txt == 'RESOLVED') {
      color = AppColors.success;
    } else if (txt == 'REJECTED' || txt == 'ERROR' || txt == 'FAILED' || txt == 'RESOLVED_REJECTED') {
      color = AppColors.error;
    } else if (txt == 'PENDING' || txt == 'PENDING_REVIEW' || txt == 'PROCESSING' || txt == 'UNDERREVIEW') {
      color = AppColors.warning;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        txt,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Metadata Table Builder
  Widget _buildMetadataTable(List<_MetadataRow> rows) {
    return Table(
      columnWidths: const {
        0: IntrinsicColumnWidth(),
        1: FlexColumnWidth(),
      },
      children: rows.map((row) {
        return TableRow(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8, right: 16),
              child: Text(
                row.label,
                style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                row.value,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

class _MetadataRow {
  const _MetadataRow(this.label, this.value);
  final String label;
  final String value;
}

// Stateful Video Player wrapper
class AdminVideoPlayerController extends GetxController {
  AdminVideoPlayerController(this.url);
  final String url;

  late VideoPlayerController videoCtrl;
  ChewieController? chewieCtrl;
  final RxBool isPlayerInitialized = false.obs;
  final RxnString error = RxnString();

  @override
  void onInit() {
    super.onInit();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      videoCtrl = VideoPlayerController.networkUrl(Uri.parse(url));
      await videoCtrl.initialize();
      chewieCtrl = ChewieController(
        videoPlayerController: videoCtrl,
        aspectRatio: videoCtrl.value.aspectRatio,
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.brand,
          handleColor: AppColors.brand,
          bufferedColor: AppColors.progressBuffered,
          backgroundColor: AppColors.progressTrack,
        ),
      );
      isPlayerInitialized.value = true;
    } catch (e) {
      error.value = 'Error loading video player: $e';
    }
  }

  @override
  void onClose() {
    videoCtrl.dispose();
    chewieCtrl?.dispose();
    super.onClose();
  }
}

// GetX Video Player wrapper
class AdminVideoPlayer extends StatelessWidget {
  const AdminVideoPlayer({required this.url, super.key});
  final String url;

  @override
  Widget build(BuildContext context) {
    // Unique tag per url to support multiple video player instances
    final controller = Get.put(AdminVideoPlayerController(url), tag: url);

    return Obx(() {
      if (controller.error.value != null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              controller.error.value!,
              style: const TextStyle(color: AppColors.error, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        );
      }
      if (!controller.isPlayerInitialized.value) {
        return const Center(
          child: SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.brand),
            ),
          ),
        );
      }
      return Chewie(controller: controller.chewieCtrl!);
    });
  }
}
