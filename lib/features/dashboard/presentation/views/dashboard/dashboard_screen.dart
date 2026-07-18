import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/analytics/analytics_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/dashboard_comments_page.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/content_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/copyright_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/studio_settings_page.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/video_management.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/customization_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/monetization_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/place_holder_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/subtitles_page.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks_page.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audience_page.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/video_rating_page.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/video_rating_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/topic_management_screen.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';
import 'package:truthworld/features/analytics/presentation/pages/watch_time_page.dart';
import 'package:truthworld/features/analytics/presentation/pages/views_page.dart';
import 'package:truthworld/features/analytics/presentation/pages/subscribers_page.dart';

class AnalyticsData {
  final DateTime date;
  final int views;

  AnalyticsData(this.date, this.views);
}

// ==========================================================================
// MODERNIZED DASHBOARD SCREEN - NOW WITH LIVE ANALYTICS AND SYNCFUSION CHARTS
// ==========================================================================

class DashboardController extends GetxController {
  final String channelId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DashboardController({required this.channelId});

  final Rx<Channel?> currentChannel = Rx<Channel?>(null);
  final RxBool showApprovalBanner = false.obs;

  var selectedIndex = 1.obs;
  var isDrawerExpanded = true.obs;
  var isLoading = true.obs;
  var errorMessage = ''.obs;

  var channelStats = <String, dynamic>{}.obs;
  var recentVideos = <Video>[].obs;
  var analyticsData = <AnalyticsData>[].obs;
  var searchQuery = ''.obs;

  var copyrightClaimsCount = 0.obs;

  StreamSubscription? _statsSubscription;
  StreamSubscription? _videosSubscription;
  StreamSubscription? _analyticsSubscription;
  StreamSubscription? _channelSubscription;
  StreamSubscription? _copyrightSubscription;

  /// Get filtered videos based on search query
  List<Video> get filteredVideos {
    if (searchQuery.value.isEmpty) {
      return recentVideos;
    }
    final query = searchQuery.value.toLowerCase();
    return recentVideos
        .where(
          (video) =>
              video.title.toLowerCase().contains(query) ||
              video.description.toLowerCase().contains(query) ||
              video.tags.any((tag) => tag.toLowerCase().contains(query)),
        )
        .toList();
  }

  @override
  void onInit() {
    super.onInit();
    if (channelId.isNotEmpty) {
      _initializeData();
    } else {
      isLoading.value = false;
      errorMessage.value = "No channel provided.";
    }
  }

  @override
  void onClose() {
    _statsSubscription?.cancel();
    _videosSubscription?.cancel();
    _analyticsSubscription?.cancel();
    _channelSubscription?.cancel();
    _copyrightSubscription?.cancel();
    super.onClose();
  }

  void _initializeData() {
    isLoading.value = true;
    _loadChannelStats();
    _loadRecentVideos();
    _loadAnalyticsData();
    _loadCopyrightStatus();
    // Use Future.delayed to set loading to false after a short period,
    // allowing streams to populate data.
    Future.delayed(Duration(seconds: 2), () {
      if (isLoading.value) {
        isLoading.value = false;
      }
    });
  }

  void _loadChannelStats() {
    // 1. Listen to the main channel document for real-time totals (subs, views)
    final channelRef = _firestore.collection('channels').doc(channelId);
    _channelSubscription = channelRef.snapshots().listen((snapshot) {
      if (snapshot.exists) {
        final channel = Channel.fromDocumentSnapshot(snapshot);
        currentChannel.value = channel;

        if (channel.status == ChannelStatus.active) {
          final storage = GetStorage();
          final key = 'approval_shown_${channel.id}';
          final shown = storage.read<bool>(key) ?? false;
          if (!shown) {
            showApprovalBanner.value = true;
            storage.write(key, true);
          }
        }

        // Only update if summary stats are missing or zeros
        if (channelStats.isEmpty || (channelStats['views'] == '0' && channel.viewCount > 0)) {
          channelStats.value = {
            ...channelStats,
            'views': _formatNumber(channel.viewCount),
            'subscribers': _formatNumber(channel.subscriberCount),
            'watchTime': _formatWatchTime(channel.metrics.totalWatchTimeMinutes),
            'revenue': channelStats['revenue'] ?? '\$0.00',
            'viewsChange': channelStats['viewsChange'] ?? '+0%',
            'watchTimeChange': channelStats['watchTimeChange'] ?? '+0%',
            'subscribersChange': channelStats['subscribersChange'] ?? '+0',
            'revenueChange': channelStats['revenueChange'] ?? '+\$0.00',
          };
        }
      }
    });

    // 2. Listen to the summary document for detailed analytics (watch time, trends)
    final summaryRef = _firestore
        .collection('channels')
        .doc(channelId)
        .collection('stats')
        .doc('summary');
    _statsSubscription = summaryRef.snapshots().listen(
      (snapshot) {
        if (snapshot.exists) {
          final data = snapshot.data() as Map<String, dynamic>;
          channelStats.value = {
            'views': _formatNumber(data['totalViews'] ?? 0),
            'watchTime': _formatWatchTime(data['totalWatchTimeMinutes'] ?? 0),
            'subscribers': _formatNumber(data['subscribers'] ?? 0),
            'revenue': '\$0.00',
            'viewsChange': '+0%',
            'watchTimeChange': '+0%',
            'subscribersChange': '+0',
            'revenueChange': '+\$0.00',
          };
        }
      },
      onError: (error) {
        errorMessage.value = "Failed to load channel stats.";
      },
    );
  }

  void _loadRecentVideos() {
    final videosRef = _firestore
        .collection('videos')
        .where('channelId', isEqualTo: channelId)
        .orderBy('uploadedAt', descending: true)
        .limit(10); // Fetch more for better fallback
    _videosSubscription = videosRef.snapshots().listen(
      (snapshot) {
        recentVideos.value = snapshot.docs
            .map((doc) => Video.fromDocumentSnapshot(doc))
            .toList();
            
        // Fallback view count from recent videos if still zero
        if ((channelStats['views'] == '0' || channelStats['views'] == null) && recentVideos.isNotEmpty) {
          int totalViews = recentVideos.fold(0, (acc, v) => acc + v.viewCount);
          if (totalViews > 0) {
            channelStats.value = {
              ...channelStats,
              'views': _formatNumber(totalViews),
            };
          }
        }
      },
      onError: (error) {
        errorMessage.value = "Failed to load recent videos.";
      },
    );
  }

  void _loadAnalyticsData() {
    final endDate = DateTime.now();
    final startDate = endDate.subtract(
      const Duration(days: 27),
    ); // Last 28 days
    final statsRef = _firestore
        .collection('channels')
        .doc(channelId)
        .collection('daily_stats')
        .where(
          FieldPath.documentId,
          isGreaterThanOrEqualTo: DateFormat('yyyy-MM-dd').format(startDate),
        )
        .orderBy(FieldPath.documentId);

    _analyticsSubscription = statsRef.snapshots().listen(
      (snapshot) {
        if (snapshot.docs.isNotEmpty) {
          List<AnalyticsData> data = [];
          for (int i = 0; i < 28; i++) {
            final date = startDate.add(Duration(days: i));
            final dateString = DateFormat('yyyy-MM-dd').format(date);
            final doc = snapshot.docs.firstWhere(
              (d) => d.id == dateString,
              orElse: () => snapshot.docs[0],
            );
            data.add(AnalyticsData(date, doc.data()['views'] ?? 0));
          }
          analyticsData.value = data;
        } else {
          // Fill with zeros if no data
          analyticsData.value = List.generate(
            28,
            (i) => AnalyticsData(startDate.add(Duration(days: i)), 0),
          );
        }
      },
      onError: (error) {
        errorMessage.value = "Failed to load analytics data.";
      },
    );
  }

  void _loadCopyrightStatus() {
    if (channelId.isEmpty) return;
    _copyrightSubscription = _firestore
        .collection('copyrights')
        .where('channelId', isEqualTo: channelId)
        .snapshots()
        .listen((snapshot) {
      copyrightClaimsCount.value = snapshot.docs.length;
    });
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  String _formatWatchTime(dynamic minutes) {
    if (minutes == null) return '0h';
    double m = (minutes is num) ? minutes.toDouble() : 0.0;

    if (m >= 60) {
      double hours = m / 60;
      if (hours >= 10) {
        return '${hours.toStringAsFixed(0)}h';
      }
      return '${hours.toStringAsFixed(1)}h';
    }
    return '${m.toStringAsFixed(0)}m';
  }

  void setSelectedIndex(int index) => selectedIndex.value = index;
  void toggleDrawer() => isDrawerExpanded.value = !isDrawerExpanded.value;
  void setSearchQuery(String query) => searchQuery.value = query;
  void retryLoad() => _initializeData();
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  late final DashboardController controller;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();

  // Get channel from arguments
  dynamic get channel => Get.arguments?['channel'];

  final RxBool isSelectingDefault = false.obs;

  @override
  void initState() {
    super.initState();
    _initializeAnimations(); // Initialize early to avoid LateInitializationError in dispose

    final channelData = channel;
    if (channelData == null) {
      isSelectingDefault.value = true;
      _selectDefaultChannel();
    } else {
      isSelectingDefault.value = false;
      String channelId = '';
      if (channelData is Map<String, dynamic> &&
          channelData.containsKey('id')) {
        channelId = channelData['id'];
      } else if (channelData is DocumentSnapshot) {
        channelId = channelData.id;
      }
      controller = Get.put(DashboardController(channelId: channelId));
      final tabIndex = Get.arguments?['tab'] as int?;
      if (tabIndex != null) {
        controller.selectedIndex.value = tabIndex;
      }
      // Ensure VideoManagementController is available for ContentScreen/Get.find
      if (!Get.isRegistered<VideoManagementController>()) {
        Get.put(VideoManagementController());
      }
      _startAnimations();
    }
  }

  Future<void> _selectDefaultChannel() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        // Not authenticated -> Trigger sign-in immediately
        await _handleGoogleSignIn();
        return;
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('channels')
          .where('ownerId', isEqualTo: user.uid)
          .get();
      if (snapshot.docs.isNotEmpty) {
        final firstChannel = snapshot.docs.first;
        final channelMap = {'id': firstChannel.id, ...firstChannel.data()};
        final tabIndex = Get.arguments?['tab'] as int?;
        final args = <String, dynamic>{
          'channel': channelMap,
        };
        if (tabIndex != null) {
          args['tab'] = tabIndex;
        }
        Get.offAndToNamed("/studio", arguments: args);
      } else {
        isSelectingDefault.value = false;
        // User has no channel -> Navigate to ChannelScreen to create one!
        Get.offAllNamed('/channelscreen');
      }
    } catch (e) {
      isSelectingDefault.value = false;
      controller = Get.put(DashboardController(channelId: ''));
      if (!Get.isRegistered<VideoManagementController>()) {
        Get.put(VideoManagementController());
      }
      _startAnimations();
    }
  }

  // Animation Controllers
  late AnimationController _staggeredAnimationController;
  late AnimationController _drawerAnimationController;
  late AnimationController _statsAnimationController;
  late AnimationController _chartAnimationController;

  // Animations
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _drawerAnimation;
  late Animation<double> _statsAnimation;
  late Animation<double> _chartAnimation;

  void _initializeAnimations() {
    _staggeredAnimationController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );

    _drawerAnimationController = AnimationController(
      duration: Duration(milliseconds: 400),
      vsync: this,
    );

    _statsAnimationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    _chartAnimationController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _staggeredAnimationController,
        curve: Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    _slideAnimation = Tween<Offset>(begin: Offset(0, 0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _staggeredAnimationController,
            curve: Interval(0.2, 0.8, curve: Curves.easeOutBack),
          ),
        );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _staggeredAnimationController,
        curve: Interval(0.4, 1.0, curve: Curves.elasticOut),
      ),
    );

    _drawerAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _drawerAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _statsAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _statsAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _chartAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _chartAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  void _startAnimations() {
    _staggeredAnimationController.forward();
    _drawerAnimationController.forward();

    Future.delayed(Duration(milliseconds: 500), () {
      _statsAnimationController.forward();
    });

    Future.delayed(Duration(milliseconds: 800), () {
      _chartAnimationController.forward();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _staggeredAnimationController.dispose();
    _drawerAnimationController.dispose();
    _statsAnimationController.dispose();
    _chartAnimationController.dispose();
    Get.delete<DashboardController>();
    super.dispose();
  }

  // Responsive breakpoints
  bool get isMobile => MediaQuery.of(context).size.width < 600;
  bool get isTablet =>
      MediaQuery.of(context).size.width >= 600 &&
      MediaQuery.of(context).size.width < 1024;
  bool get isDesktop => MediaQuery.of(context).size.width >= 1024;

  double get horizontalPadding {
    if (isDesktop) return 32.0;
    if (isTablet) return 24.0;
    return 16.0;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!AuthService.to.isAuthenticated.value) {
        return _buildFallbackLoginScreen();
      }

      if (isSelectingDefault.value) {
        return Scaffold(
          body: Center(
            child: CircularProgressIndicator(
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF6366F1),
              ),
            ),
          ),
        );
      }

      final isDarkMode = Theme.of(context).brightness == Brightness.dark;

      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: isDarkMode ? AppColors.bgPage : AppColors.bgPage,
        appBar: _buildCreatorAppBar(
          isDarkMode: isDarkMode,
          isDesktop: isDesktop,
          isMobile: isMobile,
          scaffoldKey: _scaffoldKey,
        ),
        drawer: isDesktop ? null : _buildMobileDrawer(isDarkMode),
        body: Row(
          children: [
            if (isDesktop) _buildDesktopSidebar(isDarkMode),
            Expanded(child: _buildMainContent(isDarkMode)),
          ],
        ),
      );
    });
  }

  AppBar _buildCreatorAppBar({
    required bool isDarkMode,
    required bool isDesktop,
    required bool isMobile,
    required GlobalKey<ScaffoldState> scaffoldKey,
  }) {
    return AppBar(
      backgroundColor: isDarkMode ? AppColors.bgInput : Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      toolbarHeight: 64,
      centerTitle: false,
      leading: isDesktop
          ? null
          : IconButton(
              icon: Icon(
                Icons.menu_rounded,
                color: isDarkMode ? Colors.white : AppColors.textPrimary,
              ),
              onPressed: () => scaffoldKey.currentState?.openDrawer(),
              tooltip: 'Menu',
            ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, size: 20,
              color: isDarkMode ? Colors.white70 : AppColors.textSecondary,
            ),
            onPressed: () => Get.offAllNamed("/home"),
            tooltip: 'Back to Home',
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.dashboard_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            isMobile ? "Studio" : "Creator Studio",
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: GoogleFonts.roboto(
              fontSize: isMobile ? 18 : 20,
              fontWeight: FontWeight.w700,
              color: isDarkMode ? Colors.white : AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
      actions: [
        // Search field for desktop
        if (isDesktop) ...[
          _buildSearchField(isDarkMode),
          const SizedBox(width: 16),
        ],

        // Notifications
        _buildActionButton(
          icon: Icons.notifications_none_rounded,
          onPressed: () => Get.toNamed('/notifications'),
          isDarkMode: isDarkMode,
          tooltip: 'Notifications',
        ),

        const SizedBox(width: 8),

        // Upload Video Button
        _buildActionButton(
          icon: Icons.video_call_rounded,
          label: isDesktop ? 'Upload' : '',
          onPressed: () => Get.toNamed('/uploadscreen'),
          isDarkMode: isDarkMode,
          isPrimary: true,
          tooltip: 'Upload Video',
        ),

        const SizedBox(width: 8),

        // Create Channel Button (only if user doesn't have one yet)
        if (!AuthService.to.hasChannel.value)
          _buildActionButton(
            icon: Icons.add_circle_outline_rounded,
            label: isDesktop ? 'Create Channel' : '',
            onPressed: () => Get.toNamed('/channelscreen'),
            isDarkMode: isDarkMode,
            tooltip: 'Create a Channel',
          ),

        const SizedBox(width: 12),

        // Channel Selector
        _buildChannelSelector(isDarkMode),

        const SizedBox(width: 8),

        // Google Account Selector
        _buildGoogleAccountSelector(isDarkMode),

        const SizedBox(width: 16),
      ],
    );
  }

  // Search Field Widget
  Widget _buildSearchField(bool isDarkMode) {
    return Container(
      width: 300,
      height: 40,
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.colors.surface : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDarkMode ? const Color(0xFF374151) : AppColors.bgDivider,
          width: 1,
        ),
      ),
      child: TextField(
        controller: _searchController,
        style: GoogleFonts.roboto(
          color: isDarkMode ? Colors.white : AppColors.textPrimary,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: 'Search your content...',
          hintStyle: GoogleFonts.roboto(
            color: isDarkMode ? Colors.white60 : AppColors.textSecondary,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: isDarkMode ? Colors.white60 : AppColors.textSecondary,
            size: 20,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
        onChanged: (value) => controller.setSearchQuery(value),
      ),
    );
  }

  // Action Button Widget
  Widget _buildActionButton({
    required IconData icon,
    String label = '',
    required VoidCallback onPressed,
    required bool isDarkMode,
    bool isPrimary = false,
    String? tooltip,
  }) {
    final bgColor = isPrimary
        ? const Color(0xFF6366F1)
        : (isDarkMode ? AppTheme.colors.surface : const Color(0xFFF1F5F9));
    final textColor = isPrimary
        ? Colors.white
        : (isDarkMode ? Colors.white : AppColors.textPrimary);

    // Icon-only button
    if (label.isEmpty) {
      return Tooltip(
        message: tooltip ?? '',
        child: Material(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          elevation: isPrimary ? 2 : 0,
          shadowColor: isPrimary
              ? const Color(0xFF6366F1).withValues(alpha: 0.3)
              : Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              onPressed();
              HapticFeedback.lightImpact();
            },
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: Icon(icon, color: textColor, size: 20),
            ),
          ),
        ),
      );
    }

    // Button with label
    return Tooltip(
      message: tooltip ?? label,
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        elevation: isPrimary ? 2 : 0,
        shadowColor: isPrimary
            ? const Color(0xFF6366F1).withValues(alpha: 0.3)
            : Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            onPressed();
            HapticFeedback.lightImpact();
          },
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: textColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.roboto(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Channel Selector Widget
  Widget _buildChannelSelector(bool isDarkMode) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('channels')
          .where('ownerId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: 40,
            height: 40,
            margin: EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? AppTheme.colors.surface
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                ),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Tooltip(
            message: 'Error loading channels',
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDarkMode
                    ? AppTheme.colors.surface
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.error_rounded,
                color: Color(0xFFEF4444),
                size: 20,
              ),
            ),
          );
        }

        final channels = snapshot.data?.docs ?? [];

        return PopupMenuButton<dynamic>(
          tooltip: 'Select Channel',
          offset: const Offset(0, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          color: isDarkMode ? AppColors.textPrimary : Colors.white,
          onSelected: (selectedChannel) {
            final channelMap = {
              'id': selectedChannel.id,
              ...selectedChannel.data(),
            };
            Get.offAndToNamed("/studio", arguments: {'channel': channelMap});
            HapticFeedback.lightImpact();
          },
          itemBuilder: (context) => channels.isEmpty
              ? [
                  PopupMenuItem(
                    enabled: false,
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No channels available',
                        style: GoogleFonts.roboto(
                          color: isDarkMode
                              ? Colors.white70
                              : AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ]
              : channels.map((doc) {
                  final channelData = doc.data() as Map<String, dynamic>;
                  final channelName = channelData['channelName'] ?? 'Unknown';

                  return PopupMenuItem<dynamic>(
                    value: doc,
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: const Color(0xFF6366F1),
                            child: Text(
                              channelName[0].toUpperCase(),
                              style: GoogleFonts.roboto(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              channelName,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.roboto(
                                color: isDarkMode
                                    ? Colors.white
                                    : AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? AppTheme.colors.surface
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDarkMode
                    ? const Color(0xFF374151)
                    : AppColors.bgDivider,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: const Color(0xFF6366F1),
                  child: Icon(
                    Icons.workspaces_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: isDarkMode ? Colors.white : AppColors.textPrimary,
                  size: 18,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Google Account Selector Widget
  Widget _buildGoogleAccountSelector(bool isDarkMode) {
    // Get current user from Firebase Auth
    final user = FirebaseAuth.instance.currentUser;

    // If user is not signed in, show sign-in button
    if (user == null) {
      return Tooltip(
        message: 'Sign in with Google',
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.1),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              HapticFeedback.lightImpact();
              _handleGoogleSignIn();
            },
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/google_logo.png', // Add Google logo asset
                    width: 18,
                    height: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Sign in',
                    style: GoogleFonts.roboto(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // If user is signed in, show profile menu with only Switch Account and Sign Out
    return PopupMenuButton<String>(
      tooltip: 'Account',
      offset: const Offset(0, 50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isDarkMode ? AppColors.textPrimary : Colors.white,
      onSelected: (value) {
        HapticFeedback.lightImpact();
        switch (value) {
          case 'signout':
            _handleSignOut();
            break;
        }
      },
      itemBuilder: (context) => [
        // User Info Header (Non-clickable)
        PopupMenuItem(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: user.photoURL != null
                        ? NetworkImage(user.photoURL!)
                        : null,
                    backgroundColor: const Color(0xFF6366F1),
                    child: user.photoURL == null
                        ? Text(
                            (user.displayName ?? user.email ?? 'U')[0]
                                .toUpperCase(),
                            style: GoogleFonts.roboto(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.displayName ?? 'User',
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.roboto(
                            color: isDarkMode
                                ? Colors.white
                                : AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.email ?? '',
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.roboto(
                            color: isDarkMode
                                ? Colors.white60
                                : AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Divider(
                color: isDarkMode
                    ? const Color(0xFF374151)
                    : AppColors.bgDivider,
                height: 1,
              ),
            ],
          ),
        ),
      ],
      child: Container(
        padding: EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDarkMode ? AppTheme.colors.surface : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: isDarkMode
                ? const Color(0xFF374151)
                : AppColors.bgDivider,
            width: 2,
          ),
        ),
        child: CircleAvatar(
          radius: 16,
          backgroundImage: user.photoURL != null
              ? NetworkImage(user.photoURL!)
              : null,
          backgroundColor: const Color(0xFF6366F1),
          child: user.photoURL == null
              ? Text(
                  (user.displayName ?? user.email ?? 'U')[0].toUpperCase(),
                  style: GoogleFonts.roboto(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                )
              : null,
        ),
      ),
    );
  }

  // Handle Google Sign In
  Future<void> _handleGoogleSignIn() async {
    try {
      await AuthService.to.signInWithGoogle();

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        Get.snackbar(
          'Success',
          'Signed in as ${user.email}',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFF10B981),
          colorText: Colors.white,
          margin: EdgeInsets.all(16),
          borderRadius: 8,
        );
        await _selectDefaultChannel();
      } else {
        isSelectingDefault.value = false;
      }
    } catch (e) {
      isSelectingDefault.value = false;
      String message = 'Failed to sign in';
      if (e is GoogleSignInException) {
        message = e.getDisplayMessage();
      }

      Get.snackbar(
        'Sign-In Error',
        message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFEF4444),
        colorText: Colors.white,
        margin: EdgeInsets.all(16),
        borderRadius: 8,
      );
    }
  }

  // Handle Sign Out
  // ✅ WEB-ONLY Sign Out
  Future<void> _handleSignOut() async {
    try {
      await AuthService.to.signOut();

      Get.snackbar(
        'Signed Out',
        'You have been successfully signed out',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.blueGrey[800],
        colorText: Colors.white,
        margin: EdgeInsets.all(16),
        borderRadius: 8,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to sign out: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFEF4444),
        colorText: Colors.white,
        margin: EdgeInsets.all(16),
        borderRadius: 8,
      );
    }
  }

  Widget _buildDesktopSidebar(bool isDarkMode) {
    return AnimatedBuilder(
      animation: _drawerAnimation,
      builder: (context, child) {
        return Container(
          width: controller.isDrawerExpanded.value ? 280 : 80,
          decoration: BoxDecoration(
            color: isDarkMode ? AppColors.bgInput : Colors.white,
            border: Border(
              right: BorderSide(
                color: isDarkMode ? Color(0xFF374151) : AppColors.bgDivider,
                width: 1,
              ),
            ),
          ),
          child: Column(
            children: [
              _buildSidebarHeader(isDarkMode),
              Expanded(child: _buildSidebarMenu(isDarkMode)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSidebarHeader(bool isDarkMode) {
    return Obx(
      () => Container(
        padding: EdgeInsets.all(16),
        child: controller.isDrawerExpanded.value
            ? Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.chevron_left_rounded,
                      color: isDarkMode ? Colors.white60 : AppColors.textSecondary,
                    ),
                    onPressed: () {
                      controller.toggleDrawer();
                      HapticFeedback.lightImpact();
                    },
                  ),
                ],
              )
            : Center(
                child: IconButton(
                  icon: Icon(
                    Icons.chevron_right_rounded,
                    color: isDarkMode ? Colors.white60 : AppColors.textSecondary,
                  ),
                  onPressed: () {
                    controller.toggleDrawer();
                    HapticFeedback.lightImpact();
                  },
                ),
              ),
      ),
    );
  }

  Widget _buildSidebarMenu(bool isDarkMode) {
    final menuItems = [
      // Core Studio Features
      {
        'icon': Icons.grid_view_rounded,
        'label': 'Studio Home',
        'color': Color(0xFF6366F1),
        'action': 'select',
        'target': 1,
      },
      {
        'icon': Icons.video_library_rounded,
        'label': 'Content',
        'color': Color(0xFF10B981),
        'action': 'select',
        'target': 2,
      },
      {
        'icon': Icons.upload_rounded,
        'label': 'Upload',
        'color': Color(0xFFF59E0B),
        'action': 'route',
        'route': '/uploadscreen',
      },

      // Analytics & Engagement
      {
        'icon': Icons.insights_rounded,
        'label': 'Analytics',
        'color': Color(0xFF3B82F6),
        'action': 'select',
        'target': 3,
      },
      {
        'icon': Icons.forum_rounded,
        'label': 'Comments',
        'color': Color(0xFF8B5CF6),
        'action': 'select',
        'target': 4,
      },
      {
        'icon': Icons.people_rounded,
        'label': 'Audience',
        'color': Color(0xFF14B8A6),
        'action': 'select',
        'target': 12,
      },

      // Monetization & Growth
      {
        'icon': Icons.attach_money_rounded,
        'label': 'Earnings',
        'color': Color(0xFF059669),
        'action': 'select',
        'target': 5,
      },
      {
        'icon': Icons.copyright_rounded,
        'label': 'Copyright',
        'color': Color(0xFFDC2626),
        'target': 9,
      },

      // Creative Tools
      {
        'icon': Icons.spatial_audio_rounded,
        'label': 'Audio Tracks & Dubs',
        'color': Color(0xFF10B981),
        'action': 'select',
        'target': 7,
      },
      {
        'icon': Icons.color_lens_rounded,
        'label': 'Customization',
        'color': Color(0xFFEC4899),
        'action': 'select',
        'target': 6,
      },
      {
        'icon': Icons.edit_note_rounded,
        'label': 'Subtitles',
        'color': Color(0xFF7C3AED),
        'action': 'select',
        'target': 10,
      },
      {
        'icon': Icons.star_rounded,
        'label': 'Video Ratings',
        'color': Color(0xFFFF9800),
        'action': 'select',
        'target': 13,
      },
      {
        'icon': Icons.topic_rounded,
        'label': 'Topics',
        'color': Color(0xFFE11D48),
        'action': 'select',
        'target': 14,
      },
    ];

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: menuItems.length + 2, // +2 for divider and settings
      itemBuilder: (context, index) {
        // Divider before settings
        if (index == menuItems.length) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(
              color: isDarkMode ? Color(0xFF374151) : Color(0xFFE5E7EB),
              thickness: 1,
              height: 1,
            ),
          );
        }

        // Settings at the bottom
        if (index == menuItems.length + 1) {
          return _buildSidebarItem(
            icon: Icons.settings_rounded,
            label: 'Settings',
            color: Color(0xFF6B7280),
            isSelected: controller.selectedIndex.value == 8,
            onTap: () => controller.setSelectedIndex(8),
            isDarkMode: isDarkMode,
          );
        }

        // Regular menu items: perform action based on item['action']
        final item = menuItems[index];
        final action = item['action'] as String? ?? 'select';
        final icon = item['icon'] as IconData;
        final label = item['label'] as String;
        final color = item['color'] as Color;

        VoidCallback onTapCallback;
        bool isSelected = false;

        if (action == 'select') {
          final target = item['target'] as int? ?? (index + 1);
          isSelected = controller.selectedIndex.value == target;
          onTapCallback = () => controller.setSelectedIndex(target);
        } else if (action == 'route') {
          final route = item['route'] as String?;
          onTapCallback = () {
            if (route != null && route.isNotEmpty) Get.toNamed(route);
          };
        } else if (action == 'placeholder') {
          onTapCallback = () {
            Get.to(
              () => PlaceholderScreen(
                icon: icon,
                featureName: label,
                isDarkMode: isDarkMode,
              ),
            );
          };
        } else {
          onTapCallback = () => controller.setSelectedIndex(index + 1);
        }

        return _buildSidebarItem(
          icon: icon,
          label: label,
          color: color,
          isSelected: isSelected,
          onTap: onTapCallback,
          isDarkMode: isDarkMode,
        );
      },
    );
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required String label,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDarkMode,
  }) {
    return Obx(
      () => Container(
        margin: EdgeInsets.symmetric(vertical: 2),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              onTap();
              HapticFeedback.lightImpact();
            },
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: controller.isDrawerExpanded.value ? 12 : 16,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: isSelected
                    ? Border.all(color: color.withValues(alpha: 0.3), width: 1)
                    : null,
              ),
              child: controller.isDrawerExpanded.value
                  ? Row(
                      children: [
                        Icon(
                          icon,
                          color: isSelected
                              ? color
                              : (isDarkMode
                                    ? Colors.white60
                                    : AppColors.textSecondary),
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            label,
                            style: GoogleFonts.roboto(
                              color: isSelected
                                  ? color
                                  : (isDarkMode
                                        ? Colors.white
                                        : AppColors.textPrimary),
                              fontWeight: isSelected
                                  ? FontWeight.w500
                                  : FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Center(
                      child: Icon(
                        icon,
                        color: isSelected
                            ? color
                            : (isDarkMode ? Colors.white60 : AppColors.textSecondary),
                        size: 20,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileDrawer(bool isDarkMode) {
    return Drawer(
      backgroundColor: isDarkMode ? AppColors.bgInput : Colors.white,
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.dashboard_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Creator Studio',
                    style: GoogleFonts.roboto(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildSidebarMenu(isDarkMode)),
        ],
      ),
    );
  }

  Widget _buildMainContent(bool isDarkMode) {
    if (channel == null) {
      return _buildNoChannelSelected(isDarkMode);
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Obx(() {
            switch (controller.selectedIndex.value) {
              case 1:
                return _buildDashboardContent(isDarkMode);
              case 2:
                final currentChannel = channel;
                if (currentChannel != null) {
                  final channelId =
                      (currentChannel is Map
                              ? currentChannel['id']
                              : (currentChannel as DocumentSnapshot).id)
                          as String;
                  return ContentScreen(
                    channelId: channelId,
                    isDarkMode: isDarkMode,
                    searchQuery: controller.searchQuery.value,
                  );
                }
                return _buildNoChannelSelected(isDarkMode);
              case 3:
                final currentChannel = channel;
                if (currentChannel != null) {
                  final channelId = (currentChannel is Map
                          ? currentChannel['id']
                          : (currentChannel as DocumentSnapshot).id)
                      as String;
                  return AnalyticsScreen(
                    isDarkMode: isDarkMode,
                    channelId: channelId,
                  );
                }
                return _buildNoChannelSelected(isDarkMode);
              case 4:
                return DashboardCommentsPage();
              case 5:
                return MonetizationScreen(isDarkMode: isDarkMode);
              case 6:
                final currentChannel = channel;
                if (currentChannel != null) {
                  final String channelId = currentChannel is Map
                      ? (currentChannel['id'] ?? '') as String
                      : (currentChannel as DocumentSnapshot).id;
                  final String ownerId = currentChannel is Map
                      ? (currentChannel['ownerId'] ?? '') as String
                      : ((currentChannel as DocumentSnapshot).data()
                              as Map<String, dynamic>?)?['ownerId'] as String? ??
                          '';
                  return ChannelCustomizationPage(
                    channelId: channelId,
                    ownerId: ownerId,
                  );
                }
                return _buildNoChannelSelected(isDarkMode);
              case 7:
                final currentChannel = channel;
                if (currentChannel != null) {
                  final channelId =
                      (currentChannel is Map
                              ? currentChannel['id']
                              : (currentChannel as DocumentSnapshot).id)
                          as String;
                  return AudioTracksPage(
                    channelId: channelId,
                    isDarkMode: isDarkMode,
                  );
                }
                return _buildNoChannelSelected(isDarkMode);
              case 8:
                return StudioSettingsPage();
              case 9:
                final currentChannel = channel;
                if (currentChannel != null) {
                  final channelId = (currentChannel is Map
                          ? currentChannel['id']
                          : (currentChannel as DocumentSnapshot).id)
                      as String;
                  return CopyrightScreen(channelId: channelId);
                }
                return _buildNoChannelSelected(isDarkMode);
              case 10:
                final currentChannel = channel;
                if (currentChannel != null) {
                  final channelId =
                      (currentChannel is Map
                              ? currentChannel['id']
                              : (currentChannel as DocumentSnapshot).id)
                          as String;
                  return SubtitlesPage(
                    channelId: channelId,
                    isDarkMode: isDarkMode,
                  );
                }
                return _buildNoChannelSelected(isDarkMode);
              case 12:
                final currentChannel = channel;
                if (currentChannel != null) {
                  final channelId =
                      (currentChannel is Map
                              ? currentChannel['id']
                              : (currentChannel as DocumentSnapshot).id)
                          as String;
                  return AudiencePage(
                    channelId: channelId,
                    isDarkMode: isDarkMode,
                  );
                }
                return _buildNoChannelSelected(isDarkMode);
              case 13:
                final currentChannel = channel;
                if (currentChannel != null) {
                  final channelId = (currentChannel is Map
                          ? currentChannel['id']
                          : (currentChannel as DocumentSnapshot).id)
                      as String;
                  if (!Get.isRegistered<VideoRatingController>()) {
                    Get.put(VideoRatingController(channelId: channelId));
                  }
                  return const VideoRatingPage();
                }
                return _buildNoChannelSelected(isDarkMode);
              case 14:
                final currentChannel = channel;
                if (currentChannel != null) {
                  final channelId =
                      (currentChannel is Map
                              ? currentChannel['id']
                              : (currentChannel as DocumentSnapshot).id)
                          as String;
                  return TopicManagementScreen(
                    channelId: channelId,
                    isDarkMode: isDarkMode,
                    searchQuery: controller.searchQuery.value,
                  );
                }
                return _buildNoChannelSelected(isDarkMode);
              default:
                return _buildDashboardContent(isDarkMode);
            }
          }),
        ),
      ),
    );
  }

  Widget _buildNoChannelSelected(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: isMobile ? 120 : 160,
            height: isMobile ? 120 : 160,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF6366F1).withValues(alpha: 0.2),
                  Color(0xFF8B5CF6).withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(isMobile ? 60 : 80),
            ),
            child: Icon(
              Icons.info_outline_rounded,
              size: isMobile ? 60 : 80,
              color: Color(0xFF6366F1),
            ),
          ),
          SizedBox(height: isMobile ? 24 : 32),
          Text(
            'No Channel Selected',
            style: GoogleFonts.roboto(
              fontSize: isMobile ? 24 : 32,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Please select a channel from the menu to continue.',
            style: GoogleFonts.roboto(
              fontSize: isMobile ? 14 : 16,
              color: isDarkMode ? Colors.white70 : AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardContent(bool isDarkMode) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(horizontalPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDashboardHeader(isDarkMode),
          Obx(() {
            final ch = controller.currentChannel.value;
            if (ch == null) return const SizedBox.shrink();
            if (ch.status == ChannelStatus.active) {
              if (controller.showApprovalBanner.value) {
                return _buildApprovalBanner(isDarkMode);
              }
              return const SizedBox.shrink();
            }
            return _buildModerationStatusBanner(isDarkMode, ch);
          }),
          Obx(() {
            final ch = controller.currentChannel.value;
            if (ch == null) return const SizedBox.shrink();
            return _buildImageVerificationBanner(isDarkMode, ch);
          }),
          _buildChannelStatsGrid(isDarkMode),
          Obx(() {
            if (controller.copyrightClaimsCount.value > 0) {
              return Column(
                children: [
                  SizedBox(height: 24),
                  _buildChannelViolationsCard(isDarkMode),
                ],
              );
            }
            return SizedBox.shrink();
          }),
          SizedBox(height: 32),
          _buildRecentPerformanceSection(isDarkMode),
          SizedBox(height: 32),
          _buildRecommendationsSection(isDarkMode),
          SizedBox(height: 32),
          _buildLatestContentSection(isDarkMode),
          SizedBox(height: 32),
          _buildQuickActionsSection(isDarkMode),
        ],
      ),
    );
  }

  Widget _buildImageVerificationBanner(bool isDarkMode, Channel channel) {
    final List<Widget> banners = [];

    // Avatar status
    if (channel.avatarStatus == "PENDING") {
      banners.add(
        _buildVerificationAlertCard(
          isDarkMode: isDarkMode,
          title: "Avatar Verification Pending",
          subtitle: "Google Vision AI is currently validating your channel avatar image. This will complete in a few moments.",
          color: const Color(0xFF3B82F6),
          icon: Icons.sync_rounded,
          isPending: true,
          onBypassPressed: () async {
            try {
              await FirebaseFirestore.instance.collection('channels').doc(channel.id).update({
                'avatarStatus': 'APPROVED',
                'avatarStatusReason': 'Bypassed in local/debug environment.',
                'updatedAt': DateTime.now().millisecondsSinceEpoch,
              });
              if (channel.avatarFileId != null && channel.avatarFileId!.isNotEmpty) {
                await FirebaseFirestore.instance.collection('image_verification').doc(channel.avatarFileId!).set({
                  'status': 'APPROVED',
                  'reason': 'Bypassed in local/debug environment.',
                  'category': 'avatar',
                  'processedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
              }
              Get.snackbar("Bypassed", "Avatar approved successfully.", backgroundColor: Colors.green, colorText: Colors.white);
            } catch (e) {
              Get.snackbar("Error", e.toString(), backgroundColor: Colors.red, colorText: Colors.white);
            }
          },
        ),
      );
    } else if (channel.avatarStatus == "REJECTED") {
      banners.add(
        _buildVerificationAlertCard(
          isDarkMode: isDarkMode,
          title: "Avatar Image Rejected",
          subtitle: "Your uploaded avatar image did not pass our automated content verification guidelines. Please go to Customization to upload a new one.",
          color: const Color(0xFFEF4444),
          icon: Icons.error_outline_rounded,
          showCustomizationButton: true,
        ),
      );
    } else if (channel.avatarStatus == "FLAGGED") {
      banners.add(
        _buildVerificationAlertCard(
          isDarkMode: isDarkMode,
          title: "Avatar Review Needed",
          subtitle: "Your avatar image was flagged for potential guidelines violations. It is currently queued for manual review.",
          color: const Color(0xFFF59E0B),
          icon: Icons.warning_amber_rounded,
          showCustomizationButton: true,
        ),
      );
    }

    // Banner status
    if (channel.bannerStatus == "PENDING") {
      banners.add(
        _buildVerificationAlertCard(
          isDarkMode: isDarkMode,
          title: "Banner Verification Pending",
          subtitle: "Google Vision AI is currently validating your channel banner image. This will complete in a few moments.",
          color: const Color(0xFF3B82F6),
          icon: Icons.sync_rounded,
          isPending: true,
          onBypassPressed: () async {
            try {
              await FirebaseFirestore.instance.collection('channels').doc(channel.id).update({
                'bannerStatus': 'APPROVED',
                'bannerStatusReason': 'Bypassed in local/debug environment.',
                'updatedAt': DateTime.now().millisecondsSinceEpoch,
              });
              if (channel.bannerFileId != null && channel.bannerFileId!.isNotEmpty) {
                await FirebaseFirestore.instance.collection('image_verification').doc(channel.bannerFileId!).set({
                  'status': 'APPROVED',
                  'reason': 'Bypassed in local/debug environment.',
                  'category': 'banner',
                  'processedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
              }
              Get.snackbar("Bypassed", "Banner approved successfully.", backgroundColor: Colors.green, colorText: Colors.white);
            } catch (e) {
              Get.snackbar("Error", e.toString(), backgroundColor: Colors.red, colorText: Colors.white);
            }
          },
        ),
      );
    } else if (channel.bannerStatus == "REJECTED") {
      banners.add(
        _buildVerificationAlertCard(
          isDarkMode: isDarkMode,
          title: "Banner Image Rejected",
          subtitle: "Your uploaded banner image did not pass our automated content verification guidelines. Please go to Customization to upload a new one.",
          color: const Color(0xFFEF4444),
          icon: Icons.error_outline_rounded,
          showCustomizationButton: true,
        ),
      );
    } else if (channel.bannerStatus == "FLAGGED") {
      banners.add(
        _buildVerificationAlertCard(
          isDarkMode: isDarkMode,
          title: "Banner Review Needed",
          subtitle: "Your banner image was flagged for potential guidelines violations. It is currently queued for manual review.",
          color: const Color(0xFFF59E0B),
          icon: Icons.warning_amber_rounded,
          showCustomizationButton: true,
        ),
      );
    }

    if (banners.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: banners,
    );
  }

  Widget _buildVerificationAlertCard({
    required bool isDarkMode,
    required String title,
    required String subtitle,
    required Color color,
    required IconData icon,
    bool isPending = false,
    bool showCustomizationButton = false,
    VoidCallback? onBypassPressed,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isPending)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
              ),
            )
          else
            Icon(icon, color: color, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.roboto(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: GoogleFonts.roboto(
                    color: isDarkMode ? Colors.white70 : AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                if (showCustomizationButton) ...[
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      controller.selectedIndex.value = 6; // Channel Customization tab
                    },
                    icon: const Icon(Icons.color_lens_outlined, size: 16),
                    label: const Text('Go to Customization'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ],
                if (isPending && onBypassPressed != null) ...[
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: onBypassPressed,
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                    label: const Text('Bypass Verification (Local Dev/Test)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildChannelViolationsCard(bool isDarkMode) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.colors.surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.error.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 24),
              SizedBox(width: 12),
              Text(
                'Channel violations',
                style: GoogleFonts.roboto(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Text(
            'Copyright claims',
            style: GoogleFonts.roboto(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Your channel has ${controller.copyrightClaimsCount.value} active copyright claims. This may affect your visibility or monetization.',
            style: GoogleFonts.roboto(
              fontSize: 14,
              color: isDarkMode ? Colors.white70 : AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 16),
          InkWell(
            onTap: () {
              controller.selectedIndex.value = 9; // Navigate to Copyright Screen
            },
            child: Text(
              'VIEW DETAILS',
              style: GoogleFonts.roboto(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.brand,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardHeader(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Channel Overview',
                    style: GoogleFonts.roboto(
                      fontSize: isMobile ? 24 : 32,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Last 28 days',
                    style: GoogleFonts.roboto(
                      fontSize: 14,
                      color: isDarkMode ? Colors.white70 : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (channel != null)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text(
                      (channel is Map
                              ? (channel['channelName'] ?? channel['name'])
                              : (channel as DocumentSnapshot)['name'] ??
                                  (channel as DocumentSnapshot)['channelName']) ??
                          'Unknown Channel',
                      style: GoogleFonts.roboto(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        if (isMobile) ...[
          SizedBox(height: 16),
          _buildMobileSearchField(isDarkMode),
        ],
      ],
    );
  }

  Widget _buildModerationStatusBanner(bool isDarkMode, Channel channel) {
    if (channel.status == ChannelStatus.active) {
      return const SizedBox.shrink();
    }

    Color bannerColor;
    IconData icon;
    String title;
    String subtitle;
    bool showButton = false;

    if (channel.status == ChannelStatus.underReview) {
      bannerColor = const Color(0xFF3B82F6); // Blue
      icon = Icons.sync_rounded;
      title = 'Branding Under Gemini AI Moderation';
      subtitle = 'Gemini is checking your channel details (name, description, tags) against our community guidelines. This usually takes just a few seconds.';
    } else if (channel.status == ChannelStatus.verificationRejected) {
      bannerColor = const Color(0xFFEF4444); // Red
      icon = Icons.error_outline_rounded;
      title = 'Branding Verification Rejected by Gemini AI';
      subtitle = 'We created channel according to community guidelines, then channel selected for manual verification. ${channel.moderationReason != null && channel.moderationReason!.isNotEmpty ? '\n\nGemini Response: ${channel.moderationReason}' : ''}';
      showButton = true;
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bannerColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: bannerColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (channel.status == ChannelStatus.underReview)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
              ),
            )
          else
            Icon(icon, color: bannerColor, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.roboto(
                    color: bannerColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: GoogleFonts.roboto(
                    color: isDarkMode ? Colors.white70 : AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                if (showButton) ...[
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      Get.toNamed('/community-guidelines', arguments: {
                        'fromRejectedChannelId': channel.id,
                        'ownerId': channel.ownerId,
                      });
                    },
                    icon: const Icon(Icons.description_outlined, size: 16),
                    label: const Text('Review Community Guidelines'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: bannerColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalBanner(bool isDarkMode) {
    final bannerColor = const Color(0xFF10B981); // Emerald green
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bannerColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: bannerColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_outline_rounded, color: bannerColor, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Branding Approved by Gemini AI!',
                  style: GoogleFonts.roboto(
                    color: bannerColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Congratulations! Your channel details are approved. You can now customize your channel and upload videos.',
                  style: GoogleFonts.roboto(
                    color: isDarkMode ? Colors.white70 : AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              controller.showApprovalBanner.value = false;
            },
            icon: const Icon(Icons.close_rounded),
            color: isDarkMode ? Colors.white54 : Colors.black54,
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileSearchField(bool isDarkMode) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.colors.surface : Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDarkMode ? Color(0xFF374151) : AppColors.bgDivider,
        ),
      ),
      child: TextField(
        controller: _searchController,
        style: GoogleFonts.roboto(
          color: isDarkMode ? Colors.white : AppColors.textPrimary,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: 'Search your content...',
          hintStyle: GoogleFonts.roboto(
            color: isDarkMode ? Colors.white60 : AppColors.textSecondary,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: isDarkMode ? Colors.white60 : AppColors.textSecondary,
            size: 20,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
        onChanged: (value) => controller.setSearchQuery(value),
      ),
    );
  }

  Widget _buildChannelStatsGrid(bool isDarkMode) {
    return AnimatedBuilder(
      animation: _statsAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _statsAnimation.value,
          child: Opacity(
            opacity: _statsAnimation.value,
            child: Obx(() {
              if (controller.isLoading.value &&
                  controller.channelStats.isEmpty) {
                return _buildStatsLoadingGrid(isDarkMode);
              }

              return GridView.count(
                crossAxisCount: isDesktop ? 4 : (isTablet ? 2 : 1),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                childAspectRatio: isDesktop ? 1.2 : (isTablet ? 1.5 : 2.5),
                children: [
                  _buildStatCard(
                    'Views',
                    controller.channelStats['views'] ?? '0',
                    controller.channelStats['viewsChange'] ?? '+0%',
                    Icons.visibility_rounded,
                    const Color(0xFF10B981),
                    isDarkMode,
                    onTap: () {
                      final channelData = channel;
                      if (channelData != null) {
                        final channelId = (channelData is Map
                            ? channelData['id']
                            : (channelData as DocumentSnapshot).id) as String;
                        final channelName = (channelData is Map
                            ? channelData['channelName']
                            : (channelData as DocumentSnapshot)['channelName']) as String? ?? 'My Channel';
                        
                        Get.to(() => const ViewsPage(), arguments: {
                          'channelId': channelId,
                          'channelName': channelName,
                          'viewsChange': controller.channelStats['viewsChange'] ?? '+0%',
                        });
                      }
                    },
                  ),
                  _buildStatCard(
                    'Watch Time',
                    controller.channelStats['watchTime'] ?? '0h',
                    controller.channelStats['watchTimeChange'] ?? '+0%',
                    Icons.timer_rounded,
                    const Color(0xFF3B82F6),
                    isDarkMode,
                    onTap: () {
                      final channelData = channel;
                      if (channelData != null) {
                        final channelId = (channelData is Map
                            ? channelData['id']
                            : (channelData as DocumentSnapshot).id) as String;
                        final channelName = (channelData is Map
                            ? channelData['channelName']
                            : (channelData as DocumentSnapshot)['channelName']) as String? ?? 'My Channel';
                        
                        Get.to(() => const WatchTimePage(), arguments: {
                          'channelId': channelId,
                          'channelName': channelName,
                          'watchTimeChange': controller.channelStats['watchTimeChange'] ?? '+0%',
                        });
                      }
                    },
                  ),
                  _buildStatCard(
                    'Subscribers',
                    controller.channelStats['subscribers'] ?? '0',
                    controller.channelStats['subscribersChange'] ?? '+0',
                    Icons.people_rounded,
                    const Color(0xFF8B5CF6),
                    isDarkMode,
                    onTap: () {
                      final channelData = channel;
                      if (channelData != null) {
                        final channelId = (channelData is Map
                            ? channelData['id']
                            : (channelData as DocumentSnapshot).id) as String;
                        final channelName = (channelData is Map
                            ? channelData['channelName']
                            : (channelData as DocumentSnapshot)['channelName']) as String? ?? 'My Channel';
                        
                        Get.to(() => const SubscribersPage(), arguments: {
                          'channelId': channelId,
                          'channelName': channelName,
                          'subscribersChange': controller.channelStats['subscribersChange'] ?? '+0',
                        });
                      }
                    },
                  ),
                  _buildStatCard(
                    'Revenue',
                    controller.channelStats['revenue'] ?? '\$0.00',
                    controller.channelStats['revenueChange'] ?? '+\$0.00',
                    Icons.attach_money_rounded,
                    const Color(0xFFF59E0B),
                    isDarkMode,
                  ),
                ],
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildStatsLoadingGrid(bool isDarkMode) {
    return GridView.count(
      crossAxisCount: isDesktop ? 4 : (isTablet ? 2 : 1),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      childAspectRatio: isDesktop ? 1.2 : (isTablet ? 1.5 : 2.5),
      children: List.generate(4, (index) => _buildStatCardSkeleton(isDarkMode)),
    );
  }

  Widget _buildStatCardSkeleton(bool isDarkMode) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.colors.surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? Color(0xFF374151) : AppColors.bgDivider,
        ),
      ),
      child: Shimmer.fromColors(
        baseColor: isDarkMode ? Color(0xFF374151) : AppColors.bgDivider,
        highlightColor: isDarkMode ? Color(0xFF4B5563) : Color(0xFFF1F5F9),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 60,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Container(
                width: 80,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              SizedBox(height: 12),
              Container(
                width: 50,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    String change,
    IconData icon,
    Color color,
    bool isDarkMode, {
    VoidCallback? onTap,
  }) {
    final isPositive = change.startsWith('+');

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 600),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, animationValue, child) {
        return Transform.scale(
          scale: 0.8 + (0.2 * animationValue),
          child: Container(
            decoration: BoxDecoration(
              color: isDarkMode ? AppTheme.colors.surface : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDarkMode ? Color(0xFF374151) : AppColors.bgDivider,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDarkMode ? Colors.black26 : Colors.black38,
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  HapticFeedback.lightImpact();
                  if (onTap != null) onTap();
                },
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.roboto(
                              color: isDarkMode
                                  ? Colors.white70
                                  : AppColors.textSecondary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(icon, color: color, size: 20),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Text(
                        value,
                        style: GoogleFonts.roboto(
                          fontSize: isMobile ? 20 : 24,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isPositive
                                  ? Color(0xFF10B981).withValues(alpha: 0.1)
                                  : Color(0xFFEF4444).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isPositive
                                      ? Icons.trending_up_rounded
                                      : Icons.trending_down_rounded,
                                  size: 14,
                                  color: isPositive
                                      ? Color(0xFF10B981)
                                      : Color(0xFFEF4444),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  change,
                                  style: GoogleFonts.roboto(
                                    color: isPositive
                                        ? Color(0xFF10B981)
                                        : Color(0xFFEF4444),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecentPerformanceSection(bool isDarkMode) {
    return AnimatedBuilder(
      animation: _chartAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - _chartAnimation.value)),
          child: Opacity(
            opacity: _chartAnimation.value,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Performance',
                      style: GoogleFonts.roboto(
                        fontSize: isMobile ? 20 : 24,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? AppTheme.colors.surface
                            : Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDarkMode
                              ? Color(0xFF374151)
                              : AppColors.bgDivider,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.date_range_rounded,
                            color: Color(0xFF6366F1),
                            size: 16,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Last 28 days',
                            style: GoogleFonts.roboto(
                              color: Color(0xFF6366F1),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                Container(
                  height: 300,
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDarkMode ? AppTheme.colors.surface : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDarkMode ? Color(0xFF374151) : AppColors.bgDivider,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDarkMode ? Colors.black26 : Colors.black38,
                        blurRadius: 20,
                        spreadRadius: 2,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _buildPerformanceChart(isDarkMode),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPerformanceChart(bool isDarkMode) {
    return Obx(() {
      if (controller.analyticsData.isEmpty) {
        return Center(
          child: Text(
            "No analytics data yet.",
            style: TextStyle(
              color: isDarkMode ? Colors.white54 : Colors.black45,
            ),
          ),
        );
      }

      return SfCartesianChart(
        plotAreaBorderWidth: 0,
        primaryXAxis: DateTimeAxis(
          majorGridLines: MajorGridLines(width: 0),
          labelStyle: TextStyle(
            color: isDarkMode ? Colors.white70 : AppColors.textSecondary,
          ),
          axisLine: AxisLine(
            width: 1,
            color: isDarkMode ? Color(0xFF374151) : AppColors.bgDivider,
          ),
        ),
        primaryYAxis: NumericAxis(
          labelStyle: TextStyle(
            color: isDarkMode ? Colors.white70 : AppColors.textSecondary,
          ),
          axisLine: AxisLine(width: 0),
          majorTickLines: MajorTickLines(width: 0),
          majorGridLines: MajorGridLines(
            width: 1,
            color: isDarkMode ? Color(0xFF374151) : AppColors.bgDivider,
            dashArray: [5, 5],
          ),
        ),
        tooltipBehavior: TooltipBehavior(enable: true),
        series: <CartesianSeries<AnalyticsData, DateTime>>[
          SplineAreaSeries<AnalyticsData, DateTime>(
            dataSource: controller.analyticsData,
            xValueMapper: (AnalyticsData data, _) => data.date,
            yValueMapper: (AnalyticsData data, _) => data.views,
            gradient: LinearGradient(
              colors: [
                Color(0xFF6366F1).withValues(alpha: 0.3),
                Color(0xFF6366F1).withValues(alpha: 0.1),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderWidth: 3,
            borderColor: Color(0xFF6366F1),
            name: 'Views',
          ),
        ],
      );
    });
  }

  Widget _buildRecommendationsSection(bool isDarkMode) {
    final recommendations = [
      {
        'title': 'Update Channel Banner',
        'description':
            'A refreshed banner can increase your channel visibility by up to 25%',
        'icon': Icons.image_rounded,
        'color': Color(0xFF10B981),
        'action': 'Update Now',
      },
      {
        'title': 'Optimize Thumbnails',
        'description':
            'Your recent video thumbnails can be improved to increase CTR',
        'icon': Icons.filter_rounded,
        'color': Color(0xFF3B82F6),
        'action': 'Learn More',
      },
      {
        'title': 'Schedule More Uploads',
        'description':
            'Try to maintain a consistent upload schedule for better engagement',
        'icon': Icons.schedule_rounded,
        'color': Color(0xFFF59E0B),
        'action': 'Set Schedule',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recommendations',
          style: GoogleFonts.roboto(
            fontSize: isMobile ? 20 : 24,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 20),
        GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isDesktop ? 3 : (isTablet ? 2 : 1),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: isDesktop ? 1.0 : (isTablet ? 1.2 : 1.5),
          ),
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: recommendations.length,
          itemBuilder: (context, index) {
            final rec = recommendations[index];
            return TweenAnimationBuilder<double>(
              duration: Duration(milliseconds: 600 + (index * 200)),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, 50 * (1 - value)),
                  child: Opacity(
                    opacity: value,
                    child: _buildRecommendationCard(rec, isDarkMode),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildRecommendationCard(
    Map<String, dynamic> recommendation,
    bool isDarkMode,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.colors.surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? Color(0xFF374151) : AppColors.bgDivider,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode ? Colors.black26 : Colors.black38,
            blurRadius: 20,
            spreadRadius: 2,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => HapticFeedback.lightImpact(),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: (recommendation['color'] as Color).withValues(
                      alpha: 0.1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    recommendation['icon'] as IconData,
                    color: recommendation['color'] as Color,
                    size: 24,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  recommendation['title'] as String,
                  style: GoogleFonts.roboto(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 8),
                Expanded(
                  child: Text(
                    recommendation['description'] as String,
                    style: GoogleFonts.roboto(
                      color: isDarkMode ? Colors.white70 : AppColors.textSecondary,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
                SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => HapticFeedback.lightImpact(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: recommendation['color'] as Color,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    child: Text(
                      recommendation['action'] as String,
                      style: GoogleFonts.roboto(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLatestContentSection(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Latest Content',
              style: GoogleFonts.roboto(
                fontSize: isMobile ? 20 : 24,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : AppColors.textPrimary,
              ),
            ),
            TextButton.icon(
              onPressed: () => controller.setSelectedIndex(2),
              icon: Icon(
                Icons.arrow_forward_rounded,
                color: Color(0xFF6366F1),
                size: 16,
              ),
              label: Text(
                'View all',
                style: GoogleFonts.roboto(
                  color: Color(0xFF6366F1),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 20),
        Obx(() {
          final filtered = controller.filteredVideos;
          if (filtered.isEmpty) {
            return Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(
                      Icons.search_off_rounded,
                      size: 48,
                      color: isDarkMode ? Colors.white30 : Color(0xFFCBD5E1),
                    ),
                    SizedBox(height: 16),
                    Text(
                      controller.searchQuery.value.isEmpty
                          ? 'No content yet'
                          : 'No matching content found',
                      style: GoogleFonts.roboto(
                        color: isDarkMode ? Colors.white60 : AppColors.textSecondary,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            separatorBuilder: (context, index) => SizedBox(height: 16),
            itemBuilder: (context, index) {
              final video = filtered[index];
              return TweenAnimationBuilder<double>(
                duration: Duration(milliseconds: 400 + (index * 150)),
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(30 * (1 - value), 0),
                    child: Opacity(
                      opacity: value,
                      child: _buildContentCard(video, isDarkMode),
                    ),
                  );
                },
              );
            },
          );
        }),
      ],
    );
  }

  Widget _buildContentCard(Video video, bool isDarkMode) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.colors.surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? Color(0xFF374151) : AppColors.bgDivider,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode ? Colors.black26 : Colors.black38,
            blurRadius: 20,
            spreadRadius: 2,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => HapticFeedback.lightImpact(),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: isMobile ? 120 : 160,
                  height: isMobile ? 68 : 90,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: isDarkMode ? Color(0xFF374151) : Color(0xFFF1F5F9),
                  ),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: video.thumbnailUrl,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: isDarkMode
                                ? Color(0xFF374151)
                                : Color(0xFFF1F5F9),
                            child: Icon(
                              Icons.play_circle_outline_rounded,
                              color: isDarkMode
                                  ? Colors.white60
                                  : AppColors.textSecondary,
                              size: 32,
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: isDarkMode
                                ? Color(0xFF374151)
                                : Color(0xFFF1F5F9),
                            child: Icon(
                              Icons.play_circle_outline_rounded,
                              color: isDarkMode
                                  ? Colors.white60
                                  : AppColors.textSecondary,
                              size: 32,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            video.duration,
                            style: GoogleFonts.roboto(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.title,
                        style: GoogleFonts.roboto(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: isDarkMode ? Colors.white : AppColors.textPrimary,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.visibility_rounded,
                            size: 14,
                            color: isDarkMode
                                ? Colors.white60
                                : AppColors.textSecondary,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '${video.views} views',
                            style: GoogleFonts.roboto(
                              color: isDarkMode
                                  ? Colors.white60
                                  : AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          SizedBox(width: 12),
                          Icon(
                            Icons.access_time_rounded,
                            size: 14,
                            color: isDarkMode
                                ? Colors.white60
                                : AppColors.textSecondary,
                          ),
                          SizedBox(width: 4),
                          Text(
                            DateFormat(
                              'MMM d, yyyy',
                            ).format(video.uploadedAt.toDate()),
                            style: GoogleFonts.roboto(
                              color: isDarkMode
                                  ? Colors.white60
                                  : AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.more_vert_rounded,
                  color: isDarkMode ? Colors.white60 : AppColors.textSecondary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionsSection(bool isDarkMode) {
    final actions = [
      {
        'title': 'Upload Video',
        'icon': Icons.cloud_upload_rounded,
        'color': Color(0xFF10B981),
        'onTap': () => Get.toNamed('/uploadscreen'),
      },
      {
        'title': 'Go Live',
        'icon': Icons.videocam_rounded,
        'color': Color(0xFFEF4444),
        'onTap': () => Get.toNamed('/live'),
      },
      {
        'title': 'Create Post',
        'icon': Icons.edit_rounded,
        'color': Color(0xFF3B82F6),
        'onTap': () => Get.toNamed('/create-post'),
      },
      {
        'title': 'View Analytics',
        'icon': Icons.bar_chart_rounded,
        'color': Color(0xFF8B5CF6),
        'onTap': () => controller.setSelectedIndex(3),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: GoogleFonts.roboto(
            fontSize: isMobile ? 20 : 24,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 20),
        GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isDesktop ? 4 : (isTablet ? 2 : 2),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: isDesktop ? 1.5 : (isTablet ? 1.8 : 1.5),
          ),
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: actions.length,
          itemBuilder: (context, index) {
            final action = actions[index];
            return TweenAnimationBuilder<double>(
              duration: Duration(milliseconds: 400 + (index * 100)),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Transform.scale(
                  scale: 0.8 + (0.2 * value),
                  child: Opacity(
                    opacity: value,
                    child: _buildQuickActionCard(action, isDarkMode),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildQuickActionCard(Map<String, dynamic> action, bool isDarkMode) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.colors.surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? Color(0xFF374151) : AppColors.bgDivider,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode ? Colors.black26 : Colors.black38,
            blurRadius: 20,
            spreadRadius: 2,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            action['onTap']();
            HapticFeedback.lightImpact();
          },
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: (action['color'] as Color).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    action['icon'] as IconData,
                    color: action['color'] as Color,
                    size: 24,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  action['title'] as String,
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? Colors.white : AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Placeholder screens for other sections

  Widget _buildFallbackLoginScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0014),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.dashboard_rounded,
                color: Color(0xFF6366F1),
                size: 80,
              ),
              const SizedBox(height: 24),
              Text(
                'Creator Studio',
                style: GoogleFonts.roboto(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Please sign in to access your Creator Studio dashboard.',
                style: GoogleFonts.roboto(
                  fontSize: 16,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  isSelectingDefault.value = true;
                  _handleGoogleSignIn();
                },
                icon: const Icon(Icons.login_rounded),
                label: const Text('Sign In with Google'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}





