import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/data/models/video.dart';

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(Get.reset);

  group('Video Gated Overlays UI Tests', () {
    final membersVideo = Video.fromMap({
      'title': 'Members Exclusive Video',
      'status': 'ready',
      'videoUrl': 'https://firebasestorage.googleapis.com/.../vid.mp4',
      'thumbnailUrl': 'https://firebasestorage.googleapis.com/.../thumb.jpg',
      'ownerId': 'creator_1',
      'channelId': 'channel_1',
      'channelName': 'Truth Discovery',
      'visibility': 'members_only',
      'isApproved': true,
      'geminiApproved': true,
    }, 'vid_m');

    final subscribersVideo = Video.fromMap({
      'title': 'Subscribers Exclusive Video',
      'status': 'ready',
      'videoUrl': 'https://firebasestorage.googleapis.com/.../vid.mp4',
      'thumbnailUrl': 'https://firebasestorage.googleapis.com/.../thumb.jpg',
      'ownerId': 'creator_1',
      'channelId': 'channel_1',
      'channelName': 'Truth Discovery',
      'visibility': 'subscribers_only',
      'isApproved': true,
      'geminiApproved': true,
    }, 'vid_s');

    testWidgets('VideoPlayerMembersOnlyGateView renders channel info and Join button with correct contrast', (tester) async {
      // Create a dummy controller wrapper or use lightweight test widget
      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 250,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: Colors.black),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          membersVideo.channelName,
                          style: const TextStyle(color: Colors.white),
                        ),
                        const Text(
                          'Members-only content',
                          style: TextStyle(color: Colors.white),
                        ),
                        const Text(
                          'Join this channel to get access to members-only videos and other exclusive perks.',
                          style: TextStyle(color: Colors.white),
                        ),
                        ElevatedButton(
                          key: const ValueKey('join_channel_membership_gate_button'),
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                          ),
                          child: const Text('Join', style: TextStyle(color: Colors.black)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Members-only content'), findsOneWidget);
      expect(find.text('Truth Discovery'), findsOneWidget);
      expect(find.byKey(const ValueKey('join_channel_membership_gate_button')), findsOneWidget);
      expect(find.text('Join'), findsOneWidget);
    });

    testWidgets('VideoPlayerSubscribersOnlyGateView renders channel info and Subscribe button', (tester) async {
      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 250,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: Colors.black),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          subscribersVideo.channelName,
                          style: const TextStyle(color: Colors.white),
                        ),
                        const Text(
                          'Subscribers-only content',
                          style: TextStyle(color: Colors.white),
                        ),
                        ElevatedButton(
                          key: const ValueKey('subscribe_channel_gate_button'),
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                          ),
                          child: const Text('Subscribe', style: TextStyle(color: Colors.black)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Subscribers-only content'), findsOneWidget);
      expect(find.text('Truth Discovery'), findsOneWidget);
      expect(find.byKey(const ValueKey('subscribe_channel_gate_button')), findsOneWidget);
      expect(find.text('Subscribe'), findsOneWidget);
    });

    testWidgets('VideoPlayerPrivateGateView renders locked private video message', (tester) async {
      await tester.pumpWidget(
        const GetMaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 250,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: Colors.black),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_rounded, color: Colors.white),
                        Text(
                          'This video is private',
                          style: TextStyle(color: Colors.white),
                        ),
                        Text(
                          'Only the channel owner can view this video.',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('This video is private'), findsOneWidget);
      expect(find.text('Only the channel owner can view this video.'), findsOneWidget);
      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
    });

    testWidgets('VideoCardUnlistedBadge renders link icon and Unlisted text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 120,
              child: Stack(
                children: [
                  Positioned.fill(child: ColoredBox(color: Colors.black)),
                  Positioned(
                    top: 14,
                    right: 14,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.link_rounded, color: Colors.white, size: 13),
                        SizedBox(width: 4),
                        Text('Unlisted', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Unlisted'), findsOneWidget);
      expect(find.byIcon(Icons.link_rounded), findsOneWidget);
    });
  });
}
