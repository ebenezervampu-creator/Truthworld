import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/features/admin/presentation/views/team_management/team_management_components.dart';
import 'package:truthworld/theme/app_theme.dart';

export 'team_management/team_management_components.dart';

/// Admin Team Management Tab.
/// Allows viewing, adding, editing, and deleting team members with email & password,
/// sharing login credentials, and changing administrator passwords.
class TeamManagementTab extends StatelessWidget {
  const TeamManagementTab({
    required this.controller,
    super.key,
  });

  final AdminController controller;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header & Quick Action Row
          _buildHeaderBar(context),
          const SizedBox(height: 24),

          // Overview Stats Row
          TeamManagementStatsRow(controller: controller),
          const SizedBox(height: 24),

          // Team Members List Table / Cards
          _buildMembersCard(context),
        ],
      ),
    );
  }

  Widget _buildHeaderBar(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 650;
        final buttons = Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () =>
                  showChangeAdminPasswordDialog(context, controller),
              icon:
                  const Icon(Icons.key_rounded, color: Colors.white, size: 16),
              label: const Text(
                'Change My Password',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => showAddTeamMemberDialog(context, controller),
              icon: const Icon(
                Icons.person_add_alt_1_rounded,
                color: Colors.black,
                size: 16,
              ),
              label: const Text(
                'Add Team Member',
                style: TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        );

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Admin Team & Security',
                style: TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Manage administrator credentials, create team accounts, and share login access.',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              buttons,
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Admin Team & Security',
                    style: TextStyle(
                      fontFamily: TWTypography.brandFamily,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Manage administrator credentials, create team accounts, and share login access.',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            buttons,
          ],
        );
      },
    );
  }

  Widget _buildMembersCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.manage_accounts_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Authorized Team Members',
                      style: TextStyle(
                        fontFamily: TWTypography.brandFamily,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                Obx(
                  () => Text(
                    '${controller.adminMembers.length} Accounts',
                    style: const TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
          Obx(() {
            final members = controller.adminMembers;
            if (members.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.people_outline_rounded,
                        size: 40,
                        color: Colors.white,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'No team members registered yet',
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: members.length,
              separatorBuilder: (_, _) => Divider(
                color: Colors.white.withValues(alpha: 0.05),
                height: 1,
              ),
              itemBuilder: (context, index) {
                final member = members[index];
                return TeamMemberRow(
                  controller: controller,
                  member: member,
                );
              },
            );
          }),
        ],
      ),
    );
  }
}
