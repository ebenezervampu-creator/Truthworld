import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player/tower_player_ad_policy_evaluator.dart';

void main() {
  group('TowerPlayerAdPolicyEvaluator Tests', () {
    test('suppresses ads when viewer is a channel member and channel has noAdsForMembers enabled', () {
      final suppressed = TowerPlayerAdPolicyEvaluator.shouldSuppressAds(
        isAudioOnly: false,
        isChannelMember: true,
        channelNoAdsForMembers: true,
      );

      expect(suppressed, isTrue);
    });

    test('does not suppress ads when viewer is a member but channel has noAdsForMembers disabled', () {
      final suppressed = TowerPlayerAdPolicyEvaluator.shouldSuppressAds(
        isAudioOnly: false,
        isChannelMember: true,
      );

      expect(suppressed, isFalse);
    });

    test('does not suppress ads when channel has noAdsForMembers enabled but viewer is not a member', () {
      final suppressed = TowerPlayerAdPolicyEvaluator.shouldSuppressAds(
        isAudioOnly: false,
        channelNoAdsForMembers: true,
      );

      expect(suppressed, isFalse);
    });

    test('does not suppress ads when neither member nor noAdsForMembers are enabled', () {
      final suppressed = TowerPlayerAdPolicyEvaluator.shouldSuppressAds(
        isAudioOnly: false,
      );

      expect(suppressed, isFalse);
    });
  });
}
