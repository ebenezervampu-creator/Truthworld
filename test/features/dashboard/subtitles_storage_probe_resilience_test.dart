import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/config/app_config.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/utils/storage_utils.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/subtitles_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  setUp(() {
    Get.reset();
    StorageUtils.clearFastUrlCache();
  });

  tearDown(() {
    Get.reset();
  });

  group('Subtitles Storage & Probe Resilience Tests', () {
    test('StorageUtils.getFastDownloadUrl routes to Firebase Storage direct URL when CDN is disabled', () {
      AppConfig.enableCdnThumbnails = false;
      StorageUtils.clearFastUrlCache();

      const subtitlePath = 'subtitles/job_1793595614167_ba09819d/en.srt';
      final fastUrl = StorageUtils.getFastDownloadUrl(subtitlePath);

      // Must NOT route to cdn.truthworld.in when enableCdnThumbnails is false
      expect(fastUrl, isNot(contains('cdn.truthworld.in')));
      expect(fastUrl, contains('firebasestorage.googleapis.com'));
      expect(fastUrl, contains('subtitles%2Fjob_1793595614167_ba09819d%2Fen.srt'));
      expect(fastUrl, contains('alt=media'));
    });

    test('StorageUtils.getFastDownloadUrl routes to Cloud CDN when CDN is explicitly enabled', () {
      AppConfig.enableCdnThumbnails = true;
      StorageUtils.clearFastUrlCache();

      const subtitlePath = 'subtitles/job_1793595614167_ba09819d/en.srt';
      final cdnUrl = StorageUtils.getFastDownloadUrl(subtitlePath);

      expect(cdnUrl, equals('https://cdn.truthworld.in/subtitles/job_1793595614167_ba09819d/en.srt'));
    });

    test('parseCuesForLanguage handles non-existent remote subtitle URL gracefully without crashing', () async {
      AppConfig.enableCdnThumbnails = false;
      final controller = Get.put(SubtitlesController());

      final video = Video.empty().copyWith(
        id: 'test_vid_404',
        title: "jesus song's",
        jobId: 'job_1793595614167_ba09819d',
        language: 'en',
      );
      controller.selectedVideo.value = video;

      // Passing non-existent storage URL should not crash or throw uncaught exceptions
      await controller.parseCuesForLanguage(
        'en',
        'https://firebasestorage.googleapis.com/v0/b/truthworld-1.firebasestorage.app/o/subtitles%2Fjob_1793595614167_ba09819d%2Fen.srt?alt=media',
      );

      // Current cues should be empty and view state should be success (ready for editor input)
      expect(controller.currentCues.isEmpty, isTrue);
      expect(controller.state, equals(ViewState.success));
    });

    test('parseCuesForLanguage parses raw WebVTT and SRT content directly', () async {
      final controller = Get.put(SubtitlesController());

      const rawVtt = '''WEBVTT

00:00:01.000 --> 00:00:04.000
Amazing Grace, how sweet the sound

00:00:05.000 --> 00:00:09.000
That saved a wretch like me
''';

      await controller.parseCuesForLanguage('en', rawVtt);

      expect(controller.currentCues.length, equals(2));
      expect(controller.currentCues.first.text, equals('Amazing Grace, how sweet the sound'));
      expect(controller.currentCues.last.text, equals('That saved a wretch like me'));
      expect(controller.state, equals(ViewState.success));
    });

    test('StorageUtils.configureRetryLimits executes safely without throwing', () {
      expect(() => StorageUtils.configureRetryLimits(), returnsNormally);
    });

    test('StorageUtils.getDataWithTimeout returns null safely on probe miss', () async {
      final ref = StorageUtils.getStorageRef('subtitles/non_existent_job/te.vtt');
      expect(ref, isNotNull);
      final data = await StorageUtils.getDataWithTimeout(
        ref!,
        timeout: const Duration(milliseconds: 500),
      );
      expect(data, isNull);
    });

    test('parseCuesForLanguage deduplicates rapid concurrent calls for same track', () async {
      final controller = Get.put(SubtitlesController());
      final video = Video.empty().copyWith(
        id: 'vid_dedup_test',
        title: 'Dedup Video',
        language: 'te',
      );
      controller.selectedVideo.value = video;

      const rawVtt = '''WEBVTT

00:00:01.000 --> 00:00:04.000
Telugu Subtitle Line 1
''';

      // Fire multiple parallel parse requests
      final f1 = controller.parseCuesForLanguage('te', rawVtt);
      final f2 = controller.parseCuesForLanguage('te', rawVtt);
      await Future.wait([f1, f2]);

      expect(controller.currentCues.length, equals(1));
      expect(controller.currentCues.first.text, equals('Telugu Subtitle Line 1'));
      expect(controller.state, equals(ViewState.success));
    });

    test('resolveSubtitleUrlForLanguage isolates native vs non-native tracks without transcript pollution', () {
      final controller = Get.put(SubtitlesController());
      final teluguVideo = Video.empty().copyWith(
        id: 'vid_telugu',
        title: 'Anantapur School Incident',
        language: 'te',
        transcriptionUrl: 'https://storage.googleapis.com/test/transcripts/job_te/full.json',
        mediaSubtitles: {
          'te': 'https://storage.googleapis.com/test/subtitles/vid_telugu/te.vtt',
        },
      );

      // Native language with direct subtitle URL
      expect(
        controller.resolveSubtitleUrlForLanguage(teluguVideo, 'te'),
        equals('https://storage.googleapis.com/test/subtitles/vid_telugu/te.vtt'),
      );

      // Non-native language with no subtitle URL must NOT fall back to Telugu transcriptionUrl
      expect(
        controller.resolveSubtitleUrlForLanguage(teluguVideo, 'en'),
        isNull,
      );

      // Native language with no subtitle URL DOES fall back to transcriptionUrl
      final teluguNoSubsVideo = Video.empty().copyWith(
        id: 'vid_telugu_no_subs',
        title: 'Anantapur School Incident',
        language: 'te',
        transcriptionUrl: 'https://storage.googleapis.com/test/transcripts/job_te/full.json',
        mediaSubtitles: {},
      );
      expect(
        controller.resolveSubtitleUrlForLanguage(teluguNoSubsVideo, 'te'),
        equals('https://storage.googleapis.com/test/transcripts/job_te/full.json'),
      );
      expect(
        controller.resolveSubtitleUrlForLanguage(teluguNoSubsVideo, 'en'),
        isNull,
      );
    });

    test('determineDefaultLanguage prefers video native language over English when native transcript is available', () {
      final controller = Get.put(SubtitlesController());
      final teluguVideo = Video.empty().copyWith(
        id: 'vid_telugu_select',
        title: 'Nehru Telugu Speech',
        language: 'te',
        transcriptionUrl: 'https://storage.googleapis.com/test/transcripts/job_te/full.json',
        mediaSubtitles: {},
      );

      final orderedLangs = controller.getOrderedLanguagesForVideo(teluguVideo, {});
      expect(orderedLangs.first, equals('te'));
      expect(orderedLangs.contains('en'), isTrue);

      final defaultLang = controller.determineDefaultLanguage(teluguVideo, {}, orderedLangs);
      expect(defaultLang, equals('te'));
    });

    test('determineDefaultLanguage selects English when video native language is English', () {
      final controller = Get.put(SubtitlesController());
      final englishVideo = Video.empty().copyWith(
        id: 'vid_english_select',
        title: 'Tech Talk',
        language: 'en',
        transcriptionUrl: 'https://storage.googleapis.com/test/transcripts/job_en/full.json',
        mediaSubtitles: {},
      );

      final orderedLangs = controller.getOrderedLanguagesForVideo(englishVideo, {});
      expect(orderedLangs.first, equals('en'));

      final defaultLang = controller.determineDefaultLanguage(englishVideo, {}, orderedLangs);
      expect(defaultLang, equals('en'));
    });
  });
}
