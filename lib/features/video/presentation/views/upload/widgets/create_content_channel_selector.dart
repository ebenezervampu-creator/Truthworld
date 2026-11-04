import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/customization_screen.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Card displayed when upload is blocked due to channel status (e.g. under review, rejected, suspended).
class CreateContentBlockedUploadCard extends StatelessWidget {
  const CreateContentBlockedUploadCard({
    required this.channel,
    super.key,
  });

  final Channel channel;

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    IconData icon;
    String title;
    String subtitle;
    var showButton = false;

    if (channel.status == ChannelStatus.underReview) {
      statusColor = context.colors.info;
      icon = Icons.sync_rounded;
      title = 'Branding Under Moderation';
      subtitle =
          'Your channel details are currently under review by our Verification System. You can publish videos once approved.';
    } else if (channel.status == ChannelStatus.verificationRejected) {
      statusColor = context.colors.error;
      icon = Icons.error_outline_rounded;
      title = 'Branding Verification Rejected';
      subtitle =
          channel.moderationReason != null &&
              channel.moderationReason!.isNotEmpty
          ? channel.moderationReason!
          : 'Your channel details did not pass verification. Please update your channel description to resubmit.';
      showButton = true;
    } else if (channel.status == ChannelStatus.verificationPending) {
      statusColor = context.colors.warning;
      icon = Icons.hourglass_empty_rounded;
      title = 'Verification Pending';
      subtitle =
          'Your channel is currently verification pending. You can publish videos once your branding is verified.';
    } else if (channel.status == ChannelStatus.suspended) {
      statusColor = context.colors.error;
      icon = Icons.gavel_rounded;
      title = 'Channel Suspended';
      subtitle =
          'Your channel has been suspended for policy violations. Publishing is disabled.';
    } else if (channel.status == ChannelStatus.onHold) {
      statusColor = context.colors.warning;
      icon = Icons.pause_circle_outline_rounded;
      title = 'Channel On Hold';
      subtitle = channel.moderationReason != null && channel.moderationReason!.isNotEmpty
          ? channel.moderationReason!
          : 'Your channel is currently on hold. Publishing is temporarily disabled.';
    } else {
      statusColor = context.colors.textDisabled;
      icon = Icons.info_outline_rounded;
      title = 'Upload Disabled';
      subtitle = 'Publishing is currently disabled for this channel.';
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 500),
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: context.radius.lg,
        border: Border.all(
          color: context.colors.divider,
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: channel.status == ChannelStatus.underReview
                  ? SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        strokeWidth: 3.5,
                        valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                      ),
                    )
                  : Icon(
                      icon,
                      size: 40,
                      color: statusColor,
                    ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            textAlign: TextAlign.center,
            style: context.themeTypography.headline,
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: context.themeTypography.body.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
          if (showButton) ...[
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () {
                Get.to<void>(
                  () => ChannelCustomizationPage(
                    channelId: channel.id,
                    ownerId: channel.ownerId,
                    // Basic Info tab (index 1) — description is the rejection cause
                    initialTabIndex: 1,
                  ),
                );
              },
              icon: const Icon(
                Icons.edit_rounded,
                size: 20,
                color: AppColors.textPrimary,
              ),
              label: Text(
                'Edit Channel Description',
                style: context.themeTypography.button,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: statusColor,
                foregroundColor: AppColors.textPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 16,
                ),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Card displayed when the user does not have any channels created yet.
class CreateContentNoChannelsCard extends StatelessWidget {
  const CreateContentNoChannelsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: context.radius.lg,
        border: Border.all(
          color: context.colors.divider,
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.colors.error.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.colors.error.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.video_library_outlined,
                size: 40,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Channels Yet',
            style: context.themeTypography.headline.copyWith(
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Create your first channel to start\nuploading amazing content',
            textAlign: TextAlign.center,
            style: context.themeTypography.body.copyWith(
              color: context.colors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: () => Get.toNamed('/channelscreen'),
            icon: const Icon(
              Icons.add_circle_outline,
              size: 20,
              color: Colors.black,
            ),
            label: Text(
              'Create Channel',
              style: context.themeTypography.button.copyWith(
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.brand,
              foregroundColor: Colors.black,
              iconColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Channel selector / status widget used across create content upload flows.
class CreateContentChannelSelector extends StatelessWidget {
  const CreateContentChannelSelector({
    super.key,
    this.uploadController,
    this.isDark = true,
  });

  final UploadController? uploadController;
  final bool isDark;

  UploadController get _controller =>
      uploadController ?? Get.find<UploadController>();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Show loading state
      if (_controller.isChannelsLoading.value) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161B22) : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? const Color(0xFF30363D) : const Color(0xFFE5E7EB),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isDark ? AppColors.textPrimary : const Color(0xFF6366F1),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Loading channels...',
                style: context.themeTypography.body.copyWith(
                  color: isDark
                      ? AppColors.textSecondary
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        );
      }

      // Show error state
      if (_controller.channelsError.value.isNotEmpty) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFEF4444).withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 20,
                    color: Color(0xFFEF4444),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _controller.channelsError.value,
                      style: context.themeTypography.body.copyWith(
                        color: const Color(0xFFEF4444),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _controller.fetchChannelsWithRetry,
                  icon: const Icon(
                    Icons.refresh_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: AppColors.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }

      // Show empty channels state
      if (_controller.channels.isEmpty) {
        final authChannel = AuthService.to.userChannel;
        if (authChannel != null && authChannel.status != ChannelStatus.deleted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_controller.channels.isEmpty) {
              _controller.channels.value = [authChannel];
              _controller.selectedChannel.value = authChannel;
            }
          });
          return const SizedBox.shrink();
        }
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161B22) : AppColors.textPrimary,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? const Color(0xFF30363D) : const Color(0xFFE5E7EB),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.video_library_outlined,
                size: 32,
                color: Colors.white,
              ),
              const SizedBox(height: 12),
              Text(
                'No Channels Yet',
                style: context.themeTypography.title.copyWith(
                  color: isDark
                      ? AppColors.textPrimary
                      : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Create a channel to start uploading',
                style: context.themeTypography.bodySmall.copyWith(
                  color: isDark
                      ? AppColors.textSecondary
                      : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Get.toNamed('/channelscreen'),
                  icon: const Icon(
                    Icons.add_circle_outline,
                    size: 18,
                    color: Colors.white,
                  ),
                  label: const Text('Create Channel'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: AppColors.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }

      // Show selected channel as info (non-interactive)
      final channel = _controller.selectedChannel.value;
      if (channel == null) return const SizedBox.shrink();

      final isStandard = channel.channelType == ChannelType.standard;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161B22) : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? const Color(0xFF30363D) : const Color(0xFFE5E7EB),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                UserAvatar(
                  radius: 14,
                  photoUrl: channel.avatarUrl,
                  displayName: channel.channelName,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        channel.channelName,
                        style: context.themeTypography.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.textPrimary
                              : const Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        channel.status == ChannelStatus.active
                            ? (isStandard
                                ? 'Standard Channel (20m/day limit)'
                                : 'Pro Channel (Unlimited)')
                            : channel.status == ChannelStatus.underReview
                            ? 'Under Review'
                            : channel.status == ChannelStatus.verificationRejected
                            ? 'Rejected'
                            : channel.status == ChannelStatus.verificationPending
                            ? 'Pending Verification'
                            : channel.status == ChannelStatus.onHold
                            ? 'On Hold'
                            : 'Suspended',
                        style: context.themeTypography.label.copyWith(
                          color: channel.status == ChannelStatus.active
                              ? (isDark ? AppColors.textTertiary : Colors.black45)
                              : channel.status == ChannelStatus.underReview
                              ? const Color(0xFF3B82F6)
                              : channel.status == ChannelStatus.verificationRejected
                              ? const Color(0xFFEF4444)
                              : const Color(0xFFF59E0B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (isStandard) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0D1117)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _controller.isDailyLimitReached.value
                        ? const Color(0xFFEF4444).withValues(alpha: 0.5)
                        : (isDark
                            ? const Color(0xFF21262D)
                            : const Color(0xFFE5E7EB)),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.timelapse_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Daily Upload Limit',
                              style: context.themeTypography.label.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.textPrimary
                                    : const Color(0xFF374151),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _controller.isDailyLimitReached.value
                                ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                                : const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _controller.isDailyLimitReached.value
                                ? 'Limit Reached (0m left)'
                                : '${_controller.remainingDailyDurationFormatted} remaining',
                            style: context.themeTypography.label.copyWith(
                              fontSize: 11,
                              color: _controller.isDailyLimitReached.value
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF10B981),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _controller.dailyQuotaUsedRatio,
                        minHeight: 6,
                        backgroundColor: isDark
                            ? const Color(0xFF21262D)
                            : const Color(0xFFE5E7EB),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _controller.isDailyLimitReached.value
                              ? const Color(0xFFEF4444)
                              : (_controller.dailyQuotaUsedRatio > 0.75
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFF6366F1)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_controller.todayUploadedDurationFormatted} / ${ContentValidationMixin.formatDurationMinutesSeconds(channel.maxDailyVideoDurationSeconds)} used today',
                          style: context.themeTypography.bodySmall.copyWith(
                            color: isDark
                                ? AppColors.textTertiary
                                : const Color(0xFF6B7280),
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          'Resets daily at 00:00',
                          style: context.themeTypography.bodySmall.copyWith(
                            color: isDark
                                ? AppColors.textTertiary
                                : const Color(0xFF6B7280),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    });
  }
}
