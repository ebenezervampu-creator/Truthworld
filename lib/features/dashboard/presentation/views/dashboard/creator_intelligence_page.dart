import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/creator_intelligence_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification_dashboard_page.dart';
import 'package:truthworld/features/notifications/data/models/user_notification.dart';
import 'package:truthworld/theme/app_theme.dart';

class CreatorIntelligencePage extends StatelessWidget {
  const CreatorIntelligencePage({
    required this.channelId,
    required this.creatorId,
    super.key,
  });
  final String channelId;
  final String creatorId;

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(
      CreatorIntelligenceController(
        channelId: channelId,
        creatorId: creatorId,
      ),
      tag: channelId,
    );

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: CustomScrollView(
        slivers: [
          // ── App Header Banner ──
          SliverToBoxAdapter(
            child: _buildHeaderBanner(context, controller),
          ),

          // ── Filter Chips ──
          SliverToBoxAdapter(
            child: _buildFilterChips(context, controller),
          ),

          // ── Main Content List ──
          Obx(() {
            if (controller.isLoading) {
              return const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.brand,
                  ),
                ),
              );
            }

            final allFiltered = controller.filteredNotifications;

            if (allFiltered.isEmpty) {
              return SliverFillRemaining(
                child: _buildEmptyState(context),
              );
            }

            return SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Sticky Critical Banner if present
                  if (controller.filteredNotifications.any(
                    (n) => n.priority == NotificationPriority.critical,
                  ))
                    _buildCriticalSection(context, controller),

                  // Today Section
                  if (controller.todayNotifications.isNotEmpty) ...[
                    _buildSectionHeader('TODAY'),
                    ...controller.todayNotifications.map(
                      (n) => _buildNotificationCard(context, controller, n),
                    ),
                  ],

                  // Yesterday Section
                  if (controller.yesterdayNotifications.isNotEmpty) ...[
                    _buildSectionHeader('YESTERDAY'),
                    ...controller.yesterdayNotifications.map(
                      (n) => _buildNotificationCard(context, controller, n),
                    ),
                  ],

                  // This Week Section
                  if (controller.thisWeekNotifications.isNotEmpty) ...[
                    _buildSectionHeader('THIS WEEK'),
                    ...controller.thisWeekNotifications.map(
                      (n) => _buildNotificationCard(context, controller, n),
                    ),
                  ],

                  // Earlier Section
                  if (controller.earlierNotifications.isNotEmpty) ...[
                    _buildSectionHeader('EARLIER'),
                    ...controller.earlierNotifications.map(
                      (n) => _buildNotificationCard(context, controller, n),
                    ),
                  ],

                  const SizedBox(height: 48),
                ]),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHeaderBanner(
    BuildContext context,
    CreatorIntelligenceController controller,
  ) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    final titleSection = Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.brand.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.insights_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Creator Intelligence',
                style: AppTextStyles.pageTitle.copyWith(
                  fontSize: isMobile ? 20 : 24,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Real-time channel milestones, performance insights & verification audits',
                style: AppTextStyles.caption.copyWith(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final actionSection = Row(
      mainAxisSize: isMobile ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: isMobile
          ? MainAxisAlignment.spaceBetween
          : MainAxisAlignment.end,
      children: [
        Obx(() {
          if (controller.unreadCount.value > 0) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: AppColors.brand,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${controller.unreadCount.value} UNREAD',
                style: AppTextStyles.badge.copyWith(
                  fontSize: 11,
                  color: Colors.white,
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        }),
        OutlinedButton.icon(
          onPressed: () => controller.markAllAsRead(),
          icon: const Icon(
            Icons.done_all_rounded,
            size: 16,
            color: Colors.white,
          ),
          label: Text(
            'Mark all as read',
            style: AppTextStyles.buttonText.copyWith(
              fontSize: 13,
              color: Colors.white,
            ),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: AppColors.brand),
            backgroundColor: AppColors.brand.withValues(alpha: 0.15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: const BoxDecoration(
        color: AppColors.bgPage,
        border: Border(
          bottom: BorderSide(
            color: AppColors.bgDivider,
          ),
        ),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleSection,
                const SizedBox(height: 14),
                actionSection,
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: titleSection),
                const SizedBox(width: 16),
                actionSection,
              ],
            ),
    );
  }

  Widget _buildFilterChips(
    BuildContext context,
    CreatorIntelligenceController controller,
  ) {
    final categories = [
      {'id': 'all', 'label': 'All Insights', 'icon': Icons.clear_all_rounded},
      {
        'id': 'critical',
        'label': 'Critical & Policy',
        'icon': Icons.warning_amber_rounded,
      },
      {
        'id': 'growth',
        'label': 'Milestones & Growth',
        'icon': Icons.emoji_events_rounded,
      },
      {
        'id': 'verification',
        'label': 'Fact Verification',
        'icon': Icons.verified_user_rounded,
      },
      {
        'id': 'performance',
        'label': 'Performance Spike',
        'icon': Icons.trending_up_rounded,
      },
      {
        'id': 'coach',
        'label': 'AI Creator Coach',
        'icon': Icons.auto_awesome_rounded,
      },
    ];

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Obx(() {
        final currentCategory = controller.selectedCategory.value;
        return ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: categories.length,
          separatorBuilder: (context, index) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final cat = categories[index];
            final catId = cat['id']! as String;
            final isSelected = currentCategory == catId;

            return ChoiceChip(
              avatar: Icon(
                cat['icon']! as IconData,
                size: 16,
                color: Colors.white,
              ),
              label: Text(
                cat['label']! as String,
                style: AppTextStyles.labelMedium.copyWith(
                  color: isSelected ? Colors.black : AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  controller.selectedCategory.value = catId;
                }
              },
              selectedColor: AppColors.brand,
              backgroundColor: AppColors.bgSurface,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? AppColors.brand : AppColors.bgDivider,
                ),
              ),
            );
          },
        );
      }),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text(
        title,
        style: AppTextStyles.labelMedium.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildCriticalSection(
    BuildContext context,
    CreatorIntelligenceController controller,
  ) {
    final criticalItems = controller.filteredNotifications
        .where((n) => n.priority == NotificationPriority.critical)
        .toList();

    if (criticalItems.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Text(
                'ACTION REQUIRED',
                style: AppTextStyles.labelMedium.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...criticalItems.map(
            (n) => _buildNotificationCard(
              context,
              controller,
              n,
              isCriticalStyle: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(
    BuildContext context,
    CreatorIntelligenceController controller,
    UserNotification notification, {
    bool isCriticalStyle = false,
  }) {
    const cardColor = AppColors.bgSurface;
    final borderSide = BorderSide(
      color: notification.read
          ? AppColors.bgDivider
          : AppColors.brand.withValues(alpha: 0.6),
      width: notification.read ? 1 : 1.5,
    );

    var leadingIcon = Icons.notifications_rounded;
    var containerBgColor = AppColors.brand;

    if (notification.type.contains('verification')) {
      if (notification.priority == NotificationPriority.critical ||
          notification.severity == NotificationSeverity.warning) {
        leadingIcon = Icons.cancel_rounded;
        containerBgColor = AppColors.error;
      } else {
        leadingIcon = Icons.verified_rounded;
        containerBgColor = AppColors.success;
      }
    } else if (notification.type.contains('milestone')) {
      leadingIcon = Icons.emoji_events_rounded;
      containerBgColor = AppColors.warning;
    } else if (notification.type.contains('performance') ||
        notification.type.contains('retention')) {
      leadingIcon = Icons.trending_up_rounded;
      containerBgColor = AppColors.info;
    } else if (notification.type.contains('coach')) {
      leadingIcon = Icons.auto_awesome_rounded;
      containerBgColor = AppColors.brand;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.fromBorderSide(borderSide),
        boxShadow: notification.read
            ? []
            : [
                BoxShadow(
                  color: AppColors.brand.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            controller.markAsRead(notification.id);
            if (notification.verificationReportId != null &&
                notification.verificationReportId!.isNotEmpty) {
              _showVerificationReportModal(
                context,
                controller,
                notification.verificationReportId!,
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon Badge
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: containerBgColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(leadingIcon, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),

                    // Main Text Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  notification.title,
                                  style: AppTextStyles.titleMedium.copyWith(
                                    fontSize: 15,
                                    fontWeight: notification.read
                                        ? FontWeight.w500
                                        : FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat(
                                  'h:mm a',
                                ).format(notification.createdAt),
                                style: AppTextStyles.caption.copyWith(
                                  fontSize: 12,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            notification.message,
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontSize: 13,
                              height: 1.4,
                              color: AppColors.textSecondary,
                            ),
                          ),

                          // Analytics Snapshot frozen stats pill if present
                          if (notification.analyticsSnapshot != null) ...[
                            const SizedBox(height: 10),
                            _buildAnalyticsSnapshotPill(
                              context,
                              notification.analyticsSnapshot!,
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Unread Indicator
                    if (!notification.read)
                      Container(
                        margin: const EdgeInsets.only(left: 10),
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.brand,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),

                // Action Buttons Row
                if (notification.actions.isNotEmpty ||
                    notification.verificationReportId != null) ...[
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: AppColors.bgDivider),
                  const SizedBox(height: 10),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (notification.verificationReportId != null)
                        ElevatedButton.icon(
                          onPressed: () => _showVerificationReportModal(
                            context,
                            controller,
                            notification.verificationReportId!,
                          ),
                          icon: const Icon(
                            Icons.assessment_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                          label: Text(
                            'View Verification Audit',
                            style: AppTextStyles.buttonText.copyWith(
                              fontSize: 12,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brand,
                            foregroundColor: AppColors.textPrimary,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      for (final action in notification.actions)
                        OutlinedButton(
                          onPressed: () => _handleAction(context, action),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: AppColors.brand),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            action.label,
                            style: AppTextStyles.buttonText.copyWith(
                              fontSize: 12,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyticsSnapshotPill(
    BuildContext context,
    AnalyticsSnapshotData snap,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.bgInput,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.history_rounded, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Snapshot at creation: ${NumberFormat.compact().format(snap.views)} views • ${NumberFormat.compact().format(snap.subscribers)} subs',
              style: AppTextStyles.captionBold.copyWith(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.insights_rounded,
              size: 64,
              color: Colors.white,
            ),
            const SizedBox(height: 16),
            Text(
              'No Creator Insights Yet',
              style: AppTextStyles.pageTitle.copyWith(
                fontSize: 18,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Milestones, video verification audit reports, and AI growth tips will appear here.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showVerificationReportModal(
    BuildContext context,
    CreatorIntelligenceController controller,
    String reportId,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return FutureBuilder<Map<String, dynamic>?>(
          future: controller.fetchVerificationReport(reportId),
          builder: (context, snapshot) {
            final data = snapshot.data;

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.textSecondary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Icon(
                        Icons.verified_user_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Fact Verification Audit Report',
                          style: AppTextStyles.headlineSmall.copyWith(
                            fontSize: 20,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: AppColors.bgDivider),
                  const SizedBox(height: 16),

                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Expanded(
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.brand,
                        ),
                      ),
                    )
                  else if (data == null)
                    Expanded(
                      child: Center(
                        child: Text(
                          'Verification Report Details Available in Verification Tab.',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView(
                        children: [
                          _buildAuditRow(
                            'Status',
                            (data['status'] ?? 'Rejected')
                                .toString()
                                .toUpperCase(),
                            AppColors.error,
                          ),
                          _buildAuditRow(
                            'Primary Reason',
                            data['primaryReason'] as String? ??
                                'AI Synthetic Content Detected without disclosure',
                            AppColors.textPrimary,
                          ),
                          _buildAuditRow(
                            'Confidence Score',
                            '${(((data['confidenceScore'] as num?) ?? 0.86) * 100).toInt()}%',
                            AppColors.warning,
                          ),
                          _buildAuditRow(
                            'Detected Flagged Frames',
                            (data['flaggedFrames'] as List? ??
                                    ['00:45', '02:12', '05:31'])
                                .join(', '),
                            AppColors.info,
                          ),
                          _buildAuditRow(
                            'Recommended Action',
                            data['recommendedFix'] as String? ??
                                'Enable AI Synthetic content label in video metadata settings or submit an appeal.',
                            AppColors.textPrimary,
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    Get.to<void>(
                                      () => TruthVerificationDashboardPage(
                                        channelId: channelId,
                                        isDarkMode: true,
                                      ),
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.gavel_rounded,
                                    color: Colors.white,
                                  ),
                                  label: Text(
                                    'Submit Appeal',
                                    style: AppTextStyles.buttonText.copyWith(
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.brand,
                                    foregroundColor: AppColors.textPrimary,
                                    padding: const EdgeInsets.all(14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAuditRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.captionBold.copyWith(
              fontSize: 12,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  void _handleAction(BuildContext context, NotificationActionItem action) {
    switch (action.type) {
      case 'OPEN_ANALYTICS':
        Get.snackbar(
          'Navigating',
          'Opening Channel Analytics...',
          backgroundColor: AppColors.brand,
          colorText: AppColors.textPrimary,
        );
      case 'APPEAL_VERIFICATION':
        Get.to<void>(
          () => TruthVerificationDashboardPage(
            channelId: channelId,
            isDarkMode: true,
          ),
        );
      default:
        Get.snackbar(
          'Action Triggered',
          action.label,
          backgroundColor: AppColors.bgSurface,
          colorText: AppColors.textPrimary,
        );
    }
  }
}
