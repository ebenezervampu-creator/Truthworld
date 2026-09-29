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

    test('CustomChannelInfraConfig normalizes legacy 9.0 trial credit to clean 10.0', () {
      final config = CustomChannelInfraConfig.fromMap({
        'subscriptionId': 'sub_test',
        'trialCreditUSD': 9.0,
        'trialCreditRemainingUSD': 9.0,
      });

      expect(config.trialCreditUSD, equals(10.0));
      expect(config.trialCreditRemainingUSD, equals(10.0));
    });

    test('ChannelWalletService normalizes legacy 9.0 trial credit to 10.0 in getSpendableBalance', () {
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
          trialCreditRemainingUSD: 9.0, // Legacy charm number
        ),
      );

      final spendable = service.getSpendableBalance(channel: channel);
      expect(spendable.trialCreditRemaining, equals(10.0));
      expect(spendable.totalSpendableBalance, equals(10.0));
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
  });
}
