import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/services/channel_wallet_service.dart';
import 'package:truthworld/data/models/channel.dart';

void main() {
  group('Zero Charm-Pricing & Epistemic Honesty Tests', () {
    test('Storage Packs use honest round numbers and zero charm pricing', () {
      for (final pack in ChannelWalletPricing.storagePacks) {
        expect(
          pack.priceUSD.toString().endsWith('.99'),
          isFalse,
          reason: 'Pack ${pack.id} must not use .99 charm pricing',
        );
        expect(
          pack.priceUSD,
          isNot(equals(9.00)),
          reason: r'100 GB storage pack must be clean $10.00, not $9.00 marketing price',
        );
      }

      final pack100 = ChannelWalletPricing.storagePacks.firstWhere(
        (p) => p.id == 'storage_100gb',
      );
      expect(pack100.priceUSD, equals(10.00));
    });

    test('Fact-Checking Monthly Plans use clean round numbers and zero charm pricing', () {
      for (final plan in ChannelWalletPricing.channelFactCheckPlans) {
        expect(
          plan.priceUSD.toString().endsWith('.99'),
          isFalse,
          reason: 'Plan ${plan.id} must not use .99 charm pricing',
        );
      }

      final freeStandard = ChannelWalletPricing.channelFactCheckPlans.firstWhere(
        (p) => p.id == 'fc_plan_free_standard',
      );
      expect(freeStandard.priceUSD, equals(0.00));
    });

    test('CustomChannelInfraConfig sets trial credits to 0.0 to prevent promotional farming abuse', () {
      final config = CustomChannelInfraConfig.fromMap({
        'subscriptionId': 'sub_test',
        'trialCreditUSD': 9.0,
        'trialCreditRemainingUSD': 9.0,
      });

      expect(config.trialCreditUSD, equals(0.0));
      expect(config.trialCreditRemainingUSD, equals(0.0));
    });

    test('ChannelWalletService returns 0.0 trial credit in getSpendableBalance to eliminate promotional farming', () {
      final service = ChannelWalletService();
      final channel = Channel(
        id: 'test_chan_1',
        name: 'Test Channel',
        nameLowercase: 'test channel',
        handle: '@test_chan',
        handleLowercase: '@test_chan',
        description: 'Test channel',
        avatarUrl: '',
        bannerUrl: '',
        ownerId: 'owner_1',
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
        infraConfig: CustomChannelInfraConfig(
          subscriptionId: 'sub_test',
          trialCreditUSD: 10.0,
          trialCreditRemainingUSD: 9.0,
        ),
      );

      final spendable = service.getSpendableBalance(channel: channel);
      expect(spendable.trialCreditRemaining, equals(0.0));
      expect(spendable.totalSpendableBalance, equals(0.0));
    });

    test('Channel max video limits avoid 999999 marketing gimmicks', () {
      final channel = Channel(
        id: 'test_chan_2',
        name: 'Test Channel',
        nameLowercase: 'test channel',
        handle: '@test_chan_2',
        handleLowercase: '@test_chan_2',
        description: 'Test channel',
        avatarUrl: '',
        bannerUrl: '',
        ownerId: 'owner_2',
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      );

      expect(channel.maxAllowedVideos, isNot(equals(999999)));
      expect(channel.maxAllowedVideos, equals(100000));
    });

    test('Subtitle Tiers use exact Starter (\$0.50) and Pro (\$0.75) for 10-minute video subtitles', () {
      // 10-minute video (600s), 1 language
      final starterCost10m = ChannelWalletService.calculateSubtitleCost(
        languageCount: 1,
        durationSeconds: 600,
        tierId: 'starter',
      );
      expect(starterCost10m, equals(0.50));

      final proCost10m = ChannelWalletService.calculateSubtitleCost(
        languageCount: 1,
        durationSeconds: 600,
        tierId: 'pro',
      );
      expect(proCost10m, equals(0.75));

      // Additional language for 10-minute video (+$0.20 Starter, +$0.30 Pro)
      final starter2Langs = ChannelWalletService.calculateSubtitleCost(
        languageCount: 2,
        durationSeconds: 600,
        tierId: 'starter',
      );
      expect(starter2Langs, equals(0.70));

      final pro2Langs = ChannelWalletService.calculateSubtitleCost(
        languageCount: 2,
        durationSeconds: 600,
        tierId: 'pro',
      );
      expect(pro2Langs, equals(1.05));
    });
  });
}
