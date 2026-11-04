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
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/controls/fullscreen_actions_bar.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/player_fact_check_overlay.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../../test_helpers/mock_firebase.dart';

class _FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  @override
  Future<void> init() async {}
  @override
  Future<void> dispose(int textureId) async {}
  @override
  Future<int?> create(DataSource dataSource) async => 1;
  @override
  Future<void> setLooping(int textureId, bool looping) async {}
  @override
  Future<void> play(int textureId) async {}
  @override
  Future<void> pause(int textureId) async {}
  @override
  Future<void> setVolume(int textureId, double volume) async {}
  @override
  Future<void> setPlaybackSpeed(int textureId, double speed) async {}
  @override
  Future<void> seekTo(int textureId, Duration position) async {}
  @override
  Future<Duration> getPosition(int textureId) async => Duration.zero;
  @override
  Stream<VideoEvent> videoEventsFor(int textureId) => const Stream.empty();
  @override
  Widget buildView(int textureId) => const SizedBox();
  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    VideoPlayerPlatform.instance = _FakeVideoPlayerPlatform();
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

      expect(find.text('TRUTH CREDIBILITY CHECK'), findsNothing);
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

    test('5. Spiritual videos are strictly non-credibility categories and have no AI credibility', () {
      final spiritualVideo1 = Video(
        id: 'vid_spirit_1',
        title: 'Choosen one series 1 season 2',
        description: 'Spiritual series',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        ownerId: 'owner_spirit',
        channelId: 'chan_spirit',
        channelName: 'Ebenezer Vampu',
        category: 'Spirituality',
        tags: const ['faith', 'devotional'],
      );

      final spiritualVideo2 = Video(
        id: 'vid_spirit_2',
        title: 'Morning Meditation & Prayer',
        description: 'Daily spiritual reflection',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        ownerId: 'owner_spirit',
        channelId: 'chan_spirit',
        channelName: 'Spiritual Guides',
        category: 'Spiritual',
        tags: const ['spiritual', 'prayer'],
      );

      expect(spiritualVideo1.isNonCredibilityCategory, isTrue);
      expect(spiritualVideo1.hasAiCredibility, isFalse);

      expect(spiritualVideo2.isNonCredibilityCategory, isTrue);
      expect(spiritualVideo2.hasAiCredibility, isFalse);
    });

    testWidgets('6. FullscreenFloatingActionDock hides Claims & Fact-Check option for spiritual & un-factchecked videos', (tester) async {
      final vpc = VideoPlayerController.networkUrl(Uri.parse('https://example.com/test.mp4'));
      final playerCtrl = TowerPlayerController(videoPlayerController: vpc, tag: 'test_player_spirit');
      final videoCtrl = VideoController();
      addTearDown(() {
        playerCtrl.timers.cancelAll();
        playerCtrl.cancelPendingTap();
        playerCtrl.abr.dispose();
        TowerPlayerRegistry.unregister(playerCtrl);
      });

      // Spiritual video without fact-checking
      final spiritualVideo = Video(
        id: 'vid_spirit_fs',
        title: 'Choosen one series',
        description: 'Spiritual discourse',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        ownerId: 'owner_spirit',
        channelId: 'chan_spirit',
        channelName: 'Ebenezer Vampu',
        category: 'Spirituality',
        tags: const ['spiritual'],
        isFactChecked: false,
      );

      videoCtrl.video = spiritualVideo;
      videoCtrl.rxVideo.value = spiritualVideo;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FullscreenFloatingActionDock(
              ctrl: playerCtrl,
              vc: videoCtrl,
            ),
          ),
        ),
      );
      await tester.pump();

      // Claims / Fact-Check icons MUST NOT be present
      expect(find.byIcon(Icons.fact_check_outlined), findsNothing);
      expect(find.byIcon(Icons.fact_check_rounded), findsNothing);

      // Now set a science video that IS fact-checked
      final factCheckedVideo = Video(
        id: 'vid_science_fs',
        title: 'Space Exploration Discovery',
        description: 'Documentary',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        ownerId: 'owner_sci',
        channelId: 'chan_sci',
        channelName: 'Science Hub',
        category: 'Science',
        isFactChecked: true,
        factCheckUrl: 'https://example.com/factcheck.json',
        tags: const ['science'],
      );

      videoCtrl.video = factCheckedVideo;
      videoCtrl.rxVideo.value = factCheckedVideo;
      await tester.pump();

      // Now fact-check option MUST appear
      expect(find.byIcon(Icons.fact_check_outlined), findsOneWidget);
    });

    testWidgets('7. FactCheckOverlay auto-dismisses on spiritual video and yields SizedBox.shrink', (tester) async {
      final vpc = VideoPlayerController.networkUrl(Uri.parse('https://example.com/test.mp4'));
      final playerCtrl = TowerPlayerController(videoPlayerController: vpc, tag: 'test_player_overlay');
      final videoCtrl = VideoController();
      addTearDown(() {
        playerCtrl.timers.cancelAll();
        playerCtrl.cancelPendingTap();
        playerCtrl.abr.dispose();
        TowerPlayerRegistry.unregister(playerCtrl);
      });

      final spiritualVideo = Video(
        id: 'vid_spirit_overlay',
        title: 'Choosen one series',
        description: 'Spiritual series',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        ownerId: 'owner_spirit',
        channelId: 'chan_spirit',
        channelName: 'Ebenezer Vampu',
        category: 'Spirituality',
        tags: const ['faith'],
      );

      videoCtrl.video = spiritualVideo;
      videoCtrl.rxVideo.value = spiritualVideo;
      playerCtrl.showFactCheckPopup.value = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FactCheckOverlay(ctrl: playerCtrl),
          ),
        ),
      );
      await tester.pump();

      // FactCheckOverlay should have automatically closed itself
      expect(playerCtrl.showFactCheckPopup.value, isFalse);
      expect(find.text('Not Fact-Checked Yet'), findsNothing);
      expect(find.text('Fact-Check This Video'), findsNothing);
    });
  });
}
