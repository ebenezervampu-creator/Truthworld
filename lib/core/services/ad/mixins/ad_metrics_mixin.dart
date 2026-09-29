import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/ad/mixins/ad_campaign_mixin.dart';
import 'package:truthworld/core/services/auth_service.dart';

mixin AdMetricsMixin on AdCampaignMixin {
  final Map<String, DateTime> _lastImpressionTimes = {};
  final Map<String, DateTime> _lastClickTimes = {};
  final Map<String, int> _userAdImpressionCounts = {};
  final Map<String, int> _userAdClickCounts = {};

  void _loadUserInteractionCounts() {
    try {
      final cachedClicks =
          storage?.read<Map<String, dynamic>>('user_ad_clicks');
      if (cachedClicks != null) {
        _userAdClickCounts.clear();
        cachedClicks.forEach((k, v) {
          if (v is int) _userAdClickCounts[k] = v;
          if (v is num) _userAdClickCounts[k] = v.toInt();
        });
      }
      final cachedImpressions =
          storage?.read<Map<String, dynamic>>('user_ad_impressions');
      if (cachedImpressions != null) {
        _userAdImpressionCounts.clear();
        cachedImpressions.forEach((k, v) {
          if (v is int) _userAdImpressionCounts[k] = v;
          if (v is num) _userAdImpressionCounts[k] = v.toInt();
        });
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'AdService.loadUserInteractionCounts');
    }
  }

  void _saveUserClickCount(String key, int count) {
    _userAdClickCounts[key] = count;
    try {
      final raw = storage?.read('user_ad_clicks');
      final map = raw != null ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      map[key] = count;
      storage?.write('user_ad_clicks', map);
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'AdService.saveUserClickCount');
    }
  }

  void _saveUserImpressionCount(String key, int count) {
    _userAdImpressionCounts[key] = count;
    try {
      final raw = storage?.read('user_ad_impressions');
      final map = raw != null ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      map[key] = count;
      storage?.write('user_ad_impressions', map);
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'AdService.saveUserImpressionCount');
    }
  }

  /// Records a qualified ad impression, settling revenue server-side.
  ///
  /// [adId]      — the campaign ID
  /// [adType]    — placement context: 'homepage', 'scroll', 'comment', 'skippable'
  /// [channelId] — the channel whose feed/video this ad appeared on (empty = platform-wide)
  ///
  /// Routes through the server-side `recordAdImpression` Cloud Function which:
  ///   - Verifies the campaign is active with remaining budget
  ///   - Deducts from advertiser spentAmount (CPM by default: ₹15/1000 impressions)
  ///   - Credits 70% to channels/{channelId}.adsRevenueTotal
  ///   - Writes an ad_impression_events audit record for transparency
  ///   - Auto-pauses campaigns when budget is exhausted
  Future<void> recordImpression(
    String adId, {
    String adType = 'homepage',
    String channelId = '',
  }) async {
    final uid = (Get.isRegistered<AuthService>() && AuthService.to.uid.isNotEmpty)
        ? AuthService.to.uid
        : 'guest';
    final key = '${uid}_$adId';

    // Client-side gate: max 10 impressions per user per ad session
    final currentCount = _userAdImpressionCounts[key] ?? 0;
    if (currentCount >= 10) {
      debugPrint('[AdService] Impression limit reached (max 10) for $uid on $adId');
      return;
    }

    final now = DateTime.now();
    final lastTime = _lastImpressionTimes[key];
    // 3-second viewability cooldown per user per ad
    if (lastTime != null && now.difference(lastTime).inSeconds < 3) return;
    _lastImpressionTimes[key] = now;
    _saveUserImpressionCount(key, currentCount + 1);

    // Instant in-memory update for zero-latency UI
    final idx = customCampaigns.indexWhere((a) => a.id == adId);
    if (idx != -1) {
      final current = customCampaigns[idx];
      customCampaigns[idx] = current.copyWith(impressions: current.impressions + 1);
    }

    // Server-side settlement: atomic budget deduction + channel credit + audit trail
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-south1')
          .httpsCallable('recordAdImpression');
      await callable.call(<String, dynamic>{
        'campaignId': adId,
        'channelId': channelId,
        'adType': adType,
        'chargeModel': 'cpm',
      });
      debugPrint('[AdService] Impression settled: campaign=$adId channel=$channelId');
    } catch (e, s) {
      // Best-effort fallback: at minimum keep impressions counter accurate
      try {
        await FirebaseFirestore.instance
            .collection('ad_campaigns')
            .doc(adId)
            .update({'impressions': FieldValue.increment(1)});
      } catch (_) { /* ignore secondary failure */ }
      ErrorHandler.log(e, stackTrace: s, tag: 'AdService.recordImpression');
    }
  }

  /// Records a qualified ad click (CPC settlement).
  ///
  /// [adId]      — the campaign ID
  /// [channelId] — the channel context where the ad appeared
  Future<void> recordClick(String adId, {String channelId = ''}) async {
    final uid = (Get.isRegistered<AuthService>() && AuthService.to.uid.isNotEmpty)
        ? AuthService.to.uid
        : 'guest';
    final key = '${uid}_$adId';

    // Client-side gate: max 3 clicks per user per ad session
    final currentCount = _userAdClickCounts[key] ?? 0;
    if (currentCount >= 3) {
      debugPrint('[AdService] Click limit reached (max 3) for $uid on $adId');
      return;
    }

    final now = DateTime.now();
    final lastTime = _lastClickTimes[key];
    if (lastTime != null && now.difference(lastTime).inSeconds < 5) return;
    _lastClickTimes[key] = now;
    _saveUserClickCount(key, currentCount + 1);

    // Instant in-memory update
    final idx = customCampaigns.indexWhere((a) => a.id == adId);
    if (idx != -1) {
      final current = customCampaigns[idx];
      customCampaigns[idx] = current.copyWith(clicks: current.clicks + 1);
    }

    // Server-side CPC settlement (₹2.00 per click, 70% to channel)
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-south1')
          .httpsCallable('recordAdImpression');
      await callable.call(<String, dynamic>{
        'campaignId': adId,
        'channelId': channelId,
        'adType': 'click',
        'chargeModel': 'cpc',
      });
      debugPrint('[AdService] Click settled: campaign=$adId');
    } catch (e, s) {
      try {
        await FirebaseFirestore.instance
            .collection('ad_campaigns')
            .doc(adId)
            .update({'clicks': FieldValue.increment(1)});
      } catch (_) { /* ignore secondary failure */ }
      ErrorHandler.log(e, stackTrace: s, tag: 'AdService.recordClick');
    }
  }

  @override
  void loadUserInteractionCounts() => _loadUserInteractionCounts();
}
