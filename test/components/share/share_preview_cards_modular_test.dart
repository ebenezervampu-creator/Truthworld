import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/share/share_preview_cards.dart';

import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  tearDown(Get.reset);

  group('SharePreviewCards Modular Unit & Widget Tests', () {
    testWidgets('1. ShareClipCard renders clip badge, title, channel and duration segment',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ShareClipCard(
              title: 'Breaking News Fact Checked',
              channelName: 'Truth News Network',
              clipStartTime: 5.0,
              clipEndTime: 25.0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CLIP'), findsOneWidget);
      expect(find.text('Truth News Network'), findsOneWidget);
      expect(find.text('Breaking News Fact Checked'), findsOneWidget);
      expect(find.textContaining('Segment: 00:05 - 00:25'), findsOneWidget);
      expect(find.byIcon(Icons.content_cut), findsOneWidget);
    });

    testWidgets('2. ShareClipCard reactive preparation states update properly',
        (tester) async {
      final isPreparing = true.obs;
      final status = 'Encoding 45%'.obs;
      final clipFile = Rxn<File>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShareClipCard(
              title: 'Reactive Clip Test',
              clipStartTime: 0.0,
              clipEndTime: 10.0,
              isPreparingClip: isPreparing,
              clipStatus: status,
              clipFile: clipFile,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Encoding 45%'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      isPreparing.value = false;
      clipFile.value = File('dummy.mp4');
      await tester.pump();

      expect(find.text('Ready to share'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('3. ShareVideoCard renders video badge, title, duration and channel',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ShareVideoCard(
              title: 'Full Fact Checking Investigation',
              channelName: 'Investigative Desk',
              subtitle: '120K views • 2 days ago',
              durationMs: 754000,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('VIDEO'), findsOneWidget);
      expect(find.text('Investigative Desk'), findsOneWidget);
      expect(find.text('Full Fact Checking Investigation'), findsOneWidget);
      expect(find.text('120K views • 2 days ago'), findsOneWidget);
      expect(find.text('12:34'), findsOneWidget);
    });

    testWidgets('3b. ShareVideoCard renders exact architecture with title, 2-line description, Truthworld footer, and tap navigation',
        (tester) async {
      var didTap = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShareVideoCard(
              title: '🚨 BANNED Antibiotics in UNBRANDED Eggs? 🥚 🔬\nLab Test Results || Part 2',
              subtitle: 'Instagram : https://instagram.com/trustified.in?igshid=YmMyMTA2M2Y=...',
              url: 'https://www.truthworld.in/watch/v_12345',
              onTap: () => didTap = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('🚨 BANNED Antibiotics in UNBRANDED Eggs? 🥚 🔬\nLab Test Results || Part 2'), findsOneWidget);
      expect(find.text('Instagram : https://instagram.com/trustified.in?igshid=YmMyMTA2M2Y=...'), findsOneWidget);
      expect(find.text('Truthworld'), findsOneWidget);
      expect(find.byIcon(Icons.link_rounded), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);

      await tester.tap(find.byType(ShareVideoCard));
      await tester.pump();
      expect(didTap, isTrue);
    });

    testWidgets('4. ShareChannelCard renders exact architecture with banner, avatar, title, handle, subscriber count, description, Truthworld footer, and tap navigation',
        (tester) async {
      var didTap = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShareChannelCard(
              title: 'TruthWorld Official',
              handle: 'truthworld',
              subscriberCount: 2500000,
              videoCount: 340,
              subtitle: 'The AI-powered fact checking platform with epistemic clarity and verification.',
              url: 'https://www.truthworld.in/@truthworld',
              onTap: () => didTap = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('TruthWorld Official'), findsOneWidget);
      expect(find.text('@truthworld'), findsOneWidget);
      expect(find.text('2.5M subscribers'), findsOneWidget);
      expect(find.text('The AI-powered fact checking platform with epistemic clarity and verification.'), findsOneWidget);
      expect(find.text('Truthworld'), findsOneWidget);
      expect(find.byIcon(Icons.link_rounded), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);

      await tester.tap(find.byType(ShareChannelCard));
      await tester.pump();
      expect(didTap, isTrue);
    });

    testWidgets('5. SharePlaylistCard renders playlist badge, video count overlay and title',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SharePlaylistCard(
              title: 'Debunked Health Claims',
              channelName: 'Medical Truth Desk',
              videoCount: 24,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('PLAYLIST'), findsOneWidget);
      expect(find.text('Debunked Health Claims'), findsOneWidget);
      expect(find.text('Medical Truth Desk'), findsOneWidget);
      expect(find.text('24'), findsOneWidget);
      expect(find.text('Playlist • 24 videos'), findsOneWidget);
      expect(find.byIcon(Icons.playlist_play_rounded), findsWidgets);
    });

    testWidgets('6. ShareTopicCard renders exact architecture with banner, followers, videos, url pill, and tap navigation without follow button or verified badge',
        (tester) async {
      var didTap = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShareTopicCard(
              title: 'Artificial Intelligence',
              handle: 'ai_technology',
              followerCount: 84000,
              videoCount: 320,
              subtitle: 'Explore the frontiers of deep learning, neural networks and automated verification systems.',
              url: 'https://truthworld.in/T/ai_technology',
              onTap: () => didTap = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Artificial Intelligence'), findsOneWidget);
      expect(find.text('@ ai_technology'), findsOneWidget);
      expect(find.text('84.0K Followers'), findsOneWidget);
      expect(find.text('320 Videos'), findsOneWidget);
      expect(find.text('Explore the frontiers of deep learning, neural networks and automated verification systems.'), findsOneWidget);
      expect(find.text('https://truthworld.in/T/ai_technology'), findsOneWidget);
      expect(find.text('Truthworld'), findsWidgets);
      expect(find.byIcon(Icons.link_rounded), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);

      // Gold verified badge must be removed as per specification
      expect(find.byIcon(Icons.check_rounded), findsNothing);

      // Follow option must be removed as per specification
      expect(find.text('Follow'), findsNothing);
      expect(find.text('+ Follow'), findsNothing);

      await tester.tap(find.byType(ShareTopicCard));
      await tester.pump();
      expect(didTap, isTrue);
    });

    testWidgets('7. SharePreviewCard dispatcher routes correctly by contentType',
        (tester) async {
      // Test Clip Dispatch
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SharePreviewCard(
              contentType: 'clip',
              title: 'Dispatched Clip',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ShareClipCard), findsOneWidget);

      // Test Channel Dispatch
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SharePreviewCard(
              contentType: 'channel',
              title: 'Dispatched Channel',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ShareChannelCard), findsOneWidget);

      // Test Playlist Dispatch
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SharePreviewCard(
              contentType: 'playlist',
              title: 'Dispatched Playlist',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SharePlaylistCard), findsOneWidget);

      // Test Topic Dispatch
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SharePreviewCard(
              contentType: 'topic',
              title: 'Dispatched Topic',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ShareTopicCard), findsOneWidget);

      // Test Video Dispatch
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SharePreviewCard(
              contentType: 'video',
              title: 'Dispatched Video',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ShareVideoCard), findsOneWidget);
    });
  });
}
