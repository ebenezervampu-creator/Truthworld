import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Screen displayed when a creator opens Creator Studio with a channel scheduled for deletion.
/// Displays a clear 30-day grace period countdown and provides a one-click action to cancel
/// channel deletion and restore the channel, or notifies that 30 days have elapsed.
class ChannelDeletionGracePeriodPage extends StatelessWidget {
  const ChannelDeletionGracePeriodPage({
    required this.channel,
    required this.onCancelDeletion,
    required this.onSignOut,
    this.isRestoring = false,
    super.key,
  });

  final Channel channel;
  final Future<void> Function() onCancelDeletion;
  final VoidCallback onSignOut;
  final bool isRestoring;

  @override
  Widget build(BuildContext context) {
    final isExpired = channel.isPermanentDeletionExpired;
    final remainingDays = channel.gracePeriodDaysRemaining;
    final scheduledDate = channel.scheduledPermanentDeletionDate;
    final formattedDate = DateFormat('MMMM d, yyyy').format(scheduledDate);
    final elapsedDays = (30 - remainingDays).clamp(0, 30);
    final progress = (elapsedDays / 30.0).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        backgroundColor: AppColors.bgSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.brand,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'STUDIO',
                style: TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'TruthWorld Creator Studio',
              style: TextStyle(
                fontFamily: TWTypography.brandFamily,
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              onSignOut();
            },
            icon: const Icon(
              Icons.logout_rounded,
              color: AppColors.textSecondary,
              size: 18,
            ),
            label: const Text(
              'Sign Out',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Top status icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: isExpired
                        ? AppColors.error.withValues(alpha: 0.15)
                        : AppColors.warning.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isExpired ? AppColors.error : AppColors.warning,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      isExpired
                          ? Icons.delete_forever_rounded
                          : Icons.hourglass_top_rounded,
                      color: isExpired ? AppColors.error : AppColors.warning,
                      size: 40,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Main headline
                Text(
                  isExpired
                      ? 'Channel Deletion Completed'
                      : 'Channel Scheduled for Deletion',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: TWTypography.brandFamily,
                    color: AppColors.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 10),

                // Subtitle
                Text(
                  isExpired
                      ? 'The 30-day grace period has expired. This channel and its contents were permanently deleted.'
                      : 'Your channel has been deleted and is currently in a 30-day grace period. You can cancel the deletion and restore full access anytime before it is deleted completely.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),

                // Channel Identity Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.bgDivider),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.bgSurfaceHover,
                        backgroundImage: channel.avatarUrl.isNotEmpty
                            ? NetworkImage(channel.avatarUrl)
                            : null,
                        child: channel.avatarUrl.isEmpty
                            ? const Icon(
                                Icons.person_rounded,
                                color: Colors.white,
                                size: 30,
                              )
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              channel.name,
                              style: const TextStyle(
                                fontFamily: TWTypography.brandFamily,
                                color: AppColors.textPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              channel.handle,
                              style: const TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isExpired
                              ? AppColors.error.withValues(alpha: 0.15)
                              : AppColors.warning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isExpired ? 'Deleted' : 'Pending Deletion',
                          style: TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            color: isExpired
                                ? AppColors.error
                                : AppColors.warning,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Grace Period Progress Card
                if (!isExpired) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.bgSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.bgDivider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              '30-Day Grace Period',
                              style: TextStyle(
                                fontFamily: TWTypography.brandFamily,
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '$remainingDays days left',
                                style: const TextStyle(
                                  fontFamily: TWTypography.uiFamily,
                                  color: AppColors.warning,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 8,
                            backgroundColor: AppColors.bgSurfaceHover,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.warning,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Day $elapsedDays of 30',
                              style: const TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              'Complete deletion: $formattedDate',
                              style: const TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // What Happens Details List
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.bgDivider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Important Details',
                        style: TextStyle(
                          fontFamily: TWTypography.brandFamily,
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        Icons.visibility_off_outlined,
                        'Hidden from Viewers',
                        'Your channel profile and published videos are concealed from search and public feeds.',
                      ),
                      const SizedBox(height: 10),
                      _buildInfoRow(
                        Icons.shield_outlined,
                        'Content Preserved',
                        'All video files, analytics, earnings, and subscribers are safely kept during the 30-day grace period.',
                      ),
                      const SizedBox(height: 10),
                      _buildInfoRow(
                        Icons.restore_rounded,
                        'Immediate Restoration',
                        'Canceling deletion restores your channel and its contents back to active status immediately.',
                      ),
                      const SizedBox(height: 10),
                      _buildInfoRow(
                        Icons.warning_amber_rounded,
                        'Complete Deletion After 30 Days',
                        'If you do not cancel within 30 days, all channel data and videos will be permanently destroyed.',
                        isWarning: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Primary & Secondary Actions
                if (!isExpired) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: isRestoring
                          ? null
                          : () async {
                              HapticFeedback.mediumImpact();
                              await onCancelDeletion();
                            },
                      icon: isRestoring
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Icon(
                              Icons.restore_rounded,
                              color: Colors.black,
                              size: 22,
                            ),
                      label: Text(
                        isRestoring
                            ? 'Restoring Channel...'
                            : 'Cancel Channel Deletion',
                        style: const TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Get.offAllNamed('/channelscreen');
                      },
                      icon: const Icon(
                        Icons.add_circle_outline_rounded,
                        color: Colors.black,
                        size: 22,
                      ),
                      label: const Text(
                        'Create a New Channel',
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // Return to Home / Sign Out
                TextButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    if (AuthService.to.isAuthenticated.value) {
                      Get.offAllNamed('/');
                    } else {
                      onSignOut();
                    }
                  },
                  child: const Text(
                    'Return to TruthWorld',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String title,
    String description, {
    bool isWarning = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: isWarning ? AppColors.warning : AppColors.textSecondary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: isWarning ? AppColors.warning : AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
