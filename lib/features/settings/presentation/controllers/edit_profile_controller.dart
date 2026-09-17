import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/settings/presentation/controllers/user_settings_controller.dart';
import 'package:url_launcher/url_launcher.dart';

/// Controller for the Edit Profile Details screen.
/// Enforces age constraint (1–120) and provides Google Maps location integration.
class EditProfileController extends BaseController {
  static EditProfileController get to => Get.find<EditProfileController>();

  late final TextEditingController nameController;
  late final TextEditingController handleController;
  late final TextEditingController bioController;
  late final TextEditingController ageController;
  late final TextEditingController locationController;

  final RxString liveDisplayName = ''.obs;
  final RxString selectedGender = 'Prefer not to say'.obs;
  final RxList<String> genderOptions = <String>[
    'Male',
    'Female',
    'Non-binary',
    'Other',
    'Prefer not to say',
  ].obs;

  final RxnString ageErrorText = RxnString();
  final RxBool isDetectingLocation = false.obs;
  final RxBool isSaving = false.obs;

  @override
  void onInit() {
    super.onInit();
    final auth = AuthService.to;
    nameController = trackTextController(TextEditingController(text: auth.activeDisplayName));
    liveDisplayName.value = ContentValidator.cleanProfanity(auth.activeDisplayName);
    nameController.addListener(() {
      final text = nameController.text.trim();
      final cleaned = ContentValidator.cleanProfanity(text);
      liveDisplayName.value = cleaned.isNotEmpty ? cleaned : auth.activeDisplayName;
    });

    handleController = trackTextController(TextEditingController(
      text: auth.activeHandle.replaceAll('@', ''),
    ));

    bioController = trackTextController(TextEditingController(
      text: auth.activeBio.isNotEmpty
          ? auth.activeBio
          : (auth.userChannel?.description ?? ''),
    ));

    final initialAge = auth.userAge.value;
    ageController = trackTextController(TextEditingController(
      text: initialAge != null ? initialAge.toString() : '',
    ));
    ageController.addListener(() {
      validateAge(ageController.text);
    });

    locationController = trackTextController(TextEditingController(
      text: auth.userLocation.value ?? '',
    ));

    final currentGender = auth.userGender.value;
    if (currentGender != null && currentGender.isNotEmpty) {
      if (!genderOptions.contains(currentGender)) {
        genderOptions.add(currentGender);
      }
      selectedGender.value = currentGender;
    }
  }

  /// Real-time validation for user age (1–120 years)
  void validateAge(String val) {
    final clean = val.trim();
    if (clean.isEmpty) {
      ageErrorText.value = null;
      return;
    }

    final parsed = int.tryParse(clean);
    if (parsed == null) {
      ageErrorText.value = 'Please enter a valid numeric age';
    } else if (parsed < 1) {
      ageErrorText.value = 'Age must be at least 1 year';
    } else if (parsed > 120) {
      ageErrorText.value = 'Age cannot exceed 120 years';
    } else {
      ageErrorText.value = null;
    }
  }

  /// Launches Google Maps to view, find, or share exact location pin
  Future<void> openGoogleMaps() async {
    final query = locationController.text.trim();
    final Uri mapUri;
    if (query.isNotEmpty) {
      mapUri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}',
      );
    } else {
      mapUri = Uri.parse('https://maps.google.com');
    }

    try {
      final launched = await launchUrl(
        mapUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        AppSnackbar.warning('Could not launch Google Maps');
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'EditProfileController.openGoogleMaps',
      );
      AppSnackbar.warning('Could not open Google Maps');
    }
  }

  /// Detects current city & country via IP / network geolocation
  Future<void> detectCurrentLocation() async {
    if (isDetectingLocation.value) return;

    isDetectingLocation.value = true;
    try {
      final response = await http
          .get(
            Uri.parse(
              'http://ip-api.com/json/?fields=status,country,regionName,city',
            ),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['status'] == 'success') {
          final city = data['city'] as String? ?? '';
          final country = data['country'] as String? ?? '';
          final region = data['regionName'] as String? ?? '';

          var resolved = '';
          if (city.isNotEmpty && country.isNotEmpty) {
            resolved = '$city, $country';
          } else if (city.isNotEmpty && region.isNotEmpty) {
            resolved = '$city, $region';
          } else if (country.isNotEmpty) {
            resolved = country;
          }

          if (resolved.isNotEmpty) {
            locationController.text = resolved;
            AppSnackbar.success('Current location detected: $resolved');
          } else {
            AppSnackbar.warning('Could not resolve location details');
          }
        } else {
          AppSnackbar.warning('Failed to detect location from network');
        }
      } else {
        AppSnackbar.warning('Location service is currently unavailable');
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'EditProfileController.detectCurrentLocation',
      );
      AppSnackbar.warning('Unable to detect location. Please enter your location manually.');
    } finally {
      isDetectingLocation.value = false;
    }
  }

  void _notifySuccess(String message) {
    if (!Get.testMode) {
      AppSnackbar.success(message);
    }
  }

  void _notifyWarning(String message) {
    if (!Get.testMode) {
      AppSnackbar.warning(message);
    }
  }

  /// Parses pasted coordinates or Google Maps share links and sets location
  bool parseAndSetMapLocation(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return false;

    // Pattern 1: Lat, Lng coordinates (e.g. "37.7749, -122.4194" or "12.9716,77.5946")
    final coordRegExp = RegExp(r'^[+-]?\d+(?:\.\d+)?\s*,\s*[+-]?\d+(?:\.\d+)?$');
    if (coordRegExp.hasMatch(trimmed)) {
      locationController.text = trimmed;
      _notifySuccess('Coordinates applied: $trimmed');
      return true;
    }

    // Pattern 2: Google Maps URL query parameter
    try {
      final uri = Uri.tryParse(trimmed);
      if (uri != null && uri.host.contains('google')) {
        final qParam = uri.queryParameters['q'] ??
            uri.queryParameters['query'] ??
            uri.queryParameters['destination'];
        if (qParam != null && qParam.isNotEmpty) {
          locationController.text = qParam;
          _notifySuccess('Location extracted from Google Maps: $qParam');
          return true;
        }
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'EditProfileController.parseGoogleMapsUrl',
      );
    }

    // Fallback: Use directly as location text
    locationController.text = trimmed;
    _notifySuccess('Location updated: $trimmed');
    return true;
  }

  /// Validates and saves profile details
  Future<void> saveProfile() async {
    final newName = nameController.text.trim();
    final newHandle = '@${handleController.text.trim().replaceAll('@', '')}';
    final newBio = bioController.text.trim();
    final newLocation = locationController.text.trim();
    final rawAge = ageController.text.trim();

    // 1. Display Name validation
    final nameRes = ContentValidator.validate(
      newName,
      fieldName: 'Display Name',
      checkEnglishOnly: false,
    );
    if (!nameRes.isValid) {
      _notifyWarning(nameRes.message);
      return;
    }

    // 2. Handle validation
    final handleRes = ContentValidator.validate(newHandle, fieldName: 'Handle');
    if (!handleRes.isValid) {
      _notifyWarning(handleRes.message);
      return;
    }

    // 3. Bio validation
    if (newBio.isNotEmpty) {
      final bioRes = ContentValidator.validate(newBio, fieldName: 'Bio');
      if (!bioRes.isValid) {
        _notifyWarning(bioRes.message);
        return;
      }
    }

    // 4. Age validation (Max 120, Min 1)
    int? parsedAge;
    if (rawAge.isNotEmpty) {
      parsedAge = int.tryParse(rawAge);
      if (parsedAge == null || parsedAge < 1 || parsedAge > 120) {
        ageErrorText.value = 'Age cannot exceed 120 years';
        _notifyWarning('Age must be between 1 and 120 years');
        return;
      }
    }

    // 5. Location validation
    if (newLocation.isNotEmpty) {
      final locRes = ContentValidator.validate(newLocation, fieldName: 'Location');
      if (!locRes.isValid) {
        _notifyWarning(locRes.message);
        return;
      }
    }

    isSaving.value = true;
    try {
      final settingsCtrl = UserSettingsController.to;
      final success = await settingsCtrl.updateProfileDetails(
        displayName: newName,
        handle: newHandle,
        bio: newBio,
        gender: selectedGender.value,
        age: parsedAge,
        location: newLocation,
      );

      if (success) {
        Get.back();
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'EditProfileController.saveProfile',
      );
      _notifyWarning('Failed to save profile. Please try again.');
    } finally {
      isSaving.value = false;
    }
  }

}
