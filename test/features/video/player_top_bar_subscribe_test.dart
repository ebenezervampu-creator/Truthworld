import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_subscription_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/services/sleep_timer_service.dart';
import 'package:truthworld/features/video/presentation/views/player/controls/components/player_top_bar.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../../test_helpers/mock_firebase.dart';

class _FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  @override
  Future<void> init() async {}
  @override
  Future<void> dispose(int textureId) async {}
  @override
  Future<int?> create(DataSource dataSource) async => 1;
  @override
  Future<void> setLooping(int textureId, bool looping) async {}
  @override
  Future<void> play(int textureId) async {}
  @override
  Future<void> pause(int textureId) async {}
  @override
  Future<void> setVolume(int textureId, double volume) async {}
  @override
  Future<void> setPlaybackSpeed(int textureId, double speed) async {}
  @override
  Future<void> seekTo(int textureId, Duration position) async {}
  @override
  Future<Duration> getPosition(int textureId) async => Duration.zero;
  @override
  Stream<VideoEvent> videoEventsFor(int textureId) => const Stream.empty();
  @override
  Widget buildView(int textureId) => const SizedBox();
  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
}

class _FakeConnectivityService extends GetxService implements ConnectivityService {
  @override
  ConnectivityResult get connectionStatus => ConnectivityResult.wifi;
  @override
  bool get isConnected => true;
  @override
  bool get isWifi => true;
  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => const Stream.empty();
  @override
  Stream<ConnectivityResult> get onConnectivityRestored => const Stream.empty();
  @override
  Future<ConnectivityService> init() async => this;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TowerPlayerController playerCtrl;
  late VideoController videoCtrl;
  late ChannelSubscriptionController subCtrl;
  late VideoPlayerController vpc;

  setUpAll(() async {
    VideoPlayerPlatform.instance = _FakeVideoPlayerPlatform();
    await setupMockFirebase();
  });

  setUp(() {
    Get.reset();
    Get.put<ConnectivityService>(_FakeConnectivityService());
    Get.put(SleepTimerService());
    if (!Get.isRegistered<AuthService>()) {
      Get.put(AuthService());
    }

    subCtrl = ChannelSubscriptionController();
    Get.put<ChannelSubscriptionController>(subCtrl, tag: 'topbar_test_tag');
    Get.put<ChannelSubscriptionController>(subCtrl);

    vpc = VideoPlayerController.networkUrl(Uri.parse('https://example.com/video.mp4'));
    playerCtrl = TowerPlayerController(
      videoPlayerController: vpc,
      tag: 'topbar_test_tag',
    );
    playerCtrl.isFullScreen.value = true;

    videoCtrl = VideoController(tag: 'topbar_test_tag');
    videoCtrl.video = Video(
      id: 'v_123',
      title: 'Christian songs Redx Media',
      channelName: 'Ebenezer Vampu',
      channelId: 'ch_456',
      ownerId: 'user_456',
      videoUrl: 'https://example.com/video.mp4',
      thumbnailUrl: '',
      description: 'Test video',
      category: 'Music',
      tags: const ['music'],
      views: 100,
      likes: 10,
      createdAt: DateTime.now(),
    );

    Get.put<VideoController>(videoCtrl, tag: 'topbar_test_tag');
    videoCtrl.channelController.subController = subCtrl;
  });

  tearDown(() {
    playerCtrl.timers.cancelAll();
    playerCtrl.cancelPendingTap();
    TowerPlayerRegistry.unregister(playerCtrl);
    Get.reset();
  });

  group('PlayerTopBar Fullscreen Subscribe and Bell Options Tests', () {
    testWidgets('Renders "Subscribe" button with high-contrast styling when unsubscribed', (tester) async {
      final isSubbedRx = subCtrl.isSubscribedTo('ch_456');
      isSubbedRx.value = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 200,
              child: PlayerTopBar(ctrl: playerCtrl),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check title and channel name
      expect(find.text('Christian songs Redx Media'), findsOneWidget);
      expect(find.text('Ebenezer Vampu'), findsOneWidget);

      // Check Subscribe button is rendered (NOT "+ Follow")
      expect(find.text('Subscribe'), findsOneWidget);
      expect(find.text('+ Follow'), findsNothing);
      expect(find.text('Following'), findsNothing);

      // Verify text color on white button is black
      final textWidget = tester.widget<Text>(find.text('Subscribe'));
      expect(textWidget.style?.color, equals(Colors.black));

      // Bell icon should NOT be present when unsubscribed
      expect(find.byIcon(Icons.notifications_outlined), findsNothing);
      expect(find.byIcon(Icons.notifications_active_outlined), findsNothing);
    });

    testWidgets('Renders "Subscribed" button and Bell icon when subscribed', (tester) async {
      final isSubbedRx = subCtrl.isSubscribedTo('ch_456');
      isSubbedRx.value = true;
      subCtrl.getNotificationOption('ch_456').value = 'personalized';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 200,
              child: PlayerTopBar(ctrl: playerCtrl),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check Subscribed text is rendered
      expect(find.text('Subscribed'), findsOneWidget);
      expect(find.text('Subscribe'), findsNothing);
      expect(find.text('+ Follow'), findsNothing);

      // Check dropdown arrow is rendered next to Subscribed
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);

      // Check personalized notification bell icon is rendered
      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
    });

    testWidgets('Notification bell updates dynamically when preference changes', (tester) async {
      final isSubbedRx = subCtrl.isSubscribedTo('ch_456');
      isSubbedRx.value = true;
      final prefRx = subCtrl.getNotificationOption('ch_456');
      prefRx.value = 'personalized';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 200,
              child: PlayerTopBar(ctrl: playerCtrl),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Personalized
      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
      expect(find.byIcon(Icons.notifications_active_outlined), findsNothing);
      expect(find.byIcon(Icons.notifications_off_outlined), findsNothing);

      // 2. All notifications
      prefRx.value = 'all';
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.notifications_active_outlined), findsOneWidget);
      expect(find.byIcon(Icons.notifications_outlined), findsNothing);
      expect(find.byIcon(Icons.notifications_off_outlined), findsNothing);

      // 3. None / Off notifications
      prefRx.value = 'none';
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.notifications_off_outlined), findsOneWidget);
      expect(find.byIcon(Icons.notifications_active_outlined), findsNothing);
      expect(find.byIcon(Icons.notifications_outlined), findsNothing);
    });
  });
}
