import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/home/presentation/controllers/main_controller.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_controller.dart';
import 'package:truthworld/features/video/data/models/fact_check_data_parser.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_engagement_controller.dart';
import 'package:truthworld/features/video/presentation/widgets/video_action_buttons.dart';
import 'package:truthworld/features/video/presentation/widgets/video_fact_check_card.dart';

import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await setupMockFirebase();
  });

  setUp(() {
    Get.reset();
    Get.testMode = true;
    if (!Get.isRegistered<AuthService>()) {
      Get.put<AuthService>(AuthService(), permanent: true);
    }
    if (!Get.isRegistered<ConnectivityService>()) {
      Get.put<ConnectivityService>(ConnectivityService(), permanent: true);
    }
    if (!Get.isRegistered<ChannelSubscriptionController>()) {
      Get.put<ChannelSubscriptionController>(ChannelSubscriptionController(), permanent: true);
    }
    if (!Get.isRegistered<PlaylistController>()) {
      Get.put<PlaylistController>(PlaylistController(), permanent: true);
    }
  });

  tearDown(Get.reset);

  group('AI Credibility Category Guard & Verification Button Removal Tests', () {
    test('1. Music and Entertainment videos are recognized as non-credibility categories', () {
      final musicVideo = Video(
        id: 'vid_music_1',
        title: 'Christian songs Redx Media',
        description: 'Christian worship songs',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        ownerId: 'owner_1',
        channelId: 'chan_music_1',
        channelName: 'Redx Media',
        category: 'Music',
        tags: const ['music', 'gospel', 'songs'],
        trustScore: 100.0,
      );

      final entertainmentVideo = Video(
        id: 'vid_ent_1',
        title: 'Hilarious Comedy Sketch',
        description: 'Comedy show',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        ownerId: 'owner_2',
        channelId: 'chan_ent_1',
        channelName: 'Laughs Hub',
        category: 'Entertainment',
        tags: const ['comedy', 'entertainment'],
        trustScore: 100.0,
      );

      final factualVideo = Video(
        id: 'vid_fact_1',
        title: 'Economy & Inflation Report 2026',
        description: 'Detailed analysis of global inflation',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        ownerId: 'owner_3',
        channelId: 'chan_fact_1',
        channelName: 'Global News Daily',
        category: 'News',
        tags: const ['news', 'finance'],
        isFactChecked: true,
        factCheckUrl: 'https://example.com/report.json',
        trustScore: 92.0,
      );

      expect(musicVideo.isNonCredibilityCategory, isTrue);
      expect(musicVideo.hasAiCredibility, isFalse);

      expect(entertainmentVideo.isNonCredibilityCategory, isTrue);
      expect(entertainmentVideo.hasAiCredibility, isFalse);

      expect(factualVideo.isNonCredibilityCategory, isFalse);
      expect(factualVideo.hasAiCredibility, isTrue);
    });

    test('2. FactCheckDataParser does not manufacture credibility data for unscored videos', () {
      final parsedUnchecked = FactCheckDataParser.parse(
        null,
        fallbackTrustScore: 100.0,
      );

      expect(parsedUnchecked.isEmpty, isTrue);

      final parsedChecked = FactCheckDataParser.parse(
        null,
        fallbackTrustScore: 85.0,
        isVideoFactChecked: true,
      );

      expect(parsedChecked.isEmpty, isFalse);
      expect(parsedChecked.trustScore, 85.0);
    });

    testWidgets('3. VideoFactCheckCard renders SizedBox.shrink for Music video', (tester) async {
      final musicVideo = Video(
        id: 'vid_song_1',
        title: 'Christian songs Redx Media',
        description: 'Christian songs collection',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        ownerId: 'owner_1',
        channelId: 'chan_music_1',
        channelName: 'Redx Media',
        category: 'Music',
        tags: const ['music', 'christian'],
        trustScore: 100.0,
      );

      final controller = VideoController();
      Get.put(controller);
      controller.video = musicVideo;

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: VideoFactCheckCard(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AI CREDIBILITY CHECK'), findsNothing);
      expect(find.text('EXCEPTIONAL INTEGRITY'), findsNothing);
      expect(find.text('View Full Analysis'), findsNothing);
    });

    testWidgets('4. VideoActionButtons does NOT display verification button after dislike button', (tester) async {
      final musicVideo = Video(
        id: 'vid_song_2',
        title: 'Christian songs Redx Media',
        description: 'Christian songs collection',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        ownerId: 'owner_1',
        channelId: 'chan_music_1',
        channelName: 'Redx Media',
        category: 'Music',
        tags: const ['music'],
        trustScore: 100.0,
      );

      final controller = VideoController();
      Get.put(controller);
      controller.video = musicVideo;
      controller.engagementController = Get.put(VideoEngagementController());

      final mainController = MainController();
      Get.put(mainController);

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => SingleChildScrollView(
                child: VideoActionButtons.build(
                  context: context,
                  controller: controller,
                  mainController: mainController,
                  channelController: null,
                  onSignInPrompt: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure Like and Dislike buttons are present
      expect(find.byIcon(Icons.thumb_up_outlined), findsOneWidget);
      expect(find.byIcon(Icons.thumb_down_outlined), findsOneWidget);

      // Verify that the shield verification button after dislike is NOT present
      expect(find.byIcon(Icons.verified_user_outlined), findsNothing);
      expect(find.byIcon(Icons.verified_user_rounded), findsNothing);
    });
  });
}
