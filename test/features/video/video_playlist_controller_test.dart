import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/video_playlist_controller.dart';

class TestVideoPlaylistController extends VideoPlaylistController {
  bool fetchCalled = false;

  @override
  Future<void> fetchPlaylistVideos() async {
    fetchCalled = true;
    if (currentPlaylist.value != null) {
      final videos = currentPlaylist.value!.videoIds.map((id) {
        return Video(
          id: id,
          title: 'Video $id',
          description: 'desc',
          thumbnailUrl: '',
          ownerId: 'u1',
          channelId: 'c1',
          channelName: 'channel 1',
          category: 'cat',
          tags: [],
          views: 0,
          createdAt: DateTime.now(),
        );
      }).toList();
      playlistVideos.value = videos;
    }
  }
}

Video createDummyVideo(String id) {
  return Video(
    id: id,
    title: id,
    description: 'desc',
    thumbnailUrl: '',
    ownerId: 'u1',
    channelId: 'c1',
    channelName: 'channel 1',
    category: 'cat',
    tags: [],
    views: 0,
    createdAt: DateTime.now(),
  );
}

void main() {
  group('VideoPlaylistController Tests', () {
    late TestVideoPlaylistController controller;

    setUp(() {
      controller = TestVideoPlaylistController();
    });

    test('initial state is correct', () {
      expect(controller.currentPlaylist.value, isNull);
      expect(controller.playlistVideos, isEmpty);
      expect(controller.currentPlaylistIndex.value, equals(0));
      expect(controller.isPlaylistLooping.value, isFalse);
      expect(controller.isPlaylistShuffled.value, isFalse);
      expect(controller.showPlaylistDrawer.value, isTrue);
    });

    test('togglePlaylistLoop toggles state', () {
      controller.togglePlaylistLoop();
      expect(controller.isPlaylistLooping.value, isTrue);
      controller.togglePlaylistLoop();
      expect(controller.isPlaylistLooping.value, isFalse);
    });

    test('togglePlaylistShuffle toggles state', () {
      controller.togglePlaylistShuffle();
      expect(controller.isPlaylistShuffled.value, isTrue);
      controller.togglePlaylistShuffle();
      expect(controller.isPlaylistShuffled.value, isFalse);
    });

    test('loadPlaylist sets playlist and fetches videos', () async {
      final playlist = PlaylistModel(
        id: 'p1',
        name: 'My Playlist',
        ownerId: 'u1',
        channelId: 'c1',
        videoIds: ['v1', 'v2', 'v3'],
      );

      await controller.loadPlaylist(playlist);

      expect(controller.currentPlaylist.value, equals(playlist));
      expect(controller.fetchCalled, isTrue);
      expect(controller.playlistVideos.length, equals(3));
      expect(controller.playlistVideos[0].id, equals('v1'));
    });

    test('playPlaylistVideoAtIndex sets index', () async {
      controller.playlistVideos.value = [
        createDummyVideo('v1'),
        createDummyVideo('v2'),
      ];

      controller.playPlaylistVideoAtIndex(1);
      expect(controller.currentPlaylistIndex.value, equals(1));
    });

    test('playNextPlaylistVideo advances index', () {
      controller.playlistVideos.value = [
        createDummyVideo('v1'),
        createDummyVideo('v2'),
      ];
      controller.currentPlaylistIndex.value = 0;

      controller.playNextPlaylistVideo();
      expect(controller.currentPlaylistIndex.value, equals(1));
    });

    test('playPreviousPlaylistVideo goes back', () {
      controller.playlistVideos.value = [
        createDummyVideo('v1'),
        createDummyVideo('v2'),
      ];
      controller.currentPlaylistIndex.value = 1;

      controller.playPreviousPlaylistVideo();
      expect(controller.currentPlaylistIndex.value, equals(0));
    });
  });
}
