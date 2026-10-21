import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/channel_notifications_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Top header banner displaying screen title, description, unread counter, and mark-all-as-read button.
class ChannelNotificationsHeaderBanner extends StatelessWidget {
  const ChannelNotificationsHeaderBanner({
    required this.controller,
    super.key,
  });

  final ChannelNotificationsController controller;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    final titleSection = Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.bgDivider),
          ),
          child: const Icon(
            Icons.notifications_rounded,
            color: AppColors.textPrimary,
            size: 24,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Channel Notifications',
                style: TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  fontFamilyFallback: TWTypography.fallbackFamilies,
                  fontSize: isMobile ? 20 : 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Real-time channel milestones, updates & verification audits',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontFamilyFallback: TWTypography.fallbackFamilies,
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
      mainAxisAlignment:
          isMobile ? MainAxisAlignment.spaceBetween : MainAxisAlignment.end,
      children: [
        Obx(() {
          if (controller.unreadCount.value > 0) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.16),
                ),
              ),
              child: Text(
                '${controller.unreadCount.value} UNREAD',
                style: const TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontFamilyFallback: TWTypography.fallbackFamilies,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: AppColors.textPrimary,
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        }),
        OutlinedButton.icon(
          onPressed: () => ChannelNotificationsGuideModal.show(context),
          icon: const Icon(
            Icons.help_outline_rounded,
            size: 15,
            color: AppColors.textPrimary,
          ),
          label: const Text(
            'How it works',
            style: TextStyle(
              fontFamily: TWTypography.uiFamily,
              fontFamilyFallback: TWTypography.fallbackFamilies,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            side: const BorderSide(color: AppColors.bgDivider),
            backgroundColor: AppColors.bgSurface,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: controller.markAllAsRead,
          icon: const Icon(
            Icons.done_all_rounded,
            size: 16,
            color: AppColors.textPrimary,
          ),
          label: const Text(
            'Mark all as read',
            style: TextStyle(
              fontFamily: TWTypography.uiFamily,
              fontFamilyFallback: TWTypography.fallbackFamilies,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            side: const BorderSide(color: AppColors.bgDivider),
            backgroundColor: AppColors.bgSurface,
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
}

/// Horizontal category filter chips for channel notification categories.
class ChannelNotificationsFilterChips extends StatelessWidget {
  const ChannelNotificationsFilterChips({
    required this.controller,
    super.key,
  });

  final ChannelNotificationsController controller;

  static const List<Map<String, dynamic>> categories = [
    {'id': 'all', 'label': 'All Notifications', 'icon': Icons.clear_all_rounded},
    {
      'id': 'critical',
      'label': 'Critical & Policy',
      'icon': Icons.warning_amber_rounded,
    },
    {
      'id': 'verification',
      'label': 'Fact Verification',
      'icon': Icons.verified_user_rounded,
    },
    {
      'id': 'growth',
      'label': 'Milestones & Growth',
      'icon': Icons.emoji_events_rounded,
    },
    {
      'id': 'comments',
      'label': 'Comments',
      'icon': Icons.chat_bubble_outline_rounded,
    },
    {
      'id': 'subscribers',
      'label': 'Subscribers',
      'icon': Icons.people_outline_rounded,
    },
    {
      'id': 'videos',
      'label': 'Videos & Pipeline',
      'icon': Icons.video_library_rounded,
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

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
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
              showCheckmark: false,
              avatar: Icon(
                cat['icon']! as IconData,
                size: 15,
                color: isSelected ? Colors.black : AppColors.textSecondary,
              ),
              label: Text(
                cat['label']! as String,
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontFamilyFallback: TWTypography.fallbackFamilies,
                  color: isSelected ? Colors.black : AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  controller.selectedCategory.value = catId;
                }
              },
              selectedColor: Colors.white,
              backgroundColor: AppColors.bgSurface,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected
                      ? Colors.white
                      : AppColors.bgDivider,
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

/// Educational modal explaining how notifications, Review-First verification,
/// and channel standing work on TruthWorld.
class ChannelNotificationsGuideModal extends StatelessWidget {
  const ChannelNotificationsGuideModal({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ChannelNotificationsGuideModal(),
    );
  }

  Widget _buildPillarCard({
    required IconData icon,
    required String title,
    required String description,
    required Color iconColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurfaceHover,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.bgDivider),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontFamilyFallback: TWTypography.fallbackFamilies,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontFamilyFallback: TWTypography.fallbackFamilies,
                    fontSize: 12,
                    height: 1.45,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: AppColors.bgDivider)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.bgDivider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  const Text(
                    'Channel Notifications Guide',
                    style: TextStyle(
                      fontFamily: TWTypography.brandFamily,
                      fontFamilyFallback: TWTypography.fallbackFamilies,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.bgDivider),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildPillarCard(
                    icon: Icons.verified_user_rounded,
                    title: 'Creator Review First (Fact Verification)',
                    description:
                        'You are in full control! When we check facts in your video, only YOU can see the notes at first. Viewers cannot see anything until you review and click Approve.',
                    iconColor: const Color(0xFF34D399),
                  ),
                  _buildPillarCard(
                    icon: Icons.shield_outlined,
                    title: 'Zero Arbitrary Strikes & Channel Safety',
                    description:
                        'Your channel is 100% safe. If something needs a quick adjustment (like matching your language), it never counts as a strike. You can fix it anytime with zero stress.',
                    iconColor: const Color(0xFFFBBF24),
                  ),
                  _buildPillarCard(
                    icon: Icons.video_library_rounded,
                    title: 'Video Pipeline & Processing',
                    description:
                        'We prepare your video automatically so it looks crisp and sounds great on all devices. You get a quick ping as soon as it is live for everyone!',
                    iconColor: const Color(0xFF60A5FA),
                  ),
                  _buildPillarCard(
                    icon: Icons.emoji_events_rounded,
                    title: 'Milestones & Popular Videos',
                    description:
                        'Celebrate your wins! We alert you whenever you reach a new subscriber goal or when lots of people are watching and commenting on your video.',
                    iconColor: const Color(0xFFFBBF24),
                  ),
                  _buildPillarCard(
                    icon: Icons.auto_awesome_rounded,
                    title: 'AI Creator Coach',
                    description:
                        'Helpful, friendly tips tailored to your channel so you can make your videos even more engaging and fun for your audience.',
                    iconColor: const Color(0xFFA78BFA),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.bgSurface,
                border: Border(top: BorderSide(color: AppColors.bgDivider)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontFamilyFallback: TWTypography.fallbackFamilies,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  child: const Text('Got it'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

