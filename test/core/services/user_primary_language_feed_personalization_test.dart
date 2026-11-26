import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/algorithm/algorithm_engine.dart';
import 'package:truthworld/core/services/algorithm/algorithm_remote_config.dart';
import 'package:truthworld/core/services/algorithm/scored_video.dart';
import 'package:truthworld/core/services/algorithm/truthworld_algorithm.dart';
import 'package:truthworld/core/services/user_languages_service.dart';
import 'package:truthworld/features/search/data/models/search_result.dart';
import 'package:truthworld/features/search/data/services/engine/search_result_ranker.dart';
import 'package:truthworld/features/search/presentation/controllers/search/search_filter_helper.dart';
import 'package:truthworld/features/video/data/models/video.dart';

import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TruthworldAlgorithm algorithm;
  late UserLanguagesService langService;

  setUpAll(() async {
    await setupMockFirebase();
  });

  setUp(() {
    Get.reset();
    Get.put(AlgorithmRemoteConfig());
    langService = Get.put(UserLanguagesService());
    algorithm = Get.put(TruthworldAlgorithm());
  });

  tearDown(Get.reset);

  Video createTestVideo({
    required String id,
    required String title,
    String language = 'en',
    List<String> languages = const [],
    Map<String, String> audioTracks = const {},
    Map<String, String> subtitles = const {},
    String category = 'Technology',
    double trustScore = 4.0,
  }) {
    return Video(
      id: id,
      title: title,
      description: 'Test description for $title',
      thumbnailUrl: 'https://example.com/thumb.jpg',
      ownerId: 'owner_$id',
      channelId: 'channel_$id',
      channelName: 'Channel $id',
      category: category,
      language: language,
      languages: languages,
      audioTracks: audioTracks,
      mediaSubtitles: subtitles,
      isFactChecked: true,
      tags: const [],
      status: VideoStatus.ready,
      visibility: 'public',
    );
  }

  group('UserLanguagesService - Language Matching & Detection', () {
    test('Correctly identifies matching primary language by code or full name', () {
      langService.primaryLanguage.value = 'Spanish';

      expect(langService.isPrimaryLanguage('es'), isTrue);
      expect(langService.isPrimaryLanguage('Spanish'), isTrue);
      expect(langService.isPrimaryLanguage('es_ES'), isTrue);
      expect(langService.isPrimaryLanguage('en'), isFalse);
      expect(langService.isPrimaryLanguage('English'), isFalse);
    });

    test('isUserLanguage checks across primary, secondary, and known languages', () {
      langService.primaryLanguage.value = 'French';
      langService.secondaryLanguages.assignAll(['German']);
      langService.knownLanguages.assignAll(['French', 'German', 'Spanish']);

      expect(langService.isUserLanguage('fr'), isTrue);
      expect(langService.isUserLanguage('de'), isTrue);
      expect(langService.isUserLanguage('es'), isTrue);
      expect(langService.isUserLanguage('ja'), isFalse);
    });
  });

  group('AlgorithmEngine - Language Affinity Computation', () {
    test('Assigns 1.0 for original audio matching user primary language', () {
      final video = createTestVideo(
        id: 'v_es_native',
        title: 'Video en Espanol',
        language: 'es',
      );

      final affinity = AlgorithmEngine.computeLanguageAffinity(video, 'Spanish');
      expect(affinity, equals(1.0));
    });

    test('Assigns 0.95 for video with dubbed audio track in user primary language', () {
      final video = createTestVideo(
        id: 'v_en_dubbed_es',
        title: 'English Video Dubbed',
        language: 'en',
        audioTracks: {'es': 'https://example.com/audio_es.m4a'},
      );

      final affinity = AlgorithmEngine.computeLanguageAffinity(video, 'Spanish');
      expect(affinity, equals(0.95));
    });

    test('Assigns 0.75 for video with subtitles in user primary language', () {
      final video = createTestVideo(
        id: 'v_en_sub_es',
        title: 'English Video Subbed',
        language: 'en',
        subtitles: {'es': 'https://example.com/sub_es.vtt'},
      );

      final affinity = AlgorithmEngine.computeLanguageAffinity(video, 'Spanish');
      expect(affinity, equals(0.75));
    });

    test('Assigns 0.60 for secondary or known languages match', () {
      final video = createTestVideo(
        id: 'v_de',
        title: 'German Video',
        language: 'de',
      );

      final affinity = AlgorithmEngine.computeLanguageAffinity(
        video,
        'Spanish',
        secondaryLanguages: ['German'],
      );
      expect(affinity, equals(0.60));
    });

    test('Assigns 0.10 for foreign content with no user language match', () {
      final video = createTestVideo(
        id: 'v_ja',
        title: 'Japanese Video',
        language: 'ja',
      );

      final affinity = AlgorithmEngine.computeLanguageAffinity(video, 'Spanish');
      expect(affinity, equals(0.10));
    });
  });

  group('TruthworldAlgorithm - Primary Language Feed Prioritization', () {
    test('HomeFeed prioritizes videos in the user primary language over foreign videos', () {
      langService.primaryLanguage.value = 'Spanish';

      final foreignVideo = createTestVideo(
        id: 'vid_foreign',
        title: 'Foreign Tech News',
        language: 'ru',
        category: 'Technology',
      );

      final primaryVideo = createTestVideo(
        id: 'vid_primary',
        title: 'Noticias de Tecnologia',
        language: 'es',
        category: 'Technology',
      );

      final candidates = [foreignVideo, primaryVideo];
      final ranked = algorithm.rankVideos(
        candidates,
        RecommendationSurface.homeFeedAll,
      );

      expect(ranked.isNotEmpty, isTrue);
      // The video matching user's primary language must rank first
      expect(ranked.first.video.id, equals('vid_primary'));
    });

    test('VideoFeed (Related Videos) prioritizes videos in user primary language or dubbed', () {
      langService.primaryLanguage.value = 'Hindi';

      final dubbedVideo = createTestVideo(
        id: 'vid_dubbed',
        title: 'Global Science (Hindi Dub)',
        language: 'en',
        audioTracks: {'hi': 'https://example.com/audio_hi.m4a'},
        category: 'Science',
      );

      final englishOnlyVideo = createTestVideo(
        id: 'vid_en_only',
        title: 'Global Science (English Only)',
        language: 'en',
        category: 'Science',
      );

      final candidates = [englishOnlyVideo, dubbedVideo];
      final ranked = algorithm.rankVideos(
        candidates,
        RecommendationSurface.videoRelated,
      );

      expect(ranked.isNotEmpty, isTrue);
      expect(ranked.first.video.id, equals('vid_dubbed'));
    });
  });

  group('SearchResultRanker - Search Feed Language Prioritization', () {
    test('Boosts search results matching user primary language to top', () {
      final ranker = const SearchResultRanker();
      final results = [
        SearchResult(
          id: 'res_foreign',
          title: 'Artificial Intelligence Guide',
          thumbnail: 'https://example.com/thumb1.jpg',
          views: 1000,
          channelName: 'Channel A',
          channelImage: '',
          createdAt: Timestamp.now(),
          language: 'ja',
        ),
        SearchResult(
          id: 'res_primary',
          title: 'Artificial Intelligence Guide',
          thumbnail: 'https://example.com/thumb2.jpg',
          views: 1000,
          channelName: 'Channel B',
          channelImage: '',
          createdAt: Timestamp.now(),
          language: 'es',
        ),
      ];

      final ranked = ranker.rankAndSortResults(
        results,
        'Artificial Intelligence',
        userPrimaryLanguage: 'Spanish',
      );

      expect(ranked.first.id, equals('res_primary'));
    });

    test('SearchFilterHelper filters by In <Language> chip accurately', () {
      final results = [
        SearchResult(
          id: 'res_es',
          title: 'Result in Spanish',
          thumbnail: 'https://example.com/thumb.jpg',
          views: 50,
          channelName: 'Ch 1',
          channelImage: '',
          createdAt: Timestamp.now(),
          language: 'es',
        ),
        SearchResult(
          id: 'res_en',
          title: 'Result in English',
          thumbnail: 'https://example.com/thumb.jpg',
          views: 100,
          channelName: 'Ch 2',
          channelImage: '',
          createdAt: Timestamp.now(),
          language: 'en',
        ),
      ];

      final filtered = SearchFilterHelper.applyFilter(
        results: results,
        filter: 'In Spanish',
        watchedVideoIds: {},
      );

      expect(filtered.length, equals(1));
      expect(filtered.first.id, equals('res_es'));
    });
  });
}
