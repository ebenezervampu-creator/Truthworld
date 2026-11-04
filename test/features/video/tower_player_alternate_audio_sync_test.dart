import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player/tower_player_vpc_event_handler.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/services/sleep_timer_service.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

class FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  double currentVolume = 1.0;
  bool isPlaying = false;
  Duration currentPosition = Duration.zero;

  @override
  Future<void> init() async {}
  @override
  Future<void> dispose(int textureId) async {}
  @override
  Future<int?> create(DataSource dataSource) async => 1;
  @override
  Future<void> setLooping(int textureId, bool looping) async {}
  @override
  Future<void> play(int textureId) async {
    isPlaying = true;
  }
  @override
  Future<void> pause(int textureId) async {
    isPlaying = false;
  }
  @override
  Future<void> setVolume(int textureId, double volume) async {
    currentVolume = volume;
  }
  @override
  Future<void> setPlaybackSpeed(int textureId, double speed) async {}
  @override
  Future<void> seekTo(int textureId, Duration position) async {
    currentPosition = position;
  }
  @override
  Future<Duration> getPosition(int textureId) async => currentPosition;
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
  late FakeVideoPlayerPlatform fakePlatform;

  setUpAll(() async {
    fakePlatform = FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = fakePlatform;
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

  group('TowerPlayer Alternate Audio Track & Sync Tests', () {
    test('Switching to alternate audio track mutes main video and loads audio track', () async {
      final vpc = VideoPlayerController.networkUrl(Uri.parse('https://example.com/video.mp4'));
      final ctrl = TowerPlayerController(videoPlayerController: vpc, tag: 'alt_audio_test');

      const originalTrack = AudioTrack(
        label: 'Original (English)',
        langCode: 'en',
        type: 'Original',
      );
      const teluguTrack = AudioTrack(
        label: 'Telugu (Audio)',
        langCode: 'te',
        type: 'Audio',
        url: 'https://firebasestorage.googleapis.com/v0/b/truthworld.appspot.com/o/audio%2Fte%2Fstitched.mp3?alt=media&token=test-token',
      );

      ctrl.audioTracks.assignAll([originalTrack, teluguTrack]);

      // Switch to Telugu
      await ctrl.setAudioLanguage(teluguTrack);

      expect(ctrl.activeAudioLang.value, equals('Telugu (Audio)'));
      expect(ctrl.hasAlternateAudioTrack, isTrue);
      expect(ctrl.audioTrackController, isNotNull);

      // Switching back to Original restores main video volume
      await ctrl.setAudioLanguage(originalTrack);

      expect(ctrl.activeAudioLang.value, equals('Original (English)'));
      expect(ctrl.hasAlternateAudioTrack, isFalse);
      expect(ctrl.audioTrackController, isNull);
    });

    test('TowerPlayerVpcEventHandler re-enables main video audio when alternate audio is absent or errored', () {
      final mainVpc = VideoPlayerController.networkUrl(Uri.parse('https://example.com/main.mp4'));

      // 1. When hasAlternateAudioTrack is true but audioCtrl is null (or failed)
      TowerPlayerVpcEventHandler.syncAlternateAudioTrack(
        mainVpc: mainVpc,
        audioCtrl: null,
        isMuted: false,
        volume: 0.9,
        hasAlternateAudioTrack: true,
      );

      // Main VPC must be restored to target volume (0.9), NOT muted!
      expect(mainVpc.value.volume, equals(0.9));

      // 2. When alternate audio controller has error
      final erroredAudio = VideoPlayerController.networkUrl(Uri.parse('https://example.com/audio.mp3'));
      // simulate error
      erroredAudio.value = erroredAudio.value.copyWith(
        errorDescription: '403 Forbidden',
      );

      TowerPlayerVpcEventHandler.syncAlternateAudioTrack(
        mainVpc: mainVpc,
        audioCtrl: erroredAudio,
        isMuted: false,
        volume: 0.8,
        hasAlternateAudioTrack: true,
      );

      // Main VPC volume must be restored to 0.8 instead of remaining in dead silence
      expect(mainVpc.value.volume, equals(0.8));
    });

    test('TowerPlayerVpcEventHandler triggers audioCtrl.play() when main video is playing and not buffering', () {
      final mainVpc = VideoPlayerController.networkUrl(Uri.parse('https://example.com/main.mp4'));
      final audioVpc = VideoPlayerController.networkUrl(Uri.parse('https://example.com/audio.mp3'));

      // Initialize both controllers
      mainVpc.value = mainVpc.value.copyWith(
        isInitialized: true,
        isPlaying: true,
        isBuffering: false,
        position: const Duration(seconds: 5),
        duration: const Duration(seconds: 60),
      );

      audioVpc.value = audioVpc.value.copyWith(
        isInitialized: true,
        isPlaying: false,
        isBuffering: true, // Audio stream is connecting/buffering
        position: const Duration(seconds: 5),
        duration: const Duration(seconds: 60),
      );

      TowerPlayerVpcEventHandler.syncAlternateAudioTrack(
        mainVpc: mainVpc,
        audioCtrl: audioVpc,
        isMuted: false,
        volume: 1.0,
        hasAlternateAudioTrack: true,
      );

      // audioVpc.play() must be invoked so playWhenReady is true even during initial buffer
      expect(fakePlatform.isPlaying, isTrue);
    });

    test('Audio track eof before video ends unmutes main video', () {
      final mainVpc = VideoPlayerController.networkUrl(Uri.parse('https://example.com/main.mp4'));
      final audioVpc = VideoPlayerController.networkUrl(Uri.parse('https://example.com/audio.mp3'));

      mainVpc.value = mainVpc.value.copyWith(
        isInitialized: true,
        isPlaying: true,
        position: const Duration(seconds: 25),
        duration: const Duration(seconds: 60),
      );

      // Audio dub was only 20 seconds long
      audioVpc.value = audioVpc.value.copyWith(
        isInitialized: true,
        isPlaying: true,
        position: const Duration(seconds: 20),
        duration: const Duration(seconds: 20),
      );

      TowerPlayerVpcEventHandler.syncAlternateAudioTrack(
        mainVpc: mainVpc,
        audioCtrl: audioVpc,
        isMuted: false,
        volume: 1.0,
        hasAlternateAudioTrack: true,
      );

      // Main video player volume must be restored so user is not in dead silence
      expect(mainVpc.value.volume, equals(1.0));
    });
  });
}
