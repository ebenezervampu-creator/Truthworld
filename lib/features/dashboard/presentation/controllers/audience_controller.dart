import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/features/analytics/data/models/watch_event_model.dart';
import 'package:truthworld/features/analytics/data/services/video_analytics_service.dart';

class StateAudienceItem {
  final String stateCode;
  final String stateName;
  final int viewers;
  final int subscribers;
  final double viewerPercentage;
  final double subscriberPercentage;

  StateAudienceItem({
    required this.stateCode,
    required this.stateName,
    required this.viewers,
    required this.subscribers,
    required this.viewerPercentage,
    required this.subscriberPercentage,
  });
}

class AudienceController extends BaseController {
  final String channelId;
  final VideoAnalyticsService _analyticsService = Get.find();

  AudienceController({required this.channelId});

  // Search filter
  final searchQuery = ''.obs;

  // Primary metrics snapshots
  final snapshot = Rx<ChannelAnalyticsSnapshot?>(null);
  final allStateItems = <StateAudienceItem>[].obs;

  // Global scope numbers
  final totalViews = 0.obs;
  final totalUniqueViewers = 0.obs;
  final totalSubscribersGained = 0.obs;
  final returningViewers = 0.obs;
  final subscriberConversionRate = 0.0.obs;
  final urbanPercentage = 0.0.obs;
  final ruralPercentage = 0.0.obs;

  // Indian states map for full human-readable rendering
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
    'MH': 'Maharashtra',
    'ML': 'Meghalaya',
    'MN': 'Manipur',
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
    } else {
      setError('No active channel context specified.');
    }
  }

  void fetchAudienceData() {
    runTask(() async {
      logger.info('Fetching aggregated audience data for channel: $channelId', tag: 'AudienceController');
      final data = await _analyticsService.getChannelAnalytics(channelId, dateRange: AnalyticsDateRange.last28Days);
      snapshot.value = data;

      totalViews.value = data.totalVideoWatches;
      totalUniqueViewers.value = data.totalUniqueViewers;
      totalSubscribersGained.value = data.subscribersGained;
      returningViewers.value = data.returningViewers;
      subscriberConversionRate.value = data.subscriberConversionRate;
      urbanPercentage.value = data.urbanPercentage;
      ruralPercentage.value = data.ruralPercentage;

      _processStateDistributions(data);
    });
  }

  void _processStateDistributions(ChannelAnalyticsSnapshot data) {
    final items = <StateAudienceItem>[];
    final stateCounts = data.stateTraffic;
    
    // If channel has zero views or empty states, we show empty stats instead of injecting mock data
    Map<String, int> activeStateCounts = stateCounts;

    final totalViewersSum = activeStateCounts.values.fold<int>(0, (prev, val) => prev + val);
    
    // Determine overall subscriber conversion coefficient
    double conversionRate = data.totalVideoWatches > 0
        ? (data.subscribersGained / data.totalVideoWatches)
        : 0.0;

    // Derive estimated absolute subscribers distribution based on proportional regional viewers
    int totalSubsSum = 0;
    final Map<String, int> computedSubs = {};
    for (final entry in activeStateCounts.entries) {
      int estimatedSubs = (entry.value * conversionRate).round();
      computedSubs[entry.key] = estimatedSubs;
      totalSubsSum += estimatedSubs;
    }

    for (final entry in activeStateCounts.entries) {
      final code = entry.key;
      final name = _indianStatesMap[code] ?? code;
      final viewCount = entry.value;
      final subCount = computedSubs[code] ?? 0;

      final viewPct = totalViewersSum > 0 ? (viewCount / totalViewersSum) * 100 : 0.0;
      final subPct = totalSubsSum > 0 ? (subCount / totalSubsSum) * 100 : 0.0;

      items.add(StateAudienceItem(
        stateCode: code,
        stateName: name,
        viewers: viewCount,
        subscribers: subCount,
        viewerPercentage: viewPct,
        subscriberPercentage: subPct,
      ));
    }

    // Sort descending by viewers tally
    items.sort((a, b) => b.viewers.compareTo(a.viewers));
    allStateItems.value = items;
  }


  // Reactive filtering triggered dynamically by the view layer search inputs
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




