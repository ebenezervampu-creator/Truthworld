import 'dart:async';
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
import 'package:truthworld/core/services/fcm_notification_service.dart';

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
      // 1. Maintain global legacy arrays for offline fallback/references
      await _firestore.collection('users').doc(userId).update({
        'seenVideoIds': FieldValue.arrayUnion([videoId]),
      });

      // 2. Explicitly flag the specific feed inbox document
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('feed_inbox')
          .doc(videoId)
          .update({'isSeen': true});
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
      // 1. Update legacy document tracking
      await _firestore.collection('users').doc(userId).update({
        'seenVideoIds': FieldValue.arrayUnion(videoIds),
        'lastSeenNotifications': FieldValue.serverTimestamp(),
      });

      // 2. Perform optimal batched status propagation across local collection
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
    fetchFromCloudFunction();
  }

  Future<void> fetchFromCloudFunction() async {
    isLoading.value = true;
    try {
      final list = await _service.fetchNotificationsViaCallable(limit: 100);
      notifications.value = list;
    } catch (e) {
      debugPrint('Error fetching cloud notifications via Cloud Function: $e');
    } finally {
      isLoading.value = false;
    }
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
    try {
      final fresh = await _service.fetchNotificationsViaCallable(limit: 100);
      notifications.value = fresh;
    } catch (e) {
      debugPrint('Error refreshing cloud notifications: $e');
    } finally {
      isLoading.value = false;
    }
  }

  List<UserNotification> get filteredNotifications {
    if (selectedSeverityFilter.value == 'all') {
      return notifications.toList();
    }
    return notifications
        .where((n) =>
            n.severity.name.toLowerCase() ==
            selectedSeverityFilter.value.toLowerCase())
        .toList();
  }

  int get unreadCount => notifications.where((n) => !n.read).length;
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

  bool get isMobile => MediaQuery.of(context).size.width < 600;
  bool get isTablet =>
      MediaQuery.of(context).size.width >= 600 &&
      MediaQuery.of(context).size.width < 1024;
  bool get isDesktop => MediaQuery.of(context).size.width >= 1024;

  int get gridCrossAxisCount {
    if (isDesktop) {
      return 3;
    }
    if (isTablet) {
      return 2;
    }
    return 1;
  }

  double get maxContentWidth {
    if (isDesktop) {
      return 1400;
    }
    return double.infinity;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: RefreshIndicator(
            color: const Color(0xFF6366F1),
            backgroundColor: AppColors.bgSurface,
            onRefresh: () async {
              if (_selectedTabIndex.value == 0) {
                await controller.refreshNotifications();
              } else {
                await userNotificationController.refreshNotifications();
              }
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              controller: _scrollController,
              slivers: [
                _buildAppBar(),
                SliverToBoxAdapter(child: _buildTabsHeader()),
                SliverToBoxAdapter(child: _buildFcmControlPanel()),
                Obx(() => SliverToBoxAdapter(
                      child: _selectedTabIndex.value == 0
                          ? _buildFilters()
                          : _buildCloudAlertsFilters(),
                    )),
                const SliverToBoxAdapter(child: SizedBox(height: 8)),
                Obx(() => _selectedTabIndex.value == 0
                    ? _buildContent()
                    : _buildCloudAlertsContent()),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _buildFloatingButtons(),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.bgInput,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
        onPressed: () => Get.back(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        title: Obx(
          () => AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: controller.isSearching.value
                ? _buildSearchBar()
                : _buildTitle(),
          ),
        ),
        centerTitle: false,
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF6366F1).withValues(alpha: 0.15),
                const Color(0xFF8B5CF6).withValues(alpha: 0.1),
              ],
            ),
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
              color: Colors.white,
            ),
            onPressed: controller.toggleSearching,
          ),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
          onSelected: (value) {
            if (value == 'mark_all_seen') {
              controller.markAllAsSeen();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'mark_all_seen',
              child: Row(
                children: [
                  Icon(Icons.done_all_rounded, size: 20),
                  SizedBox(width: 12),
                  Text('Mark all as seen'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      key: const ValueKey('search'),
      width: double.infinity,
      height: 44,
      margin: EdgeInsets.only(right: 60, left: 0),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        style: GoogleFonts.roboto(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search videos or channels...',
          hintStyle: GoogleFonts.roboto(color: Colors.white60),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: AppColors.bgSurface,
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Colors.white60,
            size: 20,
          ),
        ),
        onChanged: (value) => controller.searchQuery.value = value,
      ),
    );
  }

  Widget _buildTitle() {
    return Row(
      key: const ValueKey('title'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.video_library_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Video Feed",
              style: GoogleFonts.roboto(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Obx(() {
              final unseen = controller.unseenCount;
              final today = controller.todayCount;
              return Text(
                '$unseen new • $today today',
                style: GoogleFonts.roboto(fontSize: 11, color: Colors.white60),
              );
            }),
          ],
        ),
      ],
    );
  }

  // Helper for category display names
  String _getCategoryDisplayName(String category) {
    if (category == 'all') {
      return 'All Categories';
    }
    return StringExtension(category).capitalize;
  }

  // Helper for category icons
  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'gaming':
        return Icons.videogame_asset;
      case 'music':
        return Icons.music_note;
      case 'education':
        return Icons.school;
      default:
        return Icons.category;
    }
  }

  Widget _buildFilters() {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Combined Time + Seen Filters: Single Wrap row for simplicity
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // Time Filters
                Obx(
                  () => _buildFilterChip(
                    value: 'all',
                    label: 'All Time',
                    icon: Icons.all_inclusive,
                    isSelected: controller.selectedTimeFilter.value == 'all',
                    onSelected: () => controller.setTimeFilter('all'),
                    color: const Color(0xFF6366F1), // Purple accent
                  ),
                ),
                Obx(
                  () => _buildFilterChip(
                    value: 'today',
                    label: 'Today',
                    icon: Icons.today_rounded,
                    isSelected: controller.selectedTimeFilter.value == 'today',
                    onSelected: () => controller.setTimeFilter('today'),
                    color: const Color(0xFF6366F1),
                  ),
                ),
                Obx(
                  () => _buildFilterChip(
                    value: 'this_week',
                    label: 'Week',
                    icon: Icons.date_range_rounded,
                    isSelected:
                        controller.selectedTimeFilter.value == 'this_week',
                    onSelected: () => controller.setTimeFilter('this_week'),
                    color: const Color(0xFF6366F1),
                  ),
                ),
                Obx(
                  () => _buildFilterChip(
                    value: 'this_month',
                    label: 'Month',
                    icon: Icons.calendar_month_rounded,
                    isSelected:
                        controller.selectedTimeFilter.value == 'this_month',
                    onSelected: () => controller.setTimeFilter('this_month'),
                    color: const Color(0xFF6366F1),
                  ),
                ),
                // Seen Filters (integrated for fewer rows)
                const SizedBox(width: 16), // Visual separator
                Obx(
                  () => _buildFilterChip(
                    value: 'all',
                    label: 'All Videos',
                    icon: Icons.video_library_rounded,
                    isSelected: controller.selectedSeenFilter.value == 'all',
                    onSelected: () => controller.setSeenFilter('all'),
                    color: const Color(0xFF10B981), // Green accent
                  ),
                ),
                Obx(
                  () => _buildFilterChip(
                    value: 'unseen',
                    label: 'Unseen',
                    icon: Icons.fiber_new_rounded,
                    isSelected: controller.selectedSeenFilter.value == 'unseen',
                    onSelected: () => controller.setSeenFilter('unseen'),
                    color: const Color(0xFF10B981),
                  ),
                ),
                Obx(
                  () => _buildFilterChip(
                    value: 'seen',
                    label: 'Watched',
                    icon: Icons.done_rounded,
                    isSelected: controller.selectedSeenFilter.value == 'seen',
                    onSelected: () => controller.setSeenFilter('seen'),
                    color: const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16), // Increased for breathing room
          // Categories: Wrap if few, Dropdown if many
          Obx(() {
            final categories = controller.availableCategories;
            if (categories.length <= 1) {
              return const SizedBox.shrink();
            }

            if (categories.length <= 5) {
              // Horizontal-ish Wrap for small sets
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: categories
                      .map((category) => _buildCategoryChip(category))
                      .toList(),
                ),
              );
            } else {
              // Dropdown for many categories (professional, space-saving)
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: DropdownMenu<String>(
                  width: double.infinity,
                  inputDecorationTheme: InputDecorationTheme(
                    filled: true,
                    fillColor: AppColors.bgDivider,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.bgDivider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.bgDivider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: const Color(0xFF6366F1),
                        width: 2,
                      ),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  textStyle: GoogleFonts.roboto(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                  menuStyle: const MenuStyle(
                    surfaceTintColor: WidgetStatePropertyAll(
                      Colors.transparent,
                    ),
                    shadowColor: WidgetStatePropertyAll(Colors.black54),
                  ),
                  leadingIcon: const Icon(
                    Icons.category_rounded,
                    color: Colors.white60,
                  ),
                  hintText: 'Filter by Category',
                  initialSelection: controller.selectedCategory.value,
                  onSelected: (value) {
                    if (value != null) {
                      controller.setCategory(value);
                      HapticFeedback.selectionClick();
                    }
                  },
                  dropdownMenuEntries: categories.map((category) {
                    return DropdownMenuEntry<String>(
                      value: category,
                      label: _getCategoryDisplayName(category),
                      leadingIcon: Icon(
                        _getCategoryIcon(category),
                        color: const Color(0xFFF59E0B),
                      ),
                      style: MenuItemButton.styleFrom(
                        foregroundColor:
                            controller.selectedCategory.value == category
                            ? Colors.white
                            : Colors.white70,
                        backgroundColor:
                            controller.selectedCategory.value == category
                            ? const Color(0xFFF59E0B).withValues(alpha: 0.1)
                            : Colors.transparent,
                      ),
                    );
                  }).toList(),
                ),
              );
            }
          }),
        ],
      ),
    );
  }

  // Unified FilterChip builder
  Widget _buildFilterChip({
    required String value,
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onSelected,
    required Color color,
  }) {
    return FilterChip(
      label: Text(
        label,
        style: GoogleFonts.roboto(
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
          color: isSelected ? Colors.white : Colors.white70,
        ),
      ),
      avatar: CircleAvatar(
        backgroundColor: color.withValues(alpha: isSelected ? 0.2 : 0.1),
        foregroundColor: color,
        child: Icon(icon, size: 16),
      ),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      side: isSelected
          ? BorderSide.none
          : BorderSide(color: AppColors.bgDivider, width: 1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isSelected
          ? color.withValues(alpha: 0.15)
          : AppColors.bgDivider,
      selectedColor: color.withValues(alpha: 0.1),
      elevation: isSelected ? 2 : 0,
      shadowColor: isSelected
          ? color.withValues(alpha: 0.2)
          : Colors.transparent,
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      visualDensity: VisualDensity.compact, // Tighter on desktop
    );
  }

  // Simplified Category Chip (only for Wrap mode)
  Widget _buildCategoryChip(String category) {
    final isSelected = controller.selectedCategory.value == category;
    final displayName = _getCategoryDisplayName(category);
    final color = const Color(0xFFF59E0B); // Amber for categories

    return FilterChip(
      label: Text(
        displayName.length > 12
            ? '${displayName.substring(0, 9)}...'
            : displayName,
        style: GoogleFonts.roboto(
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
          color: isSelected ? Colors.white : Colors.white70,
        ),
      ),
      avatar: CircleAvatar(
        backgroundColor: color.withValues(alpha: isSelected ? 0.2 : 0.1),
        foregroundColor: color,
        child: Icon(_getCategoryIcon(category), size: 16),
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) controller.setCategory(category);
        HapticFeedback.selectionClick();
      },
      side: isSelected
          ? BorderSide.none
          : BorderSide(color: AppColors.bgDivider, width: 1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isSelected
          ? color.withValues(alpha: 0.15)
          : AppColors.bgDivider,
      selectedColor: color.withValues(alpha: 0.1),
      elevation: isSelected ? 2 : 0,
      shadowColor: isSelected
          ? color.withValues(alpha: 0.2)
          : Colors.transparent,
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildContent() {
    if (controller.isLoading.value) {
      return SliverFillRemaining(child: _buildLoadingState());
    }

    if (controller.errorMessage.isNotEmpty) {
      return SliverFillRemaining(child: _buildErrorState());
    }

    final filteredNotifications = controller.filteredNotifications;

    if (filteredNotifications.isEmpty) {
      return SliverFillRemaining(child: _buildEmptyState());
    }

    // Desktop/Tablet: Grid layout with corrected aspect ratios for minimal height
    if (isDesktop || isTablet) {
      return SliverPadding(
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 32 : 16,
          vertical: 8,
        ),
        sliver: SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: gridCrossAxisCount,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            childAspectRatio: isDesktop
                ? 1.1
                : 1.05, // Fixed: Matches ~content (w/h); reduces extra space
          ),
          delegate: SliverChildBuilderDelegate((context, index) {
            final notification = filteredNotifications[index];
            return TweenAnimationBuilder<double>(
              duration: Duration(milliseconds: 300 + (index * 50)),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, 30 * (1 - value)),
                  child: Opacity(
                    opacity: value,
                    child: _buildVideoCard(notification),
                  ),
                );
              },
            );
          }, childCount: filteredNotifications.length),
        ),
      );
    }

    // Mobile: List layout (already minimal)
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final notification = filteredNotifications[index];
          return TweenAnimationBuilder<double>(
            duration: Duration(milliseconds: 300 + (index * 50)),
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, 30 * (1 - value)),
                child: Opacity(
                  opacity: value,
                  child: _buildVideoCard(notification),
                ),
              );
            },
          );
        }, childCount: filteredNotifications.length),
      ),
    );
  }

  Widget _buildVideoCard(Video notification) {
    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 16 : 0),
      clipBehavior: Clip.hardEdge, // Trims any grid overflow
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.bgSurface, Color(0xFF1A1A1A)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: notification.isSeen
              ? AppColors.bgSurface.withValues(alpha: 0.3)
              : const Color(0xFF6366F1).withValues(alpha: 0.5),
          width: notification.isSeen ? 1 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: notification.isSeen
                ? Colors.black26
                : const Color(0xFF6366F1).withValues(alpha: 0.2),
            blurRadius: notification.isSeen ? 10 : 20,
            spreadRadius: notification.isSeen ? 1 : 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            if (!notification.isSeen) {
              controller.markVideoAsSeen(notification.id);
            }
            _navigateToVideo(notification);
            HapticFeedback.mediumImpact();
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildThumbnail(notification),
              Padding(
                padding: EdgeInsets.all(
                  isMobile ? 12 : 16,
                ), // Slightly more on desktop
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildChannelAvatar(notification),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                notification.channelName,
                                style: GoogleFonts.roboto(
                                  fontSize: isMobile ? 13 : 14,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF6366F1),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                notification.category,
                                style: GoogleFonts.roboto(
                                  fontSize: 11,
                                  color: Colors.white60,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!notification.isSeen)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'NEW',
                              style: GoogleFonts.roboto(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      notification.title,
                      style: GoogleFonts.roboto(
                        fontSize: isMobile ? 15 : 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _buildMetaChip(
                          Icons.remove_red_eye_outlined,
                          _formatViews(notification.views),
                          const Color(0xFF8B5CF6),
                        ),
                        _buildMetaChip(
                          Icons.access_time_rounded,
                          _formatTimestamp(notification.uploadedAt.toDate()),
                          const Color(0xFF10B981),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChannelAvatar(Video notification) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
        ),
        border: Border.all(
          color: const Color(0xFF6366F1).withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: ClipOval(
        child: notification.channelImage.isNotEmpty
            ? Image.network(
                notification.channelImage,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.person, color: Colors.white, size: 20),
              )
            : const Icon(Icons.person, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildMetaChip(IconData icon, String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.roboto(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail(Video notification) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.bgSurface, Color(0xFF1A202C)],
                    ),
                  ),
                  child: notification.thumbnailUrl.isNotEmpty
                      ? Image.network(
                          notification.thumbnailUrl,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.high,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.bgSurface,
                                    Color(0xFF1A202C),
                                  ],
                                ),
                              ),
                              child: Center(
                                child: CircularProgressIndicator(
                                  value:
                                      loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                      : null,
                                  color: const Color(0xFF6366F1),
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) =>
                              _buildThumbnailPlaceholder(),
                        )
                      : _buildThumbnailPlaceholder(),
                ),
              ),
            ),
            // Gradient overlay for better text visibility
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Colors
                          .black54, // Slightly stronger for desktop visibility
                    ],
                    stops: [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
            // Duration badge
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 1,
                  ),
                ),
                child: Text(
                  notification.duration,
                  style: GoogleFonts.roboto(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            // Play button overlay (larger on desktop)
            Positioned.fill(
              child: Center(
                child: Container(
                  width: isDesktop ? 72 : 60,
                  height: isDesktop ? 72 : 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: isDesktop ? 4 : 3,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 36, // Base; scales implicitly
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildThumbnailPlaceholder() {
    return SizedBox.expand(
      // Ensures it fills the AspectRatio bounds
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.bgSurface, Color(0xFF1A202C)],
          ),
        ),
        child: const Center(
          child: Icon(
            Icons.video_library_rounded,
            size: 60,
            color: Color(0xFF6366F1),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(50),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.5),
                  blurRadius: 30,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Loading your video feed...',
            style: GoogleFonts.roboto(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Fetching the latest videos',
            style: GoogleFonts.roboto(fontSize: 14, color: Colors.white60),
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
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(60),
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              size: 60,
              color: Color(0xFFEF4444),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Oops! Something went wrong',
            style: GoogleFonts.roboto(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We couldn\'t load your video feed',
            style: GoogleFonts.roboto(fontSize: 14, color: Colors.white60),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              controller.refreshNotifications();
              HapticFeedback.mediumImpact();
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF6366F1).withValues(alpha: 0.2),
                  const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(70),
            ),
            child: const Icon(
              Icons.video_library_outlined,
              size: 70,
              color: Color(0xFF6366F1),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'No videos found',
            style: GoogleFonts.roboto(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Subscribe to channels or adjust your filters to see videos here',
              style: GoogleFonts.roboto(
                fontSize: 14,
                color: Colors.white70,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingButtons() {
    return Obx(() {
      final hasUnread = _selectedTabIndex.value == 0
          ? controller.unseenCount > 0
          : userNotificationController.unreadCount > 0;

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
          if (!hasUnread)
            const SizedBox.shrink()
          else
            FloatingActionButton.extended(
              heroTag: 'mark_seen',
              onPressed: () {
                if (_selectedTabIndex.value == 0) {
                  controller.markAllAsSeen();
                } else {
                  userNotificationController.markAllAsRead();
                }
                HapticFeedback.mediumImpact();
              },
              icon: const Icon(Icons.done_all_rounded, color: Colors.white),
              label: Text(
                'Mark All Read',
                style: GoogleFonts.roboto(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              backgroundColor: _selectedTabIndex.value == 0
                  ? const Color(0xFF10B981)
                  : const Color(0xFF6366F1),
              elevation: 8,
            ),
        ],
      );
    });
  }

  // ==========================================================================
  // PREMIUM MULTI-TAB BUILDERS & CLOUD ALERTS RENDERING
  // ==========================================================================

  Widget _buildTabsHeader() {
    return Container(
      margin: EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.bgDivider.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: AppColors.bgDivider.withValues(alpha: 0.8)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Obx(() => _buildPremiumTabButton(
                  title: 'Content Feed',
                  icon: Icons.video_library_rounded,
                  isSelected: _selectedTabIndex.value == 0,
                  badgeCount: controller.unseenCount,
                  activeColor: const Color(0xFF6366F1),
                  onTap: () {
                    _selectedTabIndex.value = 0;
                    HapticFeedback.selectionClick();
                  },
                )),
          ),
          Expanded(
            child: Obx(() => _buildPremiumTabButton(
                  title: 'Activity & Alerts',
                  icon: Icons.notifications_active_rounded,
                  isSelected: _selectedTabIndex.value == 1,
                  badgeCount: userNotificationController.unreadCount,
                  activeColor: const Color(0xFF10B981),
                  onTap: () {
                    _selectedTabIndex.value = 1;
                    HapticFeedback.selectionClick();
                  },
                )),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumTabButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required int badgeCount,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(21),
          border: Border.all(
            color: isSelected
                ? activeColor.withValues(alpha: 0.5)
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? activeColor : Colors.white60,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.roboto(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.white60,
              ),
            ),
            if (badgeCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? activeColor : Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badgeCount > 99 ? '99+' : '$badgeCount',
                  style: GoogleFonts.roboto(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCloudAlertsFilters() {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          Obx(() => _buildFilterChip(
                value: 'all',
                label: 'All Alerts',
                icon: Icons.all_inclusive_rounded,
                isSelected: userNotificationController
                        .selectedSeverityFilter.value ==
                    'all',
                onSelected: () =>
                    userNotificationController.setSeverityFilter('all'),
                color: const Color(0xFF10B981),
              )),
          Obx(() => _buildFilterChip(
                value: 'priority',
                label: 'Priority',
                icon: Icons.warning_rounded,
                isSelected: userNotificationController
                        .selectedSeverityFilter.value ==
                    'priority',
                onSelected: () =>
                    userNotificationController.setSeverityFilter('priority'),
                color: const Color(0xFFEF4444),
              )),
          Obx(() => _buildFilterChip(
                value: 'warning',
                label: 'Warning',
                icon: Icons.error_outline_rounded,
                isSelected: userNotificationController
                        .selectedSeverityFilter.value ==
                    'warning',
                onSelected: () =>
                    userNotificationController.setSeverityFilter('warning'),
                color: const Color(0xFFF59E0B),
              )),
          Obx(() => _buildFilterChip(
                value: 'success',
                label: 'Milestones',
                icon: Icons.star_rounded,
                isSelected: userNotificationController
                        .selectedSeverityFilter.value ==
                    'success',
                onSelected: () =>
                    userNotificationController.setSeverityFilter('success'),
                color: const Color(0xFF10B981),
              )),
          Obx(() => _buildFilterChip(
                value: 'info',
                label: 'Updates',
                icon: Icons.info_outline_rounded,
                isSelected: userNotificationController
                        .selectedSeverityFilter.value ==
                    'info',
                onSelected: () =>
                    userNotificationController.setSeverityFilter('info'),
                color: const Color(0xFF6366F1),
              )),
        ],
      ),
    );
  }

  Widget _buildCloudAlertsContent() {
    if (userNotificationController.isLoading.value &&
        userNotificationController.notifications.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: CircularProgressIndicator(color: const Color(0xFF10B981)),
        ),
      );
    }

    final alerts = userNotificationController.filteredNotifications;
    if (alerts.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.notifications_off_rounded,
                  size: 64, color: Colors.white30),
              const SizedBox(height: 16),
              Text(
                'No activity alerts found',
                style: GoogleFonts.roboto(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 32 : 16, vertical: 8),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final alert = alerts[index];
          return _buildCloudAlertCard(alert);
        }, childCount: alerts.length),
      ),
    );
  }

  Widget _buildCloudAlertCard(UserNotification alert) {
    Color severityColor;
    IconData severityIcon;

    switch (alert.severity) {
      case NotificationSeverity.priority:
        severityColor = const Color(0xFFEF4444);
        severityIcon = Icons.warning_rounded;
        break;
      case NotificationSeverity.warning:
        severityColor = const Color(0xFFF59E0B);
        severityIcon = Icons.error_outline_rounded;
        break;
      case NotificationSeverity.success:
        severityColor = const Color(0xFF10B981);
        severityIcon = Icons.star_rounded;
        break;
      case NotificationSeverity.info:
        severityColor = const Color(0xFF6366F1);
        severityIcon = Icons.info_outline_rounded;
        break;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            alert.read
                ? AppColors.bgSurface
                : severityColor.withValues(alpha: 0.1),
            const Color(0xFF151515),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: alert.read
              ? AppColors.bgDivider
              : severityColor.withValues(alpha: 0.4),
          width: alert.read ? 1 : 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (!alert.read) {
              userNotificationController.markAsRead(alert.id);
            }

            final videoId = alert.metadata?['videoId'] as String?;
            if (videoId != null && videoId.isNotEmpty) {
              // Direct intelligent route matching to VideoScreen for comment/reply navigation
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
              Get.toNamed("/videoscreen", arguments: {
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
            HapticFeedback.lightImpact();
          },
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: severityColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: severityColor.withValues(alpha: 0.3)),
                  ),
                  child: Icon(severityIcon, color: severityColor, size: 20),
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
                              alert.title,
                              style: GoogleFonts.roboto(
                                fontSize: 15,
                                fontWeight: alert.read
                                    ? FontWeight.w500
                                    : FontWeight.bold,
                                color: alert.read
                                    ? Colors.white70
                                    : Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatTimestamp(alert.createdAt),
                            style: GoogleFonts.roboto(
                                fontSize: 12, color: Colors.white54),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        alert.message,
                        style: GoogleFonts.roboto(
                          fontSize: 13,
                          color: alert.read
                              ? Colors.white60
                              : Colors.white.withValues(alpha: 0.9),
                          height: 1.4,
                        ),
                      ),
                      if (alert.actionUrl != null &&
                          alert.actionUrl!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Text(
                              'View Details',
                              style: GoogleFonts.roboto(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: severityColor,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.arrow_forward_ios_rounded,
                                size: 10, color: severityColor),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (!alert.read) ...[
                  const SizedBox(width: 12),
                  Container(
                    width: 8,
                    height: 8,
                    margin: EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(
                      color: severityColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: severityColor.withValues(alpha: 0.5),
                            blurRadius: 4,
                            spreadRadius: 1),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatViews(int views) {
    if (views >= 1000000) {
      return '${(views / 1000000).toStringAsFixed(1)}M';
    } else if (views >= 1000) {
      return '${(views / 1000).toStringAsFixed(1)}K';
    }
    return '$views';
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
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

  void _navigateToVideo(Video notification) {
    Get.toNamed("/videoscreen", arguments: {'video': notification});
  }

  Widget _buildFcmControlPanel() {
    final fcmService = Get.find<FcmNotificationService>();
    return Obx(() {
      final status = fcmService.permissionStatus.value;
      final token = fcmService.fcmToken.value;
      final isInit = fcmService.isInitializing.value;

      Color statusColor = Colors.grey;
      String statusText = 'Notifications Disabled';
      IconData statusIcon = Icons.notifications_off_rounded;

      if (status == 'granted') {
        statusColor = const Color(0xFF10B981);
        statusText = 'Push Alerts Active';
        statusIcon = Icons.notifications_active_rounded;
      } else if (status == 'denied') {
        statusColor = const Color(0xFFEF4444);
        statusText = 'Notifications Blocked';
        statusIcon = Icons.notifications_paused_rounded;
      }

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: (status == 'granted' ? const Color(0xFF8B5CF6) : Colors.white10).withOpacity(0.2),
          ),
          gradient: LinearGradient(
            colors: [
              const Color(0xFF1E1B4B).withOpacity(0.4),
              const Color(0xFF0F0F1A).withOpacity(0.3),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (status == 'granted' ? const Color(0xFF8B5CF6) : Colors.white10).withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(statusIcon, color: status == 'granted' ? const Color(0xFF8B5CF6) : Colors.white60, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Web Push Notifications',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            statusText,
                            style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (status != 'granted') ...[
                  ElevatedButton.icon(
                    onPressed: isInit ? null : () => fcmService.requestPushPermission(context),
                    icon: isInit
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.flash_on_rounded, size: 14),
                    label: Text(isInit ? 'Enabling...' : 'Enable Alerts'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ] else ...[
                  IconButton(
                    onPressed: () {
                      fcmService.removeFcmToken();
                      Get.snackbar(
                        'Alerts Unsubscribed',
                        'Push tokens cleared successfully.',
                        backgroundColor: Colors.black54,
                        colorText: Colors.white,
                      );
                    },
                    icon: const Icon(Icons.do_not_disturb_on_rounded, color: Colors.redAccent, size: 20),
                    tooltip: 'Revoke Device Registration',
                  ),
                ],
              ],
            ),
            if (token.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Divider(color: Colors.white10, height: 1),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'ACTIVE WEB FCM TOKEN (DEVELOPER CONSOLE SYNC)',
                        style: TextStyle(fontSize: 9, color: Colors.white30, letterSpacing: 0.5, fontWeight: FontWeight.bold),
                      ),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: token));
                          Get.snackbar(
                            'Token Copied!',
                            'Device FCM registration token copied to clipboard.',
                            snackPosition: SnackPosition.BOTTOM,
                            backgroundColor: const Color(0xFF10B981),
                            colorText: Colors.white,
                          );
                        },
                        child: Row(
                          children: const [
                            Icon(Icons.copy_rounded, color: Color(0xFF8B5CF6), size: 12),
                            SizedBox(width: 4),
                            Text(
                              'COPY TOKEN',
                              style: TextStyle(fontSize: 9, color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Text(
                      token,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 9,
                        color: Colors.white60,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    });
  }
}







