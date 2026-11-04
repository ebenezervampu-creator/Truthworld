import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_subscription_controller.dart';
import 'package:truthworld/features/channel/presentation/views/channel/details/channel_banner_widget.dart';
import 'package:truthworld/features/channel/presentation/views/channel/details/channel_header_widget.dart';
import 'package:truthworld/features/channel/presentation/views/channel/details/channel_video_grid.dart';
import 'package:truthworld/features/video/data/models/video.dart';

import '../../test_helpers/mock_firebase.dart';

class MockChannelSubscriptionController extends ChannelSubscriptionController {
  @override
  void listenSubscription(String channelId) {}

  @override
  void listenMembership(String channelId) {}

  @override
  void listenMembershipTiers(String channelId) {}

  @override
  void fetchSubscriberCount(String channelId) {}
}

class TestChannelController extends ChannelController {
  bool overrideIsOwner = false;

  TestChannelController(MockChannelSubscriptionController mockSub) {
    subController = mockSub;
  }

  @override
  bool get isOwnerOfCurrentChannel => overrideIsOwner;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await setupMockFirebase();
  });

  late MockChannelSubscriptionController mockSub;
  late TestChannelController channelController;

  setUp(() {
    Get.reset();
    Get.testMode = true;
    if (!Get.isRegistered<AuthService>()) {
      Get.put<AuthService>(AuthService(), permanent: true);
    }
    if (!Get.isRegistered<ConnectivityService>()) {
      Get.put<ConnectivityService>(ConnectivityService(), permanent: true);
    }
    mockSub = MockChannelSubscriptionController();
    Get.put<ChannelSubscriptionController>(mockSub);
    channelController = TestChannelController(mockSub);
    Get.put<ChannelController>(channelController);
  });

  tearDown(Get.reset);

  final dummyChannel = Channel(
    id: 'ch_test_1',
    name: 'TruthWorld Official',
    nameLowercase: 'truthworld official',
    handle: '@truthworld',
    handleLowercase: '@truthworld',
    description: 'This is a long description designed to test expandable description behavior on mobile viewports.',
    avatarUrl: 'https://example.com/avatar.png',
    bannerUrl: 'https://example.com/banner.png',
    ownerId: 'owner_user_123',
    createdAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
    subscriberCount: 1500,
    videoCount: 42,
    hasMemberships: false,
    isMonetized: false,
  );

  testWidgets('Viewer sees Subscribe and Share buttons, but not Manage Videos',
      (tester) async {
    channelController.selectedChannel.value = dummyChannel;

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: ChannelHeaderWidget(
            channel: dummyChannel,
            controller: channelController,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Viewer should see Subscribe and Share
    expect(find.text('Subscribe'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);

    // Viewer should not see owner-exclusive Manage videos or Analytics
    expect(find.text('Manage videos'), findsNothing);
    expect(find.text('Analytics'), findsNothing);
  });

  testWidgets('Channel owner sees Manage videos and Analytics, but not Subscribe',
      (tester) async {
    channelController.selectedChannel.value = dummyChannel;
    channelController.overrideIsOwner = true;

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: ChannelHeaderWidget(
            channel: dummyChannel,
            controller: channelController,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Owner should see Manage videos, Analytics, and Share
    expect(find.text('Manage videos'), findsOneWidget);
    expect(find.text('Analytics'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);

    // Owner should never see Subscribe
    expect(find.text('Subscribe'), findsNothing);
  });

  testWidgets('ChannelBannerWidget always renders a back navigation button',
      (tester) async {
    channelController.selectedChannel.value = dummyChannel;

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: ChannelBannerWidget(
            channel: dummyChannel,
            controller: channelController,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify Back navigation IconButton is present
    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
  });

  testWidgets('ChannelVideoListCard renders 3-dots More options button',
      (tester) async {
    final testVideo = Video(
      id: 'v_123',
      title: 'Breaking Truth Investigation',
      description: 'A deep investigation into facts.',
      thumbnailUrl: 'https://example.com/thumb.jpg',
      ownerId: dummyChannel.ownerId,
      channelId: dummyChannel.channelId,
      channelName: dummyChannel.channelName,
      category: 'News',
      tags: const ['news', 'truth'],
      duration: '10:24',
      views: 12500,
    );

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: ChannelVideoListCard(video: testVideo),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify 3-dots more options action button is present on the video card
    expect(find.byTooltip('More options'), findsOneWidget);
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
  });
}
