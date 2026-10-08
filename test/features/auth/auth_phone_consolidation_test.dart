import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/services/auth/auth_phone_signin_provider.dart';
import 'package:truthworld/data/models/user_model.dart';

void main() {
  group('Auth Phone Consolidation & Model Tests', () {
    test('UserModel.toFirestoreCreate includes root phoneNumber when present in metadata', () {
      const user = UserModel(
        uid: 'yh4kKADNxifYDAilt9o6v7T2j2B2',
        email: '',
        displayName: 'Ebenezervampu',
        metadata: {
          'phoneNumber': '+919390617877',
          'platform': 'mobile',
        },
        hasCompletedOnboarding: true,
      );

      final map = user.toFirestoreCreate();
      expect(map['uid'], equals('yh4kKADNxifYDAilt9o6v7T2j2B2'));
      expect(map['displayName'], equals('Ebenezervampu'));
      expect(map['phoneNumber'], equals('+919390617877'));
      expect(map['hasCompletedOnboarding'], isTrue);
    });

    test('UserModel.toFirestoreUpdate includes root phoneNumber when present in metadata', () {
      const user = UserModel(
        uid: 'yh4kKADNxifYDAilt9o6v7T2j2B2',
        email: '',
        displayName: 'Ebenezervampu',
        metadata: {
          'phoneNumber': '+919390617877',
        },
        hasCompletedOnboarding: true,
      );

      final map = user.toFirestoreUpdate();
      expect(map['displayName'], equals('Ebenezervampu'));
      expect(map['phoneNumber'], equals('+919390617877'));
      expect(map['hasCompletedOnboarding'], isTrue);
    });

    test('AuthPhoneSignInProvider normalizes phone numbers correctly', () {
      expect(
        AuthPhoneSignInProvider.normalizePhoneNumber('+919390617877'),
        equals('+919390617877'),
      );
      expect(
        AuthPhoneSignInProvider.normalizePhoneNumber('9390617877', countryCode: '+91'),
        equals('+919390617877'),
      );
      expect(
        AuthPhoneSignInProvider.normalizePhoneNumber('09390617877', countryCode: '+91'),
        equals('+919390617877'),
      );
    });
  });
}
