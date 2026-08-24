import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/topic_management_controller.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/theme/app_theme.dart';

/// More Options Popup Menu for Topic Card (Edit, View, Copy Link, Delete)
/// Matches exact Channel Creation page popup styling & white icon guidelines.
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
          color: const Color(0xFF18181B),
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFF27272A),
          ),
        ),
        child: const Icon(
          Icons.more_vert_rounded,
          color: Colors.white,
          size: 18,
        ),
      ),
      tooltip: 'Topic Options',
      elevation: 8,
      color: const Color(0xFF18181B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(
          color: Color(0xFF27272A),
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
          const PopupMenuItem<String>(
            value: 'edit',
            child: Row(
              children: [
                Icon(
                  Icons.edit_rounded,
                  size: 18,
                  color: Colors.white,
                ),
                SizedBox(width: 12),
                Text(
                  'Edit Topic',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        const PopupMenuItem<String>(
          value: 'view',
          child: Row(
            children: [
              Icon(
                Icons.visibility_rounded,
                size: 18,
                color: Colors.white,
              ),
              SizedBox(width: 12),
              Text(
                'View Topic',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'copy',
          child: Row(
            children: [
              Icon(
                Icons.link_rounded,
                size: 18,
                color: Colors.white,
              ),
              SizedBox(width: 12),
              Text(
                'Copy Link',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
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
                  color: Colors.white,
                ),
                SizedBox(width: 12),
                Text(
                  'Delete Topic',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
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
