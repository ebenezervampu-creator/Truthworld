import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player/tower_player_preferences.dart';

/// Evaluates premium user ad suppression rules and playback ad triggers.
class TowerPlayerAdPolicyEvaluator {
  /// Check if the currently authenticated user has an active premium subscription
  static bool isPremiumUser() {
    try {
      if (!Get.isRegistered<AuthService>()) return false;
      return AuthService.to.isPremiumUser.value;
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TowerPlayerAdPolicyEvaluator.isPremiumUser',
      );
      return false;
    }
  }

  /// Determines if ads should be suppressed based on:
  /// - Channel Member with Ad-Free Perk: Ad-free when watching a channel where creator enabled `noAdsForMembers`.
  /// - TruthWorld Premium ($2) & Fact-Checked ($3): Ad-free for all playback modes.
  /// - Audio Premium ($0.50): Ad-free specifically when playing in Audio-only Mode.
  static bool shouldSuppressAds({
    required bool isAudioOnly,
    bool isChannelMember = false,
    bool channelNoAdsForMembers = false,
  }) {
    try {
      // 1. Channel Member Ad-Free Playback:
      if (isChannelMember && channelNoAdsForMembers) {
        return true;
      }

      // 2. TruthWorld Premium User Subscription:
      if (!Get.isRegistered<AuthService>()) return false;
      final auth = AuthService.to;
      if (!auth.isPremiumUser.value) return false;
      final planId = auth.premiumPlanId.value;
      if (planId == 'audio_monthly') {
        return isAudioOnly || TowerPlayerPreferences.globalAudioOnly;
      }
      return true;
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TowerPlayerAdPolicyEvaluator.shouldSuppressAds',
      );
      return false;
    }
  }

  /// Checks if genuine playable video ads or sponsor ads exist for the video
  static bool hasRealVideoAds({String? videoId}) {
    if (!Get.isRegistered<AdService>()) return false;
    final adService = AdService.to;
    return adService.getSkippableVideoAds().isNotEmpty ||
        adService.getSponsorAdForVideo(videoId) != null;
  }
}
