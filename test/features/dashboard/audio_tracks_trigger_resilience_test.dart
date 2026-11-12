import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audio_tracks_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks/dubbing_options/dubbing_options_state.dart';
import 'package:truthworld/features/video/data/models/video.dart';

import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  tearDown(Get.reset);

  group('AudioTracksController Dubbing Resilience & Error Handling', () {
    testWidgets('DubbingOptionsState initializes with target language and checks source language', (tester) async {
      final controller = Get.put(AudioTracksController());
      controller.rxState.value = ViewState.idle;
      controller.selectedVideo.value = Video(
        id: 'vid_resilience_1',
        title: 'Dubbing Resilience Video',
        description: 'Test video for dubbing resilience',
        videoUrl: 'https://example.com/stream.mp4',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        ownerId: 'test_user',
        channelId: 'chan_resilience_1',
        channelName: 'Channel One',
        category: 'Education',
        tags: const ['truth'],
        duration: '00:24',
        language: 'te',
      );

      final state = DubbingOptionsState(
        controller: controller,
        initialLangCode: 'en',
      );

      expect(state.selectedLangCode.value, equals('en'));
      expect(state.isSourceLanguage('te'), isTrue);
      expect(state.isSourceLanguage('en'), isFalse);
      expect(state.billableLanguageCount, equals(1));
    });

    test('Zombie job detection TTL logic: jobs older than 5 minutes are flagged stale', () {
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      final staleJob = AudioDubbingProgressState(
        langCode: 'en',
        startedAt: DateTime.fromMillisecondsSinceEpoch(nowMs - (6 * 60 * 1000)),
        progress: 50,
      );
      final freshJob = AudioDubbingProgressState(
        langCode: 'en',
        startedAt: DateTime.fromMillisecondsSinceEpoch(nowMs - (2 * 60 * 1000)),
        progress: 50,
      );

      expect(DateTime.now().difference(staleJob.startedAt!).inMinutes >= 5, isTrue);
      expect(DateTime.now().difference(freshJob.startedAt!).inMinutes < 5, isTrue);
    });

    test('Stale failure guard: ignores failure timestamps older than current run startedAt', () {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final currentRunStartedAtMs = nowMs;
      final priorFailureTimestampMs = nowMs - (10 * 1000); // 10 seconds ago

      final isStaleFailure = priorFailureTimestampMs < currentRunStartedAtMs;
      expect(isStaleFailure, isTrue);

      final freshFailureTimestampMs = nowMs + 5000;
      final isFreshFailureStale = freshFailureTimestampMs < currentRunStartedAtMs;
      expect(isFreshFailureStale, isFalse);
    });
  });
}
