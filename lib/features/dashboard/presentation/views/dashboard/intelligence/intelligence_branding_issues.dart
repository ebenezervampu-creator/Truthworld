import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/creator_intelligence_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/customization_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/intelligence/intelligence_issue_card.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Helper builders for channel avatar and banner verification status notices.
class IntelligenceBrandingIssues {
  static List<Widget> buildAvatarIssues({
    required Channel ch,
    required CreatorIntelligenceController controller,
    required String channelId,
    required String creatorId,
  }) {
    final issueCards = <Widget>[];

    if (ch.avatarStatus == 'REJECTED') {
      issueCards.add(
        IntelligenceIssueCard(
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
              icon: const Icon(
                Icons.edit_rounded,
                color: Colors.white,
                size: 15,
              ),
              label: const Text('Change Avatar'),
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
            OutlinedButton.icon(
              onPressed: controller.requestAvatarManualReview,
              icon: const Icon(
                Icons.rate_review_rounded,
                color: Colors.white,
                size: 15,
              ),
              label: const Text('Request Manual Review'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: AppColors.bgDivider),
                backgroundColor: AppColors.bgSurfaceHover,
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
            TextButton.icon(
              onPressed: controller.bypassAvatarVerification,
              icon: const Icon(
                Icons.flash_on_rounded,
                color: Colors.white,
                size: 15,
              ),
              label: const Text('Bypass (Debug)'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                textStyle: const TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontFamilyFallback: TWTypography.fallbackFamilies,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
    } else if (ch.avatarStatus == 'FLAGGED') {
      issueCards.add(
        IntelligenceIssueCard(
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
              icon: const Icon(
                Icons.edit_rounded,
                color: Colors.white,
                size: 15,
              ),
              label: const Text('Change Avatar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
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
            OutlinedButton.icon(
              onPressed: controller.requestAvatarManualReview,
              icon: const Icon(
                Icons.rate_review_rounded,
                color: Colors.white,
                size: 15,
              ),
              label: const Text('Request Manual Review'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: AppColors.bgDivider),
                backgroundColor: AppColors.bgSurfaceHover,
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
    } else if (ch.avatarStatus == 'MANUAL_REVIEW') {
      issueCards.add(
        const IntelligenceIssueCard(
          title: 'Avatar Under Manual Review',
          description:
              'Your avatar appeal has been received. Our moderation team is reviewing your image.',
          statusType: 'MANUAL_REVIEW',
          icon: Icons.rate_review_rounded,
        ),
      );
    } else if (ch.avatarStatus == 'PENDING') {
      issueCards.add(
        IntelligenceIssueCard(
          title: 'Avatar Verification Pending',
          description:
              'Google Vision AI is validating your channel avatar image.',
          statusType: 'PENDING',
          icon: Icons.sync_rounded,
          isLoading: true,
          actions: [
            TextButton.icon(
              onPressed: controller.bypassAvatarVerification,
              icon: const Icon(
                Icons.flash_on_rounded,
                color: Colors.white,
                size: 15,
              ),
              label: const Text('Bypass (Debug)'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                textStyle: const TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontFamilyFallback: TWTypography.fallbackFamilies,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return issueCards;
  }

  static List<Widget> buildBannerIssues({
    required Channel ch,
    required CreatorIntelligenceController controller,
    required String channelId,
    required String creatorId,
  }) {
    final issueCards = <Widget>[];

    if (ch.bannerStatus == 'REJECTED') {
      issueCards.add(
        IntelligenceIssueCard(
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
              icon: const Icon(
                Icons.edit_rounded,
                color: Colors.white,
                size: 15,
              ),
              label: const Text('Change Banner'),
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
            OutlinedButton.icon(
              onPressed: controller.requestBannerManualReview,
              icon: const Icon(
                Icons.rate_review_rounded,
                color: Colors.white,
                size: 15,
              ),
              label: const Text('Request Manual Review'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: AppColors.bgDivider),
                backgroundColor: AppColors.bgSurfaceHover,
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
            TextButton.icon(
              onPressed: controller.bypassBannerVerification,
              icon: const Icon(
                Icons.flash_on_rounded,
                color: Colors.white,
                size: 15,
              ),
              label: const Text('Bypass (Debug)'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                textStyle: const TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontFamilyFallback: TWTypography.fallbackFamilies,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
    } else if (ch.bannerStatus == 'FLAGGED') {
      issueCards.add(
        IntelligenceIssueCard(
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
              icon: const Icon(
                Icons.edit_rounded,
                color: Colors.white,
                size: 15,
              ),
              label: const Text('Change Banner'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
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
            OutlinedButton.icon(
              onPressed: controller.requestBannerManualReview,
              icon: const Icon(
                Icons.rate_review_rounded,
                color: Colors.white,
                size: 15,
              ),
              label: const Text('Request Manual Review'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: AppColors.bgDivider),
                backgroundColor: AppColors.bgSurfaceHover,
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
    } else if (ch.bannerStatus == 'MANUAL_REVIEW') {
      issueCards.add(
        const IntelligenceIssueCard(
          title: 'Banner Under Manual Review',
          description:
              'Your banner appeal has been received. Our moderation team is reviewing your image.',
          statusType: 'MANUAL_REVIEW',
          icon: Icons.rate_review_rounded,
        ),
      );
    } else if (ch.bannerStatus == 'PENDING') {
      issueCards.add(
        IntelligenceIssueCard(
          title: 'Banner Verification Pending',
          description:
              'Google Vision AI is validating your channel banner image.',
          statusType: 'PENDING',
          icon: Icons.sync_rounded,
          isLoading: true,
          actions: [
            TextButton.icon(
              onPressed: controller.bypassBannerVerification,
              icon: const Icon(
                Icons.flash_on_rounded,
                color: Colors.white,
                size: 15,
              ),
              label: const Text('Bypass (Debug)'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                textStyle: const TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontFamilyFallback: TWTypography.fallbackFamilies,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return issueCards;
  }
}
