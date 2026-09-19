import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/data/models/video_clip.dart';
import 'package:truthworld/features/video/presentation/controllers/user_clips_controller.dart';
import 'package:truthworld/features/video/presentation/views/clips/components/clips_barrel.dart';

class TestUserClipsController extends UserClipsController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestUserClipsController controller;

  final sampleClip1 = VideoClip(
    id: 'clip_1',
    videoId: 'v_101',
    userId: 'user_123',
    videoTitle: 'Exploring Cosmos',
    channelName: 'Space Science',
    title: 'Supernova explosion moment',
    thumbnailUrl: 'https://images.unsplash.com/photo-1506744038136-46273834b3fb',
    startTime: 10.0,
    endTime: 45.0,
    createdAt: DateTime.now(),
  );

  final sampleClip2 = VideoClip(
    id: 'clip_2',
    videoId: 'v_102',
    userId: 'user_123',
    videoTitle: 'Quantum Physics',
    channelName: 'Quantum Tech',
    title: 'Entanglement explained',
    thumbnailUrl: 'https://images.unsplash.com/photo-1506744038136-46273834b3fb',
    startTime: 60.0,
    endTime: 120.0,
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
  );

  final sampleClip3 = VideoClip(
    id: 'clip_3',
    videoId: 'v_103',
    userId: 'user_123',
    videoTitle: 'Ancient History',
    channelName: 'History Channel',
    title: 'Pyramids architecture',
    thumbnailUrl: 'https://images.unsplash.com/photo-1506744038136-46273834b3fb',
    startTime: 5.0,
    endTime: 30.0,
    createdAt: DateTime.now().subtract(const Duration(days: 5)),
  );

  setUp(() {
    Get.reset();
    controller = TestUserClipsController();
    Get.put<UserClipsController>(controller);
    controller.clips.assignAll([sampleClip1, sampleClip2, sampleClip3]);
    controller.rxIsLoading.value = false;
  });

  tearDown(Get.reset);

  group('UserClipsController Unit Tests', () {
    test('toggleView switches between list and grid view', () {
      expect(controller.isListView.value, isTrue);
      controller.toggleView();
      expect(controller.isListView.value, isFalse);
      controller.toggleView();
      expect(controller.isListView.value, isTrue);
    });

    test('setCategory updates selectedCategory', () {
      expect(controller.selectedCategory.value, equals('All'));
      controller.setCategory('Recent');
      expect(controller.selectedCategory.value, equals('Recent'));
    });

    test('filteredClips returns all clips when search is empty', () {
      controller.searchQuery.value = '';
      expect(controller.filteredClips.length, equals(3));
    });

    test('filteredClips filters by title, videoTitle, or channelName', () {
      controller.searchQuery.value = 'supernova';
      expect(controller.filteredClips.length, equals(1));
      expect(controller.filteredClips.first.id, equals('clip_1'));

      controller.searchQuery.value = 'Quantum Tech';
      expect(controller.filteredClips.length, equals(1));
      expect(controller.filteredClips.first.id, equals('clip_2'));

      controller.searchQuery.value = 'Ancient';
      expect(controller.filteredClips.length, equals(1));
      expect(controller.filteredClips.first.id, equals('clip_3'));
    });

    test('formatTimeAgo handles various durations correctly', () {
      final now = DateTime.now();
      expect(controller.formatTimeAgo(now), equals('Just now'));
      expect(
        controller.formatTimeAgo(now.subtract(const Duration(minutes: 5))),
        equals('5 minutes ago'),
      );
      expect(
        controller.formatTimeAgo(now.subtract(const Duration(hours: 3))),
        equals('3 hours ago'),
      );
      expect(
        controller.formatTimeAgo(now.subtract(const Duration(days: 2))),
        equals('2 days ago'),
      );
      expect(
        controller.formatTimeAgo(now.subtract(const Duration(days: 45))),
        equals('1 month ago'),
      );
      expect(
        controller.formatTimeAgo(now.subtract(const Duration(days: 400))),
        equals('1 year ago'),
      );
    });

    test('groupClipsByDate groups clips into Today, Yesterday, and date keys', () {
      final groups = controller.groupClipsByDate([
        sampleClip1,
        sampleClip2,
        sampleClip3,
      ]);
      expect(groups.containsKey('Today'), isTrue);
      expect(groups['Today']!.first.id, equals('clip_1'));
      expect(groups.containsKey('Yesterday'), isTrue);
      expect(groups['Yesterday']!.first.id, equals('clip_2'));
      expect(groups.length, equals(3));
    });
  });

  group('Clips Modular Widgets Tests', () {
    testWidgets('ClipsEmptyState renders correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ClipsEmptyState(),
          ),
        ),
      );

      expect(find.text('No clips yet'), findsOneWidget);
      expect(
        find.text('Find your favorite moments and clip them!'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.content_cut_rounded), findsOneWidget);
    });

    testWidgets('ClipsCategoryChips renders chips and reacts to selection', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ClipsCategoryChips(controller: controller),
          ),
        ),
      );

      expect(find.text('All'), findsOneWidget);
      expect(find.text('Recent'), findsOneWidget);

      await tester.tap(find.text('Recent'));
      await tester.pumpAndSettle();

      expect(controller.selectedCategory.value, equals('Recent'));
    });

    testWidgets('ClipsHeader renders search toggle and back button', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ClipsHeader(
              controller: controller,
              isDashboard: false,
            ),
          ),
        ),
      );

      expect(find.text('Your Clips'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);

      // Expand search
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      expect(controller.isSearchExpanded.value, isTrue);
      expect(find.byType(TextField), findsOneWidget);

      // Close search
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(controller.isSearchExpanded.value, isFalse);
      expect(find.text('Your Clips'), findsOneWidget);
    });

    testWidgets('ClipVideoListCard renders title, channel and duration', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ClipVideoListCard(
              clip: sampleClip1,
              controller: controller,
            ),
          ),
        ),
      );

      expect(find.text('Supernova explosion moment'), findsOneWidget);
      expect(find.textContaining('Space Science'), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets('ClipVideoGridCard renders title and options icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ClipVideoGridCard(
              clip: sampleClip1,
              controller: controller,
            ),
          ),
        ),
      );

      expect(find.text('Supernova explosion moment'), findsOneWidget);
      expect(find.text('Exploring Cosmos'), findsOneWidget);
      expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);
    });
  });
}
