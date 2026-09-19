import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/notifications/presentation/controllers/notification_view_controller.dart';
import 'package:truthworld/features/notifications/presentation/views/notifications/widgets/notification_avatar.dart';
import 'package:truthworld/features/notifications/presentation/views/notifications/widgets/notification_models.dart';
import 'package:truthworld/features/notifications/presentation/views/notifications/widgets/notification_navigation_handler.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Compact list tile rendering a unified notification item with dynamic avatar,
/// formatted message text, time ago, optional thumbnail, and action menu.
class CompactNotificationTile extends StatelessWidget {
  const CompactNotificationTile({
    required this.item,
    required this.viewController,
    super.key,
  });

  final UnifiedNotificationItem item;
  final NotificationViewController viewController;

  @override
  Widget build(BuildContext context) {
    var thumbnailUrl = '';
    if (item.video != null) {
      thumbnailUrl = item.video!.thumbnailUrl;
    } else if (item.alert != null) {
      thumbnailUrl = item.alert!.metadata?['thumbnailUrl'] as String? ?? '';
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (item.video != null) {
            if (!item.video!.isSeen) {
              viewController.feedController.markVideoAsSeen(item.video!.id);
            }
            NotificationNavigationHandler.navigateToVideo(item.video!);
          } else if (item.alert != null) {
            if (!item.alert!.read) {
              viewController.userNotificationController.markAsRead(item.alert!.id);
            }
            NotificationNavigationHandler.navigateToAlertNotification(item.alert!);
          }
          HapticFeedback.lightImpact();
        },
        child: Container(
          color: item.isSeen
              ? Colors.transparent
              : AppColors.textPrimary.withValues(alpha: 0.05),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(item),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    NotificationTextContent(item: item),
                    const SizedBox(height: 4),
                    Text(
                      NotificationNavigationHandler.formatNotificationTimestamp(
                        item.timestamp,
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8E8E8E),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (thumbnailUrl.isNotEmpty) ...[
                NotificationThumbnail(imageUrl: thumbnailUrl),
                const SizedBox(width: 8),
              ],
              NotificationActionMenu(
                item: item,
                viewController: viewController,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(UnifiedNotificationItem item) {
    var avatarUrl = '';

    if (item.video != null) {
      avatarUrl = item.video!.channelAvatarUrl.isNotEmpty
          ? item.video!.channelAvatarUrl
          : item.video!.channelImage;
    } else if (item.alert != null) {
      final metadata = item.alert!.metadata;
      avatarUrl = metadata?['avatarUrl'] as String? ??
          metadata?['userAvatar'] as String? ??
          metadata?['channelAvatarUrl'] as String? ??
          metadata?['photoURL'] as String? ??
          '';
    }

    final displayName = NotificationNavigationHandler.getDisplayName(item);

    return DynamicNotificationAvatar(
      item: item,
      initialAvatarUrl: avatarUrl,
      displayName: displayName,
    );
  }
}

/// Renders 16:9 thumbnail preview for video notifications.
class NotificationThumbnail extends StatelessWidget {
  const NotificationThumbnail({
    required this.imageUrl,
    super.key,
  });

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: AppColors.textSecondary,
      ),
      clipBehavior: Clip.antiAlias,
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => const ColoredBox(
          color: AppColors.textSecondary,
          child: Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.textDisabled,
                ),
              ),
            ),
          ),
        ),
        errorWidget: (context, url, error) => const SizedBox.shrink(),
      ),
    );
  }
}

/// Renders structured notification text (channel name, video title or user alert message).
class NotificationTextContent extends StatelessWidget {
  const NotificationTextContent({
    required this.item,
    super.key,
  });

  final UnifiedNotificationItem item;

  @override
  Widget build(BuildContext context) {
    if (item.video != null) {
      final video = item.video!;
      return RichText(
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          style: const TextStyle(
            fontSize: 14,
            height: 1.35,
            color: AppColors.textPrimary,
          ),
          children: [
            TextSpan(
              text: '${video.channelName} ',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const TextSpan(
              text: 'uploaded: ',
              style: TextStyle(color: Color(0xFFCCCCCC)),
            ),
            TextSpan(
              text: video.title,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    if (item.alert != null) {
      final alert = item.alert!;
      final message = alert.message;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (alert.title.isNotEmpty && !message.startsWith(alert.title)) ...[
            Text(
              alert.title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
          ],
          Text(
            message.isNotEmpty ? message : alert.title,
            style: const TextStyle(
              fontSize: 14,
              height: 1.3,
              color: Color(0xFFE0E0E0),
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }
}

/// Three-dots popup menu providing actions to mark as read/unseen or delete notifications.
class NotificationActionMenu extends StatelessWidget {
  const NotificationActionMenu({
    required this.item,
    required this.viewController,
    super.key,
  });

  final UnifiedNotificationItem item;
  final NotificationViewController viewController;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(
        Icons.more_vert_rounded,
        color: Color(0xFF8E8E8E),
        size: 20,
      ),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      style: const ButtonStyle(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onSelected: _handleAction,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'mark',
          child: Text(item.isSeen ? 'Mark as unseen' : 'Mark as read'),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Text('Delete notification'),
        ),
      ],
    );
  }

  Future<void> _handleAction(String action) async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'guest_user';
    if (action == 'mark') {
      if (item.video != null) {
        await viewController.feedController.markVideoAsSeen(item.video!.id);
      } else if (item.alert != null) {
        await viewController.userNotificationController.markAsRead(item.alert!.id);
      }
    } else if (action == 'delete') {
      try {
        if (item.video != null) {
          await FirebaseFirestore.instance
              .collection(FirestoreCollections.users)
              .doc(userId)
              .collection('feed_inbox')
              .doc(item.video!.id)
              .delete();
          viewController.feedController.notifications.removeWhere(
            (v) => v.id == item.video!.id,
          );
          viewController.feedController.notifications.refresh();
        } else if (item.alert != null) {
          await FirebaseFirestore.instance
              .collection('user_notifications')
              .doc(item.alert!.id)
              .delete();
          viewController.userNotificationController.notifications.removeWhere(
            (a) => a.id == item.alert!.id,
          );
          viewController.userNotificationController.notifications.refresh();
        }
        AppSnackbar.info(
          'The notification has been deleted',
          title: 'Notification removed',
        );
      } catch (e) {
        ErrorHandler.log(e, tag: 'NotificationActionMenu');
        AppSnackbar.error('Unable to remove notification. Please try again.');
      }
    }
  }
}
