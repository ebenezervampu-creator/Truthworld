import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/services/notification_service.dart';
import 'package:truthworld/features/notifications/data/models/user_notification.dart';
import 'package:truthworld/features/notifications/presentation/controllers/user_notification_controller.dart';
import 'package:truthworld/features/notifications/presentation/controllers/video_feed_notification_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

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
                if (controller.isLoading.value ||
                    userNotificationController.isLoading.value) {
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
            _navigateToAlertVideo(item.alert!);
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

  Widget _buildAvatar(_UnifiedNotification item) {
    var avatarUrl = '';
    IconData? fallbackIcon;
    var fallbackBgColor = AppColors.textSecondary;

    if (item.video != null) {
      avatarUrl = item.video!.channelAvatarUrl.isNotEmpty
          ? item.video!.channelAvatarUrl
          : item.video!.channelImage;
      fallbackIcon = Icons.video_library_rounded;
    } else if (item.alert != null) {
      final metadata = item.alert!.metadata;
      avatarUrl =
          metadata?['avatarUrl'] as String? ??
          metadata?['userAvatar'] as String? ??
          '';

      switch (item.alert!.severity) {
        case NotificationSeverity.priority:
          fallbackIcon = Icons.warning_rounded;
          fallbackBgColor = const Color(0xFFEF4444);
        case NotificationSeverity.warning:
          fallbackIcon = Icons.error_outline_rounded;
          fallbackBgColor = const Color(0xFFF59E0B);
        case NotificationSeverity.success:
          fallbackIcon = Icons.star_rounded;
          fallbackBgColor = const Color(0xFF10B981);
        case NotificationSeverity.info:
          fallbackIcon = Icons.info_outline_rounded;
          fallbackBgColor = const Color(0xFF6366F1);
      }
    }

    return _DynamicAvatar(
      item: item,
      initialAvatarUrl: avatarUrl,
      fallbackIcon: fallbackIcon,
      fallbackBgColor: fallbackBgColor,
    );
  }

  Widget _buildTextContent(_UnifiedNotification item) {
    if (item.video != null) {
      final video = item.video!;
      return RichText(
        text: TextSpan(
          style: const TextStyle(
            fontSize: 14,
            height: 1.3,
            color: AppColors.textPrimary,
          ),
          children: [
            TextSpan(
              text: '${video.channelName} ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const TextSpan(
              text: 'uploaded: ',
            ),
            TextSpan(
              text: video.title,
              style: const TextStyle(color: Color(0xFFCCCCCC)),
            ),
          ],
        ),
      );
    } else if (item.alert != null) {
      final alert = item.alert!;
      final isLike = alert.type.toLowerCase().contains('like');

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            alert.title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            alert.message,
            style: TextStyle(
              fontSize: 14,
              color: isLike ? const Color(0xFF8E8E8E) : const Color(0xFFCCCCCC),
              fontStyle: isLike ? FontStyle.italic : FontStyle.normal,
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
            Get.snackbar(
              'Notification removed',
              'The notification has been deleted',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: AppColors.bgSurface,
              colorText: AppColors.textPrimary,
              duration: const Duration(seconds: 2),
            );
          } catch (e) {
            Get.snackbar('Error', 'Failed to remove notification');
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

    Get.snackbar(
      'Notifications updated',
      'Marked active notifications as read',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.bgSurface,
      colorText: AppColors.textPrimary,
      duration: const Duration(seconds: 2),
    );
  }

  void _navigateToVideo(Video notification) {
    Get.toNamed(
      '/watch?v=${notification.id}',
      arguments: {'video': notification},
    );
  }

  void _navigateToAlertVideo(UserNotification alert) {
    final videoId = alert.metadata?['videoId'] as String? ?? alert.id;
    if (alert.type == 'perspective_flip' && videoId.isNotEmpty) {
      NotificationService.to.handlePerspectiveFlipNotification(
        videoId: videoId,
        commentId: alert.metadata?['commentId'] as String?,
        replyId: alert.metadata?['replyId'] as String?,
      );
      return;
    }

    if (videoId.isNotEmpty) {
      final mockVideo = Video(
        id: videoId,
        title: alert.title,
        description: alert.message,
        thumbnailUrl: alert.metadata?['thumbnailUrl'] as String? ?? '',
        ownerId: '',
        channelId: alert.metadata?['channelId'] as String? ?? '',
        channelName: '',
        category: 'Alerts',
        tags: const [],
      );
      Get.toNamed(
        '/watch?v=${mockVideo.id}',
        arguments: {
          'video': mockVideo,
          'commentId': alert.metadata?['commentId'],
          'replyId': alert.metadata?['replyId'],
        },
      );
    } else if (alert.actionUrl != null && alert.actionUrl!.isNotEmpty) {
      try {
        if (alert.actionUrl!.startsWith('/')) {
          Get.toNamed(alert.actionUrl!);
        }
      } catch (_) {}
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

class _DynamicAvatarController extends GetxController {
  _DynamicAvatarController({
    required this.item,
    required this.initialAvatarUrl,
  });
  final _UnifiedNotification item;
  final String initialAvatarUrl;

  final RxString avatarUrl = ''.obs;
  final RxBool isLoading = false.obs;

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
    isLoading.value = true;

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
      isLoading.value = false;

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
          } catch (e) {
            debugPrint('Error updating user_notification metadata: $e');
          }
        }());
      }
    } catch (e) {
      debugPrint('Error fetching avatar in _DynamicAvatarController: $e');
      isLoading.value = false;
    }
  }

  Future<String> _performFetch(String targetId) async {
    // Check if channel exists
    final channelDoc = await FirebaseFirestore.instance
        .collection(FirestoreCollections.channels)
        .doc(targetId)
        .get();

    if (channelDoc.exists) {
      final data = channelDoc.data();
      if (data != null) {
        return data['avatarUrl'] as String? ??
            (data['profile'] as Map<String, dynamic>?)?['photoUrl']
                as String? ??
            '';
      }
    }

    // Check user document
    final userDoc = await FirebaseFirestore.instance
        .collection(FirestoreCollections.users)
        .doc(targetId)
        .get();

    if (userDoc.exists) {
      final userData = userDoc.data();
      if (userData != null) {
        final userChannelId = userData['channelId'] as String?;
        if (userChannelId != null && userChannelId.isNotEmpty) {
          final userChannelDoc = await FirebaseFirestore.instance
              .collection(FirestoreCollections.channels)
              .doc(userChannelId)
              .get();
          if (userChannelDoc.exists) {
            final chanData = userChannelDoc.data();
            if (chanData != null) {
              return chanData['avatarUrl'] as String? ??
                  (chanData['profile'] as Map<String, dynamic>?)?['photoUrl']
                      as String? ??
                  '';
            }
          }
          return '';
        } else {
          final channelsQuery = await FirebaseFirestore.instance
              .collection(FirestoreCollections.channels)
              .where('ownerId', isEqualTo: targetId)
              .limit(1)
              .get();

          if (channelsQuery.docs.isNotEmpty) {
            final chanData = channelsQuery.docs.first.data();
            return chanData['avatarUrl'] as String? ??
                (chanData['profile'] as Map<String, dynamic>?)?['photoUrl']
                    as String? ??
                '';
          }
        }

        return userData['avatarUrl'] as String? ??
            userData['photoURL'] as String? ??
            '';
      }
    }

    return '';
  }

  @override
  void onClose() {
    avatarUrl.value = '';
    isLoading.value = false;
    super.onClose();
  }
}

class _DynamicAvatar extends StatefulWidget {
  const _DynamicAvatar({
    required this.item,
    required this.initialAvatarUrl,
    required this.fallbackIcon,
    required this.fallbackBgColor,
  });
  final _UnifiedNotification item;
  final String initialAvatarUrl;
  final IconData? fallbackIcon;
  final Color fallbackBgColor;

  @override
  State<_DynamicAvatar> createState() => _DynamicAvatarState();
}

class _DynamicAvatarState extends State<_DynamicAvatar> {
  late final _DynamicAvatarController controller;

  @override
  void initState() {
    super.initState();
    controller = _DynamicAvatarController(
      item: widget.item,
      initialAvatarUrl: widget.initialAvatarUrl,
    );
  }

  @override
  void didUpdateWidget(covariant _DynamicAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    controller.updateInitialAvatarUrl(widget.initialAvatarUrl);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value) {
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: widget.fallbackBgColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.textTertiary,
                ),
              ),
            ),
          ),
        );
      }

      if (controller.avatarUrl.value.isNotEmpty) {
        return Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.textSecondary,
          ),
          clipBehavior: Clip.antiAlias,
          child: CachedNetworkImage(
            imageUrl: controller.avatarUrl.value,
            fit: BoxFit.cover,
            placeholder: (context, url) => const ColoredBox(
              color: AppColors.textSecondary,
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.textTertiary,
                    ),
                  ),
                ),
              ),
            ),
            errorWidget: (context, url, error) => _buildFallback(),
          ),
        );
      }

      return _buildFallback();
    });
  }

  Widget _buildFallback() {
    final typeLower = widget.item.alert?.type.toLowerCase() ?? '';
    if (typeLower.contains('like')) {
      return Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: Color(0xFFE50914),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Icon(
            Icons.play_arrow_rounded,
            color: AppColors.textPrimary,
            size: 24,
          ),
        ),
      );
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: widget.fallbackBgColor.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          widget.fallbackIcon ?? Icons.notifications,
          color: widget.fallbackBgColor,
          size: 20,
        ),
      ),
    );
  }
}
