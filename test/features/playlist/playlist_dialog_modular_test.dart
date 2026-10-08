import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_dialog_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/claim_source_submission_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/stats_for_nerds_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import '../../test_helpers/mock_firebase.dart';

class _FakeVideoPlayerPlatform extends VideoPlayerPlatform {
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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleVideo = Video.fromMap({
    'title': 'Test Video',
    'channelId': 'chan_test_1',
    'channelName': 'TruthWorld Studio',
    'videoUrl': 'https://example.com/video.mp4',
    'thumbnailUrl': 'https://example.com/thumb.jpg',
    'duration': '05:32',
    'durationMs': 332000,
    'views': 120,
    'ownerId': 'usr_test_1',
  }, 'vid_001');

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (methodCall) async => '.',
    );
    await GetStorage.init();
    VideoPlayerPlatform.instance = _FakeVideoPlayerPlatform();
    await setupMockFirebase();
  });

  setUp(() {
    Get.reset();
    Get.testMode = true;
    if (!Get.isRegistered<AuthService>()) {
      Get.put<AuthService>(AuthService(), permanent: true);
    }
    if (!Get.isRegistered<ConnectivityService>()) {
      Get.put<ConnectivityService>(ConnectivityService(), permanent: true);
    }
  });

  tearDown(Get.reset);

  group('PlaylistDialogController Tests', () {
    test('initializes with default values and animation controllers', () {
      final ctrl = PlaylistDialogController();
      ctrl.onInit();

      expect(ctrl.isCreatingPlaylist.value, isFalse);
      expect(ctrl.isAddingToPlaylist.value, isFalse);
      expect(ctrl.selectedPlaylistId.value, isEmpty);
      expect(ctrl.isPublicNewPlaylist.value, isFalse);
      expect(ctrl.newPlaylistCtrl.text, isEmpty);
      expect(ctrl.scaleController, isNotNull);
      expect(ctrl.listController, isNotNull);

      ctrl.onClose();
    });

    test('setSelectedPlaylist and selectPlaylist update state correctly', () {
      final ctrl = PlaylistDialogController();
      ctrl.onInit();

      ctrl.setSelectedPlaylist('pl_123');
      expect(ctrl.selectedPlaylistId.value, 'pl_123');

      ctrl.resetForm();
      expect(ctrl.selectedPlaylistId.value, isEmpty);
      expect(ctrl.isCreatingPlaylist.value, isFalse);
      expect(ctrl.isAddingToPlaylist.value, isFalse);

      ctrl.onClose();
    });

    test('toggleCreateForm toggles showCreateForm correctly', () {
      final ctrl = PlaylistDialogController();
      ctrl.onInit();

      expect(ctrl.showCreateForm.value, isFalse);
      ctrl.toggleCreateForm();
      expect(ctrl.showCreateForm.value, isTrue);
      ctrl.toggleCreateForm();
      expect(ctrl.showCreateForm.value, isFalse);

      ctrl.onClose();
    });

    test('isPlaylistToggling tracks per-playlist toggle state', () {
      final ctrl = PlaylistDialogController();
      ctrl.onInit();

      expect(ctrl.isPlaylistToggling('pl_abc'), isFalse);
      ctrl.togglingPlaylistIds.add('pl_abc');
      expect(ctrl.isPlaylistToggling('pl_abc'), isTrue);

      ctrl.resetForm();
      expect(ctrl.isPlaylistToggling('pl_abc'), isFalse);

      ctrl.onClose();
    });

    test('createNewPlaylist rejects empty and invalid names gracefully', () async {
      final ctrl = PlaylistDialogController();
      ctrl.onInit();

      ctrl.newPlaylistCtrl.text = '';
      final result1 = await ctrl.createNewPlaylist('vid_001');
      expect(result1, isFalse);

      ctrl.newPlaylistCtrl.text = '   ';
      final result2 = await ctrl.createNewPlaylist('vid_001');
      expect(result2, isFalse);

      ctrl.onClose();
    });
  });

  group('ClaimSourceSubmissionController Tests', () {
    test('initializes and validates empty URL as invalid', () {
      final ctrl = ClaimSourceSubmissionController(video: sampleVideo);
      ctrl.onInit();

      expect(ctrl.isSubmitting.value, isFalse);
      expect(ctrl.validateForm(), isFalse);

      ctrl.onClose();
    });

    test('validates valid URL correctly and sanitizes input', () {
      final ctrl = ClaimSourceSubmissionController(video: sampleVideo);
      ctrl.onInit();

      ctrl.urlController.text = 'https://reuters.com/world/fact-check-article';
      expect(ctrl.validateForm(), isTrue);

      ctrl.resetForm();
      expect(ctrl.urlController.text, isEmpty);
      expect(ctrl.noteController.text, isEmpty);

      ctrl.onClose();
    });
  });

  group('StatsForNerdsController Tests', () {
    test('generates 12-char sCPN and valid CDN node', () {
      final vp = VideoPlayerController.networkUrl(
        Uri.parse('https://example.com/test.mp4'),
      );

      final playerCtrl = TowerPlayerController(
        videoPlayerController: vp,
        tag: 'test_vid_123',
      );
      final statsCtrl = StatsForNerdsController(playerCtrl: playerCtrl);
      statsCtrl.onInit();

      expect(statsCtrl.scpn.length, 12);
      expect(statsCtrl.cdnNode, isNotEmpty);
      expect(statsCtrl.decodedFrames.value, 0);
      expect(statsCtrl.droppedFrames.value, 0);

      // Bitrate estimation
      expect(statsCtrl.getEstimatedBitrate(1920), '4200 Kbps');
      expect(statsCtrl.getEstimatedBitrate(1280), '2400 Kbps');
      expect(statsCtrl.getEstimatedBitrate(854), '1100 Kbps');
      expect(statsCtrl.getEstimatedBitrate(480), '500 Kbps');

      // Bandwidth formatting
      expect(statsCtrl.fmtBw(0), '0 kbps');
      expect(statsCtrl.fmtBw(500), '500 kbps');
      expect(statsCtrl.fmtBw(2500), '2.5 Mbps');

      statsCtrl.onClose();
      playerCtrl.onClose();
      vp.dispose();
    });
  });
}
