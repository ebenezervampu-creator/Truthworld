import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/content/desktop_content_data_table.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/video_management.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  setUp(() {
    Get.testMode = true;
  });

  tearDown(Get.reset);

  group('DesktopContentDataTable Widget Tests', () {
    testWidgets('renders sticky header with all sortable columns and video rows', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final dummyVideos = [
        Video(
          id: 'v_1',
          title: 'Epistemic Truth Ep 1',
          description: 'Introduction to factual claims',
          videoUrl: 'https://example.com/video1.mp4',
          thumbnailUrl: 'https://example.com/thumb1.jpg',
          channelId: 'ch_1',
          channelName: 'Channel One',
          ownerId: 'u_1',
          category: 'Education',
          tags: const ['truth', 'fact'],
          views: 1200,
          likeCount: 95,
          commentCount: 42,
          createdAt: Timestamp.fromDate(DateTime(2026, 1, 15)),
        ),
        Video(
          id: 'v_2',
          title: 'Fact Checking Deep Dive',
          description: 'Detailed analysis of media',
          videoUrl: 'https://example.com/video2.mp4',
          thumbnailUrl: 'https://example.com/thumb2.jpg',
          channelId: 'ch_1',
          channelName: 'Channel One',
          ownerId: 'u_1',
          category: 'Education',
          tags: const ['truth', 'fact'],
          views: 3500,
          likeCount: 280,
          commentCount: 110,
          createdAt: Timestamp.fromDate(DateTime(2026, 2, 20)),
        ),
      ];

      final controller = Get.put(VideoManagementController());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1400,
              height: 800,
              child: DesktopContentDataTable(
                videos: dummyVideos,
                controller: controller,
                isDarkMode: true,
              ),
            ),
          ),
        ),
      );

      // Verify Column headers exist
      expect(find.text('Video'), findsOneWidget);
      expect(find.text('Visibility'), findsOneWidget);
      expect(find.text('Restrictions'), findsOneWidget);
      expect(find.text('Date'), findsOneWidget);
      expect(find.text('Views'), findsOneWidget);
      expect(find.text('Comments'), findsOneWidget);
      expect(find.text('Likes (%)'), findsOneWidget);

      // Verify Video rows render titles
      expect(find.text('Epistemic Truth Ep 1'), findsOneWidget);
      expect(find.text('Fact Checking Deep Dive'), findsOneWidget);

      // Verify View Counts render
      expect(find.text('1.2K'), findsOneWidget);
      expect(find.text('3.5K'), findsOneWidget);

      // Verify sorting by Views when clicking header
      await tester.tap(find.text('Views'));
      await tester.pumpAndSettle();

      // Sorted descending by views: 'Fact Checking Deep Dive' (3500) should be first
      final textWidgets = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).toList();
      final indexV2 = textWidgets.indexOf('Fact Checking Deep Dive');
      final indexV1 = textWidgets.indexOf('Epistemic Truth Ep 1');
      expect(indexV2 < indexV1, isTrue);

      // Verify column toggle menu exists and can be opened
      final customizeIcon = find.byIcon(Icons.view_column_rounded);
      expect(customizeIcon, findsOneWidget);
      await tester.tap(customizeIcon);
      await tester.pumpAndSettle();

      expect(find.text('Restrictions'), findsWidgets);
      expect(find.text('Date'), findsWidgets);
    });

    testWidgets('supports bulk multi-row selection, sticky batch action bar, and Hero thumbnail transitions', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final dummyVideos = [
        Video(
          id: 'v_101',
          title: 'Truth in Media',
          description: 'Analyzing news sources',
          videoUrl: 'https://example.com/video1.mp4',
          thumbnailUrl: 'https://example.com/thumb1.jpg',
          channelId: 'ch_1',
          channelName: 'Channel One',
          ownerId: 'u_1',
          category: 'News',
          tags: const ['news', 'fact'],
          views: 500,
          likeCount: 40,
          commentCount: 12,
          createdAt: Timestamp.fromDate(DateTime(2026, 3)),
        ),
        Video(
          id: 'v_102',
          title: 'AI Verification Protocols',
          description: 'How AI algorithms verify sources',
          videoUrl: 'https://example.com/video2.mp4',
          thumbnailUrl: 'https://example.com/thumb2.jpg',
          channelId: 'ch_1',
          channelName: 'Channel One',
          ownerId: 'u_1',
          category: 'Technology',
          tags: const ['ai', 'verification'],
          views: 980,
          likeCount: 88,
          commentCount: 30,
          createdAt: Timestamp.fromDate(DateTime(2026, 3, 5)),
        ),
      ];

      final controller = Get.put(VideoManagementController());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1400,
              height: 800,
              child: DesktopContentDataTable(
                videos: dummyVideos,
                controller: controller,
                isDarkMode: true,
              ),
            ),
          ),
        ),
      );

      // Verify Hero flight widgets are present for both videos
      final heroV1 = find.byWidgetPredicate(
        (widget) => widget is Hero && widget.tag == 'video-thumb-v_101',
      );
      final heroV2 = find.byWidgetPredicate(
        (widget) => widget is Hero && widget.tag == 'video-thumb-v_102',
      );
      expect(heroV1, findsOneWidget);
      expect(heroV2, findsOneWidget);

      // Verify checkboxes exist (1 in header + 2 in rows = 3 checkboxes)
      final checkboxes = find.byType(Checkbox);
      expect(checkboxes, findsNWidgets(3));

      // Initially no batch action bar
      expect(find.text('Edit Visibility'), findsNothing);
      expect(find.text('Batch AI Pipeline'), findsNothing);

      // Tap first row's checkbox (second checkbox in tree)
      await tester.tap(checkboxes.at(1));
      await tester.pumpAndSettle();

      // Verify sticky batch action bar appears with "1 selected"
      expect(find.text('1 selected'), findsOneWidget);
      expect(find.text('Edit Visibility'), findsOneWidget);
      expect(find.text('Batch AI Pipeline'), findsOneWidget);
      expect(find.text('Delete (1)'), findsOneWidget);

      // Tap header checkbox (first checkbox) to select all
      await tester.tap(checkboxes.first);
      await tester.pumpAndSettle();

      // Now "2 selected" and "Delete (2)"
      expect(find.text('2 selected'), findsOneWidget);
      expect(find.text('Delete (2)'), findsOneWidget);

      // Tap clear selection (close icon)
      final closeBtn = find.byTooltip('Clear selection');
      expect(closeBtn, findsOneWidget);
      await tester.tap(closeBtn);
      await tester.pumpAndSettle();

      // Batch action bar dismissed
      expect(find.text('Edit Visibility'), findsNothing);
      expect(find.text('Batch AI Pipeline'), findsNothing);
    });
  });
}
