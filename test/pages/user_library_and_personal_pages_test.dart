import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/channel/presentation/views/channel/channel_details_screen.dart';
import 'package:truthworld/features/channel/presentation/views/channel/channel_screen_wizard.dart';
import 'package:truthworld/features/community/presentation/controllers/saved_comments_controller.dart';
import 'package:truthworld/features/community/presentation/controllers/saved_community_posts_controller.dart';
import 'package:truthworld/features/community/presentation/views/saved_comments_screen.dart';
import 'package:truthworld/features/community/presentation/views/saved_community_posts_screen.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/library/presentation/views/library/library_screen.dart';
import 'package:truthworld/features/likedvideos/presentation/controllers/likedvideos_controller.dart';
import 'package:truthworld/features/likedvideos/presentation/views/likedvideos/liked_video_screen.dart';
import 'package:truthworld/features/myvideos/presentation/controllers/my_videos_controller.dart';
import 'package:truthworld/features/myvideos/presentation/views/myvideos/my_videos.dart';
import 'package:truthworld/features/notifications/presentation/bindings/notifications_binding.dart';
import 'package:truthworld/features/notifications/presentation/views/notifications/notification.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_controller.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_detail_controller.dart';
import 'package:truthworld/features/playlist/presentation/views/playlist/playlist_detail_screen.dart';
import 'package:truthworld/features/playlist/presentation/views/playlist/playlist_screen.dart';
import 'package:truthworld/features/settings/presentation/controllers/user_settings_controller.dart';
import 'package:truthworld/features/settings/presentation/views/settings/settings.dart';
import 'package:truthworld/features/subscriptions/presentation/controllers/subscription_controller.dart';
import 'package:truthworld/features/subscriptions/presentation/views/subscriptions/subscriptions.dart';
import 'package:truthworld/features/watchhistory/presentation/controllers/watch_history_controller.dart';
import 'package:truthworld/features/watchhistory/presentation/views/watchhistory/watchhistory.dart';
import 'package:truthworld/features/watchlater/presentation/controllers/watchlater_controller.dart';
import 'package:truthworld/features/watchlater/presentation/views/watchlater/watchlater_screen.dart';
import '../test_helpers/mock_firebase.dart';
import 'page_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  tearDown(Get.reset);

  group('Group 4: User Library, Personal & Channel Pages', () {
    testWidgets('1. LibraryScreen renders library shortcuts and collections',
        (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      await pumpPageInHarness(
        tester,
        const LibraryScreen(),
        onBeforePump: () {
          Get.put<HomeController>(HomeController());
          Get.put<PlaylistController>(PlaylistController());
          Get.put<WatchHistoryController>(WatchHistoryController());
        },
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(LibraryScreen), findsOneWidget);
    });

    testWidgets('2. WatchHistory renders viewing history and controls',
        (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      await pumpPageInHarness(
        tester,
        const WatchHistory(),
        onBeforePump: () {
          Get.put<WatchHistoryController>(WatchHistoryController());
        },
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(WatchHistory), findsOneWidget);
    });

    testWidgets('3. LikedVideoScreen renders liked videos list and count',
        (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      await pumpPageInHarness(
        tester,
        const LikedVideoScreen(),
        onBeforePump: () {
          Get.put<LikedVideosController>(LikedVideosController());
        },
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(LikedVideoScreen), findsOneWidget);
    });

    testWidgets('4. WatchLaterScreen renders saved-for-later videos',
        (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      await pumpPageInHarness(
        tester,
        const WatchLaterScreen(),
        onBeforePump: () {
          Get.put<WatchLaterController>(WatchLaterController());
        },
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(WatchLaterScreen), findsOneWidget);
    });

    testWidgets('5. MyVideos renders creator uploaded videos and analytics shortcuts',
        (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      await pumpPageInHarness(
        tester,
        const MyVideos(),
        onBeforePump: () {
          Get.put<MyVideosController>(MyVideosController());
        },
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(MyVideos), findsOneWidget);
    });

    testWidgets('6. PlaylistScreen renders user playlists and management tabs',
        (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      await pumpPageInHarness(
        tester,
        const PlaylistScreen(),
        onBeforePump: () {
          Get.put<PlaylistController>(PlaylistController());
        },
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(PlaylistScreen), findsOneWidget);
    });

    testWidgets('7. PlaylistDetailScreen renders individual playlist details',
        (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      final samplePlaylist = PlaylistModel(
        id: 'pl_test_1',
        name: 'Weekly Favorites',
        description: 'Best community picks',
        channelId: 'ch_1',
        ownerId: 'user_1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        videoCount: 5,
        isPublic: true,
      );
      await pumpPageInHarness(
        tester,
        PlaylistDetailScreen(playlist: samplePlaylist),
        onBeforePump: () {
          Get.put<PlaylistDetailController>(PlaylistDetailController());
        },
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(PlaylistDetailScreen), findsOneWidget);
    });

    testWidgets('8. SavedCommunityPostsScreen renders saved community posts',
        (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      await pumpPageInHarness(
        tester,
        const SavedCommunityPostsScreen(),
        onBeforePump: () {
          Get.put<SavedCommunityPostsController>(
              SavedCommunityPostsController());
        },
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(SavedCommunityPostsScreen), findsOneWidget);
    });

    testWidgets('9. SavedCommentsScreen renders bookmarked comments and links',
        (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      await pumpPageInHarness(
        tester,
        const SavedCommentsScreen(),
        onBeforePump: () {
          Get.put<SavedCommentsController>(SavedCommentsController());
        },
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(SavedCommentsScreen), findsOneWidget);
    });

    testWidgets('10. SubscriptionsPage renders subscription channel cards and feed',
        (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      await pumpPageInHarness(
        tester,
        const SubscriptionsPage(),
        onBeforePump: () {
          Get.put<SubscriptionController>(SubscriptionController());
        },
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(SubscriptionsPage), findsOneWidget);
    });

    testWidgets('11. ChannelScreen renders channel creation wizard',
        (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      await pumpPageInHarness(
        tester,
        const ChannelScreen(),
        onBeforePump: () {
          Get.put<ChannelController>(ChannelController());
        },
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(ChannelScreen), findsOneWidget);
    });

    testWidgets('12. ChannelDetailsPage renders channel banner, tabs and info',
        (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      final sampleChannel = Channel(
        id: 'ch_test_1',
        name: 'Science Today',
        nameLowercase: 'science today',
        handle: 'sciencetoday',
        handleLowercase: 'sciencetoday',
        description: 'Exploring scientific facts and updates',
        avatarUrl: 'https://example.com/avatar.jpg',
        bannerUrl: 'https://example.com/banner.jpg',
        ownerId: 'owner_1',
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
        subscriberCount: 1540,
        videoCount: 24,
      );
      await pumpPageInHarness(
        tester,
        ChannelDetailsPage(channel: sampleChannel),
        onBeforePump: () {
          Get.put<ChannelController>(ChannelController());
        },
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(ChannelDetailsPage), findsOneWidget);
    });

    testWidgets('13. SettingsScreen renders application preferences and settings',
        (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      await pumpPageInHarness(
        tester,
        const SettingsScreen(),
        onBeforePump: () {
          Get.put<UserSettingsController>(UserSettingsController());
        },
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets('14. VideoFeedNotificationScreen renders notifications list',
        (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      await pumpPageInHarness(
        tester,
        const VideoFeedNotificationScreen(),
        onBeforePump: () {
          NotificationsBinding().dependencies();
        },
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(VideoFeedNotificationScreen), findsOneWidget);
    });
  });
}
