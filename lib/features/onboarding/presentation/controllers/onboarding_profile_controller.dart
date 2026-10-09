import 'dart:async';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:truthworld/components/ui/google_onboarding_controller.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/cashfree/cashfree_country_support.dart';
import 'package:truthworld/core/services/currency_localization_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';

/// Controller for the dedicated full-screen user onboarding profile setup.
/// Handles Google profile defaults (avatar, display name, email), custom photo picking & uploading,
/// username validation, country selection, 18+ age group selection, gender selection,
/// and smooth finalization leading directly to the Truthworld Home page.
class OnboardingProfileController extends GoogleOnboardingController {
  late final TextEditingController displayNameController =
      trackTextController(TextEditingController());
  final Rx<String?> displayNameError = Rx<String?>(null);

  final RxString activeAvatarUrl = ''.obs;
  final RxBool isUploadingPhoto = false.obs;

  OnboardingProfileController() {
    displayNameController.addListener(_onDisplayNameChanged);
    _initProfileDefaults();
  }

  @override
  void onInit() {
    super.onInit();
    _initProfileDefaults();
  }

  @override
  void reinitialize() {
    super.reinitialize();
    _initProfileDefaults();
  }

  void _onDisplayNameChanged() {
    if (displayNameError.value != null) {
      displayNameError.value = null;
    }
  }

  /// Initializes Google / Gmail defaults for avatar, display name, handle, and country
  void _initProfileDefaults() {
    try {
      final auth = AuthService.to;
      final currentUser = auth.user;

      // 1. Display Name: from Google user or active profile
      final profileName = auth.userDisplayName.value?.trim();
      final name = (profileName != null && profileName.isNotEmpty && profileName != 'User')
          ? profileName
          : (auth.activeDisplayName.isNotEmpty && auth.activeDisplayName != 'User'
              ? auth.activeDisplayName
              : (currentUser?.displayName ?? ''));
      displayNameController.text = name;

      // 2. Avatar URL: from Google user photoURL or active profile
      final profilePhoto = auth.userPhotoUrl.value?.trim();
      final photo = (profilePhoto != null && profilePhoto.isNotEmpty)
          ? profilePhoto
          : (auth.activePhotoUrl.isNotEmpty
              ? auth.activePhotoUrl
              : (currentUser?.photoURL ?? ''));
      activeAvatarUrl.value = photo;

      // 3. Username: prefill clean handle if empty
      if (usernameController.text.isEmpty) {
        final rawHandle = auth.userHandle.value ?? '';
        if (rawHandle.isNotEmpty && !rawHandle.startsWith('@user_')) {
          usernameController.text = rawHandle.replaceAll('@', '');
        } else if (name.isNotEmpty) {
          // Generate a friendly initial handle from display name
          final slug = name
              .toLowerCase()
              .replaceAll(RegExp('[^a-z0-9_]'), '_')
              .replaceAll(RegExp('_+'), '_');
          if (slug.isNotEmpty) {
            usernameController.text = slug;
          }
        }
      }

      // 4. Country: ensure detected country is pre-selected
      final currentCountry = auth.userCountry.value;
      if (currentCountry != null && currentCountry.trim().isNotEmpty) {
        selectedCountry.value = CashfreeCountrySupport.normalizeCode(currentCountry);
      } else if (Get.isRegistered<CurrencyLocalizationService>()) {
        selectedCountry.value = CurrencyLocalizationService.to.userCountryCode.value;
      } else {
        selectedCountry.value = 'IN';
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'OnboardingProfileController._initProfileDefaults',
      );
    }
  }

  /// Opens image picker (Gallery or Camera) to change profile photo
  Future<void> pickAndChangeAvatar(
    BuildContext context, {
    ImageSource source = ImageSource.gallery,
  }) async {
    final auth = AuthService.to;
    final uid = auth.user?.uid ?? '';
    if (uid.isEmpty) return;

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (pickedFile == null) return;

      isUploadingPhoto.value = true;
      final bytes = await pickedFile.readAsBytes();
      if (bytes.isEmpty) {
        AppSnackbar.warning('Selected image is empty. Please choose another image.');
        return;
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'avatar_${uid}_$timestamp.jpg';
      final storagePath = 'avatars/$uid/$fileName';

      final storageRef = FirebaseStorage.instance.ref().child(storagePath);
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploaderId': uid,
          'category': 'avatar',
          'userId': uid,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      final uploadTask = await storageRef.putData(bytes, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      activeAvatarUrl.value = downloadUrl;
      auth.userPhotoUrl.value = downloadUrl;
      try {
        await auth.user?.updatePhotoURL(downloadUrl);
      } catch (_) {}

      AppSnackbar.success('Profile photo updated successfully!');
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'OnboardingProfileController.pickAndChangeAvatar',
      );
      AppSnackbar.error('Unable to update profile photo. Please try again.');
    } finally {
      isUploadingPhoto.value = false;
    }
  }

  /// Validates inputs, saves profile to Firestore & AuthService, and redirects to Home
  Future<void> finishAndGoToHome(BuildContext context) async {
    final auth = AuthService.to;
    final currentUser = auth.user;
    if (currentUser == null) return;

    // 1. Validate Display Name
    final rawDisplayName = displayNameController.text.trim();
    if (rawDisplayName.isEmpty) {
      displayNameError.value = 'Please enter your display name';
      AppSnackbar.warning('Please enter your display name to continue.');
      return;
    }
    final nameValidation = ContentValidator.validate(
      rawDisplayName,
      fieldName: 'Display Name',
      minLength: 2,
      maxLength: 50,
    );
    if (!nameValidation.isValid) {
      displayNameError.value = nameValidation.message;
      AppSnackbar.warning(nameValidation.message);
      return;
    }
    final cleanDisplayName = ContentValidator.cleanProfanity(rawDisplayName);
    displayNameError.value = null;

    // 2. Validate Username if provided
    String? cleanUsername;
    final rawUsername = usernameController.text.trim().replaceAll('@', '');
    if (rawUsername.isNotEmpty) {
      final err = validateUsername(rawUsername);
      if (err != null) {
        usernameError.value = err;
        AppSnackbar.warning(err);
        return;
      }
      cleanUsername = ContentValidator.cleanProfanity(rawUsername);
      usernameError.value = null;
    }

    // 3. Format Gender Value
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

    // 4. Country Value (defaults to detected country if not chosen)
    final effectiveCountry = selectedCountry.value ??
        (Get.isRegistered<CurrencyLocalizationService>()
            ? CurrencyLocalizationService.to.userCountryCode.value
            : 'IN');

    isSaving.value = true;
    try {
      // 5. Update Firestore profile & Auth state
      await auth.updateUserProfileOnboarding(
        country: effectiveCountry,
        ageGroup: selectedAgeGroup.value,
        gender: genderValue,
        username: cleanUsername,
        displayName: cleanDisplayName,
      );

      // 6. If photo was updated, update user photoURL in Auth
      if (activeAvatarUrl.value.isNotEmpty) {
        try {
          await currentUser.updatePhotoURL(activeAvatarUrl.value);
        } catch (_) {}
      }

      // 7. Synchronize CurrencyLocalizationService with the chosen country
      if (Get.isRegistered<CurrencyLocalizationService>()) {
        CurrencyLocalizationService.to.detectUserCountry();
      }

      // 8. Mark onboarding as completed
      auth.needsOnboarding.value = false;

      AppSnackbar.success('Welcome to Truthworld, $cleanDisplayName!');

      // 9. Navigate directly to Home page of Truthworld
      Get.offAllNamed('/home');
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'OnboardingProfileController.finishAndGoToHome',
      );
      AppSnackbar.error('Unable to complete setup. Please try again.');
    } finally {
      isSaving.value = false;
    }
  }

  /// Skips onboarding with Google defaults and navigates directly to Home
  Future<void> skipAndGoToHome() async {
    final auth = AuthService.to;
    isSaving.value = true;
    try {
      final effectiveCountry = selectedCountry.value ??
          (Get.isRegistered<CurrencyLocalizationService>()
              ? CurrencyLocalizationService.to.userCountryCode.value
              : 'IN');

      await auth.skipUserOnboarding(defaultCountry: effectiveCountry);
      auth.needsOnboarding.value = false;

      Get.offAllNamed('/home');
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'OnboardingProfileController.skipAndGoToHome',
      );
      Get.offAllNamed('/home');
    } finally {
      isSaving.value = false;
    }
  }
}
