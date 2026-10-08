import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';
/// Manages Firebase Phone Authentication across Web, iOS, and Android.
class AuthPhoneSignInProvider {
  ConfirmationResult? _webConfirmationResult;
  ConfirmationResult? get webConfirmationResult => _webConfirmationResult;
  RecaptchaVerifier? _webRecaptchaVerifier;

  /// Cleans up any pending reCAPTCHA verifiers or confirmation sessions.
  void clear() {
    _webConfirmationResult = null;
    try {
      _webRecaptchaVerifier?.clear();
    } catch (_) {}
    _webRecaptchaVerifier = null;
  }

  /// Normalizes a phone number to standard E.164 format.
  /// Handles country code deduplication, leading zeroes, spaces, and formatting.
  static String normalizePhoneNumber(String rawPhoneNumber, {String countryCode = '+1'}) {
    var cleaned = rawPhoneNumber.replaceAll(RegExp(r'[\s\-\(\)\.]'), '');
    if (cleaned.isEmpty) return '';

    // Normalize countryCode to guarantee leading '+'
    final cleanCode = countryCode.replaceAll(RegExp(r'[\s\-\(\)\.]'), '');
    final prefixWithPlus = cleanCode.startsWith('+') ? cleanCode : '+$cleanCode';
    final prefixDigits = prefixWithPlus.substring(1); // digits only, e.g. "91" or "1"

    // If string starts with double zero international prefix "00", replace with "+"
    if (cleaned.startsWith('00')) {
      cleaned = '+${cleaned.substring(2)}';
    }

    // If user already entered a leading '+'
    if (cleaned.startsWith('+')) {
      cleaned = '+${cleaned.replaceAll('+', '')}';
      return cleaned;
    }

    // Strip leading national trunk zero (e.g. "09876543210" -> "9876543210")
    if (cleaned.startsWith('0') && cleaned.length > 8) {
      cleaned = cleaned.replaceFirst(RegExp('^0+'), '');
    }

    // If cleaned number already starts with the country dial code digits (e.g. "919876543210" with code "+91")
    if (cleaned.startsWith(prefixDigits) && cleaned.length >= prefixDigits.length + 8) {
      return '+$cleaned';
    }

    // Otherwise prepend the formatted country code
    return '$prefixWithPlus$cleaned';
  }

  /// Initiates SMS code delivery to the target phone number.
  Future<void> verifyPhoneNumber({
    required FirebaseAuth auth,
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(PhoneAuthCredential credential) onVerificationCompleted,
    required void Function(PhoneAuthException error) onVerificationFailed,
    required void Function(String verificationId) onCodeAutoRetrievalTimeout,
    int? resendToken,
  }) async {
    final normalized = normalizePhoneNumber(phoneNumber);

    if (normalized.length < 8) {
      const error = PhoneAuthException(
        message: 'Invalid phone number length.',
        userMessage: 'Please enter a valid phone number with country code.',
        code: 'invalid-phone-number',
        isRetryable: true,
      );
      onVerificationFailed(error);
      return;
    }

    try {
      if (kIsWeb) {
        try {
          _webRecaptchaVerifier?.clear();
        } catch (_) {}
        final verifier = RecaptchaVerifier(
          auth: FirebaseAuthPlatform.instance,
          onError: (e) => ErrorHandler.log(
            e,
            tag: 'AuthPhoneSignInProvider.recaptcha',
          ),
          onExpired: () => debugPrint('ℹ️ [AuthPhone] reCAPTCHA token expired'),
        );
        _webRecaptchaVerifier = verifier;
        final confirmation =
            await auth.signInWithPhoneNumber(normalized, verifier);
        _webConfirmationResult = confirmation;
        onCodeSent(confirmation.verificationId, null);
      } else {
        await auth.verifyPhoneNumber(
          phoneNumber: normalized,
          timeout: const Duration(seconds: 60),
          forceResendingToken: resendToken,
          verificationCompleted: onVerificationCompleted,
          verificationFailed: (e) {
            final mapped = _mapPhoneAuthException(e);
            ErrorHandler.log(
              e,
              tag: 'AuthPhoneSignInProvider.verifyPhoneNumber.failed',
            );
            onVerificationFailed(mapped);
          },
          codeSent: (verificationId, newResendToken) {
            onCodeSent(verificationId, newResendToken);
          },
          codeAutoRetrievalTimeout: onCodeAutoRetrievalTimeout,
        );
      }
    } catch (e, st) {
      final mapped = _mapPhoneAuthException(e, st);
      ErrorHandler.log(
        e,
        stackTrace: st,
        tag: 'AuthPhoneSignInProvider.verifyPhoneNumber',
      );
      onVerificationFailed(mapped);
    }
  }

  /// Verifies the entered SMS OTP code and completes authentication.
  Future<UserCredential> signInWithOtp({
    required FirebaseAuth auth,
    required String verificationId,
    required String smsCode,
    ConfirmationResult? webConfirmation,
  }) async {
    final trimmedCode = smsCode.trim();
    if (trimmedCode.length < 6) {
      throw const PhoneAuthException(
        message: 'Invalid OTP length.',
        userMessage: 'Please enter the full 6-digit verification code.',
        code: 'invalid-verification-code',
        isRetryable: true,
      );
    }

    try {
      if (kIsWeb) {
        final confirmation = webConfirmation ?? _webConfirmationResult;
        if (confirmation != null) {
          final cred = await confirmation.confirm(trimmedCode);
          _webConfirmationResult = null;
          try {
            _webRecaptchaVerifier?.clear();
          } catch (_) {}
          _webRecaptchaVerifier = null;
          return cred;
        }
      }

      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: trimmedCode,
      );
      return await auth.signInWithCredential(credential);
    } catch (e, st) {
      final mapped = _mapPhoneAuthException(e, st);
      if (mapped.code != 'session-expired' &&
          mapped.code != 'invalid-verification-code') {
        ErrorHandler.log(
          e,
          stackTrace: st,
          tag: 'AuthPhoneSignInProvider.signInWithOtp',
        );
      } else {
        debugPrint('ℹ️ [AuthPhone] OTP validation notice: ${mapped.message}');
      }
      throw mapped;
    }
  }

  /// Re-authenticates user with PhoneAuthCredential before sensitive operations.
  Future<UserCredential> reauthenticateWithPhone(
    User user,
    PhoneAuthCredential credential,
  ) {
    return user.reauthenticateWithCredential(credential);
  }

  PhoneAuthException _mapPhoneAuthException(dynamic exception, [StackTrace? st]) {
    final str = exception.toString().toLowerCase();

    if (str.contains('invalid-phone-number') ||
        str.contains('invalid phone number') ||
        str.contains('missing-phone-number')) {
      return PhoneAuthException(
        message: 'Invalid phone number format.',
        userMessage:
            'Please enter a valid phone number including country code (e.g. +1 555 123 4567).',
        code: 'invalid-phone-number',
        isRetryable: true,
        originalException: exception,
        stackTrace: st,
      );
    }

    if (str.contains('invalid-verification-code') ||
        str.contains('invalid code') ||
        str.contains('code is invalid')) {
      return PhoneAuthException(
        message: 'Invalid verification code.',
        userMessage:
            'The verification code is incorrect. Please check the code sent to your phone and try again.',
        code: 'invalid-verification-code',
        isRetryable: true,
        originalException: exception,
        stackTrace: st,
      );
    }

    if (str.contains('session-expired') || str.contains('code-expired')) {
      return PhoneAuthException(
        message: 'Verification code expired.',
        userMessage:
            'The verification code has expired. Please request a new code.',
        code: 'session-expired',
        isRetryable: true,
        originalException: exception,
        stackTrace: st,
      );
    }

    if (str.contains('quota-exceeded') || str.contains('exceeded quota')) {
      return PhoneAuthException(
        message: 'SMS quota exceeded.',
        userMessage:
            'SMS limit reached for this device. Please try again later or sign in with Google or Apple.',
        code: 'quota-exceeded',
        originalException: exception,
        stackTrace: st,
      );
    }

    if (str.contains('too-many-requests')) {
      return PhoneAuthException(
        message: 'Too many requests.',
        userMessage:
            'Too many requests sent. Please wait a few moments before trying again.',
        code: 'too-many-requests',
        isRetryable: true,
        originalException: exception,
        stackTrace: st,
      );
    }

    if (str.contains('network-request-failed') ||
        str.contains('socketexception')) {
      return PhoneAuthException(
        message: 'Network error.',
        userMessage:
            'Unable to connect. Please check your internet connection and try again.',
        code: 'network-error',
        isRetryable: true,
        originalException: exception,
        stackTrace: st,
      );
    }

    if (str.contains('app-not-authorized') ||
        str.contains('not authorized to use firebase authentication')) {
      const userMsg = kIsWeb
          ? 'This web domain is not authorized for phone authentication in Firebase Console. Please verify authorized domains.'
          : 'Unable to complete verification on this app version. Please try signing in with Google or Apple, or contact support.';
      return PhoneAuthException(
        message:
            'Application build signature or web domain not registered in Firebase Console.',
        userMessage: userMsg,
        code: 'app-not-authorized',
        originalException: exception,
        stackTrace: st,
      );
    }

    if (str.contains('missing-client-identifier') ||
        str.contains('invalid-app-credential') ||
        str.contains('captcha-check-failed')) {
      const userMsg = kIsWeb
          ? 'Security verification could not be completed. Please refresh the page and try again.'
          : 'Device security verification could not be completed. Please ensure Google Play Services is updated and enabled.';
      return PhoneAuthException(
        message: 'Device verification could not be completed.',
        userMessage: userMsg,
        code: 'missing-client-identifier',
        isRetryable: true,
        originalException: exception,
        stackTrace: st,
      );
    }

    if (str.contains('operation-not-allowed')) {
      return PhoneAuthException(
        message: 'Phone sign-in is disabled.',
        userMessage:
            'Phone number sign-in is currently unavailable. Please sign in with Google or Apple.',
        code: 'operation-not-allowed',
        originalException: exception,
        stackTrace: st,
      );
    }

    if (str.contains('blocked all requests') || str.contains('unusual activity')) {
      return PhoneAuthException(
        message: 'Requests blocked due to unusual activity.',
        userMessage:
            'Too many attempts detected from this device. Please wait a short while before trying again.',
        code: 'requests-blocked',
        isRetryable: true,
        originalException: exception,
        stackTrace: st,
      );
    }

    if (str.contains('app-check') || str.contains('appcheck')) {
      return PhoneAuthException(
        message: 'Device verification failed.',
        userMessage:
            'Device security verification failed. Please try again.',
        code: 'app-check-failed',
        isRetryable: true,
        originalException: exception,
        stackTrace: st,
      );
    }

    return PhoneAuthException(
      message: 'Phone authentication failed.',
      userMessage:
          'Unable to complete phone verification. Please check the number and try again.',
      code: 'phone-auth-failed',
      isRetryable: true,
      originalException: exception,
      stackTrace: st,
    );
  }
}
