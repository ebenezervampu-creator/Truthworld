import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/video/presentation/controllers/adaptive_bitrate_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_mixins/tower_player_abr_mixin.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:video_player/video_player.dart';

import '../../test_helpers/mock_firebase.dart';

/// Test implementation of TowerPlayerAbrMixin to verify channel-level premium resolution unlocking
class TestTowerPlayerController extends GetxController with TowerPlayerAbrMixin {
  TestTowerPlayerController({this.mockVideoController});

  final VideoController? mockVideoController;

  @override
  VideoController? get videoController => mockVideoController;

  @override
  VideoPlayerController get videoPlayerController => throw UnimplementedError();

  @override
  String? get tag => 'test_tag';

  @override
  RxBool get isShowingAd => false.obs;

  @override
  RxString get activePanel => ''.obs;

  @override
  RxBool get isAudioOnly => false.obs;

  @override
  void closeSettings() {}

  @override
  void trackAnalytics(dynamic event) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  group('Channel Premium 4K Resolution & ABR Access Tests', () {
    tearDown(Get.reset);

    test('maxHeightCap 1040 blocks 2160p (4K), while null cap unlocks 4K', () {
      final abr = AdaptiveBitrateController();
      final ladder = [
        const ResolutionTier(label: '360p', url: '', height: 360, bitrate: 600, minBandwidth: 800),
        const ResolutionTier(label: '720p', url: '', height: 720, bitrate: 2500, minBandwidth: 3000),
        const ResolutionTier(label: '1040p', url: '', height: 1040, bitrate: 4500, minBandwidth: 5200),
        const ResolutionTier(label: '1080p', url: '', height: 1080, bitrate: 5000, minBandwidth: 6000),
        const ResolutionTier(label: '2160p', url: '', height: 2160, bitrate: 15000, minBandwidth: 18000),
      ];

      // Non-premium user: maxHeightCap is 1040
      abr.resolutionLadder = ladder;
      abr.currentTierIndex.value = 0;
      abr.maxHeightCap = 1040;

      // Attempting to select 2160p (4K) at index 4 is blocked
      abr.setManualTier(4);
      expect(abr.currentTierIndex.value, isNot(4));

      // Attempting to select 1080p at index 3 is blocked
      abr.setManualTier(3);
      expect(abr.currentTierIndex.value, isNot(3));

      // Selecting 720p at index 1 is allowed
      abr.setManualTier(1);
      expect(abr.currentTierIndex.value, equals(1));
      expect(abr.currentTier.label, equals('720p'));

      // Channel Premium active: maxHeightCap becomes null
      abr.updateMaxHeightCap(null);
      expect(abr.maxHeightCap, isNull);

      // Selecting 2160p (4K) is now unlocked and succeeds
      abr.setManualTier(4);
      expect(abr.currentTierIndex.value, equals(4));
      expect(abr.currentTier.label, equals('2160p'));
      expect(abr.currentTier.height, equals(2160));
    });

    test('hasPremiumPlaybackAccess unlocks 4K when viewer is a channel member with noAdsForMembers enabled', () {
      final chCtrl = ChannelController();
      chCtrl.subController = ChannelSubscriptionController();
      final videoCtrl = VideoController();
      videoCtrl.channelController = chCtrl;

      // Channel has noAdsForMembers (Channel Premium) enabled
      final premiumChannel = Channel.fromMap({
        'name': 'Nature Channel',
        'nameLowercase': 'nature channel',
        'handle': '@nature',
        'handleLowercase': '@nature',
        'description': '',
        'avatarUrl': '',
        'bannerUrl': '',
        'ownerId': 'user_1',
        'noAdsForMembers': true,
      }, 'ch_premium');
      chCtrl.selectedChannel.value = premiumChannel;

      // 1. Viewer is NOT a member -> false
      chCtrl.subController.isChannelMember.value = false;
      final playerCtrl = TestTowerPlayerController(mockVideoController: videoCtrl);
      expect(playerCtrl.hasPremiumPlaybackAccess, isFalse);

      // 2. Viewer BECOMES an active member -> true (Channel Premium unlocked!)
      chCtrl.subController.isChannelMember.value = true;
      expect(playerCtrl.hasPremiumPlaybackAccess, isTrue);

      // 3. Creator disables noAdsForMembers -> false (Channel Premium inactive)
      final standardChannel = Channel.fromMap({
        'name': 'Nature Channel',
        'nameLowercase': 'nature channel',
        'handle': '@nature',
        'handleLowercase': '@nature',
        'description': '',
        'avatarUrl': '',
        'bannerUrl': '',
        'ownerId': 'user_1',
        'noAdsForMembers': false,
      }, 'ch_premium');
      chCtrl.selectedChannel.value = standardChannel;
      expect(playerCtrl.hasPremiumPlaybackAccess, isFalse);
    });
  });
}
