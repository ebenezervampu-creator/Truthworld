import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/core/services/user_languages_service.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/models/video_chapter.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player/tower_player_track_sync_helper.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/services/sleep_timer_service.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart' hide VideoTrack;

import '../../test_helpers/mock_firebase.dart';

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
  late UserLanguagesService langService;

  setUpAll(() async {
    fakePlatform = FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = fakePlatform;
    await setupMockFirebase();
  });

  setUp(() {
    Get.reset();
    Get.put<ConnectivityService>(FakeConnectivityService());
    Get.put(SleepTimerService());
    langService = Get.put(UserLanguagesService());
  });

  tearDown(Get.reset);

  group('UserLanguagesService.isLanguageMatch - Track Matching', () {
    test('Matches tracks formatted as (Audio), (Video), Original (...), and clean codes', () {
      expect(langService.isLanguageMatch('Spanish (Audio)', 'es', 'Spanish'), isTrue);
      expect(langService.isLanguageMatch('Spanish (Video)', 'es', 'Spanish'), isTrue);
      expect(langService.isLanguageMatch('Original (Spanish)', 'es', 'Spanish'), isTrue);
      expect(langService.isLanguageMatch('', 'es', 'Spanish'), isTrue);
      expect(langService.isLanguageMatch('Spanish', '', 'Spanish'), isTrue);

      expect(langService.isLanguageMatch('Hindi (Audio)', 'hi', 'Hindi'), isTrue);
      expect(langService.isLanguageMatch('English (Audio)', 'en', 'Spanish'), isFalse);
      expect(langService.isLanguageMatch('Original (English)', 'en', 'Spanish'), isFalse);
    });
  });

  group('TowerPlayerTrackSyncHelper - Direct Playback in User Primary Language (YouTube-style)', () {
    test('Directly plays audio track in user primary language when available', () {
      langService.primaryLanguage.value = 'Spanish';

      final subtitleTracks = <SubtitleTrack>[].obs;
      final activeSubLang = 'Off'.obs;
      final audioTracks = <AudioTrack>[].obs;
      final activeAudioLang = ''.obs;
      final videoTracks = <VideoTrack>[].obs;
      final activeVideoLang = ''.obs;
      final chapters = <VideoChapter>[].obs;

      AudioTrack? selectedAudio;

      const originalAudio = AudioTrack(
        label: 'Original (English)',
        langCode: 'en',
      );
      const spanishAudio = AudioTrack(
        label: 'Spanish (Audio)',
        langCode: 'es',
        url: 'https://example.com/audio_es.mp3',
      );

      final mockVc = VideoController();
      mockVc.rxVideo.value = Video(
        id: 'test_vid_1',
        title: 'Test English Video',
        description: 'Description',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        ownerId: 'owner_1',
        channelId: 'ch_1',
        channelName: 'Channel 1',
        category: 'Education',
        audioTracks: const {'es': 'https://example.com/audio_es.mp3'},
        tags: const [],
      );

      mockVc.availableAudioTracks.assignAll([originalAudio, spanishAudio]);

      TowerPlayerTrackSyncHelper.syncTracks(
        vc: mockVc,
        subtitleTracks: subtitleTracks,
        activeSubLang: activeSubLang,
        setSubtitles: ({required enabled, track}) {},
        audioTracks: audioTracks,
        activeAudioLang: activeAudioLang,
        setAudioLanguage: (track) {
          selectedAudio = track;
          activeAudioLang.value = track.label;
        },
        videoTracks: videoTracks,
        activeVideoLang: activeVideoLang,
        setVideoLanguage: (_) {},
        chapters: chapters,
      );

      // Verify that the Spanish audio track is directly selected and played!
      expect(selectedAudio, isNotNull);
      expect(selectedAudio!.langCode, equals('es'));
      expect(selectedAudio!.label, equals('Spanish (Audio)'));
      expect(activeAudioLang.value, equals('Spanish (Audio)'));
    });

    test('Directly plays dubbed video track in user primary language when available', () {
      langService.primaryLanguage.value = 'Spanish';

      final subtitleTracks = <SubtitleTrack>[].obs;
      final activeSubLang = 'Off'.obs;
      final audioTracks = <AudioTrack>[].obs;
      final activeAudioLang = ''.obs;
      final videoTracks = <VideoTrack>[].obs;
      final activeVideoLang = ''.obs;
      final chapters = <VideoChapter>[].obs;

      VideoTrack? selectedVideo;

      const originalVideo = VideoTrack(
        label: 'Original (English)',
        langCode: 'en',
      );
      const spanishVideo = VideoTrack(
        label: 'Spanish (Video)',
        langCode: 'es',
        type: 'Video',
        url: 'https://example.com/video_es.mp4',
      );

      final mockVc = VideoController();
      mockVc.rxVideo.value = Video(
        id: 'test_vid_2',
        title: 'Test English Video',
        description: 'Description',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        ownerId: 'owner_1',
        channelId: 'ch_1',
        channelName: 'Channel 1',
        category: 'Education',
        dubbedVideos: const {'es': 'https://example.com/video_es.mp4'},
        tags: const [],
      );

      mockVc.availableVideoTracks.assignAll([originalVideo, spanishVideo]);

      TowerPlayerTrackSyncHelper.syncTracks(
        vc: mockVc,
        subtitleTracks: subtitleTracks,
        activeSubLang: activeSubLang,
        setSubtitles: ({required enabled, track}) {},
        audioTracks: audioTracks,
        activeAudioLang: activeAudioLang,
        setAudioLanguage: (_) {},
        videoTracks: videoTracks,
        activeVideoLang: activeVideoLang,
        setVideoLanguage: (track) {
          selectedVideo = track;
          activeVideoLang.value = track.label;
        },
        chapters: chapters,
      );

      // Verify that the dubbed Spanish video track was selected directly!
      expect(selectedVideo, isNotNull);
      expect(selectedVideo!.langCode, equals('es'));
      expect(selectedVideo!.label, equals('Spanish (Video)'));
      expect(activeVideoLang.value, equals('Spanish (Video)'));
    });

    test('When dubbed video track is selected, separate audio track overlay is bypassed', () {
      langService.primaryLanguage.value = 'Spanish';

      final subtitleTracks = <SubtitleTrack>[].obs;
      final activeSubLang = 'Off'.obs;
      final audioTracks = <AudioTrack>[].obs;
      final activeAudioLang = ''.obs;
      final videoTracks = <VideoTrack>[].obs;
      final activeVideoLang = ''.obs;
      final chapters = <VideoChapter>[].obs;

      AudioTrack? selectedAudio;
      VideoTrack? selectedVideo;

      const originalVideo = VideoTrack(
        label: 'Original (English)',
        langCode: 'en',
      );
      const spanishVideo = VideoTrack(
        label: 'Spanish (Video)',
        langCode: 'es',
        type: 'Video',
        url: 'https://example.com/video_es.mp4',
      );

      const originalAudio = AudioTrack(
        label: 'Original (English)',
        langCode: 'en',
      );
      const spanishAudio = AudioTrack(
        label: 'Spanish (Audio)',
        langCode: 'es',
        url: 'https://example.com/audio_es.mp3',
      );

      final mockVc = VideoController();
      mockVc.rxVideo.value = Video(
        id: 'test_vid_3',
        title: 'Test English Video',
        description: 'Description',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        ownerId: 'owner_1',
        channelId: 'ch_1',
        channelName: 'Channel 1',
        category: 'Education',
        dubbedVideos: const {'es': 'https://example.com/video_es.mp4'},
        audioTracks: const {'es': 'https://example.com/audio_es.mp3'},
        tags: const [],
      );

      mockVc.availableVideoTracks.assignAll([originalVideo, spanishVideo]);
      mockVc.availableAudioTracks.assignAll([originalAudio, spanishAudio]);

      TowerPlayerTrackSyncHelper.syncTracks(
        vc: mockVc,
        subtitleTracks: subtitleTracks,
        activeSubLang: activeSubLang,
        setSubtitles: ({required enabled, track}) {},
        audioTracks: audioTracks,
        activeAudioLang: activeAudioLang,
        setAudioLanguage: (track) {
          selectedAudio = track;
          activeAudioLang.value = track.label;
        },
        videoTracks: videoTracks,
        activeVideoLang: activeVideoLang,
        setVideoLanguage: (track) {
          selectedVideo = track;
          activeVideoLang.value = track.label;
        },
        chapters: chapters,
      );

      // Dubbed video track must be selected
      expect(selectedVideo, isNotNull);
      expect(selectedVideo!.label, equals('Spanish (Video)'));
      // Audio track overlay must NOT be selected because the video track already has Spanish audio
      expect(selectedAudio, isNull);
    });

    test('Automatically enables primary language subtitles when neither dubbed video nor dubbed audio is available', () {
      langService.primaryLanguage.value = 'Spanish';

      final subtitleTracks = <SubtitleTrack>[].obs;
      final activeSubLang = 'Off'.obs;
      final audioTracks = <AudioTrack>[].obs;
      final activeAudioLang = 'Original (English)'.obs;
      final videoTracks = <VideoTrack>[].obs;
      final activeVideoLang = 'Original (English)'.obs;
      final chapters = <VideoChapter>[].obs;

      SubtitleTrack? selectedSub;
      var subtitlesEnabled = false;

      const spanishSubtitle = SubtitleTrack(
        label: 'Spanish',
        langCode: 'es',
        url: 'https://example.com/subs_es.vtt',
      );

      final mockVc = VideoController();
      mockVc.rxVideo.value = Video(
        id: 'test_vid_4',
        title: 'Test English Video',
        description: 'Description',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        ownerId: 'owner_1',
        channelId: 'ch_1',
        channelName: 'Channel 1',
        category: 'Education',
        mediaSubtitles: const {'es': 'https://example.com/subs_es.vtt'},
        tags: const [],
      );

      mockVc.availableSubtitles.assignAll([spanishSubtitle]);

      TowerPlayerTrackSyncHelper.syncTracks(
        vc: mockVc,
        subtitleTracks: subtitleTracks,
        activeSubLang: activeSubLang,
        setSubtitles: ({required enabled, track}) {
          subtitlesEnabled = enabled;
          selectedSub = track;
        },
        audioTracks: audioTracks,
        activeAudioLang: activeAudioLang,
        setAudioLanguage: (_) {},
        videoTracks: videoTracks,
        activeVideoLang: activeVideoLang,
        setVideoLanguage: (_) {},
        chapters: chapters,
      );

      expect(subtitlesEnabled, isTrue);
      expect(selectedSub, isNotNull);
      expect(selectedSub!.langCode, equals('es'));
    });
  });
}
