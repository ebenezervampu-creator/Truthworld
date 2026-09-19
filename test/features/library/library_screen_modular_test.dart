import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/features/library/presentation/controllers/library_controller.dart';
import 'package:truthworld/features/library/presentation/views/library/library_screen.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  setUp(() {
    Get.reset();
    Get.testMode = true;
    if (!Get.isRegistered<ConnectivityService>()) {
      Get.put<ConnectivityService>(ConnectivityService());
    }
  });

  tearDown(() async {
    Get.reset();
  });

  group('Library Constants Tests', () {
    test('responsive breakpoints and theme colors are configured properly', () {
      expect(kMobileBreakpoint, equals(600));
      expect(kTabletBreakpoint, equals(1000));
      expect(kDesktopBreakpoint, equals(1200));
      expect(bgColor, isNotNull);
      expect(surfaceColor, isNotNull);
      expect(cardColor, isNotNull);
      expect(primaryText, isNotNull);
      expect(buttonBg, isNotNull);
    });
  });

  group('LibraryUnauthenticatedView Tests', () {
    testWidgets('renders lock icon, title, subtitle, and sign in button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LibraryUnauthenticatedView(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Access Your Personal Video Library'), findsOneWidget);
      expect(
        find.text('Sign in to view your saved videos, watch history, and custom playlists. Your content is waiting!'),
        findsOneWidget,
      );
      expect(find.text('Sign In to Continue'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.login_rounded), findsOneWidget);
    });
  });

  group('LibraryModernAppBar Tests', () {
    testWidgets('renders title and action buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: const LibraryModernAppBar(),
            body: Container(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Your Library'), findsOneWidget);
      expect(find.byIcon(Icons.video_library_rounded), findsOneWidget);
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
      expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);
    });
  });

  group('LibraryListTile Tests', () {
    testWidgets('renders title and triggers callback on tap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LibraryListTile(
              icon: Icons.history_rounded,
              title: 'History Test Tile',
              onTap: () => tapped = true,
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('History Test Tile'), findsOneWidget);
      expect(find.byIcon(Icons.history_rounded), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);

      await tester.tap(find.text('History Test Tile'));
      await tester.pump();
      expect(tapped, isTrue);
    });
  });

  group('LibraryProfileHeader Tests', () {
    testWidgets('renders display name and user avatar safely', (tester) async {
      Get.put<AuthService>(AuthService());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LibraryProfileHeader(userId: 'test_user_id'),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(LibraryProfileHeader), findsOneWidget);
    });
  });

  group('LibraryNavList Tests', () {
    testWidgets('renders core navigation shortcuts', (tester) async {
      Get.put<AuthService>(AuthService());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LibraryNavList(userId: 'test_user_id'),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('History'), findsOneWidget);
      expect(find.text('My videos'), findsOneWidget);
      expect(find.text('Playlists'), findsOneWidget);
      expect(find.text('Subscriptions'), findsOneWidget);
      expect(find.text('Liked videos'), findsOneWidget);
    });
  });

  group('LibrarySidebar Tests', () {
    testWidgets('renders quick action shortcuts', (tester) async {
      Get.put<AuthService>(AuthService());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LibrarySidebar(userId: 'test_user_id'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Quick Actions'), findsOneWidget);
      expect(find.text('New Playlist'), findsOneWidget);
      expect(find.text('Watch History'), findsOneWidget);
      expect(find.text('My Videos'), findsOneWidget);
      expect(find.text('Liked Videos'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });
  });

  group('LibraryScreen Layout Tests', () {
    testWidgets('renders unauthenticated state when user is null', (tester) async {
      Get.put<AuthService>(AuthService());
      Get.put<LibraryController>(LibraryController());

      await tester.pumpWidget(
        const MaterialApp(
          home: LibraryScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(LibraryUnauthenticatedView), findsOneWidget);
      expect(find.text('Access Your Personal Video Library'), findsOneWidget);
    });
  });
}
