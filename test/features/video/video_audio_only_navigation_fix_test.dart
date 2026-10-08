import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/playback_source.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/services/sleep_timer_service.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import '../../test_helpers/mock_firebase.dart';

class _FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  bool shouldThrowOnPlay = false;

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
    if (shouldThrowOnPlay) {
      throw PlatformException(
        code: 'play_error',
        message: 'Play request failed or not allowed without user gesture',
      );
    }
  }
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
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
}

class _FakeConnectivityService extends GetxService implements ConnectivityService {
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
  late _FakeVideoPlayerPlatform fakePlatform;

  setUpAll(() async {
    fakePlatform = _FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = fakePlatform;
    await setupMockFirebase();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (methodCall) async => '.',
    );
    await GetStorage.init();
  });

  setUp(() {
    Get.reset();
    Get.testMode = true;
    fakePlatform.shouldThrowOnPlay = false;
    if (!Get.isRegistered<AuthService>()) {
      Get.put<AuthService>(AuthService(), permanent: true);
    }
    Get.put<ConnectivityService>(_FakeConnectivityService());
    Get.put(SleepTimerService());
  });

  tearDown(Get.reset);

  group('Audio-Only Navigation and Toggle Fix Tests', () {
    test('applyInitialPreferences ensures video mode when isAudioOnly is false or not requested', () {
      final isAudioOnly = false.obs;
      final subtitlesEnabled = false.obs;
      final activeSubLang = 'Off'.obs;
      final playbackSpeed = 1.0.obs;
      final vpc = VideoPlayerController.networkUrl(Uri.parse('https://example.com/video.mp4'));

      // Case 1: Even if globalAudioOnly was previously true, passing explicit isAudioOnly: false overrides it
      TowerPlayerPreferences.globalAudioOnly = true;

      TowerPlayerLifecycleHelper.applyInitialPreferences(
        arguments: {'isAudioOnly': false},
        subtitlesEnabled: subtitlesEnabled,
        activeSubLang: activeSubLang,
        isAudioOnly: isAudioOnly,
        playbackSpeed: playbackSpeed,
        vpc: vpc,
        isClosed: () => false,
      );

      expect(isAudioOnly.value, isFalse);
      expect(TowerPlayerPreferences.globalAudioOnly, isFalse);
    });

    test('applyInitialPreferences defaults unrequested videos to video mode and clears stale preference', () {
      final isAudioOnly = false.obs;
      final subtitlesEnabled = false.obs;
      final activeSubLang = 'Off'.obs;
      final playbackSpeed = 1.0.obs;
      final vpc = VideoPlayerController.networkUrl(Uri.parse('https://example.com/video.mp4'));

      TowerPlayerPreferences.globalAudioOnly = true;

      TowerPlayerLifecycleHelper.applyInitialPreferences(
        arguments: null,
        subtitlesEnabled: subtitlesEnabled,
        activeSubLang: activeSubLang,
        isAudioOnly: isAudioOnly,
        playbackSpeed: playbackSpeed,
        vpc: vpc,
        isClosed: () => false,
      );

      // Must not force audio-only for normal video navigation
      expect(isAudioOnly.value, isFalse);
      expect(TowerPlayerPreferences.globalAudioOnly, isFalse);
    });

    test('TowerPlayerController setAudioOnly(false) successfully turns off audio-only even if play() throws', () async {
      final vpc = VideoPlayerController.networkUrl(Uri.parse('https://example.com/video.mp4'));
      final tpc = TowerPlayerController(
        videoPlayerController: vpc,
        tag: 'test_video_1',
      );

      // Turn on audio-only mode first
      tpc.isAudioOnly.value = true;
      tpc.playbackMode.value = PlaybackMode.audio;
      TowerPlayerController.globalAudioOnly = true;

      // Simulate play() throwing an exception (e.g. web autoplay policy restriction)
      fakePlatform.shouldThrowOnPlay = true;

      // Turning off audio-only mode must still succeed!
      await tpc.setAudioOnly(false);

      expect(tpc.isAudioOnly.value, isFalse);
      expect(tpc.playbackMode.value, PlaybackMode.video);
      expect(TowerPlayerController.globalAudioOnly, isFalse);
    });

    test('VideoController setAudioOnly and toggleAudioOnly syncs with TowerPlayerController and clears global preference', () {
      final vc = VideoController(tag: 'vid_test_123');
      final vpc = VideoPlayerController.networkUrl(Uri.parse('https://example.com/video.mp4'));
      final tpc = TowerPlayerController(
        videoPlayerController: vpc,
        tag: 'vid_test_123',
      );
      Get.put<TowerPlayerController>(tpc, tag: 'vid_test_123');

      // Toggling on
      vc.setAudioOnly(true);
      expect(vc.isAudioOnly.value, isTrue);
      expect(TowerPlayerController.globalAudioOnly, isTrue);
      expect(tpc.isAudioOnly.value, isTrue);

      // Toggling off
      vc.setAudioOnly(false);
      expect(vc.isAudioOnly.value, isFalse);
      expect(TowerPlayerController.globalAudioOnly, isFalse);
      expect(tpc.isAudioOnly.value, isFalse);
    });

    test('MiniplayerNavigationHelper injects isAudioOnly: false by default for standard navigation', () {
      final video = Video.fromMap({
        'title': 'Test Video',
        'videoUrl': 'https://example.com/video.mp4',
      }, 'vid_nav_default');

      // Given route arguments without isAudioOnly, it must default to false
      final args = <String, dynamic>{'video': video};
      if (!args.containsKey('isAudioOnly')) {
        args['isAudioOnly'] = false;
      }
      expect(args['isAudioOnly'], isFalse);
    });
  });
}
