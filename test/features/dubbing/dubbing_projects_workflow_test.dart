import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/dubbing/data/models/dubbing_job.dart';
import 'package:truthworld/features/dubbing/data/models/dubbing_project.dart';
import 'package:truthworld/features/dubbing/presentation/controllers/dubbing_studio_controller.dart';
import 'package:truthworld/features/dubbing/presentation/views/dubbing_studio_screen.dart';

import '../../test_helpers/mock_firebase.dart';

class _InMemoryDubbingController extends DubbingStudioController {
  final List<DubbingProject> persisted = [];

  @override
  Future<void> refreshWallet() async {}

  @override
  Future<void> loadUserChannelAndVideos() async {}

  @override
  Future<void> loadSavedProjects() async {
    savedProjects.assignAll(persisted);
  }

  @override
  Future<void> fetchServerQuote() async {}

  @override
  Future<DubbingProject?> createNewProject({String? title}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final cleanTitle = (title != null && title.trim().isNotEmpty)
        ? title.trim()
        : 'Untitled Project';
    final proj = DubbingProject(
      id: 'proj_$now',
      userId: 'user_1',
      title: cleanTitle,
      sourceInputMode: 'file_upload',
      sourceLanguage: 'en',
      createdAt: now,
      updatedAt: now,
    );
    persisted.insert(0, proj);
    savedProjects.insert(0, proj);
    await openProject(proj);
    return proj;
  }

  @override
  Future<void> saveActiveProject({bool immediate = false}) async {
    final current = activeProject.value;
    if (current == null) return;
    final updated = current.copyWith(
      title: mediaTitle.value.trim().isNotEmpty ? mediaTitle.value.trim() : current.title,
      sourceLanguage: sourceLanguage.value,
      targetLanguages: targetLanguages.toList(),
      mode: mode.value,
      voiceCloningEnabled: voiceCloningEnabled.value,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    activeProject.value = updated;
    final idx = persisted.indexWhere((p) => p.id == updated.id);
    if (idx >= 0) {
      persisted[idx] = updated;
    } else {
      persisted.insert(0, updated);
    }
    final sIdx = savedProjects.indexWhere((p) => p.id == updated.id);
    if (sIdx >= 0) {
      savedProjects[sIdx] = updated;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  setUp(Get.reset);
  tearDown(Get.reset);

  group('Dubbing Studio Projects Hub & Settings Tabs', () {
    test('DubbingProject serializes and wraps legacy DubbingJob cleanly', () {
      final project = DubbingProject(
        id: 'proj_101',
        userId: 'user_abc',
        title: 'Quantum Mechanics Dub',
        sourceInputMode: 'file_upload',
        sourceMediaUrl: 'https://cdn.truthworld.in/src.mp4',
        sourceLanguage: 'en',
        targetLanguages: ['te', 'hi'],
        mode: DubbingMode.subtitlesOnly,
        jobIds: ['job_1', 'job_2'],
        dubbedLanguages: ['te'],
        subtitledLanguages: ['te', 'hi'],
        latestJobId: 'job_2',
        latestStatus: 'completed',
        createdAt: 1700000000000,
        updatedAt: 1700000500000,
      );

      final map = project.toMap();
      final decoded = DubbingProject.fromMap(map);

      expect(decoded.id, 'proj_101');
      expect(decoded.userId, 'user_abc');
      expect(decoded.title, 'Quantum Mechanics Dub');
      expect(decoded.mode, DubbingMode.subtitlesOnly);
      expect(decoded.targetLanguages, ['te', 'hi']);
      expect(decoded.jobIds, ['job_1', 'job_2']);
      expect(decoded.dubbedLanguages, ['te']);
      expect(decoded.subtitledLanguages, ['te', 'hi']);
      expect(decoded.latestStatus, 'completed');

      final legacyJob = DubbingJob(
        id: 'dub_legacy_1',
        userId: 'user_abc',
        title: 'Legacy Video Dub',
        mode: DubbingMode.dubbing,
        status: DubbingJobStatus.completed,
        progressPercent: 100,
        currentStepMessage: 'Done',
        sourceMediaUrl: 'https://cdn.truthworld.in/leg.mp4',
        sourceMediaType: 'video',
        durationSeconds: 90,
        characterCount: 900,
        sourceLanguage: 'en',
        targetLanguages: ['ta'],
        voiceCloningEnabled: false,
        twoStageReviewEnabled: false,
        publishToTruthworld: false,
        costUsd: 0.30,
        totalCharactersCharged: 900,
        speakers: const [],
        segmentsByLanguage: const {},
        createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );

      final wrapped = DubbingProject.fromLegacyJob(legacyJob);
      expect(wrapped.id, 'legacy_dub_legacy_1');
      expect(wrapped.jobIds, ['dub_legacy_1']);
      expect(wrapped.dubbedLanguages, ['ta']);
      expect(wrapped.subtitledLanguages, ['ta']);
      expect(wrapped.latestStatus, 'completed');
    });

    testWidgets('Signed-in new user sees only Create New Project card below clean Appbar', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final authService = Get.put<AuthService>(AuthService(), permanent: true);
      authService.setAuthenticatedForTesting(isAuthenticated: true, uid: 'new_user_1');
      authService.userDisplayName.value = 'New Creator';

      Get.put<DubbingStudioController>(_InMemoryDubbingController());

      await tester.pumpWidget(
        const GetMaterialApp(
          home: DubbingStudioScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Appbar must NOT contain Voice Dubbing or Subtitles Only pills
      expect(find.text('Voice Dubbing'), findsNothing);
      expect(find.text('Subtitles Only'), findsNothing);

      // Studio workspace must NOT be shown before project creation
      expect(find.text('SOURCE VIDEO OR AUDIO'), findsNothing);
      expect(find.text('PROJECT SETTINGS'), findsNothing);

      // Create New Project container card MUST be visible
      expect(find.byKey(const Key('create_new_project_card')), findsOneWidget);
      expect(find.text('Create New Project'), findsOneWidget);
    });

    testWidgets('Tapping Create New Project creates project, shows workspace, and exposes Dub/Subtitles tabs after selecting languages', (tester) async {
      tester.view.physicalSize = const Size(1280, 960);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final authService = Get.put<AuthService>(AuthService(), permanent: true);
      authService.setAuthenticatedForTesting(isAuthenticated: true, uid: 'user_1');
      authService.userDisplayName.value = 'Creator';

      final controller = Get.put<DubbingStudioController>(_InMemoryDubbingController());

      await tester.pumpWidget(
        const GetMaterialApp(
          home: DubbingStudioScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Tap Create New Project card
      await tester.tap(find.byKey(const Key('create_new_project_card')));
      await tester.pumpAndSettle();

      // Dialog appears
      expect(find.text('Project Name'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'Space Science Ep 1');
      await tester.tap(find.text('Create Project'));
      await tester.pumpAndSettle();

      // 2. Full project workspace is now visible
      expect(controller.activeProject.value?.title, 'Space Science Ep 1');
      expect(find.text('Space Science Ep 1'), findsWidgets);
      expect(find.text('SOURCE VIDEO OR AUDIO'), findsOneWidget);
      expect(find.text('PROJECT SETTINGS'), findsOneWidget);

      // 3. Before selecting output languages, Dub/Subtitles tabs are not active yet
      expect(find.text('Select output languages above to choose Dub or Subtitles.'), findsOneWidget);
      expect(find.byKey(const Key('mode_tab_dub')), findsNothing);
      expect(find.byKey(const Key('mode_tab_subtitles')), findsNothing);

      // 4. Select output language -> Dub & Subtitles tabs appear in Project Settings
      controller.toggleTargetLanguage('te');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mode_tab_dub')), findsOneWidget);
      expect(find.byKey(const Key('mode_tab_subtitles')), findsOneWidget);
      expect(find.text('Start Dubbing'), findsOneWidget);
      expect(find.text('VOICE & AUDIO SETTINGS'), findsOneWidget);

      // 5. Tap Subtitles tab -> switches mode, hides voice settings, updates CTA
      await tester.tap(find.byKey(const Key('mode_tab_subtitles')));
      await tester.pumpAndSettle();

      expect(controller.mode.value, DubbingMode.subtitlesOnly);
      expect(find.text('Generate Subtitles'), findsOneWidget);
      expect(find.text('VOICE & AUDIO SETTINGS'), findsNothing);

      // 6. Tap Dub tab -> switches back to dubbing
      await tester.tap(find.byKey(const Key('mode_tab_dub')));
      await tester.pumpAndSettle();

      expect(controller.mode.value, DubbingMode.dubbing);
      expect(find.text('Start Dubbing'), findsOneWidget);

      // 7. Return to Projects Hub -> saved project card appears
      await tester.tap(find.text('Projects'));
      await tester.pumpAndSettle();

      expect(find.text('SAVED PROJECTS (1)'), findsOneWidget);
      expect(find.text('Space Science Ep 1'), findsOneWidget);

      // 8. Reopen saved project -> settings & selected languages are restored
      await tester.tap(find.text('Space Science Ep 1'));
      await tester.pumpAndSettle();

      expect(controller.activeProject.value?.title, 'Space Science Ep 1');
      expect(controller.targetLanguages, contains('te'));
      expect(find.byKey(const Key('mode_tab_dub')), findsOneWidget);
      expect(find.byKey(const Key('mode_tab_subtitles')), findsOneWidget);
    });

    test('Project accumulates dubbed videos and subtitles across multiple jobs', () {
      final controller = Get.put<DubbingStudioController>(_InMemoryDubbingController());

      final dubJob = DubbingJob(
        id: 'job_dub_te',
        userId: 'u1',
        title: 'Multi Run Project',
        mode: DubbingMode.dubbing,
        status: DubbingJobStatus.completed,
        progressPercent: 100,
        currentStepMessage: 'Done',
        sourceMediaUrl: 'https://example.com/orig.mp4',
        sourceMediaType: 'video',
        durationSeconds: 30,
        characterCount: 300,
        sourceLanguage: 'en',
        targetLanguages: ['te'],
        voiceCloningEnabled: false,
        twoStageReviewEnabled: false,
        publishToTruthworld: false,
        costUsd: 0.30,
        totalCharactersCharged: 300,
        speakers: const [],
        segmentsByLanguage: const {},
        createdAt: DateTime(2026, 1, 1),
        exportUrls: const {
          'dubbedVideoByLanguage': {'te': 'https://example.com/te_dub.mp4'},
          'dubbedAudioByLanguage': {'te': 'https://example.com/te_dub.mp3'},
        },
      );

      final subJob = DubbingJob(
        id: 'job_sub_hi',
        userId: 'u1',
        title: 'Multi Run Project',
        mode: DubbingMode.subtitlesOnly,
        status: DubbingJobStatus.completed,
        progressPercent: 100,
        currentStepMessage: 'Done',
        sourceMediaUrl: 'https://example.com/orig.mp4',
        sourceMediaType: 'video',
        durationSeconds: 30,
        characterCount: 300,
        sourceLanguage: 'en',
        targetLanguages: ['hi'],
        voiceCloningEnabled: false,
        twoStageReviewEnabled: false,
        publishToTruthworld: false,
        costUsd: 0.10,
        totalCharactersCharged: 300,
        speakers: const [],
        segmentsByLanguage: const {},
        createdAt: DateTime(2026, 1, 2),
        exportUrls: const {
          'subtitlesSrt': {'hi': 'https://example.com/hi.srt'},
          'subtitlesVtt': {'hi': 'https://example.com/hi.vtt'},
        },
      );

      controller.projectJobs.assignAll([subJob, dubJob]);
      controller.activeJob.value = subJob;

      expect(controller.allProjectOutputLanguages, containsAll(['hi', 'te']));
      expect(controller.allProjectDubbedLanguages, ['te']);
      expect(controller.combinedDubbedVideosByLang['te'], 'https://example.com/te_dub.mp4');
      expect(controller.combinedSubtitlesSrtByLang['hi'], 'https://example.com/hi.srt');
      expect(controller.combinedSubtitlesVttByLang['hi'], 'https://example.com/hi.vtt');
    });
  });
}
