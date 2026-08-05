import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/features/analytics/data/models/watch_event_model.dart';
import 'package:truthworld/features/analytics/data/services/video_analytics_service.dart';

class StateAudienceItem {
  StateAudienceItem({
    required this.stateCode,
    required this.stateName,
    required this.viewers,
    required this.subscribers,
    required this.viewerPercentage,
    required this.subscriberPercentage,
  });
  final String stateCode;
  final String stateName;
  final int viewers;
  final int subscribers;
  final double viewerPercentage;
  final double subscriberPercentage;
}

class AudienceController extends BaseController {
  AudienceController({required this.channelId});
  final String channelId;
  final VideoAnalyticsService _analyticsService = Get.find();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Search filter
  final RxString searchQuery = ''.obs;

  // Primary metrics snapshots
  final snapshot = Rx<ChannelAnalyticsSnapshot?>(null);
  final RxList<StateAudienceItem> allStateItems = <StateAudienceItem>[].obs;

  // Global scope numbers
  final RxInt totalViews = 0.obs;
  final RxInt totalUniqueViewers = 0.obs;
  final RxInt totalSubscribersGained = 0.obs;
  final RxInt returningViewers = 0.obs;
  final RxDouble subscriberConversionRate = 0.0.obs;
  final RxDouble urbanPercentage = 0.0.obs;
  final RxDouble ruralPercentage = 0.0.obs;

  // Real-time Firestore listeners
  StreamSubscription<QuerySnapshot>? _channelStatsListener;
  StreamSubscription<QuerySnapshot>? _videoStatsListener;

  // Comprehensive Indian states & union territories map — all 36 entries
  // ensures we NEVER show an empty geography list
  static const Map<String, String> _indianStatesMap = {
    'AN': 'Andaman and Nicobar',
    'AP': 'Andhra Pradesh',
    'AR': 'Arunachal Pradesh',
    'AS': 'Assam',
    'BR': 'Bihar',
    'CG': 'Chhattisgarh',
    'CH': 'Chandigarh',
    'DD': 'Daman and Diu',
    'DL': 'Delhi',
    'DN': 'Dadra and Nagar Haveli',
    'GA': 'Goa',
    'GJ': 'Gujarat',
    'HR': 'Haryana',
    'HP': 'Himachal Pradesh',
    'JK': 'Jammu and Kashmir',
    'JH': 'Jharkhand',
    'KA': 'Karnataka',
    'KL': 'Kerala',
    'LA': 'Ladakh',
    'LD': 'Lakshadweep',
    'MH': 'Maharashtra',
    'ML': 'Meghalaya',
    'MN': 'Manipur',
    'MP': 'Madhya Pradesh',
    'MZ': 'Mizoram',
    'NL': 'Nagaland',
    'OD': 'Odisha',
    'PB': 'Punjab',
    'PY': 'Puducherry',
    'RJ': 'Rajasthan',
    'SK': 'Sikkim',
    'TG': 'Telangana',
    'TN': 'Tamil Nadu',
    'TR': 'Tripura',
    'UP': 'Uttar Pradesh',
    'UT': 'Uttarakhand',
    'WB': 'West Bengal',
  };

  @override
  void onInit() {
    super.onInit();
    if (channelId.isNotEmpty) {
      fetchAudienceData();
      _startRealtimeListeners();
    } else {
      setError('No active channel context specified.');
    }
  }

  @override
  void onClose() {
    _channelStatsListener?.cancel();
    _videoStatsListener?.cancel();
    super.onClose();
  }

  // ---------------------------------------------------------------------------
  // REAL-TIME FIRESTORE LISTENERS
  // ---------------------------------------------------------------------------

  /// Attach Firestore snapshot listeners to channel_stats_daily and
  /// video_stats_daily so geography data updates in real time as new
  /// watch events are aggregated by the Cloud Function pipeline.
  void _startRealtimeListeners() {
    logger.info(
      'Starting real-time geography listeners for channel: $channelId',
      tag: 'AudienceController',
    );

    // Listen to channel_stats_daily for this channel (latest 28 days)
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(days: 28));
    final cutoffKey =
        '${cutoff.year}_${cutoff.month.toString().padLeft(2, '0')}_${cutoff.day.toString().padLeft(2, '0')}';

    _channelStatsListener = _firestore
        .collection('channel_stats_daily')
        .where('channelId', isEqualTo: channelId)
        .snapshots()
        .listen(
          (querySnapshot) {
            if (querySnapshot.docs.isNotEmpty) {
              _processRealtimeChannelStats(querySnapshot, cutoffKey);
            }
          },
          onError: (Object error) {
            logger.warning(
              'Channel stats listener error: $error',
              tag: 'AudienceController',
            );
          },
        );

    // Fallback: also listen to video_stats_daily for this channel
    // in case channel_stats_daily hasn't been populated yet
    _videoStatsListener = _firestore
        .collection('video_stats_daily')
        .where('channelId', isEqualTo: channelId)
        .snapshots()
        .listen(
          (querySnapshot) {
            // Only use video stats as fallback if channel stats haven't produced data
            if (allStateItems.isEmpty ||
                allStateItems.every((item) => item.viewers == 0)) {
              if (querySnapshot.docs.isNotEmpty) {
                _processRealtimeVideoStats(querySnapshot, cutoffKey);
              }
            }
          },
          onError: (Object error) {
            logger.warning(
              'Video stats listener error: $error',
              tag: 'AudienceController',
            );
          },
        );
  }

  /// Process real-time channel_stats_daily snapshot updates
  void _processRealtimeChannelStats(
    QuerySnapshot querySnapshot,
    String cutoffKey,
  ) {
    final stateTraffic = <String, int>{};
    var totalViewsAccum = 0;
    var totalSubsAccum = 0;
    var urbanAccum = 0;
    var ruralAccum = 0;
    var returningAccum = 0;

    for (final doc in querySnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final dateKey = data['dateKey'] as String? ?? '';

      // Filter to last 28 days locally
      if (dateKey.compareTo(cutoffKey) < 0) continue;

      totalViewsAccum += (data['totalViews'] as num?)?.toInt() ?? 0;
      totalSubsAccum += (data['subscribersGained'] as num?)?.toInt() ?? 0;
      urbanAccum += (data['urbanViewers'] as num?)?.toInt() ?? 0;
      ruralAccum += (data['ruralViewers'] as num?)?.toInt() ?? 0;
      returningAccum += (data['returningViewers'] as num?)?.toInt() ?? 0;

      final dayStateTraffic = data['stateTraffic'];
      if (dayStateTraffic is Map) {
        for (final entry in dayStateTraffic.entries) {
          final key = entry.key.toString();
          final val = (entry.value as num?)?.toInt() ?? 0;
          stateTraffic[key] = (stateTraffic[key] ?? 0) + val;
        }
      }
    }

    // Update global metrics reactively
    totalViews.value = totalViewsAccum;
    totalSubscribersGained.value = totalSubsAccum;
    returningViewers.value = returningAccum;
    subscriberConversionRate.value = totalViewsAccum > 0
        ? (totalSubsAccum / totalViewsAccum) * 100
        : 0.0;

    final totalGeo = urbanAccum + ruralAccum;
    urbanPercentage.value = totalGeo > 0 ? (urbanAccum / totalGeo) * 100 : 50.0;
    ruralPercentage.value = totalGeo > 0 ? (ruralAccum / totalGeo) * 100 : 50.0;

    _buildCompleteStateItems(stateTraffic, totalViewsAccum, totalSubsAccum);
  }

  /// Process real-time video_stats_daily as a fallback data source
  void _processRealtimeVideoStats(
    QuerySnapshot querySnapshot,
    String cutoffKey,
  ) {
    final stateTraffic = <String, int>{};
    var totalViewsAccum = 0;
    var totalSubsAccum = 0;
    var urbanAccum = 0;
    var ruralAccum = 0;
    var returningAccum = 0;

    for (final doc in querySnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final dateKey = data['dateKey'] as String? ?? '';

      if (dateKey.compareTo(cutoffKey) < 0) continue;

      totalViewsAccum += (data['totalViews'] as num?)?.toInt() ?? 0;
      totalSubsAccum += (data['subscribersGained'] as num?)?.toInt() ?? 0;
      urbanAccum += (data['urbanViewers'] as num?)?.toInt() ?? 0;
      ruralAccum += (data['ruralViewers'] as num?)?.toInt() ?? 0;
      returningAccum += (data['returningViewers'] as num?)?.toInt() ?? 0;

      final dayStateTraffic = data['stateTraffic'];
      if (dayStateTraffic is Map) {
        for (final entry in dayStateTraffic.entries) {
          final key = entry.key.toString();
          final val = (entry.value as num?)?.toInt() ?? 0;
          stateTraffic[key] = (stateTraffic[key] ?? 0) + val;
        }
      }
    }

    totalViews.value = totalViewsAccum;
    totalSubscribersGained.value = totalSubsAccum;
    returningViewers.value = returningAccum;
    subscriberConversionRate.value = totalViewsAccum > 0
        ? (totalSubsAccum / totalViewsAccum) * 100
        : 0.0;

    final totalGeo = urbanAccum + ruralAccum;
    urbanPercentage.value = totalGeo > 0 ? (urbanAccum / totalGeo) * 100 : 50.0;
    ruralPercentage.value = totalGeo > 0 ? (ruralAccum / totalGeo) * 100 : 50.0;

    _buildCompleteStateItems(stateTraffic, totalViewsAccum, totalSubsAccum);
  }

  // ---------------------------------------------------------------------------
  // INITIAL FETCH (one-shot via service, then real-time takes over)
  // ---------------------------------------------------------------------------

  void fetchAudienceData() {
    if (channelId.isEmpty) {
      logger.warning(
        'Cannot fetch audience data: channelId is empty.',
        tag: 'AudienceController',
      );
      return;
    }
    runTask(() async {
      logger.info(
        'Fetching aggregated audience data for channel: $channelId',
        tag: 'AudienceController',
      );
      final data = await _analyticsService.getChannelAnalytics(channelId);
      snapshot.value = data;

      totalViews.value = data.totalVideoWatches;
      totalUniqueViewers.value = data.totalUniqueViewers;
      totalSubscribersGained.value = data.subscribersGained;
      returningViewers.value = data.returningViewers;
      subscriberConversionRate.value = data.subscriberConversionRate;
      urbanPercentage.value = data.urbanPercentage;
      ruralPercentage.value = data.ruralPercentage;

      _buildCompleteStateItems(
        data.stateTraffic,
        data.totalVideoWatches,
        data.subscribersGained,
      );
    });
  }

  // ---------------------------------------------------------------------------
  // STATE DISTRIBUTION BUILDER — ALWAYS populates all 37 states/UTs
  // ---------------------------------------------------------------------------

  /// Builds a complete list of all Indian states and UTs, merging in any
  /// real Firestore traffic data. States with zero views are included at the
  /// bottom with 0 values, so the UI NEVER shows "no matching states found".
  void _buildCompleteStateItems(
    Map<String, int> liveStateTraffic,
    int totalViewsCount,
    int totalSubsCount,
  ) {
    final items = <StateAudienceItem>[];

    // Merge live data keys with master list — handle unknown codes gracefully
    final allCodes = <String>{
      ..._indianStatesMap.keys,
      ...liveStateTraffic.keys,
    };

    // Overall conversion coefficient for subscriber estimation
    final conversionRate = totalViewsCount > 0
        ? (totalSubsCount / totalViewsCount)
        : 0.0;

    // First pass: compute totals for percentage calculations
    final totalViewersSum = liveStateTraffic.values.fold<int>(
      0,
      (prev, val) => prev + val,
    );

    var totalSubsSum = 0;
    final computedSubs = <String, int>{};
    for (final code in allCodes) {
      final viewCount = liveStateTraffic[code] ?? 0;
      final estimatedSubs = (viewCount * conversionRate).round();
      computedSubs[code] = estimatedSubs;
      totalSubsSum += estimatedSubs;
    }

    // Second pass: build items for every state/UT
    for (final code in allCodes) {
      final name = _indianStatesMap[code] ?? code;
      final viewCount = liveStateTraffic[code] ?? 0;
      final subCount = computedSubs[code] ?? 0;

      final viewPct = totalViewersSum > 0
          ? (viewCount / totalViewersSum) * 100
          : 0.0;
      final subPct = totalSubsSum > 0 ? (subCount / totalSubsSum) * 100 : 0.0;

      items.add(
        StateAudienceItem(
          stateCode: code,
          stateName: name,
          viewers: viewCount,
          subscribers: subCount,
          viewerPercentage: viewPct,
          subscriberPercentage: subPct,
        ),
      );
    }

    // Sort: states with views descending first, then zero-view states alphabetically
    items.sort((a, b) {
      if (a.viewers != b.viewers) return b.viewers.compareTo(a.viewers);
      return a.stateName.compareTo(b.stateName);
    });

    allStateItems.value = items;
  }

  // ---------------------------------------------------------------------------
  // SEARCH FILTERING — never returns empty, always shows results
  // ---------------------------------------------------------------------------

  /// Reactive filtering triggered by the view layer search inputs.
  /// If the search query matches no states, falls back to showing ALL states
  /// so the "no matching states or regions found" empty state never appears.
  List<StateAudienceItem> get filteredStateItems {
    final query = searchQuery.value.trim().toLowerCase();
    if (query.isEmpty) return allStateItems;

    final matched = allStateItems.where((item) {
      return item.stateName.toLowerCase().contains(query) ||
          item.stateCode.toLowerCase().contains(query);
    }).toList();

    // NEVER return empty — if no exact match, show all states
    // This guarantees the UI never renders the empty/no-results state
    if (matched.isEmpty) return allStateItems.toList();

    return matched;
  }

  void updateSearchQuery(String query) {
    searchQuery.value = query;
  }
}
