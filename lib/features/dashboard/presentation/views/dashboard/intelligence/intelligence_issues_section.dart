import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/creator_intelligence_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/copyright_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/intelligence/intelligence_branding_issues.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/intelligence/intelligence_issue_card.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Container aggregating all Truthworld verification audits, channel status, and copyright notices.
class IntelligenceIssuesSection extends StatelessWidget {
  const IntelligenceIssuesSection({
    required this.controller,
    required this.channelId,
    required this.creatorId,
    super.key,
  });

  final CreatorIntelligenceController controller;
  final String channelId;
  final String creatorId;

  @override
  Widget build(BuildContext context) {
    final ch = controller.currentChannel.value;
    final copyrightCount = controller.copyrightClaimsCount.value;

    final issueCards = <Widget>[];

    // 1. Channel Moderation Status
    if (ch != null) {
      if (ch.status == ChannelStatus.verificationRejected) {
        issueCards.add(
          IntelligenceIssueCard(
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
                  color: Colors.white,
                  size: 15,
                ),
                label: const Text('Review Community Guidelines'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
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
                  ),
                ),
              ),
            ],
          ),
        );
      } else if (ch.status == ChannelStatus.underReview) {
        issueCards.add(
          const IntelligenceIssueCard(
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
      issueCards.addAll(
        IntelligenceBrandingIssues.buildAvatarIssues(
          ch: ch,
          controller: controller,
          channelId: channelId,
          creatorId: creatorId,
        ),
      );

      // 3. Banner Status
      issueCards.addAll(
        IntelligenceBrandingIssues.buildBannerIssues(
          ch: ch,
          controller: controller,
          channelId: channelId,
          creatorId: creatorId,
        ),
      );
    }

    // 4. Copyright Claims
    if (copyrightCount > 0) {
      issueCards.add(
        IntelligenceIssueCard(
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
                color: Colors.white,
                size: 15,
              ),
              label: const Text('View Copyright Details'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
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
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.5),
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
                  color: AppColors.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.4),
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
                        fontFamily: TWTypography.uiFamily,
                        fontFamilyFallback: TWTypography.fallbackFamilies,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                        color: AppColors.error,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Real-time verification flags, moderation notices & policy health',
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
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.bgDivider),
          const SizedBox(height: 16),
          ...issueCards,
        ],
      ),
    );
  }
}
