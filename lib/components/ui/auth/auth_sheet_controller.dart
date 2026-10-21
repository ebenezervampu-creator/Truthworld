import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/components/ui/auth/country_dial_codes.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/currency_localization_service.dart';
import 'package:truthworld/core/services/user_languages_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/video/data/models/ai_features.dart';

export 'package:truthworld/components/ui/auth/country_dial_codes.dart';

/// Steps within the multi-method authentication sheet.
enum AuthStep {
  languageSelection,
  languageNotice,
  options,
  phoneInput,
  otpVerification,
}

/// Controller managing authentication options (Google, Apple, Phone OTP) and language onboarding.
class AuthSheetController extends BaseController {
  /// Returns whether the target platform is an Apple platform (iOS, macOS).
  /// On Web (`kIsWeb`), Google Sign-In is used as the exclusive authentication provider.
  static bool isApplePlatform([TargetPlatform? platform, bool? isWeb]) {
    final runningOnWeb = isWeb ?? kIsWeb;
    if (runningOnWeb && platform == null) return false;
    final target = platform ?? defaultTargetPlatform;
    return target == TargetPlatform.iOS || target == TargetPlatform.macOS;
  }

  /// Returns whether the target platform is Android.
  static bool isAndroidPlatform([TargetPlatform? platform, bool? isWeb]) {
    final runningOnWeb = isWeb ?? kIsWeb;
    if (runningOnWeb && platform == null) return false;
    final target = platform ?? defaultTargetPlatform;
    return target == TargetPlatform.android;
  }

  /// Returns whether the target platform is Web.
  static bool isWebPlatform([bool? isWeb]) {
    return isWeb ?? kIsWeb;
  }

  final Rx<AuthStep> currentStep = AuthStep.options.obs;
  final RxnString selectedLanguage = RxnString();
  final RxString languageSearchQuery = ''.obs;
  final RxBool isSubmittingLanguageRequest = false.obs;
  final RxBool isLanguageRequestSubmitted = false.obs;
  final RxSet<String> requestedLanguages = <String>{}.obs;

  late final TextEditingController languageSearchController =
      trackTextController(TextEditingController());
  late final TextEditingController requestEmailController =
      trackTextController(TextEditingController());

  final RxBool isAuthBusy = false.obs;
  final RxString activeProvider = ''.obs;

  @override
  bool get isLoading => isAuthBusy.value || super.isLoading;

  late final TextEditingController phoneController =
      trackTextController(TextEditingController());
  late final TextEditingController otpController =
      trackTextController(TextEditingController());
  late final TextEditingController countrySearchController =
      trackTextController(TextEditingController());

  final Rx<CountryDialCode> selectedCountry =
      CountryDialCodes.defaultCountry.obs;

  final RxString countrySearchQuery = ''.obs;
  final RxString verificationId = ''.obs;
  final RxnInt resendToken = RxnInt();
  final Rxn<ConfirmationResult> webConfirmation = Rxn<ConfirmationResult>();

  final RxInt resendCountdown = 60.obs;
  final RxBool canResend = false.obs;
  Timer? _countdownTimer;
  bool _isClosing = false;
  VoidCallback? onCloseCallback;

  /// Global authoritative country calling codes for phone authentication.
  static const List<CountryDialCode> supportedCountries = CountryDialCodes.all;
  static const List<CountryDialCode> allCountries = CountryDialCodes.all;

  /// Dynamically filtered country list based on search query.
  List<CountryDialCode> get filteredCountries {
    final query = countrySearchQuery.value.trim().toLowerCase();
    if (query.isEmpty) return supportedCountries;
    final cleanDial = query.replaceAll(RegExp(r'[\s\+\-\(\)]'), '');
    return supportedCountries.where((c) {
      final nameLower = c.name.toLowerCase();
      final isoLower = c.isoCode.toLowerCase();
      final dialDigits = c.dialCode.replaceAll('+', '');
      return nameLower.contains(query) ||
          isoLower.contains(query) ||
          (cleanDial.isNotEmpty && dialDigits.contains(cleanDial));
    }).toList();
  }

  void updateCountrySearch(String query) {
    countrySearchQuery.value = query;
  }

  void clearCountrySearch() {
    countrySearchController.clear();
    countrySearchQuery.value = '';
  }

  /// Dynamically filtered translation languages for onboarding.
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

  void updateLanguageSearch(String query) {
    languageSearchQuery.value = query;
  }

  void clearLanguageSearch() {
    languageSearchController.clear();
    languageSearchQuery.value = '';
  }

  void selectPrimaryLanguage(String languageName) {
    selectedLanguage.value = languageName;
    if (Get.isRegistered<UserLanguagesService>()) {
      UserLanguagesService.to.setPrimaryLanguage(languageName);
    }
    currentStep.value = AuthStep.options;
  }

  void continueWithEnglish() {
    selectedLanguage.value = 'English';
    if (Get.isRegistered<UserLanguagesService>()) {
      UserLanguagesService.to.setPrimaryLanguage('English');
    }
    currentStep.value = AuthStep.options;
  }

  void goToLanguageSelection() {
    clearLanguageSearch();
    currentStep.value = AuthStep.languageSelection;
  }

  Future<void> submitLanguageRequest([String? lang]) async {
    final language = lang ?? selectedLanguage.value ?? '';
    if (language.isEmpty || isSubmittingLanguageRequest.value) return;

    try {
      isSubmittingLanguageRequest.value = true;
      requestedLanguages.add(language.toLowerCase());
      try {
        final box = GetStorage();
        box.write('lang_req_${language.toLowerCase()}', true);
      } catch (_) {}

      final email = requestEmailController.text.trim();
      final currentUid =
          Get.isRegistered<AuthService>() ? AuthService.to.uid : '';

      if (currentUid.isNotEmpty) {
        try {
          await FirebaseFirestore.instance
              .collection(FirestoreCollections.channelLanguageRequests)
              .add({
            'userId': currentUid,
            'email': email.isNotEmpty ? email : AuthService.to.email,
            'languageName': language,
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
            'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
            'source': 'sign_in_language_modal',
          });
        } catch (e, st) {
          ErrorHandler.log(
            e,
            stackTrace: st,
            tag: 'AuthSheetController.submitLangReq',
          );
        }
      }

      isLanguageRequestSubmitted.value = true;
      AppSnackbar.success(
        'Thank you! Your request for $language has been recorded.',
      );
    } catch (e, st) {
      ErrorHandler.log(
        e,
        stackTrace: st,
        tag: 'AuthSheetController.submitLangReq',
      );
      AppSnackbar.error('Unable to submit request. Please try again.');
    } finally {
      isSubmittingLanguageRequest.value = false;
    }
  }

  @override
  void onInit() {
    super.onInit();
    _detectInitialCountry();
    addWorker(
      ever<bool>(AuthService.to.isAuthenticated, (authenticated) {
        if (authenticated) {
          _closeSheet();
        }
      }),
    );
  }

  void _detectInitialCountry() {
    try {
      if (Get.isRegistered<CurrencyLocalizationService>()) {
        final detected = CurrencyLocalizationService.to.userCountryCode.value;
        final match = supportedCountries.firstWhereOrNull(
          (c) => c.isoCode.toUpperCase() == detected.toUpperCase(),
        );
        if (match != null) {
          selectedCountry.value = match;
        }
      }
    } catch (_) {}
  }

  void selectCountry(CountryDialCode country) {
    selectedCountry.value = country;
    clearCountrySearch();
  }

  void goToPhoneInput() {
    currentStep.value = AuthStep.phoneInput;
    clearCountrySearch();
  }

  void goToOptions() {
    currentStep.value = AuthStep.options;
    phoneController.clear();
    otpController.clear();
    clearCountrySearch();
    _stopCountdown();
    try {
      if (Get.isRegistered<AuthService>()) {
        AuthService.to.phoneProvider.clear();
      }
    } catch (_) {}
  }

  void changePhoneNumber() {
    currentStep.value = AuthStep.phoneInput;
    otpController.clear();
    _stopCountdown();
  }

  /// Sign in with Google
  Future<void> signInWithGoogle() async {
    if (isAuthBusy.value) return;
    try {
      isAuthBusy.value = true;
      activeProvider.value = 'google';
      await AuthService.to.signInWithGoogle();
      if (AuthService.to.isAuthenticated.value) {
        _closeSheet();
      }
    } on GoogleSignInException catch (e) {
      if (e.code == 'redirecting') {
        _closeSheet();
        return;
      }
      if (e.code == 'user-cancelled' ||
          e.code == 'popup-closed' ||
          e.code == 'popup-closed-by-user') {
        return;
      }
      AppSnackbar.error(e.displayMessage);
    } catch (e, st) {
      ErrorHandler.log(e, stackTrace: st, tag: 'AuthSheetController.google');
      AppSnackbar.error('Unable to complete Google sign-in. Please try again.');
    } finally {
      if (!_isClosing) {
        isAuthBusy.value = false;
        activeProvider.value = '';
      }
    }
  }

  /// Sign in with Apple
  Future<void> signInWithApple() async {
    if (isAuthBusy.value) return;
    try {
      isAuthBusy.value = true;
      activeProvider.value = 'apple';
      await AuthService.to.signInWithApple();
      if (AuthService.to.isAuthenticated.value) {
        _closeSheet();
      }
    } on AppleSignInException catch (e) {
      if (e.code == 'redirecting') {
        _closeSheet();
        return;
      }
      if (e.code == 'user-cancelled') {
        return;
      }
      AppSnackbar.error(e.displayMessage);
    } catch (e, st) {
      ErrorHandler.log(e, stackTrace: st, tag: 'AuthSheetController.apple');
      AppSnackbar.error('Unable to complete Apple sign-in. Please try again.');
    } finally {
      if (!_isClosing) {
        isAuthBusy.value = false;
        activeProvider.value = '';
      }
    }
  }

  /// Request SMS OTP verification code
  Future<void> sendVerificationCode() async {
    final rawPhone = phoneController.text.trim();
    if (rawPhone.isEmpty) {
      AppSnackbar.info('Please enter your phone number.');
      return;
    }

    final fullNumber = AuthPhoneSignInProvider.normalizePhoneNumber(
      rawPhone,
      countryCode: selectedCountry.value.dialCode,
    );
    if (fullNumber.length < 8) {
      AppSnackbar.info('Please enter a valid phone number.');
      return;
    }
    try {
      isAuthBusy.value = true;
      activeProvider.value = 'phone';

      await AuthService.to.verifyPhoneNumber(
        phoneNumber: fullNumber,
        resendToken: resendToken.value,
        onCodeSent: (id, token) {
          verificationId.value = id;
          resendToken.value = token;
          webConfirmation.value =
              AuthService.to.phoneProvider.webConfirmationResult;
          isAuthBusy.value = false;
          activeProvider.value = '';
          currentStep.value = AuthStep.otpVerification;
          _startCountdown();
          AppSnackbar.success('Verification code sent to $fullNumber');
        },
        onVerificationCompleted: (credential) async {
          isAuthBusy.value = false;
          activeProvider.value = '';
          if (AuthService.to.isAuthenticated.value) {
            _closeSheet();
            AppSnackbar.success('Signed in successfully.');
          }
        },
        onVerificationFailed: (error) {
          isAuthBusy.value = false;
          activeProvider.value = '';
          AppSnackbar.error(error.displayMessage);
        },
        onCodeAutoRetrievalTimeout: (id) {
          verificationId.value = id;
        },
      );
    } catch (e, st) {
      isAuthBusy.value = false;
      activeProvider.value = '';
      ErrorHandler.log(e, stackTrace: st, tag: 'AuthSheetController.sendCode');
      AppSnackbar.error('Unable to send verification code. Please check the number.');
    }
  }

  /// Verify entered SMS OTP code
  Future<void> verifyOtpAndSignIn() async {
    if (AuthService.to.isAuthenticated.value) {
      _closeSheet();
      return;
    }

    final code = otpController.text.trim();
    if (code.length < 6) {
      AppSnackbar.info('Please enter the 6-digit verification code.');
      return;
    }

    try {
      isAuthBusy.value = true;
      activeProvider.value = 'otp';

      await AuthService.to.signInWithPhoneOtp(
        verificationId: verificationId.value,
        smsCode: code,
        confirmationResult: webConfirmation.value,
      );

      if (AuthService.to.isAuthenticated.value) {
        _closeSheet();
      }
    } on PhoneAuthException catch (e) {
      if (e.code == 'session-expired') {
        canResend.value = true;
      }
      AppSnackbar.error(e.displayMessage);
    } catch (e, st) {
      ErrorHandler.log(e, stackTrace: st, tag: 'AuthSheetController.verifyOtp');
      AppSnackbar.error('Verification code invalid or expired. Please try again.');
    } finally {
      if (!_isClosing) {
        isAuthBusy.value = false;
        activeProvider.value = '';
      }
    }
  }

  /// Resend SMS OTP
  Future<void> resendOtp() async {
    if (!canResend.value || isAuthBusy.value) return;
    await sendVerificationCode();
  }

  void _startCountdown() {
    _stopCountdown();
    resendCountdown.value = 60;
    canResend.value = false;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (resendCountdown.value > 1) {
        resendCountdown.value--;
      } else {
        canResend.value = true;
        _stopCountdown();
      }
    });
  }

  void _stopCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  void _closeSheet() {
    if (_isClosing) return;
    _isClosing = true;
    _stopCountdown();
    onCloseCallback?.call();
    try {
      final ctx = Get.key.currentContext ?? Get.context;
      if (ctx != null) {
        final nav = Navigator.of(ctx, rootNavigator: true);
        if (nav.canPop()) {
          nav.pop();
          return;
        }
      }
    } catch (_) {}
    if (Get.isBottomSheetOpen ?? false) {
      Get.back();
    }
  }

  @override
  void onClose() {
    _isClosing = true;
    _stopCountdown();
    try {
      if (Get.isRegistered<AuthService>()) {
        AuthService.to.phoneProvider.clear();
      }
    } catch (_) {}
    super.onClose();
  }
}
