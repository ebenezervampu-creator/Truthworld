import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/services/infrastructure_metering_service.dart';
import 'package:truthworld/data/models/channel.dart';

void main() {
  group('InfrastructureMeteringService & Custom Channel Unit Economics', () {
    test('enforces strict 2/3 platform profit and 1/3 infrastructure budget ratios', () {
      expect(InfrastructureMeteringService.platformProfitMarginRatio, closeTo(2.0 / 3.0, 0.0001));
      expect(InfrastructureMeteringService.infraCostBudgetRatio, closeTo(1.0 / 3.0, 0.0001));
      expect(
        InfrastructureMeteringService.platformProfitMarginRatio +
            InfrastructureMeteringService.infraCostBudgetRatio,
        closeTo(1.0, 0.0001),
      );
    });

    test(r'validates Starter tier ($15) mathematical split: $10 profit, $5 infra ($0.25 Firestore/other)', () {
      final starter = InfrastructureMeteringService.availablePlans.firstWhere((p) => p.id == 'starter_15');
      expect(starter.priceUSD, equals(15.0));
      expect(starter.platformProfitUSD, closeTo(10.0, 0.001));
      expect(starter.infraBudgetUSD, closeTo(5.0, 0.001));

      // Storage & CDN allocations
      expect(starter.storageCostUSD, closeTo(1.00, 0.001)); // 50 GB * $0.02
      expect(starter.bandwidthCostUSD, closeTo(3.75, 0.001)); // 250 GB * $0.015
      expect(starter.deliveryCostUSD, closeTo(4.75, 0.001));

      // Remaining amount earmarked for Firestore operations, Cloud Functions, and DB overhead
      expect(starter.firestoreAndOtherCostsUSD, closeTo(0.25, 0.001));
      expect(starter.deliveryCostUSD + starter.firestoreAndOtherCostsUSD, closeTo(starter.infraBudgetUSD, 0.001));
      expect(starter.platformProfitUSD + starter.infraBudgetUSD, equals(15.0));
    });

    test(r'validates Growth tier ($30) mathematical split: $20 profit, $10 infra ($0.50 Firestore/other)', () {
      final growth = InfrastructureMeteringService.availablePlans.firstWhere((p) => p.id == 'growth_30');
      expect(growth.priceUSD, equals(30.0));
      expect(growth.platformProfitUSD, closeTo(20.0, 0.001));
      expect(growth.infraBudgetUSD, closeTo(10.0, 0.001));

      expect(growth.storageCostUSD, closeTo(2.00, 0.001)); // 100 GB * $0.02
      expect(growth.bandwidthCostUSD, closeTo(7.50, 0.001)); // 500 GB * $0.015
      expect(growth.deliveryCostUSD, closeTo(9.50, 0.001));

      // Remaining amount for Firestore & backend ops
      expect(growth.firestoreAndOtherCostsUSD, closeTo(0.50, 0.001));
      expect(growth.deliveryCostUSD + growth.firestoreAndOtherCostsUSD, closeTo(growth.infraBudgetUSD, 0.001));
      expect(growth.platformProfitUSD + growth.infraBudgetUSD, equals(30.0));
    });

    test(r'validates Pro tier ($45) mathematical split: $30 profit, $15 infra ($0.75 Firestore/other)', () {
      final pro = InfrastructureMeteringService.availablePlans.firstWhere((p) => p.id == 'pro_45');
      expect(pro.priceUSD, equals(45.0));
      expect(pro.platformProfitUSD, closeTo(30.0, 0.001));
      expect(pro.infraBudgetUSD, closeTo(15.0, 0.001));

      expect(pro.storageCostUSD, closeTo(3.00, 0.001)); // 150 GB * $0.02
      expect(pro.bandwidthCostUSD, closeTo(11.25, 0.001)); // 750 GB * $0.015
      expect(pro.deliveryCostUSD, closeTo(14.25, 0.001));

      // Remaining amount for Firestore & backend ops
      expect(pro.firestoreAndOtherCostsUSD, closeTo(0.75, 0.001));
      expect(pro.deliveryCostUSD + pro.firestoreAndOtherCostsUSD, closeTo(pro.infraBudgetUSD, 0.001));
      expect(pro.platformProfitUSD + pro.infraBudgetUSD, equals(45.0));
    });

    test(r'validates Studio tier ($100) mathematical split: $66.67 profit, $33.33 infra ($1.33 Firestore/other)', () {
      final studio = InfrastructureMeteringService.availablePlans.firstWhere((p) => p.id == 'scale_100');
      expect(studio.priceUSD, equals(100.0));
      expect(studio.platformProfitUSD, closeTo(66.67, 0.01));
      expect(studio.infraBudgetUSD, closeTo(33.33, 0.01));

      expect(studio.storageCostUSD, closeTo(8.00, 0.001)); // 400 GB * $0.02
      expect(studio.bandwidthCostUSD, closeTo(24.00, 0.001)); // 1,600 GB * $0.015
      expect(studio.deliveryCostUSD, closeTo(32.00, 0.001));

      // Remaining amount for Firestore & backend ops
      expect(studio.firestoreAndOtherCostsUSD, closeTo(1.33, 0.01));
      expect(studio.deliveryCostUSD + studio.firestoreAndOtherCostsUSD, closeTo(studio.infraBudgetUSD, 0.001));
    });

    test(r'validates Premier tier ($200) mathematical split: $133.33 profit, $66.67 infra ($2.67 Firestore/other)', () {
      final premier = InfrastructureMeteringService.availablePlans.firstWhere((p) => p.id == 'premier_200');
      expect(premier.priceUSD, equals(200.0));
      expect(premier.platformProfitUSD, closeTo(133.33, 0.01));
      expect(premier.infraBudgetUSD, closeTo(66.67, 0.01));

      expect(premier.storageCostUSD, closeTo(16.00, 0.001)); // 800 GB * $0.02
      expect(premier.bandwidthCostUSD, closeTo(48.00, 0.001)); // 3,200 GB * $0.015
      expect(premier.deliveryCostUSD, closeTo(64.00, 0.001));

      // Remaining amount for Firestore & backend ops
      expect(premier.firestoreAndOtherCostsUSD, closeTo(2.67, 0.01));
      expect(premier.deliveryCostUSD + premier.firestoreAndOtherCostsUSD, closeTo(premier.infraBudgetUSD, 0.001));
    });

    test('all fixed tiers have features declaring Firestore and Database operations included', () {
      for (final plan in InfrastructureMeteringService.availablePlans) {
        expect(
          plan.features.any((f) => f.contains('Firestore')),
          isTrue,
          reason: '${plan.id} must explicitly declare Firestore & Database operations included',
        );
      }
    });

    test('calculateInfraCost accurately calculates storage, CDN, and optional Firestore/other costs', () {
      // 100 GB storage ($2.00) + 500 GB bandwidth ($7.50) + $0.50 Firestore/compute = $10.00
      final cost = InfrastructureMeteringService.calculateInfraCost(
        storageUsedBytes: 100 * 1024 * 1024 * 1024,
        bandwidthUsedBytes: 500 * 1024 * 1024 * 1024,
        estimatedOtherCostsUSD: 0.50,
      );
      expect(cost, closeTo(10.00, 0.001));
    });

    test('isHypeSurgeActive triggers when infra cost approaches 90% of infra budget to protect 2/3 profit margin', () {
      final channel = Channel(
        id: 'test_custom_ch',
        ownerId: 'creator_1',
        name: 'Custom Creator',
        nameLowercase: 'custom creator',
        handle: '@customcreator',
        handleLowercase: '@customcreator',
        description: 'Test Channel',
        avatarUrl: '',
        bannerUrl: '',
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
        channelType: ChannelType.custom,
        infraConfig: CustomChannelInfraConfig(
          subscriptionId: 'sub_test_123',
          storageUsedBytes: 10 * 1024 * 1024 * 1024,
          bandwidthUsedBytesThisMonth: 100 * 1024 * 1024 * 1024,
          bandwidthQuotaBytesThisMonth: 250 * 1024 * 1024 * 1024,
        ),
      );

      // Current infra cost is $4.00 (< 90% of $5.00 budget = $4.50)
      expect(
        InfrastructureMeteringService.isHypeSurgeActive(
          channel: channel,
          grossRevenue: 100.0,
          currentInfraCost: 4.0,
        ),
        isFalse,
      );

      // Current infra cost surges to $4.60 (>= 90% of $5.00 budget = $4.50)
      expect(
        InfrastructureMeteringService.isHypeSurgeActive(
          channel: channel,
          grossRevenue: 100.0,
          currentInfraCost: 4.60,
        ),
        isTrue,
      );
    });

    test('guarantees zero-throttling: full 1080p playback even under viral surge (TruthWorld pays all)', () {
      // TruthWorld fronts all costs so viewers never get downscaled to 480p
      expect(
        InfrastructureMeteringService.getRecommendedStreamingResolution(LossPreventionMode.active),
        equals('1080p'),
      );
      expect(
        InfrastructureMeteringService.getRecommendedStreamingResolution(LossPreventionMode.warning),
        equals('1080p'),
      );
      expect(
        InfrastructureMeteringService.getRecommendedStreamingResolution(LossPreventionMode.autoScaled),
        equals('1080p'),
      );
    });

    test('places channel withdrawal on hold when traffic exceeds plan limits until creator upgrades', () {
      final surgeChannel = Channel(
        id: 'surge_creator_ch',
        ownerId: 'creator_99',
        name: 'Surge Creator',
        nameLowercase: 'surge creator',
        handle: '@surgecreator',
        handleLowercase: '@surgecreator',
        description: 'Viral Channel',
        avatarUrl: '',
        bannerUrl: '',
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
        channelType: ChannelType.custom,
        infraConfig: CustomChannelInfraConfig(
          subscriptionId: 'sub_surge_123',
          storageUsedBytes: 50 * 1024 * 1024 * 1024,
          // Exceeds 250 GB quota -> 300 GB
          bandwidthUsedBytesThisMonth: 300 * 1024 * 1024 * 1024,
          bandwidthQuotaBytesThisMonth: 250 * 1024 * 1024 * 1024,
        ),
      );

      final summary = InfrastructureMeteringService.computeHypeSurgeSummary(
        channel: surgeChannel,
        adRevenue: 150.0,
        premiumSubRevenue: 25.0,
        membershipsRevenue: 50.0,
        tipsRevenue: 10.0,
      );

      expect(summary.isHypeSurgeActive, isTrue);
      expect(summary.isWithdrawalHeld, isTrue);
      expect(summary.withdrawalHoldReason, contains('TruthWorld has fronted and paid 100%'));
      expect(summary.recommendedUpgradePlan.id, equals('growth_30'));

      // Upgraded channel with adequate quota has withdrawal unlocked
      final upgradedChannel = Channel(
        id: 'surge_creator_ch',
        ownerId: 'creator_99',
        name: 'Surge Creator',
        nameLowercase: 'surge creator',
        handle: '@surgecreator',
        handleLowercase: '@surgecreator',
        description: 'Viral Channel',
        avatarUrl: '',
        bannerUrl: '',
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
        channelType: ChannelType.custom,
        infraConfig: CustomChannelInfraConfig(
          subscriptionId: 'sub_surge_123',
          planTier: 'growth_30',
          storageUsedBytes: 50 * 1024 * 1024 * 1024,
          bandwidthUsedBytesThisMonth: 300 * 1024 * 1024 * 1024,
          // 500 GB quota covers 300 GB
          bandwidthQuotaBytesThisMonth: 500 * 1024 * 1024 * 1024,
        ),
      );

      final upgradedSummary = InfrastructureMeteringService.computeHypeSurgeSummary(
        channel: upgradedChannel,
        adRevenue: 150.0,
        premiumSubRevenue: 25.0,
        membershipsRevenue: 50.0,
        tipsRevenue: 10.0,
      );

      expect(upgradedSummary.isWithdrawalHeld, isFalse);
    });
  });
}
