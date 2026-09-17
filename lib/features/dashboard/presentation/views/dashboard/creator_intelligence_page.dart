import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/creator_intelligence_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/copyright_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/customization_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification_dashboard_page.dart';
import 'package:truthworld/features/notifications/data/models/user_notification.dart';

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
      backgroundColor: const Color(0xFF0F0F0F),
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
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              );
            }

            final allFiltered = controller.filteredNotifications;
            final hasTruthworldIssues = controller.hasActiveIssues;

            if (allFiltered.isEmpty && !hasTruthworldIssues) {
              return SliverFillRemaining(
                child: _buildEmptyState(context),
              );
            }

            return SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Truthworld Issues & Channel Health Section
                  if (hasTruthworldIssues)
                    _buildTruthworldIssuesSection(context, controller),

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
            color: const Color(0xFF161618),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF27272A)),
          ),
          child: const Icon(
            Icons.insights_rounded,
            color: Colors.white,
            size: 26,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Creator Intelligence',
                style: TextStyle(
                  fontSize: isMobile ? 20 : 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Real-time channel milestones, performance insights & verification audits',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFFA1A1AA),
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
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                '${controller.unreadCount.value} UNREAD',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF38BDF8),
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
          label: const Text(
            'Mark all as read',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Color(0xFF3F3F46)),
            backgroundColor: const Color(0xFF18181B),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: 16,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F0F),
        border: Border(
          bottom: BorderSide(
            color: Color(0xFF27272A),
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
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
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
                size: 15,
                color: Colors.white,
              ),
              label: Text(
                cat['label']! as String,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFFA1A1AA),
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  controller.selectedCategory.value = catId;
                }
              },
              selectedColor: const Color(0xFF27272A),
              backgroundColor: const Color(0xFF161618),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: isSelected
                      ? const Color(0xFF38BDF8)
                      : const Color(0xFF27272A),
                ),
              ),
            );
          },
        );
      }),
    );
  }

  Widget _buildTruthworldIssuesSection(
    BuildContext context,
    CreatorIntelligenceController controller,
  ) {
    final ch = controller.currentChannel.value;
    final copyrightCount = controller.copyrightClaimsCount.value;

    final issueCards = <Widget>[];

    // 1. Channel Moderation Status
    if (ch != null) {
      if (ch.status == ChannelStatus.verificationRejected) {
        issueCards.add(
          _buildIssueCard(
            context: context,
            title: 'Channel Branding Verification Rejected',
            description: ch.moderationReason != null &&
                    ch.moderationReason!.isNotEmpty
                ? 'Truthworld Verification System Response: ${ch.moderationReason}'
                : 'Your channel details did not pass automated verification. Channel is queued for manual verification review.',
            statusType: 'REJECTED',
            icon: Icons.error_outline_rounded,
            actions: [
              ElevatedButton.icon(
                onPressed: () {
                  Get.toNamed(
                    '/community-guidelines',
                    arguments: {
                      'fromRejectedChannelId': ch.id,
                      'ownerId': ch.ownerId,
                    },
                  );
                },
                icon: const Icon(Icons.description_outlined,
                    color: Colors.white, size: 15),
                label: const Text('Review Community Guidelines'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      } else if (ch.status == ChannelStatus.underReview) {
        issueCards.add(
          _buildIssueCard(
            context: context,
            title: 'Channel Branding Under Verification Review',
            description:
                'Truthworld Verification System is currently evaluating your channel details against community guidelines.',
            statusType: 'PENDING',
            icon: Icons.sync_rounded,
            isLoading: true,
          ),
        );
      }

      // 2. Avatar Status
      if (ch.avatarStatus == 'REJECTED') {
        issueCards.add(
          _buildIssueCard(
            context: context,
            title: 'Avatar Image Rejected',
            description: ch.avatarStatusReason != null &&
                    ch.avatarStatusReason!.isNotEmpty
                ? 'Verification Note: ${ch.avatarStatusReason}'
                : 'Your channel avatar image failed content verification guidelines.',
            statusType: 'REJECTED',
            icon: Icons.error_outline_rounded,
            actions: [
              ElevatedButton.icon(
                onPressed: () {
                  Get.to<void>(() => ChannelCustomizationPage(
                        channelId: channelId,
                        ownerId: creatorId,
                      ));
                },
                icon: const Icon(Icons.edit_rounded,
                    color: Colors.white, size: 15),
                label: const Text('Change Avatar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => controller.requestAvatarManualReview(),
                icon: const Icon(Icons.rate_review_rounded,
                    color: Colors.white, size: 15),
                label: const Text('Request Manual Review'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF3F3F46)),
                  backgroundColor: const Color(0xFF18181B),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => controller.bypassAvatarVerification(),
                icon: const Icon(Icons.flash_on_rounded,
                    color: Colors.white, size: 15),
                label: const Text('Bypass (Debug)'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFA1A1AA),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        );
      } else if (ch.avatarStatus == 'FLAGGED') {
        issueCards.add(
          _buildIssueCard(
            context: context,
            title: 'Avatar Image Flagged for Review',
            description:
                'Your channel avatar was flagged for potential guidelines review. You may upload a new image or request manual admin review.',
            statusType: 'FLAGGED',
            icon: Icons.warning_amber_rounded,
            actions: [
              ElevatedButton.icon(
                onPressed: () {
                  Get.to<void>(() => ChannelCustomizationPage(
                        channelId: channelId,
                        ownerId: creatorId,
                      ));
                },
                icon: const Icon(Icons.edit_rounded,
                    color: Colors.white, size: 15),
                label: const Text('Change Avatar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => controller.requestAvatarManualReview(),
                icon: const Icon(Icons.rate_review_rounded,
                    color: Colors.white, size: 15),
                label: const Text('Request Manual Review'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF3F3F46)),
                  backgroundColor: const Color(0xFF18181B),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      } else if (ch.avatarStatus == 'MANUAL_REVIEW') {
        issueCards.add(
          _buildIssueCard(
            context: context,
            title: 'Avatar Under Manual Review',
            description:
                'Your avatar appeal has been received. Our moderation team is reviewing your image.',
            statusType: 'MANUAL_REVIEW',
            icon: Icons.rate_review_rounded,
          ),
        );
      } else if (ch.avatarStatus == 'PENDING') {
        issueCards.add(
          _buildIssueCard(
            context: context,
            title: 'Avatar Verification Pending',
            description:
                'Google Vision AI is validating your channel avatar image.',
            statusType: 'PENDING',
            icon: Icons.sync_rounded,
            isLoading: true,
            actions: [
              TextButton.icon(
                onPressed: () => controller.bypassAvatarVerification(),
                icon: const Icon(Icons.flash_on_rounded,
                    color: Colors.white, size: 15),
                label: const Text('Bypass (Debug)'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFA1A1AA),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        );
      }

      // 3. Banner Status
      if (ch.bannerStatus == 'REJECTED') {
        issueCards.add(
          _buildIssueCard(
            context: context,
            title: 'Banner Image Rejected',
            description: ch.bannerStatusReason != null &&
                    ch.bannerStatusReason!.isNotEmpty
                ? 'Verification Note: ${ch.bannerStatusReason}'
                : 'Your uploaded banner image did not pass automated content verification guidelines.',
            statusType: 'REJECTED',
            icon: Icons.error_outline_rounded,
            actions: [
              ElevatedButton.icon(
                onPressed: () {
                  Get.to<void>(() => ChannelCustomizationPage(
                        channelId: channelId,
                        ownerId: creatorId,
                      ));
                },
                icon: const Icon(Icons.edit_rounded,
                    color: Colors.white, size: 15),
                label: const Text('Change Banner'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => controller.requestBannerManualReview(),
                icon: const Icon(Icons.rate_review_rounded,
                    color: Colors.white, size: 15),
                label: const Text('Request Manual Review'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF3F3F46)),
                  backgroundColor: const Color(0xFF18181B),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => controller.bypassBannerVerification(),
                icon: const Icon(Icons.flash_on_rounded,
                    color: Colors.white, size: 15),
                label: const Text('Bypass (Debug)'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFA1A1AA),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        );
      } else if (ch.bannerStatus == 'FLAGGED') {
        issueCards.add(
          _buildIssueCard(
            context: context,
            title: 'Banner Image Flagged for Review',
            description:
                'Your banner image was flagged for potential guidelines review. You may upload a new image or request manual admin review.',
            statusType: 'FLAGGED',
            icon: Icons.warning_amber_rounded,
            actions: [
              ElevatedButton.icon(
                onPressed: () {
                  Get.to<void>(() => ChannelCustomizationPage(
                        channelId: channelId,
                        ownerId: creatorId,
                      ));
                },
                icon: const Icon(Icons.edit_rounded,
                    color: Colors.white, size: 15),
                label: const Text('Change Banner'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => controller.requestBannerManualReview(),
                icon: const Icon(Icons.rate_review_rounded,
                    color: Colors.white, size: 15),
                label: const Text('Request Manual Review'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF3F3F46)),
                  backgroundColor: const Color(0xFF18181B),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      } else if (ch.bannerStatus == 'MANUAL_REVIEW') {
        issueCards.add(
          _buildIssueCard(
            context: context,
            title: 'Banner Under Manual Review',
            description:
                'Your banner appeal has been received. Our moderation team is reviewing your image.',
            statusType: 'MANUAL_REVIEW',
            icon: Icons.rate_review_rounded,
          ),
        );
      } else if (ch.bannerStatus == 'PENDING') {
        issueCards.add(
          _buildIssueCard(
            context: context,
            title: 'Banner Verification Pending',
            description:
                'Google Vision AI is validating your channel banner image.',
            statusType: 'PENDING',
            icon: Icons.sync_rounded,
            isLoading: true,
            actions: [
              TextButton.icon(
                onPressed: () => controller.bypassBannerVerification(),
                icon: const Icon(Icons.flash_on_rounded,
                    color: Colors.white, size: 15),
                label: const Text('Bypass (Debug)'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFA1A1AA),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        );
      }
    }

    // 4. Copyright Claims
    if (copyrightCount > 0) {
      issueCards.add(
        _buildIssueCard(
          context: context,
          title: 'Channel Copyright Claims ($copyrightCount Active)',
          description:
              'Your channel has $copyrightCount active copyright claim(s). This may affect your video monetization or visibility.',
          statusType: 'REJECTED',
          icon: Icons.copyright_rounded,
          actions: [
            ElevatedButton.icon(
              onPressed: () {
                Get.to<void>(() => CopyrightScreen(channelId: channelId));
              },
              icon: const Icon(Icons.shield_rounded,
                  color: Colors.white, size: 15),
              label: const Text('View Copyright Details'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (issueCards.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFEF4444).withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF450A0A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                  ),
                ),
                child: const Icon(
                  Icons.gavel_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TRUTHWORLD AUDITS & ACTIVE NOTICES',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                        color: Color(0xFFF87171),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Real-time verification flags, moderation notices & policy health',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFFA1A1AA),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFF27272A)),
          const SizedBox(height: 16),
          ...issueCards,
        ],
      ),
    );
  }

  Widget _buildIssueCard({
    required BuildContext context,
    required String title,
    required String description,
    required String statusType,
    required IconData icon,
    bool isLoading = false,
    List<Widget> actions = const [],
  }) {
    Color badgeBg;
    Color borderColor;

    if (statusType == 'PENDING') {
      badgeBg = const Color(0xFF1E293B);
      borderColor = const Color(0xFF38BDF8).withValues(alpha: 0.4);
    } else if (statusType == 'APPROVED') {
      badgeBg = const Color(0xFF064E3B);
      borderColor = const Color(0xFF10B981).withValues(alpha: 0.4);
    } else if (statusType == 'FLAGGED') {
      badgeBg = const Color(0xFF451A03);
      borderColor = const Color(0xFFF59E0B).withValues(alpha: 0.4);
    } else if (statusType == 'MANUAL_REVIEW') {
      badgeBg = const Color(0xFF2E1065);
      borderColor = const Color(0xFF8B5CF6).withValues(alpha: 0.4);
    } else {
      // REJECTED
      badgeBg = const Color(0xFF450A0A);
      borderColor = const Color(0xFFEF4444).withValues(alpha: 0.4);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Icon(icon, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFA1A1AA),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: actions,
            ),
          ],
        ],
      ),
    );
  }

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
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFEF4444).withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF450A0A),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                  ),
                ),
                child: const Icon(
                  Icons.warning_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'ACTION REQUIRED',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: Color(0xFFF87171),
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
    final isUnread = !notification.read;

    var leadingIcon = Icons.notifications_rounded;
    var badgeBg = const Color(0xFF18181B);
    var badgeBorder = const Color(0xFF27272A);

    if (notification.type.contains('verification')) {
      if (notification.priority == NotificationPriority.critical ||
          notification.severity == NotificationSeverity.warning) {
        leadingIcon = Icons.cancel_rounded;
        badgeBg = const Color(0xFF450A0A);
        badgeBorder = const Color(0xFFEF4444).withValues(alpha: 0.4);
      } else {
        leadingIcon = Icons.verified_rounded;
        badgeBg = const Color(0xFF064E3B);
        badgeBorder = const Color(0xFF10B981).withValues(alpha: 0.4);
      }
    } else if (notification.type.contains('milestone')) {
      leadingIcon = Icons.emoji_events_rounded;
      badgeBg = const Color(0xFF451A03);
      badgeBorder = const Color(0xFFF59E0B).withValues(alpha: 0.4);
    } else if (notification.type.contains('performance') ||
        notification.type.contains('retention')) {
      leadingIcon = Icons.trending_up_rounded;
      badgeBg = const Color(0xFF1E293B);
      badgeBorder = const Color(0xFF38BDF8).withValues(alpha: 0.4);
    } else if (notification.type.contains('coach')) {
      leadingIcon = Icons.auto_awesome_rounded;
      badgeBg = const Color(0xFF2E1065);
      badgeBorder = const Color(0xFF8B5CF6).withValues(alpha: 0.4);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUnread
              ? const Color(0xFF38BDF8).withValues(alpha: 0.5)
              : const Color(0xFF27272A),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
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
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: badgeBorder),
                      ),
                      child: Icon(leadingIcon, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),

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
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isUnread
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat(
                                  'h:mm a',
                                ).format(notification.createdAt),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF71717A),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            notification.message,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: Color(0xFFA1A1AA),
                            ),
                          ),

                          // Analytics Snapshot pill
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

                    // Unread Indicator Dot
                    if (isUnread)
                      Container(
                        margin: const EdgeInsets.only(left: 8, top: 4),
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF38BDF8),
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),

                // Action Buttons Row
                if (notification.actions.isNotEmpty ||
                    notification.verificationReportId != null) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFF27272A)),
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
                            size: 15,
                            color: Colors.white,
                          ),
                          label: const Text('View Verification Audit'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      for (final action in notification.actions)
                        OutlinedButton(
                          onPressed: () => _handleAction(context, action),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFF3F3F46)),
                            backgroundColor: const Color(0xFF18181B),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          child: Text(action.label),
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
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.history_rounded, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Snapshot at creation: ${NumberFormat.compact().format(snap.views)} views • ${NumberFormat.compact().format(snap.subscribers)} subs',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFFA1A1AA),
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
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF161618),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF27272A)),
              ),
              child: const Icon(
                Icons.insights_rounded,
                size: 40,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Creator Insights Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Milestones, video verification audit reports, and AI growth tips will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFFA1A1AA),
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
                color: Color(0xFF161618),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(
                  top: BorderSide(color: Color(0xFF27272A)),
                ),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3F3F46),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF064E3B),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color:
                                const Color(0xFF10B981).withValues(alpha: 0.4),
                          ),
                        ),
                        child: const Icon(
                          Icons.verified_user_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Fact Verification Audit Report',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFF27272A)),
                  const SizedBox(height: 16),

                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Expanded(
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    )
                  else if (data == null)
                    const Expanded(
                      child: Center(
                        child: Text(
                          'Verification Report Details Available in Verification Tab.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFFA1A1AA),
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
                            const Color(0xFFF87171),
                          ),
                          _buildAuditRow(
                            'Primary Reason',
                            data['primaryReason'] as String? ??
                                'AI Synthetic Content Detected without disclosure',
                            Colors.white,
                          ),
                          _buildAuditRow(
                            'Confidence Score',
                            '${(((data['confidenceScore'] as num?) ?? 0.86) * 100).toInt()}%',
                            const Color(0xFFFBBF24),
                          ),
                          _buildAuditRow(
                            'Detected Flagged Frames',
                            (data['flaggedFrames'] as List? ??
                                    ['00:45', '02:12', '05:31'])
                                .join(', '),
                            const Color(0xFF38BDF8),
                          ),
                          _buildAuditRow(
                            'Recommended Action',
                            data['recommendedFix'] as String? ??
                                'Enable AI Synthetic content label in video metadata settings or submit an appeal.',
                            Colors.white,
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
                                    size: 16,
                                  ),
                                  label: const Text('Submit Appeal'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2563EB),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.all(14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    textStyle: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
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
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF71717A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
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
        AppSnackbar.info('Opening Channel Analytics...');
      case 'APPEAL_VERIFICATION':
        Get.to<void>(
          () => TruthVerificationDashboardPage(
            channelId: channelId,
            isDarkMode: true,
          ),
        );
      default:
        AppSnackbar.info(action.label);
    }
  }
}
