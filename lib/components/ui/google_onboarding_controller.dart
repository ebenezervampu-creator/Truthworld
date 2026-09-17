import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';

/// Controller managing state and actions for the age group & gender selection sheet.
class GoogleOnboardingController extends BaseController {
  final Rx<String?> selectedAgeGroup = Rx<String?>(null);
  final Rx<String?> selectedGender = Rx<String?>(null);
  final RxBool isSaving = false.obs;
  late final TextEditingController selfDescribeController = trackTextController(TextEditingController());

  static const List<String> ageGroupOptions = [
    'Under 13',
    '13–17',
    '18–24',
    '25–34',
    '35–44',
    '45–54',
    '55–64',
    '65+',
    'Prefer not to say',
  ];

  static const List<String> genderOptions = [
    'Male',
    'Female',
    'Non-binary',
    'Prefer not to say',
    'Self-describe',
  ];

  List<String> get ageGroups => ageGroupOptions;
  List<String> get genders => genderOptions;

  /// Returns true if user is in first-time onboarding mode
  bool get isFirstTimeOnboarding {
    try {
      if (Get.isRegistered<AuthService>()) {
        return AuthService.to.needsOnboarding.value;
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'GoogleOnboardingController.isFirstTimeOnboarding',
      );
    }
    return false;
  }

  GoogleOnboardingController() {
    reinitialize();
  }

  @override
  void onInit() {
    super.onInit();
    reinitialize();
  }

  /// Populates the selected state from AuthService
  void reinitialize() {
    try {
      if (!Get.isRegistered<AuthService>()) return;
      final auth = AuthService.to;

      // 1. Initialize Age Group
      final currentAgeGroup = auth.userAgeGroup.value;
      if (currentAgeGroup != null && currentAgeGroup.trim().isNotEmpty) {
        selectedAgeGroup.value = matchAgeGroup(currentAgeGroup);
      } else if (auth.userAge.value != null) {
        selectedAgeGroup.value = inferAgeGroupFromAge(auth.userAge.value!);
      } else {
        selectedAgeGroup.value = null;
      }

      // 2. Initialize Gender
      final currentGender = auth.userGender.value;
      if (currentGender != null && currentGender.trim().isNotEmpty) {
        final trimmedGender = currentGender.trim();
        if (trimmedGender.toLowerCase().startsWith('self-describe:')) {
          selectedGender.value = 'Self-describe';
          selfDescribeController.text =
              trimmedGender.substring('self-describe:'.length).trim();
        } else if (trimmedGender.toLowerCase() == 'self-describe') {
          selectedGender.value = 'Self-describe';
          selfDescribeController.text = '';
        } else {
          final matchedGender = genderOptions.firstWhereOrNull(
            (g) => g.toLowerCase() == trimmedGender.toLowerCase(),
          );
          if (matchedGender != null) {
            selectedGender.value = matchedGender;
            selfDescribeController.text = '';
          } else {
            // Custom gender (e.g. 'Other' from edit profile dialog or external source)
            selectedGender.value = 'Self-describe';
            selfDescribeController.text = trimmedGender;
          }
        }
      } else {
        selectedGender.value = null;
        selfDescribeController.text = '';
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'GoogleOnboardingController.reinitialize',
      );
    }
  }

  /// Robust matching for age group strings, handling dashes/hyphens and case differences
  String? matchAgeGroup(String raw) {
    final clean = raw.trim();
    if (clean.isEmpty) return null;

    // 1. Exact or case-insensitive match
    for (final opt in ageGroupOptions) {
      if (opt.toLowerCase() == clean.toLowerCase()) {
        return opt;
      }
    }

    // 2. Dash/hyphen normalized matching (handles Unicode \u2010-\u2015, \u2212, and ASCII -)
    String normalizeDashes(String s) =>
        s.replaceAll(RegExp(r'[\u2010-\u2015\u2212\-]'), '-').replaceAll(RegExp(r'\s+'), '');

    final normalizedClean = normalizeDashes(clean).toLowerCase();
    for (final opt in ageGroupOptions) {
      if (normalizeDashes(opt).toLowerCase() == normalizedClean) {
        return opt;
      }
    }

    return null;
  }

  /// Incurs age group from numeric age
  String? inferAgeGroupFromAge(int age) {
    if (age < 13) return 'Under 13';
    if (age <= 17) return '13–17';
    if (age <= 24) return '18–24';
    if (age <= 34) return '25–34';
    if (age <= 44) return '35–44';
    if (age <= 54) return '45–54';
    if (age <= 64) return '55–64';
    return '65+';
  }

  void selectAgeGroup(String? group) {
    selectedAgeGroup.value = group;
  }

  void selectGender(String? gender) {
    selectedGender.value = gender;
  }

  Future<void> onSave(BuildContext context) async {
    final navigator = Navigator.of(context);

    try {
      String? genderValue;
      final selectedGenderVal = selectedGender.value;
      if (selectedGenderVal != null) {
        if (selectedGenderVal == 'Self-describe') {
          final customText = selfDescribeController.text.trim();
          if (customText.isNotEmpty) {
            final validation = ContentValidator.validate(
              customText,
              fieldName: 'Self-description',
            );
            if (!validation.isValid) {
              AppSnackbar.warning(validation.message);
              return;
            }
            final cleanedCustomText = ContentValidator.cleanProfanity(customText);
            genderValue = 'Self-describe: $cleanedCustomText';
          } else {
            genderValue = 'Self-describe';
          }
        } else {
          genderValue = selectedGenderVal;
        }
      }

      isSaving.value = true;

      await AuthService.to.updateUserProfileOnboarding(
        ageGroup: selectedAgeGroup.value,
        gender: genderValue,
      );

      if (context.mounted) {
        navigator.pop();
      }
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error('Unable to save your profile. Please try again.');
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> onSkip(BuildContext context) async {
    isSaving.value = true;
    final navigator = Navigator.of(context);

    try {
      if (isFirstTimeOnboarding) {
        await AuthService.to.skipUserOnboarding();
      }
      if (context.mounted) {
        navigator.pop();
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'GoogleOnboardingController.onSkip',
      );
      if (context.mounted) {
        navigator.pop();
      }
    } finally {
      isSaving.value = false;
    }
  }

}
