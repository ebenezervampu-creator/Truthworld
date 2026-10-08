import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/customization_screen.dart';
import 'package:truthworld/theme/app_theme.dart';

class DashboardTruthworldIssuesNotice extends StatelessWidget {
  final bool isDarkMode;
  final Channel channel;
  final int copyrightClaimsCount;
  final VoidCallback onOpenIntelligence;

  const DashboardTruthworldIssuesNotice({
    required this.isDarkMode,
    required this.channel,
    required this.copyrightClaimsCount,
    required this.onOpenIntelligence,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final issues = <String>[];
    if (channel.status == ChannelStatus.verificationRejected) {
      issues.add('Branding Verification Rejected');
    } else if (channel.status == ChannelStatus.underReview) {
      issues.add('Branding Under Review');
    }

    if (channel.avatarStatus == 'REJECTED') {
      issues.add('Avatar Rejected');
    } else if (channel.avatarStatus == 'FLAGGED' ||
        channel.avatarStatus == 'MANUAL_REVIEW') {
      issues.add('Avatar Review Needed');
    }

    if (channel.bannerStatus == 'REJECTED') {
      issues.add('Banner Rejected');
    } else if (channel.bannerStatus == 'FLAGGED' ||
        channel.bannerStatus == 'MANUAL_REVIEW') {
      issues.add('Banner Review Needed');
    }

    if (copyrightClaimsCount > 0) {
      issues.add('$copyrightClaimsCount Copyright Claim(s)');
    }

    if (issues.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Truthworld Notices & Action Required',
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Active issues: ${issues.join(" • ")}. Review audit details, guideline feedback, and appeal options on the Creator Intelligence page.',
                  style: TextStyle(
                    color: isDarkMode
                        ? AppColors.textSecondary
                        : Colors.black87,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: onOpenIntelligence,
                  icon: const Icon(
                    Icons.insights_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  label: const Text('Open Creator Intelligence'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardImageVerificationBanner extends StatelessWidget {
  final bool isDarkMode;
  final Channel channel;
  final VoidCallback onOpenCustomization;

  const DashboardImageVerificationBanner({
    required this.isDarkMode,
    required this.channel,
    required this.onOpenCustomization,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final banners = <Widget>[];

    // Avatar status
    if (channel.avatarStatus == 'PENDING') {
      banners.add(
        DashboardVerificationAlertCard(
          isDarkMode: isDarkMode,
          title: 'Avatar Verification Pending',
          subtitle:
              'Google Vision AI is currently validating your channel avatar image. Creation is complete and your channel is fully accessible.',
          color: AppColors.info,
          icon: Icons.sync_rounded,
          isPending: true,
          onOpenCustomization: onOpenCustomization,
          onBypassPressed: () async {
            try {
              await FirebaseFirestore.instance
                  .collection(FirestoreCollections.channels)
                  .doc(channel.id)
                  .update({
                    'avatarStatus': 'APPROVED',
                    'avatarStatusReason':
                        'Bypassed in local/debug environment.',
                    'updatedAt': DateTime.now().millisecondsSinceEpoch,
                  });
              if (channel.avatarFileId != null &&
                  channel.avatarFileId!.isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('image_verification')
                    .doc(channel.avatarFileId)
                    .set({
                      'status': 'APPROVED',
                      'reason': 'Bypassed in local/debug environment.',
                      'category': 'avatar',
                      'processedAt': FieldValue.serverTimestamp(),
                    }, SetOptions(merge: true));
              }
              AppSnackbar.success('Avatar approved successfully.');
            } catch (e) {
              ErrorHandler.log(e);
              AppSnackbar.error('Unable to approve avatar. Please try again.');
            }
          },
        ),
      );
    } else if (channel.avatarStatus == 'REJECTED') {
      banners.add(
        DashboardVerificationAlertCard(
          isDarkMode: isDarkMode,
          title: 'Avatar Image Rejected',
          subtitle:
              'Your uploaded avatar image did not pass automated content verification guidelines. Change image or request a manual admin review if you believe it complies with guidelines.',
          color: AppColors.error,
          icon: Icons.error_outline_rounded,
          showCustomizationButton: true,
          onOpenCustomization: onOpenCustomization,
          onRequestManualReviewPressed: () async {
            try {
              await FirebaseFirestore.instance
                  .collection(FirestoreCollections.channels)
                  .doc(channel.id)
                  .update({
                    'avatarStatus': 'MANUAL_REVIEW',
                    'avatarStatusReason': 'User requested manual review.',
                    'updatedAt': DateTime.now().millisecondsSinceEpoch,
                  });
              AppSnackbar.success('Avatar queued for manual admin review.');
            } catch (e) {
              ErrorHandler.log(e, tag: 'DashboardScreen');
              AppSnackbar.error(
                'Unable to submit avatar for review. Please try again.',
              );
            }
          },
        ),
      );
    } else if (channel.avatarStatus == 'FLAGGED') {
      banners.add(
        DashboardVerificationAlertCard(
          isDarkMode: isDarkMode,
          title: 'Avatar Review Needed',
          subtitle:
              'Your avatar image was flagged for potential guidelines review. You may upload a new image or request manual admin review.',
          color: AppColors.warning,
          icon: Icons.warning_amber_rounded,
          showCustomizationButton: true,
          onOpenCustomization: onOpenCustomization,
          onRequestManualReviewPressed: () async {
            try {
              await FirebaseFirestore.instance
                  .collection(FirestoreCollections.channels)
                  .doc(channel.id)
                  .update({
                    'avatarStatus': 'MANUAL_REVIEW',
                    'avatarStatusReason': 'User requested manual review.',
                    'updatedAt': DateTime.now().millisecondsSinceEpoch,
                  });
              AppSnackbar.success('Avatar queued for manual admin review.');
            } catch (e) {
              ErrorHandler.log(e, tag: 'DashboardScreen');
              AppSnackbar.error(
                'Unable to submit avatar for review. Please try again.',
              );
            }
          },
        ),
      );
    } else if (channel.avatarStatus == 'MANUAL_REVIEW') {
      banners.add(
        DashboardVerificationAlertCard(
          isDarkMode: isDarkMode,
          title: 'Avatar Under Manual Review',
          subtitle:
              'Your avatar appeal has been received. Our moderation team is reviewing your image.',
          color: AppColors.info,
          icon: Icons.rate_review_rounded,
          onOpenCustomization: onOpenCustomization,
        ),
      );
    }

    // Banner status
    if (channel.bannerStatus == 'PENDING') {
      banners.add(
        DashboardVerificationAlertCard(
          isDarkMode: isDarkMode,
          title: 'Banner Verification Pending',
          subtitle:
              'Google Vision AI is currently validating your channel banner image. Creation is complete and your channel is fully accessible.',
          color: AppColors.info,
          icon: Icons.sync_rounded,
          isPending: true,
          onOpenCustomization: onOpenCustomization,
          onBypassPressed: () async {
            try {
              await FirebaseFirestore.instance
                  .collection(FirestoreCollections.channels)
                  .doc(channel.id)
                  .update({
                    'bannerStatus': 'APPROVED',
                    'bannerStatusReason':
                        'Bypassed in local/debug environment.',
                    'updatedAt': DateTime.now().millisecondsSinceEpoch,
                  });
              if (channel.bannerFileId != null &&
                  channel.bannerFileId!.isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('image_verification')
                    .doc(channel.bannerFileId)
                    .set({
                      'status': 'APPROVED',
                      'reason': 'Bypassed in local/debug environment.',
                      'category': 'banner',
                      'processedAt': FieldValue.serverTimestamp(),
                    }, SetOptions(merge: true));
              }
              AppSnackbar.success('Banner approved successfully.');
            } catch (e) {
              ErrorHandler.log(e);
              AppSnackbar.error('Unable to approve banner. Please try again.');
            }
          },
        ),
      );
    } else if (channel.bannerStatus == 'REJECTED') {
      banners.add(
        DashboardVerificationAlertCard(
          isDarkMode: isDarkMode,
          title: 'Banner Image Rejected',
          subtitle:
              'Your uploaded banner image did not pass automated content verification guidelines. Change image or request a manual admin review if you believe it complies with guidelines.',
          color: AppColors.error,
          icon: Icons.error_outline_rounded,
          showCustomizationButton: true,
          onOpenCustomization: onOpenCustomization,
          onRequestManualReviewPressed: () async {
            try {
              await FirebaseFirestore.instance
                  .collection(FirestoreCollections.channels)
                  .doc(channel.id)
                  .update({
                    'bannerStatus': 'MANUAL_REVIEW',
                    'bannerStatusReason': 'User requested manual review.',
                    'updatedAt': DateTime.now().millisecondsSinceEpoch,
                  });
              AppSnackbar.success('Banner queued for manual admin review.');
            } catch (e) {
              ErrorHandler.log(e, tag: 'DashboardScreen');
              AppSnackbar.error(
                'Unable to submit banner for review. Please try again.',
              );
            }
          },
        ),
      );
    } else if (channel.bannerStatus == 'FLAGGED') {
      banners.add(
        DashboardVerificationAlertCard(
          isDarkMode: isDarkMode,
          title: 'Banner Review Needed',
          subtitle:
              'Your banner image was flagged for potential guidelines review. You may upload a new image or request manual admin review.',
          color: AppColors.warning,
          icon: Icons.warning_amber_rounded,
          showCustomizationButton: true,
          onOpenCustomization: onOpenCustomization,
          onRequestManualReviewPressed: () async {
            try {
              await FirebaseFirestore.instance
                  .collection(FirestoreCollections.channels)
                  .doc(channel.id)
                  .update({
                    'bannerStatus': 'MANUAL_REVIEW',
                    'bannerStatusReason': 'User requested manual review.',
                    'updatedAt': DateTime.now().millisecondsSinceEpoch,
                  });
              AppSnackbar.success('Banner queued for manual admin review.');
            } catch (e) {
              ErrorHandler.log(e, tag: 'DashboardScreen');
              AppSnackbar.error(
                'Unable to submit banner for review. Please try again.',
              );
            }
          },
        ),
      );
    } else if (channel.bannerStatus == 'MANUAL_REVIEW') {
      banners.add(
        DashboardVerificationAlertCard(
          isDarkMode: isDarkMode,
          title: 'Banner Under Manual Review',
          subtitle:
              'Your banner appeal has been received. Our moderation team is reviewing your image.',
          color: AppColors.info,
          icon: Icons.rate_review_rounded,
          onOpenCustomization: onOpenCustomization,
        ),
      );
    }

    if (banners.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: banners,
    );
  }
}

class DashboardVerificationAlertCard extends StatelessWidget {
  final bool isDarkMode;
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;
  final bool isPending;
  final bool showCustomizationButton;
  final VoidCallback? onBypassPressed;
  final VoidCallback? onRequestManualReviewPressed;
  final VoidCallback? onOpenCustomization;

  const DashboardVerificationAlertCard({
    required this.isDarkMode,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
    this.isPending = false,
    this.showCustomizationButton = false,
    this.onBypassPressed,
    this.onRequestManualReviewPressed,
    this.onOpenCustomization,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isPending)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.brand),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shield_outlined,
                color: Colors.white,
                size: 24,
              ),
            ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isDarkMode ? AppColors.textSecondary : Colors.black,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                if (showCustomizationButton ||
                    onRequestManualReviewPressed != null) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (showCustomizationButton)
                        ElevatedButton.icon(
                          onPressed: onOpenCustomization,
                          icon: const Icon(
                            Icons.color_lens_outlined,
                            size: 16,
                            color: Colors.white,
                          ),
                          label: const Text('Change Image'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: color,
                            foregroundColor: AppColors.textPrimary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                        ),
                      if (onRequestManualReviewPressed != null)
                        OutlinedButton.icon(
                          onPressed: onRequestManualReviewPressed,
                          icon: const Icon(
                            Icons.rate_review_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                          label: const Text('Request Manual Review'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDarkMode
                                ? AppColors.textPrimary
                                : Colors.black,
                            side: BorderSide(
                              color: color,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                if (isPending && onBypassPressed != null) ...[
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: onBypassPressed,
                    icon: const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: const Text('Bypass Verification (Local Dev/Test)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: AppColors.textPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardModerationStatusBanner extends StatelessWidget {
  final bool isDarkMode;
  final Channel channel;

  const DashboardModerationStatusBanner({
    required this.isDarkMode,
    required this.channel,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (channel.status == ChannelStatus.active ||
        channel.geminiApproved == true) {
      return const SizedBox.shrink();
    }

    Color bannerColor;
    IconData icon;
    String title;
    String subtitle;
    var showButton = false;

    if (channel.status == ChannelStatus.underReview) {
      bannerColor = AppColors.info;
      icon = Icons.sync_rounded;
      title = 'Branding Under Verification System Review';
      subtitle =
          'Our Verification System is checking your channel details (name, description, tags) against our community guidelines. This usually takes just a few seconds.';
    } else if (channel.status == ChannelStatus.verificationRejected) {
      bannerColor = AppColors.error;
      icon = Icons.error_outline_rounded;
      title = 'Branding Verification Rejected';
      subtitle = channel.moderationReason != null &&
              channel.moderationReason!.isNotEmpty
          ? 'Verification System Response: ${channel.moderationReason}'
          : 'Your channel details did not pass verification. Please update your channel description and resubmit.';
      showButton = true;
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bannerColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: bannerColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (channel.status == ChannelStatus.underReview)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.brand),
              ),
            )
          else
            Icon(icon, color: Colors.white, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: bannerColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isDarkMode ? AppColors.textSecondary : Colors.black,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                if (showButton) ...[
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      Get.to<void>(
                        () => ChannelCustomizationPage(
                          channelId: channel.id,
                          ownerId: channel.ownerId,
                          // Basic Info tab (index 1) — where description lives
                          initialTabIndex: 1,
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.edit_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: const Text('Edit Channel Description'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: bannerColor,
                      foregroundColor: AppColors.textPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardApprovalBanner extends StatelessWidget {
  final bool isDarkMode;
  final VoidCallback onDismiss;

  const DashboardApprovalBanner({
    required this.isDarkMode,
    required this.onDismiss,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    const bannerColor = AppColors.success;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bannerColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: bannerColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            color: Colors.white,
            size: 28,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Branding Approved by Verification System!',
                  style: TextStyle(
                    color: bannerColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Congratulations! Your channel details are approved. You can now customize your channel and upload videos.',
                  style: TextStyle(
                    color: isDarkMode ? AppColors.textSecondary : Colors.black,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
