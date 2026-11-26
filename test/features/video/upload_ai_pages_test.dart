import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_controller.dart';
import 'package:truthworld/features/video/presentation/views/upload/components/upload_video_player_language_overlay.dart';
import 'package:truthworld/features/video/presentation/views/upload/pages/upload_audio_track_dubbing_page.dart';
import 'package:truthworld/features/video/presentation/views/upload/widgets/create_content_media_sections.dart';

import '../../pages/page_test_harness.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  setUp(() {
    Get.reset();
    Get.testMode = true;
    if (!Get.isRegistered<AuthService>()) {
      Get.put<AuthService>(AuthService());
    }
  });

  tearDown(Get.reset);

  Channel createTestChannel({bool isCustom = false, double balance = 50.0}) {
    return Channel(
      id: 'test-chan-1',
      name: 'Truth Creator',
      nameLowercase: 'truth creator',
      handle: '@truthcreator',
      handleLowercase: '@truthcreator',
      description: 'Channel for testing',
      avatarUrl: '',
      bannerUrl: '',
      ownerId: 'user-1',
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
      channelType: isCustom ? ChannelType.custom : ChannelType.standard,
      walletBalanceUSD: balance,
    );
  }

  group('Upload Audio Track & Dubbing Page Tests', () {
    testWidgets('1. UploadAudioTrackDubbingPage renders cleanly via pumpPageInHarness', (tester) async {
      await pumpPageInHarness(
        tester,
        const UploadAudioTrackDubbingPage(),
        onBeforePump: () {
          final uploadCtrl = Get.put(UploadController());
          uploadCtrl.selectedChannel.value = createTestChannel();
          uploadCtrl.videoDurationSeconds.value = 300;
        },
      );

      expect(find.text('Audio Track & Dubbing'), findsOneWidget);
      expect(find.text('Create a new audio track or dub your video into another language.'), findsOneWidget);
      expect(find.text('AI Dubbing'), findsOneWidget);
      expect(find.text('Direct Audio Track'), findsOneWidget);
      expect(find.text('Original Video Language'), findsOneWidget);
      expect(find.text('Target Language'), findsOneWidget);
      expect(find.text('Voice Cloning'), findsOneWidget);
      expect(find.text('Speaker Diarization'), findsOneWidget);
      expect(find.text('Voice Gender'), findsOneWidget);
      expect(find.text('Generate Audio Track'), findsOneWidget);
    });

    testWidgets('2. UploadAudioTrackDubbingPage switches to Direct Audio Track tab cleanly', (tester) async {
      await pumpPageInHarness(
        tester,
        const UploadAudioTrackDubbingPage(),
        onBeforePump: () {
          final uploadCtrl = Get.put(UploadController());
          uploadCtrl.selectedChannel.value = createTestChannel();
        },
      );

      await tester.tap(find.text('Direct Audio Track'));
      await tester.pumpAndSettle();

      expect(find.text('Audio Role'), findsOneWidget);
      expect(find.text('Tap to select audio or video file'), findsOneWidget);
      expect(find.text('Attach Audio Track'), findsOneWidget);
    });
  });

  group('Step 2 Video File Section Feature Chips & Video Player Overlay Tests', () {
    testWidgets('1. CreateContentVideoFileSection renders Factcheck, Diarization & Chapters without bloated Section 10 headers', (tester) async {
      late UploadController uploadCtrl;
      await pumpPageInHarness(
        tester,
        Builder(
          builder: (context) => Material(
            child: SingleChildScrollView(
              child: CreateContentVideoFileSection(uploadController: uploadCtrl),
            ),
          ),
        ),
        onBeforePump: () {
          uploadCtrl = Get.put(UploadController());
          uploadCtrl.selectedChannel.value = createTestChannel();
          uploadCtrl.videoDurationSeconds.value = 300;
          uploadCtrl.aiGenerateSubtitles.value = false;
          uploadCtrl.aiGenerateDubbing.value = false;
          uploadCtrl.aiFactCheckEnabled.value = false;
          uploadCtrl.aiDiarizationEnabled.value = false;
          uploadCtrl.aiChaptersEnabled.value = false;
          uploadCtrl.isAiFeaturesExpanded.value = false;
        },
      );

      // 1. Verify old bloated Section 10 texts and code are completely removed
      expect(find.text('10. AI Features & Intelligence'), findsNothing);
      expect(find.text('AI Studio'), findsNothing);
      expect(find.textContaining(r'Free ($0.00)'), findsNothing);

      // Verify the 3 direct toggles are cleanly rendered in Section 2 (Video File)
      expect(find.text('Factcheck'), findsOneWidget);
      expect(find.text('Speaker Diarization'), findsOneWidget);
      expect(find.text('Auto Chapters'), findsOneWidget);

      // Verify Subtitles & Dubbing chips are not duplicated
      expect(find.widgetWithText(ActionChip, 'Subtitles'), findsNothing);
      expect(find.widgetWithText(ActionChip, 'Dubbing'), findsNothing);

      // 2. Direct toggle Factcheck Chip
      await tester.tap(find.text('Factcheck'));
      await tester.pumpAndSettle();
      expect(uploadCtrl.aiFactCheckEnabled.value, isTrue);

      // 3. Direct toggle Speaker Diarization Chip
      await tester.tap(find.text('Speaker Diarization'));
      await tester.pumpAndSettle();
      expect(uploadCtrl.aiDiarizationEnabled.value, isTrue);

      // 4. Direct toggle Auto Chapters Chip
      await tester.tap(find.text('Auto Chapters'));
      await tester.pumpAndSettle();
      expect(uploadCtrl.aiChaptersEnabled.value, isTrue);
    });

    testWidgets('2. UploadVideoPlayerLanguageOverlay renders base language pill and + Language button', (tester) async {
      late UploadController uploadCtrl;
      await pumpPageInHarness(
        tester,
        Builder(
          builder: (context) => Material(
            child: UploadVideoPlayerLanguageOverlay(
              controller: uploadCtrl,
              isDarkMode: true,
            ),
          ),
        ),
        onBeforePump: () {
          uploadCtrl = Get.put(UploadController());
          uploadCtrl.selectedChannel.value = createTestChannel();
          uploadCtrl.primarySpokenLanguage.value = 'en';
        },
      );

      expect(find.text('English'), findsOneWidget);
      expect(find.text('+ Language'), findsOneWidget);
    });
  });
}
