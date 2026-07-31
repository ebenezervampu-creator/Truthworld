import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/topic_management_controller.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/theme/app_theme.dart';

/// More Options Popup Menu for Topic Card (Edit, View, Copy Link, Delete)
class TopicPopupMenu extends StatelessWidget {
  const TopicPopupMenu({
    required this.topic,
    required this.controller,
    super.key,
  });
  final Topic topic;
  final TopicManagementController controller;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOwner =
        Get.isRegistered<AuthService>() &&
        ((topic.channelId != null &&
                topic.channelId!.isNotEmpty &&
                AuthService.to.userChannel?.id == topic.channelId) ||
            (topic.creatorId != null &&
                topic.creatorId!.isNotEmpty &&
                AuthService.to.uid == topic.creatorId));

    return PopupMenuButton<String>(
      icon: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.bgPage.withValues(alpha: 0.35),
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.textPrimary.withValues(alpha: 0.2),
          ),
        ),
        child: const Icon(
          Icons.more_vert_rounded,
          color: AppColors.textPrimary,
          size: 18,
        ),
      ),
      tooltip: 'Topic Options',
      elevation: 8,
      color: isDark ? const Color(0xFF161B22) : AppColors.textPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE5E7EB),
        ),
      ),
      onSelected: (action) {
        switch (action) {
          case 'edit':
            controller.editTopic(context, topic);
          case 'view':
            controller.viewTopic(topic);
          case 'copy':
            controller.copyLink(topic);
          case 'delete':
            controller.deleteTopicWithConfirmation(context, topic);
        }
      },
      itemBuilder: (ctx) => [
        if (isOwner)
          PopupMenuItem<String>(
            value: 'edit',
            child: Row(
              children: [
                const Icon(
                  Icons.edit_rounded,
                  size: 18,
                  color: Color(0xFF3B82F6),
                ),
                const SizedBox(width: 12),
                Text(
                  'Edit Topic',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? AppColors.textPrimary
                        : const Color(0xFF111827),
                  ),
                ),
              ],
            ),
          ),
        PopupMenuItem<String>(
          value: 'view',
          child: Row(
            children: [
              const Icon(
                Icons.visibility_rounded,
                size: 18,
                color: Color(0xFF10B981),
              ),
              const SizedBox(width: 12),
              Text(
                'View Topic',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? AppColors.textPrimary
                      : const Color(0xFF111827),
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'copy',
          child: Row(
            children: [
              const Icon(
                Icons.link_rounded,
                size: 18,
                color: Color(0xFF8B5CF6),
              ),
              const SizedBox(width: 12),
              Text(
                'Copy Link',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? AppColors.textPrimary
                      : const Color(0xFF111827),
                ),
              ),
            ],
          ),
        ),
        if (isOwner) ...[
          const PopupMenuDivider(),
          const PopupMenuItem<String>(
            value: 'delete',
            child: Row(
              children: [
                Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: AppColors.error,
                ),
                SizedBox(width: 12),
                Text(
                  'Delete Topic',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
