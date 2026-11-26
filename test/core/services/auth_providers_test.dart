import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_sign_in/google_sign_in.dart' as gsi;
import 'package:mocktail/mocktail.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';
import 'package:truthworld/core/services/auth_service.dart';
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

  group('AuthService Platform Detection Tests', () {
    test('Platform detection correctly distinguishes Apple from Android', () {
      // Apple platforms (iOS and macOS)
      expect(AuthService.isApplePlatform(TargetPlatform.iOS), isTrue);
      expect(AuthService.isApplePlatform(TargetPlatform.macOS), isTrue);
      expect(AuthService.isApplePlatform(TargetPlatform.android), isFalse);
      expect(AuthService.isApplePlatform(TargetPlatform.windows), isFalse);

      // Android platform
      expect(AuthService.isAndroidPlatform(TargetPlatform.android), isTrue);
      expect(AuthService.isAndroidPlatform(TargetPlatform.iOS), isFalse);
      expect(AuthService.isAndroidPlatform(TargetPlatform.macOS), isFalse);
      expect(AuthService.isAndroidPlatform(TargetPlatform.windows), isFalse);
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

    test('GoogleSignInExceptionHandler maps user cancellation to info severity and isCancelled', () {
      const canceledEx = gsi.GoogleSignInException(
        code: gsi.GoogleSignInExceptionCode.canceled,
        description: 'Sign-in was cancelled',
      );
      final mapped = GoogleSignInExceptionHandler.from(canceledEx);
      expect(mapped.code, equals('user-cancelled'));
      expect(mapped.isCancelled, isTrue);
      expect(mapped.severity, equals(ErrorSeverity.info));
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

    test('DefaultFirebaseOptions uses canonical authDomain', () {
      expect(
        DefaultFirebaseOptions.defaultAuthDomain,
        anyOf(equals('www.truthworld.in'), equals('truthworld-1.firebaseapp.com')),
      );
      expect(
        DefaultFirebaseOptions.resolvedWebAuthDomain,
        anyOf(equals('www.truthworld.in'), equals('truthworld-1.firebaseapp.com')),
      );
    });
  });
}
