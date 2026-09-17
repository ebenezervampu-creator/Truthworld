import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/notification_service.dart';
import 'package:truthworld/core/utils/studio_launcher.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/notifications/data/models/user_notification.dart';
import 'package:truthworld/features/notifications/presentation/controllers/user_notification_controller.dart';
import 'package:truthworld/features/notifications/presentation/controllers/video_feed_notification_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

// Extension for capitalize (top-level)
extension StringExtension on String {
  String get capitalize =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}

// ==========================================================================
// FIRESTORE COLLECTIONS STRUCTURE
// ==========================================================================
/*
subscriptions/
  {subscriptionId}: {
    userId: string,
    channelId: string,
    subscribedAt: timestamp
  }

videos/
  {videoId}: {
    channelId: string,
    channelName: string,
    channelImage: string,
    title: string,
    thumbnailUrl: string,
    uploadedAt: timestamp,
    views: number,
    duration: string,
    category: string (e.g., "Gaming", "Music", "Education")
  }

users/
  {userId}: {
    username: string,
    profileImage: string,
    lastSeenNotifications: timestamp,
    seenVideoIds: [videoId1, videoId2, ...]
  }
*/
// ==========================================================================
// VIDEO FEED NOTIFICATION SCREEN
// ==========================================================================

class VideoFeedNotificationScreen extends StatefulWidget {
  const VideoFeedNotificationScreen({super.key});

  @override
  State<VideoFeedNotificationScreen> createState() =>
      _VideoFeedNotificationScreenState();
}

class _VideoFeedNotificationScreenState
    extends State<VideoFeedNotificationScreen>
    with TickerProviderStateMixin {
  final VideoFeedNotificationController controller =
      Get.isRegistered<VideoFeedNotificationController>()
          ? Get.find<VideoFeedNotificationController>()
          : Get.put(VideoFeedNotificationController());
  final UserNotificationController userNotificationController = Get.find<UserNotificationController>();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final RxInt _selectedTabIndex = 0.obs;
  late AnimationController _fabAnimationController;
  final RxBool _showScrollToTop = false.obs;

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scrollController.addListener(() {
      if (_scrollController.offset > 400 && !_showScrollToTop.value) {
        _showScrollToTop.value = true;
        _fabAnimationController.forward();
      } else if (_scrollController.offset <= 400 && _showScrollToTop.value) {
        _showScrollToTop.value = false;
        _fabAnimationController.reverse();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }

  double get maxContentWidth => 720;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              _buildAppBar(),
              SliverToBoxAdapter(child: _buildPillTabs()),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              Obx(() {
                if (controller.rxIsLoading.value ||
                    userNotificationController.rxIsLoading.value) {
                  return SliverFillRemaining(child: _buildLoadingState());
                }

                if (controller.errorMessage.isNotEmpty) {
                  return SliverFillRemaining(child: _buildErrorState());
                }

                final items = _getUnifiedNotificationsForTab();
                return _buildGroupedNotificationList(items);
              }),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildFloatingButtons(),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      backgroundColor: AppColors.bgPage,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
        onPressed: Get.back,
      ),
      title: Obx(
        () => controller.isSearching.value
            ? _buildSearchBar()
            : const Text(
                'Notifications',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
      ),
      actions: [
        Obx(
          () => IconButton(
            icon: Icon(
              controller.isSearching.value
                  ? Icons.close_rounded
                  : Icons.search_rounded,
              color: AppColors.textPrimary,
            ),
            onPressed: () {
              controller.toggleSearching();
              if (!controller.isSearching.value) {
                _searchController.clear();
              }
            },
          ),
        ),
        PopupMenuButton<String>(
          icon: const Icon(
            Icons.more_vert_rounded,
            color: AppColors.textPrimary,
          ),
          onSelected: (value) {
            if (value == 'mark_all_read') {
              _markAllActiveTabAsRead();
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'mark_all_read',
              child: Row(
                children: [
                  Icon(
                    Icons.done_all_rounded,
                    size: 20,
                    color: AppColors.textPrimary,
                  ),
                  SizedBox(width: 12),
                  Text('Mark all as read'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      autofocus: true,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
      decoration: const InputDecoration(
        hintText: 'Search notifications...',
        hintStyle: TextStyle(color: AppColors.textSecondary),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: EdgeInsets.zero,
      ),
      onChanged: (value) => controller.searchQuery.value = value,
    );
  }

  Widget _buildPillTabs() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildPillButton(title: 'All', index: 0),
          const SizedBox(width: 8),
          _buildPillButton(title: 'Topics', index: 1),
          const SizedBox(width: 8),
          _buildPillButton(title: 'Comments', index: 2),
          const SizedBox(width: 8),
          _buildPillButton(title: 'Mentions', index: 3),
        ],
      ),
    );
  }

  Widget _buildPillButton({required String title, required int index}) {
    return Obx(() {
      final isSelected = _selectedTabIndex.value == index;
      return GestureDetector(
        onTap: () {
          _selectedTabIndex.value = index;
          HapticFeedback.selectionClick();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.textPrimary : const Color(0xFF272727),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? AppColors.bgPage : AppColors.textPrimary,
            ),
          ),
        ),
      );
    });
  }

  List<_UnifiedNotification> _getUnifiedNotificationsForTab() {
    final items = <_UnifiedNotification>[];
    final activeTab = _selectedTabIndex.value;
    final query = controller.searchQuery.value.trim().toLowerCase();

    // 1. Collect video upload notifications (only for "All" tab)
    if (activeTab == 0) {
      for (final v in controller.notifications) {
        if (query.isNotEmpty) {
          final titleMatch = v.title.toLowerCase().contains(query);
          final channelMatch = v.channelName.toLowerCase().contains(query);
          if (!titleMatch && !channelMatch) continue;
        }
        items.add(
          _UnifiedNotification(
            video: v,
            timestamp: v.uploadedAt.toDate(),
            isSeen: v.isSeen,
          ),
        );
      }
    }

    // 2. Collect user notifications based on tab
    for (final n in userNotificationController.notifications) {
      final typeLower = n.type.toLowerCase();
      final isMention = typeLower == 'mention';

      var belongsToTab = false;
      if (activeTab == 0) {
        belongsToTab = true; // All tab includes everything
      } else if (activeTab == 1) {
        // Topics tab: only includes new_video_topic/topic notifications
        belongsToTab =
            typeLower == 'new_video_topic' || typeLower.contains('topic');
      } else if (activeTab == 2) {
        // Comments tab: social interactions like comments, replies, and comment/video likes, excluding mentions
        belongsToTab =
            !isMention &&
            (typeLower.contains('comment') ||
                typeLower.contains('reply') ||
                typeLower.contains('like') ||
                n.typeCategory == 'social');
      } else if (activeTab == 3) {
        // Mentions tab
        belongsToTab = isMention;
      }

      if (!belongsToTab) continue;

      if (query.isNotEmpty) {
        final titleMatch = n.title.toLowerCase().contains(query);
        final messageMatch = n.message.toLowerCase().contains(query);
        if (!titleMatch && !messageMatch) continue;
      }

      items.add(
        _UnifiedNotification(
          alert: n,
          timestamp: n.createdAt,
          isSeen: n.read,
        ),
      );
    }

    // Sort by timestamp descending
    items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return items;
  }

  Widget _buildGroupedNotificationList(List<_UnifiedNotification> items) {
    if (items.isEmpty) {
      if (_selectedTabIndex.value == 1) {
        return _buildEmptyTopicsState();
      }
      if (_selectedTabIndex.value == 3) {
        return _buildEmptyMentionsState();
      }
      return _buildEmptyState();
    }

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(const Duration(days: 7));

    final todayItems = <_UnifiedNotification>[];
    final weekItems = <_UnifiedNotification>[];
    final olderItems = <_UnifiedNotification>[];

    for (final item in items) {
      if (item.timestamp.isAfter(todayStart) ||
          item.timestamp.isAtSameMomentAs(todayStart)) {
        todayItems.add(item);
      } else if (item.timestamp.isAfter(weekStart) ||
          item.timestamp.isAtSameMomentAs(weekStart)) {
        weekItems.add(item);
      } else {
        olderItems.add(item);
      }
    }

    final listWidgets = <Widget>[];

    if (todayItems.isNotEmpty) {
      listWidgets.add(_buildSectionHeader('Today'));
      for (final item in todayItems) {
        listWidgets.add(_buildCompactNotificationTile(item));
      }
    }

    if (weekItems.isNotEmpty) {
      listWidgets.add(_buildSectionHeader('This week'));
      for (final item in weekItems) {
        listWidgets.add(_buildCompactNotificationTile(item));
      }
    }

    if (olderItems.isNotEmpty) {
      listWidgets.add(_buildSectionHeader('Older'));
      for (final item in olderItems) {
        listWidgets.add(_buildCompactNotificationTile(item));
      }
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => listWidgets[index],
        childCount: listWidgets.length,
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildCompactNotificationTile(_UnifiedNotification item) {
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
              controller.markVideoAsSeen(item.video!.id);
            }
            _navigateToVideo(item.video!);
          } else if (item.alert != null) {
            if (!item.alert!.read) {
              userNotificationController.markAsRead(item.alert!.id);
            }
            _navigateToAlertNotification(item.alert!);
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
              // Left: Avatar / Status Icon
              _buildAvatar(item),
              const SizedBox(width: 12),
              // Center: Content details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTextContent(item),
                    const SizedBox(height: 4),
                    _buildTimeAgo(item),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Right: Thumbnail (if present) and popup menu
              if (thumbnailUrl.isNotEmpty) ...[
                _buildSmallThumbnail(thumbnailUrl),
                const SizedBox(width: 8),
              ],
              _buildThreeDotsButton(item),
            ],
          ),
        ),
      ),
    );
  }

  static String _getDisplayName(_UnifiedNotification item) {
    if (item.video != null) {
      return item.video!.channelName;
    }
    if (item.alert != null) {
      final meta = item.alert!.metadata;
      if (meta != null) {
        final explicitName = meta['senderName'] as String? ??
            meta['channelName'] as String? ??
            meta['userName'] as String? ??
            meta['displayName'] as String? ??
            meta['subscriberName'] as String? ??
            meta['commentAuthorName'] as String?;
        if (explicitName != null && explicitName.trim().isNotEmpty) {
          return explicitName.trim();
        }
      }
      final message = item.alert!.message;
      if (message.contains(' subscribed to your channel')) {
        return message.split(' subscribed to your channel')[0].trim();
      }
      if (message.contains(' commented:')) {
        return message.split(' commented:')[0].trim();
      }
      if (message.contains(' replied to your comment:')) {
        return message.split(' replied to your comment:')[0].trim();
      }
      if (message.contains(' liked your comment:')) {
        return message.split(' liked your comment:')[0].trim();
      }
      if (message.contains(' liked your reply:')) {
        return message.split(' liked your reply:')[0].trim();
      }
      if (message.contains(' mentioned you:')) {
        return message.split(' mentioned you:')[0].trim();
      }
      if (message.startsWith('@')) {
        final words = message.split(' ');
        if (words.isNotEmpty) return words[0].replaceAll('@', '');
      }
      if (item.alert!.title.isNotEmpty) {
        return item.alert!.title;
      }
    }
    return '';
  }

  static Color _getAvatarColor(String name) {
    final clean = name.trim().replaceAll('@', '');
    if (clean.isEmpty) return const Color(0xFF374151);
    final colors = [
      const Color(0xFFE11D48), // Rose
      const Color(0xFFD97706), // Amber
      const Color(0xFF059669), // Emerald
      const Color(0xFF0D9488), // Teal
      const Color(0xFF0284C7), // Sky
      const Color(0xFF4F46E5), // Indigo
      const Color(0xFF7C3AED), // Violet
      const Color(0xFFC026D3), // Fuchsia
      const Color(0xFFDB2777), // Pink
      const Color(0xFF2563EB), // Blue
    ];
    var hash = 0;
    for (var i = 0; i < clean.length; i++) {
      hash = clean.codeUnitAt(i) + ((hash << 5) - hash);
    }
    return colors[hash.abs() % colors.length];
  }

  Widget _buildAvatar(_UnifiedNotification item) {
    var avatarUrl = '';

    if (item.video != null) {
      avatarUrl = item.video!.channelAvatarUrl.isNotEmpty
          ? item.video!.channelAvatarUrl
          : item.video!.channelImage;
    } else if (item.alert != null) {
      final metadata = item.alert!.metadata;
      avatarUrl =
          metadata?['avatarUrl'] as String? ??
          metadata?['userAvatar'] as String? ??
          metadata?['channelAvatarUrl'] as String? ??
          metadata?['photoURL'] as String? ??
          '';
    }

    final displayName = _getDisplayName(item);

    return _DynamicAvatar(
      item: item,
      initialAvatarUrl: avatarUrl,
      displayName: displayName,
    );
  }

  Widget _buildTextContent(_UnifiedNotification item) {
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
    } else if (item.alert != null) {
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

  Widget _buildTimeAgo(_UnifiedNotification item) {
    return Text(
      _formatTimestamp(item.timestamp),
      style: const TextStyle(
        fontSize: 12,
        color: Color(0xFF8E8E8E),
      ),
    );
  }

  Widget _buildSmallThumbnail(String url) {
    return Container(
      width: 96,
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: AppColors.textSecondary,
      ),
      clipBehavior: Clip.antiAlias,
      child: CachedNetworkImage(
        imageUrl: url,
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

  Widget _buildThreeDotsButton(_UnifiedNotification item) {
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
      onSelected: (value) async {
        final userId = FirebaseAuth.instance.currentUser?.uid ?? 'guest_user';
        if (value == 'mark') {
          if (item.video != null) {
            await controller.markVideoAsSeen(item.video!.id);
          } else if (item.alert != null) {
            await userNotificationController.markAsRead(item.alert!.id);
          }
        } else if (value == 'delete') {
          try {
            if (item.video != null) {
              await FirebaseFirestore.instance
                  .collection(FirestoreCollections.users)
                  .doc(userId)
                  .collection('feed_inbox')
                  .doc(item.video!.id)
                  .delete();
              controller.notifications.removeWhere(
                (v) => v.id == item.video!.id,
              );
              controller.notifications.refresh();
            } else if (item.alert != null) {
              await FirebaseFirestore.instance
                  .collection('user_notifications')
                  .doc(item.alert!.id)
                  .delete();
              userNotificationController.notifications.removeWhere(
                (a) => a.id == item.alert!.id,
              );
              userNotificationController.notifications.refresh();
            }
            AppSnackbar.info(
              'The notification has been deleted',
              title: 'Notification removed',
            );
          } catch (e) {
            ErrorHandler.log(e, tag: 'NotificationScreen');
            AppSnackbar.error('Unable to remove notification. Please try again.');
          }
        }
      },
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

  Widget _buildEmptyTopicsState() {
    return const SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.topic_rounded,
              size: 140,
              color: Color(0xFF333333),
            ),
            SizedBox(height: 16),
            Text(
              'No topic updates yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyMentionsState() {
    return const SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.alternate_email_rounded,
              size: 140,
              color: Color(0xFF333333),
            ),
            SizedBox(height: 16),
            Text(
              'No mentions yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.textPrimary.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_off_rounded,
                size: 60,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No notifications',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'You have no notifications in this section.',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: AppColors.textPrimary.withValues(alpha: 0.6),
            strokeWidth: 3,
          ),
          const SizedBox(height: 20),
          const Text(
            'Loading...',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: 16),
          const Text(
            'Something went wrong',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              controller.refreshNotifications();
              userNotificationController.refreshNotifications();
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingButtons() {
    return Obx(() {
      final items = _getUnifiedNotificationsForTab();
      final hasUnread = items.any((item) => !item.isSeen);

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_showScrollToTop.value)
            ScaleTransition(
              scale: _fabAnimationController,
              child: FloatingActionButton(
                heroTag: 'scroll_top',
                mini: true,
                onPressed: () {
                  _scrollController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                  );
                  HapticFeedback.lightImpact();
                },
                backgroundColor: AppColors.bgSurface,
                child: const Icon(
                  Icons.keyboard_arrow_up_rounded,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          const SizedBox(height: 12),
          if (hasUnread)
            FloatingActionButton.extended(
              heroTag: 'mark_seen',
              onPressed: () {
                _markAllActiveTabAsRead();
                HapticFeedback.mediumImpact();
              },
              icon: const Icon(Icons.done_all_rounded, color: AppColors.bgPage),
              label: const Text(
                'Mark All Read',
                style: TextStyle(
                  color: AppColors.bgPage,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: AppColors.textPrimary,
              elevation: 8,
            ),
        ],
      );
    });
  }

  void _markAllActiveTabAsRead() {
    final items = _getUnifiedNotificationsForTab();
    final unreadItems = items.where((item) => !item.isSeen).toList();

    if (unreadItems.isEmpty) return;

    final videoIds = <String>[];
    final alertIds = <String>[];

    for (final item in unreadItems) {
      if (item.video != null) {
        videoIds.add(item.video!.id);
      } else if (item.alert != null) {
        alertIds.add(item.alert!.id);
      }
    }

    if (videoIds.isNotEmpty) {
      controller.markAllAsSeen();
    }
    if (alertIds.isNotEmpty) {
      userNotificationController.markAllAsRead();
    }

    AppSnackbar.info(
      'Marked active notifications as read',
      title: 'Notifications updated',
    );
  }

  void _navigateToVideo(Video notification) {
    Get.toNamed(
      '/watch?v=${notification.id}',
      arguments: {'video': notification},
    );
  }

  void _navigateToAlertNotification(UserNotification alert) {
    final typeLower = alert.type.toLowerCase();
    final titleLower = alert.title.toLowerCase();
    final messageLower = alert.message.toLowerCase();

    // 1. Check if notification is a New Subscriber / Follower / Creator Studio notification
    final isSubscriberNotification = typeLower == 'new_follower' ||
        typeLower == 'subscriber' ||
        typeLower == 'new_subscriber' ||
        typeLower == 'subscription' ||
        typeLower == 'subscribers_milestone' ||
        typeLower.contains('subscriber') ||
        typeLower.contains('follower') ||
        titleLower.contains('subscriber') ||
        titleLower.contains('subscribers') ||
        messageLower.contains('subscribed to your channel') ||
        messageLower.contains('subscribed');

    final isStudioNotification = isSubscriberNotification ||
        typeLower == 'creator_intelligence' ||
        typeLower == 'coach_growth_tip' ||
        typeLower == 'coach_growth_tip_v1' ||
        typeLower == 'subscribers_milestone_v1' ||
        typeLower == 'analytics_alert' ||
        typeLower == 'monetization' ||
        (alert.actionUrl != null &&
            alert.actionUrl!.toLowerCase().contains('studio'));

    if (isStudioNotification) {
      StudioLauncher.openStudio();
      return;
    }

    // 2. Check for Perspective Flip notification
    final videoId = alert.metadata?['videoId'] as String? ??
        alert.metadata?['targetVideoId'] as String? ??
        alert.metadata?['video_id'] as String?;

    if (alert.type == 'perspective_flip' &&
        videoId != null &&
        videoId.isNotEmpty) {
      NotificationService.to.handlePerspectiveFlipNotification(
        videoId: videoId,
        commentId: alert.metadata?['commentId'] as String?,
        replyId: alert.metadata?['replyId'] as String?,
      );
      return;
    }

    // 3. Check for specific Video-related notifications (Comment, Reply, Like, Mention, Video update)
    if (videoId != null && videoId.isNotEmpty) {
      final commentId = alert.metadata?['commentId'] as String?;
      final replyId = alert.metadata?['replyId'] as String?;

      Get.toNamed(
        '/watch?v=$videoId',
        arguments: {
          'videoId': videoId,
          'commentId': ?commentId,
          'replyId': ?replyId,
        },
      );
      return;
    }

    // 4. Action URL routing (e.g. /channel/xxx, /post/xxx, /topic/xxx, /community-guidelines, etc.)
    final actionUrl = alert.actionUrl;
    if (actionUrl != null && actionUrl.isNotEmpty) {
      try {
        if (actionUrl.startsWith('/')) {
          Get.toNamed(actionUrl);
          return;
        } else if (actionUrl.startsWith('http://') ||
            actionUrl.startsWith('https://')) {
          final uri = Uri.parse(actionUrl);
          launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'NotificationScreen._handleAlertTap');
      }
    }

    // 5. If channelId is present in metadata, navigate to channel details
    final channelId = alert.metadata?['channelId'] as String? ??
        alert.metadata?['subscriberChannelId'] as String? ??
        alert.metadata?['mentionedChannelId'] as String?;
    if (channelId != null && channelId.isNotEmpty) {
      Get.toNamed('/channel/$channelId');
      return;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.isNegative || difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}w ago';
    } else {
      return '${(difference.inDays / 30).floor()}mo ago';
    }
  }
}

class _UnifiedNotification {
  _UnifiedNotification({
    required this.timestamp,
    required this.isSeen,
    this.video,
    this.alert,
  });
  final Video? video;
  final UserNotification? alert;
  final DateTime timestamp;
  final bool isSeen;
}

class _DynamicAvatarController extends BaseController {
  _DynamicAvatarController({
    required this.item,
    required this.initialAvatarUrl,
  });
  final _UnifiedNotification item;
  final String initialAvatarUrl;

  final RxString avatarUrl = ''.obs;
  final RxBool rxIsLoading = false.obs;

  // Persistent local cache to eliminate repeat Firestore lookups
  static final _storage = GetStorage('AvatarCache');
  static final Map<String, String> _avatarCache = {};
  static final Map<String, Future<String>> _avatarFetchFutures = {};

  @override
  void onInit() {
    super.onInit();
    avatarUrl.value = initialAvatarUrl;
    if (avatarUrl.value.isEmpty) {
      fetchAvatarIfNeeded();
    }
  }

  void updateInitialAvatarUrl(String url) {
    if (avatarUrl.value != url) {
      avatarUrl.value = url;
      if (avatarUrl.value.isEmpty) {
        fetchAvatarIfNeeded();
      }
    }
  }

  Future<void> fetchAvatarIfNeeded() async {
    final alert = item.alert;
    if (alert == null) return;
    final metadata = alert.metadata;
    if (metadata == null) return;

    // Check action performer's ID first, instead of the video owner's channelId!
    final targetId =
        metadata['subscriberId'] as String? ??
        metadata['likerId'] as String? ??
        metadata['commentAuthorId'] as String? ??
        metadata['senderUserId'] as String? ??
        metadata['channelId'] as String? ??
        '';

    if (targetId.isEmpty) return;

    // 1. In-memory Cache lookup
    if (_avatarCache.containsKey(targetId)) {
      avatarUrl.value = _avatarCache[targetId]!;
      return;
    }

    // 2. Persistent Disk Cache lookup (O(1) local read, 0ms latency, 0 costs!)
    final cachedUrl = _storage.read(targetId);
    if (cachedUrl != null && cachedUrl.isNotEmpty) {
      _avatarCache[targetId] = cachedUrl;
      avatarUrl.value = cachedUrl;
      return;
    }

    // 3. Fallback: Firestore async resolve (non-blocking)
    rxIsLoading.value = true;

    try {
      Future<String> fetchFuture;
      if (_avatarFetchFutures.containsKey(targetId)) {
        fetchFuture = _avatarFetchFutures[targetId]!;
      } else {
        fetchFuture = _performFetch(targetId);
        _avatarFetchFutures[targetId] = fetchFuture;
      }

      final url = await fetchFuture;
      _avatarFetchFutures.remove(targetId);

      if (url.isNotEmpty) {
        _avatarCache[targetId] = url;
        _storage.write(targetId, url);
      }

      avatarUrl.value = url;
      rxIsLoading.value = false;

      // Update Firestore document metadata so we never hit this fallback again
      final currentMetaAvatar =
          metadata['userAvatar'] as String? ??
          metadata['avatarUrl'] as String? ??
          '';
      if (currentMetaAvatar.isEmpty && url.isNotEmpty) {
        unawaited(() async {
          try {
            final updatedMetadata = Map<String, dynamic>.from(metadata);
            updatedMetadata['userAvatar'] = url;
            await FirebaseFirestore.instance
                .collection('user_notifications')
                .doc(alert.id)
                .update({'metadata': updatedMetadata});
          } catch (e, s) {
            ErrorHandler.log(e, stackTrace: s, tag: '_DynamicAvatarController.metadata');
          }
        }());
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: '_DynamicAvatarController.fetchAvatar');
    } finally {
      rxIsLoading.value = false;
    }
  }

  Future<String> _performFetch(String targetId) async {
    try {
      // 1. Check user document first (performer of action)
      final userDoc = await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(targetId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data();
        if (userData != null) {
          final photo = userData['avatarUrl'] as String? ??
              userData['photoURL'] as String? ??
              userData['photoUrl'] as String? ??
              '';
          if (photo.isNotEmpty) return photo;

          final userChannelId = userData['channelId'] as String?;
          if (userChannelId != null && userChannelId.isNotEmpty) {
            final userChannelDoc = await FirebaseFirestore.instance
                .collection(FirestoreCollections.channels)
                .doc(userChannelId)
                .get();
            if (userChannelDoc.exists) {
              final chanData = userChannelDoc.data();
              if (chanData != null) {
                final chanPhoto = chanData['avatarUrl'] as String? ??
                    chanData['channelImage'] as String? ??
                    (chanData['profile'] as Map<String, dynamic>?)?['photoUrl']
                        as String? ??
                    '';
                if (chanPhoto.isNotEmpty) return chanPhoto;
              }
            }
          }
        }
      }

      // 2. Check channel document
      final channelDoc = await FirebaseFirestore.instance
          .collection(FirestoreCollections.channels)
          .doc(targetId)
          .get();

      if (channelDoc.exists) {
        final data = channelDoc.data();
        if (data != null) {
          final photo = data['avatarUrl'] as String? ??
              data['channelImage'] as String? ??
              (data['profile'] as Map<String, dynamic>?)?['photoUrl']
                  as String? ??
              '';
          if (photo.isNotEmpty) return photo;
        }
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: '_DynamicAvatarController._performFetch');
    }

    return '';
  }

  @override
  void onClose() {
    avatarUrl.value = '';
    rxIsLoading.value = false;
    super.onClose();
  }
}

class _DynamicAvatar extends StatelessWidget {
  const _DynamicAvatar({
    required this.item,
    required this.initialAvatarUrl,
    required this.displayName,
  });
  final _UnifiedNotification item;
  final String initialAvatarUrl;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<_DynamicAvatarController>(
      init: _DynamicAvatarController(
        item: item,
        initialAvatarUrl: initialAvatarUrl,
      ),
      tag: item.video?.id ?? item.alert?.id ?? displayName,
      builder: (controller) {
        return Obx(() {
          final url = controller.avatarUrl.value;
          if (url.isNotEmpty) {
            return Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF272727),
              ),
              clipBehavior: Clip.antiAlias,
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (context, url) => _buildPlaceholderAvatar(),
                errorWidget: (context, url, error) => _buildPlaceholderAvatar(),
              ),
            );
          }

          return _buildPlaceholderAvatar();
        });
      },
    );
  }

  Widget _buildPlaceholderAvatar() {
    final cleanName = displayName.trim().replaceAll('@', '');
    final initial = cleanName.isNotEmpty ? cleanName[0].toUpperCase() : '';
    final bgColor =
        _VideoFeedNotificationScreenState._getAvatarColor(cleanName);

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: initial.isNotEmpty
          ? Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                height: 1.0,
              ),
            )
          : const Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: 22,
            ),
    );
  }
}
