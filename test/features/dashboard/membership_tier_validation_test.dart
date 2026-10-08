import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/memberships_controller.dart';

void main() {
  group('ChannelMembershipTier Minimum Price Constants & Helpers', () {
    test('verifies minimum price values for INR and USD', () {
      expect(ChannelMembershipTier.minPriceINR, equals(10.0));
      expect(ChannelMembershipTier.minPriceUSD, equals(1.0));
    });

    test('minPriceFor returns correct minimum price according to currency', () {
      expect(ChannelMembershipTier.minPriceFor('INR'), equals(10.0));
      expect(ChannelMembershipTier.minPriceFor('inr'), equals(10.0));
      expect(ChannelMembershipTier.minPriceFor('USD'), equals(1.0));
      expect(ChannelMembershipTier.minPriceFor('usd'), equals(1.0));
      expect(ChannelMembershipTier.minPriceFor(''), equals(1.0));
    });

    test('minPriceLabel provides user-friendly labels with rupees and dollars', () {
      expect(ChannelMembershipTier.minPriceLabel('INR'), contains('10 rupees'));
      expect(ChannelMembershipTier.minPriceLabel('USD'), contains('1 dollar'));
    });

    test('validates whether a given price meets minimum pricing requirements', () {
      // INR minimum is 10 rupees
      expect(9.99 >= ChannelMembershipTier.minPriceFor('INR'), isFalse);
      expect(10.0 >= ChannelMembershipTier.minPriceFor('INR'), isTrue);
      expect(25.0 >= ChannelMembershipTier.minPriceFor('INR'), isTrue);

      // USD minimum is 1 dollar ($1)
      expect(0.50 >= ChannelMembershipTier.minPriceFor('USD'), isFalse);
      expect(0.99 >= ChannelMembershipTier.minPriceFor('USD'), isFalse);
      expect(1.0 >= ChannelMembershipTier.minPriceFor('USD'), isTrue);
      expect(5.0 >= ChannelMembershipTier.minPriceFor('USD'), isTrue);
    });
  });

  group('ChannelMembershipTier Currency and Price Formatting', () {
    test('formats INR prices cleanly', () {
      final tierWholeINR = ChannelMembershipTier(
        id: 'tier_1',
        name: 'Desi Supporter',
        price: 10.0,
        currency: 'INR',
        perks: ['Perk 1'],
      );
      expect(tierWholeINR.currencySymbol, equals('₹'));
      expect(tierWholeINR.formattedPrice, equals('₹10'));

      final tierDecINR = ChannelMembershipTier(
        id: 'tier_2',
        name: 'Desi VIP',
        price: 19.50,
        currency: 'INR',
        perks: ['Perk 1'],
      );
      expect(tierDecINR.formattedPrice, equals('₹19.50'));
    });

    test('formats USD prices cleanly', () {
      final tierMinUSD = ChannelMembershipTier(
        id: 'tier_3',
        name: 'Supporter',
        price: 1.0,
        perks: ['Perk 1'],
      );
      expect(tierMinUSD.currencySymbol, equals(r'$'));
      expect(tierMinUSD.formattedPrice, equals(r'$1'));

      final tierStdUSD = ChannelMembershipTier(
        id: 'tier_4',
        name: 'Standard Patron',
        price: 5.0,
        perks: ['Perk 1'],
      );
      expect(tierStdUSD.formattedPrice, equals(r'$5'));

      final tierDecUSD = ChannelMembershipTier(
        id: 'tier_5',
        name: 'Custom Patron',
        price: 2.50,
        perks: ['Perk 1'],
      );
      expect(tierDecUSD.formattedPrice, equals(r'$2.50'));
    });
  });

  group('ChannelMembershipTier Serialization & Backward Compatibility', () {
    test('serializes toMap and deserializes fromMap with currency', () {
      final original = ChannelMembershipTier(
        id: 'tier_test_1',
        name: 'Super Fan',
        price: 10.0,
        currency: 'INR',
        perks: ['Badge', 'Chat Emojis'],
        badgeColorHex: '0xFF0284C7',
      );

      final map = original.toMap();
      expect(map['currency'], equals('INR'));
      expect(map['price'], equals(10.0));

      final restored = ChannelMembershipTier.fromMap(map, 'tier_test_1');
      expect(restored.currency, equals('INR'));
      expect(restored.price, equals(10.0));
      expect(restored.formattedPrice, equals('₹10'));
    });

    test('backward compatibility: infers currency when currency field is absent in legacy map', () {
      // Legacy document with price < 50 defaults to USD
      final legacyUSDMap = <String, dynamic>{
        'name': 'Bronze Supporter',
        'price': 1.99,
        'perks': ['Perk 1'],
      };
      final tierUSD = ChannelMembershipTier.fromMap(legacyUSDMap, 'leg_usd');
      expect(tierUSD.currency, equals('USD'));
      expect(tierUSD.formattedPrice, equals(r'$1.99'));

      // Legacy document with price >= 50 defaults to INR
      final legacyINRMap = <String, dynamic>{
        'name': 'Silver Supporter',
        'price': 89.0,
        'perks': ['Perk 1'],
      };
      final tierINR = ChannelMembershipTier.fromMap(legacyINRMap, 'leg_inr');
      expect(tierINR.currency, equals('INR'));
      expect(tierINR.formattedPrice, equals('₹89'));
    });

    test('copyWith properly updates currency and price', () {
      final tier = ChannelMembershipTier(
        id: 'tier_cp',
        name: 'Base Tier',
        price: 4.99,
        perks: ['Perk A'],
      );

      final updated = tier.copyWith(
        currency: 'INR',
        price: 10.0,
      );

      expect(updated.currency, equals('INR'));
      expect(updated.price, equals(10.0));
      expect(updated.formattedPrice, equals('₹10'));
    });
  });

  group('ChannelMember Currency & Formatting', () {
    test('formats member price with correct currency symbol', () {
      final memberINR = ChannelMember(
        userId: 'u1',
        userName: 'Aarav',
        userAvatarUrl: '',
        tierId: 't1',
        tierName: 'Gold Member',
        price: 10.0,
        currency: 'INR',
      );
      expect(memberINR.currencySymbol, equals('₹'));
      expect(memberINR.formattedPrice, equals('₹10'));

      final memberUSD = ChannelMember(
        userId: 'u2',
        userName: 'Alex',
        userAvatarUrl: '',
        tierId: 't2',
        tierName: 'Gold Member',
        price: 0.10,
      );
      expect(memberUSD.currencySymbol, equals(r'$'));
      expect(memberUSD.formattedPrice, equals(r'$0.10'));
    });
  });

  group('Channel Membership Tier Capacity Limit (Up to 3 Tiers)', () {
    test('enforces maximum 3 tiers per channel constant', () {
      expect(ChannelMembershipTier.maxTiersPerChannel, equals(3));
      expect(MembershipsController.maxTiersPerChannel, equals(3));
    });

    test('validates starter bundles never exceed 3 tiers', () {
      for (final bundle in MembershipsController.starterBundles) {
        expect(
          bundle.tiers.length,
          lessThanOrEqualTo(3),
          reason: 'Bundle ${bundle.title} has ${bundle.tiers.length} tiers, exceeding limit of 3',
        );
      }
    });
  });
}
