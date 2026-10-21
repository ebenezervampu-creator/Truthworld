import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audience_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audio_tracks_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/chapters_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_comments_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/drafts_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/subtitles_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audience_page.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks_page.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/channel_notifications_page.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/chapters_page.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/dashboard_comments_page.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/dashboard_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/drafts_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/subtitles_page.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/trash_restore_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification_dashboard_page.dart';

import '../test_helpers/mock_firebase.dart';
import 'page_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  tearDown(Get.reset);

  group('Group 6: Creator Studio / Dashboard Pages & Tabs', () {
    testWidgets('1. DashboardScreen renders studio sidebar, stats and tabs',
        (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      await pumpPageInHarness(
        tester,
        const DashboardScreen(),
        onBeforePump: () {
          Get.put(DashboardController(channelId: 'test_channel_123'));
        },
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(DashboardScreen), findsOneWidget);
    });

    testWidgets('2. ChaptersPage renders video chapter segment editor',
        (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      await pumpPageInHarness(
        tester,
        const ChaptersPage(
          channelId: 'test_channel_123',
          isDarkMode: true,
        ),
        onBeforePump: () {
          if (!Get.isRegistered<ChaptersController>()) {
            Get.put(ChaptersController());
          }
        },
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(ChaptersPage), findsOneWidget);
    });

    testWidgets('3. DraftsScreen renders video and post drafts tabs',
        (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      await pumpPageInHarness(
        tester,
        const DraftsScreen(
          channelId: 'test_channel_123',
          isDarkMode: true,
        ),
        onBeforePump: () {
          if (!Get.isRegistered<DraftsController>()) {
            Get.put(DraftsController(channelId: 'test_channel_123'));
          }
        },
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(DraftsScreen), findsOneWidget);
    });

    testWidgets('4. TrashRestoreScreen renders soft-deleted content list',
        (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      await pumpPageInHarness(
        tester,
        const TrashRestoreScreen(
          channelId: 'test_channel_123',
          isDarkMode: true,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(TrashRestoreScreen), findsOneWidget);
    });

    testWidgets('5. SubtitlesPage renders AI transcription and subtitle manager',
        (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      await pumpPageInHarness(
        tester,
        const SubtitlesPage(
          channelId: 'test_channel_123',
          isDarkMode: true,
        ),
        onBeforePump: () {
          if (!Get.isRegistered<SubtitlesController>()) {
            Get.put(SubtitlesController());
          }
        },
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(SubtitlesPage), findsOneWidget);
    });

    testWidgets('6. AudioTracksPage renders multi-language dubbing workspace',
        (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      await pumpPageInHarness(
        tester,
        AudioTracksPage(
          channelId: 'test_channel_123',
          isDarkMode: true,
        ),
        onBeforePump: () {
          if (!Get.isRegistered<AudioTracksController>()) {
            Get.put(AudioTracksController());
          }
        },
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(AudioTracksPage), findsOneWidget);
    });

    testWidgets('7. AudiencePage renders demographic analytics and subscriber charts',
        (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      await pumpPageInHarness(
        tester,
        const AudiencePage(
          channelId: 'test_channel_123',
          isDarkMode: true,
        ),
        onBeforePump: () {
          if (!Get.isRegistered<AudienceController>()) {
            Get.put(AudienceController(initialChannelId: 'test_channel_123'));
          }
        },
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(AudiencePage), findsOneWidget);
    });

    testWidgets('8. ChannelNotificationsPage renders AI safety and copyright insights',
        (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      await pumpPageInHarness(
        tester,
        const ChannelNotificationsPage(
          channelId: 'test_channel_123',
          creatorId: 'creator_123',
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(ChannelNotificationsPage), findsOneWidget);
    });

    testWidgets('9. DashboardCommentsPage renders community response and moderation',
        (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      await pumpPageInHarness(
        tester,
        const DashboardCommentsPage(),
        onBeforePump: () {
          if (!Get.isRegistered<DashboardCommentsController>()) {
            Get.put(DashboardCommentsController());
          }
        },
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(DashboardCommentsPage), findsOneWidget);
    });

    testWidgets('10. TruthVerificationDashboardPage renders claim verification dashboard',
        (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      await pumpPageInHarness(
        tester,
        TruthVerificationDashboardPage(
          channelId: 'test_channel_123',
          isDarkMode: true,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(TruthVerificationDashboardPage), findsOneWidget);
    });
  });
}
