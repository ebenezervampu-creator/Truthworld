import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/channel_notifications_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/copyright_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/notifications/notifications_branding_issues.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/notifications/notifications_issue_card.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification_dashboard_page.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Container aggregating all Truthworld verification audits, channel status, and copyright notices.
class ChannelNotificationsIssuesSection extends StatelessWidget {
  const ChannelNotificationsIssuesSection({
    required this.controller,
    required this.channelId,
    required this.creatorId,
    super.key,
  });

  final ChannelNotificationsController controller;
  final String channelId;
  final String creatorId;

  Widget _buildStandingBanner(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    final content = Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.bgSurfaceHover,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.bgDivider),
          ),
          child: const Icon(
            Icons.verified_rounded,
            color: Color(0xFF34D399),
            size: 20,
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Channel in Good Standing',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontFamilyFallback: TWTypography.fallbackFamilies,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Channel details, branding, and uploads are verified by Truthworld.',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontFamilyFallback: TWTypography.fallbackFamilies,
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final action = ElevatedButton.icon(
      onPressed: () => Get.toNamed('/upload'),
      icon: const Icon(
        Icons.video_call_rounded,
        color: Colors.black,
        size: 16,
      ),
      label: const Text('Upload Video'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(
          fontFamily: TWTypography.uiFamily,
          fontFamilyFallback: TWTypography.fallbackFamilies,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                content,
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerRight, child: action),
              ],
            )
          : Row(
              children: [
                Expanded(child: content),
                const SizedBox(width: 16),
                action,
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ch = controller.currentChannel.value;
    final copyrightCount = controller.copyrightClaimsCount.value;
    final selectedCategory = controller.selectedCategory.value;

    final urgentCards = <Widget>[];
    final inProgressCards = <Widget>[];

    final isFullyApproved = ch != null &&
        (ch.status == ChannelStatus.active || ch.geminiApproved == true) &&
        (ch.avatarStatus == 'APPROVED' || ch.avatarStatus == null || ch.avatarStatus!.isEmpty) &&
        (ch.bannerStatus == 'APPROVED' || ch.bannerStatus == null || ch.bannerStatus!.isEmpty) &&
        ch.infraConfig?.isWithdrawalHeld != true;

    // 1. Channel Moderation & Verification Status
    if (ch != null) {
      if (ch.status == ChannelStatus.verificationRejected) {
        urgentCards.add(
          ChannelNotificationsIssueCard(
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
                icon: const Icon(
                  Icons.description_outlined,
                  color: Colors.black,
                  size: 15,
                ),
                label: const Text('Review Community Guidelines'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontFamilyFallback: TWTypography.fallbackFamilies,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        );
      } else if (ch.status == ChannelStatus.underReview ||
          ch.status == ChannelStatus.verificationPending) {
        inProgressCards.add(
          const ChannelNotificationsIssueCard(
            title: 'Channel Branding Under Verification Review',
            description:
                'Truthworld Verification System is currently evaluating your channel details against community guidelines.',
            statusType: 'PENDING',
            icon: Icons.sync_rounded,
            isLoading: true,
          ),
        );
      } else if (ch.status == ChannelStatus.suspended) {
        urgentCards.add(
          ChannelNotificationsIssueCard(
            title: 'Channel Suspended by Truthworld',
            description: ch.moderationReason != null &&
                    ch.moderationReason!.isNotEmpty
                ? 'Truthworld Moderation Reason: ${ch.moderationReason}'
                : 'Your channel has been suspended due to violations of Truthworld Community Guidelines.',
            statusType: 'REJECTED',
            icon: Icons.block_rounded,
          ),
        );
      }

      if (ch.infraConfig?.isWithdrawalHeld == true) {
        urgentCards.add(
          ChannelNotificationsIssueCard(
            title: 'Creator Payouts On Hold by Truthworld',
            description: ch.infraConfig!.withdrawalHoldReason.isNotEmpty
                ? ch.infraConfig!.withdrawalHoldReason
                : 'Creator earnings withdrawals are temporarily paused for review by Truthworld Trust & Safety.',
            statusType: 'FLAGGED',
            icon: Icons.pause_circle_outline_rounded,
          ),
        );
      }

      // 2. Avatar Status
      if (ch.avatarStatus == 'REJECTED' || ch.avatarStatus == 'FLAGGED') {
        urgentCards.addAll(
          ChannelNotificationsBrandingIssues.buildAvatarIssues(
            ch: ch,
            controller: controller,
            channelId: channelId,
            creatorId: creatorId,
          ),
        );
      } else if (ch.avatarStatus == 'MANUAL_REVIEW' || ch.avatarStatus == 'PENDING') {
        inProgressCards.addAll(
          ChannelNotificationsBrandingIssues.buildAvatarIssues(
            ch: ch,
            controller: controller,
            channelId: channelId,
            creatorId: creatorId,
          ),
        );
      }

      // 3. Banner Status
      if (ch.bannerStatus == 'REJECTED' || ch.bannerStatus == 'FLAGGED') {
        urgentCards.addAll(
          ChannelNotificationsBrandingIssues.buildBannerIssues(
            ch: ch,
            controller: controller,
            channelId: channelId,
            creatorId: creatorId,
          ),
        );
      } else if (ch.bannerStatus == 'MANUAL_REVIEW' || ch.bannerStatus == 'PENDING') {
        inProgressCards.addAll(
          ChannelNotificationsBrandingIssues.buildBannerIssues(
            ch: ch,
            controller: controller,
            channelId: channelId,
            creatorId: creatorId,
          ),
        );
      }
    }

    // 4. Copyright Claims
    if (copyrightCount > 0) {
      urgentCards.add(
        ChannelNotificationsIssueCard(
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
              icon: const Icon(
                Icons.shield_rounded,
                color: Colors.black,
                size: 15,
              ),
              label: const Text('View Copyright Details'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontFamilyFallback: TWTypography.fallbackFamilies,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 5. Rejected Channel Videos (Language Policy or Moderation)
    for (final v in controller.rejectedVideos) {
      urgentCards.add(
        ChannelNotificationsIssueCard(
          title: v.isLanguageRejection
              ? 'Video Not Accepted (Language Policy): "${v.title}"'
              : 'Video Moderation Rejected: "${v.title}"',
          description: v.isLanguageRejection
              ? '${v.reason}\nDetected Language: ${v.detectedLanguage.toUpperCase()}'
              : v.reason,
          statusType: 'REJECTED',
          icon: v.isLanguageRejection
              ? Icons.translate_rounded
              : Icons.videocam_off_rounded,
          actions: [
            ElevatedButton.icon(
              onPressed: () {
                if (Get.isRegistered<DashboardController>()) {
                  Get.find<DashboardController>().setSelectedIndex(2);
                } else {
                  Get.toNamed('/studio');
                }
              },
              icon: const Icon(
                Icons.video_library_rounded,
                color: Colors.black,
                size: 15,
              ),
              label: const Text('Manage in Videos'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontFamilyFallback: TWTypography.fallbackFamilies,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => Get.toNamed('/upload'),
              icon: const Icon(
                Icons.upload_rounded,
                color: AppColors.textPrimary,
                size: 15,
              ),
              label: const Text('Upload Video'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                backgroundColor: AppColors.bgSurfaceHover,
                side: const BorderSide(color: AppColors.bgDivider),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontFamilyFallback: TWTypography.fallbackFamilies,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 6. Videos Held for Manual Verification Review
    for (final v in controller.manualReviewVideos) {
      urgentCards.add(
        ChannelNotificationsIssueCard(
          title: 'Video Held for Manual Review: "${v.title}"',
          description:
              '${v.reason}\nOur Trust & Safety team is reviewing this video and will notify your channel once approved.',
          statusType: 'MANUAL_REVIEW',
          icon: Icons.policy_rounded,
          actions: [
            OutlinedButton.icon(
              onPressed: () {
                if (Get.isRegistered<DashboardController>()) {
                  Get.find<DashboardController>().setSelectedIndex(2);
                } else {
                  Get.toNamed('/studio');
                }
              },
              icon: const Icon(
                Icons.video_library_rounded,
                color: AppColors.textPrimary,
                size: 15,
              ),
              label: const Text('View in Videos'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                backgroundColor: AppColors.bgSurfaceHover,
                side: const BorderSide(color: AppColors.bgDivider),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontFamilyFallback: TWTypography.fallbackFamilies,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 7. Failed / Interrupted Video Pipeline Jobs
    for (final v in controller.failedVideos) {
      urgentCards.add(
        ChannelNotificationsIssueCard(
          title: 'Video Processing Interrupted: "${v.title}"',
          description: v.reason,
          statusType: 'FLAGGED',
          icon: Icons.sync_problem_rounded,
          actions: [
            OutlinedButton.icon(
              onPressed: () {
                if (Get.isRegistered<DashboardController>()) {
                  Get.find<DashboardController>().setSelectedIndex(2);
                } else {
                  Get.toNamed('/studio');
                }
              },
              icon: const Icon(
                Icons.video_library_rounded,
                color: AppColors.textPrimary,
                size: 15,
              ),
              label: const Text('Manage in Videos'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                backgroundColor: AppColors.bgSurfaceHover,
                side: const BorderSide(color: AppColors.bgDivider),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontFamilyFallback: TWTypography.fallbackFamilies,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 8. Disputed Fact-Checks Re-Evaluating
    for (final v in controller.disputedVideos) {
      inProgressCards.add(
        ChannelNotificationsIssueCard(
          title: 'Fact-Check Appeal In Progress: "${v.title}"',
          description: v.reason,
          statusType: 'PENDING',
          icon: Icons.fact_check_rounded,
          isLoading: true,
          actions: [
            OutlinedButton.icon(
              onPressed: () {
                TruthVerificationDashboardPage.targetVideoId.value = v.id;
                if (Get.isRegistered<DashboardController>()) {
                  Get.find<DashboardController>().setSelectedIndex(15);
                } else {
                  Get.to<void>(
                    () => TruthVerificationDashboardPage(
                      channelId: channelId,
                      isDarkMode: true,
                      initialVideoId: v.id,
                    ),
                  );
                }
              },
              icon: const Icon(
                Icons.fact_check_rounded,
                color: AppColors.textPrimary,
                size: 15,
              ),
              label: const Text('View Fact-Checks Tab'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                backgroundColor: AppColors.bgSurfaceHover,
                side: const BorderSide(color: AppColors.bgDivider),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontFamilyFallback: TWTypography.fallbackFamilies,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 9. Videos Currently Undergoing Verification & Processing
    for (final v in controller.processingVideos) {
      inProgressCards.add(
        ChannelNotificationsIssueCard(
          title: 'Video Verification & Processing Active: "${v.title}"',
          description: v.reason,
          statusType: 'PENDING',
          icon: Icons.hourglass_top_rounded,
          isLoading: true,
          actions: [
            OutlinedButton.icon(
              onPressed: () {
                if (Get.isRegistered<DashboardController>()) {
                  Get.find<DashboardController>().setSelectedIndex(2);
                } else {
                  Get.toNamed('/studio');
                }
              },
              icon: const Icon(
                Icons.video_library_rounded,
                color: AppColors.textPrimary,
                size: 15,
              ),
              label: const Text('Track in Videos'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                backgroundColor: AppColors.bgSurfaceHover,
                side: const BorderSide(color: AppColors.bgDivider),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontFamilyFallback: TWTypography.fallbackFamilies,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final children = <Widget>[];

    // Show standing banner if fully approved and not filtered to critical only
    if (isFullyApproved && selectedCategory != 'critical') {
      children.add(_buildStandingBanner(context));
    }

    // Render Urgent Action Required section if any
    if (urgentCards.isNotEmpty) {
      children.add(
        Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.error.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.bgSurfaceHover,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFF87171),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ACTION REQUIRED',
                          style: TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            fontFamilyFallback: TWTypography.fallbackFamilies,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                            color: Color(0xFFF87171),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Items requiring your review or attention',
                          style: TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            fontFamilyFallback: TWTypography.fallbackFamilies,
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: AppColors.bgDivider),
              const SizedBox(height: 14),
              ...urgentCards,
            ],
          ),
        ),
      );
    }

    // Render in-progress items if any
    if (inProgressCards.isNotEmpty && selectedCategory != 'critical') {
      children.addAll(inProgressCards);
    }

    if (children.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}
