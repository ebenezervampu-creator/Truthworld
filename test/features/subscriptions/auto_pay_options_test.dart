import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/cashfree_service.dart';
import 'package:truthworld/core/services/currency_localization_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_membership_join_controller.dart';
import 'package:truthworld/features/channel/presentation/views/channel/monetization/channel_monetization_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/memberships_controller.dart';
import 'package:truthworld/features/premium/presentation/controllers/premium_controller.dart';
import 'package:truthworld/features/premium/presentation/views/plans/premium_checkout_action_bar.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final dummyChannel = Channel(
    id: 'test_channel_123',
    name: 'Truth Investigates',
    nameLowercase: 'truth investigates',
    handle: 'truth_inv',
    handleLowercase: 'truth_inv',
    description: 'Channel description',
    avatarUrl: 'https://example.com/avatar.jpg',
    bannerUrl: 'https://example.com/banner.jpg',
    ownerId: 'owner_123',
    createdAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
    subscriberCount: 500,
    videoCount: 10,
    metrics: ChannelMetricsV2(
      totalViews: 10000,
      totalWatchTimeMinutes: 1200,
      averageRetention: 0.75,
    ),
    adsRevenueTotal: 50.0,
    premiumSubsRevenueTotal: 2.4,
    isVerified: true,
    category: 'News',
    categories: ['News', 'Investigation'],
    language: 'English',
    monetizationTier: MonetizationTier.eligible,
  );

  setUpAll(() async {
    await setupMockFirebase();
    CurrencyLocalizationService.enablePersistentStorage = false;
    CashfreePaymentService.enableNativeGateway = false;
  });

  tearDownAll(() {
    CurrencyLocalizationService.enablePersistentStorage = true;
    CashfreePaymentService.enableNativeGateway = true;
  });

  group('Auto Pay Model Serialization Tests', () {
    test('CustomChannelInfraConfig defaults autoPay to true', () {
      final config = CustomChannelInfraConfig(subscriptionId: 'sub_123');
      expect(config.autoPay, isTrue);

      final map = config.toMap();
      expect(map['autoPay'], isTrue);

      final fromMapDefault = CustomChannelInfraConfig.fromMap(map);
      expect(fromMapDefault.autoPay, isTrue);
    });

    test('CustomChannelInfraConfig preserves autoPay false', () {
      final config = CustomChannelInfraConfig(
        subscriptionId: 'sub_123',
        autoPay: false,
      );
      expect(config.autoPay, isFalse);

      final map = config.toMap();
      expect(map['autoPay'], isFalse);

      final fromMap = CustomChannelInfraConfig.fromMap(map);
      expect(fromMap.autoPay, isFalse);
    });

    test('ChannelMember defaults autoPay to true and serializes correctly', () {
      final member = ChannelMember(
        userId: 'user_456',
        userName: 'Test User',
        userAvatarUrl: 'https://example.com/avatar.png',
        tierId: 'tier_supporter',
        tierName: 'Supporter',
        price: 4.99,
        joinedAt: DateTime(2026),
      );
      expect(member.autoPay, isTrue);

      final map = member.toMap();
      expect(map['autoPay'], isTrue);

      final deserialized = ChannelMember.fromMap(map, 'member_123');
      expect(deserialized.autoPay, isTrue);

      final memberOneTime = ChannelMember(
        userId: 'user_456',
        userName: 'Test User',
        userAvatarUrl: 'https://example.com/avatar.png',
        tierId: 'tier_supporter',
        tierName: 'Supporter',
        price: 4.99,
        joinedAt: DateTime(2026),
        autoPay: false,
      );
      expect(memberOneTime.autoPay, isFalse);

      final mapOneTime = memberOneTime.toMap();
      expect(mapOneTime['autoPay'], isFalse);

      final deserializedOneTime = ChannelMember.fromMap(mapOneTime, 'member_999');
      expect(deserializedOneTime.autoPay, isFalse);
    });
  });

  group('Premium Auto Pay Controller & UI Tests', () {
    late PremiumController controller;

    setUp(() {
      Get.reset();
      Get.put(AuthService());
      controller = Get.put(PremiumController());
    });

    tearDown(Get.reset);

    test('PremiumController isAutoPay defaults to true and toggles accurately', () {
      expect(controller.isAutoPay.value, isTrue);

      controller.toggleAutoPay(false);
      expect(controller.isAutoPay.value, isFalse);

      controller.toggleAutoPay(true);
      expect(controller.isAutoPay.value, isTrue);

      controller.toggleAutoPay();
      expect(controller.isAutoPay.value, isFalse);
    });

    testWidgets('PremiumCheckoutButton renders Auto Pay switch and adjusts labels', (tester) async {
      controller.selectedPlanId.value = 'audio_monthly';
      controller.isAutoPay.value = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PremiumCheckoutButton(controller: controller),
          ),
        ),
      );

      // Verify Auto Pay UI elements
      expect(find.text('Auto Pay'), findsOneWidget);
      expect(find.text('RECOMMENDED'), findsOneWidget);
      expect(find.text('Pay ₹40 with Auto Pay'), findsOneWidget);

      // Toggle off Auto Pay
      controller.toggleAutoPay(false);
      await tester.pumpAndSettle();

      expect(find.text('ONE-TIME'), findsOneWidget);
      expect(find.text('Pay ₹40 (One-Time)'), findsOneWidget);
    });

    test('PremiumController cancelAutoPay updates state gracefully', () async {
      controller.isAutoPay.value = true;
      final result = await controller.cancelAutoPay();
      // Even without active server session, handles gracefully without throwing
      expect(result, isFalse);
    });
  });

  group('Cashfree Subscriptions Gateway Tests', () {
    setUp(() {
      Get.reset();
      CashfreePaymentService.enableNativeGateway = false;
      if (!Get.isRegistered<CashfreePaymentService>()) {
        Get.put(CashfreePaymentService(), permanent: true);
      }
    });

    tearDown(Get.reset);

    test('CashfreePaymentService has subscription verification and cancellation methods', () {
      final service = CashfreePaymentService.to;
      expect(service.verifySubscriptionOnServer, isNotNull);
      expect(service.cancelSubscriptionOnServer, isNotNull);
    });
  });

  group('Channel Membership Join Auto Pay Tests', () {
    late ChannelMembershipJoinController membershipController;

    setUp(() {
      Get.reset();
      membershipController = ChannelMembershipJoinController(channelId: 'test_channel_123');
    });

    tearDown(Get.reset);

    test('ChannelMembershipJoinController isAutoPay defaults to true and toggles', () {
      expect(membershipController.isAutoPay.value, isTrue);

      membershipController.toggleAutoPay(false);
      expect(membershipController.isAutoPay.value, isFalse);

      membershipController.toggleAutoPay(true);
      expect(membershipController.isAutoPay.value, isTrue);

      membershipController.toggleAutoPay();
      expect(membershipController.isAutoPay.value, isFalse);
    });
  });

  group('Channel Monetization Custom Plans Auto Pay Tests', () {
    late ChannelMonetizationController monetizationController;

    setUp(() {
      Get.reset();
      monetizationController = ChannelMonetizationController(initialChannel: dummyChannel);
    });

    tearDown(Get.reset);

    test('ChannelMonetizationController autoPayEnabled defaults to true and toggles', () {
      expect(monetizationController.autoPayEnabled.value, isTrue);

      monetizationController.toggleAutoPay(false);
      expect(monetizationController.autoPayEnabled.value, isFalse);

      monetizationController.toggleAutoPay(true);
      expect(monetizationController.autoPayEnabled.value, isTrue);

      monetizationController.toggleAutoPay();
      expect(monetizationController.autoPayEnabled.value, isFalse);
    });
  });

  group('Channel Wizard Plan Selection Auto Pay Tests', () {
    late ChannelController channelController;

    setUp(() {
      Get.reset();
      Get.put(AuthService());
      channelController = Get.put(ChannelController());
    });

    tearDown(Get.reset);

    test('ChannelController customPlanAutoPay defaults to true and toggles', () {
      expect(channelController.customPlanAutoPay.value, isTrue);

      channelController.customPlanAutoPay.value = false;
      expect(channelController.customPlanAutoPay.value, isFalse);

      channelController.customPlanAutoPay.value = true;
      expect(channelController.customPlanAutoPay.value, isTrue);
    });
  });
}
