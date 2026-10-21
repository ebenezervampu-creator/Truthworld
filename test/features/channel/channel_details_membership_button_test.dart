import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/channel/presentation/views/channel/details/channel_header_widget.dart';
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
  TestChannelController(MockChannelSubscriptionController mockSub) {
    subController = mockSub;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  group('Channel Membership Button Visibility Tests', () {
    late MockChannelSubscriptionController mockSub;
    late TestChannelController testController;

    setUp(() {
      Get.reset();
      Get.put<AuthService>(AuthService());
      mockSub = MockChannelSubscriptionController();
      Get.put<ChannelSubscriptionController>(mockSub);
      testController = TestChannelController(mockSub);
      Get.put<ChannelController>(testController);
    });

    tearDown(Get.reset);

    Channel createTestChannel({bool hasMemberships = false}) {
      return Channel(
        id: 'test_ch_1',
        name: 'Truth Channel',
        nameLowercase: 'truth channel',
        handle: '@truthchannel',
        handleLowercase: '@truthchannel',
        description: 'Test channel description',
        avatarUrl: '',
        bannerUrl: '',
        ownerId: 'owner_1',
        subscriberCount: 1500,
        videoCount: 20,
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
        hasMemberships: hasMemberships,
      );
    }

    testWidgets('Join button is HIDDEN when channel has NO memberships and user is not a member', (tester) async {
      final channel = createTestChannel();
      testController.selectedChannel.value = channel;
      testController.hasChannelMemberships.value = false;
      testController.isChannelMember.value = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChannelHeaderWidget(
              channel: channel,
              controller: testController,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Subscribe button should be present
      expect(find.text('Subscribe'), findsOneWidget);

      // Join button should NOT be present
      expect(find.text('Join'), findsNothing);
      expect(find.text('Joined'), findsNothing);
    });

    testWidgets('Join button IS SHOWN when channel has memberships', (tester) async {
      final channel = createTestChannel(hasMemberships: true);
      testController.selectedChannel.value = channel;
      testController.hasChannelMemberships.value = true;
      testController.isChannelMember.value = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChannelHeaderWidget(
              channel: channel,
              controller: testController,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Subscribe button should be present
      expect(find.text('Subscribe'), findsOneWidget);

      // Join button should be present
      expect(find.text('Join'), findsOneWidget);
    });

    testWidgets('Joined button IS SHOWN when user is an active member even if hasMemberships is currently false', (tester) async {
      final channel = createTestChannel();
      testController.selectedChannel.value = channel;
      testController.hasChannelMemberships.value = false;
      testController.isChannelMember.value = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChannelHeaderWidget(
              channel: channel,
              controller: testController,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Subscribe button should be present
      expect(find.text('Subscribe'), findsOneWidget);

      // Joined button should be present
      expect(find.text('Joined'), findsOneWidget);
    });
  });
}
