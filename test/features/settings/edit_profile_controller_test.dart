import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/settings/presentation/controllers/edit_profile_controller.dart';

import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    await setupMockFirebase();
    tempDir = Directory.systemTemp.createTempSync('tw_settings_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (methodCall) async => tempDir.path,
    );
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  setUp(() {
    Get.reset();
    Get.testMode = true;
    Get.put<AuthService>(AuthService());
  });

  tearDown(Get.reset);

  group('EditProfileController - Age Constraints (1–120)', () {
    late EditProfileController controller;

    setUp(() {
      controller = EditProfileController();
      controller.onInit();
    });

    tearDown(() {
      controller.onClose();
    });

    test('accepts valid ages between 1 and 120', () {
      controller.validateAge('1');
      expect(controller.ageErrorText.value, isNull);

      controller.validateAge('25');
      expect(controller.ageErrorText.value, isNull);

      controller.validateAge('120');
      expect(controller.ageErrorText.value, isNull);

      // Empty is allowed (optional field)
      controller.validateAge('');
      expect(controller.ageErrorText.value, isNull);
    });

    test('rejects age greater than 120', () {
      controller.validateAge('121');
      expect(controller.ageErrorText.value, 'Age cannot exceed 120 years');

      controller.validateAge('150');
      expect(controller.ageErrorText.value, 'Age cannot exceed 120 years');

      controller.validateAge('999');
      expect(controller.ageErrorText.value, 'Age cannot exceed 120 years');
    });

    test('rejects age less than 1 or non-numeric', () {
      controller.validateAge('0');
      expect(controller.ageErrorText.value, 'Age must be at least 1 year');

      controller.validateAge('-5');
      expect(controller.ageErrorText.value, 'Age must be at least 1 year');

      controller.validateAge('abc');
      expect(controller.ageErrorText.value, 'Please enter a valid numeric age');
    });
  });

  group('EditProfileController - Google Maps Location Tools', () {
    late EditProfileController controller;

    setUp(() {
      controller = EditProfileController();
      controller.onInit();
    });

    tearDown(() {
      controller.onClose();
    });

    test('parses and sets latitude/longitude coordinates', () {
      final parsed = controller.parseAndSetMapLocation('37.7749, -122.4194');
      expect(parsed, isTrue);
      expect(controller.locationController.text, '37.7749, -122.4194');

      final parsed2 = controller.parseAndSetMapLocation('12.9716, 77.5946');
      expect(parsed2, isTrue);
      expect(controller.locationController.text, '12.9716, 77.5946');
    });

    test('parses and extracts location from Google Maps URL query', () {
      final parsed = controller.parseAndSetMapLocation(
        'https://www.google.com/maps?q=Central+Park,+New+York',
      );
      expect(parsed, isTrue);
      expect(controller.locationController.text, 'Central Park, New York');
    });

    test('sets plain text location directly', () {
      final parsed = controller.parseAndSetMapLocation('Paris, France');
      expect(parsed, isTrue);
      expect(controller.locationController.text, 'Paris, France');
    });
  });

  group('EditProfileController - Profanity Sanitization & Validation for User Names', () {
    late EditProfileController controller;

    setUp(() {
      controller = EditProfileController();
      controller.onInit();
    });

    tearDown(() {
      controller.onClose();
    });

    test('sanitizes liveDisplayName in real-time when typing profanity', () {
      controller.nameController.text = 'fuck';
      expect(controller.liveDisplayName.value.contains('fuck'), isFalse);
      expect(controller.liveDisplayName.value, contains('*'));

      controller.nameController.text = 'José Müller';
      expect(controller.liveDisplayName.value, 'José Müller');
    });

    test('saveProfile blocks profanity in display name', () async {
      controller.nameController.text = 'John shit';
      await controller.saveProfile();
      expect(controller.isSaving.value, isFalse);
    });

    test('saveProfile blocks profanity in handle', () async {
      controller.nameController.text = 'Clean Name';
      controller.handleController.text = 'shit';
      await controller.saveProfile();
      expect(controller.isSaving.value, isFalse);
    });
  });
}
