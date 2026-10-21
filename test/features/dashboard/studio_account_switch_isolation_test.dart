import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/core/services/user_session_reset_manager.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audience_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_view_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/drafts_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/playlists_management_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/studio_settings_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/topic_management_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/trash_restore_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/video_management.dart';
import 'package:truthworld/features/notifications/presentation/controllers/user_notification_controller.dart';
import 'package:truthworld/features/watchhistory/presentation/controllers/watch_history_controller.dart';
import 'package:truthworld/features/watchlater/presentation/controllers/watchlater_controller.dart';
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
      Get.put<AuthService>(AuthService(), permanent: true);
    }
    if (!Get.isRegistered<ConnectivityService>()) {
      Get.put<ConnectivityService>(ConnectivityService(), permanent: true);
    }
  });

  tearDown(() {
    UserSessionResetManager.resetAllUserSessions();
    Get.reset();
  });

  final channelA = Channel(
    id: 'channel_user_a',
    name: 'Channel User A',
    nameLowercase: 'channel user a',
    handle: '@usera',
    handleLowercase: '@usera',
    description: 'Channel A Description',
    avatarUrl: 'https://example.com/avatar_a.png',
    bannerUrl: '',
    ownerId: 'user_a_uid',
    createdAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
  );

  final channelB = Channel(
    id: 'channel_user_b',
    name: 'Channel User B',
    nameLowercase: 'channel user b',
    handle: '@userb',
    handleLowercase: '@userb',
    description: 'Channel B Description',
    avatarUrl: 'https://example.com/avatar_b.png',
    bannerUrl: '',
    ownerId: 'user_b_uid',
    createdAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
  );

  group('Studio Account Switching & Cross-Account Isolation Tests', () {
    testWidgets(
        'clears all studio and user-scoped controller data on signOut and resets session state',
        (tester) async {
      final auth = AuthService.to;
      auth.isAuthenticated.value = true;
      auth.setUserChannel(channelA);

      final dashboardCtrl = Get.put(
        DashboardController(channelId: channelA.id, autoInitialize: false),
      );
      dashboardCtrl.currentChannel.value = channelA;
      dashboardCtrl.channelStats.assignAll({'subscribers': 100, 'views': 500});
      dashboardCtrl.totalWatchTimeSeconds.value = 7200;

      final settingsCtrl = Get.put(StudioSettingsController());
      settingsCtrl.userData.assignAll({'theme': 'dark', 'email': 'a@truthworld.in'});

      Get.put(DraftsController());
      Get.put(VideoManagementController());
      Get.put(PlaylistsManagementController());
      Get.put(TrashRestoreController(channelId: channelA.id));
      Get.put(TopicManagementController());
      Get.put(AudienceController(initialChannelId: channelA.id));
      Get.put(WatchHistoryController());
      Get.put(WatchLaterController());
      Get.put(UserNotificationController());

      expect(dashboardCtrl.channelId, equals('channel_user_a'));
      expect(dashboardCtrl.currentChannel.value?.name, equals('Channel User A'));
      expect(settingsCtrl.userData['email'], equals('a@truthworld.in'));

      // Sign out
      await auth.signOut();
      await tester.pump();

      expect(auth.isAuthenticated.value, isFalse);
      expect(auth.userChannel, isNull);
      expect(auth.hasChannel.value, isFalse);

      // Verify that UserSessionResetManager purged or cleared all studio controllers
      expect(Get.isRegistered<DashboardController>(), isFalse);
      expect(Get.isRegistered<StudioSettingsController>(), isFalse);
      expect(Get.isRegistered<DraftsController>(), isFalse);
      expect(Get.isRegistered<VideoManagementController>(), isFalse);
      expect(Get.isRegistered<PlaylistsManagementController>(), isFalse);
      expect(Get.isRegistered<TrashRestoreController>(), isFalse);
      expect(Get.isRegistered<TopicManagementController>(), isFalse);
      expect(Get.isRegistered<AudienceController>(), isFalse);
      expect(Get.isRegistered<WatchHistoryController>(), isFalse);
      expect(Get.isRegistered<WatchLaterController>(), isFalse);
      expect(Get.isRegistered<UserNotificationController>(), isFalse);
    });

    testWidgets(
        'DashboardViewController does not leak previous account channel when user switches',
        (tester) async {
      final auth = AuthService.to;
      auth.isAuthenticated.value = true;
      auth.setUserChannel(channelA);

      final viewCtrl = Get.put(DashboardViewController());
      final dbCtrl = viewCtrl.dashboardController;
      dbCtrl.currentChannel.value = channelA;

      expect(viewCtrl.getChannelId(viewCtrl.channel), equals('channel_user_a'));

      // Sign out
      await viewCtrl.handleSignOut();
      await tester.pump();

      expect(auth.isAuthenticated.value, isFalse);
      expect(auth.userChannel, isNull);

      // User B signs in with Channel B
      auth.isAuthenticated.value = true;
      auth.setUserChannel(channelB);

      // Fresh DashboardViewController
      final newViewCtrl = Get.put(DashboardViewController());
      final newDbCtrl = newViewCtrl.dashboardController;

      expect(newViewCtrl.getChannelId(newViewCtrl.channel), equals('channel_user_b'));
      expect(newViewCtrl.getChannelName(newViewCtrl.channel), equals('Channel User B'));
      expect(newDbCtrl.channelId, equals('channel_user_b'));
      UserSessionResetManager.resetAllUserSessions();
      await tester.pump();
    });

    testWidgets(
        'User B without a channel does not see previous User A channel',
        (tester) async {
      final auth = AuthService.to;
      auth.isAuthenticated.value = true;
      auth.setUserChannel(channelA);

      final viewCtrl = Get.put(DashboardViewController());
      final dbCtrl = viewCtrl.dashboardController;
      dbCtrl.currentChannel.value = channelA;

      // Sign out
      await viewCtrl.handleSignOut();
      await tester.pump();

      // User B signs in without any channel
      auth.isAuthenticated.value = true;
      auth.clearUserChannel();

      final newViewCtrl = Get.put(DashboardViewController());
      expect(newViewCtrl.channel, isNull);
      expect(newViewCtrl.getChannelId(newViewCtrl.channel), isEmpty);
      UserSessionResetManager.resetAllUserSessions();
      await tester.pump();
    });

    test('UserSessionResetManager safely handles already disposed or unregistered controllers', () {
      expect(UserSessionResetManager.resetAllUserSessions, returnsNormally);
    });
  });
}
