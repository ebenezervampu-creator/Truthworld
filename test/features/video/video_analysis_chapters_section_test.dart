import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/models/video_chapter.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/widgets/analysis/video_analysis_chapters_section.dart';

import '../../test_helpers/mock_firebase.dart';

class _FakeAuthService extends GetxService implements AuthService {
  @override
  String get uid => 'test_uid';
  @override
  Channel? get userChannel => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  setUp(() {
    Get.reset();
    Get.put<AuthService>(_FakeAuthService());
  });

  tearDown(Get.reset);

  final testVideo = Video(
    id: 'vid_chapters_test',
    title: 'Jio IPO 2026 Test',
    description: 'Detailed analysis of Jio IPO issue size and dates.',
    videoUrl: 'https://example.com/video.mp4',
    thumbnailUrl: 'https://example.com/thumb.jpg',
    ownerId: 'owner_1',
    channelId: 'channel_1',
    channelName: 'Truthworld Finance',
    category: 'Finance',
    tags: const ['ipo', 'jio'],
    createdAt: DateTime.now(),
    duration: const Duration(minutes: 4, seconds: 33),
    chapters: [
      VideoChapter(
        title: 'Introduction & Overview',
        startTime: Duration.zero,
      ),
      VideoChapter(
        title: 'Issue Size & Valuations',
        startTime: const Duration(minutes: 1, seconds: 15),
      ),
      VideoChapter(
        title: 'Key Dates & Anchor Bids',
        startTime: const Duration(minutes: 2, seconds: 45),
      ),
    ],
  );

  testWidgets('Renders properly when chapters is List<VideoChapter> without TypeError', (tester) async {
    final videoCtrl = VideoController();
    videoCtrl.video = testVideo;

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: VideoAnalysisChaptersSection(
              chapters: testVideo.chapters,
              videoCtrl: videoCtrl,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('CHAPTER CREDIBILITY & KEY TOPICS (3)'), findsOneWidget);
    expect(find.text('Introduction & Overview'), findsOneWidget);
    expect(find.text('Issue Size & Valuations'), findsOneWidget);
    expect(find.text('Key Dates & Anchor Bids'), findsOneWidget);

    // Verify duration ranges calculated correctly
    expect(find.text('00:00 - 01:15'), findsOneWidget);
    expect(find.text('01:15 - 02:45'), findsOneWidget);
    expect(find.text('02:45 - 04:33'), findsOneWidget);
  });

  testWidgets('Renders properly when chapters is List<Map<String, dynamic>> with trust scores', (tester) async {
    final videoCtrl = VideoController();
    videoCtrl.video = testVideo;

    final mapChapters = [
      {
        'title': 'Claim 1: Valuations',
        'startMs': 0,
        'endMs': 60000,
        'trustIndex': 9.2,
        'primaryTopics': ['Valuation', 'Financials'],
      },
      {
        'title': 'Claim 2: Listing Dates',
        'startMs': 60000,
        'endMs': 120000,
        'trustIndex': 88,
        'topics': ['Regulatory', 'SEBI'],
      },
    ];

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: VideoAnalysisChaptersSection(
              chapters: mapChapters,
              videoCtrl: videoCtrl,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('CHAPTER CREDIBILITY & KEY TOPICS (2)'), findsOneWidget);
    expect(find.text('Claim 1: Valuations'), findsOneWidget);
    expect(find.text('Claim 2: Listing Dates'), findsOneWidget);
    expect(find.text('9.2'), findsOneWidget);
    expect(find.text('88%'), findsOneWidget);
    expect(find.text('Valuation'), findsOneWidget);
    expect(find.text('SEBI'), findsOneWidget);
  });
}
