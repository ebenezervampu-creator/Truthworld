import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/location/location_lookup_service.dart';
import 'package:truthworld/core/services/location/verified_location.dart';
import 'package:truthworld/features/settings/presentation/controllers/edit_profile_controller.dart';
import 'package:truthworld/features/settings/presentation/controllers/user_settings_controller.dart';

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
    Get.put<UserSettingsController>(UserSettingsController());
  });

  tearDown(Get.reset);

  group('EditProfileController - Age Constraints (18–120)', () {
    late EditProfileController controller;

    setUp(() {
      controller = EditProfileController();
      controller.onInit();
    });

    tearDown(() {
      controller.onClose();
    });

    test('accepts valid ages between 18 and 120', () {
      controller.validateAge('18');
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

    test('rejects age less than 18 or non-numeric', () {
      controller.validateAge('17');
      expect(controller.ageErrorText.value, 'Truthworld is for users aged 18 and older');

      controller.validateAge('0');
      expect(controller.ageErrorText.value, 'Truthworld is for users aged 18 and older');

      controller.validateAge('-5');
      expect(controller.ageErrorText.value, 'Truthworld is for users aged 18 and older');

      controller.validateAge('abc');
      expect(controller.ageErrorText.value, 'Please enter a valid numeric age');
    });
  });

  group('EditProfileController - Google Maps Location Tools & Locality Verification', () {
    late EditProfileController controller;

    setUp(() {
      controller = EditProfileController();
      controller.onInit();
    });

    tearDown(() {
      controller.onClose();
    });

    test('parses and sets latitude/longitude coordinates', () async {
      final parsed = await controller.parseAndSetMapLocation('37.7749, -122.4194');
      expect(parsed, isTrue);
      expect(controller.locationController.text, '37.7749, -122.4194');

      final parsed2 = await controller.parseAndSetMapLocation('12.9716, 77.5946');
      expect(parsed2, isTrue);
      expect(controller.locationController.text, '12.9716, 77.5946');
    });

    test('parses and extracts location from Google Maps URL query', () async {
      final parsed = await controller.parseAndSetMapLocation(
        'https://www.google.com/maps?q=Central+Park,+New+York',
      );
      expect(parsed, isTrue);
      expect(controller.locationController.text, 'Central Park, New York');
    });

    test('sets plain text location directly in test mode', () async {
      final parsed = await controller.parseAndSetMapLocation('Paris, France');
      expect(parsed, isTrue);
      expect(controller.locationController.text, 'Paris, France');
    });

    test('selectLocationSuggestion updates controller and marks as verified', () {
      const sampleLoc = VerifiedLocation(
        name: 'Indiranagar',
        localityType: LocalityType.town,
        state: 'Karnataka',
        country: 'India',
        latitude: 12.9784,
        longitude: 77.6408,
        formattedAddress: 'Indiranagar, Bengaluru, Karnataka, India',
      );

      controller.selectLocationSuggestion(sampleLoc);

      expect(controller.locationController.text, 'Indiranagar, Bengaluru, Karnataka, India');
      expect(controller.isLocationVerified.value, isTrue);
      expect(controller.verifiedLocation.value, equals(sampleLoc));
      expect(controller.locationErrorText.value, isNull);
    });

    test('editing location text clears verified status until verified again', () {
      const sampleLoc = VerifiedLocation(
        name: 'Indiranagar',
        localityType: LocalityType.town,
        state: 'Karnataka',
        country: 'India',
        latitude: 12.9784,
        longitude: 77.6408,
        formattedAddress: 'Indiranagar, Bengaluru, Karnataka, India',
      );

      controller.selectLocationSuggestion(sampleLoc);
      expect(controller.isLocationVerified.value, isTrue);

      controller.locationController.text = 'Indiranagar (modified)';
      expect(controller.isLocationVerified.value, isFalse);
    });
  });

  group('LocationLookupService - Coordinate & Maps URL Parsing', () {
    test('parses latitude and longitude from string', () {
      final target = LocationLookupService.parseGoogleMapsUrlOrCoordinates('40.7128, -74.0060');
      expect(target, isNotNull);
      expect(target!.latitude, 40.7128);
      expect(target.longitude, -74.0060);
    });

    test('parses @lat,lon from Google Maps URL', () {
      final target = LocationLookupService.parseGoogleMapsUrlOrCoordinates(
        'https://www.google.com/maps/place/San+Francisco/@37.7749,-122.4194,14z/data=...',
      );
      expect(target, isNotNull);
      expect(target!.latitude, 37.7749);
      expect(target.longitude, -122.4194);
    });

    test('parses query parameter from Google Maps search URL', () {
      final target = LocationLookupService.parseGoogleMapsUrlOrCoordinates(
        'https://maps.google.com/?q=Palo+Alto,+CA',
      );
      expect(target, isNotNull);
      expect(target!.query, 'Palo Alto, CA');
    });
  });

  group('VerifiedLocation - Model & Locality Types', () {
    test('correctly identifies city, town, and village locality types', () {
      expect(LocalityType.fromString('city'), LocalityType.city);
      expect(LocalityType.fromString('pplc'), LocalityType.city);
      expect(LocalityType.fromString('town'), LocalityType.town);
      expect(LocalityType.fromString('village'), LocalityType.village);
      expect(LocalityType.fromString('ppl'), LocalityType.village);
      expect(LocalityType.fromString('hamlet'), LocalityType.hamlet);
    });

    test('serializes and deserializes VerifiedLocation faithfully', () {
      const loc = VerifiedLocation(
        name: 'Oakhurst',
        localityType: LocalityType.town,
        state: 'California',
        county: 'Madera',
        country: 'United States',
        countryCode: 'US',
        latitude: 37.328,
        longitude: -119.649,
        formattedAddress: 'Oakhurst, Madera, California, United States',
      );

      final map = loc.toMap();
      final reconstituted = VerifiedLocation.fromMap(map);

      expect(reconstituted.name, loc.name);
      expect(reconstituted.localityType, loc.localityType);
      expect(reconstituted.formattedAddress, loc.formattedAddress);
      expect(reconstituted.latitude, loc.latitude);
      expect(reconstituted.longitude, loc.longitude);
      expect(reconstituted.typeLabel, 'Town');
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
