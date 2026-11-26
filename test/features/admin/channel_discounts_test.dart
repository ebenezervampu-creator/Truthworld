import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/services/channel_wallet_pricing.dart';
import 'package:truthworld/core/services/channel_wallet_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin/admin_roles_config.dart';

void main() {
  group('Channel AI Discounts & Free Privileges Tests', () {
    test('Channel model parses and serializes discount fields accurately', () {
      final rawData = <String, dynamic>{
        'name': 'Test Creator Channel',
        'handle': '@testcreator',
        'ownerId': 'user_123',
        'dubbingDiscountType': 'free',
        'dubbingDiscountPercent': 100.0,
        'subtitlesDiscountType': '50%',
        'subtitlesDiscountPercent': 50.0,
        'aiDiscounts': {
          'dubbing': {'type': 'free', 'percent': 100.0, 'enabled': true},
          'subtitles': {'type': '50%', 'percent': 50.0, 'enabled': true},
        },
      };

      final channel = Channel.fromMap(rawData, 'chan_test_1');
      expect(channel.id, equals('chan_test_1'));
      expect(channel.dubbingDiscountType, equals('free'));
      expect(channel.dubbingDiscountPercent, equals(100.0));
      expect(channel.isDubbingFree, isTrue);
      expect(channel.effectiveDubbingDiscountPercent, equals(100.0));
      expect(channel.hasDubbingDiscount, isTrue);

      expect(channel.subtitlesDiscountType, equals('50%'));
      expect(channel.subtitlesDiscountPercent, equals(50.0));
      expect(channel.isSubtitlesFree, isFalse);
      expect(channel.effectiveSubtitlesDiscountPercent, equals(50.0));
      expect(channel.hasSubtitlesDiscount, isTrue);

      final serialized = channel.toMap();
      expect(serialized['dubbingDiscountType'], equals('free'));
      expect(serialized['dubbingDiscountPercent'], equals(100.0));
      expect(serialized['subtitlesDiscountType'], equals('50%'));
      expect(serialized['subtitlesDiscountPercent'], equals(50.0));
      expect(serialized['aiDiscounts'], isNotNull);
    });

    test('Channel model correctly parses nested aiDiscounts map when top-level fields are absent', () {
      final rawData = <String, dynamic>{
        'name': 'Legacy Nested Channel',
        'handle': '@legacynested',
        'ownerId': 'user_456',
        'aiDiscounts': {
          'dubbing': {'type': 'custom', 'percent': 35.0, 'enabled': true},
          'subtitles': {'type': 'free', 'percent': 100.0, 'enabled': true},
        },
      };

      final channel = Channel.fromMap(rawData, 'chan_test_2');
      expect(channel.dubbingDiscountType, equals('custom'));
      expect(channel.dubbingDiscountPercent, equals(35.0));
      expect(channel.isDubbingFree, isFalse);
      expect(channel.effectiveDubbingDiscountPercent, equals(35.0));

      expect(channel.subtitlesDiscountType, equals('free'));
      expect(channel.subtitlesDiscountPercent, equals(100.0));
      expect(channel.isSubtitlesFree, isTrue);
      expect(channel.effectiveSubtitlesDiscountPercent, equals(100.0));
    });

    test('Dubbing cost calculation: Free, 50%, and Custom discounts applied accurately', () {
      final baseChannel = Channel(
        id: 'std_chan',
        name: 'Standard Channel',
        nameLowercase: 'standard channel',
        handle: '@std',
        handleLowercase: '@std',
        description: '',
        avatarUrl: '',
        bannerUrl: '',
        ownerId: 'u1',
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      );

      // 1. Standard Channel (no discount, 400s -> $2.00/lang at $0.30/min, 2 languages => $4.00)
      final standardCost = ChannelWalletService.calculateDubbingCost(
        languageCount: 2,
        durationSeconds: 400,
        channel: baseChannel,
      );
      expect(standardCost, equals(4.00));

      // 2. Channel with 100% Free dubbing discount
      final freeChannel = baseChannel.copyWith(
        dubbingDiscountType: 'free',
        dubbingDiscountPercent: 100.0,
      );
      final freeCost = ChannelWalletService.calculateDubbingCost(
        languageCount: 2,
        durationSeconds: 400,
        channel: freeChannel,
      );
      expect(freeCost, equals(0.00));

      // 3. Channel with 50% dubbing discount ($4.00 -> $2.00)
      final fiftyChannel = baseChannel.copyWith(
        dubbingDiscountType: '50%',
        dubbingDiscountPercent: 50.0,
      );
      final fiftyCost = ChannelWalletService.calculateDubbingCost(
        languageCount: 2,
        durationSeconds: 400,
        channel: fiftyChannel,
      );
      expect(fiftyCost, equals(2.00));

      // 4. Channel with Custom 25% dubbing discount ($4.00 -> $3.00)
      final customChannel = baseChannel.copyWith(
        dubbingDiscountType: 'custom',
        dubbingDiscountPercent: 25.0,
      );
      final customCost = ChannelWalletService.calculateDubbingCost(
        languageCount: 2,
        durationSeconds: 400,
        channel: customChannel,
      );
      expect(customCost, equals(3.00));

      // 5. Passing explicit discountPercent overrides
      final explicitCost = ChannelWalletService.calculateDubbingCost(
        languageCount: 2,
        durationSeconds: 400,
        discountPercent: 40.0,
      );
      expect(explicitCost, equals(2.40));
    });

    test('Subtitle cost calculation: Free, 50%, and Custom discounts applied accurately', () {
      final baseChannel = Channel(
        id: 'std_chan_sub',
        name: 'Subtitle Channel',
        nameLowercase: 'subtitle channel',
        handle: '@sub',
        handleLowercase: '@sub',
        description: '',
        avatarUrl: '',
        bannerUrl: '',
        ownerId: 'u2',
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      );

      // Subtitles: 400s video (Tier 2: $0.05/lang), 10 languages => $0.50
      final standardCost = ChannelWalletService.calculateSubtitleCost(
        languageCount: 10,
        durationSeconds: 400,
        channel: baseChannel,
      );
      expect(standardCost, equals(0.50));

      // 100% Free
      final freeChannel = baseChannel.copyWith(
        subtitlesDiscountType: 'free',
        subtitlesDiscountPercent: 100.0,
      );
      final freeCost = ChannelWalletService.calculateSubtitleCost(
        languageCount: 10,
        durationSeconds: 400,
        channel: freeChannel,
      );
      expect(freeCost, equals(0.00));

      // 50% Off ($0.50 -> $0.25)
      final fiftyChannel = baseChannel.copyWith(
        subtitlesDiscountType: '50%',
        subtitlesDiscountPercent: 50.0,
      );
      final fiftyCost = ChannelWalletService.calculateSubtitleCost(
        languageCount: 10,
        durationSeconds: 400,
        channel: fiftyChannel,
      );
      expect(fiftyCost, equals(0.25));

      // Custom 20% Off ($0.50 -> $0.40)
      final customChannel = baseChannel.copyWith(
        subtitlesDiscountType: 'custom',
        subtitlesDiscountPercent: 20.0,
      );
      final customCost = ChannelWalletService.calculateSubtitleCost(
        languageCount: 10,
        durationSeconds: 400,
        channel: customChannel,
      );
      expect(customCost, equals(0.40));
    });

    test('calculateAIFeatureCost integrates channel discounts for combined features', () {
      final channel = Channel(
        id: 'combo_chan',
        name: 'Combo Channel',
        nameLowercase: 'combo channel',
        handle: '@combo',
        handleLowercase: '@combo',
        description: '',
        avatarUrl: '',
        bannerUrl: '',
        ownerId: 'u3',
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
        dubbingDiscountType: 'free',
        dubbingDiscountPercent: 100.0, // Free dubbing
        subtitlesDiscountType: '50%',
        subtitlesDiscountPercent: 50.0, // 50% subtitles
      );

      // 400s video, 2 languages (dubbing supported):
      // Subtitles standard: 2 * $0.05 = $0.10 => with 50% discount = $0.05
      // Dubbing standard: 2 * $0.50 = $1.00 => with 100% free = $0.00
      // Total = $0.05
      final cost = ChannelWalletPricing.calculateAIFeatureCost(
        selectedFeatures: {'subtitles', 'dubbing'},
        targetLanguages: ['en', 'es'],
        durationSeconds: 400,
        channel: channel,
      );
      expect(cost, equals(0.05));
    });

    test('Super Admin permission check evaluates correctly for discount management', () {
      // Super Admin role
      final isSuper1 = AdminRolesConfig.isSuperAdmin(
        isAdmin: true,
        isPrimaryOwner: false,
        currentAdminEmail: 'superadmin@truthworld.in',
        currentAdminRole: 'Super Admin',
        currentAdminRoles: ['Super Admin'],
      );
      expect(isSuper1, isTrue);

      // Primary Owner
      final isSuper2 = AdminRolesConfig.isSuperAdmin(
        isAdmin: true,
        isPrimaryOwner: true,
        currentAdminEmail: 'hello@truthworld.in',
        currentAdminRole: 'Owner',
        currentAdminRoles: ['Owner'],
      );
      expect(isSuper2, isTrue);

      // Regular Content Moderator (NOT Super Admin)
      final isSuper3 = AdminRolesConfig.isSuperAdmin(
        isAdmin: true,
        isPrimaryOwner: false,
        currentAdminEmail: 'mod@truthworld.in',
        currentAdminRole: 'Content Moderator',
        currentAdminRoles: ['Content Moderator'],
      );
      expect(isSuper3, isFalse);

      // Trust & Safety Reviewer (NOT Super Admin)
      final isSuper4 = AdminRolesConfig.isSuperAdmin(
        isAdmin: true,
        isPrimaryOwner: false,
        currentAdminEmail: 'reviewer@truthworld.in',
        currentAdminRole: 'Trust & Safety Reviewer',
        currentAdminRoles: ['Trust & Safety Reviewer'],
      );
      expect(isSuper4, isFalse);
    });
  });
}
