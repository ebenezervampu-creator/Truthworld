import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/channel/data/services/channel_memory_cache.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_membership_join_controller.dart';
import 'package:truthworld/features/channel/presentation/views/channel/widgets/channel_membership_join_sheet.dart';
import 'package:truthworld/features/video/presentation/views/comments/premium_comment_input.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  group('Monetized Channel Gating - Memberships & Superchats', () {
    setUp(() {
      Get.reset();
      Get.testMode = true;
      Get.put<AuthService>(AuthService());
      ChannelMemoryCache.clear();
    });

    tearDown(() {
      ChannelMemoryCache.clear();
      Get.reset();
    });

    testWidgets('PremiumCommentInput HIDES dollar icon when channel is NOT monetized', (tester) async {
      AuthService.to.isAuthenticated.value = true;
      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: PremiumCommentInput(
              videoId: 'vid_unmonetized',
              channelId: 'ch_unmonetized',
              videoTitle: 'Test Video',
              isChannelMonetized: false,
              onSubmit: (_, __, ___) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Great video!');
      await tester.pumpAndSettle();

      // Dollar icon (Icons.attach_money) must NOT be shown
      expect(find.byIcon(Icons.attach_money), findsNothing);
      expect(find.byTooltip('Super Thanks / Donate'), findsNothing);
    });

    testWidgets('PremiumCommentInput SHOWS dollar icon when channel is monetized', (tester) async {
      AuthService.to.isAuthenticated.value = true;
      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: PremiumCommentInput(
              videoId: 'vid_monetized',
              channelId: 'ch_monetized',
              videoTitle: 'Test Video',
              isChannelMonetized: true,
              onSubmit: (_, __, ___) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Great video!');
      await tester.pumpAndSettle();

      // Dollar icon (Icons.attach_money) MUST be shown for monetized channels
      expect(find.byIcon(Icons.attach_money), findsOneWidget);
      expect(find.byTooltip('Super Thanks / Donate'), findsOneWidget);
    });

    testWidgets('showSuperThanksModal blocks unmonetized channel from opening modal', (tester) async {
      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    PremiumCommentInput.showSuperThanksModal(
                      context,
                      videoId: 'vid_unmonetized_2',
                      channelId: 'ch_unmonetized_2',
                      isChannelMonetized: false,
                    );
                  },
                  child: const Text('Send Super Thanks'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Send Super Thanks'));
      await tester.pumpAndSettle();

      // Modal bottom sheet should NOT be displayed
      expect(find.text('Send Super Thanks to support the creator'), findsNothing);
      expect(find.text('Buy & Send Super Thanks'), findsNothing);
    });

    test('ChannelMembershipJoinController blocks joining when channel is not monetized', () async {
      final unmonetizedChannel = Channel(
        id: 'ch_unmonetized_join',
        name: 'Unmonetized Channel',
        nameLowercase: 'unmonetized channel',
        handle: '@unmonetized',
        handleLowercase: '@unmonetized',
        description: 'Testing channel',
        avatarUrl: '',
        bannerUrl: '',
        ownerId: 'owner_unmonetized',
        subscriberCount: 50,
        videoCount: 2,
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
        isMonetized: false,
        monetizationTier: MonetizationTier.none,
      );

      final ctrl = ChannelMembershipJoinController(
        channelId: unmonetizedChannel.id,
        channel: unmonetizedChannel,
      );

      // Verify channel is not monetization active
      expect(unmonetizedChannel.isMonetizationActive, isFalse);

      // Attempt to join tier
      await ctrl.joinSelectedTier();

      // Ensure processing does not proceed to payment
      expect(ctrl.isProcessing.value, isFalse);
    });

    testWidgets('ChannelMembershipJoinSheet blocks opening for unmonetized channel', (tester) async {
      final unmonetizedChannel = Channel(
        id: 'ch_unmonetized_sheet',
        name: 'Unmonetized Channel',
        nameLowercase: 'unmonetized channel',
        handle: '@unmonetized',
        handleLowercase: '@unmonetized',
        description: 'Testing channel',
        avatarUrl: '',
        bannerUrl: '',
        ownerId: 'owner_unmonetized',
        subscriberCount: 50,
        videoCount: 2,
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
        isMonetized: false,
        monetizationTier: MonetizationTier.none,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    ChannelMembershipJoinSheet.show(
                      context,
                      channelId: unmonetizedChannel.id,
                      channel: unmonetizedChannel,
                    );
                  },
                  child: const Text('Open Join Sheet'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Join Sheet'));
      await tester.pumpAndSettle();

      // BottomSheet should not open with membership tiers
      expect(find.byType(ChannelMembershipJoinSheet), findsNothing);
    });
  });
}
