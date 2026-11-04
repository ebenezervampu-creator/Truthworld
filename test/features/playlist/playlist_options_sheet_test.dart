import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_controller.dart';
import 'package:truthworld/features/playlist/presentation/views/playlist/widgets/playlist_options_sheet.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  setUp(() {
    Get.reset();
    if (!Get.isRegistered<AuthService>()) {
      Get.put<AuthService>(AuthService(), permanent: true);
    }
  });

  tearDown(Get.reset);

  group('PlaylistModel Watch Later Identification Tests', () {
    test('isWatchLater correctly returns true for system Watch Later and false for custom playlists', () {
      final wlById = PlaylistModel(
        id: 'watchlater',
        ownerId: 'u1',
        channelId: '',
        name: 'Custom Label',
      );
      final wlByName = PlaylistModel(
        id: 'custom_id',
        ownerId: 'u1',
        channelId: '',
        name: 'Watch Later',
      );
      final wlByLowerName = PlaylistModel(
        id: 'custom_id_2',
        ownerId: 'u1',
        channelId: '',
        name: '  watch later  ',
      );
      final customPlaylist = PlaylistModel(
        id: 'p_123',
        ownerId: 'u1',
        channelId: '',
        name: 'My Best Videos',
      );

      expect(wlById.isWatchLater, isTrue);
      expect(wlByName.isWatchLater, isTrue);
      expect(wlByLowerName.isWatchLater, isTrue);
      expect(customPlaylist.isWatchLater, isFalse);
    });
  });

  group('PlaylistCrudManager Watch Later Safety Guards', () {
    test('deletePlaylist and editPlaylist safely reject watchlater operations without throwing', () async {
      final sync = PlaylistSyncManager(getUserId: () => 'user_123');
      final crud = PlaylistCrudManager(
        getUserId: () => 'user_123',
        syncManager: sync,
        refreshPlaylistsTick: () {},
      );

      // deletePlaylist on watchlater must guard and return early without trying to update non-existent doc
      await expectLater(crud.deletePlaylist('watchlater', false), completes);
      await expectLater(crud.deletePlaylist('Watch Later', false), completes);

      // editPlaylist on watchlater must guard and return early
      await expectLater(crud.editPlaylist('watchlater', 'New Title', false), completes);
      await expectLater(crud.editPlaylist('Watch Later', 'New Title', false), completes);
    });

    test('getPlaylist cleanly resolves watchlater from getWatchLaterPlaylist callback', () async {
      final synthetic = PlaylistModel(
        id: 'watchlater',
        ownerId: 'user_123',
        channelId: '',
        name: 'Watch Later',
        videoCount: 5,
      );

      final sync = PlaylistSyncManager(getUserId: () => 'user_123');
      final crud = PlaylistCrudManager(
        getUserId: () => 'user_123',
        syncManager: sync,
        refreshPlaylistsTick: () {},
        getWatchLaterPlaylist: () => synthetic,
      );

      final result = await crud.getPlaylist('watchlater', isPublic: false);
      expect(result.id, equals('watchlater'));
      expect(result.name, equals('Watch Later'));
      expect(result.videoCount, equals(5));
    });
  });

  group('PlaylistOptionsSheet Widget & UX Tests', () {
    testWidgets('Custom playlist renders Share, Edit, Manage Videos, and Delete Playlist', (tester) async {
      final controller = Get.put(PlaylistController());

      final customPlaylist = PlaylistModel(
        id: 'custom_playlist_1',
        ownerId: 'user_123',
        channelId: 'chan_1',
        name: 'Kerala Trip',
        videoCount: 3,
        videoIds: ['v1', 'v2', 'v3'],
      );

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showPlaylistOptionsSheet(
                  context: context,
                  playlist: customPlaylist,
                  playlistController: controller,
                ),
                child: const Text('Open Options'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Options'));
      await tester.pumpAndSettle();

      expect(find.text('Kerala Trip'), findsOneWidget);
      expect(find.text('Share Playlist'), findsOneWidget);
      expect(find.text('Edit Playlist'), findsOneWidget);
      expect(find.text('Manage Videos'), findsOneWidget);
      expect(find.text('Delete Playlist'), findsOneWidget);
      expect(find.text('Clear Watch Later'), findsNothing);

      // Tap Delete Playlist to verify confirmation dialog
      await tester.tap(find.text('Delete Playlist'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Playlist?'), findsOneWidget);
      expect(
        find.text('Are you sure you want to delete "Kerala Trip"? This action cannot be undone.'),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('Watch Later playlist renders Share and Clear Watch Later, and omits Edit Playlist & Delete Playlist', (tester) async {
      final controller = Get.put(PlaylistController());
      controller.watchLaterVideoIds.addAll(['v1', 'v2']);

      final watchLater = PlaylistModel(
        id: 'watchlater',
        ownerId: 'user_123',
        channelId: '',
        name: 'Watch Later',
        videoCount: 2,
        videoIds: ['v1', 'v2'],
      );

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showPlaylistOptionsSheet(
                  context: context,
                  playlist: watchLater,
                  playlistController: controller,
                ),
                child: const Text('Open Options'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Options'));
      await tester.pumpAndSettle();

      expect(find.text('Watch Later'), findsOneWidget);
      expect(find.text('Share Playlist'), findsOneWidget);
      expect(find.text('Clear Watch Later'), findsOneWidget);
      expect(find.text('Manage Videos'), findsOneWidget);

      // System playlist must NEVER offer Edit or Delete Playlist
      expect(find.text('Edit Playlist'), findsNothing);
      expect(find.text('Delete Playlist'), findsNothing);

      // Tap Clear Watch Later to verify confirmation dialog
      await tester.tap(find.text('Clear Watch Later'));
      await tester.pumpAndSettle();

      expect(find.text('Clear Watch Later?'), findsOneWidget);
      expect(find.text('This will remove all videos from your Watch Later list.'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Clear All'), findsOneWidget);
    });
  });
}
