import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/google_onboarding_controller.dart';
import 'package:truthworld/core/services/auth_service.dart';

import '../test_helpers/mock_firebase.dart';

void main() {
  setUpAll(() async {
    await setupMockFirebase();
  });

  setUp(() {
    Get.reset();
    Get.testMode = true;
    Get.put<AuthService>(AuthService());
  });

  tearDown(Get.reset);

  group('GoogleOnboardingController - Matching & Inferences', () {
    late GoogleOnboardingController controller;

    setUp(() {
      controller = GoogleOnboardingController();
    });

    tearDown(() {
      controller.onClose();
    });

    test('matches age groups exactly and case-insensitively', () {
      expect(controller.matchAgeGroup('18–24'), '18–24');
      expect(controller.matchAgeGroup('18-24'), '18–24');
      expect(controller.matchAgeGroup('65+'), '65+');
      expect(controller.matchAgeGroup('Prefer not to say'), 'Prefer not to say');
    });

    test('matches age groups with ASCII hyphen and en-dash variants', () {
      // ASCII hyphen matches unicode en-dash option
      expect(controller.matchAgeGroup('45-54'), '45–54');
      expect(controller.matchAgeGroup('45–54'), '45–54');
      expect(controller.matchAgeGroup('18-24'), '18–24');
      expect(controller.matchAgeGroup('18–24'), '18–24');
      expect(controller.matchAgeGroup(' 25 - 34 '), '25–34');
    });

    test('infers age group from numeric age starting from 18 years and not below', () {
      expect(controller.inferAgeGroupFromAge(10), isNull);
      expect(controller.inferAgeGroupFromAge(15), isNull);
      expect(controller.inferAgeGroupFromAge(17), isNull);
      expect(controller.inferAgeGroupFromAge(18), '18–24');
      expect(controller.inferAgeGroupFromAge(21), '18–24');
      expect(controller.inferAgeGroupFromAge(30), '25–34');
      expect(controller.inferAgeGroupFromAge(40), '35–44');
      expect(controller.inferAgeGroupFromAge(48), '45–54');
      expect(controller.inferAgeGroupFromAge(60), '55–64');
      expect(controller.inferAgeGroupFromAge(70), '65+');
    });
  });

  group('GoogleOnboardingController - Pre-selection from AuthService', () {
    test('pre-selects age group and gender when saved in AuthService', () {
      final auth = AuthService.to;
      auth.userAgeGroup.value = '45–54';
      auth.userGender.value = 'Male';

      final controller = GoogleOnboardingController();
      expect(controller.selectedAgeGroup.value, '45–54');
      expect(controller.selectedGender.value, 'Male');
      expect(controller.selfDescribeController.text, isEmpty);

      controller.onClose();
    });

    test('pre-selects age group when stored with ASCII hyphen', () {
      final auth = AuthService.to;
      auth.userAgeGroup.value = '45-54'; // ASCII hyphen
      auth.userGender.value = 'Female';

      final controller = GoogleOnboardingController();
      expect(controller.selectedAgeGroup.value, '45–54');
      expect(controller.selectedGender.value, 'Female');

      controller.onClose();
    });

    test('falls back to numeric userAge when userAgeGroup is not set', () {
      final auth = AuthService.to;
      auth.userAgeGroup.value = null;
      auth.userAge.value = 50;
      auth.userGender.value = 'Non-binary';

      final controller = GoogleOnboardingController();
      expect(controller.selectedAgeGroup.value, '45–54');
      expect(controller.selectedGender.value, 'Non-binary');

      controller.onClose();
    });

    test('parses Self-describe gender with custom description', () {
      final auth = AuthService.to;
      auth.userAgeGroup.value = '25–34';
      auth.userGender.value = 'Self-describe: Two-spirit';

      final controller = GoogleOnboardingController();
      expect(controller.selectedAgeGroup.value, '25–34');
      expect(controller.selectedGender.value, 'Self-describe');
      expect(controller.selfDescribeController.text, 'Two-spirit');

      controller.onClose();
    });

    test('parses custom non-standard gender into Self-describe', () {
      final auth = AuthService.to;
      auth.userGender.value = 'Other';

      final controller = GoogleOnboardingController();
      expect(controller.selectedGender.value, 'Self-describe');
      expect(controller.selfDescribeController.text, 'Other');

      controller.onClose();
    });

    test('allows updating and deselecting age group and gender', () {
      final auth = AuthService.to;
      auth.userAgeGroup.value = '45–54';
      auth.userGender.value = 'Male';

      final controller = GoogleOnboardingController();
      expect(controller.selectedAgeGroup.value, '45–54');

      // Change age group
      controller.selectAgeGroup('55–64');
      expect(controller.selectedAgeGroup.value, '55–64');

      // Deselect age group
      controller.selectAgeGroup(null);
      expect(controller.selectedAgeGroup.value, isNull);

      // Deselect gender
      controller.selectGender(null);
      expect(controller.selectedGender.value, isNull);

      controller.onClose();
    });
  });

  group('GoogleOnboardingController - Phone User & Username Handling', () {
    late GoogleOnboardingController controller;

    setUp(() {
      controller = GoogleOnboardingController();
    });

    tearDown(() {
      controller.onClose();
    });

    test('validates valid usernames correctly', () {
      expect(controller.validateUsername(''), isNull);
      expect(controller.validateUsername('alex'), isNull);
      expect(controller.validateUsername('alex_rider'), isNull);
      expect(controller.validateUsername('user.name_123'), isNull);
      expect(controller.validateUsername('@alex_rider'), isNull);
    });

    test('rejects usernames with invalid characters or spaces', () {
      expect(controller.validateUsername('alex rider'), contains('letters, numbers, underscores, and periods'));
      expect(controller.validateUsername('alex!rider'), contains('letters, numbers, underscores, and periods'));
      expect(controller.validateUsername('alex#123'), contains('letters, numbers, underscores, and periods'));
    });

    test('rejects usernames that are too short or too long', () {
      expect(controller.validateUsername('ab'), contains('at least 3 characters'));
      expect(controller.validateUsername('a' * 31), contains('cannot exceed 30 characters'));
    });

    test('rejects profane usernames', () {
      final err = controller.validateUsername('fuck_you');
      expect(err, isNotNull);
      expect(err, contains('inappropriate language'));
    });

    test('clears usernameError when username text changes', () {
      controller.usernameError.value = 'Invalid username';
      expect(controller.usernameError.value, isNotNull);

      controller.usernameController.text = 'valid_name';
      expect(controller.usernameError.value, isNull);
    });

    test('does not prefill default @user_XXXX handle during reinitialize', () {
      final auth = AuthService.to;
      auth.userHandle.value = '@user_1234';

      controller.reinitialize();
      expect(controller.usernameController.text, isEmpty);
    });

    test('prefills custom handle during reinitialize', () {
      final auth = AuthService.to;
      auth.userHandle.value = '@custom_creator';

      controller.reinitialize();
      expect(controller.usernameController.text, 'custom_creator');
    });
  });

  group('GoogleOnboardingController - Country Selection', () {
    late GoogleOnboardingController controller;

    setUp(() {
      controller = GoogleOnboardingController();
    });

    tearDown(() {
      controller.onClose();
    });

    test('initializes country from AuthService userCountry when set', () {
      final auth = AuthService.to;
      auth.userCountry.value = 'US';
      controller.reinitialize();

      expect(controller.selectedCountry.value, 'US');
    });

    test('allows changing and selecting country code', () {
      controller.selectCountry('GB');
      expect(controller.selectedCountry.value, 'GB');

      controller.selectCountry('India');
      expect(controller.selectedCountry.value, 'IN');
    });

    test('countryOptions includes popular supported countries and flag emojis', () {
      final options = controller.countryOptions;
      expect(options.any((c) => c.code == 'IN'), isTrue);
      expect(options.any((c) => c.code == 'US'), isTrue);
      expect(options.first.flagEmoji, isNotEmpty);
    });
  });
}
