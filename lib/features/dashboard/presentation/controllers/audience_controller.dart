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

class CountryAudienceItem {
  CountryAudienceItem({
    required this.countryCode,
    required this.countryName,
    required this.viewers,
    required this.subscribers,
    required this.viewerPercentage,
    required this.subscriberPercentage,
  });
  final String countryCode;
  final String countryName;
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
  final RxList<CountryAudienceItem> allCountryItems = <CountryAudienceItem>[].obs;

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

  // Comprehensive international country code -> name map (ISO 3166-1 alpha-2)
  static const Map<String, String> _countryNamesMap = {
    'AF': 'Afghanistan',
    'AL': 'Albania',
    'DZ': 'Algeria',
    'AR': 'Argentina',
    'AM': 'Armenia',
    'AU': 'Australia',
    'AT': 'Austria',
    'AZ': 'Azerbaijan',
    'BH': 'Bahrain',
    'BD': 'Bangladesh',
    'BY': 'Belarus',
    'BE': 'Belgium',
    'BT': 'Bhutan',
    'BO': 'Bolivia',
    'BA': 'Bosnia and Herzegovina',
    'BR': 'Brazil',
    'BG': 'Bulgaria',
    'KH': 'Cambodia',
    'CM': 'Cameroon',
    'CA': 'Canada',
    'CL': 'Chile',
    'CN': 'China',
    'CO': 'Colombia',
    'CR': 'Costa Rica',
    'HR': 'Croatia',
    'CU': 'Cuba',
    'CY': 'Cyprus',
    'CZ': 'Czech Republic',
    'DK': 'Denmark',
    'EC': 'Ecuador',
    'EG': 'Egypt',
    'ET': 'Ethiopia',
    'FI': 'Finland',
    'FR': 'France',
    'GE': 'Georgia',
    'DE': 'Germany',
    'GH': 'Ghana',
    'GR': 'Greece',
    'HK': 'Hong Kong',
    'HU': 'Hungary',
    'IS': 'Iceland',
    'IN': 'India',
    'ID': 'Indonesia',
    'IR': 'Iran',
    'IQ': 'Iraq',
    'IE': 'Ireland',
    'IL': 'Israel',
    'IT': 'Italy',
    'JP': 'Japan',
    'JO': 'Jordan',
    'KZ': 'Kazakhstan',
    'KE': 'Kenya',
    'KW': 'Kuwait',
    'KG': 'Kyrgyzstan',
    'LB': 'Lebanon',
    'MY': 'Malaysia',
    'MV': 'Maldives',
    'MX': 'Mexico',
    'MA': 'Morocco',
    'NP': 'Nepal',
    'NL': 'Netherlands',
    'NZ': 'New Zealand',
    'NG': 'Nigeria',
    'NO': 'Norway',
    'OM': 'Oman',
    'PK': 'Pakistan',
    'PA': 'Panama',
    'PE': 'Peru',
    'PH': 'Philippines',
    'PL': 'Poland',
    'PT': 'Portugal',
    'QA': 'Qatar',
    'RO': 'Romania',
    'RU': 'Russia',
    'SA': 'Saudi Arabia',
    'RS': 'Serbia',
    'SG': 'Singapore',
    'ZA': 'South Africa',
    'KR': 'South Korea',
    'ES': 'Spain',
    'LK': 'Sri Lanka',
    'SE': 'Sweden',
    'CH': 'Switzerland',
    'TW': 'Taiwan',
    'TH': 'Thailand',
    'TR': 'Turkey',
    'UG': 'Uganda',
    'UA': 'Ukraine',
    'AE': 'United Arab Emirates',
    'GB': 'United Kingdom',
    'UK': 'United Kingdom',
    'US': 'United States',
    'USA': 'United States',
    'UY': 'Uruguay',
    'UZ': 'Uzbekistan',
    'VE': 'Venezuela',
    'VN': 'Vietnam',
    'YE': 'Yemen',
    'ZM': 'Zambia',
    'ZW': 'Zimbabwe',
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
    } else if (id.isNotEmpty && (state == ViewState.error || allCountryItems.isEmpty)) {
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
            if (allCountryItems.isEmpty ||
                allCountryItems.every((item) => item.viewers == 0)) {
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
    final countryTraffic = <String, int>{};
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

      final dayCountryTraffic = data['countryTraffic'];
      if (dayCountryTraffic is Map) {
        for (final entry in dayCountryTraffic.entries) {
          final key = entry.key.toString();
          final val = (entry.value as num?)?.toInt() ?? 0;
          countryTraffic[key] = (countryTraffic[key] ?? 0) + val;
        }
      }

      final dayStateTraffic = data['stateTraffic'];
      if (dayStateTraffic is Map) {
        for (final entry in dayStateTraffic.entries) {
          final key = entry.key.toString();
          final val = (entry.value as num?)?.toInt() ?? 0;
          stateTraffic[key] = (stateTraffic[key] ?? 0) + val;
        }
      }
    }

    if (countryTraffic.isEmpty && stateTraffic.isNotEmpty) {
      final sum = stateTraffic.values.fold<int>(0, (a, b) => a + b);
      if (sum > 0) countryTraffic['IN'] = sum;
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

    _buildCompleteCountryItems(countryTraffic, totalViewsAccum, totalSubsAccum);
  }

  /// Process real-time video_stats_daily as a fallback data source
  void _processRealtimeVideoStats(
    QuerySnapshot querySnapshot,
    String cutoffKey,
  ) {
    final countryTraffic = <String, int>{};
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

      final dayCountryTraffic = data['countryTraffic'];
      if (dayCountryTraffic is Map) {
        for (final entry in dayCountryTraffic.entries) {
          final key = entry.key.toString();
          final val = (entry.value as num?)?.toInt() ?? 0;
          countryTraffic[key] = (countryTraffic[key] ?? 0) + val;
        }
      }

      final dayStateTraffic = data['stateTraffic'];
      if (dayStateTraffic is Map) {
        for (final entry in dayStateTraffic.entries) {
          final key = entry.key.toString();
          final val = (entry.value as num?)?.toInt() ?? 0;
          stateTraffic[key] = (stateTraffic[key] ?? 0) + val;
        }
      }
    }

    if (countryTraffic.isEmpty && stateTraffic.isNotEmpty) {
      final sum = stateTraffic.values.fold<int>(0, (a, b) => a + b);
      if (sum > 0) countryTraffic['IN'] = sum;
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

    _buildCompleteCountryItems(countryTraffic, totalViewsAccum, totalSubsAccum);
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

      final countryTraffic = Map<String, int>.from(data.countryTraffic);
      if (countryTraffic.isEmpty && data.stateTraffic.isNotEmpty) {
        final sum = data.stateTraffic.values.fold<int>(0, (a, b) => a + b);
        if (sum > 0) countryTraffic['IN'] = sum;
      }

      _buildCompleteCountryItems(
        countryTraffic,
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
  // COUNTRY DISTRIBUTION BUILDER — ONLY includes countries with viewers > 0
  // ---------------------------------------------------------------------------

  /// Builds audience country list containing ONLY countries that have > 0 viewers (viewerPercentage > 0.0).
  /// Truthworld is global, so countries with zero views are omitted rather than showing an exhaustive empty list.
  void _buildCompleteCountryItems(
    Map<String, int> liveCountryTraffic,
    int totalViewsCount,
    int totalSubsCount,
  ) {
    final items = <CountryAudienceItem>[];

    // Filter ONLY countries with > 0 viewers
    final activeEntries = liveCountryTraffic.entries
        .where((e) => e.value > 0)
        .toList();

    // Overall conversion coefficient for subscriber estimation
    final conversionRate = totalViewsCount > 0
        ? (totalSubsCount / totalViewsCount)
        : 0.0;

    final totalViewersSum = activeEntries.fold<int>(
      0,
      (prev, val) => prev + val.value,
    );

    var totalSubsSum = 0;
    final computedSubs = <String, int>{};
    for (final entry in activeEntries) {
      final estimatedSubs = (entry.value * conversionRate).round();
      computedSubs[entry.key] = estimatedSubs;
      totalSubsSum += estimatedSubs;
    }

    for (final entry in activeEntries) {
      final rawKey = entry.key.trim();
      final code = rawKey.length == 2
          ? rawKey.toUpperCase()
          : (_lookupCountryCode(rawKey) ?? rawKey);
      final name = _countryNamesMap[code] ??
          _countryNamesMap[rawKey.toUpperCase()] ??
          rawKey;
      final viewCount = entry.value;
      final subCount = computedSubs[entry.key] ?? 0;

      final viewPct = totalViewersSum > 0
          ? (viewCount / totalViewersSum) * 100
          : 0.0;
      final subPct = totalSubsSum > 0
          ? (subCount / totalSubsSum) * 100
          : 0.0;

      if (viewCount > 0) {
        items.add(
          CountryAudienceItem(
            countryCode: code,
            countryName: name,
            viewers: viewCount,
            subscribers: subCount,
            viewerPercentage: viewPct,
            subscriberPercentage: subPct,
          ),
        );
      }
    }

    // Sort descending by viewers
    items.sort((a, b) {
      if (a.viewers != b.viewers) return b.viewers.compareTo(a.viewers);
      return a.countryName.compareTo(b.countryName);
    });

    allCountryItems.value = items;
  }

  static String? _lookupCountryCode(String nameOrCode) {
    final lower = nameOrCode.toLowerCase();
    for (final entry in _countryNamesMap.entries) {
      if (entry.key.toLowerCase() == lower ||
          entry.value.toLowerCase() == lower) {
        return entry.key;
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // SEARCH FILTERING
  // ---------------------------------------------------------------------------

  /// Reactive filtering triggered by the view layer search inputs.
  List<CountryAudienceItem> get filteredCountryItems {
    final query = searchQuery.value.trim().toLowerCase();
    if (query.isEmpty) return allCountryItems;

    return allCountryItems.where((item) {
      return item.countryName.toLowerCase().contains(query) ||
          item.countryCode.toLowerCase().contains(query);
    }).toList();
  }

  void updateSearchQuery(String query) {
    searchQuery.value = query;
  }
}
