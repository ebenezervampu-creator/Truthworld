import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/creator_intelligence_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/intelligence/creator_intelligence_widgets.dart';
import 'package:truthworld/features/notifications/data/models/user_notification.dart';

export 'package:truthworld/features/dashboard/presentation/views/dashboard/intelligence/creator_intelligence_widgets.dart';

/// Creator Studio Intelligence view displaying channel health, AI verification audits, and milestones.
class CreatorIntelligencePage extends StatelessWidget {
  const CreatorIntelligencePage({
    required this.channelId,
    required this.creatorId,
    super.key,
  });

  final String channelId;
  final String creatorId;

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: Color(0xFF71717A),
        ),
      ),
    );
  }

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
      backgroundColor: const Color(0xFF0F0F0F),
      body: CustomScrollView(
        slivers: [
          // ── App Header Banner ──
          SliverToBoxAdapter(
            child: IntelligenceHeaderBanner(controller: controller),
          ),

          // ── Filter Chips ──
          SliverToBoxAdapter(
            child: IntelligenceFilterChips(controller: controller),
          ),

          // ── Main Content List ──
          Obx(() {
            if (controller.isLoading) {
              return const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              );
            }

            final allFiltered = controller.filteredNotifications;
            final hasTruthworldIssues = controller.hasActiveIssues;

            if (allFiltered.isEmpty && !hasTruthworldIssues) {
              return const SliverFillRemaining(
                child: IntelligenceEmptyState(),
              );
            }

            return SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Truthworld Issues & Channel Health Section
                  if (hasTruthworldIssues)
                    IntelligenceIssuesSection(
                      controller: controller,
                      channelId: channelId,
                      creatorId: creatorId,
                    ),

                  // Sticky Critical Banner if present
                  if (controller.filteredNotifications.any(
                    (n) => n.priority == NotificationPriority.critical,
                  ))
                    IntelligenceCriticalSection(
                      controller: controller,
                      channelId: channelId,
                    ),

                  // Today Section
                  if (controller.todayNotifications.isNotEmpty) ...[
                    _buildSectionHeader('TODAY'),
                    ...controller.todayNotifications.map(
                      (n) => IntelligenceNotificationCard(
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
                      (n) => IntelligenceNotificationCard(
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
                      (n) => IntelligenceNotificationCard(
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
                      (n) => IntelligenceNotificationCard(
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
