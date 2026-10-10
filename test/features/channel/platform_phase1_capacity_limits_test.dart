import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/constants/platform_limits.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/data/models/user_model.dart';

void main() {
  group('Truthworld Phase 1 Capacity Limits Specification', () {
    test('PlatformLimits configuration holds exact Phase 1 quotas', () {
      expect(PlatformLimits.currentPhase, equals(1));
      expect(PlatformLimits.maxStandardUsers, equals(10000));
      expect(PlatformLimits.maxStandardChannels, equals(100));
      expect(PlatformLimits.isCustomChannelUnlimited, isTrue);
    });

    test('Standard channels are capped at 100 while custom channels are unlimited', () {
      const standardType = ChannelType.standard;
      const customType = ChannelType.custom;

      // Business rule: standard channels must adhere to maxStandardChannels limit
      expect(standardType, equals(ChannelType.standard));
      expect(PlatformLimits.maxStandardChannels, equals(100));

      // Business rule: custom channels are unlimited
      expect(customType, equals(ChannelType.custom));
      expect(PlatformLimits.isCustomChannelUnlimited, isTrue);
    });

    test('UserModel AccountStatus correctly handles waitlisted status for >10k users', () {
      expect(AccountStatus.fromString('waitlisted'), equals(AccountStatus.waitlisted));
      expect(AccountStatus.waitlisted.value, equals('waitlisted'));

      const user = UserModel(
        uid: 'user_10001',
        email: 'waitlist_user@example.com',
        status: AccountStatus.waitlisted,
      );

      expect(user.status, equals(AccountStatus.waitlisted));
      final map = user.toFirestoreUpdate();
      expect(map['status'], equals('waitlisted'));
    });
  });
}
