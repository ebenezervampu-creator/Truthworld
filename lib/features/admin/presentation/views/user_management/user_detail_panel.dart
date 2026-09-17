import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/features/admin/presentation/views/user_management/user_avatar_vision_dialog.dart';
import 'package:truthworld/features/admin/presentation/views/user_management/user_detail_metrics_cards.dart';
import 'package:truthworld/features/admin/presentation/views/user_management/user_management_action_dialogs.dart';
import 'package:truthworld/features/admin/presentation/views/user_management/user_management_badges.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Full detail panel displaying selected user information, safety profile, and moderation controls.
class UserDetailPanel extends StatelessWidget {
  final AdminController controller;
  final Map<String, dynamic> user;
  final bool isModal;

  const UserDetailPanel({
    required this.controller,
    required this.user,
    this.isModal = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final photoUrl = (user['photoURL'] ?? user['avatarUrl'] ?? '').toString();
    final name = (user['name'] ?? user['displayName'] ?? 'User').toString();
    final email = (user['email'] ?? '').toString();
    final userId = (user['id'] ?? user['uid'] ?? '').toString();
    final role = (user['role'] ?? 'user').toString();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: isModal ? null : BorderRadius.circular(16),
        border: isModal ? null : Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Header Profile Card
            Row(
              children: [
                Tooltip(
                  message: 'Inspect Avatar with Vision AI',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(32),
                    onTap: () => showAvatarVisionInspectionDialog(context, controller, user),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: const Color(0xFF2A2A2A),
                          backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                          child: photoUrl.isEmpty
                              ? Text(
                                  name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'U',
                                  style: const TextStyle(
                                    fontFamily: TWTypography.brandFamily,
                                    color: AppColors.textPrimary,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E1E),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.4),
                              ),
                            ),
                            child: const Icon(
                              Icons.visibility,
                              size: 13,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontFamily: TWTypography.brandFamily,
                                color: AppColors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              role.toUpperCase(),
                              style: const TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                color: AppColors.textPrimary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (email.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          email,
                          style: const TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: userId));
                          AppSnackbar.info(
                            'User ID copied to clipboard',
                            title: 'Copied',
                          );
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'UID: ${userId.length > 16 ? "${userId.substring(0, 16)}..." : userId}',
                              style: const TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                color: AppColors.textTertiary,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.copy,
                              size: 12,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            Divider(color: Colors.white.withValues(alpha: 0.08)),
            const SizedBox(height: 16),

            // Safety Profile & Stats
            Obx(() {
              final safetyProfile = controller.userSafetyProfile.value;
              if (controller.isLoadingProfile.value && safetyProfile == null) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.0),
                  child: Center(child: CircularProgressIndicator(color: Colors.white)),
                );
              }

              final trustScore = (safetyProfile?['trustScore'] is num)
                  ? (safetyProfile!['trustScore'] as num).toInt()
                  : (user['trustScore'] as int? ?? 100);
              final strikes = (safetyProfile?['strikes'] is num)
                  ? (safetyProfile!['strikes'] as num).toInt()
                  : (user['strikes'] as int? ?? 0);
              final channels = (safetyProfile?['channels'] as List?) ?? [];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UserTrustScoreCard(score: trustScore),
                  const SizedBox(height: 12),
                  UserStrikeCountCard(strikes: strikes),
                  const SizedBox(height: 12),
                  UserUploadStatisticsCard(stats: safetyProfile ?? {}),
                  if (channels.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    UserChannelsCard(channels: channels),
                  ],
                ],
              );
            }),

            const SizedBox(height: 24),
            Divider(color: Colors.white.withValues(alpha: 0.08)),
            const SizedBox(height: 16),

            // Moderation Actions Section
            const Text(
              'Moderation Actions',
              style: TextStyle(
                fontFamily: TWTypography.brandFamily,
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Obx(() {
              final currentUser = controller.searchedUsers.firstWhereOrNull(
                    (u) => u['id'] == userId,
                  ) ??
                  user;
              final currentStatus = (currentUser['status'] ?? 'active').toString();

              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (currentStatus == 'active') ...[
                    UserActionButton(
                      label: 'Warn User',
                      color: Colors.amber,
                      onPressed: () => showUserActionDialog(
                        context: context,
                        controller: controller,
                        title: 'Warn User',
                        userId: userId,
                        actionCode: 'warn',
                      ),
                    ),
                    UserActionButton(
                      label: 'Suspend 7d',
                      color: Colors.orange,
                      onPressed: () => showUserActionDialog(
                        context: context,
                        controller: controller,
                        title: 'Suspend 7d',
                        userId: userId,
                        actionCode: 'suspend',
                        duration: 7,
                      ),
                    ),
                    UserActionButton(
                      label: 'Ban User',
                      color: AppColors.error,
                      onPressed: () => showUserActionDialog(
                        context: context,
                        controller: controller,
                        title: 'Ban User',
                        userId: userId,
                        actionCode: 'ban',
                      ),
                    ),
                    UserActionButton(
                      label: 'Reset Trust',
                      color: Colors.blue,
                      onPressed: () => showUserActionDialog(
                        context: context,
                        controller: controller,
                        title: 'Reset Trust',
                        userId: userId,
                        actionCode: 'reset_trust',
                      ),
                    ),
                  ] else if (currentStatus == 'banned') ...[
                    UserActionButton(
                      label: 'Unban User',
                      color: Colors.green,
                      onPressed: () => showUserActionDialog(
                        context: context,
                        controller: controller,
                        title: 'Unban User',
                        userId: userId,
                        actionCode: 'unban',
                      ),
                    ),
                    UserActionButton(
                      label: 'Reset Trust',
                      color: Colors.blue,
                      onPressed: () => showUserActionDialog(
                        context: context,
                        controller: controller,
                        title: 'Reset Trust',
                        userId: userId,
                        actionCode: 'reset_trust',
                      ),
                    ),
                    UserActionButton(
                      label: 'Delete Account',
                      color: AppColors.error,
                      onPressed: () => showUserActionDialog(
                        context: context,
                        controller: controller,
                        title: 'Delete Account',
                        userId: userId,
                        actionCode: 'delete',
                      ),
                    ),
                  ] else if (currentStatus == 'suspended') ...[
                    UserActionButton(
                      label: 'Reactivate User',
                      color: Colors.green,
                      onPressed: () => showUserActionDialog(
                        context: context,
                        controller: controller,
                        title: 'Reactivate User',
                        userId: userId,
                        actionCode: 'unban',
                      ),
                    ),
                    UserActionButton(
                      label: 'Ban User',
                      color: AppColors.error,
                      onPressed: () => showUserActionDialog(
                        context: context,
                        controller: controller,
                        title: 'Ban User',
                        userId: userId,
                        actionCode: 'ban',
                      ),
                    ),
                    UserActionButton(
                      label: 'Reset Trust',
                      color: Colors.blue,
                      onPressed: () => showUserActionDialog(
                        context: context,
                        controller: controller,
                        title: 'Reset Trust',
                        userId: userId,
                        actionCode: 'reset_trust',
                      ),
                    ),
                  ],
                ],
              );
            }),

            if (email.isNotEmpty) ...[
              const SizedBox(height: 20),
              Divider(color: Colors.white.withValues(alpha: 0.08)),
              const SizedBox(height: 16),
              const Text(
                'Account Integrity & Consolidation',
                style: TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Merge duplicate profiles created under this email and restore channel ownership.',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              Obx(() {
                final isConsolidating = controller.isConsolidatingAccounts.value;
                return ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF242424),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                  ),
                  onPressed: isConsolidating
                      ? null
                      : () => showConfirmConsolidationDialog(
                            context: context,
                            controller: controller,
                            email: email,
                            primaryUid: userId,
                          ),
                  icon: isConsolidating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.merge_type, color: Colors.white, size: 18),
                  label: Text(
                    isConsolidating ? 'Consolidating...' : 'Consolidate Duplicate Accounts',
                    style: const TextStyle(
                      fontFamily: TWTypography.brandFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

/// Placeholder container when no user is currently selected in master-detail view.
class UserEmptyDetailPanel extends StatelessWidget {
  const UserEmptyDetailPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: const Center(
        child: Text(
          'Select a user to view details',
          style: TextStyle(
            fontFamily: TWTypography.uiFamily,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Helper to display user details in a responsive mobile bottom sheet modal.
void showMobileUserDetailSheet({
  required BuildContext context,
  required AdminController controller,
  required Map<String, dynamic> user,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF181818),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => SingleChildScrollView(
        controller: scrollController,
        child: UserDetailPanel(
          controller: controller,
          user: user,
          isModal: true,
        ),
      ),
    ),
  );
}
