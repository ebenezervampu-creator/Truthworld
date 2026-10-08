import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/features/admin/presentation/views/team_management/edit_team_member_dialog.dart';
import 'package:truthworld/features/admin/presentation/views/team_management/team_management_badges.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Single item row representing an authorized team member in the management list.
class TeamMemberRow extends StatelessWidget {
  const TeamMemberRow({
    required this.controller,
    required this.member,
    super.key,
  });

  final AdminController controller;
  final Map<String, dynamic> member;

  @override
  Widget build(BuildContext context) {
    final email = member['email']?.toString() ?? 'Unknown';
    final name = member['name']?.toString() ?? email.split('@').first;
    final role = member['role']?.toString() ?? 'Moderator';
    final password = member['password']?.toString() ?? '••••••••';
    final status = member['status']?.toString() ?? 'active';
    final isSuspended = status == 'suspended';
    final isPrimaryOwner =
        email.toLowerCase() == 'hello@truthworld.in';

    final rawRoles = member['roles'];
    var rolesList = <String>[];
    if (rawRoles is List && rawRoles.isNotEmpty) {
      rolesList = rawRoles.map((e) => e.toString()).toList();
    } else if (role.isNotEmpty) {
      rolesList = role
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (rolesList.isEmpty) rolesList = [role];

    final showPassword = false.obs;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 650;

          final memberInfo = Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: isPrimaryOwner
                    ? AppColors.brand.withValues(alpha: 0.2)
                    : const Color(0xFF282828),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'A',
                  style: TextStyle(
                    fontFamily: TWTypography.brandFamily,
                    color: isPrimaryOwner
                        ? AppColors.brand
                        : AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        TeamRoleBadges(roles: rolesList),
                        if (isPrimaryOwner)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.brand.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: AppColors.brand.withValues(alpha: 0.3),
                              ),
                            ),
                            child: const Text(
                              'OWNER',
                              style: TextStyle(
                                fontFamily: TWTypography.brandFamily,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AppColors.brand,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: const TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          );

          final credentialsSection = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF101010),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.lock_outline_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Obx(
                      () => Text(
                        showPassword.value ? password : '••••••••',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: AppColors.textPrimary,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: showPassword.toggle,
                      borderRadius: BorderRadius.circular(4),
                      child: const Padding(
                        padding: EdgeInsets.all(2),
                        child: Icon(
                          Icons.remove_red_eye_outlined,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Copy / Share Credentials Button
              IconButton(
                onPressed: () => controller.copyMemberCredentials(
                  email: email,
                  password: password,
                  role: role,
                ),
                tooltip: 'Copy & Share Login Credentials',
                icon: const Icon(
                  Icons.share_outlined,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              // Edit / Change Password
              IconButton(
                onPressed: () =>
                    showEditTeamMemberDialog(context, controller, member),
                tooltip: 'Edit / Reset Password',
                icon: const Icon(
                  Icons.edit_outlined,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              // Delete Button (disabled for primary owner)
              if (!isPrimaryOwner)
                IconButton(
                  onPressed: () =>
                      showConfirmDeleteMemberDialog(context, controller, email),
                  tooltip: 'Revoke Access',
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
            ],
          );

          if (isMobile) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                memberInfo,
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TeamStatusChip(isSuspended: isSuspended),
                    credentialsSection,
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(flex: 3, child: memberInfo),
              TeamStatusChip(isSuspended: isSuspended),
              const SizedBox(width: 16),
              credentialsSection,
            ],
          );
        },
      ),
    );
  }
}
