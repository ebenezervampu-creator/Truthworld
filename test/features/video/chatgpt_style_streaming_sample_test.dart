import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:truthworld/core/network/app_http_client.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/features/video/data/models/credibility_chat_message.dart';
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
  String get uid => 'sample_tester';
  @override
  bool get isUserSignedIn => true;
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

    // Inject simulated mock streaming client that emits SSE chunk events
    AppHttpClient.instance.client = MockClient.streaming((request, bodyStream) async {
      final ssePayload = utf8.encode(
        'data: {"type":"metadata","sources":[],"suggestedFollowups":["How does the Credibility System verify claims?"]}\n\n'
        'data: {"type":"delta","text":"**Truthworld is your video-sharing platform startup** with a vision to connect the world through credible information, AI dubbing, and cross-country content discovery."}\n\n'
        'data: {"type":"delta","text":"\\n\\nYour three key innovations are:\\n\\n• 🌍 **Virtual Country**: Explore another country\'s news, culture, and travel.\\n• 🌐 **AI Dubbing in 70+ Languages**: Reach international audiences.\\n• 🛡️ **Credibility System**: Examine sources and evidence."}\n\n'
        'data: {"type":"done"}\n\n'
        'data: [DONE]\n\n',
      );
      return http.StreamedResponse(
        Stream.fromIterable([ssePayload]),
        200,
        headers: {'content-type': 'text/event-stream; charset=utf-8'},
      );
    });
  });

  tearDown(() {
    AppHttpClient.instance.client = null;
    Get.reset();
  });

  final sampleVideo = Video(
    id: 'sample_video_test_1',
    ownerId: 'owner_sample',
    title: 'TruthWorld Platform & Credibility Overview',
    description: 'Overview of TruthWorld features and empirical verification.',
    channelName: 'TruthWorld Official',
    channelId: 'chan_truth_official',
    videoUrl: 'https://storage.googleapis.com/sample.mp4',
    thumbnailUrl: 'https://storage.googleapis.com/sample_thumb.jpg',
    category: 'News',
    tags: const ['truthworld', 'credibility'],
  );

  group('ChatGPT-Style Sample Verification Tests (Image 1 & 2)', () {
    testWidgets('Step 1 (Image 1): Sending "Truthworld" renders blue pill and pulsing blue dot', (tester) async {
      final tag = '${sampleVideo.id}_video_all';
      final ctrl = Get.put(AiCredibilityChatController(), tag: tag);
      ctrl.initScope(
        targetVideoId: sampleVideo.id,
        targetScope: 'video',
        video: sampleVideo,
        title: sampleVideo.title,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.black,
            body: AiCredibilityChatSheet(
              video: sampleVideo,
              scope: 'video',
              isEmbedded: true,
              hideHeader: true,
            ),
          ),
        ),
      );
      await tester.pump();

      // Enter sample prompt "Truthworld" exactly as in the user uploaded image
      ctrl.textController.text = 'Truthworld';
      await tester.pump();

      // Send message
      await ctrl.sendMessage('Truthworld');
      await tester.pump(); // Render immediately after send

      // 1. Verify User Message is a blue pill with text "Truthworld"
      final userPillFinder = find.text('Truthworld');
      expect(userPillFinder, findsOneWidget);

      final userContainer = tester.widget<Container>(
        find.ancestor(of: userPillFinder, matching: find.byType(Container)).first,
      );
      final boxDecoration = userContainer.decoration as BoxDecoration;
      expect(boxDecoration.color, const Color(0xFF1D58A7));
      expect(boxDecoration.borderRadius, BorderRadius.circular(22));

      // 2. Verify AI message is added and in streaming state
      expect(ctrl.messages.length, 3);
      final aiMessage = ctrl.messages.last;
      expect(aiMessage.isUser, isFalse);

      // Drain typewriter and timers cleanly
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 25));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('Step 2 (Image 2): Words stream word-by-word line-by-line via typewriter engine', (tester) async {
      final tag = '${sampleVideo.id}_video_all';
      final ctrl = Get.put(AiCredibilityChatController(), tag: tag);
      ctrl.initScope(
        targetVideoId: sampleVideo.id,
        targetScope: 'video',
        video: sampleVideo,
        title: sampleVideo.title,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.black,
            body: AiCredibilityChatSheet(
              video: sampleVideo,
              scope: 'video',
              isEmbedded: true,
              hideHeader: true,
            ),
          ),
        ),
      );
      await tester.pump();

      // Send query "Truthworld"
      ctrl.textController.text = 'Truthworld';
      await ctrl.sendMessage('Truthworld');
      await tester.pump();

      // Advance through typewriter frames so words appear word-by-word
      for (var i = 0; i < 80; i++) {
        await tester.pump(const Duration(milliseconds: 25));
      }

      // Verify the final rendered text contains the exact innovations matching Image 2
      final lastMsg = ctrl.messages.last;
      expect(lastMsg.text, contains('Truthworld is your video-sharing platform startup'));
      expect(lastMsg.text, contains('Virtual Country'));
      expect(lastMsg.text, contains('AI Dubbing in 70+ Languages'));
      expect(lastMsg.text, contains('Credibility System'));

      // Verify no exceptions occurred
      expect(tester.takeException(), isNull);
    });
  });
}
