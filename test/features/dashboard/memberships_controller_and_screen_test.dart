import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/memberships_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/memberships_screen.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  group('MembershipsController Unit Tests', () {
    late MembershipsController controller;

    setUp(() {
      Get.reset();
      controller = MembershipsController(initialChannelId: 'channel_test_123');
    });

    test('initial values and default reactive properties are correct', () {
      expect(controller.channelId, equals('channel_test_123'));
      expect(controller.selectedTab.value, equals(0));
      expect(controller.selectedTierFilter.value, equals('all'));
      expect(controller.isLoadingTiers.value, isTrue);
      expect(controller.isSaving.value, isFalse);
    });

    test('setChannelId updates channel and clears active state', () {
      controller.setChannelId('channel_new_456');
      expect(controller.channelId, equals('channel_new_456'));
    });

    test('selectedTab transitions between Tiers, Members, and Analytics', () {
      controller.selectedTab.value = 1;
      expect(controller.selectedTab.value, equals(1));
      controller.selectedTab.value = 2;
      expect(controller.selectedTab.value, equals(2));
      controller.selectedTab.value = 0;
      expect(controller.selectedTab.value, equals(0));
    });

    test('filteredMembers filters by selected tier', () {
      final m1 = ChannelMember(
        userId: 'u1',
        userName: 'Alice',
        userAvatarUrl: '',
        tierId: 'tier_bronze',
        tierName: 'Bronze Supporter',
        price: 1.99,
        joinedAt: DateTime(2026, 1, 15),
      );
      final m2 = ChannelMember(
        userId: 'u2',
        userName: 'Bob',
        userAvatarUrl: '',
        tierId: 'tier_silver',
        tierName: 'Silver VIP',
        price: 4.99,
        joinedAt: DateTime(2026, 2, 15),
      );

      controller.members.assignAll([m1, m2]);
      expect(controller.filteredMembers.length, equals(2));

      controller.selectedTierFilter.value = 'tier_bronze';
      expect(controller.filteredMembers.length, equals(1));
      expect(controller.filteredMembers.first.userName, equals('Alice'));

      controller.selectedTierFilter.value = 'tier_silver';
      expect(controller.filteredMembers.length, equals(1));
      expect(controller.filteredMembers.first.userName, equals('Bob'));

      controller.selectedTierFilter.value = 'all';
      expect(controller.filteredMembers.length, equals(2));
    });

    test('starterBundles are properly loaded and accessible', () {
      expect(MembershipsController.starterBundles.isNotEmpty, isTrue);
      final bundle = MembershipsController.starterBundles.first;
      expect(bundle.title.isNotEmpty, isTrue);
      expect(bundle.tiers.isNotEmpty, isTrue);
    });

    test('presetBadgeColors contains valid color mappings', () {
      expect(MembershipsController.presetBadgeColors.isNotEmpty, isTrue);
      expect(MembershipsController.presetBadgeColors.first.containsKey('hex'), isTrue);
      expect(MembershipsController.presetBadgeColors.first.containsKey('color'), isTrue);
    });

    test('totalActiveMembers does not double count member document and tier memberCount aggregate', () {
      final tier = ChannelMembershipTier(
        id: 'tier_supporter',
        name: 'Supporter',
        price: 0.10,
        perks: const ['Perk 1'],
        memberCount: 1, // Tier aggregate counter has 1
      );
      final member = ChannelMember(
        userId: 'u123',
        userName: 'John Doe',
        userAvatarUrl: '',
        tierId: 'tier_supporter',
        tierName: 'Supporter',
        price: 0.10,
        joinedAt: DateTime(2026, 3),
      );

      controller.tiers.assignAll([tier]);
      controller.members.assignAll([member]);

      // Critical assertion: 1 member + 1 tier memberCount MUST NOT equal 2! It must equal 1!
      expect(controller.totalActiveMembers, equals(1));
      expect(controller.monthlyRecurringRevenue, equals(0.10));
    });

    test('totalActiveMembers deduplicates multiple records for the same user', () {
      final m1 = ChannelMember(
        userId: 'u123',
        userName: 'John Doe',
        userAvatarUrl: '',
        tierId: 'tier_1',
        tierName: 'Tier 1',
        price: 0.10,
      );
      final m2 = ChannelMember(
        userId: 'u123',
        userName: 'John Doe Duplicate',
        userAvatarUrl: '',
        tierId: 'tier_2',
        tierName: 'Tier 2',
        price: 0.10,
      );

      controller.members.assignAll([m1, m2]);
      expect(controller.totalActiveMembers, equals(1));
    });

    test('totalActiveMembers falls back to tier memberCount when members list is empty', () {
      final tier1 = ChannelMembershipTier(
        id: 'tier_1',
        name: 'Tier 1',
        price: 5.0,
        perks: const [],
        memberCount: 3,
      );
      final tier2 = ChannelMembershipTier(
        id: 'tier_2',
        name: 'Tier 2',
        price: 10.0,
        perks: const [],
        memberCount: 2,
      );

      controller.members.clear();
      controller.tiers.assignAll([tier1, tier2]);

      expect(controller.totalActiveMembers, equals(5));
      expect(controller.monthlyRecurringRevenue, equals(35.0)); // 3*5 + 2*10 = 35
    });

    test('primaryCurrencySymbol returns correct symbol for INR and USD', () {
      // Defaults to USD symbol
      controller.members.clear();
      controller.tiers.clear();
      expect(controller.primaryCurrencySymbol, equals(r'$'));

      // INR tier
      final inrTier = ChannelMembershipTier(
        id: 'tier_inr',
        name: 'VIP INR',
        price: 100.0,
        perks: const [],
        currency: 'INR',
      );
      controller.tiers.assignAll([inrTier]);
      expect(controller.primaryCurrencySymbol, equals('₹'));

      // Active INR member
      final inrMember = ChannelMember(
        userId: 'u_inr',
        userName: 'Raj',
        userAvatarUrl: '',
        tierId: 'tier_inr',
        tierName: 'VIP INR',
        price: 100.0,
        currency: 'INR',
      );
      controller.members.assignAll([inrMember]);
      expect(controller.primaryCurrencySymbol, equals('₹'));
    });
  });

  group('MembershipsScreen Widget Tests', () {
    setUp(Get.reset);

    testWidgets('MembershipsScreen renders banner, KPIs, sub-tab bar, and empty tiers state', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = Get.put(MembershipsController(initialChannelId: 'test_channel_id'));
      controller.isLoadingTiers.value = false;

      await tester.pumpWidget(
        const GetMaterialApp(
          home: MembershipsScreen(
            channelId: 'test_channel_id',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check AppBar title
      expect(find.text('Channel Memberships & Fan Funding'), findsOneWidget);

      // Check 0% Platform Commission Guarantee Banner
      expect(find.text('0% Platform Commission Guarantee'), findsOneWidget);

      // Check KPI Tiles
      expect(find.text('Active Members'), findsOneWidget);
      expect(find.text('Monthly Fan Income'), findsOneWidget);
      expect(find.text('Active Tiers'), findsOneWidget);
      expect(find.text('Platform Fee Rate'), findsOneWidget);

      // Check Sub-tabs
      expect(find.text('Tiers & Perks'), findsOneWidget);
      expect(find.text('Members & Community'), findsOneWidget);
      expect(find.text('Analytics & Payouts'), findsOneWidget);

      // Check Empty Tiers View (default state when no tiers)
      expect(find.text('No Membership Tiers Created Yet'), findsOneWidget);
      expect(find.text('Setup Default Starter Tiers'), findsOneWidget);
      expect(find.text('Create Custom Tier'), findsOneWidget);
    });

    testWidgets('Tapping sub-tab bar switches between views', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = Get.put(MembershipsController(initialChannelId: 'test_channel_id'));
      controller.isLoadingTiers.value = false;

      await tester.pumpWidget(
        const GetMaterialApp(
          home: MembershipsScreen(
            channelId: 'test_channel_id',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Members & Community tab
      await tester.tap(find.text('Members & Community'));
      await tester.pumpAndSettle();

      expect(find.text('Subscribed Channel Members'), findsOneWidget);
      expect(find.text('No Members Subscribed Yet'), findsOneWidget);

      // Tap Analytics & Payouts tab
      await tester.tap(find.text('Analytics & Payouts'));
      await tester.pumpAndSettle();

      expect(find.text('Fan Funding & Revenue Projections'), findsOneWidget);
      expect(find.text('Creator Payout Terms'), findsOneWidget);
      expect(find.text('100% TO CREATOR'), findsOneWidget);
    });
  });
}
