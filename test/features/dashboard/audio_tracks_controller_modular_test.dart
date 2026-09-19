import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audio_tracks_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import '../../test_helpers/mock_firebase.dart';

Video _createTestVideo({
  String id = 'video_1',
  String title = 'Test Multi-Language Video',
  String description = 'Test description',
  List<String> tags = const ['test', 'audio'],
  Map<String, String> audioTracks = const {
    'en': 'https://example.com/en.mp3',
    'es': 'https://example.com/es.mp3',
  },
}) {
  return Video(
    id: id,
    title: title,
    description: description,
    videoUrl: 'https://example.com/video.mp4',
    thumbnailUrl: 'https://example.com/thumb.jpg',
    ownerId: 'user_1',
    channelId: 'test_channel_123',
    channelName: 'Test Channel',
    category: 'Tech',
    tags: tags,
    audioTracks: audioTracks,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  setUp(Get.reset);
  tearDown(Get.reset);

  group('AudioTrack Models Tests', () {
    test('AudioTrackItem instantiation and properties', () {
      final item = AudioTrackItem(
        id: 'track_1',
        languageCode: 'en',
        languageName: 'English (Base)',
        audioUrl: 'https://example.com/en.mp3',
        isBaseTrack: true,
        isResolved: true,
      );

      expect(item.id, equals('track_1'));
      expect(item.languageCode, equals('en'));
      expect(item.languageName, equals('English (Base)'));
      expect(item.audioUrl, equals('https://example.com/en.mp3'));
      expect(item.isBaseTrack, isTrue);
      expect(item.isResolved, isTrue);
    });

    test('CommentaryTrackItem serialization and deserialization', () {
      final track = CommentaryTrackItem(
        id: 'c_1',
        title: 'Director Cut Commentary',
        role: 'Director Commentary',
        videoUrl: 'https://example.com/dir.mp4',
        audioUrl: 'https://example.com/dir.mp3',
        langCode: 'en',
        uploadedAt: '2026-09-18T10:00:00Z',
        fileSizeMB: 45.5,
      );

      final map = track.toMap();
      expect(map['id'], equals('c_1'));
      expect(map['title'], equals('Director Cut Commentary'));
      expect(map['role'], equals('Director Commentary'));
      expect(map['fileSizeMB'], equals('45.5'));

      final restored = CommentaryTrackItem.fromMap('c_1', map);
      expect(restored.id, equals('c_1'));
      expect(restored.title, equals('Director Cut Commentary'));
      expect(restored.fileSizeMB, equals(45.5));
    });

    test('getSupportedLanguageName resolves codes accurately', () {
      expect(getSupportedLanguageName('en'), equals('English (Base)'));
      expect(getSupportedLanguageName('hi'), equals('Hindi (हिन्दी)'));
      expect(getSupportedLanguageName('es'), equals('Spanish (Español)'));
      expect(getSupportedLanguageName('fr'), equals('French (Français)'));
      expect(getSupportedLanguageName('unknown_code'), equals('UNKNOWN_CODE'));
    });
  });

  group('AudioTracksLanguageManager Tests', () {
    late AudioTracksLanguageManager manager;

    setUp(() {
      manager = AudioTracksLanguageManager();
    });

    tearDown(() {
      manager.dispose();
    });

    test('setActiveTab and toggleRequestsPanel update state reactively', () {
      expect(manager.activeTab.value, equals('tracks'));
      manager.setActiveTab('languages');
      expect(manager.activeTab.value, equals('languages'));

      expect(manager.showRequestsPanel.value, isFalse);
      manager.toggleRequestsPanel();
      expect(manager.showRequestsPanel.value, isTrue);
      manager.toggleRequestsPanel();
      expect(manager.showRequestsPanel.value, isFalse);
    });

    test('addLanguageLayer adds unique language and invokes callback', () {
      var callbackCalled = false;
      var successMessage = '';

      manager.addLanguageLayer(
        'de',
        onLanguageAdded: (code) {
          callbackCalled = true;
        },
        onShowSuccess: (msg) {
          successMessage = msg;
        },
      );

      expect(manager.availableLanguages.contains('de'), isTrue);
      expect(manager.selectedLanguage.value, equals('de'));
      expect(callbackCalled, isTrue);
      expect(successMessage, contains('German'));
    });
  });

  group('AudioTracksEditorManager Tests', () {
    late AudioTracksEditorManager editorManager;

    setUp(() {
      editorManager = AudioTracksEditorManager();
    });

    test('parseAudioTracksForLanguage creates tracks with resolved status', () async {
      await editorManager.parseAudioTracksForLanguage(
        'en',
        {'en': 'https://example.com/audio_en.mp3'},
        selectedVideoId: 'v_10',
      );

      expect(editorManager.currentTracks.length, equals(1));
      final track = editorManager.currentTracks.first;
      expect(track.id, equals('v_10_en'));
      expect(track.languageCode, equals('en'));
      expect(track.isBaseTrack, isTrue);
      expect(track.isResolved, isTrue);
    });

    test('updateTrackUrl updates track and flags unsaved changes', () {
      final initialTrack = AudioTrackItem(
        id: 't_1',
        languageCode: 'es',
        languageName: 'Spanish (Español)',
        audioUrl: 'https://example.com/old.mp3',
      );
      editorManager.currentTracks.value = [initialTrack];
      expect(editorManager.hasUnsavedChanges.value, isFalse);

      editorManager.updateTrackUrl(0, 'https://example.com/new.mp3');
      expect(editorManager.currentTracks.first.audioUrl, equals('https://example.com/new.mp3'));
      expect(editorManager.hasUnsavedChanges.value, isTrue);
    });
  });

  group('AudioTracksController Coordinator Tests', () {
    late AudioTracksController controller;

    setUp(() {
      Get.testMode = true;
      controller = Get.put(AudioTracksController());
    });

    tearDown(() {
      controller.onClose();
    });

    test('initializes with default state and sub-managers', () {
      expect(controller.contextManager, isNotNull);
      expect(controller.languageManager, isNotNull);
      expect(controller.editorManager, isNotNull);
      expect(controller.uploadManager, isNotNull);
      expect(controller.commentaryManager, isNotNull);
      expect(controller.activeTab.value, equals('tracks'));
      expect(controller.isUploading.value, isFalse);
    });

    test('search filtering filters videos by title, description, and tags', () {
      final v1 = _createTestVideo(id: 'v1', title: 'Flutter Multi-Track Guide');
      final v2 = _createTestVideo(id: 'v2', title: 'Podcast Commentary', tags: ['audio', 'commentary']);
      final v3 = _createTestVideo(id: 'v3', title: 'TruthWorld News', description: 'Deep dive into local issues');

      controller.videos.value = [v1, v2, v3];
      controller.filteredVideos.value = [v1, v2, v3];

      controller.setSearchQuery('podcast');
      expect(controller.filteredVideos.length, equals(1));
      expect(controller.filteredVideos.first.id, equals('v2'));

      controller.setSearchQuery('deep dive');
      expect(controller.filteredVideos.length, equals(1));
      expect(controller.filteredVideos.first.id, equals('v3'));

      controller.setSearchQuery('');
      expect(controller.filteredVideos.length, equals(3));
    });

    test('getLanguageName resolves supported languages', () {
      expect(controller.getLanguageName('en'), equals('English (Base)'));
      expect(controller.getLanguageName('te'), equals('Telugu (తెలుగు)'));
      expect(controller.getLanguageName('ja'), equals('Japanese (日本語)'));
    });

    test('selectVideo null clears editor and language state', () async {
      controller.availableLanguages.value = ['en', 'es'];
      controller.selectedLanguage.value = 'es';

      await controller.selectVideo(null);

      expect(controller.selectedVideo.value, isNull);
      expect(controller.availableLanguages, isEmpty);
      expect(controller.selectedLanguage.value, isEmpty);
      expect(controller.currentTracks, isEmpty);
      expect(controller.commentaryTracks, isEmpty);
    });
  });
}
