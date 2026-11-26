import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/playlists/playlist_cards.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  setUp(() {
    Get.reset();
    Get.testMode = true;
    if (!Get.isRegistered<AuthService>()) {
      Get.put<AuthService>(AuthService(), permanent: true);
    }
    if (!Get.isRegistered<ConnectivityService>()) {
      Get.put<ConnectivityService>(ConnectivityService(), permanent: true);
    }
  });

  tearDown(Get.reset);

  testWidgets('PlaylistGridCard has zero RenderFlex overflow on exact 390x373.3 constraints', (tester) async {
    final playlist = PlaylistModel(
      id: 'pl_test_1',
      ownerId: 'owner_1',
      channelId: 'ch_test_1',
      name: 'Flutter & Dart Deep Dive Advanced Architectures and Full Stack Masterclass',
      description: 'Comprehensive guide covering State Management, Streams, RenderObjects, Layouts, and Performance Optimization.',
      visibility: PlaylistVisibility.public,
      videoIds: ['v1', 'v2', 'v3'],
      updatedAt: Timestamp.now(),
      createdAt: Timestamp.now(),
    );

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 390.0,
              height: 373.3,
              child: PlaylistGridCard(
                playlist: playlist,
                channelId: 'ch_test_1',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PlaylistGridCard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PlaylistGridCard renders properly with short and empty metadata', (tester) async {
    final playlist = PlaylistModel(
      id: 'pl_test_2',
      ownerId: 'owner_1',
      channelId: 'ch_test_1',
      name: 'Quick Tips',
      description: '',
      visibility: PlaylistVisibility.private,
      videoIds: [],
      updatedAt: Timestamp.now(),
      createdAt: Timestamp.now(),
    );

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 390.0,
              height: 373.3,
              child: PlaylistGridCard(
                playlist: playlist,
                channelId: 'ch_test_1',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PlaylistGridCard), findsOneWidget);
    expect(find.text('No description provided.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PlaylistGridCard handles multiple screen widths without overflow', (tester) async {
    final playlist = PlaylistModel(
      id: 'pl_test_3',
      ownerId: 'owner_1',
      channelId: 'ch_test_1',
      name: 'Very Long Playlist Title That Wraps Onto Two Lines Properly In Grid View',
      description: 'A detailed description that demonstrates how the flexible layout prevents overflow on small cards.',
      visibility: PlaylistVisibility.unlisted,
      videoIds: ['v1'],
      updatedAt: Timestamp.now(),
      createdAt: Timestamp.now(),
    );

    // Test a variety of grid widths and calculated heights
    for (final width in [260.0, 320.0, 390.0, 480.0]) {
      final thumbnailHeight = (width - 20) * (9 / 16) + 16;
      final totalCardHeight = thumbnailHeight + 180.0;

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                height: totalCardHeight,
                child: PlaylistGridCard(
                  playlist: playlist,
                  channelId: 'ch_test_1',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    }
  });
}
