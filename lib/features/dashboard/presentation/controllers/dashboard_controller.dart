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
import 'package:truthworld/features/dashboard/presentation/controllers/audience_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audio_tracks/audio_tracks_playback_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/multi_audio_player_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification_dashboard_page.dart';
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
  final RxString targetVideoId = ''.obs;
  RxBool isDrawerExpanded = true.obs;

  /// Tracks the last route key (tab + videoId) for which applyRouteTargetIfPresent
  /// has already been applied, preventing repeated mutations on every Obx rebuild.
  String _appliedRouteKey = '';
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
  final RxDouble rxPremiumSubsRevenue = 0.0.obs;
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

  /// Target watch hours threshold required for cash withdrawal
  static const double videoWithdrawalWatchHoursThreshold = 30.0;

  /// Checks if a specific video has reached 30 hours watch time and 1,000 views for cash withdrawal
  bool isVideoWithdrawalEligible(Video video) {
    return getVideoWatchHours(video) >= videoWithdrawalWatchHoursThreshold &&
        video.viewCount >= videoWithdrawalViewsThreshold;
  }

  /// Resolves the most authoritative list of channel videos available across in-memory controllers.
  List<Video> get _authoritativeVideos {
    if (recentVideos.isNotEmpty) return recentVideos;
    if (Get.isRegistered<VideoManagementController>()) {
      final vmVideos = Get.find<VideoManagementController>().channelVideos;
      if (vmVideos.isNotEmpty) return vmVideos;
    }
    if (Get.isRegistered<CreatorAnalyticsController>()) {
      final caVideos = Get.find<CreatorAnalyticsController>().channelVideos;
      if (caVideos.isNotEmpty) return caVideos;
    }
    return const [];
  }

  /// Checks if ANY video on the channel has crossed the threshold (1k views & 30 hours watch time)
  bool get hasAnyVideoCrossedThreshold =>
      _authoritativeVideos.any(isVideoWithdrawalEligible);

  /// Returns the first video that crossed 1k views and 30 hours watch time (if any)
  Video? get firstQualifiedVideo =>
      _authoritativeVideos.firstWhereOrNull(isVideoWithdrawalEligible);

  /// Returns the highest performing video so far for tracking monetization progress
  Video? get topPerformingVideo {
    final vids = _authoritativeVideos;
    if (vids.isEmpty) return null;
    return vids.reduce((curr, next) {
      final currScore = curr.viewCount + (curr.totalWatchTimeSeconds / 36);
      final nextScore = next.viewCount + (next.totalWatchTimeSeconds / 36);
      return currScore >= nextScore ? curr : next;
    });
  }

  /// Eagerly loads authoritative videos from local controllers or remote Firestore
  Future<void> ensureVideosLoaded() async {
    if (recentVideos.isNotEmpty) return;

    if (Get.isRegistered<VideoManagementController>()) {
      final vmVideos = Get.find<VideoManagementController>().channelVideos;
      if (vmVideos.isNotEmpty) {
        _applyRecentVideos(vmVideos.toList());
        return;
      }
    }

    if (Get.isRegistered<CreatorAnalyticsController>()) {
      final caVideos = Get.find<CreatorAnalyticsController>().channelVideos;
      if (caVideos.isNotEmpty) {
        _applyRecentVideos(caVideos.toList());
        return;
      }
    }

    final effectiveChannelId = channelId.isNotEmpty
        ? channelId
        : (currentChannel.value?.id ?? '');
    if (effectiveChannelId.isEmpty) return;

    try {
      var snap = await _firestore
          .collection(FirestoreCollections.videos)
          .where('channelId', isEqualTo: effectiveChannelId)
          .get();
      var docs = snap.docs;
      if (docs.isEmpty) {
        final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
        final ownerId = currentChannel.value?.ownerId.isNotEmpty == true
            ? currentChannel.value!.ownerId
            : currentUid;
        if (ownerId.isNotEmpty && ownerId != effectiveChannelId) {
          snap = await _firestore
              .collection(FirestoreCollections.videos)
              .where('ownerId', isEqualTo: ownerId)
              .get();
          docs = snap.docs;
        }
      }

      final videos = docs
          .map(Video.fromDocumentSnapshot)
          .where((v) => v.status != VideoStatus.deleted)
          .toList();

      if (videos.isNotEmpty) {
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
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'DashboardController.ensureVideosLoaded',
      );
    }
  }

  /// Checks if any video meets the 1k views and 30h threshold, querying Firestore if in-memory list is empty
  Future<bool> checkVideoMonetizationThreshold() async {
    if (hasAnyVideoCrossedThreshold) return true;
    final effectiveChannelId = channelId.isNotEmpty
        ? channelId
        : (currentChannel.value?.id ?? '');
    if (effectiveChannelId.isEmpty) return false;

    // Check loaded videos or populate from channel query first
    if (recentVideos.isEmpty) {
      await ensureVideosLoaded();
      if (hasAnyVideoCrossedThreshold) return true;
    }

    try {
      final snap = await _firestore
          .collection(FirestoreCollections.videos)
          .where('channelId', isEqualTo: effectiveChannelId)
          .where('viewCount', isGreaterThanOrEqualTo: videoWithdrawalViewsThreshold)
          .limit(20)
          .get();

      for (final doc in snap.docs) {
        final v = Video.fromDocumentSnapshot(doc);
        if (isVideoWithdrawalEligible(v)) {
          if (!recentVideos.any((rv) => rv.id == v.id)) {
            recentVideos.add(v);
          }
          return true;
        }
      }
    } on FirebaseException catch (e, stackTrace) {
      // If composite index is building or not yet deployed, fallback to single-field index
      if (e.code == 'failed-precondition') {
        try {
          final fallbackSnap = await _firestore
              .collection(FirestoreCollections.videos)
              .where('channelId', isEqualTo: effectiveChannelId)
              .limit(100)
              .get();
          for (final doc in fallbackSnap.docs) {
            final v = Video.fromDocumentSnapshot(doc);
            if (v.status != VideoStatus.deleted && isVideoWithdrawalEligible(v)) {
              if (!recentVideos.any((rv) => rv.id == v.id)) {
                recentVideos.add(v);
              }
              return true;
            }
          }
        } catch (innerError, innerStack) {
          ErrorHandler.log(
            innerError,
            stackTrace: innerStack,
            tag: 'DashboardController.checkVideoMonetizationThreshold.fallback',
          );
        }
      } else {
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'DashboardController.checkVideoMonetizationThreshold',
        );
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'DashboardController.checkVideoMonetizationThreshold',
      );
    }
    return false;
  }

  /// Count of videos that crossed the 1,000 views and 30 hours watch time threshold
  int get qualifiedVideoCount =>
      _authoritativeVideos.where(isVideoWithdrawalEligible).length;

  /// Count of videos that have not yet crossed the 1,000 views and 30 hours watch time threshold
  int get pendingVideoCount =>
      _authoritativeVideos.where((v) => !isVideoWithdrawalEligible(v)).length;

  /// Evaluates whether creator KYC verification is completed
  bool get isCreatorKycVerified {
    if (Get.isRegistered<RevenueAnalyticsController>()) {
      return Get.find<RevenueAnalyticsController>().isKycVerified;
    }
    return currentChannel.value?.isVerified ?? false;
  }

  /// Evaluates if the channel's monetization is ON:
  /// Monetization turns ON when approved by an administrator after verifying details,
  /// or when operating on Custom Channel Tier.
  bool isChannelMonetizationOn({bool? isKycVerified, bool? isAdminApproved}) {
    final ch = currentChannel.value;
    if (ch != null) {
      if (ch.channelType == ChannelType.custom) return true;
      if (ch.monetizationTier != MonetizationTier.none) return true;
      if (ch.isMonetized) return true;
      if (ch.monetizationSettings?['isMonetized'] == true) return true;
      if (ch.monetizationStatus == 'approved') return true;
      if (ch.isMonetizationUnderReview) return false;
    }
    final kyc = isKycVerified ?? isCreatorKycVerified;
    if (isAdminApproved != null) {
      return hasAnyVideoCrossedThreshold && kyc && isAdminApproved;
    }
    return hasAnyVideoCrossedThreshold && kyc;
  }

  /// Reactive getter indicating if monetization is currently active on the channel
  bool get isChannelMonetizationActive => isChannelMonetizationOn();

  /// Whether monetization is actively enabled on this channel
  bool get isChannelMonetized => isChannelMonetizationActive;

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
    applyRouteTargetIfPresent();
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
    if (_channelId.isEmpty && Get.isRegistered<AuthService>()) {
      final authCh = AuthService.to.userChannel ?? AuthService.to.rxUserChannel.value;
      if (authCh != null && authCh.id.isNotEmpty) {
        _channelId = authCh.id;
        currentChannel.value = authCh;
      }
    }
    if (currentChannel.value != null) {
      _seedInitialChannelStats(currentChannel.value!);
    }
    if (Get.isRegistered<CurrencyLocalizationService>()) {
      _rateWorker = ever(CurrencyLocalizationService.to.liveUsdToInrRate, (_) {
        _recalculateMembershipsWithRate();
      });
    }

    if (Get.isRegistered<AuthService>()) {
      trackWorker(
        ever(AuthService.to.rxUserChannel, (ch) {
          if (ch != null) {
            final isFirstInit = _channelId.isEmpty;
            if (_channelId.isEmpty || _channelId == ch.id) {
              _channelId = ch.id;
              currentChannel.value = ch;
              _seedInitialChannelStats(ch);
              if (isFirstInit && autoInitialize) {
                _initializeData();
              }
            }
          }
        }),
      );
    }

    // Guard: Automatically return to home if current channel is not monetized but on memberships tab
    trackWorker(
      ever(currentChannel, (_) {
        if (selectedIndex.value == 18 && !isChannelMonetizationActive) {
          selectedIndex.value = 1;
        }
      }),
    );

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
    rxPremiumSubsRevenue.value = 0.0;
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

  /// Seeds initial channel stats synchronously on frame 0 to eliminate studio cold-start lag.
  void _seedInitialChannelStats(Channel ch) {
    currentChannel.value = ch;
    if (_channelId.isEmpty) {
      _channelId = ch.id;
    }

    final rawWatch = ch.metrics.totalWatchTimeMinutes * 60;
    if (rawWatch > totalWatchTimeSeconds.value) {
      totalWatchTimeSeconds.value = rawWatch;
    }

    final rawViews = ch.metrics.totalViews > 0 ? ch.metrics.totalViews : ch.viewCount;
    final currentViews = int.tryParse(
      (channelStats['views'] ?? '0').toString().replaceAll(RegExp('[^0-9]'), ''),
    ) ?? 0;
    final effectiveViews = math.max(currentViews, rawViews);

    final currentSubs = int.tryParse(
      (channelStats['subscribers'] ?? '0').toString().replaceAll(RegExp('[^0-9]'), ''),
    ) ?? 0;
    final effectiveSubs = math.max(currentSubs, ch.subscriberCount);

    channelStats.value = {
      ...channelStats,
      if (effectiveViews > 0 || channelStats['views'] == null)
        'views': _formatNumber(effectiveViews),
      'subscribers': _formatNumber(effectiveSubs),
      'rawSubscribers': effectiveSubs,
      'watchTime': formattedWatchTime,
      'revenue': channelStats['revenue'] ?? '₹0.00',
      'viewsChange': channelStats['viewsChange'] ?? '+0%',
      'watchTimeChange': channelStats['watchTimeChange'] ?? '+0%',
      'subscribersChange': channelStats['subscribersChange'] ?? '+0',
      'revenueChange': channelStats['revenueChange'] ?? '+₹0.00',
    };
  }

  void updateChannelId(String id) {
    if (id.isEmpty) {
      clearData();
      return;
    }
    final isNew = id != _channelId;
    _channelId = id;
    if (autoInitialize && (isNew || channelStats.isEmpty || recentVideos.isEmpty)) {
      _initializeData();
    }
  }

  /// Reload all channel stats, recent videos, analytics, and revenue data
  void refreshChannelData() {
    if (Get.isRegistered<AuthService>() && AuthService.to.userChannel != null) {
      final authCh = AuthService.to.userChannel!;
      if (_channelId.isEmpty || _channelId != authCh.id) {
        _channelId = authCh.id;
      }
      currentChannel.value = authCh;
    }
    _initializeData();
  }

  /// Sync real-time metrics computed by CreatorAnalyticsController into Studio Dashboard
  void syncMetricsFromAnalytics({
    required int views,
    required int watchTimeSeconds,
    int? subscribers,
    Map<DateTime, int>? dailyViews,
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

    if (subscribers != null && subscribers > 0) {
      final currentSubs = (channelStats['rawSubscribers'] as int?) ??
          int.tryParse((channelStats['subscribers'] ?? '0').toString().replaceAll(RegExp('[^0-9]'), '')) ??
          0;
      if (subscribers > currentSubs) {
        channelStats['subscribers'] = _formatNumber(subscribers);
        channelStats['rawSubscribers'] = subscribers;
        updated = true;
        if (channelId.isNotEmpty) {
          _firestore
              .collection(FirestoreCollections.channels)
              .doc(channelId)
              .update({'subscriberCount': subscribers})
              .catchError((_) {});
        }
      }
    }

    if (dailyViews != null && dailyViews.isNotEmpty) {
      final sortedKeys = dailyViews.keys.toList()..sort();
      final points = sortedKeys
          .map((d) => AnalyticsData(d, dailyViews[d] ?? 0))
          .toList();
      if (points.isNotEmpty && points.any((p) => p.views > 0)) {
        analyticsData.value = points;
      }
    }

    if (updated) {
      channelStats.refresh();
      checkAndActivateMonetization();
    }
  }

  /// Reconciles channel subscriber count across authoritative sources:
  /// analytics controllers, distributed counter shards, subscriptions count queries, and daily stats history.
  Future<int> _reconcileSubscriberCount(String targetChannelId, int baseCount) async {
    if (targetChannelId.isEmpty) return baseCount;
    var resolvedCount = baseCount;

    // 1. Sync from CreatorAnalyticsController if active
    if (Get.isRegistered<CreatorAnalyticsController>()) {
      final ca = Get.find<CreatorAnalyticsController>();
      final caGained = ca.channelAnalytics.value?.subscribersGained ?? 0;
      if (caGained > resolvedCount) {
        resolvedCount = caGained;
      }
    }

    // 2. Sync from AudienceController if active
    if (Get.isRegistered<AudienceController>()) {
      final aud = Get.find<AudienceController>();
      final audGained = aud.totalSubscribersGained.value;
      if (audGained > resolvedCount) {
        resolvedCount = audGained;
      }
    }

    // 3. Check real-time shard deltas
    if (Get.isRegistered<DistributedCounterService>()) {
      try {
        final shardDelta = await DistributedCounterService.to
            .getRealtimeChannelSubscriberDelta(targetChannelId);
        if (shardDelta > 0 && shardDelta > resolvedCount) {
          resolvedCount = math.max(resolvedCount, shardDelta);
        }
      } catch (_) {}
    }

    // 4. Query authoritative Firestore count aggregations
    try {
      final subSnap = await _firestore
          .collection(FirestoreCollections.subscriptions)
          .where('channelId', isEqualTo: targetChannelId)
          .count()
          .get();
      final rootSubCount = subSnap.count ?? 0;
      if (rootSubCount > resolvedCount) {
        resolvedCount = rootSubCount;
      }
    } catch (_) {}

    try {
      final chSubSnap = await _firestore
          .collection(FirestoreCollections.channelSubscribers(targetChannelId))
          .count()
          .get();
      final chSubCount = chSubSnap.count ?? 0;
      if (chSubCount > resolvedCount) {
        resolvedCount = chSubCount;
      }
    } catch (_) {}

    // 5. Query channel_stats_daily if count is still 0
    if (resolvedCount <= 0) {
      try {
        final dailySnap = await _firestore
            .collection('channel_stats_daily')
            .where('channelId', isEqualTo: targetChannelId)
            .get();
        var dailyGainedTotal = 0;
        for (final doc in dailySnap.docs) {
          final g = (doc.data()['subscribersGained'] as num?)?.toInt() ?? 0;
          dailyGainedTotal += g;
        }
        if (dailyGainedTotal > resolvedCount) {
          resolvedCount = dailyGainedTotal;
        }
      } catch (_) {}
    }

    // 6. Auto-heal Firestore channel document if authoritative count exceeds stale doc value
    if (resolvedCount > baseCount) {
      try {
        _firestore
            .collection(FirestoreCollections.channels)
            .doc(targetChannelId)
            .update({'subscriberCount': resolvedCount})
            .catchError((_) {});
      } catch (_) {}
    }

    return resolvedCount;
  }

  /// Asynchronously hydrates all channel metrics, videos, subscriber count, and analytics concurrently
  /// in parallel with the live stream listeners to provide instant sub-second render.
  Future<void> _hydrateInitialData() async {
    final currentChId = channelId.isNotEmpty ? channelId : (currentChannel.value?.id ?? '');
    if (currentChId.isEmpty) {
      rxIsLoading.value = false;
      return;
    }

    try {
      final channelFuture = _firestore
          .collection(FirestoreCollections.channels)
          .doc(currentChId)
          .get()
          .then<DocumentSnapshot<Map<String, dynamic>>?>((d) => d)
          .catchError((_) => null);

      final videosFuture = _firestore
          .collection(FirestoreCollections.videos)
          .where('channelId', isEqualTo: currentChId)
          .get()
          .then<QuerySnapshot<Map<String, dynamic>>?>((s) => s)
          .catchError((_) => null);

      final shardWatchFuture = Get.isRegistered<DistributedCounterService>()
          ? DistributedCounterService.to
              .getRealtimeChannelWatchTime(currentChId)
              .catchError((_) => 0)
          : Future<int>.value(0);

      final shardSubsFuture = Get.isRegistered<DistributedCounterService>()
          ? DistributedCounterService.to
              .getRealtimeChannelSubscriberDelta(currentChId)
              .catchError((_) => 0)
          : Future<int>.value(0);

      final subsCountFuture = _firestore
          .collection(FirestoreCollections.subscriptions)
          .where('channelId', isEqualTo: currentChId)
          .count()
          .get()
          .then<int>((s) => s.count ?? 0)
          .catchError((_) => 0);

      final results = await Future.wait<dynamic>([
        channelFuture,
        videosFuture,
        shardWatchFuture,
        shardSubsFuture,
        subsCountFuture,
      ]);

      if (isClosed) return;

      final chDoc = results[0] as DocumentSnapshot<Map<String, dynamic>>?;
      final vSnap = results[1] as QuerySnapshot<Map<String, dynamic>>?;
      final shardWatch = (results[2] as int?) ?? 0;
      final shardSubs = (results[3] as int?) ?? 0;
      final subsCount = (results[4] as int?) ?? 0;

      // Apply channel document
      if (chDoc != null && chDoc.exists) {
        final ch = Channel.fromDocumentSnapshot(chDoc);
        currentChannel.value = ch;
        if (channelStats.isEmpty) {
          _seedInitialChannelStats(ch);
        }
      }

      // Apply videos
      if (vSnap != null && vSnap.docs.isNotEmpty) {
        final videos = vSnap.docs
            .map(Video.fromDocumentSnapshot)
            .where((v) => v.status != VideoStatus.deleted)
            .toList();
        if (videos.isNotEmpty) {
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
      } else if (recentVideos.isEmpty) {
        final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
        final ownerId = currentChannel.value?.ownerId.isNotEmpty == true
            ? currentChannel.value!.ownerId
            : currentUid;
        if (ownerId.isNotEmpty && ownerId != currentChId) {
          final ownerSnap = await _firestore
              .collection(FirestoreCollections.videos)
              .where('ownerId', isEqualTo: ownerId)
              .get()
              .then<QuerySnapshot<Map<String, dynamic>>?>((s) => s)
              .catchError((_) => null);
          if (ownerSnap != null && ownerSnap.docs.isNotEmpty) {
            final ownerVideos = ownerSnap.docs
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
          }
        }
      }

      // Reconcile watch time
      if (recentVideos.isEmpty && shardWatch > totalWatchTimeSeconds.value) {
        totalWatchTimeSeconds.value = shardWatch;
        channelStats['watchTime'] = formattedWatchTime;
      }

      // Reconcile subscribers
      final docSubs = currentChannel.value?.subscriberCount ?? 0;
      final reconciledSubs = await _reconcileSubscriberCount(
        currentChId,
        math.max(docSubs, math.max(shardSubs, subsCount)),
      );
      if (reconciledSubs > 0 || (channelStats['rawSubscribers'] as int? ?? 0) == 0) {
        channelStats['subscribers'] = _formatNumber(reconciledSubs);
        channelStats['rawSubscribers'] = reconciledSubs;
      }

      channelStats.refresh();
      checkAndActivateMonetization();
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'DashboardController._hydrateInitialData',
      );
    } finally {
      if (!isClosed) {
        rxIsLoading.value = false;
      }
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

      final shardSubsFuture = (channelId.isNotEmpty &&
              Get.isRegistered<DistributedCounterService>())
          ? DistributedCounterService.to
              .getRealtimeChannelSubscriberDelta(channelId)
              .catchError((_) => 0)
          : Future<int>.value(0);

      final subsCountFuture = channelId.isNotEmpty
          ? _firestore
              .collection(FirestoreCollections.subscriptions)
              .where('channelId', isEqualTo: channelId)
              .count()
              .get()
              .then<int>((s) => s.count ?? 0)
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
        shardSubsFuture,
        subsCountFuture,
        analyticsFuture,
      ]);

      final channelDoc = results[0] as DocumentSnapshot<Map<String, dynamic>>?;
      final vSnapshot = results[1] as QuerySnapshot<Map<String, dynamic>>?;
      final shardWatch = (results[2] as int?) ?? 0;
      final shardViews = (results[3] as int?) ?? 0;
      final shardSubs = (results[4] as int?) ?? 0;
      final subsCount = (results[5] as int?) ?? 0;

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

      // Reconcile subscribers
      final docSubs = currentChannel.value?.subscriberCount ?? 0;
      final reconciledSubs = await _reconcileSubscriberCount(
        channelId,
        math.max(docSubs, math.max(shardSubs, subsCount)),
      );
      if (reconciledSubs > 0 || (channelStats['rawSubscribers'] as int? ?? 0) == 0) {
        channelStats['subscribers'] = _formatNumber(reconciledSubs);
        channelStats['rawSubscribers'] = reconciledSubs;
      }

      channelStats.refresh();

      // Trigger background server-side reconciliation if authenticated
      if (channelId.isNotEmpty && FirebaseAuth.instance.currentUser != null) {
        try {
          FirebaseFunctions.instanceFor(region: 'asia-south1')
              .httpsCallable('reconcileChannelMetrics')
              .call({'channelId': channelId})
              .ignore();
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

    // Do NOT wipe out existing channelStats or recentVideos if we are re-initializing for the same channel,
    // avoiding visual flicker and zero-metric flash.
    if (currentChannel.value != null && channelStats.isEmpty) {
      _seedInitialChannelStats(currentChannel.value!);
    }

    // Eagerly seed recentVideos from available controllers
    if (recentVideos.isEmpty) {
      if (Get.isRegistered<VideoManagementController>() &&
          Get.find<VideoManagementController>().channelVideos.isNotEmpty) {
        _applyRecentVideos(Get.find<VideoManagementController>().channelVideos.toList());
      } else if (Get.isRegistered<CreatorAnalyticsController>() &&
          Get.find<CreatorAnalyticsController>().channelVideos.isNotEmpty) {
        _applyRecentVideos(Get.find<CreatorAnalyticsController>().channelVideos.toList());
      }
    }

    if (channelStats.isEmpty) {
      rxIsLoading.value = true;
    }

    try {
      _loadChannelStats();
      _loadRecentVideos();
      _loadAnalyticsData();
      _loadCopyrightStatus();
      unawaited(_hydrateInitialData());
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'DashboardController._initializeData',
      );
    }
    // Use managed Timer to set loading to false after a short period,
    // allowing streams and hydration to populate data.
    _loadingTimeoutTimer = trackTimer(Timer(const Duration(seconds: 1), () {
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
              rxPremiumSubsRevenue.value = premiumSubs;
              _updateRevenueStats();
            }

            final channel = Channel.fromDocumentSnapshot(snapshot);
            currentChannel.value = channel;
            if (Get.isRegistered<AuthService>() &&
                AuthService.to.userChannel?.id == channel.id) {
              AuthService.to.setUserChannel(channel);
            }

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

            final currentSubsCount = (channelStats['rawSubscribers'] as int?) ??
                channel.subscriberCount;
            final resolvedDocSubs = (data?['subscriberCount'] as num?)?.toInt() ??
                (data?['subscribers'] as num?)?.toInt() ??
                channel.subscriberCount;
            final effectiveSubs = math.max(currentSubsCount, resolvedDocSubs);

            channelStats.value = {
              ...channelStats,
              if (effectiveViews > 0) 'views': _formatNumber(effectiveViews),
              'subscribers': _formatNumber(effectiveSubs),
              'rawSubscribers': effectiveSubs,
              'watchTime': formattedWatchTime,
              'revenue': formattedRev,
              'viewsChange': channelStats['viewsChange'] ?? '+0%',
              'watchTimeChange': channelStats['watchTimeChange'] ?? '+0%',
              'subscribersChange': channelStats['subscribersChange'] ?? '+0',
              'revenueChange': formattedChange,
            };

            if (channelId.isNotEmpty) {
              _reconcileSubscriberCount(channelId, effectiveSubs).then((reconciled) {
                if (reconciled > effectiveSubs && !isClosed) {
                  channelStats.value = {
                    ...channelStats,
                    'subscribers': _formatNumber(reconciled),
                    'rawSubscribers': reconciled,
                  };
                }
              }).ignore();
            }
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

          final currentSubsCount = (channelStats['rawSubscribers'] as int?) ??
              currentChannel.value?.subscriberCount ??
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
        rxPremiumSubsRevenue.value = revCtrl.premiumSubsRevenue.value;
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
            if (premiumSubs > 0 && rxPremiumSubsRevenue.value == 0.0) {
              rxPremiumSubsRevenue.value = premiumSubs;
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
        rxPremiumSubsRevenue.value;
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

    // Eagerly populate from available controllers if recentVideos is empty
    if (recentVideos.isEmpty) {
      if (Get.isRegistered<VideoManagementController>()) {
        final vmVideos = Get.find<VideoManagementController>().channelVideos;
        if (vmVideos.isNotEmpty) {
          _applyRecentVideos(vmVideos.toList());
        }
      } else if (Get.isRegistered<CreatorAnalyticsController>()) {
        final caVideos = Get.find<CreatorAnalyticsController>().channelVideos;
        if (caVideos.isNotEmpty) {
          _applyRecentVideos(caVideos.toList());
        }
      }
    }

    final videosRef = _firestore
        .collection(FirestoreCollections.videos)
        .where('channelId', isEqualTo: channelId);

    trackSubscription(_videosSubscription = videosRef.snapshots().listen(
      (snapshot) {
        final videos = snapshot.docs
            .map(Video.fromDocumentSnapshot)
            .where((v) => v.status != VideoStatus.deleted)
            .toList();

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
          if (recentVideos.isEmpty) {
            if (Get.isRegistered<VideoManagementController>()) {
              final vmVideos = Get.find<VideoManagementController>().channelVideos;
              if (vmVideos.isNotEmpty) {
                _applyRecentVideos(vmVideos.toList());
                return;
              }
            }
            if (Get.isRegistered<CreatorAnalyticsController>()) {
              final caVideos = Get.find<CreatorAnalyticsController>().channelVideos;
              if (caVideos.isNotEmpty) {
                _applyRecentVideos(caVideos.toList());
                return;
              }
            }
          }
        }

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

        _applyRecentVideos(videos);
      },
      onError: (error, stackTrace) {
        ErrorHandler.log(
          error,
          stackTrace: stackTrace,
          tag: 'DashboardController._loadRecentVideos',
        );
        // Fallback to VideoManagementController if available
        if (recentVideos.isEmpty) {
          if (Get.isRegistered<VideoManagementController>()) {
            final vmVideos = Get.find<VideoManagementController>().channelVideos;
            if (vmVideos.isNotEmpty) {
              _applyRecentVideos(vmVideos.toList());
              return;
            }
          }
          if (Get.isRegistered<CreatorAnalyticsController>()) {
            final caVideos = Get.find<CreatorAnalyticsController>().channelVideos;
            if (caVideos.isNotEmpty) {
              _applyRecentVideos(caVideos.toList());
              return;
            }
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
    // 1. Preserve authentic watch time from video records without synthetic multipliers
    final healedVideos = <Video>[...videos];

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

    // 1. Eagerly seed from CreatorAnalyticsController if active
    if (Get.isRegistered<CreatorAnalyticsController>()) {
      final ca = Get.find<CreatorAnalyticsController>();
      final caDaily = ca.channelAnalytics.value?.dailyViews;
      if (caDaily != null && caDaily.isNotEmpty) {
        final sortedKeys = caDaily.keys.toList()..sort();
        analyticsData.value = sortedKeys
            .map((d) => AnalyticsData(d, caDaily[d] ?? 0))
            .toList();
      }
    }

    // 2. Ensure baseline 28 points so UI never flashes "No analytics data yet"
    if (analyticsData.isEmpty) {
      final curViews = int.tryParse(
        (channelStats['views'] ?? currentChannel.value?.metrics.totalViews ?? '0')
            .toString()
            .replaceAll(RegExp('[^0-9]'), ''),
      ) ?? 0;
      analyticsData.value = List.generate(28, (i) {
        final d = startDate.add(Duration(days: i));
        // Allocate views on latest date if available so chart shows current activity
        final v = (i == 27 && curViews > 0) ? curViews : 0;
        return AnalyticsData(DateTime(d.year, d.month, d.day), v);
      });
    }

    if (channelId.isEmpty) return;

    _analyticsSubscription?.cancel();
    final query = _firestore
        .collection('channel_stats_daily')
        .where('channelId', isEqualTo: channelId);

    trackSubscription(_analyticsSubscription = query.snapshots().listen(
      (snapshot) {
        if (snapshot.docs.isNotEmpty) {
          final viewsByDate = <String, int>{};
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final rawKey = (data['dateKey'] as String?) ?? doc.id;
            final views = (data['totalViews'] as num?)?.toInt() ??
                (data['views'] as num?)?.toInt() ?? 0;
            final normalizedKey = rawKey.replaceAll('_', '-');
            viewsByDate[normalizedKey] = (viewsByDate[normalizedKey] ?? 0) + views;
          }

          final data = <AnalyticsData>[];
          var totalAggregatedViews = 0;
          for (var i = 0; i < 28; i++) {
            final date = startDate.add(Duration(days: i));
            final dateKeyDash = DateFormat('yyyy-MM-dd').format(date);
            final dateKeyUnderscore = DateFormat('yyyy_MM_dd').format(date);
            final views = viewsByDate[dateKeyDash] ?? viewsByDate[dateKeyUnderscore] ?? 0;
            totalAggregatedViews += views;
            data.add(AnalyticsData(DateTime(date.year, date.month, date.day), views));
          }

          // If channel document has higher total views than aggregated daily documents,
          // reconcile the difference onto the most recent day so the curve reflects reality
          final curViews = int.tryParse(
            (channelStats['views'] ?? currentChannel.value?.metrics.totalViews ?? '0')
                .toString()
                .replaceAll(RegExp('[^0-9]'), ''),
          ) ?? 0;
          if (curViews > totalAggregatedViews && data.isNotEmpty) {
            final diff = curViews - totalAggregatedViews;
            data[data.length - 1] = AnalyticsData(data.last.date, data.last.views + diff);
          }

          analyticsData.value = data;
        } else {
          // If no daily documents exist yet, keep baseline with current views on recent days
          final curViews = int.tryParse(
            (channelStats['views'] ?? currentChannel.value?.metrics.totalViews ?? '0')
                .toString()
                .replaceAll(RegExp('[^0-9]'), ''),
          ) ?? 0;
          analyticsData.value = List.generate(28, (i) {
            final d = startDate.add(Duration(days: i));
            final v = (i == 27 && curViews > 0) ? curViews : 0;
            return AnalyticsData(DateTime(d.year, d.month, d.day), v);
          });
        }
      },
      onError: (error, stackTrace) {
        ErrorHandler.log(
          error,
          stackTrace: stackTrace,
          tag: 'DashboardController._loadAnalyticsData',
        );
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

    trackSubscription(_copyrightSubscription = claimsQuery.snapshots().listen(
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
    ));
  }

  String _formatNumber(int number) {
    return FormatUtils.formatCount(number);
  }

  void setSelectedIndex(int index) {
    if (index == 18 && !isChannelMonetizationActive) {
      // Memberships tab is only available for monetized channels
      return;
    }
    if (selectedIndex.value != index) {
      if (Get.isRegistered<AudioTracksPlaybackController>()) {
        Get.find<AudioTracksPlaybackController>().stop();
      }
      MultiAudioPlayerController.pauseAll();
      selectedIndex.value = index;
    }
  }

  /// Applies incoming route parameters/arguments to select the target studio tab and highlight video.
  void applyRouteTargetIfPresent() {
    final tabArg = Get.arguments is Map ? Get.arguments['tab'] : null;
    final tabParam = Get.parameters['tab'];
    final tab = tabArg ?? tabParam;

    final vidId =
        (Get.arguments is Map ? Get.arguments['videoId'] as String? : null) ??
            Get.parameters['videoId'];

    // Build a key representing the current route target. If we've already
    // processed this exact combination, skip — prevents repeated Rx mutations
    // on every Obx rebuild that would cause "setState() during build" crashes.
    final routeKey = '${tab ?? ''}_${vidId ?? ''}';
    if (routeKey == _appliedRouteKey) return;
    _appliedRouteKey = routeKey;

    if (tab is int && tab >= 1 && tab <= 20) {
      if (tab == 18 && !isChannelMonetizationActive) {
        selectedIndex.value = 1;
      } else {
        selectedIndex.value = tab;
      }
    } else if (tab is String) {
      final tabLower = tab.toLowerCase().trim();
      final parsedInt = int.tryParse(tabLower);
      if (parsedInt != null && parsedInt >= 1 && parsedInt <= 20) {
        if (parsedInt == 18 && !isChannelMonetizationActive) {
          selectedIndex.value = 1;
        } else {
          selectedIndex.value = parsedInt;
        }
      } else {
        switch (tabLower) {
          case 'overview':
          case 'dashboard':
          case 'home':
            selectedIndex.value = 1;
          case 'content':
          case 'videos':
            selectedIndex.value = 2;
          case 'analytics':
          case 'growth':
          case 'stats':
            selectedIndex.value = 3;
          case 'comments':
            selectedIndex.value = 4;
          case 'monetization':
          case 'revenue':
          case 'wallet':
          case 'payout':
            selectedIndex.value = 5;
          case 'customization':
            selectedIndex.value = 6;
          case 'audio_tracks':
          case 'audio':
          case 'dubbing':
            selectedIndex.value = 7;
          case 'settings':
            selectedIndex.value = 8;
          case 'copyright':
          case 'claims':
            selectedIndex.value = 9;
          case 'subtitles':
            selectedIndex.value = 10;
          case 'chapters':
            selectedIndex.value = 11;
          case 'audience':
          case 'subscribers':
            selectedIndex.value = 12;
          case 'trash':
            selectedIndex.value = 13;
          case 'topics':
            selectedIndex.value = 14;
          case 'verification':
          case 'fact_check':
          case 'factcheck':
            selectedIndex.value = 15;
          case 'notifications':
          case 'alerts':
            selectedIndex.value = 16;
          case 'playlists':
            selectedIndex.value = 17;
          case 'memberships':
            if (isChannelMonetizationActive) {
              selectedIndex.value = 18;
            } else {
              selectedIndex.value = 1;
            }
          case 'posts':
          case 'community':
            selectedIndex.value = 19;
          case 'drafts':
            selectedIndex.value = 20;
        }
      }
    }

    // Video ID targeting for Truth Verification, Copyright, or Content tabs
    if (vidId != null && vidId.isNotEmpty) {
      targetVideoId.value = vidId;
      TruthVerificationDashboardPage.targetVideoId.value = vidId;
    }
  }

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
