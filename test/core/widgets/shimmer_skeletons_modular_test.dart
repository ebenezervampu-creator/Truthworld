import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/widgets/shimmer_skeletons.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void setDesktopSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  void setMobileSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('Shimmer Primitives Tests', () {
    testWidgets('ShimmerBase and shimmerBone render correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShimmerBase(
              child: shimmerBone(width: 120, height: 20, radius: 8),
            ),
          ),
        ),
      );

      expect(find.byType(ShimmerBase), findsOneWidget);
    });
  });

  group('Shimmer Card Skeletons Tests', () {
    testWidgets('renders ShimmerVideoListCard and ShimmerVideoGridCard', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  ShimmerVideoListCard(),
                  ShimmerVideoGridCard(),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(ShimmerVideoListCard), findsOneWidget);
      expect(find.byType(ShimmerVideoGridCard), findsOneWidget);
    });

    testWidgets('renders ShimmerCommentCard and ShimmerChannelCard', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  ShimmerCommentCard(),
                  ShimmerChannelCard(),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(ShimmerCommentCard), findsOneWidget);
      expect(find.byType(ShimmerChannelCard), findsOneWidget);
    });

    testWidgets('renders ShimmerDiscoverChannelCard', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 280,
              child: ShimmerDiscoverChannelCard(),
            ),
          ),
        ),
      );

      expect(find.byType(ShimmerDiscoverChannelCard), findsOneWidget);
    });

    testWidgets('convenience builders produce expected card counts', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  buildShimmerVideoList(count: 3),
                  buildShimmerCommentList(count: 2),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(ShimmerVideoListCard), findsNWidgets(3));
      expect(find.byType(ShimmerCommentCard), findsNWidgets(2));
    });

    testWidgets('buildShimmerVideoGrid produces expected count in bounded container', (tester) async {
      setDesktopSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 600,
              child: buildShimmerVideoGrid(crossAxisCount: 4, count: 4),
            ),
          ),
        ),
      );

      expect(find.byType(ShimmerVideoGridCard), findsNWidgets(4));
    });
  });

  group('Shimmer Video & Playlist Skeletons Tests', () {
    testWidgets('ShimmerPlaylistDetail renders in mobile layout', (tester) async {
      setMobileSize(tester);

      await tester.pumpWidget(
        const MaterialApp(
          home: ShimmerPlaylistDetail(),
        ),
      );

      expect(find.byType(ShimmerPlaylistDetail), findsOneWidget);
      expect(find.byType(ShimmerVideoListCard), findsWidgets);
    });

    testWidgets('ShimmerPlaylistDetail renders in desktop layout', (tester) async {
      setDesktopSize(tester);

      await tester.pumpWidget(
        const MaterialApp(
          home: ShimmerPlaylistDetail(),
        ),
      );

      expect(find.byType(ShimmerPlaylistDetail), findsOneWidget);
      expect(find.byType(ShimmerVideoListCard), findsWidgets);
    });

    testWidgets('ShimmerVideoScreen renders responsive playback layout', (tester) async {
      setDesktopSize(tester);

      await tester.pumpWidget(
        const MaterialApp(
          home: ShimmerVideoScreen(),
        ),
      );

      expect(find.byType(ShimmerVideoScreen), findsOneWidget);
      expect(find.byIcon(Icons.play_circle_outline_rounded), findsOneWidget);
    });
  });

  group('Shimmer Dashboard & Channel Details Skeletons Tests', () {
    testWidgets('ShimmerDashboard renders without errors', (tester) async {
      setDesktopSize(tester);

      await tester.pumpWidget(
        const MaterialApp(
          home: ShimmerDashboard(),
        ),
      );

      expect(find.byType(ShimmerDashboard), findsOneWidget);
    });

    testWidgets('ShimmerChannelDetailsScreen renders banner and tabs', (tester) async {
      setDesktopSize(tester);

      await tester.pumpWidget(
        const MaterialApp(
          home: ShimmerChannelDetailsScreen(),
        ),
      );

      expect(find.byType(ShimmerChannelDetailsScreen), findsOneWidget);
    });
  });

  group('Shimmer Utility Skeletons Tests', () {
    testWidgets('ShimmerButtonText renders text inside button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: ShimmerButtonText('Loading...'),
            ),
          ),
        ),
      );

      expect(find.text('Loading...'), findsOneWidget);
    });

    testWidgets('ShimmerVideoGrid renders responsive grid items', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 400,
              child: ShimmerVideoGrid(
                itemCount: 4,
                isDesktop: true,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(ShimmerVideoGrid), findsOneWidget);
    });
  });
}
