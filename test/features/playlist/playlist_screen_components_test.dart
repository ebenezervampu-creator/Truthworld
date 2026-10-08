import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/playlist/presentation/views/playlist/widgets/playlist_screen_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(Get.reset);

  tearDown(Get.reset);

  group('Playlist Screen Extracted Components Tests', () {
    testWidgets('StackedThumbnail renders video count and correct icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 180,
              child: StackedThumbnail(
                thumbnailUrl: 'https://example.com/thumb.jpg',
                videoCount: 15,
              ),
            ),
          ),
        ),
      );

      expect(find.text('15 videos'), findsOneWidget);
      expect(find.byIcon(Icons.playlist_play_rounded), findsOneWidget);
    });

    testWidgets('StackedThumbnail renders podcast mode with episode label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 180,
              child: StackedThumbnail(
                thumbnailUrl: 'https://example.com/thumb.jpg',
                videoCount: 42,
                isPodcast: true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('42 episodes'), findsOneWidget);
      expect(find.byIcon(Icons.podcasts_rounded), findsOneWidget);
    });

    testWidgets('PlaylistTypeSelectionCards renders both types and responds to taps', (tester) async {
      final selectedType = 'private'.obs;
      var lastSelected = '';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlaylistTypeSelectionCards(
              selectedType: selectedType,
              onTypeSelected: (type) {
                lastSelected = type;
                selectedType.value = type;
              },
            ),
          ),
        ),
      );

      expect(find.text('Choose Playlist Type'), findsOneWidget);
      expect(find.text('Private Playlists'), findsOneWidget);
      expect(find.text('Public Playlists'), findsOneWidget);

      await tester.tap(find.text('Public Playlists'));
      await tester.pumpAndSettle();

      expect(lastSelected, 'public');
      expect(selectedType.value, 'public');
    });

    testWidgets('PlaylistEmptyStateWidget renders empty copy correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlaylistEmptyStateWidget(isPublic: false),
          ),
        ),
      );

      expect(find.text('No playlists yet'), findsOneWidget);
      expect(find.text('Create your first playlist to organize your favorite videos'), findsOneWidget);
    });

    testWidgets('PlaylistNoResultsWidget renders search feedback', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlaylistNoResultsWidget(),
          ),
        ),
      );

      expect(find.text('No playlists found'), findsOneWidget);
      expect(find.text('Try adjusting your search terms'), findsOneWidget);
      expect(find.byIcon(Icons.search_off_rounded), findsOneWidget);
    });

    testWidgets('PlaylistSortOptionTile renders label and triggers tap', (tester) async {
      final sortBy = 'recent'.obs;
      final isAsc = false.obs;
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlaylistSortOptionTile(
              value: 'name',
              label: 'Name',
              icon: Icons.sort_by_alpha_rounded,
              sortBy: sortBy,
              isAscending: isAsc,
              onSelected: (val) {
                sortBy.value = val;
              },
              onTap: () {
                tapped = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Name'), findsOneWidget);
      expect(find.byIcon(Icons.sort_by_alpha_rounded), findsOneWidget);

      await tester.tap(find.text('Name'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
      expect(sortBy.value, 'name');
    });

    testWidgets('PlaylistScreenCard renders metadata, badges, and triggers taps', (tester) async {
      var cardTapped = false;
      var optionsTapped = false;

      final testPlaylist = PlaylistModel(
        id: 'test_123',
        ownerId: 'user_1',
        channelId: 'chan_1',
        playlistName: 'Watch Later',
        videoCount: 12,
        isPublic: false,
        updatedAt: Timestamp.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: PlaylistScreenCard(
                playlist: testPlaylist,
                onTap: () => cardTapped = true,
                onOptionsTap: () => optionsTapped = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Watch Later'), findsOneWidget);
      expect(find.text('12 videos'), findsOneWidget);
      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
      expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);

      await tester.tap(find.text('Watch Later'));
      expect(cardTapped, isTrue);

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      expect(optionsTapped, isTrue);
    });

    testWidgets('PlaylistScreenCard has zero overflow in grid across screen widths and text scales', (tester) async {
      final testPlaylist = PlaylistModel(
        id: 'test_overflow_guard',
        ownerId: 'user_1',
        channelId: 'chan_1',
        playlistName: "jesus song's",
        videoCount: 1,
        isPublic: true,
        updatedAt: Timestamp.now(),
      );

      for (final scale in [1.0, 1.15, 1.3]) {
        for (final screenWidth in [320.0, 360.0, 375.0, 392.0, 412.0]) {
          final crossAxisCount = screenWidth >= 360 ? 2 : 1;
          final availableWidth = screenWidth - 32.0;
          final cardWidth = (availableWidth - (16.0 * (crossAxisCount - 1))) / crossAxisCount;
          final thumbWidth = cardWidth - 24.0;
          final thumbHeight = thumbWidth * (9.0 / 16.0);
          final cardHeight = thumbHeight + 104.0;
          final childAspectRatio = (cardWidth / cardHeight).clamp(0.65, 1.45);

          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData.dark(),
              home: Scaffold(
                body: MediaQuery(
                  data: MediaQueryData(
                    size: Size(screenWidth, 800),
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverGrid(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: childAspectRatio,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => PlaylistScreenCard(
                              playlist: testPlaylist,
                              onTap: () {},
                              onOptionsTap: () {},
                            ),
                            childCount: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pump();

          final err = tester.takeException();
          expect(err, isNull, reason: 'Card overflowed at width $screenWidth with scale $scale');
        }
      }
    });
  });
}
