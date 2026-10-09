import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/currency_localization_service.dart';
import 'package:truthworld/features/onboarding/presentation/controllers/onboarding_profile_controller.dart';

import '../../test_helpers/mock_firebase.dart';

void main() {
  setUpAll(() async {
    await setupMockFirebase();
  });

  setUp(() {
    Get.reset();
    Get.testMode = true;
    CurrencyLocalizationService.enablePersistentStorage = false;
    Get.put<CurrencyLocalizationService>(CurrencyLocalizationService());
    Get.put<AuthService>(AuthService());
  });

  tearDown(Get.reset);

  group('OnboardingProfileController - Google Defaults & Initialization', () {
    test('pre-fills display name and avatar from AuthService / Google user', () {
      final auth = AuthService.to;
      auth.userDisplayName.value = 'John Doe';
      auth.userPhotoUrl.value = 'https://example.com/avatar.jpg';
      auth.userCountry.value = 'US';

      final controller = OnboardingProfileController();

      expect(controller.displayNameController.text, 'John Doe');
      expect(controller.activeAvatarUrl.value, 'https://example.com/avatar.jpg');
      expect(controller.selectedCountry.value, 'US');
      expect(controller.usernameController.text, 'john_doe');

      controller.onClose();
    });

    test('pre-selects detected country from CurrencyLocalizationService if not set in profile', () {
      final auth = AuthService.to;
      auth.userCountry.value = null;
      CurrencyLocalizationService.to.userCountryCode.value = 'GB';

      final controller = OnboardingProfileController();

      expect(controller.selectedCountry.value, 'GB');

      controller.onClose();
    });

    test('countryOptions includes international flags and codes', () {
      final controller = OnboardingProfileController();
      final options = controller.countryOptions;

      expect(options.any((c) => c.code == 'IN'), isTrue);
      expect(options.any((c) => c.code == 'US'), isTrue);
      expect(options.first.flagEmoji, isNotEmpty);

      controller.onClose();
    });
  });

  group('OnboardingProfileController - 18+ Age Groups & Validation', () {
    late OnboardingProfileController controller;

    setUp(() {
      controller = OnboardingProfileController();
    });

    tearDown(() {
      controller.onClose();
    });

    test('ageGroups strictly starts from 18 years and contains no under-18 options', () {
      final groups = controller.ageGroups;

      expect(groups.contains('Under 13'), isFalse);
      expect(groups.contains('13–17'), isFalse);
      expect(groups.first, '18–24');
      expect(groups.contains('25–34'), isTrue);
      expect(groups.contains('35–44'), isTrue);
      expect(groups.contains('45–54'), isTrue);
      expect(groups.contains('55–64'), isTrue);
      expect(groups.contains('65+'), isTrue);
      expect(groups.contains('Prefer not to say'), isTrue);
    });

    test('inferAgeGroupFromAge returns null for age under 18', () {
      expect(controller.inferAgeGroupFromAge(12), isNull);
      expect(controller.inferAgeGroupFromAge(16), isNull);
      expect(controller.inferAgeGroupFromAge(17), isNull);
      expect(controller.inferAgeGroupFromAge(18), '18–24');
      expect(controller.inferAgeGroupFromAge(22), '18–24');
    });

    test('validates display name and rejects empty string', () {
      controller.displayNameController.text = '   ';
      expect(controller.displayNameController.text.trim(), isEmpty);
    });

    test('validates username format properly', () {
      expect(controller.validateUsername('alex_rider'), isNull);
      expect(controller.validateUsername('ab'), contains('at least 3 characters'));
      expect(controller.validateUsername('invalid space'), contains('letters, numbers, underscores, and periods'));
    });
  });
}
