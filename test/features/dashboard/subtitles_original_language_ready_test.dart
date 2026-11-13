import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/subtitles_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  tearDown(Get.reset);

  group('Subtitles Original Language Ready Tests', () {
    test('VideoMapParser auto-injects original language subtitles when transcriptionUrl is present', () {
      final rawVideoData = <String, dynamic>{
        'id': 'test_video_phone_cheyye',
        'title': 'phone cheyye',
        'description': 'Test phone cheyye video description',
        'language': 'en',
        'media': {
          'subtitles': {
            'hi': 'https://firebasestorage.googleapis.com/v0/b/truthworld/subtitles/job_1/hi.srt',
          },
          'transcriptionUrl': 'https://storage.googleapis.com/truthworld/transcripts/job_1/full.json',
        },
      };

      final video = VideoMapParser.parse(rawVideoData);

      expect(video.mediaSubtitles.containsKey('hi'), isTrue);
      expect(video.mediaSubtitles.containsKey('en'), isTrue);
      expect(video.mediaSubtitles['en'], 'https://storage.googleapis.com/truthworld/transcripts/job_1/full.json');
    });

    test('Video.mediaSubtitles getter merges transcriptionUrl for original language when missing from direct map', () {
      final video = Video(
        id: 'test_vid_2',
        title: 'phone cheyye',
        description: 'Testing original subtitle recovery',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        ownerId: 'owner_1',
        channelId: 'channel_1',
        channelName: 'Channel One',
        category: 'Tech',
        tags: const ['tech'],
        language: 'en',
        mediaSubtitles: const {
          'hi': 'https://firebasestorage.googleapis.com/v0/b/truthworld/subtitles/job_1/hi.srt',
        },
        transcriptionUrl: 'https://storage.googleapis.com/truthworld/transcripts/job_1/full.json',
      );

      expect(video.mediaSubtitles.containsKey('hi'), isTrue);
      expect(video.mediaSubtitles.containsKey('en'), isTrue);
      expect(video.mediaSubtitles['en'], 'https://storage.googleapis.com/truthworld/transcripts/job_1/full.json');
    });

    test('SubtitlesController hasPublishedSubtitles and availableLanguagesWithSubtitles recognize original language', () {
      final controller = Get.put(SubtitlesController());

      final video = Video(
        id: 'test_vid_3',
        title: 'phone cheyye',
        description: 'Original language ready in studio',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        ownerId: 'owner_1',
        channelId: 'channel_1',
        channelName: 'Channel One',
        category: 'Tech',
        tags: const ['tech'],
        language: 'en',
        mediaSubtitles: const {
          'hi': 'https://firebasestorage.googleapis.com/v0/b/truthworld/subtitles/job_1/hi.srt',
        },
        transcriptionUrl: 'https://storage.googleapis.com/truthworld/transcripts/job_1/full.json',
      );

      controller.selectedVideo.value = video;

      // Has published subtitles for original language
      expect(controller.hasPublishedSubtitles('en'), isTrue);
      expect(controller.hasPublishedSubtitles('hi'), isTrue);

      // Available languages with subtitles includes both 'hi' and 'en'
      final available = controller.availableLanguagesWithSubtitles;
      expect(available.contains('en'), isTrue);
      expect(available.contains('hi'), isTrue);

      // Subtitle track status is published, never "Not added"
      expect(controller.getLanguageStatus('en'), SubtitleTrackStatus.published);
      expect(controller.getLanguageStatus('hi'), SubtitleTrackStatus.published);
    });

    test('determineDefaultLanguage selects original video language when subtitles or transcription are ready', () {
      final controller = Get.put(SubtitlesController());

      final video = Video(
        id: 'test_vid_4',
        title: 'phone cheyye',
        description: 'Testing default language resolution',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        ownerId: 'owner_1',
        channelId: 'channel_1',
        channelName: 'Channel One',
        category: 'Tech',
        tags: const ['tech'],
        language: 'en',
        transcriptionUrl: 'https://storage.googleapis.com/truthworld/transcripts/job_1/full.json',
      );

      final subs = video.mediaSubtitles;
      final ordered = controller.getOrderedLanguagesForVideo(video, subs);
      final defaultLang = controller.determineDefaultLanguage(video, subs, ordered);

      expect(defaultLang, 'en');
    });
  });
}
