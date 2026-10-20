import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/video_card.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    await setupMockFirebase();
  });

  setUp(() {
    Get.reset();
    Get.testMode = true;
    if (!Get.isRegistered<ConnectivityService>()) {
      Get.put<ConnectivityService>(ConnectivityService(), permanent: true);
    }
  });

  tearDown(Get.reset);

  Widget wrapWithMaterial(Widget child) {
    return GetMaterialApp(
      home: Scaffold(
        body: child,
      ),
    );
  }

  final sampleVideo = Video.fromMap({
    'title': 'TruthWorld Modular Architecture Deep Dive',
    'channelId': 'chan_mod_1',
    'channelName': 'TruthWorld Engineering',
    'channelAvatarUrl': 'https://example.com/avatar.jpg',
    'videoUrl': 'https://example.com/video.mp4',
    'thumbnailUrl': 'https://example.com/thumb.jpg',
    'duration': '12:34',
    'durationMs': 754000,
    'views': 125400,
    'isFactChecked': true,
    'uploadedAt': Timestamp.now(),
  }, 'vid_mod_card_1');

  group('VideoCard Modular Architecture Tests', () {
    test('1. VideoCardFormatters formats views count across scales', () {
      expect(VideoCardFormatters.formatViews(500), equals('500'));
      expect(VideoCardFormatters.formatViews(1500), equals('1.5K'));
      expect(VideoCardFormatters.formatViews(2000), equals('2K'));
      expect(VideoCardFormatters.formatViews(250000), equals('250K'));
      expect(VideoCardFormatters.formatViews(1500000), equals('1.5M'));
      expect(VideoCardFormatters.formatViews(3000000), equals('3M'));
      expect(VideoCardFormatters.formatViews(2500000000), equals('2.5B'));
    });

    test('2. VideoCardFormatters formats timestamp safely', () {
      final now = Timestamp.now();
      expect(VideoCardFormatters.formatTimestamp(now), isNotEmpty);
    });

    testWidgets('3. VideoCardAvatar renders placeholder with initials when image is missing',
        (tester) async {
      await tester.pumpWidget(
        wrapWithMaterial(
          const VideoCardAvatar(
            radius: 20,
            imageUrl: '',
            placeholderText: 'TruthWorld',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('T'), findsOneWidget);
    });

    testWidgets('4. VideoCardFactCheckBadge renders emerald badge and verified icon',
        (tester) async {
      await tester.pumpWidget(
        wrapWithMaterial(
          const Stack(
            children: [
              VideoCardFactCheckBadge(),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(VideoCardFactCheckBadge), findsOneWidget);
      expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
    });

    testWidgets('5. VideoCardDurationBadge renders duration label and verified icon when fact checked',
        (tester) async {
      await tester.pumpWidget(
        wrapWithMaterial(
          const Stack(
            children: [
              VideoCardDurationBadge(
                duration: '10:45',
                isFactChecked: true,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('10:45'), findsOneWidget);
      expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
    });

    testWidgets('6. VideoCardAudioToggle toggles global mute state',
        (tester) async {
      final controller = VideoCardController(video: sampleVideo);
      HoverPreviewCoordinator.globalMute.value = false;

      await tester.pumpWidget(
        wrapWithMaterial(
          Stack(
            children: [
              VideoCardAudioToggle(controller: controller),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);

      await tester.tap(find.byType(VideoCardAudioToggle));
      await tester.pumpAndSettle();

      expect(HoverPreviewCoordinator.globalMute.value, isTrue);
      expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
    });

    testWidgets('7. VideoCardController manages hover playback flow',
        (tester) async {
      final controller = VideoCardController(video: sampleVideo);
      expect(controller.isHovered, isFalse);

      controller.handleHoverEnter();
      expect(controller.isHovered, isTrue);

      controller.handleHoverExit();
      expect(controller.isHovered, isFalse);
    });

    testWidgets('8. VideoCard renders in grid mode with all elements',
        (tester) async {
      await tester.pumpWidget(
        wrapWithMaterial(
          VideoCard(
            video: sampleVideo,
            isGrid: true,
            disableHoverPreview: true,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text(sampleVideo.title), findsOneWidget);
      expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
      expect(find.text(sampleVideo.duration), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets('9. VideoCard renders in list mode with thumbnail and info',
        (tester) async {
      await tester.pumpWidget(
        wrapWithMaterial(
          VideoCard(
            video: sampleVideo,
            disableHoverPreview: true,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text(sampleVideo.title), findsOneWidget);
      expect(find.text(sampleVideo.channelName), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets(
        '10. VideoCard in grid mode enforces uniform card height regardless of title length',
        (tester) async {
      final shortTitleVideo = sampleVideo.copyWith(
        id: 'vid_short_title',
        title: 'Christian songs Redx Media',
      );
      final longTitleVideo = sampleVideo.copyWith(
        id: 'vid_long_title',
        title: "How ISRO Does More in Space for Less | India's Space Strategy",
      );

      await tester.pumpWidget(
        wrapWithMaterial(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 320,
                child: VideoCard(
                  video: shortTitleVideo,
                  isGrid: true,
                  disableHoverPreview: true,
                  heroPrefix: 'test_short',
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 320,
                child: VideoCard(
                  video: longTitleVideo,
                  isGrid: true,
                  disableHoverPreview: true,
                  heroPrefix: 'test_long',
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      final cardFinders = find.byType(VideoCard);
      expect(cardFinders, findsNWidgets(2));

      final shortCardSize = tester.getSize(cardFinders.first);
      final longCardSize = tester.getSize(cardFinders.last);

      expect(shortCardSize.height, equals(longCardSize.height));
      expect(shortCardSize.width, equals(longCardSize.width));
    });
  });
}
