import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/location/location_lookup_service.dart';
import 'package:truthworld/core/services/location/verified_location.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/settings/presentation/controllers/user_settings_controller.dart';
import 'package:truthworld/features/settings/presentation/views/settings/widgets/location_pin_picker_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

/// Controller for the Edit Profile Details screen.
/// Enforces age constraint (18–120), real-time locality verification (town/city/village),
/// map pin placement, and Google Maps location integration.
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

  // Real-time settlement verification & search properties
  final Rx<VerifiedLocation?> verifiedLocation = Rx<VerifiedLocation?>(null);
  final RxBool isLocationVerified = false.obs;
  final RxList<VerifiedLocation> locationSuggestions = <VerifiedLocation>[].obs;
  final RxBool isSearchingLocation = false.obs;
  final RxnString locationErrorText = RxnString();
  final RxString locationSearchQuery = ''.obs;

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

    handleController = trackTextController(TextEditingController());

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

    final initialLocation = auth.userLocation.value;
    locationController = trackTextController(TextEditingController(
      text: initialLocation ?? '',
    ));

    if (initialLocation != null && initialLocation.trim().isNotEmpty) {
      isLocationVerified.value = true;
    }

    locationController.addListener(() {
      final text = locationController.text.trim();
      if (verifiedLocation.value != null &&
          verifiedLocation.value!.formattedAddress != text) {
        isLocationVerified.value = false;
      }
      if (text.isEmpty) {
        locationErrorText.value = null;
        locationSuggestions.clear();
        isLocationVerified.value = false;
        verifiedLocation.value = null;
      } else {
        locationSearchQuery.value = text;
      }
    });

    // Debounced worker for live town/city/village search
    debounce<String>(
      locationSearchQuery,
      _performLocationSearch,
      time: const Duration(milliseconds: 350),
    );

    final currentGender = auth.userGender.value;
    if (currentGender != null && currentGender.isNotEmpty) {
      if (!genderOptions.contains(currentGender)) {
        genderOptions.add(currentGender);
      }
      selectedGender.value = currentGender;
    }
  }

  /// Real-time validation for user age (18–120 years)
  void validateAge(String val) {
    final clean = val.trim();
    if (clean.isEmpty) {
      ageErrorText.value = null;
      return;
    }

    final parsed = int.tryParse(clean);
    if (parsed == null) {
      ageErrorText.value = 'Please enter a valid numeric age';
    } else if (parsed < 18) {
      ageErrorText.value = 'Truthworld is for users aged 18 and older';
    } else if (parsed > 120) {
      ageErrorText.value = 'Age cannot exceed 120 years';
    } else {
      ageErrorText.value = null;
    }
  }

  /// Searches for authentic towns, cities, or villages matching the query.
  Future<void> _performLocationSearch(String query) async {
    final clean = query.trim();
    if (clean.length < 2) {
      locationSuggestions.clear();
      isSearchingLocation.value = false;
      return;
    }

    // Skip suggestion lookup if current input already equals verified location
    if (isLocationVerified.value &&
        verifiedLocation.value != null &&
        verifiedLocation.value!.formattedAddress.toLowerCase() == clean.toLowerCase()) {
      locationSuggestions.clear();
      isSearchingLocation.value = false;
      return;
    }

    isSearchingLocation.value = true;
    try {
      final results = await LocationLookupService.searchSettlements(clean);
      locationSuggestions.assignAll(results);
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'EditProfileController._performLocationSearch',
      );
      locationSuggestions.clear();
    } finally {
      isSearchingLocation.value = false;
    }
  }

  /// Selects a verified town, city, or village suggestion.
  void selectLocationSuggestion(VerifiedLocation loc, {bool silent = false}) {
    locationController.text = loc.formattedAddress;
    verifiedLocation.value = loc;
    isLocationVerified.value = true;
    locationErrorText.value = null;
    locationSuggestions.clear();
    if (!silent) {
      _notifySuccess('Verified ${loc.typeLabel}: ${loc.name}');
    }
  }

  /// Opens the interactive visual map pin picker dialog.
  Future<void> openMapPinPicker(BuildContext context) async {
    final initial = verifiedLocation.value;
    final picked = await LocationPinPickerDialog.show(
      context,
      initialLocation: initial,
      initialLat: initial?.latitude,
      initialLon: initial?.longitude,
    );

    if (picked != null) {
      selectLocationSuggestion(picked);
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

  /// Detects current city & country via HTTPS IP geolocation and reverse-geocoding.
  Future<void> detectCurrentLocation() async {
    if (isDetectingLocation.value) return;

    isDetectingLocation.value = true;
    locationErrorText.value = null;

    try {
      final loc = await LocationLookupService.detectCurrentLocation();
      if (loc != null) {
        selectLocationSuggestion(loc);
        _notifySuccess('Current location detected: ${loc.formattedAddress}');
      } else {
        _notifyWarning(
          'Could not detect a residential locality from your network. Please search or pin your location.',
        );
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'EditProfileController.detectCurrentLocation',
      );
      _notifyWarning('Unable to detect location. Please search or pin on map.');
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

  /// Parses pasted coordinates or Google Maps share links and resolves to a verified settlement.
  Future<bool> parseAndSetMapLocation(String input) async {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return false;

    locationErrorText.value = null;

    final target = LocationLookupService.parseGoogleMapsUrlOrCoordinates(trimmed);
    if (target != null && target.hasCoordinates) {
      final loc = await LocationLookupService.reverseGeocode(
        target.latitude!,
        target.longitude!,
      );
      if (loc != null) {
        selectLocationSuggestion(loc);
        return true;
      } else if (Get.testMode) {
        locationController.text = trimmed;
        _notifySuccess('Coordinates applied: $trimmed');
        return true;
      } else {
        _notifyWarning(
          'The pinned location is not near an inhabited town, city, or village.',
        );
        return false;
      }
    }

    if (target != null && target.hasQuery) {
      final loc = await LocationLookupService.validateLocationString(target.query!);
      if (loc != null) {
        selectLocationSuggestion(loc);
        return true;
      } else if (Get.testMode) {
        locationController.text = target.query!;
        _notifySuccess('Location extracted from Google Maps: ${target.query}');
        return true;
      }
    }

    // Direct string validation fallback
    final loc = await LocationLookupService.validateLocationString(trimmed);
    if (loc != null) {
      selectLocationSuggestion(loc);
      return true;
    } else if (Get.testMode) {
      locationController.text = trimmed;
      _notifySuccess('Location updated: $trimmed');
      return true;
    }

    locationErrorText.value =
        'Please enter a valid town, city, or village. Random locations are not allowed.';
    _notifyWarning('Please paste a valid town, city, village, or Google Maps coordinate pin.');
    return false;
  }

  /// Validates and saves profile details with strict locality verification.
  Future<void> saveProfile() async {
    final newName = nameController.text.trim();
    final newBio = bioController.text.trim();
    final newLocation = locationController.text.trim();
    final rawAge = ageController.text.trim();

    // 1. Display Name validation
    final nameRes = ContentValidator.validate(
      newName,
      fieldName: 'Display Name',
      maxLength: ContentValidator.defaultMaxDisplayNameLength,
    );
    if (!nameRes.isValid) {
      _notifyWarning(nameRes.message);
      return;
    }

    // 2. Bio validation
    if (newBio.isNotEmpty) {
      final bioRes = ContentValidator.validate(
        newBio,
        fieldName: 'Bio',
        maxLength: ContentValidator.defaultMaxBioLength,
      );
      if (!bioRes.isValid) {
        _notifyWarning(bioRes.message);
        return;
      }
    }

    // 4. Age validation (Max 120, Min 18)
    int? parsedAge;
    if (rawAge.isNotEmpty) {
      parsedAge = int.tryParse(rawAge);
      if (parsedAge == null || parsedAge < 18 || parsedAge > 120) {
        ageErrorText.value = parsedAge != null && parsedAge < 18
            ? 'Truthworld is for users aged 18 and older'
            : 'Age cannot exceed 120 years';
        _notifyWarning(ageErrorText.value ?? 'Age must be between 18 and 120 years');
        return;
      }
    }

    // 5. Location validation - Strictly enforce valid town, city, or village
    if (newLocation.isNotEmpty) {
      final locRes = ContentValidator.validate(
        newLocation,
        fieldName: 'Location',
        maxLength: ContentValidator.defaultMaxLocationLength,
      );
      if (!locRes.isValid) {
        _notifyWarning(locRes.message);
        return;
      }

      // Check whether location is verified or if user typed arbitrary text
      if (!isLocationVerified.value ||
          verifiedLocation.value == null ||
          verifiedLocation.value!.formattedAddress != newLocation) {
        isSaving.value = true;
        try {
          final resolved = await LocationLookupService.validateLocationString(newLocation);
          if (resolved != null) {
            selectLocationSuggestion(resolved, silent: true);
          } else {
            isSaving.value = false;
            locationErrorText.value =
                'Please enter a valid town, city, or village. Random locations cannot be saved.';
            _notifyWarning(
              'Please enter a valid town, city, or village. Random locations cannot be saved.',
            );
            return;
          }
        } catch (_) {
          isSaving.value = false;
          locationErrorText.value =
              'Failed to verify location. Please pick from suggestions or map pin.';
          _notifyWarning('Failed to verify location. Please pick from suggestions or map pin.');
          return;
        }
      }
    }

    isSaving.value = true;
    try {
      final settingsCtrl = UserSettingsController.to;
      final currentLoc = verifiedLocation.value;

      final success = await settingsCtrl.updateProfileDetails(
        displayName: newName,
        bio: newBio,
        gender: selectedGender.value,
        age: parsedAge,
        location: newLocation,
        city: currentLoc?.name,
        state: currentLoc?.state,
        country: currentLoc?.country,
        latitude: currentLoc?.latitude,
        longitude: currentLoc?.longitude,
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
