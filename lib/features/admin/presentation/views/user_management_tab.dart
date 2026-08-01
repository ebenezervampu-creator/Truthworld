import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

class UserManagementTab extends StatelessWidget {
  final AdminController controller;
  const UserManagementTab({required this.controller, super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 800;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildUserList(context),
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

  Widget _buildUserList(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (val) {
                if (val.length > 2) {
                  controller.searchUsers(val);
                }
              },
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search users by email or name...',
                hintStyle: const TextStyle(color: AppColors.textTertiary),
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppColors.textPrimary,
                ),
                filled: true,
                fillColor: AppColors.bgInput,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const Divider(color: AppColors.bgDivider, height: 1),
          Expanded(
            child: Obx(() {
              if (controller.isSearchingUsers.value) {
                return const Center(child: CircularProgressIndicator());
              }
              if (controller.searchedUsers.isEmpty) {
                return const Center(
                  child: Text(
                    'No users found',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                );
              }
              return ListView.separated(
                itemCount: controller.searchedUsers.length,
                separatorBuilder: (context, index) =>
                    const Divider(color: AppColors.bgDivider, height: 1),
                itemBuilder: (context, index) {
                  final user = controller.searchedUsers[index];
                  return Material(
                    color: Colors.transparent,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.bgElevated,
                        child: Text(
                          user['name']?.substring(0, 1).toUpperCase() ?? 'U',
                          style: const TextStyle(color: AppColors.textPrimary),
                        ),
                      ),
                      title: Text(
                        user['name'] ?? 'Unknown User',
                        style: const TextStyle(color: AppColors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        user['email'] ?? '',
                        style: const TextStyle(color: AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildTrustScoreBadge(user['trustScore'] ?? 0),
                            const SizedBox(width: 8),
                            _buildStatusBadge(user['status'] ?? 'active'),
                          ],
                        ),
                      ),
                      onTap: () {
                        controller.selectedUser.value = user;
                        controller.getUserSafetyProfile(user['id'] ?? '');
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

  Widget _buildEmptyDetail(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: const Center(
        child: Text(
          'Select a user to view details',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ),
    );
  }

  Widget _buildDetailPanel(BuildContext context, Map<String, dynamic> user) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppColors.bgElevated,
                  child: Text(
                    user['name']?.substring(0, 1).toUpperCase() ?? 'U',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user['name'] ?? 'Unknown User',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        user['email'] ?? '',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Obx(() {
              final safetyProfile = controller.userSafetyProfile.value;
              if (safetyProfile == null) {
                return const CircularProgressIndicator();
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTrustScoreCard(safetyProfile['trustScore'] ?? 0),
                  const SizedBox(height: 16),
                  _buildStrikeCount(safetyProfile['strikes'] ?? 0),
                  const SizedBox(height: 16),
                  _buildUploadStatistics(safetyProfile),
                ],
              );
            }),
            const SizedBox(height: 24),
            const Text(
              'Actions',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildActionButton(
                  context,
                  'Warn',
                  user['id'],
                  color: Colors.amber,
                ),
                _buildActionButton(
                  context,
                  'Suspend 7d',
                  user['id'],
                  duration: 7,
                  color: Colors.orange,
                ),
                _buildActionButton(
                  context,
                  'Ban',
                  user['id'],
                  color: AppColors.error,
                ),
                _buildActionButton(
                  context,
                  'Reset Trust',
                  user['id'],
                  color: Colors.blue,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrustScoreCard(int score) {
    Color scoreColor = Colors.red;
    if (score >= 75) {
      scoreColor = Colors.green;
    } else if (score >= 40) {
      scoreColor = Colors.amber;
    } else if (score >= 10) {
      scoreColor = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Trust Score',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: scoreColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scoreColor),
            ),
            child: Text(
              score.toString(),
              style: TextStyle(color: scoreColor, fontWeight: FontWeight.bold),
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
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Strikes',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
          ),
          Text(
            strikes.toString(),
            style: const TextStyle(
              color: AppColors.error,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadStatistics(Map<String, dynamic> stats) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Upload Statistics',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Total Uploads: ${stats['totalUploads'] ?? 0}',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          Text(
            'Approval Rate: ${stats['approvalRate'] ?? 0}%',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          Text(
            'Rejection Rate: ${stats['rejectionRate'] ?? 0}%',
            style: const TextStyle(color: AppColors.textSecondary),
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
        color: scoreColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scoreColor),
      ),
      child: Text(
        score.toString(),
        style: TextStyle(color: scoreColor, fontSize: 12),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final color = status == 'active' ? Colors.green : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontSize: 12),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String action,
    String userId, {
    required Color color, int? duration,
  }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.2),
        foregroundColor: color,
        side: BorderSide(color: color),
      ),
      onPressed: () =>
          _showActionDialog(context, action, userId, duration: duration),
      child: Text(action),
    );
  }

  void _showActionDialog(
    BuildContext context,
    String action,
    String userId, {
    int? duration,
  }) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        title: Text(
          'Confirm $action',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        content: TextField(
          controller: reasonController,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Enter reason...',
            hintStyle: TextStyle(color: AppColors.textTertiary),
            filled: true,
            fillColor: AppColors.bgInput,
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              controller.moderateUser(
                userId,
                action,
                reasonController.text,
                durationDays: duration,
              );
              Navigator.pop(context);
            },
            child: const Text(
              'Confirm',
              style: TextStyle(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
