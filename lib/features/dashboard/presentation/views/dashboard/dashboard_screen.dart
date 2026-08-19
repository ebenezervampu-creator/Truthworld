import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/utils/watch_time_formatter.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/analytics/presentation/pages/subscribers_page.dart';
import 'package:truthworld/features/analytics/presentation/pages/views_page.dart';
import 'package:truthworld/features/analytics/presentation/pages/watch_time_page.dart';
import 'package:truthworld/features/dashboard/presentation/bindings/dashboard_binding.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/topic_management_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/analytics/analytics_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audience_page.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks_page.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/category_insights_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/content_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/copyright_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/creator_intelligence_page.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/customization_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/dashboard_comments_page.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/drafts_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/memberships_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/monetization_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/place_holder_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/playlists_management_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/studio_settings_page.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/subtitles_page.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/topic_management_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification_dashboard_page.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/video_management.dart';
import 'package:truthworld/features/topics/presentation/widgets/create_topic_dialog.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

class AnalyticsData {
  AnalyticsData(this.date, this.views);
  final DateTime date;
  final int views;
}

// ==========================================================================
// MODERNIZED DASHBOARD SCREEN - NOW WITH LIVE ANALYTICS AND SYNCFUSION CHARTS
// ==========================================================================

class DashboardController extends BaseController {
  DashboardController({required this.channelId});
  final String channelId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final Rx<Channel?> currentChannel = Rx<Channel?>(null);
  final RxBool showApprovalBanner = false.obs;

  RxInt selectedIndex = 1.obs;
  RxBool isDrawerExpanded = true.obs;
  RxBool rxIsLoading = true.obs;
  RxString rxErrorMessage = ''.obs;

  RxMap<String, dynamic> channelStats = <String, dynamic>{}.obs;
  RxList<Video> recentVideos = <Video>[].obs;
  RxList<AnalyticsData> analyticsData = <AnalyticsData>[].obs;
  RxString searchQuery = ''.obs;

  RxInt copyrightClaimsCount = 0.obs;
  final RxInt totalWatchTimeSeconds = 0.obs;

  double get watchMinutes => totalWatchTimeSeconds.value / 60.0;
  double get watchHours => totalWatchTimeSeconds.value / 3600.0;

  String get formattedWatchTime =>
      WatchTimeFormatter.format(totalWatchTimeSeconds.value);
  String get formattedWatchTimeCompact =>
      WatchTimeFormatter.format(totalWatchTimeSeconds.value, compact: true);

  /// Returns watch hours for a specific video
  double getVideoWatchHours(Video video) {
    return video.totalWatchTimeSeconds / 3600.0;
  }

  /// Checks if a specific video has reached 10 hours watch time for cash withdrawal
  bool isVideoWithdrawalEligible(Video video) {
    return getVideoWatchHours(video) >= 10.0;
  }

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
      rxIsLoading.value = false;
      rxErrorMessage.value = 'No channel provided.';
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
    rxIsLoading.value = true;
    _loadChannelStats();
    _loadRecentVideos();
    _loadAnalyticsData();
    _loadCopyrightStatus();
    // Use Future.delayed to set loading to false after a short period,
    // allowing streams to populate data.
    Future.delayed(const Duration(seconds: 2), () {
      if (rxIsLoading.value) {
        rxIsLoading.value = false;
      }
    });
  }

  void _loadChannelStats() {
    // 1. Listen to the main channel document for real-time totals (subs, views, watchTime)
    final channelRef = _firestore
        .collection(FirestoreCollections.channels)
        .doc(channelId);
    trackSubscription(
      _channelSubscription = channelRef.snapshots().listen(
        (snapshot) {
          if (snapshot.exists) {
            final data = snapshot.data();
            if (data != null) {
              if (data.containsKey('totalWatchTimeSeconds')) {
                totalWatchTimeSeconds.value =
                    (data['totalWatchTimeSeconds'] as num).toInt();
              } else if (data.containsKey('totalWatchTimeMinutes')) {
                totalWatchTimeSeconds.value =
                    (((data['totalWatchTimeMinutes'] as num).toDouble()) * 60)
                        .toInt();
              }
            }

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

            channelStats.value = {
              ...channelStats,
              'views': _formatNumber(channel.viewCount),
              'subscribers': _formatNumber(channel.subscriberCount),
              'watchTime': formattedWatchTime,
              'revenue': channelStats['revenue'] ?? r'$0.00',
              'viewsChange': channelStats['viewsChange'] ?? '+0%',
              'watchTimeChange': channelStats['watchTimeChange'] ?? '+0%',
              'subscribersChange': channelStats['subscribersChange'] ?? '+0',
              'revenueChange': channelStats['revenueChange'] ?? r'+$0.00',
            };
          }
        },
      ),
    );

    // 2. Listen to the summary document for detailed analytics (watch time, trends)
    final summaryRef = _firestore
        .collection(FirestoreCollections.channels)
        .doc(channelId)
        .collection('stats')
        .doc('summary');
    trackSubscription(_statsSubscription = summaryRef.snapshots().listen(
      (snapshot) {
        if (snapshot.exists) {
          final data = snapshot.data()!;
          if (data.containsKey('totalWatchTimeSeconds')) {
            totalWatchTimeSeconds.value = (data['totalWatchTimeSeconds'] as num)
                .toInt();
          }
          channelStats.value = {
            ...channelStats,
            'views': _formatNumber(data['totalViews'] ?? 0),
            'watchTime': formattedWatchTime,
            'subscribers': _formatNumber(data['subscribers'] ?? 0),
            'revenue': r'$0.00',
            'viewsChange': '+0%',
            'watchTimeChange': '+0%',
            'subscribersChange': '+0',
            'revenueChange': r'+$0.00',
          };
        }
      },
      onError: (error) {
        rxErrorMessage.value = 'Failed to load channel stats.';
      },
    ));
  }

  void _loadRecentVideos() {
    final videosRef = _firestore
        .collection(FirestoreCollections.videos)
        .where('channelId', isEqualTo: channelId)
        .orderBy('uploadedAt', descending: true)
        .limit(10); // Fetch more for better fallback
    trackSubscription(_videosSubscription = videosRef.snapshots().listen(
      (snapshot) {
        recentVideos.value = snapshot.docs
            .map(Video.fromDocumentSnapshot)
            .toList();

        // Fallback view count from recent videos if still zero
        if ((channelStats['views'] == '0' || channelStats['views'] == null) &&
            recentVideos.isNotEmpty) {
          final totalViews = recentVideos.fold(
            0,
            (acc, v) => acc + v.viewCount,
          );
          if (totalViews > 0) {
            channelStats.value = {
              ...channelStats,
              'views': _formatNumber(totalViews),
            };
          }
        }
      },
      onError: (error) {
        rxErrorMessage.value = 'Failed to load recent videos.';
      },
    ));
  }

  void _loadAnalyticsData() {
    final endDate = DateTime.now();
    final startDate = endDate.subtract(
      const Duration(days: 27),
    ); // Last 28 days
    final statsRef = _firestore
        .collection(FirestoreCollections.channels)
        .doc(channelId)
        .collection('daily_stats')
        .where(
          FieldPath.documentId,
          isGreaterThanOrEqualTo: DateFormat('yyyy-MM-dd').format(startDate),
        )
        .orderBy(FieldPath.documentId);

    trackSubscription(_analyticsSubscription = statsRef.snapshots().listen(
      (snapshot) {
        if (snapshot.docs.isNotEmpty) {
          final data = <AnalyticsData>[];
          for (var i = 0; i < 28; i++) {
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
        rxErrorMessage.value = 'Failed to load analytics data.';
      },
    ));
  }

  void _loadCopyrightStatus() {
    if (channelId.isEmpty) return;
    _copyrightSubscription = _firestore
        .collection('copyright_claims')
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
  late DashboardController controller;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();

  Worker? _authWorker;
  Worker? _channelWorker;

  // Get channel from arguments, controller, or AuthService
  dynamic get channel {
    final args = Get.arguments;
    if (args is Map && args['channel'] != null) {
      final ch = args['channel'];
      if (ch is Channel) return ch;
      if (ch is Map<String, dynamic>) {
        return Channel.fromMap(ch, (ch['id'] ?? '').toString());
      }
      return ch;
    }
    if (Get.isRegistered<DashboardController>() &&
        controller.currentChannel.value != null) {
      return controller.currentChannel.value;
    }
    if (AuthService.to.userChannel != null) {
      return AuthService.to.userChannel;
    }
    return null;
  }

  String _getChannelId(dynamic ch) {
    if (ch == null) return '';
    if (ch is Channel) return ch.id;
    if (ch is Map) return (ch['id'] ?? '').toString();
    if (ch is DocumentSnapshot) return ch.id;
    return '';
  }

  String _getOwnerId(dynamic ch) {
    if (ch == null) return '';
    if (ch is Channel) return ch.ownerId;
    if (ch is Map) return (ch['ownerId'] ?? ch['userId'] ?? '').toString();
    if (ch is DocumentSnapshot) {
      final data = ch.data() as Map<String, dynamic>?;
      return (data?['ownerId'] ?? data?['userId'] ?? '').toString();
    }
    return '';
  }

  String _getChannelName(dynamic ch) {
    if (ch == null) return 'Unknown Channel';
    if (ch is Channel) return ch.name.isNotEmpty ? ch.name : 'Unknown Channel';
    if (ch is Map) {
      final val = ch['channelName'] ?? ch['name'];
      return (val != null && val.toString().isNotEmpty)
          ? val.toString()
          : 'Unknown Channel';
    }
    if (ch is DocumentSnapshot) {
      final data = ch.data() as Map<String, dynamic>?;
      final val = data?['channelName'] ?? data?['name'];
      return (val != null && val.toString().isNotEmpty)
          ? val.toString()
          : 'Unknown Channel';
    }
    return 'Unknown Channel';
  }

  final RxBool isSelectingDefault = false.obs;

  @override
  void initState() {
    super.initState();
    _initializeAnimations(); // Initialize early to avoid LateInitializationError in dispose
    final initChannelId = _getChannelId(channel);
    controller = Get.isRegistered<DashboardController>()
        ? Get.find<DashboardController>()
        : Get.put(DashboardController(channelId: initChannelId));
    unawaited(_resolveChannelAndInit());

    _authWorker = ever(AuthService.to.isAuthenticated, (isAuth) {
      if (isAuth && !isSelectingDefault.value && channel == null) {
        unawaited(_resolveChannelAndInit());
      }
    });

    _channelWorker = ever(AuthService.to.rxUserChannel, (ch) {
      if (ch != null) {
        if (Get.isRegistered<DashboardController>()) {
          controller.currentChannel.value = ch;
        }
        if (mounted) {
          setState(() {});
        }
      }
    });
  }

  Future<void> _resolveChannelAndInit() async {
    isSelectingDefault.value = true;
    try {
      final authService = AuthService.to;
      var user = FirebaseAuth.instance.currentUser;

      // Allow brief moment for auth token restoration on cold start / new tab
      if (user == null && !authService.isAuthenticated.value) {
        await Future.delayed(const Duration(milliseconds: 300));
        user = FirebaseAuth.instance.currentUser;
      }

      if (user == null && !authService.isAuthenticated.value) {
        isSelectingDefault.value = false;
        return;
      }

      dynamic resolvedChannel = channel;

      // 1. If channel not in args, check AuthService.to.userChannel
      if (resolvedChannel == null && authService.userChannel != null) {
        resolvedChannel = authService.userChannel;
      }

      // 2. Direct Firestore fallback query if stream hasn't emitted yet
      if (resolvedChannel == null && user != null) {
        try {
          var snapshot = await FirebaseFirestore.instance
              .collection(FirestoreCollections.channels)
              .where('ownerId', isEqualTo: user.uid)
              .get();

          if (snapshot.docs.isEmpty) {
            snapshot = await FirebaseFirestore.instance
                .collection(FirestoreCollections.channels)
                .where('userId', isEqualTo: user.uid)
                .get();
          }

          if (snapshot.docs.isNotEmpty) {
            final activeDocs = snapshot.docs
                .map(Channel.fromDocumentSnapshot)
                .where((c) => c.status != ChannelStatus.deleted)
                .toList();
            if (activeDocs.isNotEmpty) {
              resolvedChannel = activeDocs.first;
              authService.hasChannel.value = true;
            }
          }

          // Check user document for channelId reference
          if (resolvedChannel == null) {
            final userDoc = await FirebaseFirestore.instance
                .collection(FirestoreCollections.users)
                .doc(user.uid)
                .get();
            final chId = userDoc.data()?['channelId'] as String?;
            if (chId != null && chId.isNotEmpty) {
              final chDoc = await FirebaseFirestore.instance
                  .collection(FirestoreCollections.channels)
                  .doc(chId)
                  .get();
              if (chDoc.exists && chDoc.data() != null) {
                final ch = Channel.fromDocumentSnapshot(chDoc);
                if (ch.status != ChannelStatus.deleted) {
                  resolvedChannel = ch;
                  authService.hasChannel.value = true;
                }
              }
            }
          }
        } on Object catch (e) {
          debugPrint('Error fetching channel for studio: $e');
        }
      }

      // 3. Only redirect to channel creation if confirmed authenticated with 0 channels
      if (resolvedChannel == null &&
          !authService.hasChannel.value &&
          authService.isAuthenticated.value) {
        isSelectingDefault.value = false;
        await Get.offAllNamed<dynamic>('/channelscreen');
        return;
      }

      // 4. Initialize DashboardController with resolved channelId
      DashboardBinding().dependencies();
      final channelId = _getChannelId(resolvedChannel);
      if (!Get.isRegistered<DashboardController>()) {
        controller = Get.put(DashboardController(channelId: channelId));
      } else {
        controller = Get.find<DashboardController>();
        if (controller.channelId != channelId && channelId.isNotEmpty) {
          unawaited(Get.delete<DashboardController>());
          controller = Get.put(DashboardController(channelId: channelId));
        }
      }

      if (controller.currentChannel.value == null) {
        if (resolvedChannel is Channel) {
          controller.currentChannel.value = resolvedChannel;
        } else if (resolvedChannel is Map) {
          controller.currentChannel.value = Channel.fromMap(
            Map<String, dynamic>.from(resolvedChannel),
            (resolvedChannel['id'] ?? channelId).toString(),
          );
        }
      }

      final args = Get.arguments;
      final tabIndex = args is Map ? args['tab'] as int? : null;
      if (tabIndex != null) {
        controller.selectedIndex.value = tabIndex;
      }

      if (!Get.isRegistered<VideoManagementController>()) {
        Get.put(VideoManagementController());
      }
    } on Object catch (e) {
      debugPrint('Error in _resolveChannelAndInit: $e');
      if (!Get.isRegistered<DashboardController>()) {
        controller = Get.put(DashboardController(channelId: ''));
      } else {
        controller = Get.find<DashboardController>();
      }
      if (!Get.isRegistered<VideoManagementController>()) {
        Get.put(VideoManagementController());
      }
    } finally {
      isSelectingDefault.value = false;
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
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _drawerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _statsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _chartAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _staggeredAnimationController,
        curve: const Interval(0, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _staggeredAnimationController,
            curve: const Interval(0.2, 0.8, curve: Curves.easeOutBack),
          ),
        );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(
        parent: _staggeredAnimationController,
        curve: const Interval(0.4, 1, curve: Curves.elasticOut),
      ),
    );

    _drawerAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _drawerAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _statsAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _statsAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _chartAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _chartAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  void _startAnimations() {
    _staggeredAnimationController.forward();
    _drawerAnimationController.forward();

    Future.delayed(const Duration(milliseconds: 500), () {
      _statsAnimationController.forward();
    });

    Future.delayed(const Duration(milliseconds: 800), () {
      _chartAnimationController.forward();
    });
  }

  @override
  void dispose() {
    _authWorker?.dispose();
    _channelWorker?.dispose();
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
    if (isDesktop) return 32;
    if (isTablet) return 24;
    return 16;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!AuthService.to.isAuthenticated.value) {
        return _buildFallbackLoginScreen();
      }

      if (isSelectingDefault.value) {
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
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
      backgroundColor: isDarkMode ? AppColors.bgInput : AppColors.textPrimary,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      toolbarHeight: 64,
      centerTitle: false,
      titleSpacing: isMobile ? 4 : null,
      leading: isDesktop
          ? null
          : IconButton(
              icon: Icon(
                Icons.menu_rounded,
                color: isDarkMode
                    ? AppColors.textPrimary
                    : Colors.black,
              ),
              onPressed: () => scaffoldKey.currentState?.openDrawer(),
              tooltip: 'Menu',
            ),
      title: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back,
              size: 20,
              color: isDarkMode
                  ? AppColors.textSecondary
                  : Colors.black,
            ),
            onPressed: () => Get.offAllNamed('/home'),
            tooltip: 'Back to Home',
          ),
          if (!isMobile) ...[
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
                color: AppColors.textPrimary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              isMobile ? 'Studio' : 'Creator Studio',
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(
                fontSize: isMobile ? 18 : 20,
                fontWeight: FontWeight.w700,
                color: isDarkMode
                    ? AppColors.textPrimary
                    : Colors.black,
                letterSpacing: -0.5,
              ),
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
          onPressed: () => controller.setSelectedIndex(16),
          isDarkMode: isDarkMode,
          tooltip: 'Creator Intelligence',
        ),

        SizedBox(width: isMobile ? 4 : 8),

        // Upload Video Button
        _buildActionButton(
          icon: Icons.video_call_rounded,
          label: isDesktop ? 'Upload' : '',
          onPressed: () => Get.toNamed('/upload'),
          isDarkMode: isDarkMode,
          isPrimary: true,
          tooltip: 'Upload Video',
        ),

        SizedBox(width: isMobile ? 4 : 8),

        // Google Account Selector
        _buildGoogleAccountSelector(isDarkMode),

        SizedBox(width: isMobile ? 8 : 16),
      ],
    );
  }

  // Search Field Widget
  Widget _buildSearchField(bool isDarkMode) {
    return Container(
      width: 300,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.bgSurfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppTokens.radius.lg),
        border: Border.all(
          color: AppColors.bgSurfaceContainerHighest,
        ),
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(
          color: isDarkMode ? AppColors.textPrimary : Colors.black,
          fontSize: 14,
        ),
        onChanged: (value) {
          controller.setSearchQuery(value);
        },
        decoration: InputDecoration(
          hintText: 'Search your content...',
          hintStyle: TextStyle(
            color: isDarkMode
                ? AppColors.textSecondary
                : Colors.black,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: isDarkMode
                ? AppColors.textSecondary
                : Colors.black,
            size: 20,
          ),
          suffixIcon: Obx(
            () => controller.searchQuery.value.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.clear_rounded,
                      color: isDarkMode
                          ? AppColors.textSecondary
                          : Colors.black,
                      size: 18,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      controller.setSearchQuery('');
                    },
                  )
                : const SizedBox.shrink(),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
        ),
      ),
    );
  }

  // Action Button Widget
  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onPressed,
    required bool isDarkMode,
    String label = '',
    bool isPrimary = false,
    String? tooltip,
  }) {
    final bgColor = isPrimary
        ? const Color(0xFF6366F1)
        : (isDarkMode ? AppTheme.colors.surface : const Color(0xFFF1F5F9));
    final textColor = isPrimary
        ? AppColors.textPrimary
        : (isDarkMode ? AppColors.textPrimary : Colors.black);

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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: textColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
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

  // Google Account Selector Widget
  Widget _buildGoogleAccountSelector(bool isDarkMode) {
    // Get current user from Firebase Auth
    final user = FirebaseAuth.instance.currentUser;

    // If user is not signed in, show sign-in button
    if (user == null) {
      return Tooltip(
        message: 'Sign in with Google',
        child: Material(
          color: AppColors.textPrimary,
          borderRadius: BorderRadius.circular(20),
          elevation: 2,
          shadowColor: AppColors.bgPage.withValues(alpha: 0.1),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              HapticFeedback.lightImpact();
              _handleGoogleSignIn();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/google_logo.png',
                    width: 18,
                    height: 18,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.account_circle,
                      color: AppColors.textPrimary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Sign in',
                    style: TextStyle(
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

    // If user is signed in, show profile avatar display in Appbar
    return Tooltip(
      message: AuthService.to.activeDisplayName.isNotEmpty
          ? '${AuthService.to.activeDisplayName} (${user.email ?? ''})'
          : (user.email ?? 'Account'),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDarkMode ? AppTheme.colors.surface : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: isDarkMode ? const Color(0xFF374151) : AppColors.bgDivider,
            width: 2,
          ),
        ),
        child: UserAvatar(
          radius: 16,
          photoUrl: AuthService.to.activePhotoUrl,
          displayName: AuthService.to.activeDisplayName.isNotEmpty
              ? AuthService.to.activeDisplayName
              : (user.email ?? 'U'),
          showBorder: false,
        ),
      ),
    );
  }

  // Handle Google Sign In
  Future<void> _handleGoogleSignIn() async {
    try {
      await AuthService.to.signInWithGoogle();
      if (!mounted) return;
      await AuthService.to.checkAndPromptOnboarding(context);

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        Get.snackbar(
          'Success',
          'Signed in as ${user.email}',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFF10B981),
          colorText: AppColors.textPrimary,
          margin: const EdgeInsets.all(16),
          borderRadius: 8,
        );
        await _resolveChannelAndInit();
      } else {
        isSelectingDefault.value = false;
      }
    } catch (e) {
      isSelectingDefault.value = false;
      if (e is GoogleSignInUserCancelledException ||
          (e is AuthException && e.code == 'user-cancelled')) {
        return;
      }
      var message = 'Failed to sign in';
      if (e is GoogleSignInException) {
        message = e.getDisplayMessage();
      }

      Get.snackbar(
        'Sign-In Error',
        message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFEF4444),
        colorText: AppColors.textPrimary,
        margin: const EdgeInsets.all(16),
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
        colorText: AppColors.textPrimary,
        margin: const EdgeInsets.all(16),
        borderRadius: 8,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to sign out: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFEF4444),
        colorText: AppColors.textPrimary,
        margin: const EdgeInsets.all(16),
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
            color: isDarkMode ? AppColors.bgInput : AppColors.textPrimary,
            border: Border(
              right: BorderSide(
                color: isDarkMode
                    ? const Color(0xFF374151)
                    : AppColors.bgDivider,
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
        padding: const EdgeInsets.all(16),
        child: controller.isDrawerExpanded.value
            ? Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.chevron_left_rounded,
                      color: isDarkMode
                          ? AppColors.textSecondary
                          : Colors.black,
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
                    color: isDarkMode
                        ? AppColors.textSecondary
                        : Colors.black,
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
        'color': const Color(0xFF6366F1),
        'action': 'select',
        'target': 1,
      },
      {
        'icon': Icons.video_library_rounded,
        'label': 'Content',
        'color': const Color(0xFF10B981),
        'action': 'select',
        'target': 2,
      },
      {
        'icon': Icons.upload_rounded,
        'label': 'Upload',
        'color': const Color(0xFFF59E0B),
        'action': 'route',
        'route': '/upload',
      },

      // Analytics & Engagement
      {
        'icon': Icons.insights_rounded,
        'label': 'Analytics',
        'color': const Color(0xFF3B82F6),
        'action': 'select',
        'target': 3,
      },
      {
        'icon': Icons.category_rounded,
        'label': 'Category Insights',
        'color': const Color(0xFF6366F1),
        'action': 'select',
        'target': 19,
      },
      {
        'icon': Icons.forum_rounded,
        'label': 'Comments',
        'color': const Color(0xFF8B5CF6),
        'action': 'select',
        'target': 4,
      },
      {
        'icon': Icons.people_rounded,
        'label': 'Audience',
        'color': const Color(0xFF14B8A6),
        'action': 'select',
        'target': 12,
      },

      // Monetization & Growth
      {
        'icon': Icons.attach_money_rounded,
        'label': 'Earnings',
        'color': const Color(0xFF059669),
        'action': 'select',
        'target': 5,
      },
      {
        'icon': Icons.stars_rounded,
        'label': 'Memberships',
        'color': const Color(0xFFF59E0B),
        'action': 'select',
        'target': 18,
      },
      {
        'icon': Icons.copyright_rounded,
        'label': 'Copyright & Matches',
        'color': const Color(0xFFDC2626),
        'action': 'select',
        'target': 9,
      },

      // Creative Tools
      {
        'icon': Icons.playlist_play_rounded,
        'label': 'Playlists',
        'color': const Color(0xFF3B82F6),
        'action': 'select',
        'target': 17,
      },
      {
        'icon': Icons.spatial_audio_rounded,
        'label': 'Audio Tracks & Dubs',
        'color': const Color(0xFF10B981),
        'action': 'select',
        'target': 7,
      },
      {
        'icon': Icons.color_lens_rounded,
        'label': 'Customization',
        'color': const Color(0xFFEC4899),
        'action': 'select',
        'target': 6,
      },
      {
        'icon': Icons.edit_note_rounded,
        'label': 'Subtitles',
        'color': const Color(0xFF7C3AED),
        'action': 'select',
        'target': 10,
      },
      {
        'icon': Icons.topic_rounded,
        'label': 'Topics',
        'color': const Color(0xFFE11D48),
        'action': 'select',
        'target': 14,
      },
      {
        'icon': Icons.verified_user_rounded,
        'label': 'Fact Verification',
        'color': const Color(0xFF10B981),
        'action': 'select',
        'target': 15,
      },
      {
        'icon': Icons.drafts_rounded,
        'label': 'Drafts',
        'color': const Color(0xFF6366F1),
        'action': 'select',
        'target': 20,
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: menuItems.length + 3, // +3 for divider, settings, and sign out
      itemBuilder: (context, index) {
        // Divider before settings
        if (index == menuItems.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(
              color: isDarkMode
                  ? const Color(0xFF374151)
                  : const Color(0xFFE5E7EB),
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
            color: const Color(0xFF6B7280),
            isSelected: controller.selectedIndex.value == 8,
            onTap: () => controller.setSelectedIndex(8),
            isDarkMode: isDarkMode,
          );
        }

        // Sign Out at the bottom
        if (index == menuItems.length + 2) {
          return _buildSidebarItem(
            icon: Icons.logout_rounded,
            label: 'Sign Out',
            color: const Color(0xFFEF4444),
            isSelected: false,
            onTap: () {
              HapticFeedback.lightImpact();
              _handleSignOut();
            },
            isDarkMode: isDarkMode,
          );
        }

        // Regular menu items: perform action based on item['action']
        final item = menuItems[index];
        final action = item['action'] as String? ?? 'select';
        final icon = item['icon']! as IconData;
        final label = item['label']! as String;
        final color = item['color']! as Color;

        VoidCallback onTapCallback;
        var isSelected = false;

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
        margin: const EdgeInsets.symmetric(vertical: 2),
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
                    ? Border.all(color: color.withValues(alpha: 0.3))
                    : null,
              ),
              child: controller.isDrawerExpanded.value
                  ? Row(
                      children: [
                        Icon(
                          icon,
                          color: AppColors.textPrimary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            label,
                            style: TextStyle(
                              color: isSelected
                                  ? color
                                  : (isDarkMode
                                        ? AppColors.textPrimary
                                        : Colors.black),
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
                        color: AppColors.textPrimary,
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
      backgroundColor: isDarkMode ? AppColors.bgInput : AppColors.textPrimary,
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
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
                    color: AppColors.textPrimary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.dashboard_rounded,
                    color: AppColors.textPrimary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'Creator Studio',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
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
    final currentChannel = channel;
    final channelId = _getChannelId(currentChannel);
    if (channelId.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Get.offAllNamed<dynamic>('/channelscreen');
        }
      });
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
        ),
      );
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
                return ContentScreen(
                  channelId: channelId,
                  isDarkMode: isDarkMode,
                  searchQuery: controller.searchQuery.value,
                );
              case 3:
                return AnalyticsScreen(
                  isDarkMode: isDarkMode,
                  channelId: channelId,
                );
              case 4:
                return const DashboardCommentsPage();
              case 5:
                return MonetizationScreen(isDarkMode: isDarkMode);
              case 6:
                final ownerId = _getOwnerId(currentChannel);
                return ChannelCustomizationPage(
                  channelId: channelId,
                  ownerId: ownerId,
                );
              case 7:
                return AudioTracksPage(
                  channelId: channelId,
                  isDarkMode: isDarkMode,
                );
              case 8:
                return const StudioSettingsPage();
              case 9:
                return CopyrightScreen(channelId: channelId);
              case 10:
                return SubtitlesPage(
                  channelId: channelId,
                  isDarkMode: isDarkMode,
                );
              case 12:
                return AudiencePage(
                  channelId: channelId,
                  isDarkMode: isDarkMode,
                );
              case 14:
                return TopicManagementScreen(
                  channelId: channelId,
                  isDarkMode: isDarkMode,
                  searchQuery: controller.searchQuery.value,
                );
              case 15:
                return TruthVerificationDashboardPage(
                  channelId: channelId,
                  isDarkMode: isDarkMode,
                );
              case 16:
                final ownerId = _getOwnerId(currentChannel);
                return CreatorIntelligencePage(
                  channelId: channelId,
                  creatorId: ownerId,
                );
              case 17:
                return PlaylistsManagementScreen(
                  channelId: channelId,
                  isDarkMode: isDarkMode,
                );
              case 18:
                return MembershipsScreen(
                  channelId: channelId,
                  isDarkMode: isDarkMode,
                );
              case 19:
                return CategoryInsightsScreen(
                  channelId: channelId,
                  isDarkMode: isDarkMode,
                );
              case 20:
                return DraftsScreen(
                  channelId: channelId,
                  isDarkMode: isDarkMode,
                );
              default:
                return _buildDashboardContent(isDarkMode);
            }
          }),
        ),
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
            if (ch.status == ChannelStatus.active || ch.geminiApproved == true) {
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
                  const SizedBox(height: 24),
                  _buildChannelViolationsCard(isDarkMode),
                ],
              );
            }
            return const SizedBox.shrink();
          }),
          const SizedBox(height: 32),
          _buildRecentPerformanceSection(isDarkMode),
          const SizedBox(height: 32),
          _buildRecommendationsSection(isDarkMode),
          const SizedBox(height: 32),
          _buildLatestContentSection(isDarkMode),
          const SizedBox(height: 32),
          _buildQuickActionsSection(isDarkMode),
        ],
      ),
    );
  }

  Widget _buildImageVerificationBanner(bool isDarkMode, Channel channel) {
    final banners = <Widget>[];

    // Avatar status
    if (channel.avatarStatus == 'PENDING') {
      banners.add(
        _buildVerificationAlertCard(
          isDarkMode: isDarkMode,
          title: 'Avatar Verification Pending',
          subtitle:
              'Google Vision AI is currently validating your channel avatar image. Creation is complete and your channel is fully accessible.',
          color: const Color(0xFF3B82F6),
          icon: Icons.sync_rounded,
          isPending: true,
          onBypassPressed: () async {
            try {
              await FirebaseFirestore.instance
                  .collection(FirestoreCollections.channels)
                  .doc(channel.id)
                  .update({
                    'avatarStatus': 'APPROVED',
                    'avatarStatusReason':
                        'Bypassed in local/debug environment.',
                    'updatedAt': DateTime.now().millisecondsSinceEpoch,
                  });
              if (channel.avatarFileId != null &&
                  channel.avatarFileId!.isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('image_verification')
                    .doc(channel.avatarFileId)
                    .set({
                      'status': 'APPROVED',
                      'reason': 'Bypassed in local/debug environment.',
                      'category': 'avatar',
                      'processedAt': FieldValue.serverTimestamp(),
                    }, SetOptions(merge: true));
              }
              Get.snackbar(
                'Bypassed',
                'Avatar approved successfully.',
                backgroundColor: AppColors.success,
                colorText: AppColors.textPrimary,
              );
            } catch (e) {
              Get.snackbar(
                'Error',
                e.toString(),
                backgroundColor: AppColors.error,
                colorText: AppColors.textPrimary,
              );
            }
          },
        ),
      );
    } else if (channel.avatarStatus == 'REJECTED') {
      banners.add(
        _buildVerificationAlertCard(
          isDarkMode: isDarkMode,
          title: 'Avatar Image Rejected',
          subtitle:
              'Your uploaded avatar image did not pass automated content verification guidelines. Change image or request a manual admin review if you believe it complies with guidelines.',
          color: const Color(0xFFEF4444),
          icon: Icons.error_outline_rounded,
          showCustomizationButton: true,
          onRequestManualReviewPressed: () async {
            try {
              await FirebaseFirestore.instance
                  .collection(FirestoreCollections.channels)
                  .doc(channel.id)
                  .update({
                    'avatarStatus': 'MANUAL_REVIEW',
                    'avatarStatusReason': 'User requested manual review.',
                    'updatedAt': DateTime.now().millisecondsSinceEpoch,
                  });
              Get.snackbar(
                'Submitted',
                'Avatar queued for manual admin review.',
                backgroundColor: AppColors.success,
                colorText: AppColors.textPrimary,
              );
            } catch (e) {
              Get.snackbar('Error', e.toString(), backgroundColor: AppColors.error, colorText: AppColors.textPrimary);
            }
          },
        ),
      );
    } else if (channel.avatarStatus == 'FLAGGED') {
      banners.add(
        _buildVerificationAlertCard(
          isDarkMode: isDarkMode,
          title: 'Avatar Review Needed',
          subtitle:
              'Your avatar image was flagged for potential guidelines review. You may upload a new image or request manual admin review.',
          color: const Color(0xFFF59E0B),
          icon: Icons.warning_amber_rounded,
          showCustomizationButton: true,
          onRequestManualReviewPressed: () async {
            try {
              await FirebaseFirestore.instance
                  .collection(FirestoreCollections.channels)
                  .doc(channel.id)
                  .update({
                    'avatarStatus': 'MANUAL_REVIEW',
                    'avatarStatusReason': 'User requested manual review.',
                    'updatedAt': DateTime.now().millisecondsSinceEpoch,
                  });
              Get.snackbar(
                'Submitted',
                'Avatar queued for manual admin review.',
                backgroundColor: AppColors.success,
                colorText: AppColors.textPrimary,
              );
            } catch (e) {
              Get.snackbar('Error', e.toString(), backgroundColor: AppColors.error, colorText: AppColors.textPrimary);
            }
          },
        ),
      );
    } else if (channel.avatarStatus == 'MANUAL_REVIEW') {
      banners.add(
        _buildVerificationAlertCard(
          isDarkMode: isDarkMode,
          title: 'Avatar Under Manual Review',
          subtitle:
              'Your avatar appeal has been received. Our moderation team is reviewing your image.',
          color: const Color(0xFF8B5CF6),
          icon: Icons.rate_review_rounded,
        ),
      );
    }

    // Banner status
    if (channel.bannerStatus == 'PENDING') {
      banners.add(
        _buildVerificationAlertCard(
          isDarkMode: isDarkMode,
          title: 'Banner Verification Pending',
          subtitle:
              'Google Vision AI is currently validating your channel banner image. Creation is complete and your channel is fully accessible.',
          color: const Color(0xFF3B82F6),
          icon: Icons.sync_rounded,
          isPending: true,
          onBypassPressed: () async {
            try {
              await FirebaseFirestore.instance
                  .collection(FirestoreCollections.channels)
                  .doc(channel.id)
                  .update({
                    'bannerStatus': 'APPROVED',
                    'bannerStatusReason':
                        'Bypassed in local/debug environment.',
                    'updatedAt': DateTime.now().millisecondsSinceEpoch,
                  });
              if (channel.bannerFileId != null &&
                  channel.bannerFileId!.isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('image_verification')
                    .doc(channel.bannerFileId)
                    .set({
                      'status': 'APPROVED',
                      'reason': 'Bypassed in local/debug environment.',
                      'category': 'banner',
                      'processedAt': FieldValue.serverTimestamp(),
                    }, SetOptions(merge: true));
              }
              Get.snackbar(
                'Bypassed',
                'Banner approved successfully.',
                backgroundColor: AppColors.success,
                colorText: AppColors.textPrimary,
              );
            } catch (e) {
              Get.snackbar(
                'Error',
                e.toString(),
                backgroundColor: AppColors.error,
                colorText: AppColors.textPrimary,
              );
            }
          },
        ),
      );
    } else if (channel.bannerStatus == 'REJECTED') {
      banners.add(
        _buildVerificationAlertCard(
          isDarkMode: isDarkMode,
          title: 'Banner Image Rejected',
          subtitle:
              'Your uploaded banner image did not pass automated content verification guidelines. Change image or request a manual admin review if you believe it complies with guidelines.',
          color: const Color(0xFFEF4444),
          icon: Icons.error_outline_rounded,
          showCustomizationButton: true,
          onRequestManualReviewPressed: () async {
            try {
              await FirebaseFirestore.instance
                  .collection(FirestoreCollections.channels)
                  .doc(channel.id)
                  .update({
                    'bannerStatus': 'MANUAL_REVIEW',
                    'bannerStatusReason': 'User requested manual review.',
                    'updatedAt': DateTime.now().millisecondsSinceEpoch,
                  });
              Get.snackbar(
                'Submitted',
                'Banner queued for manual admin review.',
                backgroundColor: AppColors.success,
                colorText: AppColors.textPrimary,
              );
            } catch (e) {
              Get.snackbar('Error', e.toString(), backgroundColor: AppColors.error, colorText: AppColors.textPrimary);
            }
          },
        ),
      );
    } else if (channel.bannerStatus == 'FLAGGED') {
      banners.add(
        _buildVerificationAlertCard(
          isDarkMode: isDarkMode,
          title: 'Banner Review Needed',
          subtitle:
              'Your banner image was flagged for potential guidelines review. You may upload a new image or request manual admin review.',
          color: const Color(0xFFF59E0B),
          icon: Icons.warning_amber_rounded,
          showCustomizationButton: true,
          onRequestManualReviewPressed: () async {
            try {
              await FirebaseFirestore.instance
                  .collection(FirestoreCollections.channels)
                  .doc(channel.id)
                  .update({
                    'bannerStatus': 'MANUAL_REVIEW',
                    'bannerStatusReason': 'User requested manual review.',
                    'updatedAt': DateTime.now().millisecondsSinceEpoch,
                  });
              Get.snackbar(
                'Submitted',
                'Banner queued for manual admin review.',
                backgroundColor: AppColors.success,
                colorText: AppColors.textPrimary,
              );
            } catch (e) {
              Get.snackbar('Error', e.toString(), backgroundColor: AppColors.error, colorText: AppColors.textPrimary);
            }
          },
        ),
      );
    } else if (channel.bannerStatus == 'MANUAL_REVIEW') {
      banners.add(
        _buildVerificationAlertCard(
          isDarkMode: isDarkMode,
          title: 'Banner Under Manual Review',
          subtitle:
              'Your banner appeal has been received. Our moderation team is reviewing your image.',
          color: const Color(0xFF8B5CF6),
          icon: Icons.rate_review_rounded,
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
    VoidCallback? onRequestManualReviewPressed,
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
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isDarkMode
                        ? AppColors.textSecondary
                        : Colors.black,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                if (showCustomizationButton || onRequestManualReviewPressed != null) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (showCustomizationButton)
                        ElevatedButton.icon(
                          onPressed: () {
                            controller.selectedIndex.value =
                                6; // Channel Customization tab
                          },
                          icon: const Icon(
                            Icons.color_lens_outlined,
                            size: 16,
                            color: Colors.white,
                          ),
                          label: const Text('Change Image'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: color,
                            foregroundColor: AppColors.textPrimary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                        ),
                      if (onRequestManualReviewPressed != null)
                        OutlinedButton.icon(
                          onPressed: onRequestManualReviewPressed,
                          icon: const Icon(
                            Icons.rate_review_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                          label: const Text('Request Manual Review'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDarkMode
                                ? AppColors.textPrimary
                                : const Color(0xFF2D3748),
                            side: BorderSide(
                              color: color,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                if (isPending && onBypassPressed != null) ...[
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: onBypassPressed,
                    icon: const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: const Text('Bypass Verification (Local Dev/Test)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: AppColors.textPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.colors.surface : AppColors.textPrimary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.error.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.error,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Channel violations',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode
                      ? AppColors.textPrimary
                      : Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Copyright claims',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? AppColors.textPrimary : Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your channel has ${controller.copyrightClaimsCount.value} active copyright claims. This may affect your visibility or monetization.',
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode
                  ? AppColors.textSecondary
                  : Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () {
              controller.selectedIndex.value =
                  9; // Navigate to Copyright Screen
            },
            child: const Text(
              'VIEW DETAILS',
              style: TextStyle(
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
                    style: TextStyle(
                      fontSize: isMobile ? 24 : 32,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode
                          ? AppColors.textPrimary
                          : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Last 28 days',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode
                          ? AppColors.textSecondary
                          : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
            if (channel != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      color: AppColors.textPrimary,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _getChannelName(channel),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
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
          const SizedBox(height: 16),
          _buildMobileSearchField(isDarkMode),
        ],
      ],
    );
  }

  Widget _buildModerationStatusBanner(bool isDarkMode, Channel channel) {
    if (channel.status == ChannelStatus.active || channel.geminiApproved == true) {
      return const SizedBox.shrink();
    }

    Color bannerColor;
    IconData icon;
    String title;
    String subtitle;
    var showButton = false;

    if (channel.status == ChannelStatus.underReview) {
      bannerColor = const Color(0xFF3B82F6); // Blue
      icon = Icons.sync_rounded;
      title = 'Branding Under Verification System Review';
      subtitle =
          'Our Verification System is checking your channel details (name, description, tags) against our community guidelines. This usually takes just a few seconds.';
    } else if (channel.status == ChannelStatus.verificationRejected) {
      bannerColor = const Color(0xFFEF4444); // Red
      icon = Icons.error_outline_rounded;
      title = 'Branding Verification Rejected';
      subtitle =
          'We created channel according to community guidelines, then channel selected for manual verification. ${channel.moderationReason != null && channel.moderationReason!.isNotEmpty ? '\n\nVerification System Response: ${channel.moderationReason}' : ''}';
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
                  style: TextStyle(
                    color: bannerColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isDarkMode
                        ? AppColors.textSecondary
                        : Colors.black,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                if (showButton) ...[
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      Get.toNamed(
                        '/community-guidelines',
                        arguments: {
                          'fromRejectedChannelId': channel.id,
                          'ownerId': channel.ownerId,
                        },
                      );
                    },
                    icon: const Icon(Icons.description_outlined, size: 16),
                    label: const Text('Review Community Guidelines'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: bannerColor,
                      foregroundColor: AppColors.textPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
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
    const bannerColor = Color(0xFF10B981); // Emerald green
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
          const Icon(
            Icons.check_circle_outline_rounded,
            color: bannerColor,
            size: 28,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Branding Approved by Verification System!',
                  style: TextStyle(
                    color: bannerColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Congratulations! Your channel details are approved. You can now customize your channel and upload videos.',
                  style: TextStyle(
                    color: isDarkMode
                        ? AppColors.textSecondary
                        : Colors.black,
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
            color: isDarkMode ? AppColors.textSecondary : Colors.black,
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
        color: AppColors.bgSurfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppTokens.radius.lg),
        border: Border.all(
          color: AppColors.bgSurfaceContainerHighest,
        ),
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(
          color: isDarkMode ? AppColors.textPrimary : Colors.black,
          fontSize: 14,
        ),
        onChanged: (value) {
          controller.setSearchQuery(value);
        },
        decoration: InputDecoration(
          hintText: 'Search your content...',
          hintStyle: TextStyle(
            color: isDarkMode
                ? AppColors.textSecondary
                : Colors.black,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: isDarkMode
                ? AppColors.textSecondary
                : Colors.black,
            size: 20,
          ),
          suffixIcon: Obx(
            () => controller.searchQuery.value.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.clear_rounded,
                      color: isDarkMode
                          ? AppColors.textSecondary
                          : Colors.black,
                      size: 18,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      controller.setSearchQuery('');
                    },
                  )
                : const SizedBox.shrink(),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
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
              if (controller.rxIsLoading.value &&
                  controller.channelStats.isEmpty) {
                return _buildStatsLoadingGrid(isDarkMode);
              }

              if (isMobile) {
                return Column(
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
                          final channelId = _getChannelId(channelData);
                          final channelName = _getChannelName(channelData);

                          Get.to(
                            () => const ViewsPage(),
                            arguments: {
                              'channelId': channelId,
                              'channelName': channelName,
                              'viewsChange':
                                  controller.channelStats['viewsChange'] ??
                                  '+0%',
                            },
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 16),
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
                          final channelId = _getChannelId(channelData);
                          final channelName = _getChannelName(channelData);

                          Get.to(
                            () => const WatchTimePage(),
                            arguments: {
                              'channelId': channelId,
                              'channelName': channelName,
                              'watchTimeChange':
                                  controller.channelStats['watchTimeChange'] ??
                                  '+0%',
                            },
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 16),
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
                          final channelId = _getChannelId(channelData);
                          final channelName = _getChannelName(channelData);

                          Get.to(
                            () => const SubscribersPage(),
                            arguments: {
                              'channelId': channelId,
                              'channelName': channelName,
                              'subscribersChange':
                                  controller
                                      .channelStats['subscribersChange'] ??
                                  '+0',
                            },
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildStatCard(
                      'Revenue',
                      controller.channelStats['revenue'] ?? r'$0.00',
                      controller.channelStats['revenueChange'] ?? r'+$0.00',
                      Icons.attach_money_rounded,
                      const Color(0xFFF59E0B),
                      isDarkMode,
                    ),
                  ],
                );
              }

              return GridView.count(
                crossAxisCount: isDesktop ? 4 : (isTablet ? 2 : 1),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
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
                        final channelId = _getChannelId(channelData);
                        final channelName = _getChannelName(channelData);

                        Get.to(
                          () => const ViewsPage(),
                          arguments: {
                            'channelId': channelId,
                            'channelName': channelName,
                            'viewsChange':
                                controller.channelStats['viewsChange'] ?? '+0%',
                          },
                        );
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
                        final channelId = _getChannelId(channelData);
                        final channelName = _getChannelName(channelData);

                        Get.to(
                          () => const WatchTimePage(),
                          arguments: {
                            'channelId': channelId,
                            'channelName': channelName,
                            'watchTimeChange':
                                controller.channelStats['watchTimeChange'] ??
                                '+0%',
                          },
                        );
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
                        final channelId = _getChannelId(channelData);
                        final channelName = _getChannelName(channelData);

                        Get.to(
                          () => const SubscribersPage(),
                          arguments: {
                            'channelId': channelId,
                            'channelName': channelName,
                            'subscribersChange':
                                controller.channelStats['subscribersChange'] ??
                                '+0',
                          },
                        );
                      }
                    },
                  ),
                  _buildStatCard(
                    'Revenue',
                    controller.channelStats['revenue'] ?? r'$0.00',
                    controller.channelStats['revenueChange'] ?? r'+$0.00',
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
    if (isMobile) {
      return Column(
        children: List.generate(
          4,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildStatCardSkeleton(isDarkMode),
          ),
        ),
      );
    }
    return GridView.count(
      crossAxisCount: isDesktop ? 4 : (isTablet ? 2 : 1),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: isDesktop ? 1.2 : (isTablet ? 1.5 : 2.5),
      children: List.generate(4, (index) => _buildStatCardSkeleton(isDarkMode)),
    );
  }

  Widget _buildStatCardSkeleton(bool isDarkMode) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.colors.surface : AppColors.textPrimary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? const Color(0xFF374151) : AppColors.bgDivider,
        ),
      ),
      child: Shimmer.fromColors(
        baseColor: isDarkMode ? const Color(0xFF374151) : AppColors.bgDivider,
        highlightColor: isDarkMode
            ? const Color(0xFF4B5563)
            : const Color(0xFFF1F5F9),
        child: Padding(
          padding: const EdgeInsets.all(20),
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
                      color: AppColors.textPrimary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.textPrimary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: 80,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.textPrimary,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: 50,
                height: 16,
                decoration: BoxDecoration(
                  color: AppColors.textPrimary,
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
      duration: const Duration(milliseconds: 600),
      tween: Tween(begin: 0, end: 1),
      builder: (context, animationValue, child) {
        return Transform.scale(
          scale: 0.8 + (0.2 * animationValue),
          child: Container(
            decoration: BoxDecoration(
              color: isDarkMode
                  ? AppTheme.colors.surface
                  : AppColors.textPrimary,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDarkMode
                    ? const Color(0xFF374151)
                    : AppColors.bgDivider,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDarkMode ? Colors.black26 : Colors.black38,
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
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
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: isDarkMode
                                  ? AppColors.textSecondary
                                  : Colors.black,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(icon, color: color, size: 20),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: isMobile ? 20 : 24,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode
                              ? AppColors.textPrimary
                              : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isPositive
                                  ? const Color(
                                      0xFF10B981,
                                    ).withValues(alpha: 0.1)
                                  : const Color(
                                      0xFFEF4444,
                                    ).withValues(alpha: 0.1),
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
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFEF4444),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  change,
                                  style: TextStyle(
                                    color: isPositive
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFEF4444),
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
                      style: TextStyle(
                        fontSize: isMobile ? 20 : 24,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode
                            ? AppColors.textPrimary
                            : Colors.black,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? AppTheme.colors.surface
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDarkMode
                              ? const Color(0xFF374151)
                              : AppColors.bgDivider,
                        ),
                      ),
                      child: const Row(
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
                            style: TextStyle(
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
                const SizedBox(height: 20),
                Container(
                  height: 300,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? AppTheme.colors.surface
                        : AppColors.textPrimary,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDarkMode
                          ? const Color(0xFF374151)
                          : AppColors.bgDivider,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDarkMode ? Colors.black26 : Colors.black38,
                        blurRadius: 20,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
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
            'No analytics data yet.',
            style: TextStyle(
              color: isDarkMode ? AppColors.textSecondary : Colors.black,
            ),
          ),
        );
      }

      return SfCartesianChart(
        plotAreaBorderWidth: 0,
        primaryXAxis: DateTimeAxis(
          majorGridLines: const MajorGridLines(width: 0),
          labelStyle: TextStyle(
            color: isDarkMode
                ? AppColors.textSecondary
                : Colors.black,
          ),
          axisLine: AxisLine(
            color: isDarkMode ? const Color(0xFF374151) : AppColors.bgDivider,
          ),
        ),
        primaryYAxis: NumericAxis(
          labelStyle: TextStyle(
            color: isDarkMode
                ? AppColors.textSecondary
                : Colors.black,
          ),
          axisLine: const AxisLine(width: 0),
          majorTickLines: const MajorTickLines(width: 0),
          majorGridLines: MajorGridLines(
            width: 1,
            color: isDarkMode ? const Color(0xFF374151) : AppColors.bgDivider,
            dashArray: const [5, 5],
          ),
        ),
        tooltipBehavior: TooltipBehavior(enable: true),
        series: <CartesianSeries<AnalyticsData, DateTime>>[
          SplineAreaSeries<AnalyticsData, DateTime>(
            dataSource: controller.analyticsData,
            xValueMapper: (data, _) => data.date,
            yValueMapper: (data, _) => data.views,
            gradient: LinearGradient(
              colors: [
                const Color(0xFF6366F1).withValues(alpha: 0.3),
                const Color(0xFF6366F1).withValues(alpha: 0.1),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderWidth: 3,
            borderColor: const Color(0xFF6366F1),
            name: 'Views',
          ),
        ],
      );
    });
  }

  Widget _buildRecommendationsSection(bool isDarkMode) {
    return Obx(() {
      final ch = controller.currentChannel.value;
      final videos = controller.recentVideos;
      final stats = controller.channelStats;
      final recommendations = _generateRecommendations(ch, videos, stats);

      if (recommendations.isEmpty) {
        return const SizedBox.shrink();
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recommendations',
            style: TextStyle(
              fontSize: isMobile ? 20 : 24,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? AppColors.textPrimary : Colors.black,
            ),
          ),
          const SizedBox(height: 20),
          GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isDesktop ? 3 : (isTablet ? 2 : 1),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: isDesktop ? 1.0 : (isTablet ? 1.2 : 1.5),
            ),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recommendations.length,
            itemBuilder: (context, index) {
              final rec = recommendations[index];
              return TweenAnimationBuilder<double>(
                duration: Duration(milliseconds: 600 + (index * 200)),
                tween: Tween(begin: 0, end: 1),
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
    });
  }

  List<Map<String, dynamic>> _generateRecommendations(
    Channel? ch,
    List<Video> videos,
    Map<String, dynamic> stats,
  ) {
    final recs = <Map<String, dynamic>>[];

    // 1. Banner check
    if (ch != null && ch.bannerUrl.isEmpty) {
      recs.add({
        'title': 'Add a Channel Banner',
        'description':
            'Channels with banners get up to 25% more subscribers. Upload a banner to make your channel stand out.',
        'icon': Icons.image_rounded,
        'color': const Color(0xFF10B981),
        'action': 'Customize',
        'onTap': () => controller.setSelectedIndex(6),
      });
    }

    // 2. Channel description check
    if (ch != null && ch.description.trim().length < 30) {
      recs.add({
        'title': 'Improve Channel Description',
        'description':
            'A detailed description helps viewers find your channel. Add keywords and tell viewers what to expect.',
        'icon': Icons.description_rounded,
        'color': const Color(0xFF8B5CF6),
        'action': 'Customize',
        'onTap': () => controller.setSelectedIndex(6),
      });
    }

    // 3. Upload frequency check
    if (videos.isNotEmpty) {
      final now = DateTime.now();
      final lastUpload = videos.first.createdAt.toDate();
      final daysSince = now.difference(lastUpload).inDays;
      if (daysSince > 14) {
        recs.add({
          'title': 'Upload New Content',
          'description':
              "It's been $daysSince days since your last upload. Consistent uploads boost discoverability and subscriber retention.",
          'icon': Icons.cloud_upload_rounded,
          'color': const Color(0xFFF59E0B),
          'action': 'Upload Now',
          'onTap': () => Get.toNamed('/upload'),
        });
      }
    } else if (ch != null) {
      recs.add({
        'title': 'Upload Your First Video',
        'description':
            "You haven't uploaded any videos yet. Start creating content to grow your channel.",
        'icon': Icons.cloud_upload_rounded,
        'color': const Color(0xFFF59E0B),
        'action': 'Upload Now',
        'onTap': () => Get.toNamed('/upload'),
      });
    }

    // 4. Engagement check — low average views
    if (videos.length >= 3) {
      final avgViews =
          videos.fold(0, (acc, v) => acc + v.viewCount) / videos.length;
      if (avgViews < 10) {
        recs.add({
          'title': 'Boost Video Visibility',
          'description':
              'Your recent videos average ${avgViews.toStringAsFixed(0)} views. Try sharing on social media and adding trending topics to increase reach.',
          'icon': Icons.trending_up_rounded,
          'color': const Color(0xFF3B82F6),
          'action': 'View Analytics',
          'onTap': () => controller.setSelectedIndex(3),
        });
      }
    }

    // 5. Tags/Topics check — videos with no tags
    if (videos.isNotEmpty) {
      final untaggedCount = videos
          .where((v) => v.tags.isEmpty && v.topics.isEmpty)
          .length;
      if (untaggedCount > 0) {
        recs.add({
          'title': 'Add Tags & Topics',
          'description':
              '$untaggedCount of your recent videos have no tags or topics. Adding them improves search discoverability.',
          'icon': Icons.label_rounded,
          'color': const Color(0xFFEC4899),
          'action': 'Manage Content',
          'onTap': () => controller.setSelectedIndex(2),
        });
      }
    }

    // 6. Thumbnail check — missing thumbnails
    if (videos.isNotEmpty) {
      final noThumbCount = videos.where((v) => v.thumbnailUrl.isEmpty).length;
      if (noThumbCount > 0) {
        recs.add({
          'title': 'Add Video Thumbnails',
          'description':
              '$noThumbCount of your videos are missing custom thumbnails. Eye-catching thumbnails can increase CTR by up to 30%.',
          'icon': Icons.filter_rounded,
          'color': const Color(0xFF14B8A6),
          'action': 'Manage Content',
          'onTap': () => controller.setSelectedIndex(2),
        });
      }
    }

    // 7. Create a Topic
    if (ch != null && videos.length >= 3) {
      recs.add({
        'title': 'Organize with Topics',
        'description':
            'Group your ${videos.length} videos into Topics to help viewers discover related content more easily.',
        'icon': Icons.topic_rounded,
        'color': const Color(0xFF6366F1),
        'action': 'Create Topic',
        'onTap': () => controller.setSelectedIndex(14),
      });
    }

    // 8. Social links check
    if (ch != null &&
        (ch.socialLinks == null || (ch.socialLinks?.isEmpty ?? true))) {
      recs.add({
        'title': 'Add Social Links',
        'description':
            'Connect your social media accounts to your channel to build a cross-platform audience.',
        'icon': Icons.link_rounded,
        'color': const Color(0xFF0EA5E9),
        'action': 'Customize',
        'onTap': () => controller.setSelectedIndex(6),
      });
    }

    // Cap at 3 most relevant recommendations
    return recs.take(3).toList();
  }

  Widget _buildRecommendationCard(
    Map<String, dynamic> recommendation,
    bool isDarkMode,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.colors.surface : AppColors.textPrimary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? const Color(0xFF374151) : AppColors.bgDivider,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode ? Colors.black26 : Colors.black38,
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            final onTap = recommendation['onTap'];
            if (onTap is VoidCallback) {
              onTap();
            }
            HapticFeedback.lightImpact();
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: (recommendation['color'] as Color).withValues(
                      alpha: 0.2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    recommendation['icon'] as IconData,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  recommendation['title'] as String,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode
                        ? AppColors.textPrimary
                        : Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Text(
                    recommendation['description'] as String,
                    style: TextStyle(
                      color: isDarkMode
                          ? AppColors.textSecondary
                          : Colors.black,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final onTap = recommendation['onTap'];
                      if (onTap is VoidCallback) {
                        onTap();
                      }
                      HapticFeedback.lightImpact();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: recommendation['color'] as Color,
                      foregroundColor: AppColors.textPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    child: Text(
                      recommendation['action'] as String,
                      style: const TextStyle(
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
              style: TextStyle(
                fontSize: isMobile ? 20 : 24,
                fontWeight: FontWeight.bold,
                color: isDarkMode
                    ? AppColors.textPrimary
                    : Colors.black,
              ),
            ),
            TextButton.icon(
              onPressed: () => controller.setSelectedIndex(2),
              icon: const Icon(
                Icons.arrow_forward_rounded,
                color: Color(0xFF6366F1),
                size: 16,
              ),
              label: const Text(
                'View all',
                style: TextStyle(
                  color: Color(0xFF6366F1),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Obx(() {
          final filtered = controller.filteredVideos;
          if (filtered.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(
                      Icons.search_off_rounded,
                      size: 48,
                      color: isDarkMode
                          ? AppColors.textTertiary
                          : const Color(0xFFCBD5E1),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      controller.searchQuery.value.isEmpty
                          ? 'No content yet'
                          : 'No matching content found',
                      style: TextStyle(
                        color: isDarkMode
                            ? AppColors.textSecondary
                            : Colors.black,
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
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final video = filtered[index];
              return TweenAnimationBuilder<double>(
                duration: Duration(milliseconds: 400 + (index * 150)),
                tween: Tween(begin: 0, end: 1),
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
        color: isDarkMode ? AppTheme.colors.surface : AppColors.textPrimary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? const Color(0xFF374151) : AppColors.bgDivider,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode ? Colors.black26 : Colors.black38,
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: HapticFeedback.lightImpact,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: isMobile ? 120 : 160,
                  height: isMobile ? 68 : 90,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: isDarkMode
                        ? const Color(0xFF374151)
                        : const Color(0xFFF1F5F9),
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
                          placeholder: (context, url) => ColoredBox(
                            color: isDarkMode
                                ? const Color(0xFF374151)
                                : const Color(0xFFF1F5F9),
                            child: Icon(
                              Icons.play_circle_outline_rounded,
                              color: isDarkMode
                                  ? AppColors.textSecondary
                                  : Colors.black,
                              size: 32,
                            ),
                          ),
                          errorWidget: (context, url, error) => ColoredBox(
                            color: isDarkMode
                                ? const Color(0xFF374151)
                                : const Color(0xFFF1F5F9),
                            child: Icon(
                              Icons.play_circle_outline_rounded,
                              color: isDarkMode
                                  ? AppColors.textSecondary
                                  : Colors.black,
                              size: 32,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.bgPage.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            video.duration,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: isDarkMode
                              ? AppColors.textPrimary
                              : Colors.black,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            Icon(
                              Icons.visibility_rounded,
                              size: 14,
                              color: isDarkMode
                                  ? Colors.white
                                  : Colors.black,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${video.views} views',
                              style: TextStyle(
                                color: isDarkMode
                                    ? AppColors.textSecondary
                                    : Colors.black,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(
                              Icons.access_time_rounded,
                              size: 14,
                              color: isDarkMode
                                  ? Colors.white
                                  : Colors.black,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat(
                                'MMM d, yyyy',
                              ).format(video.uploadedAt.toDate()),
                              style: TextStyle(
                                color: isDarkMode
                                    ? AppColors.textSecondary
                                    : Colors.black,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.more_vert_rounded,
                  color: isDarkMode
                      ? AppColors.textSecondary
                      : Colors.black,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openCreateTopicDialogFromQuickActions(bool isDarkMode) {
    final topicCtrl = Get.isRegistered<TopicManagementController>()
        ? Get.find<TopicManagementController>()
        : Get.put(TopicManagementController());
    final channelId = _getChannelId(channel);
    CreateTopicDialog.show(
      context: context,
      isDarkMode: isDarkMode,
      channelVideosFuture: topicCtrl.fetchChannelVideos(channelId),
      onCreateTopicSubmitted: (createCtrl) async {
        String? finalThumbnailUrl;
        if (createCtrl.thumbnailSource.value == 'custom' &&
            createCtrl.pickedCustomImageBytes.value != null) {
          finalThumbnailUrl = await topicCtrl.uploadTopicThumbnail(
            createCtrl.pickedCustomImageBytes.value!,
            createCtrl.pickedCustomImageName.value ?? 'custom_topic_thumb.jpg',
          );
        } else if (createCtrl.thumbnailSource.value == 'video') {
          finalThumbnailUrl = createCtrl.chosenVideoThumbnailUrl.value;
        }

        await topicCtrl.createTopic(
          channelId: channelId,
          title: createCtrl.titleController.text,
          handle: createCtrl.handleController.text,
          description: createCtrl.descriptionController.text,
          category: createCtrl.categoryController.text.isEmpty
              ? 'General'
              : createCtrl.categoryController.text,
          thumbnailUrl: finalThumbnailUrl,
          selectedVideoIds: createCtrl.selectedVideoIds.toList(),
        );
      },
    );
  }

  Widget _buildQuickActionsSection(bool isDarkMode) {
    final actions = [
      {
        'title': 'Upload Video',
        'icon': Icons.cloud_upload_rounded,
        'color': const Color(0xFF10B981),
        'onTap': () => Get.toNamed('/upload'),
      },
      {
        'title': 'Create Topic',
        'icon': Icons.topic_rounded,
        'color': const Color(0xFFEF4444),
        'onTap': () => _openCreateTopicDialogFromQuickActions(isDarkMode),
      },
      {
        'title': 'Create Post',
        'icon': Icons.edit_rounded,
        'color': const Color(0xFF3B82F6),
        'onTap': () => Get.toNamed('/upload/community'),
      },
      {
        'title': 'View Analytics',
        'icon': Icons.bar_chart_rounded,
        'color': const Color(0xFF8B5CF6),
        'onTap': () => controller.setSelectedIndex(3),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: isMobile ? 20 : 24,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? AppColors.textPrimary : Colors.black,
          ),
        ),
        const SizedBox(height: 20),
        GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isDesktop ? 4 : (isTablet ? 2 : 2),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: isDesktop ? 1.5 : (isTablet ? 1.6 : 1.3),
          ),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: actions.length,
          itemBuilder: (context, index) {
            final action = actions[index];
            return TweenAnimationBuilder<double>(
              duration: Duration(milliseconds: 400 + (index * 100)),
              tween: Tween(begin: 0, end: 1),
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
        color: isDarkMode ? AppTheme.colors.surface : AppColors.textPrimary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? const Color(0xFF374151) : AppColors.bgDivider,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode ? Colors.black26 : Colors.black38,
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 4),
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (action['color'] as Color).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    action['icon'] as IconData,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    action['title'] as String,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDarkMode
                          ? AppColors.textPrimary
                          : Colors.black,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                  ),
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
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.dashboard_rounded,
                color: Colors.white,
                size: 80,
              ),
              const SizedBox(height: 24),
              const Text(
                'Creator Studio',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Please sign in to access your Creator Studio dashboard.',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
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
                  foregroundColor: AppColors.textPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
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
