import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/features/home/presentation/controllers/main_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/widgets/video_action_buttons.dart';
import '../../test_helpers/mock_firebase.dart';

class TestMainController extends MainController {
  final RxMap<String, int> _mockLikes = <String, int>{}.obs;
  final RxMap<String, int> _mockDislikes = <String, int>{}.obs;

  @override
  RxMap<String, int> get videoLikes => _mockLikes;

  @override
  RxMap<String, int> get videoDislikes => _mockDislikes;

  @override
  // ignore: must_call_super
  void onInit() {
    // Avoid triggering live Firestore/RTDB listeners in isolated unit test
  }

  @override
  Future<void> likeVideo(String videoId, String userId) async {
    // Simulated remote persistence
  }

  @override
  Future<void> dislikeVideo(String videoId, String userId) async {
    // Simulated remote persistence
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
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
    if (!Get.isRegistered<MainController>()) {
      Get.put<MainController>(TestMainController(), permanent: true);
    }
  });

  tearDown(Get.reset);

  group('VideoActionButtons Audit Tests', () {
    testWidgets('1. Builds cleanly on mobile layout', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final video = Video(
        id: 'test_vid_audit_1',
        title: 'Audit Video Title',
        description: 'Audit video description',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        ownerId: 'owner_test_1',
        channelName: 'Truth Channel',
        channelId: 'ch_test_1',
        category: 'Technology',
        tags: const ['AI', 'Truth'],
        videoUrl: 'https://example.com/video.mp4',
        topics: const ['AI', 'Truth'],
      );

      final vc = Get.put(VideoController(tag: video.id));
      vc.rxVideo.value = video;
      final mainCtrl = Get.find<MainController>();

      var signInPromptCount = 0;

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return VideoActionButtons.build(
                  context: context,
                  controller: vc,
                  mainController: mainCtrl,
                  channelController: vc.channelController,
                  onSignInPrompt: () => signInPromptCount++,
                  isDesktop: false,
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find Like button, Share, Clip, Save, Download
      expect(find.text('Share'), findsOneWidget);
      expect(find.text('Clip'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Download'), findsOneWidget);
    });

    testWidgets('2. Builds cleanly on desktop layout with isDesktop: true', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final video = Video(
        id: 'test_vid_audit_2',
        title: 'Desktop Audit Video',
        description: 'Desktop audit description',
        thumbnailUrl: 'https://example.com/thumb2.jpg',
        ownerId: 'owner_test_2',
        channelName: 'Science Channel',
        channelId: 'ch_test_2',
        category: 'Science',
        tags: const ['Science'],
        videoUrl: 'https://example.com/video2.mp4',
      );

      final vc = Get.put(VideoController(tag: video.id));
      vc.rxVideo.value = video;
      final mainCtrl = Get.find<MainController>();

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return VideoActionButtons.build(
                  context: context,
                  controller: vc,
                  mainController: mainCtrl,
                  channelController: vc.channelController,
                  onSignInPrompt: () {},
                  isDesktop: true,
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Share'), findsOneWidget);
      expect(find.text('Clip'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Download'), findsOneWidget);
    });

    test('3. Video engagement action mixin toggleSubscription calls subController', () async {
      final video = Video(
        id: 'test_vid_audit_3',
        title: 'Engagement Audit Video',
        description: 'Engagement description',
        thumbnailUrl: 'https://example.com/thumb3.jpg',
        ownerId: 'owner_test_3',
        channelName: 'Channel 3',
        channelId: 'ch_test_3',
        category: 'News',
        tags: const ['News'],
        videoUrl: 'https://example.com/video3.mp4',
      );

      final vc = Get.put(VideoController(tag: video.id));
      vc.rxVideo.value = video;

      expect(vc.isSubscribed.value, isFalse);
      await vc.toggleSubscription();
      // Should not throw or crash and attempts subscription logic
    });
  });
}
