import 'dart:async';
import 'package:truthworld/components/ui/back_symbol.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/notifications/data/models/user_notification.dart';
import 'package:truthworld/features/notifications/data/services/user_notification_service.dart';

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
// VIDEO FEED NOTIFICATION MODEL
// ==========================================================================

// ==========================================================================
// VIDEO FEED NOTIFICATION SERVICE (Feed Reconstruction)
// ==========================================================================

class VideoFeedNotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const int defaultVideoLimit = 50;

  // ==========================================================================
  // 🔥 O(1) MATERIALIZED FEED STREAM
  // ==========================================================================
  Stream<List<Video>> getVideoNotificationsStream(
    String userId, {
    int limit = defaultVideoLimit,
  }) {
    if (userId == 'guest_user' || userId.isEmpty) {
      return Stream.value([]);
    }

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('feed_inbox')
        .orderBy('uploadedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => _mapInboxToVideo(doc)).toList();
    });
  }

  // ==========================================================================
  // 🔥 FETCH NOTIFICATIONS ONCE
  // ==========================================================================
  Future<List<Video>> getVideoNotificationsOnce(
    String userId, {
    int limit = defaultVideoLimit,
  }) async {
    if (userId == 'guest_user' || userId.isEmpty) {
      return [];
    }

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('feed_inbox')
          .orderBy('uploadedAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => _mapInboxToVideo(doc)).toList();
    } catch (e) {
      debugPrint('Error fetching materialized notifications once: $e');
      return [];
    }
  }

  // ==========================================================================
  // 🔥 MARK VIDEO AS SEEN
  // ==========================================================================
  Future<void> markVideoAsSeen(String userId, String videoId) async {
    if (userId == 'guest_user' || userId.isEmpty) return;
    try {
      // ⚡ SCALE FIX: Removed legacy seenVideoIds arrayUnion — unbounded array growth.
      // The feed_inbox isSeen flag is the authoritative source of truth.

      // Flag the specific feed inbox document as seen
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('feed_inbox')
          .doc(videoId)
          .update({'isSeen': true});

      // Update lastSeenNotifications timestamp only (no array)
      await _firestore.collection('users').doc(userId).update({
        'lastSeenNotifications': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error marking video as seen: $e');
    }
  }

  // ==========================================================================
  // 🔥 MARK ALL AS SEEN
  // ==========================================================================
  Future<void> markAllAsSeen(String userId, List<String> videoIds) async {
    if (userId == 'guest_user' || userId.isEmpty || videoIds.isEmpty) return;
    try {
      // ⚡ SCALE FIX: Removed legacy seenVideoIds arrayUnion — unbounded array growth.
      // Only update lastSeenNotifications timestamp and feed_inbox flags.
      await _firestore.collection('users').doc(userId).update({
        'lastSeenNotifications': FieldValue.serverTimestamp(),
      });

      // Perform optimal batched status propagation across feed_inbox
      final batch = _firestore.batch();
      for (final vid in videoIds) {
        final ref = _firestore
            .collection('users')
            .doc(userId)
            .collection('feed_inbox')
            .doc(vid);
        batch.update(ref, {'isSeen': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error batch marking all as seen: $e');
    }
  }

  // ==========================================================================
  // 🔥 INTERNAL DOCUMENT MAPPER
  // ==========================================================================
  Video _mapInboxToVideo(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final id = doc.id;
    final title = data['title'] as String? ?? '';
    final channelId = data['channelId'] as String? ?? '';
    final channelName = data['channelName'] as String? ?? '';
    final channelImage = data['channelImage'] as String? ?? '';
    final thumbnailUrl = data['thumbnailUrl'] as String? ?? '';
    final category = data['category'] as String? ?? 'General';
    final isSeen = data['isSeen'] as bool? ?? false;

    Timestamp createdAt = Timestamp.now();
    if (data['uploadedAt'] is Timestamp) {
      createdAt = data['uploadedAt'] as Timestamp;
    } else if (data['createdAt'] is Timestamp) {
      createdAt = data['createdAt'] as Timestamp;
    }

    int viewCount = 0;
    if (data['views'] is int) {
      viewCount = data['views'] as int;
    } else if (data['viewCount'] is int) {
      viewCount = data['viewCount'] as int;
    } else {
      viewCount = int.tryParse(data['views']?.toString() ?? '0') ?? 0;
    }

    Duration durationValue = Duration.zero;
    final durStr = data['duration']?.toString() ?? '';
    if (durStr.isNotEmpty && durStr.contains(':')) {
      final parts = durStr.split(':');
      if (parts.length == 3) {
        durationValue = Duration(
          hours: int.tryParse(parts[0]) ?? 0,
          minutes: int.tryParse(parts[1]) ?? 0,
          seconds: int.tryParse(parts[2]) ?? 0,
        );
      } else if (parts.length == 2) {
        durationValue = Duration(
          minutes: int.tryParse(parts[0]) ?? 0,
          seconds: int.tryParse(parts[1]) ?? 0,
        );
      }
    }

    final video = Video(
      id: id,
      title: title,
      description: '',
      thumbnailUrl: thumbnailUrl,
      ownerId: channelId,
      channelId: channelId,
      channelName: channelName,
      channelAvatarUrl: channelImage,
      category: category,
      tags: const [],
      viewCount: viewCount,
      vDurationValue: durationValue,
      createdAt: createdAt,
    );
    video.isSeen = isSeen;
    return video;
  }
}

// ==========================================================================
// VIDEO FEED NOTIFICATION CONTROLLER
// ==========================================================================

class VideoFeedNotificationController extends GetxController {
  final VideoFeedNotificationService _service = VideoFeedNotificationService();

  var notifications = <Video>[].obs;
  var isLoading = true.obs;
  var errorMessage = ''.obs;
  var selectedTimeFilter = 'all'.obs;
  var selectedSeenFilter = 'all'.obs;
  var selectedCategory = 'all'.obs;
  var searchQuery = ''.obs;
  var isSearching = false.obs;

  StreamSubscription<List<Video>>? _subscription;
  final String userId = FirebaseAuth.instance.currentUser?.uid ?? 'guest_user';

  @override
  void onInit() {
    super.onInit();
    _listenToNotifications();
  }

  @override
  void onClose() {
    _subscription?.cancel();
    super.onClose();
  }

  void _listenToNotifications() {
    isLoading.value = true;
    errorMessage.value = '';

    _subscription = _service
        .getVideoNotificationsStream(userId, limit: 100)
        .listen(
          (notificationList) {
            notifications.value = notificationList;
            isLoading.value = false;
          },
          onError: (error) {
            errorMessage.value = error.toString();
            isLoading.value = false;
          },
        );
  }

  void setTimeFilter(String filter) {
    selectedTimeFilter.value = filter;
    HapticFeedback.selectionClick();
  }

  void setSeenFilter(String filter) {
    selectedSeenFilter.value = filter;
    HapticFeedback.selectionClick();
  }

  void setCategory(String category) {
    selectedCategory.value = category;
    HapticFeedback.selectionClick();
  }

  void toggleSearching() {
    isSearching.value = !isSearching.value;
    if (!isSearching.value) {
      searchQuery.value = '';
    }
  }

  Future<void> markVideoAsSeen(String videoId) async {
    await _service.markVideoAsSeen(userId, videoId);
    final index = notifications.indexWhere((n) => n.id == videoId);
    if (index != -1) {
      notifications[index].isSeen = true;
      notifications.refresh();
    }
  }

  Future<void> markAllAsSeen() async {
    try {
      final videoIds = notifications.map((n) => n.id).toList();
      await _service.markAllAsSeen(userId, videoIds);
      for (var notification in notifications) {
        notification.isSeen = true;
      }
      notifications.refresh();
      Get.snackbar(
        'Success',
        'All videos marked as seen',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF10B981),
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
        margin: EdgeInsets.all(16),
        borderRadius: 12,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to mark all as seen',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFEF4444),
        colorText: Colors.white,
      );
    }
  }

  Future<void> refreshNotifications() async {
    try {
      final fresh = await _service.getVideoNotificationsOnce(userId);
      notifications.value = fresh;
    } catch (e) {
      errorMessage.value = e.toString();
    }
  }

  List<Video> get filteredNotifications {
    var filtered = notifications.toList();

    // Search filter
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((n) {
        return n.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
            n.channelName.toLowerCase().contains(searchQuery.toLowerCase());
      }).toList();
    }

    // Time filter
    final now = DateTime.now();
    switch (selectedTimeFilter.value) {
      case 'today':
        filtered = filtered.where((n) {
          return n.uploadedAt.toDate().year == now.year &&
              n.uploadedAt.toDate().month == now.month &&
              n.uploadedAt.toDate().day == now.day;
        }).toList();
        break;
      case 'this_week':
        final weekAgo = now.subtract(const Duration(days: 7));
        filtered = filtered
            .where((n) => n.uploadedAt.toDate().isAfter(weekAgo))
            .toList();
        break;
      case 'this_month':
        filtered = filtered.where((n) {
          return n.uploadedAt.toDate().year == now.year &&
              n.uploadedAt.toDate().month == now.month;
        }).toList();
        break;
    }

    // Seen filter
    switch (selectedSeenFilter.value) {
      case 'unseen':
        filtered = filtered.where((n) => !n.isSeen).toList();
        break;
      case 'seen':
        filtered = filtered.where((n) => n.isSeen).toList();
        break;
    }

    // Category filter
    if (selectedCategory.value != 'all') {
      filtered = filtered
          .where((n) => n.category == selectedCategory.value)
          .toList();
    }

    return filtered;
  }

  List<String> get availableCategories {
    final categories = notifications.map((n) => n.category).toSet().toList();
    categories.sort();
    return ['all', ...categories];
  }

  int get unseenCount => notifications.where((n) => !n.isSeen).length;
  int get todayCount {
    final now = DateTime.now();
    return notifications.where((n) {
      final uploadDate = n.uploadedAt.toDate();
      return uploadDate.year == now.year &&
          uploadDate.month == now.month &&
          uploadDate.day == now.day;
    }).length;
  }
}

// ==========================================================================
// USER NOTIFICATION CONTROLLER (Cloud Functions Alerts)
// ==========================================================================

class UserNotificationController extends GetxController {
  final UserNotificationService _service = UserNotificationService();
  final String userId = FirebaseAuth.instance.currentUser?.uid ?? 'guest_user';

  var notifications = <UserNotification>[].obs;
  var isLoading = true.obs;
  var selectedSeverityFilter = 'all'.obs;

  StreamSubscription<List<UserNotification>>? _subscription;

  @override
  void onInit() {
    super.onInit();
    _listenToCloudNotifications();
  }

  @override
  void onClose() {
    _subscription?.cancel();
    super.onClose();
  }

  void _listenToCloudNotifications() {
    isLoading.value = true;
    _subscription = _service.getNotificationsStream(userId, limit: 100).listen(
      (list) {
        notifications.value = list;
        isLoading.value = false;
      },
      onError: (err) {
        debugPrint('Error streaming cloud notifications: $err');
        isLoading.value = false;
      },
    );
  }

  void setSeverityFilter(String severity) {
    selectedSeverityFilter.value = severity;
    HapticFeedback.selectionClick();
  }

  Future<void> markAsRead(String notificationId) async {
    final success = await _service.markAsRead(notificationId);
    if (success) {
      final index = notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        notifications[index].read = true;
        notifications.refresh();
      }
    }
  }

  Future<void> markAllAsRead() async {
    final unreadIds = notifications.where((n) => !n.read).map((n) => n.id).toList();
    if (unreadIds.isEmpty) return;

    await _service.markAllAsReadBatch(userId, unreadIds);
    for (var n in notifications) {
      n.read = true;
    }
    notifications.refresh();
    HapticFeedback.mediumImpact();
  }

  Future<void> refreshNotifications() async {
    isLoading.value = true;
    final fresh = await _service.fetchNotificationsViaCallable(limit: 100);
    if (fresh.isNotEmpty) {
      notifications.value = fresh;
    }
    isLoading.value = false;
  }

  List<UserNotification> get filteredNotifications {
    final nonMentions = notifications.where((n) => n.type.toLowerCase() != 'mention').toList();
    if (selectedSeverityFilter.value == 'all') {
      return nonMentions;
    }
    return nonMentions
        .where((n) =>
            n.severity.name.toLowerCase() ==
            selectedSeverityFilter.value.toLowerCase())
        .toList();
  }

  int get unreadCount => notifications.where((n) => !n.read).length;

  Future<void> markAllMentionsAsRead() async {
    final unreadMentions = notifications.where((n) => n.type.toLowerCase() == 'mention' && !n.read).toList();
    if (unreadMentions.isEmpty) return;

    final unreadIds = unreadMentions.map((n) => n.id).toList();
    await _service.markAllAsReadBatch(userId, unreadIds);
    for (var n in notifications) {
      if (n.type.toLowerCase() == 'mention') {
        n.read = true;
      }
    }
    notifications.refresh();
    HapticFeedback.mediumImpact();
  }

  Future<void> markAllNonMentionsAsRead() async {
    final unreadNonMentions = notifications.where((n) => n.type.toLowerCase() != 'mention' && !n.read).toList();
    if (unreadNonMentions.isEmpty) return;

    final unreadIds = unreadNonMentions.map((n) => n.id).toList();
    await _service.markAllAsReadBatch(userId, unreadIds);
    for (var n in notifications) {
      if (n.type.toLowerCase() != 'mention') {
        n.read = true;
      }
    }
    notifications.refresh();
    HapticFeedback.mediumImpact();
  }
}

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
  final controller = Get.put(VideoFeedNotificationController());
  final userNotificationController = Get.put(UserNotificationController());
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
                if (controller.isLoading.value || userNotificationController.isLoading.value) {
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
      floating: false,
      pinned: true,
      backgroundColor: AppColors.bgPage,
      elevation: 0,
      leading: IconButton(
        icon: const BackSymbol(color: Colors.white),
        onPressed: () => Get.back(),
      ),
      title: Obx(() => controller.isSearching.value
          ? _buildSearchBar()
          : Text(
              "Notifications",
              style: GoogleFonts.roboto(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            )),
      actions: [
        Obx(() => IconButton(
              icon: Icon(
                controller.isSearching.value
                    ? Icons.close_rounded
                    : Icons.search_rounded,
                color: Colors.white,
              ),
              onPressed: () {
                controller.toggleSearching();
                if (!controller.isSearching.value) {
                  _searchController.clear();
                }
              },
            )),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
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
                  Icon(Icons.done_all_rounded, size: 20, color: Colors.white),
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
      style: GoogleFonts.roboto(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        hintText: 'Search notifications...',
        hintStyle: GoogleFonts.roboto(color: Colors.white60),
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
          _buildPillButton(title: 'Comments', index: 1),
          const SizedBox(width: 8),
          _buildPillButton(title: 'Mentions', index: 2),
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
            color: isSelected ? Colors.white : const Color(0xFF272727),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: GoogleFonts.roboto(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? Colors.black : Colors.white,
            ),
          ),
        ),
      );
    });
  }

  List<_UnifiedNotification> _getUnifiedNotificationsForTab() {
    final List<_UnifiedNotification> items = [];
    final int activeTab = _selectedTabIndex.value;
    final String query = controller.searchQuery.value.trim().toLowerCase();

    // 1. Collect video upload notifications (only for "All" tab)
    if (activeTab == 0) {
      for (final v in controller.notifications) {
        if (query.isNotEmpty) {
          final titleMatch = v.title.toLowerCase().contains(query);
          final channelMatch = v.channelName.toLowerCase().contains(query);
          if (!titleMatch && !channelMatch) continue;
        }
        items.add(_UnifiedNotification(
          video: v,
          timestamp: v.uploadedAt.toDate(),
          isSeen: v.isSeen,
        ));
      }
    }

    // 2. Collect user notifications based on tab
    for (final n in userNotificationController.notifications) {
      final typeLower = n.type.toLowerCase();
      final isMention = typeLower == 'mention';

      bool belongsToTab = false;
      if (activeTab == 0) {
        belongsToTab = true; // All tab includes everything
      } else if (activeTab == 1) {
        // Comments tab: social interactions like comments, replies, and comment/video likes, excluding mentions
        belongsToTab = !isMention && (
          typeLower.contains('comment') ||
          typeLower.contains('reply') ||
          typeLower.contains('like') ||
          n.typeCategory == 'social'
        );
      } else if (activeTab == 2) {
        // Mentions tab
        belongsToTab = isMention;
      }

      if (!belongsToTab) continue;

      if (query.isNotEmpty) {
        final titleMatch = n.title.toLowerCase().contains(query);
        final messageMatch = n.message.toLowerCase().contains(query);
        if (!titleMatch && !messageMatch) continue;
      }

      items.add(_UnifiedNotification(
        alert: n,
        timestamp: n.createdAt,
        isSeen: n.read,
      ));
    }

    // Sort by timestamp descending
    items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return items;
  }

  Widget _buildGroupedNotificationList(List<_UnifiedNotification> items) {
    if (items.isEmpty) {
      if (_selectedTabIndex.value == 2) {
        return _buildEmptyMentionsState();
      }
      return _buildEmptyState();
    }

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(const Duration(days: 7));

    final List<_UnifiedNotification> todayItems = [];
    final List<_UnifiedNotification> weekItems = [];
    final List<_UnifiedNotification> olderItems = [];

    for (final item in items) {
      if (item.timestamp.isAfter(todayStart) || item.timestamp.isAtSameMomentAs(todayStart)) {
        todayItems.add(item);
      } else if (item.timestamp.isAfter(weekStart) || item.timestamp.isAtSameMomentAs(weekStart)) {
        weekItems.add(item);
      } else {
        olderItems.add(item);
      }
    }

    final List<Widget> listWidgets = [];

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
        style: GoogleFonts.roboto(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildCompactNotificationTile(_UnifiedNotification item) {
    String thumbnailUrl = '';
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
          color: item.isSeen ? Colors.transparent : Colors.white.withValues(alpha: 0.05),
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
    String avatarUrl = '';
    IconData? fallbackIcon;
    Color fallbackBgColor = Colors.grey[800]!;

    if (item.video != null) {
      avatarUrl = item.video!.channelAvatarUrl.isNotEmpty
          ? item.video!.channelAvatarUrl
          : item.video!.channelImage;
      fallbackIcon = Icons.video_library_rounded;
    } else if (item.alert != null) {
      final metadata = item.alert!.metadata;
      avatarUrl = metadata?['avatarUrl'] as String? ??
                  metadata?['userAvatar'] as String? ?? '';

      final typeLower = item.alert!.type.toLowerCase();
      if (typeLower.contains('like')) {
        return Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: Color(0xFFE50914), // Red play icon container
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        );
      }

      switch (item.alert!.severity) {
        case NotificationSeverity.priority:
          fallbackIcon = Icons.warning_rounded;
          fallbackBgColor = const Color(0xFFEF4444);
          break;
        case NotificationSeverity.warning:
          fallbackIcon = Icons.error_outline_rounded;
          fallbackBgColor = const Color(0xFFF59E0B);
          break;
        case NotificationSeverity.success:
          fallbackIcon = Icons.star_rounded;
          fallbackBgColor = const Color(0xFF10B981);
          break;
        case NotificationSeverity.info:
          fallbackIcon = Icons.info_outline_rounded;
          fallbackBgColor = const Color(0xFF6366F1);
          break;
      }
    }

    if (avatarUrl.isNotEmpty) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey[900],
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.network(
          avatarUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => CircleAvatar(
            backgroundColor: fallbackBgColor,
            child: Icon(fallbackIcon ?? Icons.notifications, color: Colors.white, size: 20),
          ),
        ),
      );
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: fallbackBgColor.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          fallbackIcon ?? Icons.notifications,
          color: fallbackBgColor,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildTextContent(_UnifiedNotification item) {
    if (item.video != null) {
      final video = item.video!;
      return RichText(
        text: TextSpan(
          style: GoogleFonts.roboto(
            fontSize: 14,
            height: 1.3,
            color: Colors.white,
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
            style: GoogleFonts.roboto(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            alert.message,
            style: GoogleFonts.roboto(
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
      style: GoogleFonts.roboto(
        fontSize: 12,
        color: const Color(0xFF8E8E8E),
      ),
    );
  }

  Widget _buildSmallThumbnail(String url) {
    return Container(
      width: 96,
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[900],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
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
                  .collection('users')
                  .doc(userId)
                  .collection('feed_inbox')
                  .doc(item.video!.id)
                  .delete();
              controller.notifications.removeWhere((v) => v.id == item.video!.id);
              controller.notifications.refresh();
            } else if (item.alert != null) {
              await FirebaseFirestore.instance
                  .collection('user_notifications')
                  .doc(item.alert!.id)
                  .delete();
              userNotificationController.notifications.removeWhere((a) => a.id == item.alert!.id);
              userNotificationController.notifications.refresh();
            }
            Get.snackbar(
              'Notification removed',
              'The notification has been deleted',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: AppColors.bgSurface,
              colorText: Colors.white,
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

  Widget _buildEmptyMentionsState() {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.alternate_email_rounded,
              size: 140,
              color: Color(0xFF333333),
            ),
            const SizedBox(height: 16),
            Text(
              'No mentions yet',
              style: GoogleFonts.roboto(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: Colors.white54,
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
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_off_rounded,
                size: 60,
                color: Colors.white30,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No notifications',
              style: GoogleFonts.roboto(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You have no notifications in this section.',
              style: GoogleFonts.roboto(fontSize: 14, color: Colors.white60),
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
            color: Colors.white.withValues(alpha: 0.6),
            strokeWidth: 3,
          ),
          const SizedBox(height: 20),
          Text(
            'Loading...',
            style: GoogleFonts.roboto(color: Colors.white60, fontSize: 14),
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
            color: Colors.white30,
          ),
          const SizedBox(height: 16),
          Text(
            'Something went wrong',
            style: GoogleFonts.roboto(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
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
                  color: Colors.white,
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
              icon: const Icon(Icons.done_all_rounded, color: Colors.black),
              label: Text(
                'Mark All Read',
                style: GoogleFonts.roboto(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: Colors.white,
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

    final List<String> videoIds = [];
    final List<String> alertIds = [];

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
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );
  }

  void _navigateToVideo(Video notification) {
    Get.toNamed('/watch?v=${notification.id}', arguments: {'video': notification});
  }

  void _navigateToAlertVideo(UserNotification alert) {
    final videoId = alert.metadata?['videoId'] as String?;
    if (videoId != null && videoId.isNotEmpty) {
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
      Get.toNamed('/watch?v=${mockVideo.id}', arguments: {
        'video': mockVideo,
        'commentId': alert.metadata?['commentId'],
        'replyId': alert.metadata?['replyId'],
      });
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
  final Video? video;
  final UserNotification? alert;
  final DateTime timestamp;
  final bool isSeen;

  _UnifiedNotification({
    this.video,
    this.alert,
    required this.timestamp,
    required this.isSeen,
  });
}







