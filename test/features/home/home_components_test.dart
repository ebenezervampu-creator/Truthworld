import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/home/presentation/views/home/widgets/home_widgets.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  group('Home Extracted Components Test Suite', () {
    setUpAll(() async {
      await setupMockFirebase();
    });

    setUp(() {
      Get.reset();
      Get.testMode = true;
      Get.put<AuthService>(AuthService());
      Get.put<ConnectivityService>(ConnectivityService());
    });

    tearDown(Get.reset);

    testWidgets('SubscriptionsShimmerPlaceholder renders safely', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SubscriptionsShimmerPlaceholder(),
        ),
      );

      expect(find.byType(SubscriptionsShimmerPlaceholder), findsOneWidget);
    });

    testWidgets('TopicsShimmerPlaceholder renders safely', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TopicsShimmerPlaceholder(),
        ),
      );

      expect(find.byType(TopicsShimmerPlaceholder), findsOneWidget);
    });

    testWidgets('LibraryShimmerPlaceholder renders safely', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LibraryShimmerPlaceholder(),
        ),
      );

      expect(find.byType(LibraryShimmerPlaceholder), findsOneWidget);
    });

    testWidgets('HomeVideoGridSection renders empty state when video list is empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                HomeVideoGridSection(
                  isMobile: true,
                  isTablet: false,
                  isDesktop: false,
                  videos: const [],
                  heroPrefix: 'test',
                  isLoading: false,
                  horizontalPadding: 16.0,
                  formatViews: (v) => '$v views',
                  formatTimestamp: (t) => 'just now',
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('No videos found'), findsOneWidget);
      expect(find.text('Try selecting a different category'), findsOneWidget);
    });

    testWidgets('HomeVideoGridSection renders loading grid when isLoading is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                HomeVideoGridSection(
                  isMobile: false,
                  isTablet: true,
                  isDesktop: false,
                  videos: const [],
                  heroPrefix: 'test',
                  isLoading: true,
                  horizontalPadding: 24.0,
                  formatViews: (v) => '$v views',
                  formatTimestamp: (t) => 'just now',
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(HomeVideoGridSection), findsOneWidget);
      expect(find.text('No videos found'), findsNothing);
    });

    testWidgets('HomeBottomNavigation renders navigation destinations', (
      tester,
    ) async {
      final controller = Get.put(HomeController());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: HomeBottomNavigation(homeController: controller),
          ),
        ),
      );

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Channels'), findsOneWidget);
      expect(find.text('You'), findsOneWidget);

      await tester.pumpAndSettle();
    });

    test('HomeVideoGridSection calculates responsive columns on desktop for prominent video cards', () {
      // Mobile (<600px): 1 column
      expect(
        HomeVideoGridSection.calculateCrossAxisCountForWidth(
          width: 390,
          isMobile: true,
          isTablet: false,
          isDesktop: false,
        ),
        equals(1),
      );

      // Tablet / Mobile device: 2 columns
      expect(
        HomeVideoGridSection.calculateCrossAxisCountForWidth(
          width: 800,
          isMobile: false,
          isTablet: true,
          isDesktop: false,
        ),
        equals(2),
      );

      // Desktop compact / narrow (<1100px): 2 columns
      expect(
        HomeVideoGridSection.calculateCrossAxisCountForWidth(
          width: 1000,
          isMobile: false,
          isTablet: false,
          isDesktop: true,
        ),
        equals(2),
      );

      // Desktop standard laptop / 1080p scaled at 150% (1100px - 2099px): 3 columns
      expect(
        HomeVideoGridSection.calculateCrossAxisCountForWidth(
          width: 1280,
          isMobile: false,
          isTablet: false,
          isDesktop: true,
        ),
        equals(3),
      );

      // Desktop 1080p scaled at 125% / standard screen (1100px - 2099px): 3 columns (~386px card)
      expect(
        HomeVideoGridSection.calculateCrossAxisCountForWidth(
          width: 1536,
          isMobile: false,
          isTablet: false,
          isDesktop: true,
        ),
        equals(3),
      );

      // Desktop 1080p unscaled (1100px - 2099px): 3 columns (prominent ~514px card)
      expect(
        HomeVideoGridSection.calculateCrossAxisCountForWidth(
          width: 1920,
          isMobile: false,
          isTablet: false,
          isDesktop: true,
        ),
        equals(3),
      );

      // Desktop 1440p / 2K (2100px - 2799px): 4 columns (~542px card)
      expect(
        HomeVideoGridSection.calculateCrossAxisCountForWidth(
          width: 2560,
          isMobile: false,
          isTablet: false,
          isDesktop: true,
        ),
        equals(4),
      );

      // Desktop Ultra-wide / 4K (>=2800px): 5 columns
      expect(
        HomeVideoGridSection.calculateCrossAxisCountForWidth(
          width: 2800,
          isMobile: false,
          isTablet: false,
          isDesktop: true,
        ),
        equals(5),
      );
    });
  });
}
