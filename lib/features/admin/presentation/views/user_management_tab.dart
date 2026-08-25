import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

class UserManagementTab extends StatelessWidget {
  final AdminController controller;
  const UserManagementTab({required this.controller, super.key});

  TextEditingController get _searchController => controller.userSearchController;

  @override
  Widget build(BuildContext context) {
    if (controller.allUsers.isEmpty && !controller.isSearchingUsers.value) {
      controller.fetchUsers();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 800;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildUserList(context, isDesktop),
            ),
            if (isDesktop) ...[
              const SizedBox(width: 24),
              Expanded(
                child: Obx(
                  () => controller.selectedUser.value != null
                      ? _buildDetailPanel(
                          context,
                          controller.selectedUser.value!,
                        )
                      : _buildEmptyDetail(context),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildUserList(BuildContext context, bool isDesktop) {
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
                    onChanged: (val) {
                      controller.searchUsers(val);
                    },
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
                    _buildFilterChip('all', 'All ($allCount)', currentFilter),
                    const SizedBox(width: 6),
                    _buildFilterChip('active', 'Active ($activeCount)', currentFilter),
                    const SizedBox(width: 6),
                    _buildFilterChip('banned', 'Banned ($bannedCount)', currentFilter),
                    const SizedBox(width: 6),
                    _buildFilterChip('suspended', 'Suspended ($suspendedCount)', currentFilter),
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
                      leading: CircleAvatar(
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
                            _buildTrustScoreBadge(trustScore),
                            const SizedBox(width: 8),
                            _buildStatusBadge(status),
                          ],
                        ),
                      ),
                      onTap: () {
                        controller.selectedUser.value = user;
                        controller.getUserSafetyProfile(user['id'] ?? '');
                        if (!isDesktop) {
                          _showMobileDetailSheet(context, user);
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

  Widget _buildFilterChip(String statusKey, String label, String currentFilter) {
    final isSelected = currentFilter == statusKey;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => controller.setUserFilterStatus(statusKey),
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

  Widget _buildEmptyDetail(BuildContext context) {
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

  void _showMobileDetailSheet(BuildContext context, Map<String, dynamic> user) {
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
          child: _buildDetailPanel(context, user, isModal: true),
        ),
      ),
    );
  }

  Widget _buildDetailPanel(
    BuildContext context,
    Map<String, dynamic> user, {
    bool isModal = false,
  }) {
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
                          Get.snackbar(
                            'Copied',
                            'User ID copied to clipboard',
                            backgroundColor: const Color(0xFF252525),
                            colorText: AppColors.textPrimary,
                            snackPosition: SnackPosition.BOTTOM,
                            duration: const Duration(seconds: 1),
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
                  _buildTrustScoreCard(trustScore),
                  const SizedBox(height: 12),
                  _buildStrikeCount(strikes),
                  const SizedBox(height: 12),
                  _buildUploadStatistics(safetyProfile ?? {}),
                  if (channels.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildChannelsCard(channels),
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
                    _buildActionButton(
                      context,
                      'Warn User',
                      userId,
                      actionCode: 'warn',
                      color: Colors.amber,
                    ),
                    _buildActionButton(
                      context,
                      'Suspend 7d',
                      userId,
                      actionCode: 'suspend',
                      duration: 7,
                      color: Colors.orange,
                    ),
                    _buildActionButton(
                      context,
                      'Ban User',
                      userId,
                      actionCode: 'ban',
                      color: AppColors.error,
                    ),
                    _buildActionButton(
                      context,
                      'Reset Trust',
                      userId,
                      actionCode: 'reset_trust',
                      color: Colors.blue,
                    ),
                  ] else if (currentStatus == 'banned') ...[
                    _buildActionButton(
                      context,
                      'Unban User',
                      userId,
                      actionCode: 'unban',
                      color: Colors.green,
                    ),
                    _buildActionButton(
                      context,
                      'Reset Trust',
                      userId,
                      actionCode: 'reset_trust',
                      color: Colors.blue,
                    ),
                    _buildActionButton(
                      context,
                      'Delete Account',
                      userId,
                      actionCode: 'delete',
                      color: AppColors.error,
                    ),
                  ] else if (currentStatus == 'suspended') ...[
                    _buildActionButton(
                      context,
                      'Reactivate User',
                      userId,
                      actionCode: 'unban',
                      color: Colors.green,
                    ),
                    _buildActionButton(
                      context,
                      'Ban User',
                      userId,
                      actionCode: 'ban',
                      color: AppColors.error,
                    ),
                    _buildActionButton(
                      context,
                      'Reset Trust',
                      userId,
                      actionCode: 'reset_trust',
                      color: Colors.blue,
                    ),
                  ],
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelsCard(List channels) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF212121),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Associated Channels',
            style: TextStyle(
              fontFamily: TWTypography.brandFamily,
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...channels.map((ch) {
            final chData = ch is Map ? ch : {};
            final chName = chData['name'] ?? chData['channelName'] ?? 'Channel';
            final handle = chData['handle'] ?? chData['username'] ?? '';
            final subs = chData['subscriberCount'] ?? 0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.tv, size: 16, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$chName ${handle.isNotEmpty ? "(@$handle)" : ""}',
                      style: const TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: AppColors.textPrimary,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '$subs subs',
                    style: const TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: AppColors.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTrustScoreCard(int score) {
    Color scoreColor = Colors.red;
    var assessment = 'High Risk';
    if (score >= 75) {
      scoreColor = Colors.green;
      assessment = 'Good Standing';
    } else if (score >= 40) {
      scoreColor = Colors.amber;
      assessment = 'Moderate Risk';
    } else if (score >= 10) {
      scoreColor = Colors.orange;
      assessment = 'Flagged';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF212121),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Trust Score',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                assessment,
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: scoreColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: scoreColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scoreColor),
            ),
            child: Text(
              score.toString(),
              style: TextStyle(
                fontFamily: TWTypography.brandFamily,
                color: scoreColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStrikeCount(int strikes) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF212121),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Recorded Strikes',
            style: TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            strikes.toString(),
            style: TextStyle(
              fontFamily: TWTypography.brandFamily,
              color: strikes > 0 ? AppColors.error : Colors.green,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadStatistics(Map<String, dynamic> stats) {
    final totalUploads = stats['totalUploads'] ?? 0;
    final approvalRate = stats['approvalRate'] ?? 100;
    final rejectionRate = stats['rejectionRate'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF212121),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Upload Activity Statistics',
            style: TextStyle(
              fontFamily: TWTypography.brandFamily,
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Uploads:',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              Text(
                '$totalUploads',
                style: const TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Approval Rate:',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              Text(
                '$approvalRate%',
                style: const TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Rejection Rate:',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              Text(
                '$rejectionRate%',
                style: const TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrustScoreBadge(int score) {
    Color scoreColor = Colors.red;
    if (score >= 75) {
      scoreColor = Colors.green;
    } else if (score >= 40) {
      scoreColor = Colors.amber;
    } else if (score >= 10) {
      scoreColor = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scoreColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scoreColor),
      ),
      child: Text(
        score.toString(),
        style: TextStyle(
          fontFamily: TWTypography.brandFamily,
          color: scoreColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = Colors.green;
    if (status == 'banned') {
      color = AppColors.error;
    } else if (status == 'suspended') {
      color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontFamily: TWTypography.uiFamily,
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String label,
    String userId, {
    required String actionCode,
    required Color color,
    int? duration,
  }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.15),
        foregroundColor: color,
        side: BorderSide(color: color),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      onPressed: () => _showActionDialog(
        context,
        label,
        userId,
        actionCode: actionCode,
        duration: duration,
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: TWTypography.uiFamily,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  void _showActionDialog(
    BuildContext context,
    String title,
    String userId, {
    required String actionCode,
    int? duration,
  }) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF181818),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        title: Text(
          'Confirm $title',
          style: const TextStyle(
            fontFamily: TWTypography.brandFamily,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to apply this action to user $userId?',
              style: const TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              style: const TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Enter reason for this action...',
                hintStyle: const TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textTertiary,
                ),
                filled: true,
                fillColor: AppColors.bgInput,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: actionCode.contains('ban') || actionCode == 'delete'
                  ? AppColors.error
                  : (actionCode == 'unban' ? Colors.green : const Color(0xFF252525)),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              controller.moderateUser(
                userId,
                actionCode,
                reasonController.text.trim().isNotEmpty
                    ? reasonController.text.trim()
                    : 'Admin moderation action: $title',
                durationDays: duration,
              );
            },
            child: const Text(
              'Confirm',
              style: TextStyle(
                fontFamily: TWTypography.brandFamily,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
