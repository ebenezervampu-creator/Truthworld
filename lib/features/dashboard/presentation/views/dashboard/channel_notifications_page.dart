import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/widgets/studio_loading_indicator.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/channel_notifications_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/notifications/channel_notifications_widgets.dart';
import 'package:truthworld/features/notifications/data/models/user_notification.dart';
import 'package:truthworld/theme/app_theme.dart';

export 'package:truthworld/features/dashboard/presentation/views/dashboard/notifications/channel_notifications_widgets.dart';

/// Creator Studio Channel Notifications view displaying channel health, AI verification audits, and milestones.
class ChannelNotificationsPage extends StatelessWidget {
  const ChannelNotificationsPage({
    required this.channelId,
    required this.creatorId,
    super.key,
  });

  final String channelId;
  final String creatorId;

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: TWTypography.uiFamily,
          fontFamilyFallback: TWTypography.fallbackFamilies,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final horizontalPadding = isMobile ? 16.0 : 24.0;

    final controller = Get.put(
      ChannelNotificationsController(
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
            child: ChannelNotificationsHeaderBanner(controller: controller),
          ),

          // ── Category Filter Chips ──
          SliverToBoxAdapter(
            child: ChannelNotificationsFilterChips(controller: controller),
          ),

          // ── Main Content List ──
          Obx(() {
            if (controller.isLoading && controller.notifications.isEmpty) {
              return const SliverFillRemaining(
                hasScrollBody: false,
                child: StudioLoadingIndicator(
                  message: 'Loading notifications...',
                  isFullScreen: false,
                ),
              );
            }

            final allFiltered = controller.filteredNotifications;
            final hasTruthworldIssues = controller.hasActiveIssues;

            if (allFiltered.isEmpty && !hasTruthworldIssues) {
              return const SliverFillRemaining(
                child: ChannelNotificationsEmptyState(),
              );
            }

            return SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 12,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Truthworld Issues & Channel Health Section
                  if (hasTruthworldIssues)
                    ChannelNotificationsIssuesSection(
                      controller: controller,
                      channelId: channelId,
                      creatorId: creatorId,
                    ),

                  // Sticky Critical Banner if present
                  if (controller.filteredNotifications.any(
                    (n) => n.priority == NotificationPriority.critical,
                  ))
                    ChannelNotificationsCriticalSection(
                      controller: controller,
                      channelId: channelId,
                    ),

                  // Today Section
                  if (controller.todayNotifications.isNotEmpty) ...[
                    _buildSectionHeader('TODAY'),
                    ...controller.todayNotifications.map(
                      (n) => ChannelNotificationsNotificationCard(
                        controller: controller,
                        notification: n,
                        channelId: channelId,
                      ),
                    ),
                  ],

                  // Yesterday Section
                  if (controller.yesterdayNotifications.isNotEmpty) ...[
                    _buildSectionHeader('YESTERDAY'),
                    ...controller.yesterdayNotifications.map(
                      (n) => ChannelNotificationsNotificationCard(
                        controller: controller,
                        notification: n,
                        channelId: channelId,
                      ),
                    ),
                  ],

                  // This Week Section
                  if (controller.thisWeekNotifications.isNotEmpty) ...[
                    _buildSectionHeader('THIS WEEK'),
                    ...controller.thisWeekNotifications.map(
                      (n) => ChannelNotificationsNotificationCard(
                        controller: controller,
                        notification: n,
                        channelId: channelId,
                      ),
                    ),
                  ],

                  // Earlier Section
                  if (controller.earlierNotifications.isNotEmpty) ...[
                    _buildSectionHeader('EARLIER'),
                    ...controller.earlierNotifications.map(
                      (n) => ChannelNotificationsNotificationCard(
                        controller: controller,
                        notification: n,
                        channelId: channelId,
                      ),
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
}
