import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/create_tier_controller.dart';
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
        price: 2.0,
        joinedAt: DateTime(2026, 1, 15),
      );
      final m2 = ChannelMember(
        userId: 'u2',
        userName: 'Bob',
        userAvatarUrl: '',
        tierId: 'tier_silver',
        tierName: 'Silver VIP',
        price: 5.0,
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
        price: 1.0,
        perks: const ['Perk 1'],
        memberCount: 1, // Tier aggregate counter has 1
      );
      final member = ChannelMember(
        userId: 'u123',
        userName: 'John Doe',
        userAvatarUrl: '',
        tierId: 'tier_supporter',
        tierName: 'Supporter',
        price: 1.0,
        joinedAt: DateTime(2026, 3),
      );

      controller.tiers.assignAll([tier]);
      controller.members.assignAll([member]);

      // Critical assertion: 1 member + 1 tier memberCount MUST NOT equal 2! It must equal 1!
      expect(controller.totalActiveMembers, equals(1));
      expect(controller.monthlyRecurringRevenue, equals(1.0));
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
      expect(controller.primaryCurrencySymbol, equals('\u20B9'));

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
      expect(controller.primaryCurrencySymbol, equals('\u20B9'));
    });

    test('noAdsForMembers applies 70/30 MRR split when enabled and hybrid split when disabled', () {
      final tier = ChannelMembershipTier(
        id: 'tier_1',
        name: 'Tier 1',
        price: 100.0,
        perks: const [],
        memberCount: 1,
      );
      controller.members.clear();
      controller.tiers.assignAll([tier]);

      // When false (Standard Channel: 90% creator / 10% platform fee)
      controller.isCustomChannel.value = false;
      controller.noAdsForMembers.value = false;
      expect(controller.monthlyRecurringRevenue, equals(100.0));
      expect(controller.creatorMonthlyRecurringRevenue, equals(90.0));
      expect(controller.platformMonthlyRecurringRevenue, equals(10.0));

      // When Custom Channel: 100% creator / 0% platform fee
      controller.isCustomChannel.value = true;
      expect(controller.creatorMonthlyRecurringRevenue, equals(100.0));
      expect(controller.platformMonthlyRecurringRevenue, equals(0.0));

      // When true (Member Ad-Free active -> 70% creator / 30% platform)
      controller.isCustomChannel.value = false;
      controller.noAdsForMembers.value = true;
      expect(controller.monthlyRecurringRevenue, equals(100.0));
      expect(controller.creatorMonthlyRecurringRevenue, equals(70.0));
      expect(controller.platformMonthlyRecurringRevenue, equals(30.0));
    });

    test('ChannelMembershipTier hasPremiumBundle and platform cut calculations work correctly', () {
      final standardTier = ChannelMembershipTier(
        id: 'tier_standard',
        name: 'Standard Tier',
        price: 5.0,
        perks: const ['VIP Discord Access', 'Exclusive Badges'],
      );
      expect(standardTier.includesPremiumBundle, isFalse);
      expect(standardTier.platformCutPercentage, equals(0.10));
      expect(standardTier.creatorSharePercentage, equals(0.90));
      expect(standardTier.platformCutForChannel(isCustom: true), equals(0.0));
      expect(standardTier.creatorShareForChannel(isCustom: true), equals(1.0));

      final premiumTier = ChannelMembershipTier(
        id: 'tier_premium',
        name: 'Premium Tier',
        price: 10.0,
        perks: const [ChannelMembershipTier.premiumBundlePerkTitle],
        hasPremiumBundle: true,
      );
      expect(premiumTier.includesPremiumBundle, isTrue);
      expect(premiumTier.platformCutPercentage, equals(0.30));
      expect(premiumTier.creatorSharePercentage, equals(0.70));

      final copy = standardTier.copyWith(hasPremiumBundle: true);
      expect(copy.includesPremiumBundle, isTrue);
      expect(copy.platformCutPercentage, equals(0.30));
      expect(copy.creatorSharePercentage, equals(0.70));

      // Recommended Bundle Pricing Checks ($5 USD / â‚¹150 INR)
      expect(ChannelMembershipTier.recommendedBundlePriceUSD, equals(5.0));
      expect(ChannelMembershipTier.recommendedBundlePriceINR, equals(150.0));
      expect(ChannelMembershipTier.recommendedBundlePriceFor('USD'), equals(5.0));
      expect(ChannelMembershipTier.recommendedBundlePriceFor('INR'), equals(150.0));
      expect(ChannelMembershipTier.recommendedBundlePriceLabel('USD'), equals(r'$5'));
      expect(ChannelMembershipTier.recommendedBundlePriceLabel('INR'), equals('\u20B9150'));

      final cheapUsdBundleTier = ChannelMembershipTier(
        id: 'tier_cheap_usd',
        name: 'Cheap Bundle',
        price: 2.0,
        perks: const [ChannelMembershipTier.premiumBundlePerkTitle],
        hasPremiumBundle: true,
      );
      expect(cheapUsdBundleTier.isBelowRecommendedBundlePrice, isTrue);

      final healthyUsdBundleTier = ChannelMembershipTier(
        id: 'tier_healthy_usd',
        name: 'Healthy Bundle',
        price: 5.0,
        perks: const [ChannelMembershipTier.premiumBundlePerkTitle],
        hasPremiumBundle: true,
      );
      expect(healthyUsdBundleTier.isBelowRecommendedBundlePrice, isFalse);

      final cheapInrBundleTier = ChannelMembershipTier(
        id: 'tier_cheap_inr',
        name: 'Cheap INR Bundle',
        price: 50.0,
        currency: 'INR',
        perks: const [ChannelMembershipTier.premiumBundlePerkTitle],
        hasPremiumBundle: true,
      );
      expect(cheapInrBundleTier.isBelowRecommendedBundlePrice, isTrue);

      final healthyInrBundleTier = ChannelMembershipTier(
        id: 'tier_healthy_inr',
        name: 'Healthy INR Bundle',
        price: 150.0,
        currency: 'INR',
        perks: const [ChannelMembershipTier.premiumBundlePerkTitle],
        hasPremiumBundle: true,
      );
      expect(healthyInrBundleTier.isBelowRecommendedBundlePrice, isFalse);
    });

    test('MRR calculates 70% creator / 30% platform for tiers with Premium Bundle and hybrid split for standard tiers', () {
      final standardTier = ChannelMembershipTier(
        id: 't_standard',
        name: 'Standard',
        price: 10.0,
        perks: const ['Standard Perk'],
        memberCount: 1,
      );
      final premiumTier = ChannelMembershipTier(
        id: 't_premium',
        name: 'Premium',
        price: 20.0,
        perks: const [ChannelMembershipTier.premiumBundlePerkTitle],
        memberCount: 1,
        hasPremiumBundle: true,
      );

      controller.members.clear();
      controller.tiers.assignAll([standardTier, premiumTier]);

      // Standard Channel: 90% creator / 10% platform on standard tier
      controller.isCustomChannel.value = false;
      // Total gross: 10 + 20 = 30
      expect(controller.monthlyRecurringRevenue, equals(30.0));
      // Creator net: (10 * 0.90) + (20 * 0.70) = 9 + 14 = 23.0
      expect(controller.creatorMonthlyRecurringRevenue, equals(23.0));
      // Platform cut: 30 - 23 = 7.0 ($1 on standard tier + $6 on premium tier)
      expect(controller.platformMonthlyRecurringRevenue, equals(7.0));

      // Custom Channel: 100% creator / 0% platform on standard tier
      controller.isCustomChannel.value = true;
      expect(controller.creatorMonthlyRecurringRevenue, equals(24.0));
      expect(controller.platformMonthlyRecurringRevenue, equals(6.0));
    });

    test('popularPerkSuggestions and starter bundles include ad-free and 4K Ultra HD perks', () {
      expect(
        MembershipsController.popularPerkSuggestions,
        contains('No ads while watching this channel'),
      );
      expect(
        MembershipsController.popularPerkSuggestions,
        contains('4K Ultra HD (2160p) video streaming'),
      );
      expect(
        MembershipsController.popularPerkSuggestions,
        contains('Channel Premium: Ad-free & 4K streaming'),
      );
      final allStarterTiers =
          MembershipsController.starterBundles.expand((b) => b.tiers).toList();
      final silverTier = allStarterTiers.firstWhere(
        (t) => t.id == 'tier_silver',
      );
      expect(
        silverTier.perks,
        contains('No ads while watching this channel'),
      );
      expect(
        silverTier.perks,
        contains('4K Ultra HD (2160p) video streaming'),
      );
      final fanClubTier = allStarterTiers.firstWhere(
        (t) => t.id == 'tier_fan_club',
      );
      expect(
        fanClubTier.perks,
        contains('Channel Premium: Ad-free & 4K Ultra HD streaming'),
      );
    });

    test('createTier blocks creating 4th tier when channel already has 3 tiers', () async {
      controller.tiers.assignAll([
        ChannelMembershipTier(id: 't1', name: 'T1', price: 2.0, perks: const ['P1']),
        ChannelMembershipTier(id: 't2', name: 'T2', price: 5.0, perks: const ['P2']),
        ChannelMembershipTier(id: 't3', name: 'T3', price: 10.0, perks: const ['P3']),
      ]);

      final created = await controller.createTier(
        name: 'T4',
        price: 15.0,
        perks: const ['P4'],
      );

      expect(created, isFalse);
      expect(controller.tiers.length, equals(3));
    });

    test('duplicateTier blocks duplicating when channel already has 3 tiers', () async {
      final t1 = ChannelMembershipTier(id: 't1', name: 'T1', price: 2.0, perks: const ['P1']);
      controller.tiers.assignAll([
        t1,
        ChannelMembershipTier(id: 't2', name: 'T2', price: 5.0, perks: const ['P2']),
        ChannelMembershipTier(id: 't3', name: 'T3', price: 10.0, perks: const ['P3']),
      ]);

      await controller.duplicateTier(t1);

      expect(controller.tiers.length, equals(3));
    });

    test('reactive tier limit getters report accurate capacity and thresholds', () {
      controller.tiers.clear();

      expect(controller.tiers.length, equals(0));
      expect(controller.hasReachedMaxTiers, isFalse);
      expect(controller.remainingTierSlots, equals(3));
      expect(controller.tierLimitLabel, equals('0/3 tiers'));

      controller.tiers.add(ChannelMembershipTier(
        id: 't1',
        name: 'Tier 1',
        price: 2.0,
        perks: const ['Perk 1'],
      ));
      expect(controller.hasReachedMaxTiers, isFalse);
      expect(controller.remainingTierSlots, equals(2));
      expect(controller.tierLimitLabel, equals('1/3 tiers'));

      controller.tiers.add(ChannelMembershipTier(
        id: 't2',
        name: 'Tier 2',
        price: 5.0,
        perks: const ['Perk 2'],
      ));
      expect(controller.hasReachedMaxTiers, isFalse);
      expect(controller.remainingTierSlots, equals(1));
      expect(controller.tierLimitLabel, equals('2/3 tiers'));

      controller.tiers.add(ChannelMembershipTier(
        id: 't3',
        name: 'Tier 3',
        price: 10.0,
        perks: const ['Perk 3'],
      ));
      expect(controller.hasReachedMaxTiers, isTrue);
      expect(controller.remainingTierSlots, equals(0));
      expect(controller.tierLimitLabel, equals('3/3 tiers'));
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

      // Check Hybrid Model Standard Channel Banner
      expect(find.text('Standard Channel: 90% Creator Revenue (10% Platform Fee)'), findsOneWidget);

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
      expect(find.text('90% TO CREATOR (10% FEE)'), findsOneWidget);
    });

    testWidgets('Displays 3/3 Tiers (Max) badge and 3/3 Tiers button when channel has 3 tiers', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = Get.put(MembershipsController(initialChannelId: 'test_channel_id'));
      controller.isLoadingTiers.value = false;
      controller.tiers.assignAll([
        ChannelMembershipTier(id: 't1', name: 'Bronze', price: 2.0, perks: const ['P1']),
        ChannelMembershipTier(id: 't2', name: 'Silver', price: 5.0, perks: const ['P2']),
        ChannelMembershipTier(id: 't3', name: 'Gold', price: 10.0, perks: const ['P3']),
      ]);

      await tester.pumpWidget(
        const GetMaterialApp(
          home: MembershipsScreen(
            channelId: 'test_channel_id',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check header capacity badge
      expect(find.text('3/3 Tiers (Max)'), findsOneWidget);

      // Check buttons reflecting 3/3 capacity
      expect(find.text('3/3 Tiers'), findsWidgets);
    });

    testWidgets('MembershipsScreen renders cleanly on mobile screen (360x780) with zero overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = Get.put(MembershipsController(initialChannelId: 'test_channel_mobile'));
      controller.isLoadingTiers.value = false;

      // Add a tier
      final tier = ChannelMembershipTier(
        id: 'tier_supporter',
        name: 'Supporter VIP',
        price: 5.0,
        perks: const [
          ChannelMembershipTier.premiumBundlePerkTitle,
          'Exclusive Discord VIP Role',
        ],
        hasPremiumBundle: true,
      );
      controller.tiers.assignAll([tier]);

      // Add members with avatars
      final m1 = ChannelMember(
        userId: 'm1',
        userName: 'Elena Rostova',
        userAvatarUrl: 'https://example.com/avatar1.jpg',
        tierId: 'tier_supporter',
        tierName: 'Supporter VIP',
        price: 5.0,
        joinedAt: DateTime(2026, 2, 10),
      );
      final m2 = ChannelMember(
        userId: 'm2',
        userName: 'David Miller',
        userAvatarUrl: '',
        tierId: 'tier_supporter',
        tierName: 'Supporter VIP',
        price: 5.0,
        joinedAt: DateTime(2026, 3),
      );
      controller.members.assignAll([m1, m2]);

      await tester.pumpWidget(
        const GetMaterialApp(
          home: MembershipsScreen(
            channelId: 'test_channel_mobile',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure no flutter overflow exceptions occurred
      expect(tester.takeException(), isNull);

      // Verify mobile responsive header title
      expect(find.text('Memberships'), findsOneWidget);

      // Verify KPIs and avatar facepile
      expect(find.text('Active Members'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Monthly Fan Income'), findsOneWidget);
      expect(find.text('Active Tiers'), findsOneWidget);
      expect(find.text('Platform Fee Rate'), findsOneWidget);

      // Verify Tier card renders with member count and perks without overflow
      expect(find.text('Supporter VIP'), findsWidgets);
      expect(find.text('70% Net (30% Cut)'), findsWidgets);

      // Switch to Members & Community tab on mobile
      await tester.tap(find.text('Members & Community'));
      await tester.pumpAndSettle();

      // Ensure no overflow
      expect(tester.takeException(), isNull);
      expect(find.text('Subscribed Channel Members'), findsOneWidget);
      expect(find.text('Elena Rostova'), findsOneWidget);
      expect(find.text('David Miller'), findsOneWidget);

      // Switch to Analytics & Payouts tab on mobile
      await tester.tap(find.text('Analytics & Payouts'));
      await tester.pumpAndSettle();

      // Ensure no overflow
      expect(tester.takeException(), isNull);
      expect(find.text('Creator Payout Terms'), findsOneWidget);
    });
  });

  group('CreateTierController Unit Tests', () {
    late MembershipsController membershipsController;
    late CreateTierController createTierController;

    setUp(() {
      Get.reset();
      membershipsController = MembershipsController(initialChannelId: '');
      createTierController = CreateTierController(
        membershipsController: membershipsController,
      );
      createTierController.onInit();
    });

    tearDown(() {
      createTierController.onClose();
    });

    test('Initial default state is correct for new tier', () {
      expect(createTierController.isEditing, isFalse);
      expect(createTierController.selectedCurrency.value, equals('USD'));
      expect(createTierController.priceRx.value, equals(5.0));
      expect(createTierController.priceController.text, equals('5'));
      expect(createTierController.hasPremiumBundle.value, isFalse);
      expect(createTierController.activePerks.isNotEmpty, isTrue);
      expect(createTierController.selectedColorHex.value, equals('0xFF10B981'));
    });

    test('Switching currency adjusts price to currency bounds', () {
      createTierController.selectCurrency('INR');
      expect(createTierController.selectedCurrency.value, equals('INR'));
      expect(createTierController.priceRx.value, greaterThanOrEqualTo(50.0));

      createTierController.selectCurrency('USD');
      expect(createTierController.selectedCurrency.value, equals('USD'));
      expect(createTierController.priceRx.value, greaterThanOrEqualTo(1.0));
    });

    test('Toggling Premium Bundle adjusts recommended minimum price', () {
      createTierController.selectCurrency('USD');
      createTierController.selectPrice(2.0);

      createTierController.togglePremiumBundle(true);
      expect(createTierController.hasPremiumBundle.value, isTrue);
      expect(createTierController.priceRx.value, greaterThanOrEqualTo(5.0));
      expect(
        createTierController.activePerks.contains(ChannelMembershipTier.premiumBundlePerkTitle),
        isTrue,
      );

      createTierController.togglePremiumBundle(false);
      expect(createTierController.hasPremiumBundle.value, isFalse);
      expect(
        createTierController.activePerks.contains(ChannelMembershipTier.premiumBundlePerkTitle),
        isFalse,
      );
    });

    test('Adding and removing custom perks works correctly', () {
      createTierController.addCustomPerk('Custom VIP Discord Channel');
      expect(createTierController.activePerks.contains('Custom VIP Discord Channel'), isTrue);

      createTierController.removePerk('Custom VIP Discord Channel');
      expect(createTierController.activePerks.contains('Custom VIP Discord Channel'), isFalse);
    });

    test('Color selection updates selectedColorHex', () {
      createTierController.selectColor('0xFF8B5CF6');
      expect(createTierController.selectedColorHex.value, equals('0xFF8B5CF6'));
    });
  });

  group('CreateOrEditTierPage Responsive Widget Tests', () {
    tearDown(Get.reset);

    testWidgets('Renders cleanly on mobile device (360x780) with zero overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final membershipsController = Get.put(MembershipsController(initialChannelId: ''));
      membershipsController.isLoadingTiers.value = false;

      await tester.pumpWidget(
        GetMaterialApp(
          home: CreateOrEditTierPage(
            controller: membershipsController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify zero overflow exceptions
      expect(tester.takeException(), isNull);

      // Verify AppBar title and tier capacity indicator
      expect(find.text('Create Membership Tier'), findsOneWidget);
      expect(find.text('1/3 Tiers'), findsOneWidget);

      // Verify Form inputs and sections are present
      expect(find.text('TIER NAME'), findsOneWidget);
      expect(find.text('BADGE ACCENT COLOR'), findsOneWidget);
      expect(find.text('Monthly Subscription Price'), findsOneWidget);
      expect(find.text('Channel Premium Bundle'), findsOneWidget);
      expect(find.text('YouTube-Grade Loyalty Badges'), findsOneWidget);
      expect(find.text('Tier Perks & Benefits'), findsOneWidget);
      expect(find.text('LIVE FAN PREVIEW'), findsOneWidget);

      // Verify Quick price pills render without overflow
      expect(find.text(r'$1'), findsWidgets);
      expect(find.text(r'$5'), findsWidgets);
      expect(find.text(r'$25'), findsWidgets);

      // Verify bottom action buttons render
      expect(find.text('Cancel'), findsWidgets);
      expect(find.text('Create Tier'), findsWidgets);
    });

    testWidgets('Renders cleanly on desktop device (1280x900) in 2-column layout', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final membershipsController = Get.put(MembershipsController(initialChannelId: ''));
      membershipsController.isLoadingTiers.value = false;

      await tester.pumpWidget(
        GetMaterialApp(
          home: CreateOrEditTierPage(
            controller: membershipsController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify zero overflow exceptions
      expect(tester.takeException(), isNull);

      // Verify 2-column elements
      expect(find.text('Create Membership Tier'), findsOneWidget);
      expect(find.text('Configure New Tier'), findsOneWidget);
      expect(find.text('LIVE FAN PREVIEW'), findsOneWidget);
      expect(find.text('INCLUDED PERKS'), findsOneWidget);
      expect(find.text('Join Tier'), findsOneWidget);

      // Test typing a tier name updates live fan preview
      await tester.enterText(find.byType(TextField).first, 'Master Patron');
      await tester.pump();

      expect(find.text('Master Patron'), findsWidgets);
    });
  });
}
