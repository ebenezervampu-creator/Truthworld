import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/utils/content_validator.dart';
import 'package:truthworld/core/utils/truthworld_text_input_formatters.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

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
          _buildStatsRow(context),
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
              onPressed: () => _showChangePasswordDialog(context),
              icon: const Icon(Icons.key_rounded, color: Colors.white, size: 16),
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _showAddMemberDialog(context),
              icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 16),
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
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

  Widget _buildStatsRow(BuildContext context) {
    return Obx(() {
      final members = controller.adminMembers;
      final total = members.length;
      final active = members.where((m) => (m['status'] ?? 'active') != 'suspended').length;
      final superAdmins = members.where((m) => (m['role'] ?? '').toString().contains('Super')).length;
      final moderators = members.where((m) => (m['role'] ?? '').toString().contains('Mod')).length;

      return LayoutBuilder(
        builder: (context, constraints) {
          final cols = constraints.maxWidth > 1000
              ? 4
              : (constraints.maxWidth > 600 ? 2 : 1);

          return GridView.count(
            crossAxisCount: cols,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: cols == 1 ? 3.0 : 2.0,
            children: [
              _buildMetricCard(
                title: 'Total Administrators',
                value: '$total',
                subtitle: 'Registered access keys',
                icon: Icons.shield_outlined,
              ),
              _buildMetricCard(
                title: 'Active Accounts',
                value: '$active',
                subtitle: 'Currently authorized',
                icon: Icons.verified_user_outlined,
              ),
              _buildMetricCard(
                title: 'Super Admins',
                value: '$superAdmins',
                subtitle: 'Full system privileges',
                icon: Icons.admin_panel_settings_outlined,
              ),
              _buildMetricCard(
                title: 'Moderators',
                value: '$moderators',
                subtitle: 'Queue review operators',
                icon: Icons.remove_red_eye_outlined,
              ),
            ],
          );
        },
      );
    });
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Icon(icon, color: Colors.white, size: 18),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontFamily: TWTypography.brandFamily,
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: AppColors.textTertiary,
              fontSize: 11,
            ),
          ),
        ],
      ),
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
                    Icon(Icons.manage_accounts_rounded, color: Colors.white, size: 20),
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
                Obx(() => Text(
                      '${controller.adminMembers.length} Accounts',
                      style: const TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    )),
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
                      Icon(Icons.people_outline_rounded, size: 40, color: Colors.white),
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
                return _buildMemberRow(context, member);
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMemberRow(BuildContext context, Map<String, dynamic> member) {
    final email = member['email']?.toString() ?? 'Unknown';
    final name = member['name']?.toString() ?? email.split('@').first;
    final role = member['role']?.toString() ?? 'Moderator';
    final password = member['password']?.toString() ?? '••••••••';
    final status = member['status']?.toString() ?? 'active';
    final isSuspended = status == 'suspended';
    final isPrimaryOwner = email.toLowerCase() == 'ebenezervampy@towervsp.com' ||
        email.toLowerCase() == 'ebenezervampu@towervsp.com';

    final rawRoles = member['roles'];
    var rolesList = <String>[];
    if (rawRoles is List && rawRoles.isNotEmpty) {
      rolesList = rawRoles.map((e) => e.toString()).toList();
    } else if (role.isNotEmpty) {
      rolesList = role.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
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
                    color: isPrimaryOwner ? AppColors.brand : AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildRoleBadges(rolesList),
                        if (isPrimaryOwner) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.brand.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.brand.withValues(alpha: 0.3)),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF101010),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline_rounded, color: Colors.white, size: 14),
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
                icon: const Icon(Icons.share_outlined, color: Colors.white, size: 18),
              ),
              // Edit / Change Password
              IconButton(
                onPressed: () => _showEditMemberDialog(context, member),
                tooltip: 'Edit / Reset Password',
                icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 18),
              ),
              // Delete Button (disabled for primary owner)
              if (!isPrimaryOwner)
                IconButton(
                  onPressed: () => _confirmDeleteMember(context, email),
                  tooltip: 'Revoke Access',
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 18),
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
                    _buildStatusChip(isSuspended),
                    credentialsSection,
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(flex: 3, child: memberInfo),
              _buildStatusChip(isSuspended),
              const SizedBox(width: 16),
              credentialsSection,
            ],
          );
        },
      ),
    );
  }

  Widget _buildRoleBadges(List<String> roles) {
    if (roles.isEmpty) return _buildRoleBadge('Admin');
    if (roles.contains('Super Admin') || roles.any((r) => r.toLowerCase().contains('owner'))) {
      return _buildRoleBadge('Super Admin (All Tabs)');
    }
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: roles.map(_buildRoleBadge).toList(),
    );
  }

  Widget _buildRoleBadge(String role) {
    var bg = const Color(0xFF202020);
    var fg = Colors.white;

    final r = role.toLowerCase();
    if (r.contains('super') || r.contains('owner')) {
      bg = const Color(0xFF332040);
      fg = const Color(0xFFD8B4FE);
    } else if (r.contains('content') || r.contains('mod')) {
      bg = const Color(0xFF1E2D4A);
      fg = const Color(0xFF93C5FD);
    } else if (r.contains('ad')) {
      bg = const Color(0xFF3E3218);
      fg = const Color(0xFFFDE68A);
    } else if (r.contains('trust') || r.contains('safety')) {
      bg = const Color(0xFF1A3828);
      fg = const Color(0xFF86EFAC);
    } else if (r.contains('user')) {
      bg = const Color(0xFF34231E);
      fg = const Color(0xFFFDBA74);
    } else if (r.contains('audit') || r.contains('compliance')) {
      bg = const Color(0xFF2E2638);
      fg = const Color(0xFFE9D5FF);
    } else if (r.contains('team')) {
      bg = const Color(0xFF16323B);
      fg = const Color(0xFF67E8F9);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: 0.2)),
      ),
      child: Text(
        role,
        style: TextStyle(
          fontFamily: TWTypography.uiFamily,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildStatusChip(bool isSuspended) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isSuspended
            ? AppColors.error.withValues(alpha: 0.15)
            : const Color(0xFF1E3A24),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSuspended
              ? AppColors.error.withValues(alpha: 0.3)
              : const Color(0xFF2BA640).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSuspended ? AppColors.error : const Color(0xFF2BA640),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            isSuspended ? 'Suspended' : 'Active',
            style: TextStyle(
              fontFamily: TWTypography.uiFamily,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isSuspended ? AppColors.error : const Color(0xFF4ADE80),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DIALOGS: Add Member, Edit Member, Change Password, Confirm Delete
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildRoleSelectionSection(RxList<String> selectedRoles) {
    final allCount = AdminController.availableRoles.length;

    return Obx(() {
      final selectedCount = selectedRoles.length;
      final isAllSelected = selectedCount == allCount;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Assign Roles & Permissions ($selectedCount/$allCount)',
                style: const TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              InkWell(
                onTap: () {
                  if (isAllSelected) {
                    selectedRoles.clear();
                  } else {
                    selectedRoles.assignAll(AdminController.allRoleNames);
                  }
                },
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isAllSelected
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isAllSelected ? 'Deselect All' : 'Select All Roles',
                        style: const TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: AdminController.availableRoles.length,
              separatorBuilder: (_, _) => Divider(
                color: Colors.white.withValues(alpha: 0.04),
                height: 1,
              ),
              itemBuilder: (context, idx) {
                final roleMeta = AdminController.availableRoles[idx];
                final roleName = roleMeta['name'] as String;
                final roleDesc = roleMeta['description'] as String;
                final isSelected = selectedRoles.contains(roleName);

                return InkWell(
                  onTap: () {
                    if (isSelected) {
                      selectedRoles.remove(roleName);
                    } else {
                      selectedRoles.add(roleName);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: isSelected,
                          activeColor: const Color(0xFF2BA640),
                          checkColor: Colors.white,
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          onChanged: (val) {
                            if (val == true) {
                              if (!selectedRoles.contains(roleName)) selectedRoles.add(roleName);
                            } else {
                              selectedRoles.remove(roleName);
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    roleName,
                                    style: TextStyle(
                                      fontFamily: TWTypography.uiFamily,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? Colors.white : AppColors.textSecondary,
                                    ),
                                  ),
                                  if (roleName == 'Super Admin') ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'ALL TABS',
                                        style: TextStyle(
                                          fontSize: 8,
                                          color: Color(0xFFD8B4FE),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                roleDesc,
                                style: TextStyle(
                                  fontFamily: TWTypography.uiFamily,
                                  fontSize: 10,
                                  color: isSelected ? AppColors.textSecondary : AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    });
  }

  void _showAddMemberDialog(BuildContext context) {
    final emailCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final selectedRoles = <String>['Content Moderator'].obs;
    final isObscure = true.obs;
    final isSubmitting = false.obs;

    void generatePassword() {
      const chars = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';
      final rnd = Random.secure();
      final generated = List.generate(8, (_) => chars[rnd.nextInt(chars.length)]).join();
      passCtrl.text = generated;
    }

    Get.dialog(
      Dialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Container(
          width: 480,
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    Icon(Icons.person_add_alt_rounded, color: Colors.white, size: 22),
                    SizedBox(width: 10),
                    Text(
                      'Add Team Member',
                      style: TextStyle(
                        fontFamily: TWTypography.brandFamily,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Enter member email, password, and assign their specific roles & tabs permissions.',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 18),

                // Email
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Member Email',
                    hintText: 'e.g. moderator@towervsp.com',
                    labelStyle: const TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.bgInput,
                    prefixIcon: const Icon(Icons.email_outlined, color: Colors.white),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),

                // Name
                TextField(
                  controller: nameCtrl,
                  inputFormatters: TruthworldTextInputFormatters.standard,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Member Name / Designation',
                    hintText: 'e.g. John Doe',
                    labelStyle: const TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.bgInput,
                    prefixIcon: const Icon(Icons.badge_outlined, color: Colors.white),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),

                // Password & Generator
                Obx(
                  () => TextField(
                    controller: passCtrl,
                    obscureText: isObscure.value,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Enter or generate password',
                      labelStyle: const TextStyle(color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.bgInput,
                      prefixIcon: const Icon(Icons.lock_outline_rounded, color: Colors.white),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.auto_fix_high_rounded, color: Colors.white, size: 18),
                            tooltip: 'Generate Random Password',
                            onPressed: generatePassword,
                          ),
                          IconButton(
                            icon: Icon(
                              isObscure.value ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: Colors.white,
                              size: 18,
                            ),
                            tooltip: isObscure.value ? 'Show Password' : 'Hide Password',
                            onPressed: isObscure.toggle,
                          ),
                        ],
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Role Selection with "Select All Roles" and list of all roles
                _buildRoleSelectionSection(selectedRoles),
                const SizedBox(height: 22),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: Get.back,
                      child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                    ),
                    const SizedBox(width: 12),
                    Obx(
                      () => ElevatedButton.icon(
                        onPressed: isSubmitting.value
                            ? null
                            : () async {
                                final email = emailCtrl.text.trim();
                                final pass = passCtrl.text.trim();
                                if (email.isEmpty || pass.isEmpty) {
                                  AppSnackbar.warning('Please fill in email and password.');
                                  return;
                                }
                                final name = nameCtrl.text.trim();
                                if (name.isNotEmpty) {
                                  final nameVal = ContentValidator.validate(name, checkEnglishOnly: false, fieldName: 'Member Name');
                                  if (!nameVal.isValid) {
                                    AppSnackbar.warning(nameVal.message);
                                    return;
                                  }
                                }
                                if (selectedRoles.isEmpty) {
                                  AppSnackbar.warning('Please select at least one role for this member.');
                                  return;
                                }
                                isSubmitting.value = true;
                                final rolesList = selectedRoles.toList();
                                final primaryRole = rolesList.contains('Super Admin')
                                    ? 'Super Admin'
                                    : rolesList.join(', ');
                                final success = await controller.addTeamMember(
                                  email: email,
                                  password: pass,
                                  role: primaryRole,
                                  roles: rolesList,
                                  name: name,
                                );
                                isSubmitting.value = false;
                                if (success) {
                                  Get.back();
                                  controller.copyMemberCredentials(
                                    email: email,
                                    password: pass,
                                    role: primaryRole,
                                  );
                                }
                              },
                        icon: isSubmitting.value
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                        label: const Text('Save & Share', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brand,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditMemberDialog(BuildContext context, Map<String, dynamic> member) {
    final email = member['email']?.toString() ?? '';
    final nameCtrl = TextEditingController(text: member['name']?.toString() ?? '');
    final passCtrl = TextEditingController(text: member['password']?.toString() ?? '');
    final rawRoles = member['roles'];
    var initialRoles = <String>[];
    if (rawRoles is List && rawRoles.isNotEmpty) {
      initialRoles = rawRoles.map((e) => e.toString()).toList();
    } else {
      final singleRole = member['role']?.toString() ?? 'Content Moderator';
      initialRoles = singleRole.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    if (initialRoles.isEmpty) initialRoles = ['Content Moderator'];
    final selectedRoles = <String>[...initialRoles].obs;
    final isSuspended = ((member['status'] ?? 'active') == 'suspended').obs;
    final isObscure = true.obs;
    final isSaving = false.obs;

    Get.dialog(
      Dialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Container(
          width: 480,
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.edit_note_rounded, color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Edit $email',
                        style: const TextStyle(
                          fontFamily: TWTypography.brandFamily,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                TextField(
                  controller: nameCtrl,
                  inputFormatters: TruthworldTextInputFormatters.standard,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Name',
                    labelStyle: const TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.bgInput,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),

                Obx(
                  () => TextField(
                    controller: passCtrl,
                    obscureText: isObscure.value,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Reset Password',
                      labelStyle: const TextStyle(color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.bgInput,
                      suffixIcon: IconButton(
                        icon: Icon(
                          isObscure.value ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: Colors.white,
                          size: 18,
                        ),
                        onPressed: isObscure.toggle,
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Roles Selection with "Select All Roles"
                _buildRoleSelectionSection(selectedRoles),
                const SizedBox(height: 14),

                Obx(
                  () => SwitchListTile(
                    title: const Text(
                      'Suspend Account Access',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                    ),
                    subtitle: Text(
                      isSuspended.value
                          ? 'Member cannot log in while suspended.'
                          : 'Account is currently active and authorized.',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                    value: isSuspended.value,
                    activeTrackColor: AppColors.error.withValues(alpha: 0.5),
                    activeColor: AppColors.error,
                    onChanged: (val) => isSuspended.value = val,
                  ),
                ),
                const SizedBox(height: 22),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: Get.back,
                      child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                    ),
                    const SizedBox(width: 12),
                    Obx(
                      () => ElevatedButton(
                        onPressed: isSaving.value
                            ? null
                            : () async {
                                if (selectedRoles.isEmpty) {
                                  AppSnackbar.warning('Please select at least one role.');
                                  return;
                                }
                                final name = nameCtrl.text.trim();
                                if (name.isNotEmpty) {
                                  final nameVal = ContentValidator.validate(name, checkEnglishOnly: false, fieldName: 'Member Name');
                                  if (!nameVal.isValid) {
                                    AppSnackbar.warning(nameVal.message);
                                    return;
                                  }
                                }
                                isSaving.value = true;
                                final rolesList = selectedRoles.toList();
                                final primaryRole = rolesList.contains('Super Admin')
                                    ? 'Super Admin'
                                    : rolesList.join(', ');
                                final updates = <String, dynamic>{
                                  'role': primaryRole,
                                  'status': isSuspended.value ? 'suspended' : 'active',
                                };
                                if (name.isNotEmpty) {
                                  updates['name'] = name;
                                }
                                if (passCtrl.text.trim().isNotEmpty) {
                                  updates['password'] = passCtrl.text.trim();
                                }
                                await controller.updateTeamMember(
                                  email: email,
                                  updates: updates,
                                  roles: rolesList,
                                );
                                isSaving.value = false;
                                Get.back();
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brand,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final currentPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    final isSaving = false.obs;
    final isObscureCurrent = true.obs;
    final isObscureNew = true.obs;

    Get.dialog(
      Dialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(Icons.lock_reset_rounded, color: Colors.white, size: 22),
                  SizedBox(width: 10),
                  Text(
                    'Change Admin Password',
                    style: TextStyle(
                      fontFamily: TWTypography.brandFamily,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Obx(
                () => Text(
                  'Updating credentials for ${controller.currentAdminEmail.value.isNotEmpty ? controller.currentAdminEmail.value : "Authorized Administrator"}.',
                  style: const TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Current Password
              Obx(
                () => TextField(
                  controller: currentPassCtrl,
                  obscureText: isObscureCurrent.value,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    hintText: 'Enter existing password',
                    labelStyle: const TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.bgInput,
                    prefixIcon: const Icon(Icons.lock_outline_rounded, color: Colors.white),
                    suffixIcon: IconButton(
                      icon: Icon(
                        isObscureCurrent.value ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                      onPressed: isObscureCurrent.toggle,
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // New Password
              Obx(
                () => TextField(
                  controller: newPassCtrl,
                  obscureText: isObscureNew.value,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    hintText: 'Enter new password',
                    labelStyle: const TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.bgInput,
                    prefixIcon: const Icon(Icons.key_rounded, color: Colors.white),
                    suffixIcon: IconButton(
                      icon: Icon(
                        isObscureNew.value ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                      onPressed: isObscureNew.toggle,
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Confirm New Password
              TextField(
                controller: confirmPassCtrl,
                obscureText: true,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  hintText: 'Re-enter new password',
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.bgInput,
                  prefixIcon: const Icon(Icons.check_circle_outline_rounded, color: Colors.white),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: Get.back,
                    child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                  ),
                  const SizedBox(width: 12),
                  Obx(
                    () => ElevatedButton(
                      onPressed: isSaving.value
                          ? null
                          : () async {
                              final current = currentPassCtrl.text.trim();
                              final newPass = newPassCtrl.text.trim();
                              final confirm = confirmPassCtrl.text.trim();

                              if (current.isEmpty || newPass.isEmpty) {
                                AppSnackbar.warning('Please fill in all password fields.');
                                return;
                              }
                              if (newPass.length < 6) {
                                AppSnackbar.warning('New password must be at least 6 characters long.');
                                return;
                              }
                              if (newPass != confirm) {
                                AppSnackbar.warning('New passwords do not match.');
                                return;
                              }
                              isSaving.value = true;
                              final success = await controller.changeAdminPassword(
                                currentPassword: current,
                                newPassword: newPass,
                              );
                              isSaving.value = false;
                              if (success) {
                                Get.back();
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: isSaving.value
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Update Password', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteMember(BuildContext context, String email) {
    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Revoke Admin Access',
          style: TextStyle(
            fontFamily: TWTypography.brandFamily,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          'Are you sure you want to revoke access for $email? This member will no longer be able to log into the Admin Portal.',
          style: const TextStyle(
            fontFamily: TWTypography.uiFamily,
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              controller.deleteTeamMember(email);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Revoke Access', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
