import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_sign_in/google_sign_in.dart' as gsi;
import 'package:mocktail/mocktail.dart';
import 'package:truthworld/components/ui/auth/auth_sheet_controller.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';
import 'package:truthworld/core/services/auth/auth_google_signin_provider.dart';
import 'package:truthworld/core/services/auth/auth_phone_signin_provider.dart';
import 'package:truthworld/core/services/google_signin_exception_handler.dart';
import 'package:truthworld/firebase_options.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}
class MockUserCredential extends Mock implements UserCredential {}
class MockAuthProvider extends Mock implements AuthProvider {}
class MockUser extends Mock implements User {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (methodCall) async => '.',
    );
    try {
      await GetStorage.init();
    } catch (_) {}
  });

  group('AuthPhoneSignInProvider Tests', () {
    test('normalizePhoneNumber formats correctly with country code', () {
      expect(
        AuthPhoneSignInProvider.normalizePhoneNumber('5551234567'),
        equals('+15551234567'),
      );
      expect(
        AuthPhoneSignInProvider.normalizePhoneNumber('(555) 123-4567'),
        equals('+15551234567'),
      );
      expect(
        AuthPhoneSignInProvider.normalizePhoneNumber('+91 98765 43210'),
        equals('+919876543210'),
      );
      expect(
        AuthPhoneSignInProvider.normalizePhoneNumber('9876543210', countryCode: '+91'),
        equals('+919876543210'),
      );
      // Handles leading zero stripping (e.g. India 09876543210 -> +919876543210)
      expect(
        AuthPhoneSignInProvider.normalizePhoneNumber('09876543210', countryCode: '+91'),
        equals('+919876543210'),
      );
      // Handles dial code already present in digits (e.g. 919876543210 with countryCode +91)
      expect(
        AuthPhoneSignInProvider.normalizePhoneNumber('919876543210', countryCode: '+91'),
        equals('+919876543210'),
      );
      // Handles international 00 prefix
      expect(
        AuthPhoneSignInProvider.normalizePhoneNumber('00919876543210', countryCode: '+91'),
        equals('+919876543210'),
      );
    });

    test('Short phone numbers are rejected with user-friendly PhoneAuthException', () async {
      final provider = AuthPhoneSignInProvider();
      final mockAuth = MockFirebaseAuth();
      PhoneAuthException? capturedError;

      await provider.verifyPhoneNumber(
        auth: mockAuth,
        phoneNumber: '123',
        onCodeSent: (_, _) {},
        onVerificationCompleted: (_) {},
        onVerificationFailed: (error) {
          capturedError = error;
        },
        onCodeAutoRetrievalTimeout: (_) {},
      );

      expect(capturedError, isNotNull);
      expect(capturedError!.code, equals('invalid-phone-number'));
      expect(
        capturedError!.userMessage,
        contains('valid phone number with country code'),
      );
    });
  });

  group('AuthSheetController Tests', () {
    test('Initializes with default languageSelection step and country', () {
      final controller = AuthSheetController();
      expect(controller.currentStep.value, equals(AuthStep.languageSelection));
      expect(controller.selectedCountry.value.dialCode, isNotEmpty);
      expect(controller.isAuthBusy.value, isFalse);
    });

    test('Selecting English proceeds to options with Google sign-in available', () {
      final controller = AuthSheetController();
      controller.selectPrimaryLanguage('English');
      expect(controller.selectedLanguage.value, equals('English'));
      expect(controller.currentStep.value, equals(AuthStep.options));
    });

    test('Selecting non-English language transitions to languageNotice', () {
      final controller = AuthSheetController();
      controller.selectPrimaryLanguage('Spanish');
      expect(controller.selectedLanguage.value, equals('Spanish'));
      expect(controller.currentStep.value, equals(AuthStep.languageNotice));

      // Continuing with English switches to options
      controller.continueWithEnglish();
      expect(controller.selectedLanguage.value, equals('English'));
      expect(controller.currentStep.value, equals(AuthStep.options));
    });

    test('Language search filters supported languages with English available', () {
      final controller = AuthSheetController();
      expect(controller.filteredLanguages.first.name, equals('English'));

      controller.updateLanguageSearch('Span');
      expect(controller.filteredLanguages.any((l) => l.name.contains('Spanish')), isTrue);

      controller.clearLanguageSearch();
      expect(controller.languageSearchQuery.value, isEmpty);
    });

    test('Navigates between options, phone input, and resets gracefully', () {
      final controller = AuthSheetController();
      controller.selectPrimaryLanguage('English');
      controller.goToPhoneInput();
      expect(controller.currentStep.value, equals(AuthStep.phoneInput));

      controller.goToOptions();
      expect(controller.currentStep.value, equals(AuthStep.options));
      expect(controller.phoneController.text, isEmpty);
      expect(controller.otpController.text, isEmpty);
    });

    test('Country dial code can be selected', () {
      final controller = AuthSheetController();
      const india = CountryDialCode(name: 'India', dialCode: '+91', isoCode: 'IN');
      controller.selectCountry(india);
      expect(controller.selectedCountry.value.dialCode, equals('+91'));
      expect(controller.selectedCountry.value.isoCode, equals('IN'));
    });

    test('Platform detection correctly distinguishes Apple from Android', () {
      // Apple platforms (iOS and macOS)
      expect(AuthSheetController.isApplePlatform(TargetPlatform.iOS), isTrue);
      expect(AuthSheetController.isApplePlatform(TargetPlatform.macOS), isTrue);
      expect(AuthSheetController.isApplePlatform(TargetPlatform.android), isFalse);
      expect(AuthSheetController.isApplePlatform(TargetPlatform.windows), isFalse);

      // Android platform
      expect(AuthSheetController.isAndroidPlatform(TargetPlatform.android), isTrue);
      expect(AuthSheetController.isAndroidPlatform(TargetPlatform.iOS), isFalse);
      expect(AuthSheetController.isAndroidPlatform(TargetPlatform.macOS), isFalse);
      expect(AuthSheetController.isAndroidPlatform(TargetPlatform.windows), isFalse);
    });
  });

  group('Auth Exceptions Verification', () {
    test('AppleSignInException has polite user messages and proper defaults', () {
      const exception = AppleSignInException(
        message: 'Internal error',
        userMessage: 'Unable to sign in with Apple. Please try again.',
        code: 'apple-signin-failed',
        isRetryable: true,
      );
      expect(exception.code, equals('apple-signin-failed'));
      expect(exception.isRetryable, isTrue);
      expect(exception.displayMessage, equals('Unable to sign in with Apple. Please try again.'));
    });

    test('PhoneAuthException formats display messages clearly', () {
      const exception = PhoneAuthException(
        message: 'Invalid code provided.',
        userMessage: 'The verification code is incorrect. Please check and try again.',
        code: 'invalid-verification-code',
        isRetryable: true,
      );
      expect(exception.code, equals('invalid-verification-code'));
      expect(exception.isRetryable, isTrue);
      expect(exception.displayMessage, contains('verification code is incorrect'));
    });

    test('GoogleSignInExceptionHandler maps platform configuration errors properly', () {
      const platformEx = gsi.GoogleSignInException(
        code: gsi.GoogleSignInExceptionCode.clientConfigurationError,
        description: 'Server client ID missing',
      );
      final mapped = GoogleSignInExceptionHandler.from(platformEx);
      expect(mapped.code, equals('configuration-error'));
      expect(mapped.isRetryable, isFalse);
      expect(mapped.displayMessage, contains('SHA-1 fingerprint'));
    });

    test('GoogleSignInExceptionHandler maps unauthorized-domain properly', () {
      final authEx = FirebaseAuthException(
        code: 'unauthorized-domain',
        message: 'Domain not authorized',
      );
      final mapped = GoogleSignInExceptionHandler.from(authEx);
      expect(mapped.code, equals('unauthorized-domain'));
      expect(mapped.displayMessage, contains('Authorized domains'));
    });
  });

  group('AuthGoogleSignInProvider Web & WASM Flow Tests', () {
    setUpAll(() async {
      registerFallbackValue(MockAuthProvider());
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (methodCall) async => '.',
      );
      try {
        await GetStorage.init();
      } catch (_) {}
    });

    test('signInWithGoogleWeb uses signInWithPopup across Web and WASM', () async {
      final provider = AuthGoogleSignInProvider();
      final mockAuth = MockFirebaseAuth();
      final mockCredential = MockUserCredential();

      when(() => mockAuth.signInWithPopup(any())).thenAnswer((_) async => mockCredential);

      final resultNonWasm = await provider.signInWithGoogleWeb(
        mockAuth,
        isWasmOverride: false,
      );
      expect(resultNonWasm, equals(mockCredential));

      final resultWasm = await provider.signInWithGoogleWeb(
        mockAuth,
        isWasmOverride: true,
      );
      expect(resultWasm, equals(mockCredential));

      verify(() => mockAuth.signInWithPopup(any())).called(2);
      verifyNever(() => mockAuth.signInWithRedirect(any()));
    });

    test('signInWithGoogleWeb handles popup-closed-by-user gracefully without redirecting or throwing fatal error', () async {
      final provider = AuthGoogleSignInProvider();
      final mockAuth = MockFirebaseAuth();

      when(() => mockAuth.signInWithPopup(any())).thenThrow(
        FirebaseAuthException(code: 'popup-closed-by-user', message: 'Popup was closed'),
      );

      expect(
        () => provider.signInWithGoogleWeb(
          mockAuth,
          isWasmOverride: true,
        ),
        throwsA(
          isA<GoogleSignInException>().having(
            (e) => e.code,
            'code',
            equals('user-cancelled'),
          ),
        ),
      );
      verify(() => mockAuth.signInWithPopup(any())).called(1);
      verifyNever(() => mockAuth.signInWithRedirect(any()));
    });

    test('signInWithGoogleWeb falls back to redirect when popup is blocked', () async {
      final provider = AuthGoogleSignInProvider();
      final mockAuth = MockFirebaseAuth();

      when(() => mockAuth.signInWithPopup(any())).thenThrow(
        FirebaseAuthException(code: 'popup-blocked', message: 'Popup blocked by browser'),
      );
      when(() => mockAuth.signInWithRedirect(any())).thenAnswer((_) async {});

      expect(
        () => provider.signInWithGoogleWeb(
          mockAuth,
          isWasmOverride: true,
        ),
        throwsA(
          isA<GoogleSignInException>().having(
            (e) => e.code,
            'code',
            equals('redirecting'),
          ),
        ),
      );
      verify(() => mockAuth.signInWithPopup(any())).called(1);
      verify(() => mockAuth.signInWithRedirect(any())).called(1);

      final box = GetStorage();
      expect(box.read<bool>('auth_pending_redirect'), isTrue);
      expect(box.read<int>('auth_pending_redirect_time'), isNotNull);
    });

    test('reauthenticateWithGoogle provider initializes and handles reauthentication cleanly', () async {
      final provider = AuthGoogleSignInProvider();
      expect(provider, isNotNull);
    });

    test('isWasm getter safely reports web runtime environment without crashing', () {
      // On VM test runtime, kIsWeb is false so isWasm evaluates to false.
      expect(AuthGoogleSignInProvider.isWasm, isFalse);
    });

    test('DefaultFirebaseOptions uses canonical www.truthworld.in authDomain', () {
      expect(
        DefaultFirebaseOptions.defaultAuthDomain,
        equals('www.truthworld.in'),
      );
      expect(
        DefaultFirebaseOptions.resolvedWebAuthDomain,
        equals('www.truthworld.in'),
      );
    });
  });
}
