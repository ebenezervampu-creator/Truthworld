import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/features/video/presentation/services/sleep_timer_service.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player/tower_player_registry.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:truthworld/features/video/presentation/views/player/panels/main_settings_menu.dart';
import 'package:truthworld/features/video/presentation/views/player/panels/mobile_settings_panels.dart';
import 'package:truthworld/features/video/presentation/views/player/panels/video_language_panel.dart';
import 'package:video_player/video_player.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const MethodChannel('plugins.flutter.io/path_provider')
        .setMockMethodCallHandler((MethodCall methodCall) async => '.');
    await GetStorage.init();
  });

  setUp(() {
    Get.reset();
    Get.put(SleepTimerService());
  });

  tearDown(() {
    Get.reset();
  });

  group('VideoTrack Model & Settings UI Tests', () {
    test('VideoTrack constructs correctly with defaults and parameters', () {
      const orig = VideoTrack(
        label: 'Original (English)',
        langCode: 'en',
      );
      expect(orig.label, equals('Original (English)'));
      expect(orig.langCode, equals('en'));
      expect(orig.type, equals('Original'));
      expect(orig.url, isNull);

      const dubbed = VideoTrack(
        label: 'Spanish (Video)',
        langCode: 'es',
        type: 'Video',
        url: 'https://cdn.truthworld.com/videos/es.mp4',
      );
      expect(dubbed.label, equals('Spanish (Video)'));
      expect(dubbed.langCode, equals('es'));
      expect(dubbed.type, equals('Video'));
      expect(dubbed.url, equals('https://cdn.truthworld.com/videos/es.mp4'));
    });

    testWidgets('MainSettingsMenu shows AudioTracks and VideoTracks options in sequence', (tester) async {
      final vpc = VideoPlayerController.networkUrl(Uri.parse('https://example.com/v.mp4'));
      final ctrl = Get.put(
        TowerPlayerController(
          videoPlayerController: vpc,
          tag: 'test_main_settings_vid',
        ),
        tag: 'test_main_settings_vid',
      );

      ctrl.activeAudioLang.value = 'Original (English)';
      ctrl.activeVideoLang.value = 'Original (English)';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MainSettingsMenu(ctrl: ctrl),
          ),
        ),
      );
      await tester.pump();

      // Verify AudioTracks and VideoTracks options exist
      expect(find.text('AudioTracks'), findsOneWidget);
      expect(find.text('VideoTracks'), findsOneWidget);

      // Verify they display active language
      expect(find.text('Original (English)'), findsNWidgets(2));

      // Tap VideoTracks tile opens video_language panel
      await tester.tap(find.text('VideoTracks'));
      await tester.pump();
      expect(ctrl.activePanel.value, equals('video_language'));

      // Tap AudioTracks tile opens language panel
      await tester.tap(find.text('AudioTracks'));
      await tester.pump();
      expect(ctrl.activePanel.value, equals('language'));

      ctrl.onClose();
      TowerPlayerRegistry.unregister(ctrl);
    });

    testWidgets('MobileMainSettingsMenu displays AudioTracks and VideoTracks tiles in order', (tester) async {
      final vpc = VideoPlayerController.networkUrl(Uri.parse('https://example.com/v.mp4'));
      final ctrl = Get.put(
        TowerPlayerController(
          videoPlayerController: vpc,
          tag: 'test_mobile_settings_vid',
        ),
        tag: 'test_mobile_settings_vid',
      );

      ctrl.activeAudioLang.value = 'English';
      ctrl.activeVideoLang.value = 'Original (English)';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MobileMainSettingsMenu(ctrl: ctrl),
          ),
        ),
      );
      await tester.pump();

      // Verify renamed to AudioTracks and VideoTracks
      expect(find.text('AudioTracks'), findsOneWidget);
      expect(find.text('VideoTracks'), findsOneWidget);

      // Tap VideoTracks tile opens video_language panel
      await tester.tap(find.text('VideoTracks'));
      await tester.pump();
      expect(ctrl.activePanel.value, equals('video_language'));

      // Tap AudioTracks tile opens language panel
      await tester.tap(find.text('AudioTracks'));
      await tester.pump();
      expect(ctrl.activePanel.value, equals('language'));

      ctrl.onClose();
      TowerPlayerRegistry.unregister(ctrl);
    });

    testWidgets('VideoLanguagePanel renders empty state when no tracks', (tester) async {
      final vpc = VideoPlayerController.networkUrl(Uri.parse('https://example.com/v.mp4'));
      final ctrl = Get.put(
        TowerPlayerController(
          videoPlayerController: vpc,
          tag: 'test_video_panel_empty',
        ),
        tag: 'test_video_panel_empty',
      );

      ctrl.videoTracks.clear();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoLanguagePanel(ctrl: ctrl),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Video Language'), findsOneWidget);
      expect(find.text('Original video only'), findsOneWidget);

      ctrl.onClose();
      TowerPlayerRegistry.unregister(ctrl);
    });

    testWidgets('VideoLanguagePanel renders generated video languages matching Audios style', (tester) async {
      final vpc = VideoPlayerController.networkUrl(Uri.parse('https://example.com/v.mp4'));
      final ctrl = Get.put(
        TowerPlayerController(
          videoPlayerController: vpc,
          tag: 'test_video_panel_items',
        ),
        tag: 'test_video_panel_items',
      );

      ctrl.videoTracks.assignAll([
        const VideoTrack(
          label: 'Original (English)',
          langCode: 'en',
          type: 'Original',
        ),
        const VideoTrack(
          label: 'Spanish (Video)',
          langCode: 'es',
          type: 'Video',
          url: 'https://example.com/es.mp4',
        ),
        const VideoTrack(
          label: 'Hindi (Video)',
          langCode: 'hi',
          type: 'Video',
          url: 'https://example.com/hi.mp4',
        ),
      ]);
      ctrl.activeVideoLang.value = 'Original (English)';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoLanguagePanel(ctrl: ctrl),
          ),
        ),
      );
      await tester.pump();

      // Verify all video languages from studio are displayed
      expect(find.text('Video Language'), findsOneWidget);
      expect(find.text('Original (English)'), findsOneWidget);
      expect(find.text('Spanish (Video)'), findsOneWidget);
      expect(find.text('Hindi (Video)'), findsOneWidget);

      // Verify language badges (EN, ES, HI)
      expect(find.text('EN'), findsOneWidget);
      expect(find.text('ES'), findsOneWidget);
      expect(find.text('HI'), findsOneWidget);

      // Tap Hindi Video track switches activeVideoLang
      await tester.tap(find.text('Hindi (Video)'));
      await tester.pump();
      expect(ctrl.activeVideoLang.value, equals('Hindi (Video)'));

      ctrl.onClose();
      TowerPlayerRegistry.unregister(ctrl);
    });
  });
}
