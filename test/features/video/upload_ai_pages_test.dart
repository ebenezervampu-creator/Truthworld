import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_dubbing_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_subtitles_controller.dart';
import 'package:truthworld/features/video/presentation/views/upload/pages/upload_dubbing_page.dart';
import 'package:truthworld/features/video/presentation/views/upload/pages/upload_subtitles_and_dubbing_page.dart';
import 'package:truthworld/features/video/presentation/views/upload/pages/upload_subtitles_page.dart';
import 'package:truthworld/features/video/presentation/views/upload/widgets/create_content_ai_section.dart';

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

  group('Upload Subtitles Controller & Page Tests', () {
    test('1. Calculates flat pricing at-cost (0% platform profit) for standard and custom channels', () {
      final uploadCtrl = Get.put(UploadController());
      uploadCtrl.videoDurationSeconds.value = 360; // 6 mins -> $0.05 / lang at-cost (Standard Tier)
      uploadCtrl.selectedChannel.value = createTestChannel();

      final subCtrl = Get.put(UploadSubtitlesController());
      expect(subCtrl.flatSubtitleRatePerLang, equals(0.05));

      subCtrl.selectedLanguages.addAll(['Spanish', 'French', 'German']);
      expect(subCtrl.calculatedCost, equals(0.15));

      // Switch to custom channel (exact same at-cost rate)
      uploadCtrl.selectedChannel.value = createTestChannel(isCustom: true);
      expect(subCtrl.flatSubtitleRatePerLang, equals(0.05));
      expect(subCtrl.calculatedCost, equals(0.15));
    });

    test('2. Subtitles for dubbed languages are complimentary (free)', () {
      final uploadCtrl = Get.put(UploadController());
      uploadCtrl.videoDurationSeconds.value = 300;
      uploadCtrl.selectedChannel.value = createTestChannel();
      uploadCtrl.aiGenerateDubbing.value = true;
      uploadCtrl.aiDubbingLanguages.assignAll(['Spanish', 'French']);

      final subCtrl = Get.put(UploadSubtitlesController());
      subCtrl.selectedLanguages.assignAll(['Spanish', 'French', 'German', 'Hindi']);

      expect(subCtrl.freeDubbedSubtitleCount, equals(2));
      expect(subCtrl.billableLanguages.length, equals(2));
      expect(subCtrl.billableLanguages, containsAll(['German', 'Hindi']));
      expect(subCtrl.billableLanguages, isNot(contains('Spanish')));
    });

    test('3. Presets and search filtering work cleanly', () {
      Get.put(UploadController());
      final subCtrl = Get.put(UploadSubtitlesController());

      subCtrl.selectTopGlobal();
      expect(subCtrl.selectedLanguages, contains('Spanish'));
      expect(subCtrl.selectedLanguages, contains('Japanese'));

      subCtrl.searchQuery.value = 'telugu';
      expect(subCtrl.filteredLanguages.length, equals(1));
      expect(subCtrl.filteredLanguages.first.name, equals('Telugu'));

      subCtrl.clearAll();
      expect(subCtrl.selectedLanguages, isEmpty);
    });

    testWidgets('4. UploadSubtitlesPage renders cleanly via pumpPageInHarness', (tester) async {
      await pumpPageInHarness(
        tester,
        const UploadSubtitlesPage(),
        onBeforePump: () {
          final uploadCtrl = Get.put(UploadController());
          uploadCtrl.selectedChannel.value = createTestChannel();
          uploadCtrl.videoDurationSeconds.value = 360;
        },
      );

      expect(find.text('AI Subtitles & Translation'), findsOneWidget);
      expect(find.text('Live Pricing Breakdown'), findsOneWidget);
      expect(find.text('Apply Subtitles'), findsOneWidget);
    });

    test('5. Normalizes ISO language codes to canonical language names on load', () {
      final uploadCtrl = Get.put(UploadController());
      uploadCtrl.aiTranslationLanguages.assignAll(['es', 'hi', 'te', 'fr']);

      final subCtrl = Get.put(UploadSubtitlesController());
      expect(subCtrl.selectedLanguages.length, equals(4));
      expect(subCtrl.selectedLanguages, containsAll(['Spanish', 'Hindi', 'Telugu', 'French']));
      expect(subCtrl.selectedLanguageDisplayNames, containsAll(['Spanish', 'Hindi', 'Telugu', 'French']));

      final spanish = UploadSubtitlesController.findLanguage('es');
      expect(spanish, isNotNull);
      expect(subCtrl.isLanguageSelected(spanish!), isTrue);

      final hindi = UploadSubtitlesController.findLanguage('Hindi');
      expect(hindi, isNotNull);
      expect(subCtrl.isLanguageSelected(hindi!), isTrue);
    });

    test('6. "selected" filter category filters only selected languages', () {
      Get.put(UploadController());
      final subCtrl = Get.put(UploadSubtitlesController());

      subCtrl.selectedLanguages.assignAll(['Spanish', 'Tamil', 'Japanese']);
      expect(subCtrl.selectedLanguages.length, equals(3));

      subCtrl.selectedCategoryFilter.value = 'selected';
      final filtered = subCtrl.filteredLanguages;
      expect(filtered.length, equals(3));
      expect(filtered.map((l) => l.name), containsAll(['Spanish', 'Tamil', 'Japanese']));

      // Removing a language updates filtered list
      subCtrl.removeLanguage('Tamil');
      expect(subCtrl.filteredLanguages.length, equals(2));
      expect(subCtrl.filteredLanguages.map((l) => l.name), isNot(contains('Tamil')));
    });

    testWidgets('7. Displays Selected Languages section and chips when languages are selected', (tester) async {
      await pumpPageInHarness(
        tester,
        const UploadSubtitlesPage(),
        onBeforePump: () {
          final uploadCtrl = Get.put(UploadController());
          uploadCtrl.selectedChannel.value = createTestChannel();
          uploadCtrl.videoDurationSeconds.value = 360;
          uploadCtrl.aiTranslationLanguages.assignAll(['Spanish', 'Hindi', 'German']);
        },
      );

      // Verify Selected Languages section, AppBar chip, sticky strip, and preset chips
      expect(find.text('Selected Languages (3)'), findsOneWidget);
      expect(find.text('Selected (3)'), findsOneWidget);
      expect(find.text('Selected (3):'), findsOneWidget);
      expect(find.text('3 Selected'), findsOneWidget);
      expect(find.text('Spanish'), findsWidgets);
      expect(find.text('Hindi'), findsWidgets);
      expect(find.text('German'), findsWidgets);
      expect(find.text('3 languages selected'), findsOneWidget);
    });
  });

  group('Upload Dubbing Controller & Page Tests', () {
    test('1. Calculates dubbing cost and duration tiers properly at-cost', () {
      final uploadCtrl = Get.put(UploadController());
      uploadCtrl.videoDurationSeconds.value = 300; // 5 min -> $1.50 at-cost ($0.30/min baseline)
      uploadCtrl.selectedChannel.value = createTestChannel();

      final dubCtrl = Get.put(UploadDubbingController());
      expect(dubCtrl.flatDubbingRatePerLang, equals(1.50));

      dubCtrl.selectedLanguages.addAll(['Spanish', 'Hindi', 'French']);
      expect(dubCtrl.calculatedCost, equals(4.50));

      // Custom channel (exact same at-cost rate)
      uploadCtrl.selectedChannel.value = createTestChannel(isCustom: true);
      expect(dubCtrl.flatDubbingRatePerLang, equals(1.50));
      expect(dubCtrl.calculatedCost, equals(4.50));
    });

    test('2. Protects against dubbing into channel native source language', () {
      final uploadCtrl = Get.put(UploadController());
      uploadCtrl.selectedChannel.value = createTestChannel(); // language: 'en' (English)

      final dubCtrl = Get.put(UploadDubbingController());
      final english = UploadDubbingController.allDubbingLanguages
          .firstWhere((l) => l.name == 'English');

      expect(dubCtrl.isSourceLanguage(english), isTrue);
      dubCtrl.toggleLanguage(english);
      expect(dubCtrl.selectedLanguages, isNot(contains('English')));
    });

    test('3. applyAndSave syncs dubbed languages to subtitles', () {
      final uploadCtrl = Get.put(UploadController());
      uploadCtrl.selectedChannel.value = createTestChannel();
      final dubCtrl = Get.put(UploadDubbingController());

      dubCtrl.selectedLanguages.assignAll(['Spanish', 'German']);
      dubCtrl.voiceType.value = 'cloned';
      dubCtrl.isDiarizationEnabled.value = true;
      dubCtrl.applyAndSave();

      expect(uploadCtrl.aiGenerateDubbing.value, isTrue);
      expect(uploadCtrl.aiDubbingLanguages, containsAll(['Spanish', 'German']));
      expect(uploadCtrl.aiGenerateSubtitles.value, isTrue);
      expect(uploadCtrl.aiTranslationLanguages, containsAll(['Spanish', 'German']));
      expect(uploadCtrl.aiTTSVoiceType.value, equals('cloned'));
      expect(uploadCtrl.aiDiarizationEnabled.value, isTrue);
    });

    testWidgets('4. UploadDubbingPage renders cleanly via pumpPageInHarness', (tester) async {
      await pumpPageInHarness(
        tester,
        const UploadDubbingPage(),
        onBeforePump: () {
          final uploadCtrl = Get.put(UploadController());
          uploadCtrl.selectedChannel.value = createTestChannel();
          uploadCtrl.videoDurationSeconds.value = 400;
        },
      );

      expect(find.text('AI Voice Dubbing & Localization'), findsOneWidget);
      expect(find.text('Dubbing is NOT Free (Predictable Flat Pricing)'), findsOneWidget);
      expect(find.text('Studio Dubbing Features & Options'), findsOneWidget);
      expect(find.text('Apply Dubbing'), findsOneWidget);
    });

    testWidgets('5. Displays Selected Languages section, persistent strip, and chips when dubbing languages are selected', (tester) async {
      await pumpPageInHarness(
        tester,
        const UploadDubbingPage(),
        onBeforePump: () {
          final uploadCtrl = Get.put(UploadController());
          uploadCtrl.selectedChannel.value = createTestChannel();
          uploadCtrl.videoDurationSeconds.value = 400;
          uploadCtrl.aiDubbingLanguages.assignAll(['Spanish', 'Hindi', 'German']);
        },
      );

      expect(find.text('Selected Dubbing Languages (3)'), findsOneWidget);
      expect(find.text('Selected (3)'), findsOneWidget);
      expect(find.text('Selected (3):'), findsOneWidget);
      expect(find.text('3 Selected'), findsOneWidget);
      expect(find.text('Spanish'), findsWidgets);
      expect(find.text('Hindi'), findsWidgets);
      expect(find.text('German'), findsWidgets);
    });
  });

  group('Create Content AI Section Direct Truth Verification Toggle Tests', () {
    test('1. Directly toggles TruthWorld verification on and off on UploadController', () {
      final uploadCtrl = Get.put(UploadController());
      expect(uploadCtrl.aiFactCheckEnabled.value, isFalse);
      expect(uploadCtrl.aiFactCheckTier.value, equals('full_ground'));
      expect(uploadCtrl.allowRatings.value, isFalse);

      // Toggle ON
      uploadCtrl.aiFactCheckEnabled.value = true;
      expect(uploadCtrl.aiFactCheckEnabled.value, isTrue);
      expect(uploadCtrl.aiFactCheckTier.value, equals('full_ground'));
      expect(uploadCtrl.allowRatings.value, isTrue);

      // Toggle OFF
      uploadCtrl.aiFactCheckEnabled.value = false;
      expect(uploadCtrl.aiFactCheckEnabled.value, isFalse);
      expect(uploadCtrl.allowRatings.value, isFalse);
    });

    testWidgets('2. CreateContentAISection renders direct Truth Verification card without 100% FREE badge and toggles cleanly', (tester) async {
      final uploadCtrl = Get.put(UploadController());
      uploadCtrl.selectedChannel.value = createTestChannel();
      uploadCtrl.videoDurationSeconds.value = 600;

      await pumpPageInHarness(
        tester,
        CreateContentAISection(controller: uploadCtrl),
      );

      // Verify direct card elements
      expect(find.text('Truth Verification (Full Ground Truth)'), findsOneWidget);
      expect(find.text('100% FREE'), findsNothing);
      expect(find.textContaining('Epistemic multi-source AI verification powered by Google Cloud'), findsNothing);
      expect(find.text('Epistemic multi-source AI verification & claim citations'), findsOneWidget);

      // Verify no subpage configure buttons exist
      expect(find.text('Configure Depth Tiers & Pricing â†’'), findsNothing);
      expect(find.text('View Fact-Checking & Sources â†’'), findsNothing);

      // Direct toggle interaction
      expect(uploadCtrl.aiFactCheckEnabled.value, isFalse);
      final factCheckSwitch = find.byType(Switch).at(2);
      await tester.tap(factCheckSwitch);
      await tester.pumpAndSettle();
      expect(uploadCtrl.aiFactCheckEnabled.value, isTrue);
    });
  });

  group('Separated Studio Sections Tests', () {
    testWidgets('1. CreateContentSubtitlesDubbingSection renders Subtitles and Dubbing section cleanly', (tester) async {
      late UploadController uploadCtrl;

      await pumpPageInHarness(
        tester,
        Builder(
          builder: (context) => CreateContentSubtitlesDubbingSection(uploadController: uploadCtrl),
        ),
        onBeforePump: () {
          uploadCtrl = Get.put(UploadController());
          uploadCtrl.selectedChannel.value = createTestChannel();
          uploadCtrl.videoDurationSeconds.value = 300;
        },
      );

      expect(find.text('10. Subtitles and Dubbing'), findsOneWidget);
      expect(find.text('AI Subtitles & Translation'), findsOneWidget);
      expect(find.text('AI Voice Dubbing & Localization'), findsOneWidget);
      expect(find.textContaining('Configure Subtitles & Dubbing'), findsOneWidget);
    });

    testWidgets('2. CreateContentTruthVerificationSection renders 11. TruthWorld Verification standalone cleanly', (tester) async {
      late UploadController uploadCtrl;

      await pumpPageInHarness(
        tester,
        Builder(
          builder: (context) => CreateContentTruthVerificationSection(uploadController: uploadCtrl),
        ),
        onBeforePump: () {
          uploadCtrl = Get.put(UploadController());
          uploadCtrl.selectedChannel.value = createTestChannel();
        },
      );

      expect(find.text('11. TruthWorld Verification'), findsOneWidget);
      expect(find.text('100% FREE'), findsNothing);
      expect(find.textContaining('Epistemic multi-source AI verification powered by Google Cloud'), findsNothing);
      expect(find.text('Truth Verification (Full Ground Truth)'), findsOneWidget);

      // Toggle ON
      expect(uploadCtrl.aiFactCheckEnabled.value, isFalse);
      final toggleSwitch = find.byType(Switch).first;
      await tester.tap(toggleSwitch);
      await tester.pumpAndSettle();
      expect(uploadCtrl.aiFactCheckEnabled.value, isTrue);

      // Verify review mode selector and complex options are removed (only ON/OFF toggle, public by default)
      expect(find.text('Fact-Check Results Delivery'), findsNothing);
      expect(find.text('Open for user directly'), findsNothing);
      expect(find.text('Show results first to you'), findsNothing);
      expect(uploadCtrl.aiFactCheckReviewMode.value, equals('open_to_users'));
    });

    testWidgets('3. CreateContentSpeakerDiarizationSection renders 12. Speaker Diarization and toggles', (tester) async {
      late UploadController uploadCtrl;

      await pumpPageInHarness(
        tester,
        Builder(
          builder: (context) => CreateContentSpeakerDiarizationSection(uploadController: uploadCtrl),
        ),
        onBeforePump: () {
          uploadCtrl = Get.put(UploadController());
        },
      );

      expect(find.text('12. Speaker Diarization'), findsOneWidget);
      expect(find.text('Identify and label multiple speakers'), findsOneWidget);

      expect(uploadCtrl.aiDiarizationEnabled.value, isFalse);
      final toggleSwitch = find.byType(Switch).first;
      await tester.tap(toggleSwitch);
      await tester.pumpAndSettle();
      expect(uploadCtrl.aiDiarizationEnabled.value, isTrue);
    });

    testWidgets('4. CreateContentAutoChaptersSection renders 13. Auto Chapters and toggles', (tester) async {
      late UploadController uploadCtrl;

      await pumpPageInHarness(
        tester,
        Builder(
          builder: (context) => CreateContentAutoChaptersSection(uploadController: uploadCtrl),
        ),
        onBeforePump: () {
          uploadCtrl = Get.put(UploadController());
        },
      );

      expect(find.text('13. Auto Chapters'), findsOneWidget);
      expect(find.text('Generate smart video timestamp chapters'), findsOneWidget);

      expect(uploadCtrl.aiChaptersEnabled.value, isFalse);
      final toggleSwitch = find.byType(Switch).first;
      await tester.tap(toggleSwitch);
      await tester.pumpAndSettle();
      expect(uploadCtrl.aiChaptersEnabled.value, isTrue);
    });

    testWidgets('5. UploadSubtitlesAndDubbingPage renders dedicated configuration page cleanly', (tester) async {
      await pumpPageInHarness(
        tester,
        const UploadSubtitlesAndDubbingPage(),
        onBeforePump: () {
          final uploadCtrl = Get.put(UploadController());
          uploadCtrl.selectedChannel.value = createTestChannel();
          uploadCtrl.videoDurationSeconds.value = 360;
        },
      );

      expect(find.text('Subtitles and Dubbing'), findsWidgets);
      expect(find.textContaining('AI Subtitles & Translation'), findsOneWidget);
      expect(find.textContaining('AI Audio Translation & Dubbing'), findsOneWidget);
      expect(find.text('DUBBING IS NOT FREE'), findsOneWidget);
      expect(find.text('Live Pricing Breakdown'), findsOneWidget);
      expect(find.text('Save & Return to Studio'), findsOneWidget);
    });

    testWidgets('6. CreateContentUnifiedAiSection renders 5 feature chips and directly toggles features cleanly', (tester) async {
      late UploadController uploadCtrl;
      await pumpPageInHarness(
        tester,
        Builder(
          builder: (context) => CreateContentUnifiedAiSection(uploadController: uploadCtrl),
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

      // 1. Verify Card Header and all 5 chips
      expect(find.text('10. AI Features & Intelligence'), findsOneWidget);
      expect(find.text('AI Studio'), findsOneWidget);
      expect(find.text('Subtitles'), findsOneWidget);
      expect(find.text('Dubbing'), findsOneWidget);
      expect(find.text('Factcheck'), findsOneWidget);
      expect(find.text('Speaker Diarization'), findsOneWidget);
      expect(find.text('Auto Chapters'), findsOneWidget);

      // Guidance text visible when no studio languages are chosen yet
      expect(find.textContaining('Tap Subtitles or Dubbing'), findsOneWidget);

      // 2. Direct toggle Factcheck Chip
      await tester.tap(find.text('Factcheck'));
      await tester.pumpAndSettle();
      expect(uploadCtrl.aiFactCheckEnabled.value, isTrue);
      expect(find.text('Verified'), findsOneWidget);

      // 3. Direct toggle Speaker Diarization Chip
      await tester.tap(find.text('Speaker Diarization'));
      await tester.pumpAndSettle();
      expect(uploadCtrl.aiDiarizationEnabled.value, isTrue);

      // 4. Direct toggle Auto Chapters Chip
      await tester.tap(find.text('Auto Chapters'));
      await tester.pumpAndSettle();
      expect(uploadCtrl.aiChaptersEnabled.value, isTrue);

      // Verify NO redundant bulky duplicate switches for these 3 features
      expect(find.text('Truth Verification (Full Ground Truth)'), findsNothing);

      // 5. Simulate configured Subtitles
      uploadCtrl.aiGenerateSubtitles.value = true;
      uploadCtrl.aiTranslationLanguages.assignAll(['Telugu', 'Hindi', 'Spanish']);
      await tester.pumpAndSettle();
      expect(find.textContaining('AI Subtitles & Captions (3 languages)'), findsOneWidget);
      expect(find.text('Configure'), findsOneWidget);
    });
  });
}
