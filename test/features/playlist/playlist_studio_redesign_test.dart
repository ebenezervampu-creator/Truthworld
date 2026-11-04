import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/playlists_management_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/playlists/playlist_cards.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/playlists/playlists_metrics_bar.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/playlists/playlists_search_filter_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PlaylistModel samplePlaylist;
  late PlaylistModel singleVideoPlaylist;

  setUp(() {
    Get.reset();
    Get.put(PlaylistsManagementController());

    final now = Timestamp.now();
    samplePlaylist = PlaylistModel(
      id: 'test_pl_1',
      channelId: 'channel_123',
      ownerId: 'user_123',
      name: 'Flutter Masterclass',
      description: 'Comprehensive guide to modern Flutter & Dart development.',
      visibility: PlaylistVisibility.public,
      videoIds: ['vid_1', 'vid_2', 'vid_3'],
      thumbnailUrl: '',
      createdAt: now,
      updatedAt: now,
    );

    singleVideoPlaylist = PlaylistModel(
      id: 'test_pl_2',
      channelId: 'channel_123',
      ownerId: 'user_123',
      name: 'Solo Video Track',
      description: '',
      visibility: PlaylistVisibility.unlisted,
      videoIds: ['vid_1'],
      thumbnailUrl: '',
      createdAt: now,
      updatedAt: now,
    );
  });

  tearDown(Get.reset);

  group('YouTube-Style Playlist Cards & Studio Tab Tests', () {
    testWidgets('PlaylistThumbnailStacked renders video count accurately', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 200,
              child: PlaylistThumbnailStacked(playlist: samplePlaylist),
            ),
          ),
        ),
      );

      // Verify YouTube badge text ("3 videos")
      expect(find.text('3 videos'), findsOneWidget);
      expect(find.byIcon(Icons.playlist_play_rounded), findsWidgets);
    });

    testWidgets('PlaylistThumbnailStacked formats singular video count', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 200,
              child: PlaylistThumbnailStacked(playlist: singleVideoPlaylist),
            ),
          ),
        ),
      );

      // Verify singular formatting ("1 video")
      expect(find.text('1 video'), findsOneWidget);
    });

    testWidgets('PlaylistGridCard renders YouTube-style info, visibility, and toolstrip', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 380,
              child: PlaylistGridCard(
                playlist: samplePlaylist,
                channelId: 'channel_123',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Flutter Masterclass'), findsOneWidget);
      expect(find.text('Public'), findsOneWidget);
      expect(find.byIcon(Icons.public_rounded), findsOneWidget);
      expect(find.text('Manage Videos'), findsOneWidget);
      expect(find.byIcon(Icons.video_collection_outlined), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect(find.byIcon(Icons.play_circle_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);
    });

    testWidgets('PlaylistListCard renders row layout with metadata and action buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 140,
              child: PlaylistListCard(
                playlist: samplePlaylist,
                channelId: 'channel_123',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Flutter Masterclass'), findsOneWidget);
      expect(find.text('Public'), findsOneWidget);
      expect(find.text('Manage Videos'), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);
    });

    testWidgets('PlaylistMetricSummaryCard renders stat and triggers onTap', (tester) async {
      var cardTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 80,
              child: PlaylistMetricSummaryCard(
                title: 'Total Playlists',
                value: '12',
                icon: Icons.playlist_play_rounded,
                onTap: () => cardTapped = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Total Playlists'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);

      await tester.tap(find.text('Total Playlists'));
      await tester.pumpAndSettle();

      expect(cardTapped, isTrue);
    });

    testWidgets('PlaylistFilterChip adheres to Zero White-on-White Policy', (tester) async {
      final controller = Get.find<PlaylistsManagementController>();
      controller.setFilterMode('public');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                PlaylistFilterChip(label: 'All', mode: 'all'),
                PlaylistFilterChip(label: 'Public', mode: 'public'),
              ],
            ),
          ),
        ),
      );

      final publicTextFinder = find.text('Public');
      expect(publicTextFinder, findsOneWidget);

      // Verify the active chip uses Black text on white background
      final Text publicTextWidget = tester.widget(publicTextFinder);
      expect(publicTextWidget.style?.color, Colors.black);

      // Verify the unselected chip uses Primary white/light text
      final allTextFinder = find.text('All');
      expect(allTextFinder, findsOneWidget);
      final Text allTextWidget = tester.widget(allTextFinder);
      expect(allTextWidget.style?.color, isNot(Colors.black));
    });
  });
}
