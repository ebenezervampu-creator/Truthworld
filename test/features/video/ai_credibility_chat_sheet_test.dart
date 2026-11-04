import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/services/ai_credibility_chat_service.dart';
import 'package:truthworld/features/video/presentation/controllers/ai_credibility_chat_controller.dart';
import 'package:truthworld/features/video/presentation/widgets/analysis/ai_chat/ai_credibility_chat_sheet.dart';

import '../../test_helpers/mock_firebase.dart';

class _FakeConnectivityService extends GetxService implements ConnectivityService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuthService extends GetxService implements AuthService {
  @override
  String get uid => 'test_user';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await setupMockFirebase();
  });

  setUp(() {
    Get.reset();
    Get.put<AuthService>(_FakeAuthService());
    Get.put<ConnectivityService>(_FakeConnectivityService());
  });

  tearDown(Get.reset);

  final testVideo = Video(
    id: 'test_vid_123',
    ownerId: 'owner_123',
    title: 'Are Eggs Vegetarian or Non-Vegetarian?',
    description: 'Scientific and biological analysis of unfertilized eggs.',
    channelName: 'The Science & Truth Explained',
    channelId: 'chan_science_1',
    videoUrl: 'https://storage.googleapis.com/test.mp4',
    thumbnailUrl: 'https://storage.googleapis.com/thumb.jpg',
    category: 'Science',
    tags: const ['science', 'truth'],
  );

  group('AiCredibilityChatSheet Tests', () {
    testWidgets('Renders on narrow 320px viewport without RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(320 * 2.0, 700 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final tag = '${testVideo.id}_claim_8';
      final ctrl = Get.put(AiCredibilityChatController(), tag: tag);
      ctrl.initScope(
        targetVideoId: testVideo.id,
        targetScope: 'claim',
        video: testVideo,
        targetClaimIndex: 8,
        targetClaimText: 'A stated that eggs are almost always unfertilized and lack embryonic life.',
        targetVerdict: 'VERIFIED TRUE',
        title: testVideo.title,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiCredibilityChatSheet(
              video: testVideo,
              scope: 'claim',
              claimIndex: 8,
              claimText: 'A stated that eggs are almost always unfertilized and lack embryonic life.',
              verdict: 'VERIFIED TRUE',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Truth AI • Claim #9'), findsOneWidget);
      expect(find.text('VERIFIED TRUE'), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders whole video scope without exception', (tester) async {
      tester.view.physicalSize = const Size(375 * 2.0, 812 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final tag = '${testVideo.id}_video_all';
      final ctrl = Get.put(AiCredibilityChatController(), tag: tag);
      ctrl.initScope(
        targetVideoId: testVideo.id,
        targetScope: 'video',
        video: testVideo,
        title: testVideo.title,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiCredibilityChatSheet(
              video: testVideo,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Truth Intelligence AI'), findsOneWidget);
      expect(find.text(testVideo.title), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Embedded in VideoAnalysisView tab directly auto-initializes scope with video context', (tester) async {
      tester.view.physicalSize = const Size(375 * 2.0, 812 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      var didCallClose = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiCredibilityChatSheet(
              video: testVideo,
              allSources: const [
                {'title': 'Nature Scientific Reports', 'url': 'https://nature.com/articles/srep123'},
              ],
              isEmbedded: true,
              onClose: () => didCallClose = true,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final tag = '${testVideo.id}_video_all';
      expect(Get.isRegistered<AiCredibilityChatController>(tag: tag), isTrue);
      final ctrl = Get.find<AiCredibilityChatController>(tag: tag);
      expect(ctrl.videoId.value, equals(testVideo.id));
      expect(ctrl.videoTitle.value, equals(testVideo.title));
      expect(ctrl.messages.isNotEmpty, isTrue);
      expect(ctrl.cachedSources.length, equals(1));
      expect(find.text('Truth Intelligence AI'), findsOneWidget);
      expect(find.text(testVideo.title), findsOneWidget);

      // Verify close button calls onClose
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      expect(didCallClose, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('User asking "hi" receives polite greeting without delay or error', (tester) async {
      AiCredibilityChatService.instance.callableHandler = (payload) async {
        throw Exception('Simulated cloud function internal error [firebase_functions/internal]');
      };
      addTearDown(() => AiCredibilityChatService.instance.callableHandler = null);

      final msg = await AiCredibilityChatService.instance.askCredibilityAi(
        videoId: testVideo.id,
        userQuery: 'hi',
        scope: 'video',
        videoTitle: testVideo.title,
        trustScore: 88,
        cachedSources: const [
          {'title': 'Poultry Science Journal', 'url': 'https://example.org/poultry'},
        ],
      );

      expect(msg.isUser, isFalse);
      expect(msg.text.contains('Hello!'), isTrue);
      expect(msg.text.contains('Are Eggs Vegetarian or Non-Vegetarian?'), isTrue);
      expect(msg.text.contains('temporary processing delay'), isFalse);
      expect(msg.suggestedFollowups.isNotEmpty, isTrue);
    });

    testWidgets('User asking about sources receives verified primary sources', (tester) async {
      AiCredibilityChatService.instance.callableHandler = (payload) async {
        throw Exception('Simulated cloud function internal error [firebase_functions/internal]');
      };
      addTearDown(() => AiCredibilityChatService.instance.callableHandler = null);

      final msg = await AiCredibilityChatService.instance.askCredibilityAi(
        videoId: testVideo.id,
        userQuery: 'what are the primary sources?',
        scope: 'video',
        videoTitle: testVideo.title,
        trustScore: 92,
        cachedSources: const [
          {'title': 'USDA Dietary Guidelines', 'url': 'https://usda.gov/egg-guidelines'},
        ],
      );

      expect(msg.isUser, isFalse);
      expect(msg.text.contains('primary verified sources'), isTrue);
      expect(msg.sources.isNotEmpty, isTrue);
      expect(msg.sources.first.title, equals('USDA Dietary Guidelines'));
    });
  });
}
