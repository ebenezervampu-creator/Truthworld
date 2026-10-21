import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/cashfree/cashfree_country_support.dart';
import 'package:truthworld/core/services/currency_localization_service.dart';
import 'package:truthworld/core/services/user_languages_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/video/data/models/ai_features.dart';

/// Controller managing state and actions for the country, age group & gender selection sheet.
class GoogleOnboardingController extends BaseController {
  final Rx<String?> selectedCountry = Rx<String?>(null);
  final Rx<String?> selectedAgeGroup = Rx<String?>(null);
  final Rx<String?> selectedGender = Rx<String?>(null);
  final RxString selectedLanguage = 'English'.obs;
  late final TextEditingController languageSearchController = trackTextController(TextEditingController());
  final RxString languageSearchQuery = ''.obs;
  final RxBool isSaving = false.obs;
  late final TextEditingController selfDescribeController = trackTextController(TextEditingController());
  late final TextEditingController usernameController = trackTextController(TextEditingController());
  final Rx<String?> usernameError = Rx<String?>(null);
  bool _isClosing = false;

  /// Age groups starting from 18 years and above (Truthworld is exclusively 18+)
  static const List<String> ageGroupOptions = [
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

  /// Filtered languages for primary language onboarding selection.
  /// English is always positioned first as the canonical platform language.
  List<TranslationLanguage> get filteredLanguages {
    final query = languageSearchQuery.value.trim().toLowerCase();
    final english = supportedLanguages.firstWhere(
      (l) => l.code == 'en' || l.name.toLowerCase() == 'english',
      orElse: () => const TranslationLanguage(
        code: 'en',
        name: 'English',
        nativeName: 'English',
        category: LanguageCategory.global,
      ),
    );
    final nonEnglish = supportedLanguages
        .where((l) => l.code != 'en' && l.name.toLowerCase() != 'english')
        .toList();

    if (query.isEmpty) {
      return [english, ...nonEnglish];
    }

    final matches = supportedLanguages.where((l) {
      final nameLower = l.name.toLowerCase();
      final nativeLower = l.nativeName.toLowerCase();
      return nameLower.contains(query) || nativeLower.contains(query);
    }).toList();

    if (matches.any((l) => l.code == 'en')) {
      matches.removeWhere((l) => l.code == 'en');
      return [english, ...matches];
    }
    return matches;
  }


  /// Complete list of supported languages for onboarding primary language selection,
  /// with English pinned at the top, followed by all 130+ languages alphabetically.
  static final List<TranslationLanguage> staticLanguageOptions = _buildLanguageOptions();

  static List<TranslationLanguage> _buildLanguageOptions() {
    final english = supportedLanguages.firstWhere(
      (l) => l.code == 'en' || l.name.toLowerCase() == 'english',
      orElse: () => const TranslationLanguage(
        code: 'en',
        name: 'English',
        nativeName: 'English',
        category: LanguageCategory.global,
      ),
    );
    final others = supportedLanguages
        .where((l) => l.code != 'en' && l.name.toLowerCase() != 'english')
        .toList();
    others.sort((a, b) => a.name.compareTo(b.name));
    return List.unmodifiable([english, ...others]);
  }

  List<TranslationLanguage> get languageOptions => staticLanguageOptions;

  void selectLanguage(String languageName) {
    selectedLanguage.value = languageName;
  }

  void updateLanguageSearch(String query) {
    languageSearchQuery.value = query;
  }

  void clearLanguageSearch() {
    languageSearchController.clear();
    languageSearchQuery.value = '';
  }

  /// List of selectable countries ensuring selected country is always present in items
  List<CashfreeCountryInfo> get countryOptions {
    final cur = selectedCountry.value;
    final all = CashfreeCountrySupport.allCountries;
    if (cur != null && cur.isNotEmpty && !all.any((c) => c.code == cur)) {
      final list = List<CashfreeCountryInfo>.from(all);
      list.add(CashfreeCountrySupport.getCountryInfo(cur));
      return list;
    }
    return all;
  }

  void selectCountry(String? code) {
    if (code != null && code.isNotEmpty) {
      selectedCountry.value = CashfreeCountrySupport.normalizeCode(code);
    } else {
      selectedCountry.value = null;
    }
  }

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

  /// Returns true if user signed up/in with phone auth or lacks an email address
  bool get isPhoneUser {
    try {
      if (Get.isRegistered<AuthService>()) {
        final auth = AuthService.to;
        final u = auth.user;
        if (u == null) return false;
        final isPhoneProvider = auth.primaryAuthProvider == 'phone' ||
            u.providerData.any((p) => p.providerId == 'phone');
        final hasNoEmail = u.email == null || u.email!.trim().isEmpty;
        final hasPhone = u.phoneNumber != null && u.phoneNumber!.trim().isNotEmpty;
        return isPhoneProvider || (hasPhone && hasNoEmail);
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'GoogleOnboardingController.isPhoneUser',
      );
    }
    return false;
  }

  GoogleOnboardingController() {
    usernameController.addListener(_onUsernameChanged);
    reinitialize();
  }

  @override
  void onInit() {
    super.onInit();
    reinitialize();
  }

  void _onUsernameChanged() {
    if (usernameError.value != null) {
      usernameError.value = null;
    }
  }

  /// Populates the selected state from AuthService
  void reinitialize() {
    try {
      if (!Get.isRegistered<AuthService>()) return;
      final auth = AuthService.to;

      // 0. Reset username error / controller (standard users do not require a handle)
      usernameController.text = '';
      usernameError.value = null;

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

      // 3. Initialize Country (Priority: Auth profile -> Currency localization detected -> 'IN')
      final currentCountry = auth.userCountry.value;
      if (currentCountry != null && currentCountry.trim().isNotEmpty) {
        selectedCountry.value = CashfreeCountrySupport.normalizeCode(currentCountry);
      } else if (Get.isRegistered<CurrencyLocalizationService>()) {
        selectedCountry.value = CurrencyLocalizationService.to.userCountryCode.value;
      } else {
        selectedCountry.value = 'IN';
      }

      // 4. Initialize Language (Priority: UserLanguagesService -> 'English')
      if (Get.isRegistered<UserLanguagesService>()) {
        final lang = UserLanguagesService.to.primaryLanguage.value;
        if (lang.isNotEmpty) {
          selectedLanguage.value = lang;
        }
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

  /// Infers age group from numeric age (starting from 18 years, not below)
  String? inferAgeGroupFromAge(int age) {
    if (age < 18) return null;
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

  /// Validates username format, length, and profanity. Returns error message if invalid, null if valid.
  String? validateUsername(String raw) {
    final clean = raw.trim().replaceAll('@', '');
    if (clean.isEmpty) return null; // Optional during onboarding
    if (!RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(clean)) {
      return 'Username can only contain letters, numbers, underscores, and periods';
    }
    if (clean.length < 3) {
      return 'Username must be at least 3 characters';
    }
    if (clean.length > 30) {
      return 'Username cannot exceed 30 characters';
    }
    final validation = ContentValidator.validate(
      clean,
      fieldName: 'Username',
      minLength: 3,
      maxLength: 30,
    );
    if (!validation.isValid) {
      return validation.message;
    }

    final spacedClean = clean.replaceAll(RegExp('[_.]'), ' ');
    if (ContentValidator.hasProfanity(spacedClean)) {
      return 'Your Username contains inappropriate language. Please use respectful words.';
    }

    return null;
  }

  Future<void> save(BuildContext context) => onSave(context);

  Future<void> skip([BuildContext? context]) {
    if (context != null) return onSkip(context);
    if (Get.context != null) return onSkip(Get.context!);
    return Future.value();
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

      if (Get.isRegistered<UserLanguagesService>()) {
        await UserLanguagesService.to.setPrimaryLanguage(selectedLanguage.value);
      }

      await AuthService.to.updateUserProfileOnboarding(
        country: selectedCountry.value,
        ageGroup: selectedAgeGroup.value,
        gender: genderValue,
        primaryLanguage: selectedLanguage.value,
      );

      if (context.mounted) {
        _isClosing = true;
        navigator.pop();
      }
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error('Unable to save your profile. Please try again.');
    } finally {
      if (!_isClosing) {
        isSaving.value = false;
      }
    }
  }

  Future<void> onSkip(BuildContext context) async {
    isSaving.value = true;
    final navigator = Navigator.of(context);

    try {
      if (isFirstTimeOnboarding) {
        await AuthService.to.skipUserOnboarding(
          defaultCountry: selectedCountry.value,
        );
      }
      if (context.mounted) {
        _isClosing = true;
        navigator.pop();
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'GoogleOnboardingController.onSkip',
      );
      if (context.mounted) {
        _isClosing = true;
        navigator.pop();
      }
    } finally {
      if (!_isClosing) {
        isSaving.value = false;
      }
    }
  }

}
