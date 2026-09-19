import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/share_bottom_sheet.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  tearDown(Get.reset);

  group('ShareBottomSheet Modular Unit & Widget Tests', () {
    test('1. ShareUtils.detectType correctly classifies content', () {
      expect(
        ShareUtils.detectType(
          url: 'https://truthworld.in/clip?start=10&end=25',
        ),
        equals('clip'),
      );

      expect(
        ShareUtils.detectType(
          url: 'https://truthworld.in/watch?v=vid123',
          durationMs: 60000,
        ),
        equals('video'),
      );

      expect(
        ShareUtils.detectType(
          url: 'https://truthworld.in/channel/chan1',
          handle: '@TruthCreator',
        ),
        equals('channel'),
      );

      expect(
        ShareUtils.detectType(
          url: 'https://truthworld.in/playlist/pl1',
          videoCount: 15,
        ),
        equals('playlist'),
      );

      expect(
        ShareUtils.detectType(
          url: 'https://truthworld.in/topic/science',
          followerCount: 500,
        ),
        equals('topic'),
      );
    });

    test('2. ShareUtils formatting functions produce expected outputs', () {
      // Duration formatting
      expect(ShareUtils.formatDuration(const Duration(seconds: 45)), equals('0:45'));
      expect(ShareUtils.formatDuration(const Duration(minutes: 3, seconds: 12)), equals('3:12'));
      expect(ShareUtils.formatDuration(const Duration(hours: 1, minutes: 2, seconds: 3)), equals('1:02:03'));
      expect(ShareUtils.formatMsDuration(90000), equals('1:30'));

      // Count formatting
      expect(ShareUtils.formatCount(450), equals('450'));
      expect(ShareUtils.formatCount(1500), equals('1.5K'));
      expect(ShareUtils.formatCount(2400000), equals('2.4M'));

      // Video ID extraction
      expect(ShareUtils.extractVideoId('https://truthworld.in/watch?v=abc1234'), equals('abc1234'));
      expect(ShareUtils.extractVideoId('https://truthworld.in/watch/xyz789'), equals('xyz789'));

      // Share URL timestamp parameter
      expect(
        ShareUtils.getShareUrl(
          url: 'https://truthworld.in/watch?v=123',
          startAtChecked: false,
          currentPosition: const Duration(seconds: 30),
        ),
        equals('https://truthworld.in/watch?v=123'),
      );
      expect(
        ShareUtils.getShareUrl(
          url: 'https://truthworld.in/watch?v=123',
          startAtChecked: true,
          currentPosition: const Duration(seconds: 30),
        ),
        equals('https://truthworld.in/watch?v=123&t=30'),
      );
    });

    test('3. ShareDispatcher.buildShareMessage formats clean platform captions', () {
      final videoMsg = ShareDispatcher.buildShareMessage(
        title: 'Quantum Computing Explained',
        shareUrl: 'https://truthworld.in/watch?v=quantum',
        contentType: 'video',
        channelName: 'Science Daily',
      );
      expect(videoMsg, contains('Watch "Quantum Computing Explained" by Science Daily'));
      expect(videoMsg, contains('https://truthworld.in/watch?v=quantum'));

      final chanMsg = ShareDispatcher.buildShareMessage(
        title: 'Science Daily',
        shareUrl: 'https://truthworld.in/channel/scidaily',
        contentType: 'channel',
        handle: '@scidaily',
      );
      expect(chanMsg, contains('Check out Science Daily (@scidaily)'));

      final playlistMsg = ShareDispatcher.buildShareMessage(
        title: 'Flutter Tutorials',
        shareUrl: 'https://truthworld.in/playlist/flutter',
        contentType: 'playlist',
      );
      expect(playlistMsg, contains('Check out "Flutter Tutorials" playlist'));
    });

    testWidgets('4. ShareSocialIcon renders with white icon and handles tap', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShareSocialIcon(
              label: 'WhatsApp',
              icon: Icons.share_rounded,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.byIcon(Icons.share_rounded), findsOneWidget);

      await tester.tap(find.text('WhatsApp'));
      expect(tapped, isTrue);
    });

    testWidgets('5. ShareMainPanel renders preview card, start-at checkbox, and actions', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final startAt = false.obs;
      final showEmbed = false.obs;
      final isPrep = false.obs;
      final clipFile = Rxn<File>();
      final clipStatus = ''.obs;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShareMainPanel(
              title: 'AI Revolution',
              url: 'https://truthworld.in/watch?v=ai',
              contentType: 'video',
              startAtChecked: startAt,
              showEmbedPanel: showEmbed,
              isPreparingClip: isPrep,
              clipFile: clipFile,
              clipStatus: clipStatus,
              currentPosition: const Duration(seconds: 45),
            ),
          ),
        ),
      );

      expect(find.text('Share'), findsOneWidget);
      expect(find.text('AI Revolution'), findsOneWidget);
      expect(find.text('Start at 0:45'), findsOneWidget);
      expect(find.text('Copy Link'), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);
    });

    testWidgets('6. ShareTikTokClipPanel renders clip header and actions', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final isPrep = false.obs;
      final clipFile = Rxn<File>();
      final clipProg = 0.0.obs;
      final clipStatus = ''.obs;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShareTikTokClipPanel(
              title: 'Best Goal Ever',
              url: 'https://truthworld.in/clip?id=goal',
              isPreparingClip: isPrep,
              clipFile: clipFile,
              clipProgress: clipProg,
              clipStatus: clipStatus,
            ),
          ),
        ),
      );

      expect(find.text('Share video clip to'), findsOneWidget);
      expect(find.text('Share Video'), findsOneWidget);
      expect(find.text('Actions'), findsOneWidget);
      expect(find.text('Save Video'), findsOneWidget);
      expect(find.text('Copy Link'), findsOneWidget);
      expect(find.text('Share Link'), findsOneWidget);
    });

    testWidgets('7. ShareBottomSheet widget renders gracefully in bottom sheet', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const GetMaterialApp(
          home: Scaffold(
            body: ShareBottomSheet(
              title: 'TruthWorld Demo',
              url: 'https://truthworld.in/watch?v=demo',
            ),
          ),
        ),
      );

      expect(find.byType(ShareBottomSheet), findsOneWidget);
      expect(find.byType(ShareMainPanel), findsOneWidget);
    });
  });
}
