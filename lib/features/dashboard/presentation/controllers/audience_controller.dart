import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/analytics/data/models/watch_event_model.dart';
import 'package:truthworld/features/analytics/data/services/video_analytics_service.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/dashboard_screen.dart';

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
  AudienceController({String initialChannelId = ''}) {
    if (initialChannelId.isNotEmpty) {
      _channelId.value = initialChannelId;
    }
  }

  VideoAnalyticsService get _analyticsService =>
      Get.isRegistered<VideoAnalyticsService>()
          ? Get.find<VideoAnalyticsService>()
          : Get.put(VideoAnalyticsService());
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final RxString _channelId = ''.obs;
  String get channelId => _channelId.value;

  StreamSubscription? _channelStatsSub;
  StreamSubscription? _videoStatsSub;

  // Search filter
  final RxString searchQuery = ''.obs;

  // Primary metrics snapshots
  final snapshot = Rx<ChannelAnalyticsSnapshot?>(null);
  final RxList<StateAudienceItem> allStateItems = <StateAudienceItem>[].obs;

  // Global scope numbers
  final RxInt totalViews = 0.obs;
  final RxInt totalUniqueViewers = 0.obs;
  final RxInt totalSubscribersGained = 0.obs;
  final RxInt totalSubscribersLost = 0.obs;
  final RxInt returningViewers = 0.obs;
  final RxInt subscriberViews = 0.obs;
  final RxInt nonSubscriberViews = 0.obs;
  final RxDouble subscriberConversionRate = 0.0.obs;
  final RxDouble urbanPercentage = 0.0.obs;
  final RxDouble ruralPercentage = 0.0.obs;

  // Demographics (Age groups & Genders)
  final RxMap<String, double> ageDistribution = <String, double>{}.obs;
  final RxMap<String, double> genderDistribution = <String, double>{}.obs;

  // Computed / Getter metrics
  double get subscribedPercentage {
    final total = subscriberViews.value + nonSubscriberViews.value;
    if (total > 0) {
      return ((subscriberViews.value / total) * 100).clamp(0.0, 100.0);
    }
    if (totalViews.value > 0 && subscriberViews.value > 0) {
      return ((subscriberViews.value / totalViews.value) * 100).clamp(0.0, 100.0);
    }
    return 0.0;
  }

  double get notSubscribedPercentage {
    final total = subscriberViews.value + nonSubscriberViews.value;
    if (total > 0) {
      return ((nonSubscriberViews.value / total) * 100).clamp(0.0, 100.0);
    }
    if (totalViews.value > 0) {
      final subPct = subscribedPercentage;
      return (100.0 - subPct).clamp(0.0, 100.0);
    }
    return 0.0;
  }

  int get newViewers {
    final diff = totalUniqueViewers.value - returningViewers.value;
    if (diff > 0) return diff;
    if (totalUniqueViewers.value > 0) return totalUniqueViewers.value;
    return totalViews.value;
  }

  double get returningPercentage {
    if (totalUniqueViewers.value > 0) {
      return ((returningViewers.value / totalUniqueViewers.value) * 100).clamp(0.0, 100.0);
    }
    if (totalViews.value > 0 && returningViewers.value > 0) {
      return ((returningViewers.value / totalViews.value) * 100).clamp(0.0, 100.0);
    }
    return 0.0;
  }

  double get newViewersPercentage {
    if (totalUniqueViewers.value == 0 && totalViews.value == 0) return 0.0;
    return (100.0 - returningPercentage).clamp(0.0, 100.0);
  }

  int get netSubscribers =>
      totalSubscribersGained.value - totalSubscribersLost.value;


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
    _resolveAndLoad();
  }

  @override
  void onClose() {
    _channelStatsSub?.cancel();
    _videoStatsSub?.cancel();
    super.onClose();
  }

  /// Inject or update channel navigation context dynamically
  void setChannelContext(String id) {
    if (id.isNotEmpty && _channelId.value != id) {
      _channelId.value = id;
      clearError();
      fetchAudienceData();
      _startRealtimeListeners();
    } else if (id.isNotEmpty && (state == ViewState.error || allStateItems.isEmpty)) {
      _channelId.value = id;
      clearError();
      fetchAudienceData();
      _startRealtimeListeners();
    }
  }

  void _resolveAndLoad() {
    if (_channelId.value.isEmpty) {
      // 1. Try DashboardController if registered
      if (Get.isRegistered<DashboardController>()) {
        final dash = Get.find<DashboardController>();
        if (dash.channelId.isNotEmpty) {
          _channelId.value = dash.channelId;
        } else if (dash.currentChannel.value != null &&
            dash.currentChannel.value!.id.isNotEmpty) {
          _channelId.value = dash.currentChannel.value!.id;
        }
      }

      // 2. Try AuthService userChannel
      if (_channelId.value.isEmpty && Get.isRegistered<AuthService>()) {
        final authChannel = AuthService.to.userChannel;
        if (authChannel != null && authChannel.id.isNotEmpty) {
          _channelId.value = authChannel.id;
        } else if (AuthService.to.rxUserChannel.value != null &&
            AuthService.to.rxUserChannel.value!.id.isNotEmpty) {
          _channelId.value = AuthService.to.rxUserChannel.value!.id;
        }
      }

      // 3. Try Get.arguments
      if (_channelId.value.isEmpty) {
        final args = Get.arguments;
        if (args is Map && args['channel'] != null) {
          final ch = args['channel'];
          if (ch is Channel) {
            _channelId.value = ch.id;
          } else if (ch is Map && ch['id'] != null) {
            _channelId.value = ch['id'].toString();
          }
        }
      }
    }

    if (_channelId.value.isNotEmpty) {
      clearError();
      fetchAudienceData();
      _startRealtimeListeners();
    } else {
      // Listen for reactive channel updates in case it resolves slightly later
      if (Get.isRegistered<AuthService>()) {
        addWorker(
          ever(AuthService.to.rxUserChannel, (channel) {
            if (channel != null &&
                channel.id.isNotEmpty &&
                _channelId.value.isEmpty) {
              setChannelContext(channel.id);
            }
          }),
        );
      }
      if (Get.isRegistered<DashboardController>()) {
        addWorker(
          ever(Get.find<DashboardController>().currentChannel, (channel) {
            if (channel != null &&
                channel.id.isNotEmpty &&
                _channelId.value.isEmpty) {
              setChannelContext(channel.id);
            }
          }),
        );
      }
      setError('No active channel context specified.');
    }
  }

  // ---------------------------------------------------------------------------
  // REAL-TIME FIRESTORE LISTENERS
  // ---------------------------------------------------------------------------

  /// Attach Firestore snapshot listeners to channel_stats_daily and
  /// video_stats_daily so geography data updates in real time as new
  /// watch events are aggregated by the Cloud Function pipeline.
  void _startRealtimeListeners() {
    _channelStatsSub?.cancel();
    _videoStatsSub?.cancel();

    if (channelId.isEmpty) return;

    logger.info(
      'Starting real-time geography listeners for channel: $channelId',
      tag: 'AudienceController',
    );

    // Listen to channel_stats_daily for this channel (latest 28 days)
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(days: 28));
    final cutoffKey =
        '${cutoff.year}_${cutoff.month.toString().padLeft(2, '0')}_${cutoff.day.toString().padLeft(2, '0')}';

    _channelStatsSub = _firestore
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
    trackSubscription(_channelStatsSub!);

    // Fallback: also listen to video_stats_daily for this channel
    // in case channel_stats_daily hasn't been populated yet
    _videoStatsSub = _firestore
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
    trackSubscription(_videoStatsSub!);
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
    urbanPercentage.value = totalGeo > 0 ? (urbanAccum / totalGeo) * 100 : 0.0;
    ruralPercentage.value = totalGeo > 0 ? (ruralAccum / totalGeo) * 100 : 0.0;

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
    urbanPercentage.value = totalGeo > 0 ? (urbanAccum / totalGeo) * 100 : 0.0;
    ruralPercentage.value = totalGeo > 0 ? (ruralAccum / totalGeo) * 100 : 0.0;

    _buildCompleteStateItems(stateTraffic, totalViewsAccum, totalSubsAccum);
  }

  // ---------------------------------------------------------------------------
  // INITIAL FETCH (one-shot via service, then real-time takes over)
  // ---------------------------------------------------------------------------

  void fetchAudienceData() {
    if (channelId.isEmpty) {
      _resolveAndLoad();
      if (channelId.isEmpty) {
        logger.warning(
          'Cannot fetch audience data: channelId is empty.',
          tag: 'AudienceController',
        );
        setError('No active channel context specified.');
        return;
      }
    }
    clearError();
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
      totalSubscribersLost.value = data.subscribersLost;
      returningViewers.value = data.returningViewers;
      subscriberViews.value = data.subscriberViews;
      nonSubscriberViews.value = data.nonSubscriberViews;
      subscriberConversionRate.value = data.subscriberConversionRate;
      urbanPercentage.value = data.urbanPercentage;
      ruralPercentage.value = data.ruralPercentage;

      _buildCompleteStateItems(
        data.stateTraffic,
        data.totalVideoWatches,
        data.subscribersGained,
      );

      await _fetchDemographicsDetails();
    });
  }

  /// Loads detailed age and gender demographics breakdown
  Future<void> _fetchDemographicsDetails() async {
    try {
      // 1. Try analytics/{channelId}/demographics/latest
      final doc = await _firestore
          .collection('analytics')
          .doc(channelId)
          .collection('demographics')
          .doc('latest')
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _updateDemographicsFromMap(data);
        return;
      }

      // 2. Try channels/{channelId}/demographics/latest
      final chDoc = await _firestore
          .collection('channels')
          .doc(channelId)
          .collection('demographics')
          .doc('latest')
          .get();

      if (chDoc.exists && chDoc.data() != null) {
        final data = chDoc.data()!;
        _updateDemographicsFromMap(data);
        return;
      }

      // 3. Dynamically aggregate from real subscribers and viewers
      final aggregated = await _aggregateLiveDemographicsFromAudience();
      if (aggregated) return;

      _populateEmptyDemographics();
    } catch (e) {
      logger.warning(
        'Error fetching demographics doc: $e, using zero distribution',
        tag: 'AudienceController',
      );
      _populateEmptyDemographics();
    }
  }

  Future<bool> _aggregateLiveDemographicsFromAudience() async {
    try {
      final userIds = <String>{};

      // Get subscribers of this channel
      final subSnap = await _firestore
          .collection(FirestoreCollections.channelSubscribers(channelId))
          .limit(50)
          .get();

      for (final doc in subSnap.docs) {
        final uid = (doc.data()['userId'] as String?) ?? doc.id;
        if (uid.isNotEmpty) userIds.add(uid);
      }

      // Get videos of this channel
      final vidSnap = await _firestore
          .collection('videos')
          .where('channelId', isEqualTo: channelId)
          .limit(20)
          .get();

      final videoIds = vidSnap.docs.map((d) => d.id).toList();
      if (videoIds.isNotEmpty) {
        for (var i = 0; i < videoIds.length; i += 10) {
          final chunk = videoIds.sublist(
            i,
            i + 10 > videoIds.length ? videoIds.length : i + 10,
          );
          final sessionSnap = await _firestore
              .collection('watch_sessions')
              .where('videoId', whereIn: chunk)
              .limit(50)
              .get();

          for (final sDoc in sessionSnap.docs) {
            final uid = sDoc.data()['userId'] as String?;
            if (uid != null && uid.isNotEmpty && uid != 'anonymous') {
              userIds.add(uid);
            }
          }
        }
      }

      if (userIds.isEmpty) {
        _populateEmptyDemographics();
        return false;
      }

      final ageCounts = <String, int>{};
      final genderCounts = <String, int>{};
      var totalAge = 0;
      var totalGender = 0;

      final uidList = userIds.toList();
      for (var i = 0; i < uidList.length; i += 10) {
        final chunk = uidList.sublist(
          i,
          i + 10 > uidList.length ? uidList.length : i + 10,
        );
        final usersSnap = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        for (final uDoc in usersSnap.docs) {
          final uData = uDoc.data();
          final age = uData['ageGroup'] as String?;
          final gender = uData['gender'] as String?;

          if (age != null && age.trim().isNotEmpty) {
            final stdAge = _standardizeAgeGroup(age);
            ageCounts[stdAge] = (ageCounts[stdAge] ?? 0) + 1;
            totalAge++;
          }

          if (gender != null && gender.trim().isNotEmpty) {
            final stdGender = _standardizeGender(gender);
            genderCounts[stdGender] = (genderCounts[stdGender] ?? 0) + 1;
            totalGender++;
          }
        }
      }

      if (totalAge > 0) {
        final ageMap = <String, double>{};
        for (final key in _standardAgeBrackets) {
          final count = ageCounts[key] ?? 0;
          ageMap[key] = (count / totalAge) * 100;
        }
        ageDistribution.value = ageMap;
      } else {
        _populateEmptyAgeDistribution();
      }

      if (totalGender > 0) {
        final genderMap = <String, double>{};
        for (final key in ['Male', 'Female', 'User specified / Other']) {
          final count = genderCounts[key] ?? 0;
          genderMap[key] = (count / totalGender) * 100;
        }
        genderDistribution.value = genderMap;
      } else {
        _populateEmptyGenderDistribution();
      }

      return totalAge > 0 || totalGender > 0;
    } catch (e) {
      logger.warning(
        'Live demographics aggregation fallback failed: $e',
        tag: 'AudienceController',
      );
      return false;
    }
  }

  static const List<String> _standardAgeBrackets = [
    '13–17 years',
    '18–24 years',
    '25–34 years',
    '35–44 years',
    '45–54 years',
    '55–64 years',
    '65+ years',
  ];

  String _standardizeAgeGroup(String raw) {
    final clean = raw.replaceAll('years', '').replaceAll('year', '').trim();
    if (clean == '13–17' || clean == '13-17' || clean == 'Under 18' || clean == 'Under 13') {
      return '13–17 years';
    }
    if (clean == '18–24' || clean == '18-24') return '18–24 years';
    if (clean == '25–34' || clean == '25-34') return '25–34 years';
    if (clean == '35–44' || clean == '35-44') return '35–44 years';
    if (clean == '45–54' || clean == '45-54') return '45–54 years';
    if (clean == '55–64' || clean == '55-64') return '55–64 years';
    if (clean == '65+' || clean == '65 plus') return '65+ years';
    return '18–24 years';
  }

  String _standardizeGender(String raw) {
    final lower = raw.trim().toLowerCase();
    if (lower == 'male' || lower == 'm') return 'Male';
    if (lower == 'female' || lower == 'f') return 'Female';
    return 'User specified / Other';
  }

  void _updateDemographicsFromMap(Map<String, dynamic> data) {
    if (data['ageDistribution'] is Map) {
      final map = data['ageDistribution'] as Map;
      ageDistribution.value = map.map(
        (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
      );
    } else {
      _populateEmptyAgeDistribution();
    }

    if (data['genderDistribution'] is Map) {
      final map = data['genderDistribution'] as Map;
      genderDistribution.value = map.map(
        (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
      );
    } else {
      _populateEmptyGenderDistribution();
    }
  }

  void _populateEmptyDemographics() {
    _populateEmptyAgeDistribution();
    _populateEmptyGenderDistribution();
  }

  void _populateEmptyAgeDistribution() {
    ageDistribution.value = {
      '13–17 years': 0.0,
      '18–24 years': 0.0,
      '25–34 years': 0.0,
      '35–44 years': 0.0,
      '45–54 years': 0.0,
      '55–64 years': 0.0,
      '65+ years': 0.0,
    };
  }

  void _populateEmptyGenderDistribution() {
    genderDistribution.value = {
      'Male': 0.0,
      'Female': 0.0,
      'User specified / Other': 0.0,
    };
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
  // SEARCH FILTERING
  // ---------------------------------------------------------------------------

  /// Reactive filtering triggered by the view layer search inputs.
  List<StateAudienceItem> get filteredStateItems {
    final query = searchQuery.value.trim().toLowerCase();
    if (query.isEmpty) return allStateItems;

    return allStateItems.where((item) {
      return item.stateName.toLowerCase().contains(query) ||
          item.stateCode.toLowerCase().contains(query);
    }).toList();
  }

  void updateSearchQuery(String query) {
    searchQuery.value = query;
  }
}
