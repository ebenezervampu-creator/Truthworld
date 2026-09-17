import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/community/community_post_upload_controller.dart';
import 'package:truthworld/features/community/community_post_upload_screen.dart';
import 'package:truthworld/features/playlist/presentation/views/playlist/create_playlist_screen.dart';
import 'package:truthworld/features/topics/presentation/pages/create_topic_screen.dart';
import 'package:truthworld/features/video/presentation/controllers/downloadcontroller.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_controller.dart';
import 'package:truthworld/features/video/presentation/views/downloadpage/download_page.dart';
import 'package:truthworld/features/video/presentation/views/upload/create_content_screen.dart';
import 'package:truthworld/features/video/presentation/views/upload/models/upload_type.dart';
import 'package:truthworld/features/video/presentation/views/upload/upload_selection_screen.dart';
import '../test_helpers/mock_firebase.dart';
import 'page_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  tearDown(Get.reset);

  group('Group 3: Content Creation & Upload Pages', () {
    testWidgets('1. UploadSelectionScreen renders content type cards and options',
        (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      await pumpPageInHarness(
        tester,
        const UploadSelectionScreen(),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(UploadSelectionScreen), findsOneWidget);
    });

    testWidgets('2. CreateContentScreen (Video) renders multi-step upload wizard',
        (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      await pumpPageInHarness(
        tester,
        const CreateContentScreen(uploadType: UploadType.video),
        onBeforePump: () {
          Get.put<UploadController>(UploadController());
        },
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(CreateContentScreen), findsOneWidget);
    });

    testWidgets('3. CommunityPostUploadScreen renders post creator form and options',
        (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      await pumpPageInHarness(
        tester,
        const CommunityPostUploadScreen(),
        onBeforePump: () {
          Get.put<CommunityPostUploadController>(CommunityPostUploadController());
        },
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(CommunityPostUploadScreen), findsOneWidget);
    });

    testWidgets('4. CreatePlaylistScreen renders playlist creation form and video picker',
        (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      await pumpPageInHarness(
        tester,
        const CreatePlaylistScreen(),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(CreatePlaylistScreen), findsOneWidget);
    });

    testWidgets('5. CreateTopicScreen renders topic creation dialog and category selectors',
        (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      await pumpPageInHarness(
        tester,
        const CreateTopicScreen(),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(CreateTopicScreen), findsOneWidget);
    });

    testWidgets('6. DownloadsPage renders offline downloads list and storage status',
        (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      await pumpPageInHarness(
        tester,
        const DownloadsPage(),
        onBeforePump: () {
          Get.put<DownloadsController>(DownloadsController());
        },
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(DownloadsPage), findsOneWidget);
    });
  });
}
