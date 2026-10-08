import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/clip_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/widgets/video_clip_dialog.dart';

import '../../test_helpers/mock_firebase.dart';

class MockAuthService extends AuthService {
  @override
  final RxBool isAuthenticated = true.obs;
  @override
  String get uid => 'test_user_id';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Video testVideo;
  late MockAuthService authService;

  setUpAll(() async {
    await setupMockFirebase();
  });

  setUp(() {
    Get.reset();
    Get.testMode = true;
    authService = MockAuthService();
    Get.put<AuthService>(authService, permanent: true);
    Get.put<ConnectivityService>(ConnectivityService(), permanent: true);

    testVideo = Video(
      id: 'test_vid_clip_1',
      title: 'Amazing Science Experiment',
      description: 'Test description for clipping',
      videoUrl: 'https://example.com/video.mp4',
      thumbnailUrl: 'https://example.com/thumb.jpg',
      ownerId: 'owner_123',
      channelId: 'channel_123',
      channelName: 'Science Channel',
      category: 'Science',
      tags: const ['science', 'experiment'],
      duration: 300,
      vDurationValue: const Duration(seconds: 300),
      createdAt: DateTime.now(),
    );
  });

  tearDown(Get.reset);

  testWidgets('VideoClipDialog renders correctly on mobile viewport and adjusts presets',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final videoCtrl = Get.put(VideoController());
    videoCtrl.rxVideo.value = testVideo;

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  VideoClipDialog.show(
                    context: context,
                    controller: videoCtrl,
                    onSignInPrompt: () {},
                  );
                },
                child: const Text('Open Clip Dialog'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Clip Dialog'));
    await tester.pumpAndSettle();

    // Verify header and UI components render
    expect(find.text('Create Clip'), findsOneWidget);
    expect(find.text('SELECT SEGMENT'), findsOneWidget);
    expect(find.text('Quick Length:'), findsOneWidget);
    expect(find.text('5s'), findsWidgets);
    expect(find.text('10s'), findsOneWidget);
    expect(find.text('15s'), findsOneWidget);
    expect(find.text('30s'), findsOneWidget);
    expect(find.text('START TIME'), findsOneWidget);
    expect(find.text('END TIME'), findsOneWidget);
    expect(find.text('Preview Clip'), findsOneWidget);
    expect(find.text('Save Clip'), findsOneWidget);
    expect(find.text('Share Clip'), findsOneWidget);

    // Tap on 10s preset chip
    final clipController = Get.find<ClipController>();
    await tester.tap(find.text('10s'));
    await tester.pump();
    expect(clipController.endSeconds.value - clipController.startSeconds.value, equals(10.0));

    // Tap on +1s stepper for Start Time
    final initialStart = clipController.startSeconds.value;
    await tester.tap(find.text('+1s').first);
    await tester.pump();
    expect(clipController.startSeconds.value, equals(initialStart + 1.0));
  });

  testWidgets('VideoClipDialog renders centered dialog on desktop viewport',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final videoCtrl = Get.put(VideoController());
    videoCtrl.rxVideo.value = testVideo;

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  VideoClipDialog.show(
                    context: context,
                    controller: videoCtrl,
                    onSignInPrompt: () {},
                  );
                },
                child: const Text('Open Clip Dialog'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Clip Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Create Clip'), findsOneWidget);
    expect(find.text('SELECT SEGMENT'), findsOneWidget);
    expect(find.text('Save Clip'), findsOneWidget);
    expect(find.text('Share Clip'), findsOneWidget);
  });
}
