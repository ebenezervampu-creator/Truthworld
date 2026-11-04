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
import 'package:truthworld/features/video/data/models/video.dart';
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
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets(
    'Ask AI suggests real TruthWorld videos when user asks "Suggest better videos in this topic"',
    (tester) async {
      final mockSsePayload = [
        'data: ${jsonEncode({
          "type": "metadata",
          "sources": [],
          "suggestedFollowups": ["Summarize verified claims", "What are the primary sources?"],
          "scope": "video",
          "disclaimer": "TruthWorld: Recommending verified videos from our empirical truth ledger.",
        })}\n\n',
        'data: ${jsonEncode({
          "type": "delta",
          "text": '### Recommended Videos on TruthWorld for "10 Facts about India"\n\n'
              'Here are top recommended and verified videos available directly on **TruthWorld** exploring this topic with transparent evidence:\n\n'
              '• **"India: Ancient Heritage and Modern Science"** by **Discovery India**\n'
              '  *Category: Education* • 🛡️ *TruthWorld Verified*\n'
              '  Offers verified coverage, transparent source citations, and objective analysis.\n\n'
              '• **"Kerala: Culture, History & Ecology"** by **Incredible Travel**\n'
              '  *Category: Travel & Events* • 🛡️ *TruthWorld Verified*\n'
              '  In-depth documentary exploring regional heritage.',
        })}\n\n',
        'data: ${jsonEncode({"type": "done"})}\n\n',
        'data: [DONE]\n\n',
      ].join();

      final mockClient = MockClient.streaming((request, bodyStream) async {
        final stream = Stream.value(utf8.encode(mockSsePayload));
        return http.StreamedResponse(stream, 200, headers: {
          'content-type': 'text/event-stream; charset=utf-8',
        });
      });

      AppHttpClient.instance.client = mockClient;

      final testVideo = Video(
        id: 'd0669086-0f1a-4017-8606-346188af6bb8',
        title: '10 Facts about India',
        description: 'Empirical fact check of 10 assertions about India.',
        thumbnailUrl: 'https://truthworld.in/thumb.jpg',
        ownerId: 'creator_india_01',
        channelId: 'ch_india_01',
        channelName: 'Knowledge Hub',
        category: 'Education',
        tags: const ['india', 'facts', 'culture'],
      );

      final controllerTag = '${testVideo.id}_video_all';
      final controller = Get.put(AiCredibilityChatController(), tag: controllerTag);
      controller.initScope(
        targetVideoId: testVideo.id,
        targetScope: 'video',
        video: testVideo,
        title: testVideo.title,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.black,
            body: AiCredibilityChatSheet(
              video: testVideo,
              scope: 'video',
              isEmbedded: true,
              hideHeader: true,
            ),
          ),
        ),
      );
      await tester.pump();

      // Trigger the prompt "Suggest better videos in this topic"
      await controller.sendMessage('Suggest better videos in this topic');
      await tester.pump();

      // Drain typewriter animation timer
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 25));
      }

      // Verify TruthWorld video recommendations are surfaced
      expect(find.textContaining('Recommended Videos on TruthWorld'), findsWidgets);
      expect(find.textContaining('India: Ancient Heritage and Modern Science'), findsWidgets);
      expect(find.textContaining('TruthWorld Verified'), findsWidgets);
      expect(find.textContaining('Kerala: Culture, History & Ecology'), findsWidgets);

      // Verify external irrelevant publications (Bloomberg, The Ken, dark store) are NEVER shown
      expect(find.textContaining('Bloomberg'), findsNothing);
      expect(find.textContaining('The Ken'), findsNothing);
      expect(find.textContaining('dark store'), findsNothing);
    },
  );
}
