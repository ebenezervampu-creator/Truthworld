import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/features/admin/presentation/views/user_management/user_avatar_vision_dialog.dart';
import 'package:truthworld/features/admin/presentation/views/user_management/user_detail_panel.dart';
import 'package:truthworld/features/admin/presentation/views/user_management/user_management_badges.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Single filter chip button for filtering user list by account status.
class UserFilterChip extends StatelessWidget {
  final String statusKey;
  final String label;
  final String currentFilter;
  final VoidCallback onTap;

  const UserFilterChip({
    required this.statusKey,
    required this.label,
    required this.currentFilter,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = currentFilter == statusKey;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.white.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: TWTypography.uiFamily,
            color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

/// The searchable, filterable list section for user management.
class UserListSection extends StatelessWidget {
  final AdminController controller;
  final bool isDesktop;

  const UserListSection({
    required this.controller,
    required this.isDesktop,
    super.key,
  });

  TextEditingController get _searchController => controller.userSearchController;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search & Actions Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    maxLength: defaultMaxSearchLength,
                    buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                    inputFormatters: TruthworldTextInputFormatters.withLimit(defaultMaxSearchLength),
                    onChanged: controller.searchUsers,
                    style: const TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search by name, email, or UID...',
                      hintStyle: const TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: AppColors.textTertiary,
                        fontSize: 13,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Colors.white,
                        size: 20,
                      ),
                      suffixIcon: Obx(
                        () => controller.userSearchQuery.value.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.clear,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  controller.searchUsers('');
                                },
                                tooltip: 'Clear search',
                              )
                            : const SizedBox.shrink(),
                      ),
                      filled: true,
                      fillColor: AppColors.bgInput,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: () => controller.fetchUsers(force: true),
                  tooltip: 'Reload users',
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF212121),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Filter Chips (All, Active, Banned, Suspended)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Obx(() {
              final currentFilter = controller.userFilterStatus.value;
              final allCount = controller.allUsers.length;
              final activeCount = controller.allUsers.where((u) => u['status'] == 'active').length;
              final bannedCount = controller.allUsers.where((u) => u['status'] == 'banned').length;
              final suspendedCount = controller.allUsers.where((u) => u['status'] == 'suspended').length;

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    UserFilterChip(
                      statusKey: 'all',
                      label: 'All ($allCount)',
                      currentFilter: currentFilter,
                      onTap: () => controller.setUserFilterStatus('all'),
                    ),
                    const SizedBox(width: 6),
                    UserFilterChip(
                      statusKey: 'active',
                      label: 'Active ($activeCount)',
                      currentFilter: currentFilter,
                      onTap: () => controller.setUserFilterStatus('active'),
                    ),
                    const SizedBox(width: 6),
                    UserFilterChip(
                      statusKey: 'banned',
                      label: 'Banned ($bannedCount)',
                      currentFilter: currentFilter,
                      onTap: () => controller.setUserFilterStatus('banned'),
                    ),
                    const SizedBox(width: 6),
                    UserFilterChip(
                      statusKey: 'suspended',
                      label: 'Suspended ($suspendedCount)',
                      currentFilter: currentFilter,
                      onTap: () => controller.setUserFilterStatus('suspended'),
                    ),
                  ],
                ),
              );
            }),
          ),

          const SizedBox(height: 8),
          Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),

          // User List
          Expanded(
            child: Obx(() {
              if (controller.isSearchingUsers.value && controller.searchedUsers.isEmpty) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              }
              if (controller.searchedUsers.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.person_off_outlined,
                          size: 48,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No users found',
                          style: TextStyle(
                            fontFamily: TWTypography.brandFamily,
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Try adjusting your search query or status filter.',
                          style: TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            _searchController.clear();
                            controller.searchUsers('');
                            controller.setUserFilterStatus('all');
                            controller.fetchUsers();
                          },
                          icon: const Icon(Icons.refresh, color: Colors.white, size: 16),
                          label: const Text(
                            'Load All Users',
                            style: TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF252525),
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                itemCount: controller.searchedUsers.length,
                separatorBuilder: (context, index) =>
                    Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
                itemBuilder: (context, index) {
                  final user = controller.searchedUsers[index];
                  final isSelected = controller.selectedUser.value?['id'] == user['id'];
                  final photoUrl = (user['photoURL'] ?? user['avatarUrl'] ?? '').toString();
                  final name = (user['name'] ?? user['displayName'] ?? 'User').toString();
                  final email = (user['email'] ?? '').toString();
                  final status = (user['status'] ?? 'active').toString();
                  final trustScore = (user['trustScore'] is num) ? (user['trustScore'] as num).toInt() : 100;

                  return Material(
                    color: isSelected ? const Color(0xFF252525) : Colors.transparent,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: Tooltip(
                        message: 'Inspect Avatar with Vision AI',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => showAvatarVisionInspectionDialog(context, controller, user),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: const Color(0xFF2A2A2A),
                                backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                                child: photoUrl.isEmpty
                                    ? Text(
                                        name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'U',
                                        style: const TextStyle(
                                          fontFamily: TWTypography.brandFamily,
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : null,
                              ),
                              Positioned(
                                bottom: -2,
                                right: -2,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E1E1E),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.visibility,
                                    size: 10,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(
                          fontFamily: TWTypography.brandFamily,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        email.isNotEmpty ? email : (user['id'] ?? ''),
                        style: const TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            UserTrustScoreBadge(score: trustScore),
                            const SizedBox(width: 8),
                            UserStatusBadge(status: status),
                          ],
                        ),
                      ),
                      onTap: () {
                        controller.selectedUser.value = user;
                        controller.getUserSafetyProfile(user['id'] ?? '');
                        if (!isDesktop) {
                          showMobileUserDetailSheet(
                            context: context,
                            controller: controller,
                            user: user,
                          );
                        }
                      },
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}
