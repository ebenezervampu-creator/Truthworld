import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_dubbing_controller.dart';
import 'package:truthworld/features/video/presentation/views/upload/components/dubbing/dubbing_multi_language_picker_sheet.dart';

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

  Channel createChannel({String language = 'en'}) {
    return Channel(
      id: 'chan-overflow-test',
      name: 'Truth Creator',
      nameLowercase: 'truth creator',
      handle: '@truthcreator',
      handleLowercase: '@truthcreator',
      description: 'Test channel',
      avatarUrl: '',
      bannerUrl: '',
      ownerId: 'user-1',
      language: language,
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    );
  }

  group('Multi-language picker sheet overflow regression tests', () {
    testWidgets(
      'showDubbingMultiLanguagePicker does not overflow on 384px viewport when Clear All is shown',
      (tester) async {
        tester.view.physicalSize = const Size(384, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final uploadCtrl = Get.put(UploadController());
        uploadCtrl.selectedChannel.value = createChannel();
        final dubCtrl = Get.put(UploadDubbingController());
        dubCtrl.selectedLanguages.assignAll(['Spanish', 'Hindi']);

        await tester.pumpWidget(
          GetMaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => showDubbingMultiLanguagePicker(
                    context: ctx,
                    controller: dubCtrl,
                  ),
                  child: const Text('Open Dubbing Picker'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Dubbing Picker'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('+ Top 5 Global'), findsOneWidget);
        expect(find.text('+ Top Indic'), findsOneWidget);
        expect(find.text('+ Top European'), findsOneWidget);
        expect(find.text('Clear All'), findsOneWidget);

        // Tap Clear All and preset buttons while constrained to 384px width
        await tester.tap(find.text('Clear All'));
        await tester.pump();
        expect(dubCtrl.selectedLanguages, isEmpty);
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('+ Top 5 Global'));
        await tester.pump();
        expect(dubCtrl.selectedLanguages, isNotEmpty);
        expect(find.text('Clear All'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'showDubbingMultiLanguagePicker handles long source language names on 320px viewport without overflow',
      (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final uploadCtrl = Get.put(UploadController());
        uploadCtrl.selectedChannel.value = createChannel(language: 'zh');
        final dubCtrl = Get.put(UploadDubbingController());
        dubCtrl.selectedLanguages.assignAll(['Spanish']);

        await tester.pumpWidget(
          GetMaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => showDubbingMultiLanguagePicker(
                    context: ctx,
                    controller: dubCtrl,
                  ),
                  child: const Text('Open Dubbing Picker'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Dubbing Picker'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Select Dubbing Languages'), findsOneWidget);

        await tester.scrollUntilVisible(
          find.text('SOURCE LANGUAGE'),
          300,
          scrollable: find.descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('SOURCE LANGUAGE'), findsOneWidget);
      },
    );

    testWidgets(
      'showSubtitlesMultiLanguagePicker does not overflow on 384px viewport with Clear All visible',
      (tester) async {
        tester.view.physicalSize = const Size(384, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final uploadCtrl = Get.put(UploadController());
        uploadCtrl.selectedChannel.value = createChannel();
        uploadCtrl.aiTranslationLanguages.assignAll(['Spanish', 'French']);

        await tester.pumpWidget(
          GetMaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => showSubtitlesMultiLanguagePicker(
                    context: ctx,
                    controller: uploadCtrl,
                  ),
                  child: const Text('Open Subtitles Picker'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Subtitles Picker'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('+ Top 5 Global'), findsOneWidget);
        expect(find.text('+ Top Indic'), findsOneWidget);
        expect(find.text('Clear All'), findsOneWidget);
      },
    );

    testWidgets(
      'showSpokenLanguagePicker renders properly in single language mode without GetX Obx exceptions',
      (tester) async {
        final uploadCtrl = Get.put(UploadController());
        uploadCtrl.selectedChannel.value = createChannel();
        uploadCtrl.isMultilingualSpoken.value = false;
        uploadCtrl.primarySpokenLanguage.value = 'auto';

        await tester.pumpWidget(
          GetMaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => showSpokenLanguagePicker(
                    context: ctx,
                    controller: uploadCtrl,
                  ),
                  child: const Text('Open Spoken Language Picker'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Spoken Language Picker'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Select Spoken Video Language ("From")'), findsOneWidget);
        expect(find.text('Auto-Detect'), findsOneWidget);
        expect(find.text('Hindi'), findsOneWidget);

        // Tap a language to select it in single language mode
        await tester.tap(find.text('Hindi'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(uploadCtrl.primarySpokenLanguage.value, 'hi');
      },
    );

    testWidgets(
      'showSpokenLanguagePicker renders properly in multilingual mode without GetX Obx exceptions',
      (tester) async {
        final uploadCtrl = Get.put(UploadController());
        uploadCtrl.selectedChannel.value = createChannel();
        uploadCtrl.isMultilingualSpoken.value = true;
        uploadCtrl.spokenLanguages.assignAll(['en']);

        await tester.pumpWidget(
          GetMaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => showSpokenLanguagePicker(
                    context: ctx,
                    controller: uploadCtrl,
                  ),
                  child: const Text('Open Multilingual Spoken Picker'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Multilingual Spoken Picker'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Select Spoken Video Language ("From")'), findsOneWidget);

        // Toggle Hindi in multilingual mode
        await tester.tap(find.text('Hindi'));
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(uploadCtrl.spokenLanguages.contains('hi'), isTrue);
      },
    );
  });
}
