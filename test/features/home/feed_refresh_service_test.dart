import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/algorithm/algorithm_remote_config.dart';
import 'package:truthworld/core/services/algorithm/truthworld_algorithm.dart';
import 'package:truthworld/features/home/data/services/feed_refresh_service.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import '../../test_helpers/mock_firebase.dart';

Video createYouTubeTestVideo({
  required String id,
  required String title,
  required String channelId,
  String category = 'Education',
  int viewCount = 100,
  int likes = 10,
  DateTime? uploadedAt,
}) {
  final now = uploadedAt ?? DateTime.now();
  return Video(
    id: id,
    title: title,
    description: 'Description for $title',
    thumbnailUrl: 'https://example.com/thumb_$id.jpg',
    ownerId: 'owner_$channelId',
    channelId: channelId,
    channelName: 'Channel $channelId',
    category: category,
    tags: ['test'],
    createdAt: Timestamp.fromDate(now),
    uploadedAt: Timestamp.fromDate(now),
    videoUrl: 'https://example.com/video_$id.mp4',
    viewCount: viewCount,
    likes: likes,
    status: VideoStatus.ready,
    geminiApproved: true,
    isApproved: true,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  group('YouTube Home Feed Refresh System Tests (YouTube Architecture Parity)', () {
    late YouTubeFeedRefreshService refreshService;

    setUp(() {
      Get.reset();
      Get.testMode = true;
      refreshService = YouTubeFeedRefreshService();
      if (!Get.isRegistered<AlgorithmRemoteConfig>()) {
        Get.put<AlgorithmRemoteConfig>(AlgorithmRemoteConfig(), permanent: true);
      }
      if (!Get.isRegistered<TruthworldAlgorithm>()) {
        Get.put<TruthworldAlgorithm>(TruthworldAlgorithm(), permanent: true);
      }
    });

    tearDown(() {
      Get.reset();
    });

    test('YouTubeFeedRefreshService tracks session impressions and increments epoch', () {
      expect(refreshService.refreshEpoch, equals(0));
      expect(refreshService.seenVideoIds, isEmpty);

      // Record first batch of displayed videos
      refreshService.markVideosAsSeen(['vid_taj_mahal', 'vid_demonetization']);
      refreshService.incrementRefreshEpoch();

      expect(refreshService.refreshEpoch, equals(1));
      expect(refreshService.seenVideoIds, containsAll(['vid_taj_mahal', 'vid_demonetization']));

      // Second refresh increments epoch further
      refreshService.incrementRefreshEpoch();
      expect(refreshService.refreshEpoch, equals(2));
    });

    test('Fresh unseen candidate videos are prioritized at top over previously seen videos', () {
      final seenVid1 = createYouTubeTestVideo(
        id: 'vid_seen_1',
        title: 'Taj Mahal History Truths',
        channelId: 'ch_1',
        viewCount: 1000,
      );
      final seenVid2 = createYouTubeTestVideo(
        id: 'vid_seen_2',
        title: 'Demonetization Analysis',
        channelId: 'ch_2',
        viewCount: 500,
      );
      final freshVid3 = createYouTubeTestVideo(
        id: 'vid_fresh_3',
        title: 'AI Robotics Breakthrough',
        channelId: 'ch_3',
        viewCount: 200,
      );
      final freshVid4 = createYouTubeTestVideo(
        id: 'vid_fresh_4',
        title: 'Quantum Computing Explained',
        channelId: 'ch_4',
        viewCount: 150,
      );

      // Simulate that user already saw vid_seen_1 and vid_seen_2 in current session
      refreshService.markVideosAsSeen(['vid_seen_1', 'vid_seen_2']);
      refreshService.setLastTopVideoId('vid_seen_1');
      refreshService.incrementRefreshEpoch();

      final candidates = [seenVid1, seenVid2, freshVid3, freshVid4];

      // Re-rank for YouTube pull-to-refresh
      final reRanked = refreshService.reRankFeedForYouTubeRefresh(candidates: candidates);

      expect(reRanked.length, equals(4));
      // Fresh unseen videos must occupy the top hero positions
      expect(reRanked[0].id, isIn(['vid_fresh_3', 'vid_fresh_4']));
      expect(reRanked[1].id, isIn(['vid_fresh_3', 'vid_fresh_4']));

      // Seen videos are demoted to the lower slots (zero catalog drop)
      expect(reRanked[2].id, isIn(['vid_seen_1', 'vid_seen_2']));
      expect(reRanked[3].id, isIn(['vid_seen_1', 'vid_seen_2']));
    });

    test('Small catalog scenario: 2-video feed rotates so top video changes on EVERY refresh', () {
      final vidTajMahal = createYouTubeTestVideo(
        id: 'vid_taj_mahal',
        title: 'Taj Mahal History Truths',
        channelId: 'ch_ebenezer',
        viewCount: 1,
      );
      final vidDemonetization = createYouTubeTestVideo(
        id: 'vid_demonetization',
        title: 'Demonetization 10 Years Analysis',
        channelId: 'ch_ebenezer',
        viewCount: 0,
      );

      final initialCatalog = [vidTajMahal, vidDemonetization];

      // Initial state: top video is Taj Mahal
      refreshService.markVideosAsSeen(['vid_taj_mahal', 'vid_demonetization']);
      refreshService.setLastTopVideoId('vid_taj_mahal');

      // Refresh 1: User pulls to refresh
      refreshService.incrementRefreshEpoch();
      final refresh1 = refreshService.reRankFeedForYouTubeRefresh(candidates: initialCatalog);

      expect(refresh1.length, equals(2));
      // In Refresh 1, Demonetization MUST become the top video!
      expect(refresh1.first.id, equals('vid_demonetization'));
      expect(refresh1.last.id, equals('vid_taj_mahal'));

      // Refresh 2: User pulls to refresh again
      refreshService.incrementRefreshEpoch();
      final refresh2 = refreshService.reRankFeedForYouTubeRefresh(candidates: initialCatalog);

      expect(refresh2.length, equals(2));
      // In Refresh 2, Taj Mahal rotates back to the top!
      expect(refresh2.first.id, equals('vid_taj_mahal'));
      expect(refresh2.last.id, equals('vid_demonetization'));
    });

    test('Small catalog with 5 videos rotates top items across consecutive refreshes', () {
      final videos = List.generate(
        5,
        (i) => createYouTubeTestVideo(
          id: 'v_$i',
          title: 'Video Title $i',
          channelId: 'ch_$i',
        ),
      );

      // Mark all as seen to simulate small catalog saturation
      refreshService.markVideosAsSeen(videos.map((v) => v.id));
      refreshService.setLastTopVideoId(videos.first.id);

      final topVideoIds = <String>[];

      for (var epoch = 1; epoch <= 4; epoch++) {
        refreshService.incrementRefreshEpoch();
        final refreshed = refreshService.reRankFeedForYouTubeRefresh(candidates: videos);
        topVideoIds.add(refreshed.first.id);
      }

      // Check that consecutive refreshes never have the identical top video
      for (var i = 0; i < topVideoIds.length - 1; i++) {
        expect(
          topVideoIds[i],
          isNot(equals(topVideoIds[i + 1])),
          reason: 'Refresh ${i + 1} and ${i + 2} should not have identical top videos',
        );
      }
    });

    test('YouTube creator diversity prevents consecutive same-channel videos in rotated feed', () {
      final v1 = createYouTubeTestVideo(id: '1', title: 'Video 1', channelId: 'ch_A');
      final v2 = createYouTubeTestVideo(id: '2', title: 'Video 2', channelId: 'ch_A');
      final v3 = createYouTubeTestVideo(id: '3', title: 'Video 3', channelId: 'ch_B');
      final v4 = createYouTubeTestVideo(id: '4', title: 'Video 4', channelId: 'ch_C');

      refreshService.markVideosAsSeen(['1', '2', '3', '4']);
      refreshService.incrementRefreshEpoch();

      final reRanked = refreshService.reRankFeedForYouTubeRefresh(candidates: [v1, v2, v3, v4]);

      // Verify that no two consecutive videos share channel ch_A
      for (var i = 0; i < reRanked.length - 1; i++) {
        final currentChannel = reRanked[i].channelId;
        final nextChannel = reRanked[i + 1].channelId;
        if (currentChannel == 'ch_A') {
          expect(nextChannel, isNot(equals('ch_A')));
        }
      }
    });

    test('Zero Catalog Starvation: All valid candidates are preserved in the re-ranked feed', () {
      final videos = List.generate(
        6,
        (i) => createYouTubeTestVideo(
          id: 'v_$i',
          title: 'Video $i',
          channelId: 'ch_$i',
        ),
      );

      // Part seen, part unseen
      refreshService.markVideosAsSeen(['v_0', 'v_1']);
      refreshService.incrementRefreshEpoch();

      final reRanked = refreshService.reRankFeedForYouTubeRefresh(candidates: videos);

      expect(reRanked.length, equals(6));
      final returnedIds = reRanked.map((v) => v.id).toSet();
      expect(returnedIds, containsAll(videos.map((v) => v.id)));
    });

    test('Flip Coin tab (isFlipped: true) changes top video and rotates on refresh', () {
      final v1 = createYouTubeTestVideo(id: 'fc_1', title: 'Flip Video 1', channelId: 'ch_1');
      final v2 = createYouTubeTestVideo(id: 'fc_2', title: 'Flip Video 2', channelId: 'ch_2');
      final videos = [v1, v2];

      refreshService.markVideosAsSeen(['fc_1', 'fc_2']);
      refreshService.setLastTopVideoId('fc_1');
      refreshService.incrementRefreshEpoch();

      final reRanked1 = refreshService.reRankFeedForYouTubeRefresh(
        candidates: videos,
        category: 'Flip Coin',
        isFlipped: true,
      );

      // Top video should alternate to fc_2
      expect(reRanked1.first.id, equals('fc_2'));

      refreshService.setLastTopVideoId('fc_2');
      refreshService.incrementRefreshEpoch();

      final reRanked2 = refreshService.reRankFeedForYouTubeRefresh(
        candidates: videos,
        category: 'Flip Coin',
        isFlipped: true,
      );

      // Top video should alternate back to fc_1
      expect(reRanked2.first.id, equals('fc_1'));
    });
  });
}
