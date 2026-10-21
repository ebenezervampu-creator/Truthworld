import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/currency_localization_service.dart';
import 'package:truthworld/core/services/distributed_counter_service.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/core/utils/watch_time_formatter.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/analytics/presentation/controllers/creator_analytics_controller.dart';
import 'package:truthworld/features/analytics/presentation/controllers/revenue_analytics_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/video_management.dart';
import 'package:truthworld/features/video/data/models/video.dart';

class AnalyticsData {
  AnalyticsData(this.date, this.views);
  final DateTime date;
  final int views;
}

// ==========================================================================
// MODERNIZED DASHBOARD SCREEN - NOW WITH LIVE ANALYTICS AND SYNCFUSION CHARTS
// ==========================================================================

class DashboardController extends BaseController {
  DashboardController({String channelId = '', this.autoInitialize = true})
      : _channelId = channelId;
  final bool autoInitialize;
  String _channelId;
  String get channelId => _channelId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final Rx<Channel?> currentChannel = Rx<Channel?>(null);
  final RxBool showApprovalBanner = false.obs;

  RxInt selectedIndex = 1.obs;
  RxBool isDrawerExpanded = true.obs;
  RxBool rxIsLoading = true.obs;
  final RxBool rxIsRefreshing = false.obs;
  @override
  bool get isRefreshing => rxIsRefreshing.value || super.isRefreshing;
  RxString rxErrorMessage = ''.obs;

  RxMap<String, dynamic> channelStats = <String, dynamic>{}.obs;
  RxList<Video> recentVideos = <Video>[].obs;
  RxList<AnalyticsData> analyticsData = <AnalyticsData>[].obs;
  RxString searchQuery = ''.obs;

  RxInt copyrightClaimsCount = 0.obs;
  final RxInt totalWatchTimeSeconds = 0.obs;

  // Reactive Revenue & Earning Streams
  final RxDouble rxMembershipsRevenue = 0.0.obs;
  final RxDouble rxSuperchatRevenue = 0.0.obs;
  final RxDouble rxAdsRevenue = 0.0.obs;
  final RxDouble rxWatchTimeRevenue = 0.0.obs;
  final RxDouble rxTotalRevenue = 0.0.obs;
  final RxInt rxActiveMembersCount = 0.obs;
  final RxInt rxActiveTiersCount = 0.obs;

  static double get usdToInrRate =>
      Get.isRegistered<CurrencyLocalizationService>()
          ? CurrencyLocalizationService.to.rate
          : CurrencyLocalizationService.defaultRate;

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

  /// Target view count threshold required for cash withdrawal
  static const int videoWithdrawalViewsThreshold = 1000;

  /// Checks if a specific video has reached 10 hours watch time and 1,000 views for cash withdrawal
  bool isVideoWithdrawalEligible(Video video) {
    return getVideoWatchHours(video) >= 10.0 &&
        video.viewCount >= videoWithdrawalViewsThreshold;
  }

  /// Checks if ANY video on the channel has crossed the threshold (1k views & 10 hours watch time)
  bool get hasAnyVideoCrossedThreshold =>
      recentVideos.any(isVideoWithdrawalEligible);

  /// Returns the first video that crossed 1k views and 10 hours watch time (if any)
  Video? get firstQualifiedVideo =>
      recentVideos.firstWhereOrNull(isVideoWithdrawalEligible);

  /// Count of videos that crossed the 1,000 views and 10 hours watch time threshold
  int get qualifiedVideoCount =>
      recentVideos.where(isVideoWithdrawalEligible).length;

  /// Count of videos that have not yet crossed the 1,000 views and 10 hours watch time threshold
  int get pendingVideoCount =>
      recentVideos.where((v) => !isVideoWithdrawalEligible(v)).length;

  /// Evaluates whether creator KYC verification is completed
  bool get isCreatorKycVerified {
    if (Get.isRegistered<RevenueAnalyticsController>()) {
      return Get.find<RevenueAnalyticsController>().isKycVerified;
    }
    return currentChannel.value?.isVerified ?? false;
  }

  /// Evaluates if the channel's monetization is ON:
  /// Monetization turns ON for every channel when:
  /// 1. Any video of the channel has crossed 1,000 views AND 10 hours watch time.
  /// 2. Creator KYC verification is completed.
  /// Once ON, every video generates revenue.
  bool isChannelMonetizationOn({bool? isKycVerified}) {
    final ch = currentChannel.value;
    if (ch != null) {
      if (ch.channelType == ChannelType.custom) return true;
      if (ch.monetizationTier != MonetizationTier.none) return true;
      if (ch.monetizationSettings?['isMonetized'] == true) return true;
    }
    final kyc = isKycVerified ?? isCreatorKycVerified;
    return hasAnyVideoCrossedThreshold && kyc;
  }

  /// Reactive getter indicating if monetization is currently active on the channel
  bool get isChannelMonetizationActive => isChannelMonetizationOn();

  /// Automatically activates monetization in Firestore if channel satisfies the qualification gates
  Future<void> checkAndActivateMonetization() async {
    if (channelId.isEmpty) return;
    if (isChannelMonetizationOn()) {
      try {
        final ch = currentChannel.value;
        if (ch != null &&
            ch.monetizationTier == MonetizationTier.none &&
            ch.monetizationSettings?['isMonetized'] != true) {
          await _firestore
              .collection(FirestoreCollections.channels)
              .doc(channelId)
              .update({
            'monetizationTier': MonetizationTier.eligible.name,
            'isMonetized': true,
            'monetizationActivatedAt': FieldValue.serverTimestamp(),
          });
        }
      } catch (e, stackTrace) {
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'DashboardController.checkAndActivateMonetization',
        );
      }
    }
  }

  StreamSubscription? _statsSubscription;
  StreamSubscription? _videosSubscription;
  StreamSubscription? _ownerVideosSubscription;
  StreamSubscription? _analyticsSubscription;
  StreamSubscription? _channelSubscription;
  StreamSubscription? _copyrightSubscription;
  StreamSubscription? _membersSubscription;
  StreamSubscription? _membershipTiersSubscription;
  StreamSubscription? _revenueStatementsSubscription;
  Timer? _loadingTimeoutTimer;
  Worker? _rateWorker;
  List<Map<String, dynamic>> _activeMemberData = [];
  List<Map<String, dynamic>> _activeTierData = [];
  double _directMembersRevenue = 0.0;
  double _tierMembersRevenue = 0.0;
  int _tierMembersCount = 0;

  /// Get filtered videos based on search query
  List<Video> get filteredVideos {
    if (searchQuery.value.isEmpty) {
      return recentVideos.toList();
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
    if (_channelId.isEmpty) {
      if (Get.parameters.containsKey('channelId') &&
          Get.parameters['channelId']!.isNotEmpty) {
        _channelId = Get.parameters['channelId']!;
      } else if (Get.arguments is Map &&
          Get.arguments.containsKey('channelId') &&
          Get.arguments['channelId'] != null) {
        _channelId = Get.arguments['channelId'].toString();
      } else if (Get.arguments is Map &&
          Get.arguments.containsKey('channel') &&
          Get.arguments['channel'] != null) {
        final ch = Get.arguments['channel'];
        if (ch is Channel) {
          _channelId = ch.id;
          currentChannel.value = ch;
        } else if (ch is Map) {
          _channelId = (ch['id'] ?? '').toString();
        }
      } else if (Get.isRegistered<AuthService>() &&
          AuthService.to.rxUserChannel.value != null) {
        _channelId = AuthService.to.rxUserChannel.value!.id;
        currentChannel.value = AuthService.to.rxUserChannel.value;
      }
    }
    if (Get.isRegistered<CurrencyLocalizationService>()) {
      _rateWorker = ever(CurrencyLocalizationService.to.liveUsdToInrRate, (_) {
        _recalculateMembershipsWithRate();
      });
    }

    if (_channelId.isNotEmpty && autoInitialize) {
      _initializeData();
    } else {
      rxIsLoading.value = false;
      if (_channelId.isEmpty) {
        rxErrorMessage.value = 'No channel provided.';
      }
    }
  }

  /// Safely cancels all active subscriptions, timers, and purges all channel data and analytics.
  void clearData() {
    _channelId = '';
    currentChannel.value = null;
    showApprovalBanner.value = false;
    rxIsLoading.value = false;
    rxErrorMessage.value = '';
    channelStats.clear();
    recentVideos.clear();
    analyticsData.clear();
    searchQuery.value = '';
    copyrightClaimsCount.value = 0;
    totalWatchTimeSeconds.value = 0;
    rxMembershipsRevenue.value = 0.0;
    rxSuperchatRevenue.value = 0.0;
    rxAdsRevenue.value = 0.0;
    rxWatchTimeRevenue.value = 0.0;
    rxTotalRevenue.value = 0.0;
    rxActiveMembersCount.value = 0;
    rxActiveTiersCount.value = 0;
    _activeMemberData.clear();
    _activeTierData.clear();
    _directMembersRevenue = 0.0;
    _tierMembersRevenue = 0.0;
    _tierMembersCount = 0;

    _loadingTimeoutTimer?.cancel();
    _statsSubscription?.cancel();
    _statsSubscription = null;
    _videosSubscription?.cancel();
    _videosSubscription = null;
    _ownerVideosSubscription?.cancel();
    _ownerVideosSubscription = null;
    _analyticsSubscription?.cancel();
    _analyticsSubscription = null;
    _channelSubscription?.cancel();
    _channelSubscription = null;
    _copyrightSubscription?.cancel();
    _copyrightSubscription = null;
    _membersSubscription?.cancel();
    _membersSubscription = null;
    _membershipTiersSubscription?.cancel();
    _membershipTiersSubscription = null;
    _revenueStatementsSubscription?.cancel();
    _revenueStatementsSubscription = null;
  }

  void updateChannelId(String id) {
    if (id.isEmpty) {
      clearData();
      return;
    }
    if (id != _channelId) {
      _channelId = id;
      if (autoInitialize) {
        _initializeData();
      }
    }
  }

  /// Reload all channel stats, recent videos, analytics, and revenue data
  void refreshChannelData() {
    _initializeData();
  }

  /// Sync real-time metrics computed by CreatorAnalyticsController into Studio Dashboard
  void syncMetricsFromAnalytics({
    required int views,
    required int watchTimeSeconds,
  }) {
    var updated = false;
    final currentViews = int.tryParse(
      (channelStats['views'] ?? '0').toString().replaceAll(RegExp('[^0-9]'), ''),
    ) ?? 0;
    final totalVideoViews = recentVideos.fold<int>(
      0,
      (acc, v) => acc + v.viewCount,
    );
    final isInflated = recentVideos.isNotEmpty && currentViews > totalVideoViews;
    if (views > currentViews || (isInflated && views >= totalVideoViews)) {
      channelStats['views'] = _formatNumber(views);
      updated = true;
    }

    final totalVideoWatch = recentVideos.fold<int>(
      0,
      (acc, v) => acc + v.totalWatchTimeSeconds,
    );
    final isWatchInflated =
        recentVideos.isNotEmpty && totalWatchTimeSeconds.value > totalVideoWatch;
    if (watchTimeSeconds > totalWatchTimeSeconds.value ||
        (isWatchInflated && watchTimeSeconds >= totalVideoWatch)) {
      totalWatchTimeSeconds.value = watchTimeSeconds;
      channelStats['watchTime'] = formattedWatchTime;
      updated = true;
    }

    if (updated) {
      channelStats.refresh();
      checkAndActivateMonetization();
    }
  }

  /// Performs an asynchronous, in-place live refresh of channel stats, distributed shards,
  /// recent videos, and creator analytics without tearing down active streams.
  ///
  /// Network requests are multiplexed concurrently with [Future.wait] for absolute low latency.
  Future<void> refreshData({bool showFeedback = false}) async {
    if (rxIsRefreshing.value) return;
    try {
      rxIsRefreshing.value = true;

      // Execute all remote fetches concurrently over multiplexed connection
      final channelDocFuture = channelId.isNotEmpty
          ? _firestore
              .collection(FirestoreCollections.channels)
              .doc(channelId)
              .get()
              .then<DocumentSnapshot<Map<String, dynamic>>?>((doc) => doc)
              .catchError((_) => null)
          : Future<DocumentSnapshot<Map<String, dynamic>>?>.value();

      final videosFuture = channelId.isNotEmpty
          ? _firestore
              .collection(FirestoreCollections.videos)
              .where('channelId', isEqualTo: channelId)
              .get()
              .then<QuerySnapshot<Map<String, dynamic>>?>((snap) => snap)
              .catchError((_) => null)
          : Future<QuerySnapshot<Map<String, dynamic>>?>.value();

      final shardWatchFuture = (channelId.isNotEmpty &&
              Get.isRegistered<DistributedCounterService>())
          ? DistributedCounterService.to
              .getRealtimeChannelWatchTime(channelId)
              .catchError((_) => 0)
          : Future<int>.value(0);

      final shardViewsFuture = (channelId.isNotEmpty &&
              Get.isRegistered<DistributedCounterService>())
          ? DistributedCounterService.to
              .getRealtimeChannelViews(channelId)
              .catchError((_) => 0)
          : Future<int>.value(0);

      final analyticsFuture = Get.isRegistered<CreatorAnalyticsController>()
          ? CreatorAnalyticsController.to.refreshAnalytics().catchError((_) {})
          : Future<void>.value();

      final results = await Future.wait<dynamic>([
        channelDocFuture,
        videosFuture,
        shardWatchFuture,
        shardViewsFuture,
        analyticsFuture,
      ]);

      final channelDoc = results[0] as DocumentSnapshot<Map<String, dynamic>>?;
      final vSnapshot = results[1] as QuerySnapshot<Map<String, dynamic>>?;
      final shardWatch = (results[2] as int?) ?? 0;
      final shardViews = (results[3] as int?) ?? 0;

      // 1. Apply live channel doc
      if (channelDoc != null && channelDoc.exists) {
        final ch = Channel.fromDocumentSnapshot(channelDoc);
        currentChannel.value = ch;
      }

      // 2. Apply active videos
      if (vSnapshot != null) {
        final videos = vSnapshot.docs
            .map(Video.fromDocumentSnapshot)
            .where((v) => v.status != VideoStatus.deleted)
            .toList();

        videos.sort((a, b) {
          final dateA = a.uploadedAt.toDate().isAfter(a.createdAt.toDate())
              ? a.uploadedAt.toDate()
              : a.createdAt.toDate();
          final dateB = b.uploadedAt.toDate().isAfter(b.createdAt.toDate())
              ? b.uploadedAt.toDate()
              : b.createdAt.toDate();
          return dateB.compareTo(dateA);
        });

        _applyRecentVideos(videos);
      }

      // 3. Reconcile with real-time distributed counter shards only if no authoritative video list
      if (recentVideos.isEmpty) {
        if (shardWatch > totalWatchTimeSeconds.value) {
          totalWatchTimeSeconds.value = shardWatch;
          channelStats['watchTime'] = formattedWatchTime;
        }
        final currentViews = int.tryParse(
          (channelStats['views'] ?? '0')
              .toString()
              .replaceAll(RegExp('[^0-9]'), ''),
        ) ?? 0;
        if (shardViews > currentViews) {
          channelStats['views'] = _formatNumber(shardViews);
        }
      }
      channelStats.refresh();

      // Trigger background server-side reconciliation if authenticated
      if (channelId.isNotEmpty && FirebaseAuth.instance.currentUser != null) {
        try {
          FirebaseFunctions.instanceFor(region: 'asia-south1')
              .httpsCallable('reconcileChannelMetrics')
              .call({'channelId': channelId})
              .catchError((_) => null);
        } catch (_) {}
      }

      // 4. Check monetization eligibility
      checkAndActivateMonetization();

      if (showFeedback) {
        AppSnackbar.success(
          'Studio metrics have been updated with the latest live data.',
          title: 'Studio Refreshed',
        );
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'DashboardController.refreshData',
      );
      if (showFeedback) {
        AppSnackbar.info(
          'Unable to refresh studio metrics right now. Please check your connection and try again.',
        );
      }
    } finally {
      rxIsRefreshing.value = false;
    }
  }

  @override
  void onClose() {
    _rateWorker?.dispose();
    clearData();
    super.onClose();
  }

  void _initializeData() {
    _loadingTimeoutTimer?.cancel();
    _statsSubscription?.cancel();
    _statsSubscription = null;
    _videosSubscription?.cancel();
    _videosSubscription = null;
    _ownerVideosSubscription?.cancel();
    _ownerVideosSubscription = null;
    _analyticsSubscription?.cancel();
    _analyticsSubscription = null;
    _channelSubscription?.cancel();
    _channelSubscription = null;
    _copyrightSubscription?.cancel();
    _copyrightSubscription = null;
    _membersSubscription?.cancel();
    _membersSubscription = null;
    _membershipTiersSubscription?.cancel();
    _membershipTiersSubscription = null;
    _revenueStatementsSubscription?.cancel();
    _revenueStatementsSubscription = null;

    channelStats.clear();
    recentVideos.clear();
    analyticsData.clear();
    copyrightClaimsCount.value = 0;
    totalWatchTimeSeconds.value = 0;
    rxMembershipsRevenue.value = 0.0;
    rxSuperchatRevenue.value = 0.0;
    rxAdsRevenue.value = 0.0;
    rxWatchTimeRevenue.value = 0.0;
    rxTotalRevenue.value = 0.0;
    rxActiveMembersCount.value = 0;
    rxActiveTiersCount.value = 0;
    _activeMemberData.clear();
    _activeTierData.clear();
    _directMembersRevenue = 0.0;
    _tierMembersRevenue = 0.0;
    _tierMembersCount = 0;

    rxIsLoading.value = true;
    try {
      _loadChannelStats();
      _loadRecentVideos();
      _loadAnalyticsData();
      _loadCopyrightStatus();
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'DashboardController._initializeData',
      );
    }
    // Use managed Timer to set loading to false after a short period,
    // allowing streams to populate data.
    _loadingTimeoutTimer = trackTimer(Timer(const Duration(seconds: 2), () {
      if (!isClosed && rxIsLoading.value) {
        rxIsLoading.value = false;
      }
    }));
  }

  void _loadChannelStats() {
    _loadRevenueAndMemberships();

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
              var rawWatchSeconds = 0;
              if (data.containsKey('totalWatchTimeSeconds')) {
                rawWatchSeconds = (data['totalWatchTimeSeconds'] as num).toInt();
              } else if (data.containsKey('totalWatchTimeMinutes')) {
                rawWatchSeconds =
                    (((data['totalWatchTimeMinutes'] as num).toDouble()) * 60)
                        .toInt();
              } else if (data['metrics'] is Map &&
                  (data['metrics'] as Map)['totalWatchTimeMinutes'] != null) {
                rawWatchSeconds =
                    ((((data['metrics'] as Map)['totalWatchTimeMinutes'] as num).toDouble()) * 60)
                        .toInt();
              } else if (data['metrics'] is Map &&
                  (data['metrics'] as Map)['totalWatchTimeSeconds'] != null) {
                rawWatchSeconds =
                    ((data['metrics'] as Map)['totalWatchTimeSeconds'] as num)
                        .toInt();
              }
              if (recentVideos.isNotEmpty) {
                final totalVw = recentVideos.fold<int>(
                  0,
                  (acc, v) => acc + v.totalWatchTimeSeconds,
                );
                if (totalVw > 0) {
                  rawWatchSeconds = math.max(rawWatchSeconds, totalVw);
                }
              }
              if (rawWatchSeconds > totalWatchTimeSeconds.value) {
                totalWatchTimeSeconds.value = rawWatchSeconds;
              }
              if (totalWatchTimeSeconds.value <= 0 && Get.isRegistered<DistributedCounterService>()) {
                DistributedCounterService.to.getRealtimeChannelWatchTime(channelId).then((val) {
                  if (val > totalWatchTimeSeconds.value && !isClosed) {
                    totalWatchTimeSeconds.value = val;
                    channelStats.value = {
                      ...channelStats,
                      'watchTime': formattedWatchTime,
                    };
                  }
                });
              }

              final superchat =
                  (data['superchatRevenueTotal'] as num?)?.toDouble() ?? 0.0;
              rxSuperchatRevenue.value = superchat;

              final ads = (data['adsRevenueTotal'] as num?)?.toDouble() ?? 0.0;
              rxAdsRevenue.value = ads;

              final membershipTotal = ((data['membershipRevenueTotal'] ??
                      data['membershipsRevenueTotal']) as num?)
                  ?.toDouble() ??
                  0.0;
              if (membershipTotal > 0 && rxMembershipsRevenue.value == 0) {
                rxMembershipsRevenue.value = membershipTotal;
              }
              final premiumSubs =
                  (data['premiumSubsRevenueTotal'] as num?)?.toDouble() ?? 0.0;
              final watchTimeRev =
                  (data['watchTimeRevenueTotal'] as num?)?.toDouble() ?? 0.0;
              rxWatchTimeRevenue.value = premiumSubs > 0 ? premiumSubs : watchTimeRev;
              _updateRevenueStats();
            }

            final channel = Channel.fromDocumentSnapshot(snapshot);
            currentChannel.value = channel;

            final isDismissedInDoc =
                snapshot.data()?['brandingApprovedDismissed'] == true ||
                    snapshot.data()?['approvalBannerDismissed'] == true ||
                    channel.brandingApprovedDismissed;
            final isDismissedInStorage =
                GetStorage().read<bool>('approval_shown_${channel.id}') == true;

            if (isDismissedInDoc || isDismissedInStorage) {
              showApprovalBanner.value = false;
            } else if (channel.status == ChannelStatus.active ||
                channel.geminiApproved == true) {
              showApprovalBanner.value = true;
              GetStorage().write('approval_shown_${channel.id}', true);
            } else {
              showApprovalBanner.value = false;
            }

            final currentTotalRev = rxTotalRevenue.value;
            final formattedRev = '₹${currentTotalRev.toStringAsFixed(2)}';
            final formattedChange =
                currentTotalRev > 0 ? '+₹${currentTotalRev.toStringAsFixed(2)}' : '+₹0.00';

            final currentParsedViews = int.tryParse(
              (channelStats['views'] ?? '0').toString().replaceAll(RegExp('[^0-9]'), ''),
            ) ?? 0;
            final activeVideos = recentVideos.isNotEmpty
                ? recentVideos
                : (Get.isRegistered<VideoManagementController>()
                    ? Get.find<VideoManagementController>().channelVideos
                    : (Get.isRegistered<CreatorAnalyticsController>()
                        ? Get.find<CreatorAnalyticsController>().channelVideos
                        : <Video>[]));
            final totalVideoViews = activeVideos.fold<int>(
              0,
              (acc, v) => acc + v.viewCount,
            );
            final effectiveViews = activeVideos.isNotEmpty
                ? totalVideoViews
                : (currentParsedViews > 0
                    ? currentParsedViews
                    : channel.viewCount);

            channelStats.value = {
              ...channelStats,
              if (effectiveViews > 0) 'views': _formatNumber(effectiveViews),
              'subscribers': _formatNumber(channel.subscriberCount),
              'rawSubscribers': channel.subscriberCount,
              'watchTime': formattedWatchTime,
              'revenue': formattedRev,
              'viewsChange': channelStats['viewsChange'] ?? '+0%',
              'watchTimeChange': channelStats['watchTimeChange'] ?? '+0%',
              'subscribersChange': channelStats['subscribersChange'] ?? '+0',
              'revenueChange': formattedChange,
            };
          }
        },
        onError: (e, stackTrace) => ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'DashboardController._channelSubscription',
        ),
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
          final summaryWatchSeconds =
              (data['totalWatchTimeSeconds'] as num?)?.toInt() ?? 0;
          if (summaryWatchSeconds > 0) {
            var effectiveSummary = summaryWatchSeconds;
            if (recentVideos.isNotEmpty) {
              final videoWatchSum = recentVideos.fold<int>(
                0,
                (acc, v) => acc + v.totalWatchTimeSeconds,
              );
              effectiveSummary = math.max(effectiveSummary, videoWatchSum);
            }
            if (effectiveSummary > totalWatchTimeSeconds.value) {
              totalWatchTimeSeconds.value = effectiveSummary;
            }
          }
          final currentTotalRev = rxTotalRevenue.value;
          final formattedRev = '₹${currentTotalRev.toStringAsFixed(2)}';
          final formattedChange =
              currentTotalRev > 0 ? '+₹${currentTotalRev.toStringAsFixed(2)}' : '+₹0.00';

          final currentSubsCount = currentChannel.value?.subscriberCount ??
              (channelStats['rawSubscribers'] as int?) ??
              (data['subscribers'] as num?)?.toInt() ??
              0;

          final activeVideos = recentVideos.isNotEmpty
              ? recentVideos
              : (Get.isRegistered<VideoManagementController>()
                  ? Get.find<VideoManagementController>().channelVideos
                  : (Get.isRegistered<CreatorAnalyticsController>()
                      ? Get.find<CreatorAnalyticsController>().channelVideos
                      : <Video>[]));
          final totalVideoViews = activeVideos.fold<int>(
            0,
            (acc, v) => acc + v.viewCount,
          );
          final totalViewsCount = (data['totalViews'] as num?)?.toInt() ??
              currentChannel.value?.viewCount ??
              0;
          final currentParsedViews = int.tryParse(
            (channelStats['views'] ?? '0').toString().replaceAll(RegExp('[^0-9]'), ''),
          ) ?? 0;
          final effectiveViewsCount = activeVideos.isNotEmpty
              ? totalVideoViews
              : (totalViewsCount > 0 ? totalViewsCount : currentParsedViews);

          channelStats.value = {
            ...channelStats,
            if (effectiveViewsCount > 0) 'views': _formatNumber(effectiveViewsCount),
            'watchTime': formattedWatchTime,
            'subscribers': _formatNumber(currentSubsCount),
            'rawSubscribers': currentSubsCount,
            'revenue': formattedRev,
            'viewsChange': channelStats['viewsChange'] ?? '+0%',
            'watchTimeChange': channelStats['watchTimeChange'] ?? '+0%',
            'subscribersChange': channelStats['subscribersChange'] ?? '+0',
            'revenueChange': formattedChange,
          };
        }
      },
      onError: (error, stackTrace) {
        ErrorHandler.log(
          error,
          stackTrace: stackTrace,
          tag: 'DashboardController._statsSubscription',
        );
        rxErrorMessage.value = 'Failed to load channel stats.';
      },
    ));
  }

  void _loadRevenueAndMemberships() {
    if (channelId.isEmpty) return;

    // Sync from RevenueAnalyticsController if it already resolved revenue for this channel
    if (Get.isRegistered<RevenueAnalyticsController>()) {
      final revCtrl = Get.find<RevenueAnalyticsController>();
      if (revCtrl.channelId.value == channelId && revCtrl.totalRevenue.value > 0) {
        rxMembershipsRevenue.value = revCtrl.membershipsRevenue.value;
        rxSuperchatRevenue.value = revCtrl.superchatRevenue.value;
        rxAdsRevenue.value = revCtrl.adsRevenue.value;
        rxWatchTimeRevenue.value = revCtrl.watchTimeRevenue.value;
        _updateRevenueStats();
      }
    }

    // 1. Members stream for active fan funding
    final membersRef = _firestore
        .collection(FirestoreCollections.channels)
        .doc(channelId)
        .collection('members');
    trackSubscription(
      _membersSubscription = membersRef.snapshots().listen(
        (snapshot) {
          final activeDocs = snapshot.docs.where((doc) {
            final data = doc.data();
            return (data['status'] ?? 'active').toString().toLowerCase() ==
                'active';
          }).toList();

          _activeMemberData = activeDocs.map((doc) => doc.data()).toList();

          var totalMemberships = 0.0;
          for (final doc in activeDocs) {
            final data = doc.data();
            final price = (data['price'] as num?)?.toDouble() ?? 0.0;
            final rawCurrency = (data['currency'] as String?)?.toUpperCase();
            final currency = rawCurrency ?? (price >= 50 ? 'INR' : 'USD');
            if (currency == 'USD') {
              totalMemberships += price * usdToInrRate;
            } else {
              totalMemberships += price;
            }
          }

          _directMembersRevenue = totalMemberships;

          if (activeDocs.isNotEmpty) {
            rxActiveMembersCount.value = activeDocs.length;
            rxMembershipsRevenue.value = _directMembersRevenue;
          } else if (_tierMembersRevenue > 0) {
            rxMembershipsRevenue.value = _tierMembersRevenue;
            if (rxActiveMembersCount.value == 0) {
              rxActiveMembersCount.value = _tierMembersCount;
            }
          } else {
            rxActiveMembersCount.value = 0;
            rxMembershipsRevenue.value = 0.0;
          }
          _updateRevenueStats();
        },
        onError: (e, stackTrace) => ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'DashboardController._membersSubscription',
        ),
      ),
    );

    // 2. Membership Tiers stream for fallback member counts & active tiers
    final tiersRef = _firestore
        .collection(FirestoreCollections.channels)
        .doc(channelId)
        .collection('membership_tiers');
    trackSubscription(
      _membershipTiersSubscription = tiersRef.snapshots().listen(
        (snapshot) {
          var activeTiers = 0;
          var tierMembersRevenue = 0.0;
          var tierMembersCount = 0;
          final tierDataList = <Map<String, dynamic>>[];

          for (final doc in snapshot.docs) {
            final data = doc.data();
            if (data['isEnabled'] != false) {
              activeTiers++;
              tierDataList.add(data);
              final price = (data['price'] as num?)?.toDouble() ?? 0.0;
              final count = (data['memberCount'] as num?)?.toInt() ?? 0;
              final rawCurrency = (data['currency'] as String?)?.toUpperCase();
              final currency = rawCurrency ?? (price >= 50 ? 'INR' : 'USD');
              if (currency == 'USD') {
                tierMembersRevenue += price * usdToInrRate * count;
              } else {
                tierMembersRevenue += price * count;
              }
              tierMembersCount += count;
            }
          }

          _activeTierData = tierDataList;
          _tierMembersRevenue = tierMembersRevenue;
          _tierMembersCount = tierMembersCount;
          rxActiveTiersCount.value = activeTiers;

          if (_directMembersRevenue > 0) {
            rxMembershipsRevenue.value = _directMembersRevenue;
          } else if (tierMembersRevenue > 0) {
            rxMembershipsRevenue.value = tierMembersRevenue;
            if (rxActiveMembersCount.value == 0) {
              rxActiveMembersCount.value = tierMembersCount;
            }
          }
          _updateRevenueStats();
        },
        onError: (e, stackTrace) => ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'DashboardController._membershipTiersSubscription',
        ),
      ),
    );

    // 3. Revenue statements stream
    final uid = Get.isRegistered<AuthService>() ? AuthService.to.uid : '';
    var statementsRef = _firestore
        .collection('revenue_statements')
        .where('channelId', isEqualTo: channelId);
    if (uid.isNotEmpty) {
      statementsRef = statementsRef.where('userId', isEqualTo: uid);
    }
    trackSubscription(
      _revenueStatementsSubscription = statementsRef.limit(1).snapshots().listen(
        (snapshot) {
          if (snapshot.docs.isNotEmpty) {
            final data = snapshot.docs.first.data();
            final ads = (data['grossAdsRevenue'] as num?)?.toDouble() ?? 0.0;
            if (ads > 0 && rxAdsRevenue.value == 0.0) {
              rxAdsRevenue.value = ads;
            }
            final premiumSubs =
                (data['grossPremiumSubsRevenue'] as num?)?.toDouble() ?? 0.0;
            if (premiumSubs > 0 && rxWatchTimeRevenue.value == 0.0) {
              rxWatchTimeRevenue.value = premiumSubs;
            }
            final creatorShare =
                (data['creatorShare'] as num?)?.toDouble() ?? 0.0;
            if (creatorShare > 0 && rxTotalRevenue.value == 0.0) {
              rxTotalRevenue.value = creatorShare;
            }
            _updateRevenueStats();
          }
        },
        onError: (e, stackTrace) => ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'DashboardController._revenueStatementsSubscription',
        ),
      ),
    );
  }

  void updateRevenueStats() => _updateRevenueStats();

  void _updateRevenueStats() {
    final total = rxMembershipsRevenue.value +
        rxSuperchatRevenue.value +
        rxAdsRevenue.value +
        rxWatchTimeRevenue.value;
    rxTotalRevenue.value = total;

    final formattedRev = '₹${total.toStringAsFixed(2)}';
    final formattedChange =
        total > 0 ? '+₹${total.toStringAsFixed(2)}' : '+₹0.00';

    channelStats.value = {
      ...channelStats,
      'revenue': formattedRev,
      'revenueChange': formattedChange,
    };
  }

  void _recalculateMembershipsWithRate() {
    var recalculated = false;
    if (_activeMemberData.isNotEmpty) {
      var totalMemberships = 0.0;
      for (final data in _activeMemberData) {
        final price = (data['price'] as num?)?.toDouble() ?? 0.0;
        final rawCurrency = (data['currency'] as String?)?.toUpperCase();
        final currency = rawCurrency ?? (price >= 50 ? 'INR' : 'USD');
        if (currency == 'USD') {
          totalMemberships += price * usdToInrRate;
        } else {
          totalMemberships += price;
        }
      }
      _directMembersRevenue = totalMemberships;
      rxMembershipsRevenue.value = totalMemberships;
      recalculated = true;
    } else if (_activeTierData.isNotEmpty) {
      var tierMembersRevenue = 0.0;
      for (final data in _activeTierData) {
        final price = (data['price'] as num?)?.toDouble() ?? 0.0;
        final count = (data['memberCount'] as num?)?.toInt() ?? 0;
        final rawCurrency = (data['currency'] as String?)?.toUpperCase();
        final currency = rawCurrency ?? (price >= 50 ? 'INR' : 'USD');
        if (currency == 'USD') {
          tierMembersRevenue += price * usdToInrRate * count;
        } else {
          tierMembersRevenue += price * count;
        }
      }
      _tierMembersRevenue = tierMembersRevenue;
      rxMembershipsRevenue.value = tierMembersRevenue;
      recalculated = true;
    }
    if (recalculated) {
      _updateRevenueStats();
    }
  }

  void _loadRecentVideos() {
    if (channelId.isEmpty) return;

    final videosRef = _firestore
        .collection(FirestoreCollections.videos)
        .where('channelId', isEqualTo: channelId);

    trackSubscription(_videosSubscription = videosRef.snapshots().listen(
      (snapshot) {
        final videos = snapshot.docs
            .map(Video.fromDocumentSnapshot)
            .where((v) => v.status != VideoStatus.deleted)
            .toList();

        // Sort in memory by most recent upload/creation date descending
        videos.sort((a, b) {
          final dateA = a.uploadedAt.toDate().isAfter(a.createdAt.toDate())
              ? a.uploadedAt.toDate()
              : a.createdAt.toDate();
          final dateB = b.uploadedAt.toDate().isAfter(b.createdAt.toDate())
              ? b.uploadedAt.toDate()
              : b.createdAt.toDate();
          return dateB.compareTo(dateA);
        });

        // If channel query returned no videos, check if creator videos exist by ownerId
        if (videos.isEmpty) {
          final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
          final ownerId = currentChannel.value?.ownerId.isNotEmpty == true
              ? currentChannel.value!.ownerId
              : currentUid;
          if (ownerId.isNotEmpty && ownerId != channelId) {
            _checkOwnerVideosFallback(ownerId);
            return;
          }
        }

        _applyRecentVideos(videos);
      },
      onError: (error, stackTrace) {
        ErrorHandler.log(
          error,
          stackTrace: stackTrace,
          tag: 'DashboardController._loadRecentVideos',
        );
        // Fallback to VideoManagementController if available
        if (Get.isRegistered<VideoManagementController>()) {
          final vmVideos = Get.find<VideoManagementController>().channelVideos;
          if (vmVideos.isNotEmpty) {
            _applyRecentVideos(vmVideos.toList());
            return;
          }
        }
        rxErrorMessage.value = 'Failed to load recent videos.';
      },
    ));
  }

  void _checkOwnerVideosFallback(String ownerId) {
    _ownerVideosSubscription?.cancel();
    final ownerRef = _firestore
        .collection(FirestoreCollections.videos)
        .where('ownerId', isEqualTo: ownerId);
    trackSubscription(_ownerVideosSubscription = ownerRef.snapshots().listen(
      (snapshot) {
        if (recentVideos.isNotEmpty && snapshot.docs.isEmpty) return;
        final ownerVideos = snapshot.docs
            .map(Video.fromDocumentSnapshot)
            .where((v) => v.status != VideoStatus.deleted)
            .toList();
        if (ownerVideos.isNotEmpty) {
          ownerVideos.sort((a, b) {
            final dateA = a.uploadedAt.toDate().isAfter(a.createdAt.toDate())
                ? a.uploadedAt.toDate()
                : a.createdAt.toDate();
            final dateB = b.uploadedAt.toDate().isAfter(b.createdAt.toDate())
                ? b.uploadedAt.toDate()
                : b.createdAt.toDate();
            return dateB.compareTo(dateA);
          });
          _applyRecentVideos(ownerVideos);
        }
      },
      onError: (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'DashboardController._checkOwnerVideosFallback',
        );
      },
    ));
  }

  @visibleForTesting
  void applyRecentVideosForTest(List<Video> videos) => _applyRecentVideos(videos);

  void _applyRecentVideos(List<Video> videos) {
    // 1. Resolve and heal watch time from baseline or distributed shards on all videos
    final healedVideos = <Video>[];
    for (final v in videos) {
      var w = v.totalWatchTimeSeconds;
      if (w <= 0 && v.viewCount > 0 && v.durationSeconds > 0) {
        final healed = math.min(
          v.viewCount * v.durationSeconds,
          (v.viewCount * v.durationSeconds * 0.75).round(),
        );
        if (healed > 0) {
          w = healed;
          if (Get.isRegistered<DistributedCounterService>()) {
            DistributedCounterService.to.healParentVideoWatchTime(v.id, healed);
          }
        }
      }
      healedVideos.add(v.copyWith(totalWatchTimeSeconds: w));
    }

    recentVideos.value = healedVideos.take(20).toList();

    // Auto-heal channel videoCount if Firestore doc had stale count
    if (healedVideos.isNotEmpty && currentChannel.value != null) {
      final ch = currentChannel.value!;
      if (ch.videoCount != healedVideos.length) {
        currentChannel.value = ch.copyWith(videoCount: healedVideos.length);
        if (channelId.isNotEmpty) {
          _firestore
              .collection(FirestoreCollections.channels)
              .doc(channelId)
              .update({'videoCount': healedVideos.length})
              .catchError((_) {});
        }
      }
    }

    // 2. Reconcile total views across all videos and channel doc
    final totalVideoViews = healedVideos.fold<int>(
      0,
      (acc, v) => acc + v.viewCount,
    );
    final rawDocViews = currentChannel.value?.viewCount ?? 0;
    final effectiveViews = healedVideos.isNotEmpty
        ? totalVideoViews
        : rawDocViews;

    // 3. Reconcile total watch time across all videos
    final totalVideoWatchSeconds = healedVideos.fold<int>(
      0,
      (acc, v) => acc + v.totalWatchTimeSeconds,
    );
    final effectiveWatchSec = healedVideos.isNotEmpty && totalVideoWatchSeconds > 0
        ? totalVideoWatchSeconds
        : math.max(totalWatchTimeSeconds.value, totalVideoWatchSeconds);
    if (effectiveWatchSec > 0 || totalWatchTimeSeconds.value == 0) {
      totalWatchTimeSeconds.value = effectiveWatchSec;
    }

    // Synchronize in-memory channel metrics so currentChannel is always consistent
    if (currentChannel.value != null) {
      final ch = currentChannel.value!;
      currentChannel.value = ch.copyWith(
        videoCount: healedVideos.length,
        metrics: ch.metrics.copyWith(
          totalViews: effectiveViews,
          totalWatchTimeMinutes: effectiveWatchSec ~/ 60,
        ),
      );
    }

    channelStats.value = {
      ...channelStats,
      'views': _formatNumber(effectiveViews),
      'watchTime': formattedWatchTime,
      'videos': (currentChannel.value?.videoCount ?? 0) > 0
          ? (currentChannel.value?.videoCount ?? 0)
          : healedVideos.length,
    };

    // Heal shard watch time on parent channel if needed
    if (channelId.isNotEmpty && totalWatchTimeSeconds.value > 0 && Get.isRegistered<DistributedCounterService>()) {
      DistributedCounterService.to.healParentChannelWatchTime(channelId, totalWatchTimeSeconds.value);
    }

    // Check distributed counter shards for real-time channel updates asynchronously
    if (channelId.isNotEmpty && Get.isRegistered<DistributedCounterService>()) {
      DistributedCounterService.to.getRealtimeChannelWatchTime(channelId).then((val) {
        if (healedVideos.isEmpty && val > totalWatchTimeSeconds.value && !isClosed) {
          totalWatchTimeSeconds.value = val;
          channelStats.value = {
            ...channelStats,
            'watchTime': formattedWatchTime,
          };
          checkAndActivateMonetization();
        }
      });
      DistributedCounterService.to.getRealtimeChannelViews(channelId).then((val) {
        if (healedVideos.isEmpty) {
          final currentV = int.tryParse(
            (channelStats['views'] ?? '0').toString().replaceAll(RegExp('[^0-9]'), ''),
          ) ?? 0;
          if (val > currentV && !isClosed) {
            channelStats.value = {
              ...channelStats,
              'views': _formatNumber(val),
            };
          }
        }
      });
    }

    checkAndActivateMonetization();
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
            final doc = snapshot.docs.firstWhereOrNull(
              (d) => d.id == dateString,
            );
            data.add(AnalyticsData(date, (doc?.data()['views'] as num?)?.toInt() ?? 0));
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
      onError: (error, stackTrace) {
        ErrorHandler.log(
          error,
          stackTrace: stackTrace,
          tag: 'DashboardController._loadAnalyticsData',
        );
        rxErrorMessage.value = 'Failed to load analytics data.';
      },
    ));
  }

  void _loadCopyrightStatus() {
    if (channelId.isEmpty) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final claimsQuery = (uid != null && uid.isNotEmpty)
        ? _firestore
            .collection('copyright_claims')
            .where('uploaderId', isEqualTo: uid)
        : _firestore
            .collection('copyright_claims')
            .where('channelId', isEqualTo: channelId);

    _copyrightSubscription = claimsQuery.snapshots().listen(
      (snapshot) {
        final relevantClaims = (uid != null && uid.isNotEmpty)
            ? snapshot.docs.where((doc) {
                final data = doc.data();
                final docChannelId = data['channelId'] as String?;
                return docChannelId == null ||
                    docChannelId.isEmpty ||
                    docChannelId == channelId;
              }).toList()
            : snapshot.docs;
        copyrightClaimsCount.value = relevantClaims.length;
      },
      onError: (e, stackTrace) => ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'DashboardController._loadCopyrightStatus',
      ),
    );
  }

  String _formatNumber(int number) {
    return FormatUtils.formatCount(number);
  }

  void setSelectedIndex(int index) => selectedIndex.value = index;
  void toggleDrawer() => isDrawerExpanded.value = !isDrawerExpanded.value;
  void setSearchQuery(String query) => searchQuery.value = query;
  void retryLoad() => _initializeData();

  Future<void> dismissApprovalBanner() async {
    showApprovalBanner.value = false;
    final targetId =
        channelId.isNotEmpty ? channelId : (currentChannel.value?.id ?? '');
    if (targetId.isNotEmpty) {
      GetStorage().write('approval_shown_$targetId', true);
      try {
        await _firestore
            .collection(FirestoreCollections.channels)
            .doc(targetId)
            .update({
          'brandingApprovedDismissed': true,
          'approvalBannerDismissed': true,
        });
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'DashboardController.dismissApprovalBanner',
        );
      }
    }
  }
}
