import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/data/models/channel_wallet_models.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audio_tracks_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks/audio_track_dubbing_options_dialog.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks/audio_track_dubbing_options_page.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks/audio_tracks_dialogs.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  tearDown(Get.reset);

  Video buildSampleVideo({String duration = '01:00'}) {
    return Video(
      id: 'vid_dub_test_1',
      title: 'TruthWorld Global Broadcast',
      description: 'Sample test video',
      videoUrl: 'https://example.com/video.mp4',
      thumbnailUrl: 'https://example.com/thumb.jpg',
      ownerId: 'owner_1',
      channelId: 'chan_1',
      channelName: 'TruthWorld Studio',
      category: 'News',
      tags: const ['truth'],
      duration: duration,
    );
  }

  Channel buildChannel({
    String? dubbingDiscountType,
    double? dubbingDiscountPercent,
  }) {
    final now = Timestamp.fromDate(DateTime(2026));
    return Channel(
      id: 'chan_1',
      name: 'TruthWorld Studio',
      nameLowercase: 'truthworld studio',
      handle: '@truthworld',
      handleLowercase: '@truthworld',
      description: 'Test channel',
      avatarUrl: '',
      bannerUrl: '',
      ownerId: 'owner_1',
      createdAt: now,
      updatedAt: now,
      dubbingDiscountType: dubbingDiscountType,
      dubbingDiscountPercent: dubbingDiscountPercent,
    );
  }

  group('Audio Track & Dubbing Redesigned UI & Multi-Language Tests', () {
    testWidgets(
      'AudioTrackDubbingOptionsPage renders Image-2 minimalist UI without overflow',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final controller = Get.put(AudioTracksController());
        controller.rxState.value = ViewState.idle;
        controller.selectedVideo.value = buildSampleVideo();

        final page = AudioTrackDubbingOptionsPage(
          controller: controller,
          initialLangCode: 'te',
          isDarkMode: true,
        );

        await tester.pumpWidget(
          GetMaterialApp(
            theme: buildAppTheme(),
            home: page,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byIcon(Icons.arrow_back), findsOneWidget);
        expect(find.text('Audio Track & Dubbing'), findsOneWidget);
        expect(
          find.text(
            'Create a new audio track or dub your video into another language.',
          ),
          findsOneWidget,
        );
        expect(find.text('AI Dubbing'), findsOneWidget);
        expect(find.text('Direct Audio Track'), findsOneWidget);
        expect(find.text('Target Language'), findsOneWidget);
        expect(find.text('Telugu (తెలుగు)'), findsOneWidget);
        expect(find.text('Voice Cloning'), findsOneWidget);
        expect(find.text("Use the original speaker's voice."), findsOneWidget);
        expect(find.text('Speaker Diarization'), findsOneWidget);
        expect(
          find.text('Detect and separate multiple speakers.'),
          findsOneWidget,
        );
        expect(find.text('Voice Gender'), findsOneWidget);
        expect(find.text('Auto'), findsOneWidget);
        expect(find.text('Generate Audio Track'), findsOneWidget);
        expect(find.text('Cancel'), findsNothing);
      },
    );

    testWidgets(
      'Never shows predefined Telugu language for Audio tracks generation and shows "Select a language" instead',
      (tester) async {
        tester.view.physicalSize = const Size(500, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final controller = Get.put(AudioTracksController());
        controller.rxState.value = ViewState.idle;
        controller.selectedVideo.value = buildSampleVideo();

        // Created without initialLangCode (as when launching Audio tracks generation)
        final page = AudioTrackDubbingOptionsPage(
          controller: controller,
          isDarkMode: true,
        );

        await tester.pumpWidget(
          GetMaterialApp(
            theme: buildAppTheme(),
            home: page,
          ),
        );
        await tester.pumpAndSettle();

        expect(page.selectedLangCodes, isEmpty);
        expect(page.selectedLangCode.value, isEmpty);
        expect(find.text('Telugu (తెలుగు)'), findsNothing);
        expect(find.text('Select a language'), findsOneWidget);
        expect(find.text('Target Language'), findsOneWidget);
        expect(find.text('Generate Audio Track'), findsOneWidget);

        // Tapping 'Select a language' opens the target language picker
        await tester.tap(find.text('Select a language'));
        await tester.pumpAndSettle();

        expect(find.text('Select Target Languages'), findsOneWidget);

        // Select Hindi
        await tester.tap(find.text('Indian'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Hindi (हिन्दी)'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();

        expect(page.selectedLangCodes, ['hi']);
        expect(find.text('Hindi (हिन्दी)'), findsOneWidget);
        expect(find.text('Select a language'), findsNothing);
      },
    );

    testWidgets(
      'AudioTrackDubbingOptionsDialog renders AI Dubbing options and updates switches & voice gender sheet',
      (tester) async {
        final controller = Get.put(AudioTracksController());
        controller.rxState.value = ViewState.idle;
        controller.selectedVideo.value = buildSampleVideo();

        final dialog = AudioTrackDubbingOptionsDialog(
          controller: controller,
          initialLangCode: 'te',
          isDarkMode: true,
        );

        await tester.pumpWidget(
          GetMaterialApp(
            theme: buildAppTheme(),
            home: Scaffold(body: dialog),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Audio Track & Dubbing'), findsOneWidget);
        expect(find.text('Voice Cloning'), findsOneWidget);
        expect(find.text('Speaker Diarization'), findsOneWidget);
        expect(find.text('Voice Gender'), findsOneWidget);
        expect(find.text('Auto'), findsOneWidget);
        expect(find.text('Generate Audio Track'), findsOneWidget);

        // Toggle Voice Cloning & Speaker Diarization switches
        expect(dialog.voiceType.value, 'cloned');
        expect(dialog.enableDiarization.value, isFalse);

        final switches = find.byType(Switch);
        expect(switches, findsNWidgets(2));
        await tester.tap(switches.at(0));
        await tester.pumpAndSettle();
        expect(dialog.voiceType.value, 'standard');

        await tester.tap(switches.at(1));
        await tester.pumpAndSettle();
        expect(dialog.enableDiarization.value, isTrue);

        // Open Voice Gender picker bottom sheet and choose Male
        await tester.tap(find.text('Voice Gender'));
        await tester.pumpAndSettle();
        expect(find.text('Male'), findsOneWidget);
        expect(find.text('Female'), findsOneWidget);

        await tester.tap(find.text('Male'));
        await tester.pumpAndSettle();
        expect(dialog.selectedVoiceGender.value, 'male');
        expect(find.text('Male'), findsOneWidget);
      },
    );

    testWidgets(
      'Supports selecting multiple target languages, displays removable chips, and updates CTA batch count',
      (tester) async {
        tester.view.physicalSize = const Size(420, 880);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final controller = Get.put(AudioTracksController());
        controller.rxState.value = ViewState.idle;
        controller.selectedVideo.value = buildSampleVideo();

        final page = AudioTrackDubbingOptionsPage(
          controller: controller,
          initialLangCode: 'te',
          isDarkMode: true,
        );

        await tester.pumpWidget(
          GetMaterialApp(
            theme: buildAppTheme(),
            home: page,
          ),
        );
        await tester.pumpAndSettle();

        // Starts with 1 language ('te')
        expect(page.selectedLangCodes, ['te']);
        expect(find.text('Target Language'), findsOneWidget);
        expect(find.text('Generate Audio Track'), findsOneWidget);

        // Open language picker sheet
        await tester.tap(find.text('Target Language'));
        await tester.pumpAndSettle();

        expect(find.text('Select Target Languages'), findsOneWidget);
        expect(find.text('1 language selected'), findsOneWidget);

        // Filter by Indian category so Hindi and Tamil appear immediately
        await tester.tap(find.text('Indian'));
        await tester.pumpAndSettle();

        // Select Hindi and Tamil in the multi-select list
        await tester.tap(find.text('Hindi (हिन्दी)'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Tamil (தமிழ்)'));
        await tester.pumpAndSettle();

        expect(page.selectedLangCodes, ['te', 'hi', 'ta']);
        expect(find.text('3 languages selected'), findsOneWidget);

        // Close picker via Done button
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();

        // Main UI switches to multi-language view
        expect(find.text('Target Languages'), findsOneWidget);
        expect(find.text('3 languages'), findsOneWidget);
        expect(find.text('Generate 3 Audio Tracks'), findsOneWidget);
        expect(find.text('Add'), findsOneWidget);

        // Removing one language via chip close button updates reactive CTA count
        await tester.tap(find.byIcon(Icons.close_rounded).first);
        await tester.pumpAndSettle();

        expect(page.selectedLangCodes, ['hi', 'ta']);
        expect(find.text('2 languages'), findsOneWidget);
        expect(find.text('Generate 2 Audio Tracks'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Enforces max batch limit of 5 languages and prevents selecting original video language',
      (tester) async {
        final controller = Get.put(AudioTracksController());
        controller.rxState.value = ViewState.idle;
        controller.selectedVideo.value = buildSampleVideo(); // base language: en

        final page = AudioTrackDubbingOptionsPage(
          controller: controller,
          initialLangCode: 'te',
          isDarkMode: true,
        );

        await tester.pumpWidget(
          GetMaterialApp(
            theme: buildAppTheme(),
            home: page,
          ),
        );
        await tester.pumpAndSettle();

        // Attempting to toggle source language 'en' must be ignored
        page.state.toggleLanguage('en');
        expect(page.selectedLangCodes, ['te']);

        // Selecting a 6-language preset caps at 5 languages and excludes 'en'
        page.state.selectLanguagePreset(['en', 'hi', 'ta', 'kn', 'ml', 'es']);
        await tester.pumpAndSettle();

        expect(page.selectedLangCodes.length, 5);
        expect(page.selectedLangCodes.contains('en'), isFalse);
        expect(find.text('5 languages'), findsOneWidget);
        expect(find.text('Generate 5 Audio Tracks'), findsOneWidget);
      },
    );

    testWidgets(
      'Respects free discount waiver and calculates transparent batch pricing without charm pricing',
      (tester) async {
        final controller = Get.put(AudioTracksController());
        controller.rxState.value = ViewState.idle;
        controller.selectedVideo.value = buildSampleVideo();

        final dialog = AudioTrackDubbingOptionsDialog(
          controller: controller,
          initialLangCode: 'te',
          isDarkMode: true,
        );

        await tester.pumpWidget(
          GetMaterialApp(
            theme: buildAppTheme(),
            home: Scaffold(body: dialog),
          ),
        );
        await tester.pumpAndSettle();

        // Free / Super-Admin waiver channel
        dialog.currentChannel.value = buildChannel(dubbingDiscountType: 'free');
        dialog.spendableBalance.value = const SpendableBalance(
          withdrawableRevenue: 0,
          lockedRevenue: 0,
        );
        await tester.pumpAndSettle();

        expect(find.text('Generate Audio Track'), findsOneWidget);
        expect(find.textContaining('Pay'), findsNothing);

        // Standard paid channel with 2 languages & $0 wallet shows clear Pay CTA
        dialog.currentChannel.value = buildChannel();
        dialog.state.toggleLanguage('hi');
        await tester.pumpAndSettle();

        expect(find.textContaining(r'Estimated total: $'), findsOneWidget);
        expect(find.textContaining('& Generate 2 Tracks'), findsOneWidget);
      },
    );

    testWidgets(
      'Direct Audio Track tab renders Studio Guide, download CTA, and multi-language upload rows',
      (tester) async {
        tester.view.physicalSize = const Size(420, 880);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final controller = Get.put(AudioTracksController());
        controller.rxState.value = ViewState.idle;
        controller.selectedVideo.value = buildSampleVideo();

        final page = AudioTrackDubbingOptionsPage(
          controller: controller,
          initialLangCode: 'te',
          isDarkMode: true,
        );

        await tester.pumpWidget(
          GetMaterialApp(
            theme: buildAppTheme(),
            home: page,
          ),
        );
        await tester.pumpAndSettle();

        // Switch to Direct Audio Track tab
        await tester.tap(find.text('Direct Audio Track'));
        await tester.pumpAndSettle();

        expect(
          find.text('Where to Get Direct Audio Tracks (Studio Guide)'),
          findsOneWidget,
        );
        expect(find.text('Download Original Audio'), findsOneWidget);
        expect(find.text('Upload Finished Direct Audio Track'), findsOneWidget);
        expect(find.text('Upload & Attach Track'), findsOneWidget);

        // Selecting a second language shows per-language upload slots
        page.state.toggleLanguage('hi');
        await tester.pumpAndSettle();

        expect(find.text('Attach Audio Files by Language'), findsOneWidget);
        expect(find.text('Telugu (తెలుగు)'), findsWidgets);
        expect(find.text('Hindi (हिन्दी)'), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'showAudioTrackDubbingOptionsModal opens AudioTrackDubbingOptionsPage for target language',
      (tester) async {
        tester.view.physicalSize = const Size(900, 760);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final controller = Get.put(AudioTracksController());
        final sampleVideo = buildSampleVideo();
        controller.rxState.value = ViewState.idle;
        controller.videos.value = [sampleVideo];
        controller.selectedVideo.value = sampleVideo;

        await tester.pumpWidget(
          GetMaterialApp(
            theme: buildAppTheme(),
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    AudioTracksDialogs.showAudioTrackDubbingOptionsModal(
                      context: context,
                      controller: controller,
                      langCode: 'kn',
                      isDarkMode: true,
                    );
                  },
                  child: const Text('Add'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final addFinder = find.widgetWithText(ElevatedButton, 'Add');
        expect(addFinder, findsOneWidget);
        await tester.tap(addFinder);
        await tester.pumpAndSettle();

        expect(find.text('Audio Track & Dubbing'), findsOneWidget);
        expect(find.text('Generate Audio Track'), findsOneWidget);
        expect(find.text('Kannada (ಕನ್ನಡ)'), findsOneWidget);
      },
    );
  });
}
