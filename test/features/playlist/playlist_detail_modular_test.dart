import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_detail_controller.dart';
import 'package:truthworld/features/playlist/presentation/views/playlist/playlist_detail_screen.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  setUp(() {
    Get.reset();
    if (!Get.isRegistered<AuthService>()) {
      Get.put<AuthService>(AuthService());
    }
  });

  tearDown(Get.reset);

  final testPlaylist = PlaylistModel(
    id: 'pl_deep_space',
    ownerId: 'user_astronomer',
    channelId: '',
    playlistName: 'Deep Space Journey',
    description: 'Explore stars, black holes, and galaxies beyond.',
    videoCount: 8,
    createdAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
  );

  final testVideo = Video(
    id: 'vid_galaxy_1',
    title: 'James Webb: Deep Field Insights',
    description: 'Observing the earliest galaxies in the universe.',
    thumbnailUrl: '',
    ownerId: 'user_astronomer',
    channelId: 'ch_astronomy',
    channelName: 'Cosmic Horizons',
    category: 'science',
    tags: ['space', 'jwst'],
    duration: '14:20',
    views: 45200,
  );

  group('PlaylistDetail Modular Unit & Widget Tests', () {
    testWidgets('1. PlaylistThumbnailWidget renders placeholder on empty URL',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlaylistThumbnailWidget(playlist: testPlaylist),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PlaylistThumbnailPlaceholder), findsOneWidget);
      expect(find.byIcon(Icons.playlist_play), findsOneWidget);
    });

    testWidgets('2. PlaylistChannelInfoWidget renders owner displayName',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlaylistChannelInfoWidget(playlist: testPlaylist),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('user_astronomer'), findsOneWidget);
    });

    testWidgets('3. PlaylistActionButtons renders primary Play all and Shuffle',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlaylistActionButtons(
              playlist: testPlaylist,
              isDesktop: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Play all'), findsOneWidget);
      expect(find.text('Shuffle'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.byIcon(Icons.shuffle), findsOneWidget);
      expect(find.byIcon(Icons.download), findsOneWidget);
      expect(find.byIcon(Icons.share), findsOneWidget);
    });

    testWidgets('4. PlaylistFilterTabs updates controller filter selection',
        (tester) async {
      final controller = PlaylistDetailController();
      Get.put<PlaylistDetailController>(controller);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlaylistFilterTabs(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('All'), findsOneWidget);
      expect(find.text('Videos'), findsOneWidget);

      await tester.tap(find.text('Videos'));
      await tester.pumpAndSettle();

      expect(controller.filterValue.value, equals('Videos'));
    });

    testWidgets('5. PlaylistVideoOptionsBottomSheet displays video actions',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlaylistVideoOptionsBottomSheet(video: testVideo),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Play next'), findsOneWidget);
      expect(find.text('Add to queue'), findsOneWidget);
      expect(find.text('Download'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.byIcon(Icons.playlist_add), findsOneWidget);
    });

    testWidgets('6. PlaylistVideoListItem renders thumbnail, title, and metadata',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlaylistVideoListItem(
              index: 1,
              video: testVideo,
              playlist: testPlaylist,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('James Webb: Deep Field Insights'), findsOneWidget);
      expect(find.text('Cosmic Horizons • 45.2K views'), findsOneWidget);
      expect(find.text('14:20'), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets('7. PlaylistDetailEmptyState displays contextual message',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlaylistDetailEmptyState(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No videos found'), findsOneWidget);
      expect(find.text('This playlist is empty'), findsOneWidget);
      expect(find.byIcon(Icons.playlist_remove), findsOneWidget);
    });

    testWidgets('8. PlaylistDetailErrorState renders message and triggers retry',
        (tester) async {
      var retried = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlaylistDetailErrorState(
              message: 'Failed to load videos',
              onRetry: () => retried = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Failed to load videos'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);

      await tester.tap(find.text('Retry'));
      expect(retried, isTrue);
    });

    testWidgets('9. PlaylistDetailScreen renders layout with provided playlist',
        (tester) async {
      final controller = PlaylistDetailController();
      Get.put<PlaylistDetailController>(controller);

      await tester.pumpWidget(
        GetMaterialApp(
          home: PlaylistDetailScreen(playlist: testPlaylist),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PlaylistDetailScreen), findsOneWidget);
      expect(find.text('Deep Space Journey'), findsWidgets);
      expect(find.byType(PlaylistDetailHeader), findsOneWidget);
      expect(find.byType(PlaylistFilterTabs), findsOneWidget);
    });
  });
}
