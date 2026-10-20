import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_controller.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  group('PlaylistUiFilterManager Tests', () {
    late PlaylistUiFilterManager filterManager;

    setUp(() {
      filterManager = PlaylistUiFilterManager();
    });

    test('initial states have expected defaults', () {
      expect(filterManager.isSearching.value, isFalse);
      expect(filterManager.isSearchExpanded.value, isFalse);
      expect(filterManager.isListView.value, isTrue);
      expect(filterManager.sortBy.value, equals('recent'));
      expect(filterManager.isAscending.value, isFalse);
      expect(filterManager.searchQuery.value, isEmpty);
      expect(filterManager.refreshTick.value, equals(0));
      expect(filterManager.selectedVideoIds, isEmpty);
      expect(filterManager.selectedCategory.value, equals('Playlists'));
      expect(filterManager.categories, containsAll(['Playlists', 'Music', 'Owned', 'Saved']));
    });

    test('toggleView toggles list view mode', () {
      expect(filterManager.isListView.value, isTrue);
      filterManager.toggleView();
      expect(filterManager.isListView.value, isFalse);
      filterManager.toggleView();
      expect(filterManager.isListView.value, isTrue);
    });

    test('toggleSearch toggles search state and resets query when closing', () {
      expect(filterManager.isSearching.value, isFalse);
      filterManager.toggleSearch();
      expect(filterManager.isSearching.value, isTrue);

      filterManager.updateSearchQuery('truth');
      expect(filterManager.searchQuery.value, equals('truth'));

      filterManager.toggleSearch();
      expect(filterManager.isSearching.value, isFalse);
      expect(filterManager.searchQuery.value, isEmpty);
    });

    test('setSortBy updates sort criteria and toggles ascending when repeating', () {
      filterManager.setSortBy('name');
      expect(filterManager.sortBy.value, equals('name'));
      expect(filterManager.isAscending.value, isFalse);

      // Repeating toggles ascending
      filterManager.setSortBy('name');
      expect(filterManager.sortBy.value, equals('name'));
      expect(filterManager.isAscending.value, isTrue);

      // Switching resets ascending
      filterManager.setSortBy('date');
      expect(filterManager.sortBy.value, equals('date'));
      expect(filterManager.isAscending.value, isFalse);
    });

    test('toggleVideoSelection adds and removes video IDs', () {
      expect(filterManager.selectedVideoIds.contains('vid_1'), isFalse);
      filterManager.toggleVideoSelection('vid_1');
      expect(filterManager.selectedVideoIds.contains('vid_1'), isTrue);

      filterManager.toggleVideoSelection('vid_2');
      expect(filterManager.selectedVideoIds.length, equals(2));

      filterManager.toggleVideoSelection('vid_1');
      expect(filterManager.selectedVideoIds.contains('vid_1'), isFalse);
      expect(filterManager.selectedVideoIds.length, equals(1));
    });

    test('refreshPlaylistsTick increments refresh count', () {
      expect(filterManager.refreshTick.value, equals(0));
      filterManager.refreshPlaylistsTick();
      expect(filterManager.refreshTick.value, equals(1));
    });

    test('setCategory updates current category', () {
      filterManager.setCategory('Podcasts');
      expect(filterManager.selectedCategory.value, equals('Podcasts'));
    });

    test('getAllUserPlaylists merges private and public playlists with deduplication', () {
      final p1 = PlaylistModel(
        id: 'p1',
        playlistName: 'Private List',
        ownerId: 'user_1',
        channelId: 'chan_1',
        isPublic: false,
      );
      final p2 = PlaylistModel(
        id: 'p2',
        playlistName: 'Public List',
        ownerId: 'user_1',
        channelId: 'chan_1',
        isPublic: true,
      );
      final p1Duplicate = PlaylistModel(
        id: 'p1',
        playlistName: 'Overridden Private List',
        ownerId: 'user_1',
        channelId: 'chan_1',
        isPublic: false,
      );

      final result = filterManager.getAllUserPlaylists(
        playlists: [p1],
        publicPlaylists: [p1Duplicate, p2],
        user: 'user_1',
        selectedChannel: null,
      );

      expect(result.length, equals(2));
      expect(result.map((p) => p.id), containsAll(['p1', 'p2']));
    });

    test('getUserCreatedPlaylists filters out watch later and playlists with empty thumbnails', () {
      final valid = PlaylistModel(
        id: 'p_valid',
        playlistName: 'Valid Tech Playlist',
        ownerId: 'user_1',
        channelId: 'chan_1',
        thumbnailUrl: 'https://example.com/thumb.jpg',
      );
      final watchLater = PlaylistModel(
        id: 'p_wl',
        playlistName: 'Watch Later',
        ownerId: 'user_1',
        channelId: 'chan_1',
        thumbnailUrl: 'https://example.com/thumb.jpg',
      );
      final noThumb = PlaylistModel(
        id: 'p_no_thumb',
        playlistName: 'No Thumbnail Playlist',
        ownerId: 'user_1',
        channelId: 'chan_1',
      );

      final filtered = filterManager.getUserCreatedPlaylists(
        allUserPlaylists: [valid, watchLater, noThumb],
        rawPlaylists: [valid, watchLater, noThumb],
      ).toList();

      expect(filtered.length, equals(1));
      expect(filtered.first.id, equals('p_valid'));
    });
  });

  group('PlaylistWatchLaterManager Tests', () {
    late PlaylistWatchLaterManager watchLaterManager;

    setUp(() {
      watchLaterManager = PlaylistWatchLaterManager(
        getUserId: () => 'user_123',
      );
    });

    test('isInWatchLater correctly checks local video IDs', () {
      expect(watchLaterManager.isInWatchLater('vid_99'), isFalse);

      watchLaterManager.watchLaterVideoIds.addAll(['vid_99', 'vid_100']);
      expect(watchLaterManager.isInWatchLater('vid_99'), isTrue);
      expect(watchLaterManager.isInWatchLater('vid_100'), isTrue);
      expect(watchLaterManager.isInWatchLater('vid_101'), isFalse);
    });

    test('getWatchLaterPlaylist returns synthetic PlaylistModel for user', () {
      watchLaterManager.watchLaterVideoIds.addAll(['v1', 'v2']);
      final playlist = watchLaterManager.getWatchLaterPlaylist();

      expect(playlist, isNotNull);
      expect(playlist!.id, equals('watchlater'));
      expect(playlist.playlistName, equals('Watch Later'));
      expect(playlist.ownerId, equals('user_123'));
      expect(playlist.videoIds, equals(['v1', 'v2']));
      expect(playlist.videoCount, equals(2));
      expect(playlist.effectiveVideoCount, equals(2));
    });

    test('toggleWatchLater unauthenticated returns false', () async {
      final unauthManager = PlaylistWatchLaterManager(getUserId: () => '');
      final res = await unauthManager.toggleWatchLater('vid_123', showFeedback: false);
      expect(res, isFalse);
      expect(unauthManager.watchLaterVideoIds, isEmpty);
    });

    test('toggleWatchLater rolls back optimistic updates on Firestore network failure', () async {
      expect(watchLaterManager.watchLaterVideoIds.contains('v_opt'), isFalse);

      final addResult = await watchLaterManager.toggleWatchLater('v_opt', showFeedback: false);
      expect(addResult, isFalse);
      expect(watchLaterManager.isInWatchLater('v_opt'), isFalse);
    });

    test('dispose cancels cleanly', () {
      expect(() => watchLaterManager.dispose(), returnsNormally);
    });
  });

  group('PlaylistController Coordinator Delegation Tests', () {
    late PlaylistController controller;

    setUp(() {
      Get.reset();
      controller = PlaylistController();
    });

    tearDown(() {
      controller.onClose();
    });

    test('initial state exposes sub-manager properties through getters', () {
      expect(controller.isListView.value, isTrue);
      expect(controller.sortBy.value, equals('recent'));
      expect(controller.isAscending.value, isFalse);
      expect(controller.searchQuery.value, isEmpty);
      expect(controller.selectedCategory.value, equals('Playlists'));
      expect(controller.categories, contains('Playlists'));
      expect(controller.selectedVideoIds, isEmpty);
      expect(controller.watchLaterVideoIds, isEmpty);
      expect(controller.playlists, isEmpty);
      expect(controller.publicPlaylists, isEmpty);
    });

    test('coordinator delegates UI filter actions accurately', () {
      controller.toggleView();
      expect(controller.isListView.value, isFalse);

      controller.toggleSearch();
      expect(controller.isSearching.value, isTrue);

      controller.updateSearchQuery('science');
      expect(controller.searchQuery.value, equals('science'));

      controller.setCategory('Music');
      expect(controller.selectedCategory.value, equals('Music'));

      controller.toggleVideoSelection('vid_xyz');
      expect(controller.selectedVideoIds.contains('vid_xyz'), isTrue);

      controller.toggleVideoSelection('vid_xyz');
      expect(controller.selectedVideoIds.contains('vid_xyz'), isFalse);
    });
  });
}
