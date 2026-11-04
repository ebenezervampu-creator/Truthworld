import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player/tower_player_registry.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player/tower_player_vpc_event_handler.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/services/sleep_timer_service.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:video_player/video_player.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const MethodChannel('plugins.flutter.io/path_provider')
        .setMockMethodCallHandler((MethodCall methodCall) async => '.');
    await GetStorage.init();
  });

  setUp(() {
    Get.reset();
    Get.put(SleepTimerService());
  });

  tearDown(() {
    Get.reset();
  });

  group('TowerPlayerController Audio Track Switching & Volume Isolation Tests', () {
    test('1. Initial state has hasAlternateAudioTrack false and normal volume', () {
      final vpc = VideoPlayerController.networkUrl(Uri.parse('https://example.com/video.mp4'));
      final ctrl = Get.put(
        TowerPlayerController(
          videoPlayerController: vpc,
          tag: 'test_audio_switch_tag_1',
        ),
        tag: 'test_audio_switch_tag_1',
      );

      expect(ctrl.hasAlternateAudioTrack, isFalse);
      expect(ctrl.activeAudioLang.value, equals('Original'));
      expect(ctrl.audioTrackController, isNull);

      ctrl.onClose();
      TowerPlayerRegistry.unregister(ctrl);
    });

    test('2. Selecting Telugu alternate audio track mutes video player and sets hasAlternateAudioTrack true', () {
      final vpc = VideoPlayerController.networkUrl(Uri.parse('https://example.com/video.mp4'));
      final ctrl = Get.put(
        TowerPlayerController(
          videoPlayerController: vpc,
          tag: 'test_audio_switch_tag_2',
        ),
        tag: 'test_audio_switch_tag_2',
      );

      const teluguTrack = AudioTrack(
        label: 'Telugu (Audio)',
        langCode: 'te',
        type: 'Audio',
        url: 'https://example.com/audio/te.mp3',
      );

      ctrl.setAudioLanguage(teluguTrack);

      expect(ctrl.activeAudioLang.value, equals('Telugu (Audio)'));
      expect(ctrl.hasAlternateAudioTrack, isTrue);
      expect(ctrl.videoPlayerController.value.volume, equals(0.0));
      expect(ctrl.audioTrackController, isNotNull);

      ctrl.onClose();
      TowerPlayerRegistry.unregister(ctrl);
    });

    test('3. onInteraction() does NOT unmute videoPlayerController when alternate audio track is active', () {
      final vpc = VideoPlayerController.networkUrl(Uri.parse('https://example.com/video.mp4'));
      final ctrl = Get.put(
        TowerPlayerController(
          videoPlayerController: vpc,
          tag: 'test_audio_switch_tag_3',
        ),
        tag: 'test_audio_switch_tag_3',
      );

      const teluguTrack = AudioTrack(
        label: 'Telugu (Audio)',
        langCode: 'te',
        type: 'Audio',
        url: 'https://example.com/audio/te.mp3',
      );

      ctrl.setAudioLanguage(teluguTrack);
      expect(ctrl.hasAlternateAudioTrack, isTrue);
      expect(ctrl.videoPlayerController.value.volume, equals(0.0));

      // Trigger user interaction (e.g. tap, hover, gesture)
      ctrl.onInteraction();

      // Main video player MUST remain muted so English audio does not bleed
      expect(ctrl.videoPlayerController.value.volume, equals(0.0));

      ctrl.onClose();
      TowerPlayerRegistry.unregister(ctrl);
    });

    test('4. setVolume() adjusts alternate audio volume while keeping main player strictly muted', () {
      final vpc = VideoPlayerController.networkUrl(Uri.parse('https://example.com/video.mp4'));
      final ctrl = Get.put(
        TowerPlayerController(
          videoPlayerController: vpc,
          tag: 'test_audio_switch_tag_4',
        ),
        tag: 'test_audio_switch_tag_4',
      );

      const teluguTrack = AudioTrack(
        label: 'Telugu (Audio)',
        langCode: 'te',
        type: 'Audio',
        url: 'https://example.com/audio/te.mp3',
      );

      ctrl.setAudioLanguage(teluguTrack);
      expect(ctrl.hasAlternateAudioTrack, isTrue);

      // User changes volume to 0.7
      ctrl.setVolume(0.7);

      expect(ctrl.volume.value, equals(0.7));
      expect(ctrl.videoPlayerController.value.volume, equals(0.0));

      ctrl.onClose();
      TowerPlayerRegistry.unregister(ctrl);
    });

    test('5. syncAlternateAudioTrack enforces zero volume on main player when alternate audio track is active', () {
      final vpc = VideoPlayerController.networkUrl(Uri.parse('https://example.com/video.mp4'));
      vpc.setVolume(1.0);
      expect(vpc.value.volume, equals(1.0));

      TowerPlayerVpcEventHandler.syncAlternateAudioTrack(
        mainVpc: vpc,
        audioCtrl: null,
        isMuted: false,
        volume: 1.0,
        hasAlternateAudioTrack: true,
      );

      expect(vpc.value.volume, equals(0.0));
    });

    test('6. Reverting to Original track restores video player volume and sets hasAlternateAudioTrack false', () {
      final vpc = VideoPlayerController.networkUrl(Uri.parse('https://example.com/video.mp4'));
      final ctrl = Get.put(
        TowerPlayerController(
          videoPlayerController: vpc,
          tag: 'test_audio_switch_tag_6',
        ),
        tag: 'test_audio_switch_tag_6',
      );

      const teluguTrack = AudioTrack(
        label: 'Telugu (Audio)',
        langCode: 'te',
        type: 'Audio',
        url: 'https://example.com/audio/te.mp3',
      );
      ctrl.setAudioLanguage(teluguTrack);
      expect(ctrl.hasAlternateAudioTrack, isTrue);
      expect(ctrl.videoPlayerController.value.volume, equals(0.0));

      // Revert back to Original (English)
      const originalTrack = AudioTrack(
        label: 'Original (English)',
        langCode: 'en',
        type: 'Original',
      );
      ctrl.setAudioLanguage(originalTrack);

      expect(ctrl.activeAudioLang.value, equals('Original (English)'));
      expect(ctrl.hasAlternateAudioTrack, isFalse);
      expect(ctrl.audioTrackController, isNull);
      expect(ctrl.videoPlayerController.value.volume, equals(1.0));

      ctrl.onClose();
      TowerPlayerRegistry.unregister(ctrl);
    });
  });
}
