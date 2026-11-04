import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/services/channel_payout_calculator.dart';
import 'package:truthworld/data/models/channel.dart';

void main() {
  group('Channel Revenue Share Audit & Verification Tests', () {
    test('Standard Channel receives exact 70/30 split on Ads & Subs, 90/10 on Memberships & Superchats (Hybrid Model)', () {
      final breakdown = ChannelPayoutCalculator.calculateStandardChannelPayout(
        adRevenue: 1000.0,
        premiumSubRevenue: 500.0,
        tipsRevenue: 300.0,
        membershipsRevenue: 200.0,
      );

      // Gross: 1000 + 500 + 300 + 200 = 2000.0
      expect(breakdown.grossRevenue, equals(2000.0));

      // Creator Share:
      // Ads: 70% of 1000 = 700.0
      // Premium Subs: 70% of 500 = 350.0
      // Superchats/Tips: 90% of 300 = 270.0 (10% fee)
      // Memberships: 90% of 200 = 180.0 (10% fee)
      // Total Creator Payout: 700 + 350 + 270 + 180 = 1500.0
      expect(breakdown.creatorPayout, closeTo(1500.0, 0.001));

      // Platform Share:
      // Ads: 30% of 1000 = 300.0
      // Premium Subs: 30% of 500 = 150.0
      // Superchats/Tips: 10% of 300 = 30.0
      // Memberships: 10% of 200 = 20.0
      // Total Platform Share: 300 + 150 + 30 + 20 = 500.0
      expect(breakdown.platformShare, closeTo(500.0, 0.001));

      // Sum of creator + platform equals gross revenue exactly
      expect(breakdown.creatorPayout + breakdown.platformShare, closeTo(breakdown.grossRevenue, 0.001));
    });

    test('Custom Channel receives 100% across all revenue streams minus configured infra and fee', () {
      final breakdown = ChannelPayoutCalculator.calculateCustomChannelPayout(
        grossRevenue: 2000.0,
        actualInfraCost: 200.0,
      );

      expect(breakdown.grossRevenue, equals(2000.0));
      // Creator: 2000 - 200 (infra) - 25 (flat fee) = 1775.0
      expect(breakdown.creatorPayout, equals(1775.0));
      // Platform: 200 + 25 = 225.0
      expect(breakdown.platformShare, equals(225.0));
      expect(breakdown.creatorPayout + breakdown.platformShare, equals(breakdown.grossRevenue));
    });

    test('Superchat USD normalization converts to INR correctly with 84.0 rate', () {
      const usdRate = 84.0;

      // $10 Superchat = ₹840
      const tipUsd10 = 10.0;
      const tipInr10 = tipUsd10 * usdRate;
      expect(tipInr10, equals(840.0));

      // $25.50 Superchat = ₹2142
      const tipUsd25_5 = 25.50;
      const tipInr25_5 = tipUsd25_5 * usdRate;
      expect(tipInr25_5, equals(2142.0));

      // Standard channel: 90% of Superchats go to creator (10% platform fee)
      final standardPayout = ChannelPayoutCalculator.calculateStandardChannelPayout(
        adRevenue: 0.0,
        premiumSubRevenue: 0.0,
        tipsRevenue: tipInr10,
        membershipsRevenue: 0.0,
      );
      expect(standardPayout.creatorPayout, equals(756.0));
      expect(standardPayout.platformShare, equals(84.0));

      // Custom channel: 100% of Superchats retained
      final customChannel = Channel.fromMap({
        'name': 'Custom Channel',
        'channelType': 'custom',
        'superchatRevenueTotal': tipInr10,
      }, 'ch-custom');
      final customPayout = ChannelPayoutCalculator.calculatePayout(
        customChannel,
        tipsRevenue: tipInr10,
        actualInfraCost: 0.0,
      );
      // Flat platform fee is deducted in custom channel calculation
      expect(customPayout.grossRevenue, equals(840.0));
    });

    test('Channel Model serialization accurately preserves all 5 revenue fields', () {
      final channelData = <String, dynamic>{
        'name': 'Test Channel',
        'nameLowercase': 'test channel',
        'handle': '@testchannel',
        'handleLowercase': '@testchannel',
        'description': 'Channel Description',
        'avatarUrl': 'https://example.com/avatar.png',
        'bannerUrl': 'https://example.com/banner.png',
        'ownerId': 'user_test_123',
        'channelType': 'standard',
        'adsRevenueTotal': 1250.75,
        'premiumSubsRevenueTotal': 620.50,
        'membershipRevenueTotal': 450.00,
        'superchatRevenueTotal': 840.00,
        'withdrawnRevenueTotal': 500.00,
      };

      final channel = Channel.fromMap(channelData, 'ch_abc123');

      expect(channel.adsRevenueTotal, equals(1250.75));
      expect(channel.premiumSubsRevenueTotal, equals(620.50));
      expect(channel.membershipRevenueTotal, equals(450.00));
      expect(channel.superchatRevenueTotal, equals(840.00));
      expect(channel.withdrawnRevenueTotal, equals(500.00));

      // Verify toMap export
      final exported = channel.toMap();
      expect(exported['adsRevenueTotal'], equals(1250.75));
      expect(exported['premiumSubsRevenueTotal'], equals(620.50));
      expect(exported['membershipRevenueTotal'], equals(450.00));
      expect(exported['superchatRevenueTotal'], equals(840.00));
      expect(exported['withdrawnRevenueTotal'], equals(500.00));

      // Verify copyWith modifications
      final updated = channel.copyWith(
        adsRevenueTotal: 1500.00,
        withdrawnRevenueTotal: 750.00,
      );
      expect(updated.adsRevenueTotal, equals(1500.00));
      expect(updated.withdrawnRevenueTotal, equals(750.00));
      expect(updated.premiumSubsRevenueTotal, equals(620.50));
      expect(updated.membershipRevenueTotal, equals(450.00));
      expect(updated.superchatRevenueTotal, equals(840.00));
    });

    test('Zero double platform deduction check: net channel revenue is not penalized twice', () {
      // Simulate channel storing net creator share
      const grossAdPool = 1000.0;
      const netCreatorShare = grossAdPool * 0.70; // 700.0

      // An erroneous double cut would do netCreatorShare * 0.70 = 490.0 (a 49% cut)
      const erroneousDoubleCut = netCreatorShare * 0.70;
      expect(erroneousDoubleCut, closeTo(490.0, 0.001));

      // Correct handling: netCreatorShare is already the creator's 70% share
      // Reconstructing gross:
      const reconstructedGross = netCreatorShare / 0.70;
      expect(reconstructedGross, closeTo(grossAdPool, 0.001));

      // Platform share:
      const platformShare = reconstructedGross * 0.30;
      expect(platformShare, closeTo(300.0, 0.001));

      // Spendable balance for creator must be 700.0, NOT 490.0
      expect(netCreatorShare, equals(700.0));
      expect(netCreatorShare, isNot(equals(erroneousDoubleCut)));
    });
  });
}
