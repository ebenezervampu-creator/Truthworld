import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/services/sleep_timer_service.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

class FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  @override
  Future<void> init() async {}
  @override
  Future<void> dispose(int textureId) async {}
  @override
  Future<int?> create(DataSource dataSource) async => 1;
  @override
  Future<void> setLooping(int textureId, bool looping) async {}
  @override
  Future<void> play(int textureId) async {}
  @override
  Future<void> pause(int textureId) async {}
  @override
  Future<void> setVolume(int textureId, double volume) async {}
  @override
  Future<void> setPlaybackSpeed(int textureId, double speed) async {}
  @override
  Future<void> seekTo(int textureId, Duration position) async {}
  @override
  Future<Duration> getPosition(int textureId) async => Duration.zero;
  @override
  Stream<VideoEvent> videoEventsFor(int textureId) => const Stream.empty();
  @override
  Widget buildView(int textureId) => const SizedBox();
  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
}

class FakeConnectivityService extends GetxService implements ConnectivityService {
  @override
  ConnectivityResult get connectionStatus => ConnectivityResult.wifi;
  @override
  bool get isConnected => true;
  @override
  bool get isWifi => true;
  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => const Stream.empty();
  @override
  Stream<ConnectivityResult> get onConnectivityRestored => const Stream.empty();
  @override
  Future<ConnectivityService> init() async => this;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    VideoPlayerPlatform.instance = FakeVideoPlayerPlatform();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (methodCall) async => '.',
    );
    await GetStorage.init();
  });

  setUp(() {
    Get.reset();
    Get.put<ConnectivityService>(FakeConnectivityService());
    Get.put(SleepTimerService());
  });

  tearDown(Get.reset);

  group('TowerPlayerPreferences Tests', () {
    test('Can update and read persistent preferences', () {
      TowerPlayerPreferences.globalSubtitlesEnabled = true;
      expect(TowerPlayerPreferences.globalSubtitlesEnabled, isTrue);

      TowerPlayerPreferences.globalActiveSubLang = 'es';
      expect(TowerPlayerPreferences.globalActiveSubLang, 'es');

      TowerPlayerPreferences.globalAudioOnly = true;
      expect(TowerPlayerPreferences.globalAudioOnly, isTrue);

      TowerPlayerPreferences.globalPlaybackSpeed = 1.5;
      expect(TowerPlayerPreferences.globalPlaybackSpeed, 1.5);

      TowerPlayerPreferences.globalQualityPreference = '1080p';
      expect(TowerPlayerPreferences.globalQualityPreference, '1080p');

      // Reset to defaults
      TowerPlayerPreferences.globalSubtitlesEnabled = false;
      TowerPlayerPreferences.globalActiveSubLang = 'en';
      TowerPlayerPreferences.globalAudioOnly = false;
      TowerPlayerPreferences.globalPlaybackSpeed = 1.0;
      TowerPlayerPreferences.globalQualityPreference = null;
    });

    test('Subtitle text style generation and style reset', () {
      final style = TowerPlayerPreferences.getSubtitleTextStyle(
        fontFamily: 'Roboto',
        color: Colors.white,
        fontSize: 18.0,
        fontWeight: FontWeight.bold,
        height: 1.2,
        shadows: const [],
      );

      expect(style.fontSize, 18.0);
      expect(style.fontWeight, FontWeight.bold);

      TowerPlayerPreferences.resetSubtitleStyleToDefault();
      expect(TowerPlayerPreferences.globalSubtitleFontSizeOption.value, 'Normal');
      expect(TowerPlayerPreferences.globalSubtitleTextColor.value, Colors.white);
    });
  });

  group('TowerPlayerRegistry Tests', () {
    test('Register, lookup by tag or active, pause all, and unregister', () {
      final vpc1 = VideoPlayerController.networkUrl(Uri.parse('https://example.com/video1.mp4'));
      final ctrl1 = TowerPlayerController(videoPlayerController: vpc1, tag: 'ctrl_1');

      final vpc2 = VideoPlayerController.networkUrl(Uri.parse('https://example.com/video2.mp4'));
      final ctrl2 = TowerPlayerController(videoPlayerController: vpc2, tag: 'ctrl_2');

      TowerPlayerRegistry.register(ctrl1);
      TowerPlayerRegistry.register(ctrl2);

      expect(TowerPlayerRegistry.activePlayers.contains(ctrl1), isTrue);
      expect(TowerPlayerRegistry.activePlayers.contains(ctrl2), isTrue);

      // Lookup by specific tag
      expect(TowerPlayerRegistry.getForTagOrActive('ctrl_1'), equals(ctrl1));
      expect(TowerPlayerRegistry.getForTagOrActive('ctrl_2'), equals(ctrl2));

      // Fallback when tag is null or unfound returns the last active player
      expect(TowerPlayerRegistry.getForTagOrActive(null), equals(ctrl2));
      expect(TowerPlayerRegistry.getForTagOrActive('non_existent'), equals(ctrl2));

      // Pause all except ctrl2
      ctrl1.isPlaying.value = true;
      ctrl2.isPlaying.value = true;
      TowerPlayerRegistry.pauseAllActivePlayers(except: ctrl2);
      expect(ctrl1.isPlaying.value, isFalse);

      // Unregister
      TowerPlayerRegistry.unregister(ctrl1);
      TowerPlayerRegistry.unregister(ctrl2);
      expect(TowerPlayerRegistry.activePlayers.contains(ctrl1), isFalse);
      expect(TowerPlayerRegistry.activePlayers.contains(ctrl2), isFalse);
    });
  });

  group('TowerPlayerAdPolicyEvaluator Tests', () {
    test('Correctly identifies real ads and suppression criteria', () {
      expect(TowerPlayerAdPolicyEvaluator.isPremiumUser(), isFalse);
      expect(TowerPlayerAdPolicyEvaluator.shouldSuppressAds(isAudioOnly: false), isFalse);
      expect(TowerPlayerAdPolicyEvaluator.hasRealVideoAds(), isFalse);
    });
  });

  group('TowerPlayerVpcEventHandler Tests', () {
    test('Filters transient DOM errors correctly', () {
      expect(
        TowerPlayerVpcEventHandler.isTransientDomError(
          'The play() request was interrupted by a call to pause().',
          '',
        ),
        isTrue,
      );
      expect(
        TowerPlayerVpcEventHandler.isTransientDomError('AbortError', ''),
        isTrue,
      );
      expect(
        TowerPlayerVpcEventHandler.isTransientDomError(
          'Failed to load media: 404 Not Found',
          'Network failure',
        ),
        isFalse,
      );
    });

    test('Volume normalization scale values', () {
      expect(TowerPlayerVpcEventHandler.getNormalizedVolumeScale(), 1.0);
    });

    test('Handles null or uninitialized audio controller gracefully', () {
      final mainVpc = VideoPlayerController.networkUrl(Uri.parse('https://example.com/main.mp4'));

      // Does not throw when audioCtrl is null
      TowerPlayerVpcEventHandler.syncAlternateAudioTrack(
        mainVpc: mainVpc,
        audioCtrl: null,
        isMuted: false,
        volume: 0.8,
      );

      // Does not throw when audioCtrl is uninitialized
      final audioVpc = VideoPlayerController.networkUrl(Uri.parse('https://example.com/audio.mp3'));
      TowerPlayerVpcEventHandler.syncAlternateAudioTrack(
        mainVpc: mainVpc,
        audioCtrl: audioVpc,
        isMuted: false,
        volume: 0.8,
      );

      expect(audioVpc.value.isInitialized, isFalse);
    });
  });

  group('TowerPlayerController Playback Control Tests', () {
    test('Reactive state and volume / mute toggling', () {
      final vpc = VideoPlayerController.networkUrl(Uri.parse('https://example.com/test.mp4'));
      final ctrl = TowerPlayerController(videoPlayerController: vpc);

      expect(ctrl.volume.value, 1.0);
      expect(ctrl.isMuted.value, isFalse);

      ctrl.setVolume(0.5);
      expect(ctrl.volume.value, 0.5);

      ctrl.toggleMute();
      expect(ctrl.isMuted.value, isTrue);

      ctrl.toggleMute();
      expect(ctrl.isMuted.value, isFalse);
      expect(ctrl.volume.value, 0.5);
    });

    test('Playback speed toggling and zoom scale', () {
      final vpc = VideoPlayerController.networkUrl(Uri.parse('https://example.com/test.mp4'));
      final ctrl = TowerPlayerController(videoPlayerController: vpc);

      expect(ctrl.playbackSpeed.value, 1.0);
      ctrl.setSpeed(1.25);
      expect(ctrl.playbackSpeed.value, 1.25);

      expect(ctrl.isZoomToFill.value, isFalse);
      expect(ctrl.zoomScale.value, 1.0);

      ctrl.toggleZoomToFill();
      expect(ctrl.isZoomToFill.value, isTrue);
      expect(ctrl.zoomScale.value, 1.0);

      ctrl.toggleZoomToFill();
      expect(ctrl.isZoomToFill.value, isFalse);
      expect(ctrl.zoomScale.value, 1.0);
    });

    test('Seek relative and seekTo controls', () async {
      final vpc = VideoPlayerController.networkUrl(Uri.parse('https://example.com/test.mp4'));
      final ctrl = TowerPlayerController(videoPlayerController: vpc);

      await ctrl.seekRelative(-10);
      await ctrl.seekTo(const Duration(seconds: 30));
      expect(ctrl.hasEnded, isFalse);
    });

    test('Aspect ratio and popup reactive observables', () {
      final vpc = VideoPlayerController.networkUrl(Uri.parse('https://example.com/test.mp4'));
      final ctrl = TowerPlayerController(videoPlayerController: vpc);

      expect(ctrl.aspectRatio.value, 16 / 9);
      ctrl.aspectRatio.value = 16 / 9;
      expect(ctrl.aspectRatio.value, 16 / 9);

      expect(ctrl.showCommentsPopup.value, isFalse);
      ctrl.showCommentsPopup.value = true;
      expect(ctrl.showCommentsPopup.value, isTrue);

      expect(ctrl.showTranscriptPopup.value, isFalse);
      ctrl.showTranscriptPopup.value = true;
      expect(ctrl.showTranscriptPopup.value, isTrue);

      expect(ctrl.showFactCheckPopup.value, isFalse);
      ctrl.showFactCheckPopup.value = true;
      expect(ctrl.showFactCheckPopup.value, isTrue);
    });

    test('Clean disposal on onClose()', () {
      final vpc = VideoPlayerController.networkUrl(Uri.parse('https://example.com/test.mp4'));
      final ctrl = Get.put(TowerPlayerController(videoPlayerController: vpc));

      expect(TowerPlayerRegistry.activePlayers.contains(ctrl), isTrue);

      Get.delete<TowerPlayerController>();
      expect(ctrl.isClosed, isTrue);
      expect(TowerPlayerRegistry.activePlayers.contains(ctrl), isFalse);
    });
  });
}
